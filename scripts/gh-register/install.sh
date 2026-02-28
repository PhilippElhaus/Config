#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi

set -euo pipefail

ORG="elhaus-labs"
LOG_FILE="/var/log/ensure-org-runners.log"
LOCK_FILE="/var/lock/ensure-org-runners.lock"
SCRIPT_VERSION="2026-02-28.4"
BOOTSTRAP_LOG="/mnt/c/scripts/logs/ensure-org-runners-wsl-bootstrap.log"

mkdir -p "$(dirname "$BOOTSTRAP_LOG")" 2>/dev/null || true
printf '%s %s\n' "$(date -Is)" "bootstrap script_version=${SCRIPT_VERSION} path=$0 user=$(id -un 2>/dev/null || echo unknown) uid=$(id -u 2>/dev/null || echo unknown)" >>"$BOOTSTRAP_LOG" 2>/dev/null || true

log() {
	local msg
	msg="$(redact_text "$*")"
	printf '%s %s\n' "$(date -Is)" "$msg" >>"$LOG_FILE"
	printf '%s %s\n' "$(date -Is)" "$msg" >>"$BOOTSTRAP_LOG" 2>/dev/null || true
}

redact_text() {
	local s="$*"
	s="$(printf '%s' "$s" | sed -E \
		-e 's/(Authorization[[:space:]]*:[[:space:]]*Bearer[[:space:]]+)[^[:space:]'"'"']+/\1[REDACTED]/Ig' \
		-e 's/("token"[[:space:]]*:[[:space:]]*")[^"]+/\1[REDACTED]/Ig' \
		-e 's/(--token[[:space:]]+)[^[:space:]'"'"']+/\1[REDACTED]/Ig' \
		-e 's/(GITHUB_PAT=)[^[:space:]'"'"']+/\1[REDACTED]/Ig')"
	printf '%s' "$s"
}

init_paths() {
	local log_dir lock_dir
	log_dir="$(dirname "$LOG_FILE")"
	lock_dir="$(dirname "$LOCK_FILE")"

	if ! mkdir -p "$log_dir" 2>/dev/null || ! touch "$LOG_FILE" 2>/dev/null; then
		LOG_FILE="/tmp/ensure-org-runners.log"
		mkdir -p "$(dirname "$LOG_FILE")"
		touch "$LOG_FILE"
	fi

	if ! mkdir -p "$lock_dir" 2>/dev/null; then
		LOCK_FILE="/tmp/ensure-org-runners.lock"
	fi
}

init_paths

trap 'rc=$?; log "FATAL rc=${rc} line=${LINENO}"; exit $rc' ERR

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
	log "Another instance is running. Exiting."
	exit 0
fi

load_pat() {
	if [[ -n "${GITHUB_PAT:-}" ]]; then
		return 0
	fi

	if [[ -f /etc/profile.d/github_pat.sh ]]; then
		# shellcheck disable=SC1091
		source /etc/profile.d/github_pat.sh || true
	fi

	if [[ -z "${GITHUB_PAT:-}" ]] && [[ -f /etc/environment ]]; then
		local line
		line="$(grep -E '^GITHUB_PAT=' /etc/environment | tail -n1 || true)"
		if [[ -n "$line" ]]; then
			line="${line#GITHUB_PAT=}"
			line="${line%\"}"
			line="${line#\"}"
			export GITHUB_PAT="$line"
		fi
	fi
}

load_pat

if [[ -z "${GITHUB_PAT:-}" ]]; then
	log "PAT missing: GITHUB_PAT is not set in environment/profile.d/environment."
	exit 1
fi

require_cmd() {
	local cmd="$1"
	if ! command -v "$cmd" >/dev/null 2>&1; then
		log "Missing dependency: ${cmd}"
		exit 1
	fi
}

require_cmd bash
require_cmd curl
require_cmd python3
require_cmd flock
require_cmd mktemp
require_cmd awk
require_cmd sed
require_cmd tr
require_cmd ps

log "ScriptVersion=${SCRIPT_VERSION} ScriptPath=$0 User=$(id -un) UID=$(id -u)"

body_snippet_file() {
	local file="$1"
	if [[ ! -s "$file" ]]; then
		return 0
	fi
	sed -e 's/[\r\n\t]/ /g' "$file" | head -c 400 | redact_text
}

classify_http_root_cause() {
	local http_code="$1"
	local content_type="$2"
	local body_snippet="$3"
	local text
	text="$(printf '%s %s' "$content_type" "$body_snippet" | tr '[:upper:]' '[:lower:]')"

	if [[ "$http_code" == "401" ]]; then
		printf '%s' "auth.invalid_or_expired_token"
		return 0
	fi

	if [[ "$http_code" == "403" ]]; then
		if grep -Eqi 'sso|saml' <<<"$text"; then
			printf '%s' "auth.sso_not_authorized"
			return 0
		fi
		if grep -Eqi 'resource not accessible|insufficient|permission|forbidden' <<<"$text"; then
			printf '%s' "auth.missing_org_permission"
			return 0
		fi
		printf '%s' "auth.access_forbidden"
		return 0
	fi

	if [[ "$http_code" == "429" ]]; then
		printf '%s' "api.rate_limited"
		return 0
	fi

	if [[ "$http_code" -ge 500 && "$http_code" -le 599 ]]; then
		printf '%s' "api.server_error"
		return 0
	fi

	if grep -Eqi '^text/html' <<<"$text"; then
		printf '%s' "network.proxy_or_tls_intercept_html_response"
		return 0
	fi
	if grep -Eqi 'proxy' <<<"$text"; then
		printf '%s' "network.proxy_error"
		return 0
	fi
	if grep -Eqi 'ssl|tls|certificate|handshake|trust' <<<"$text"; then
		printf '%s' "network.tls_error"
		return 0
	fi
	if grep -Eqi 'name resolution|dns|could not resolve|no such host' <<<"$text"; then
		printf '%s' "network.dns_error"
		return 0
	fi
	if grep -Eqi 'timed out|timeout' <<<"$text"; then
		printf '%s' "network.timeout"
		return 0
	fi

	printf '%s' "unknown"
}

classify_curl_root_cause() {
	local curl_status="$1"
	case "$curl_status" in
	5) printf '%s' "network.proxy_error" ;;
	6) printf '%s' "network.dns_error" ;;
	7) printf '%s' "network.connect_error" ;;
	28) printf '%s' "network.timeout" ;;
	35|51|58|59|60|77|83|90|91) printf '%s' "network.tls_error" ;;
	*) printf '%s' "network.curl_exit_${curl_status}" ;;
	esac
}

api_call() {
	local method="$1"
	local url="$2"

	local max_attempts=6
	local attempt=1

	while (( attempt <= max_attempts )); do
		local headers body http_code retry_after delay content_type body_snip root_cause

		headers="$(mktemp)"
		body="$(mktemp)"

		set +e
		curl -sS --connect-timeout 10 --max-time 30 -D "$headers" -o "$body" -X "$method" \
			-H "Authorization: Bearer ${GITHUB_PAT}" \
			-H "Accept: application/vnd.github+json" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			-H "User-Agent: ensure-org-runners" \
			"$url"
		local curl_status=$?
		set -e

		if (( curl_status != 0 )); then
			root_cause="$(classify_curl_root_cause "$curl_status")"
			delay=$(( attempt < 6 ? 2**attempt : 60 ))
			log "GitHub request exception transient method=${method} url=${url} http_status=0 content_type='' root_cause=${root_cause} retry_in=${delay}s attempt=${attempt}/${max_attempts} error='curl exit ${curl_status}' body_snippet=''"
			rm -f "$headers" "$body"
			sleep "$delay"
			(( attempt++ ))
			continue
		fi

		# Accept both "HTTP/1.1 200" and "HTTP/2 200" status lines.
		http_code="$(awk '/^HTTP\//{code=$2} END{print code+0}' "$headers")"
		content_type="$(awk -F': ' 'tolower($1)=="content-type"{gsub("\r","",$2); ct=$2} END{print ct}' "$headers")"
		body_snip="$(body_snippet_file "$body")"

		if [[ "$http_code" -ge 200 && "$http_code" -le 299 ]]; then
			cat "$body"
			rm -f "$headers" "$body"
			return 0
		fi

		retry_after="$(awk -F': ' 'tolower($1)=="retry-after"{gsub("\r","",$2); print $2}' "$headers" | tail -n1)"
		root_cause="$(classify_http_root_cause "$http_code" "$content_type" "$body_snip")"

		if [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
			log "GitHub auth/access error method=${method} url=${url} http_status=${http_code} content_type='${content_type}' root_cause=${root_cause} body_snippet='${body_snip}'"
			rm -f "$headers" "$body"
			return 1
		fi

		if [[ "$http_code" == "429" || ( "$http_code" -ge 500 && "$http_code" -le 599 ) ]]; then
			if [[ -n "${retry_after:-}" && "$retry_after" =~ ^[0-9]+$ ]]; then
				delay="$retry_after"
			else
				delay=$(( attempt < 6 ? 2**attempt : 60 ))
				(( delay > 60 )) && delay=60
			fi

			log "GitHub transient error method=${method} url=${url} http_status=${http_code} content_type='${content_type}' root_cause=${root_cause} retry_in=${delay}s attempt=${attempt}/${max_attempts} body_snippet='${body_snip}'"
			rm -f "$headers" "$body"
			sleep "$delay"
			(( attempt++ ))
			continue
		fi

		log "GitHub API error method=${method} url=${url} http_status=${http_code} content_type='${content_type}' root_cause=${root_cause} body_snippet='${body_snip}'"
		rm -f "$headers" "$body"
		return 1
	done

	log "GitHub request exception final method=${method} url=${url} http_status=0 content_type='' root_cause=network.max_retries_exceeded error='Exceeded retries' body_snippet=''"
	return 1
}

get_org_runner_names() {
	local page=1
	local names=()

	while true; do
		local url="https://api.github.com/orgs/${ORG}/actions/runners?per_page=100&page=${page}"
		local json batch count
		local -a batch_names=()

		if ! json="$(api_call GET "$url")"; then
			return 1
		fi

		if ! batch="$(printf '%s' "$json" | python3 -c '
import sys, json
data = json.load(sys.stdin)
if "runners" not in data or not isinstance(data["runners"], list):
    raise SystemExit(2)
for r in data.get("runners", []):
    name = r.get("name")
    if name:
        print(name)
')" ; then
			log "GitHub response parse failure method=GET url=${url} http_status=200 content_type='application/json' root_cause=api.invalid_json_or_shape body_snippet='$(printf '%s' "$json" | tr '\r\n\t' ' ' | head -c 400)'"
			return 1
		fi

		if [[ -n "$batch" ]]; then
			mapfile -t batch_names <<<"$batch"
			names+=("${batch_names[@]}")
		fi

		if ! count="$(printf '%s' "$json" | python3 -c '
import sys, json
data = json.load(sys.stdin)
if "runners" not in data or not isinstance(data["runners"], list):
    raise SystemExit(2)
print(len(data.get("runners", [])))
')" ; then
			log "GitHub response parse failure method=GET url=${url} http_status=200 content_type='application/json' root_cause=api.invalid_json_or_shape body_snippet='$(printf '%s' "$json" | tr '\r\n\t' ' ' | head -c 400)'"
			return 1
		fi

		if [[ "$count" -lt 100 ]]; then
			break
		fi

		(( page++ ))
	done

	if (( ${#names[@]} > 0 )); then
		printf '%s\n' "${names[@]}"
	fi
}

REG_TOKEN=""
get_registration_token_cached() {
	if [[ -n "$REG_TOKEN" ]]; then
		printf '%s' "$REG_TOKEN"
		return 0
	fi

	local url="https://api.github.com/orgs/${ORG}/actions/runners/registration-token"
	local json

	if ! json="$(api_call POST "$url")"; then
		return 1
	fi

	if ! REG_TOKEN="$(printf '%s' "$json" | python3 -c '
import sys, json
data = json.load(sys.stdin)
token = data.get("token")
if not token or not isinstance(token, str):
    raise SystemExit(2)
print(token)
')"; then
		log "GitHub response parse failure method=POST url=${url} http_status=200 content_type='application/json' root_cause=api.invalid_json_or_shape body_snippet='$(printf '%s' "$json" | tr '\r\n\t' ' ' | head -c 400)'"
		return 1
	fi

	printf '%s' "$REG_TOKEN"
}

REMOVE_TOKEN=""
get_remove_token_cached() {
	if [[ -n "$REMOVE_TOKEN" ]]; then
		printf '%s' "$REMOVE_TOKEN"
		return 0
	fi

	local url="https://api.github.com/orgs/${ORG}/actions/runners/remove-token"
	local json

	if ! json="$(api_call POST "$url")"; then
		return 1
	fi

	if ! REMOVE_TOKEN="$(printf '%s' "$json" | python3 -c '
import sys, json
data = json.load(sys.stdin)
token = data.get("token")
if not token or not isinstance(token, str):
    raise SystemExit(2)
print(token)
')"; then
		log "GitHub response parse failure method=POST url=${url} http_status=200 content_type='application/json' root_cause=api.invalid_json_or_shape body_snippet='$(printf '%s' "$json" | tr '\r\n\t' ' ' | head -c 400)'"
		return 1
	fi

	printf '%s' "$REMOVE_TOKEN"
}

runner_listener_running() {
	local runner_root="$1"
	local expected="${runner_root}/bin/Runner.Listener"
	ps -eo args= | grep -F -- "$expected" | grep -v -F -- "grep" >/dev/null 2>&1
}

ensure_runner_started() {
	local runner_name="$1"
	local runner_root="$2"

	local svc_sh="${runner_root}/svc.sh"
	if [[ -f "$svc_sh" ]]; then
		if ! bash "$svc_sh" start >>"$LOG_FILE" 2>&1; then
			log "Runner '${runner_name}': service start failed; attempting install+start."
			bash "$svc_sh" install >>"$LOG_FILE" 2>&1 || true
			bash "$svc_sh" start >>"$LOG_FILE" 2>&1 || true
		fi
	fi

	if [[ -f "${runner_root}/.service" ]] && command -v systemctl >/dev/null 2>&1; then
		local service_name
		service_name="$(tr -d '\r\n' < "${runner_root}/.service" || true)"
		if [[ -n "$service_name" ]]; then
			if systemctl is-active --quiet "$service_name" 2>/dev/null; then
				log "Runner '${runner_name}': service '${service_name}' is running."
				return 0
			fi
			log "Runner '${runner_name}': service '${service_name}' not active after start attempts."
		fi
	fi

	local run_sh="${runner_root}/run.sh"
	if [[ -f "$run_sh" ]]; then
		nohup bash "$run_sh" >>"$LOG_FILE" 2>&1 &
		sleep 2
		if runner_listener_running "$runner_root"; then
			log "Runner '${runner_name}': started via run.sh fallback."
			return 0
		fi
		log "Runner '${runner_name}': run.sh fallback launched but listener process not detected."
	fi

	log "Runner '${runner_name}': failed to start runner process/service."
	return 1
}

resolve_runner_root() {
	local mount="$1"

	if [[ -f "${mount}/config.sh" ]]; then
		printf '%s' "$mount"
		return 0
	fi

	for d in "${mount}"/*; do
		if [[ -d "$d" && -f "${d}/config.sh" ]]; then
			printf '%s' "$d"
			return 0
		fi
	done

	return 1
}

ensure_runner() {
	local runner_name="$1"
	local mount="$2"

	local runner_root
	if ! runner_root="$(resolve_runner_root "$mount")"; then
		log "Runner '${runner_name}': config.sh not found under ${mount}"
		return 1
	fi

	if grep -qx "${runner_name}" <<<"${ORG_RUNNERS}"; then
		log "Runner '${runner_name}' exists in org. Ensuring service is started."
		ensure_runner_started "$runner_name" "$runner_root"
		return $?
	fi

	local token
	if ! token="$(get_registration_token_cached)"; then
		log "Runner '${runner_name}': failed to obtain registration token."
		return 1
	fi

	log "Runner '${runner_name}' missing in org. Re-registering in-place."

	pushd "${runner_root}" >/dev/null
	if ! bash "./config.sh" \
		--url "https://github.com/${ORG}" \
		--token "${token}" \
		--unattended \
		--name "${runner_name}" \
		--work "_work" \
		--replace >>"$LOG_FILE" 2>&1; then
		log "Runner '${runner_name}': config.sh failed. Attempting local remove + re-register."
		local remove_token
		if remove_token="$(get_remove_token_cached)"; then
			bash "./config.sh" remove --unattended --token "${remove_token}" >>"$LOG_FILE" 2>&1 || true
		else
			log "Runner '${runner_name}': failed to obtain remove token."
		fi

		if ! bash "./config.sh" \
			--url "https://github.com/${ORG}" \
			--token "${token}" \
			--unattended \
			--name "${runner_name}" \
			--work "_work" \
			--replace >>"$LOG_FILE" 2>&1; then
			log "Runner '${runner_name}': config.sh retry failed."
			popd >/dev/null
			return 1
		fi
	fi

	if ! ensure_runner_started "$runner_name" "$runner_root"; then
		popd >/dev/null
		return 1
	fi

	popd >/dev/null
	return 0
}

log "Starting reconciliation for org=${ORG}"

if ! ORG_RUNNERS="$(get_org_runner_names)"; then
	log "Failed to retrieve org runners list. Aborting."
	exit 1
fi

log "Org runners:"
printf '%s\n' "$ORG_RUNNERS" | sed 's/^/  - /' >>"$LOG_FILE"

overall_status=0
ensure_runner "NUC-LINUX-3" "/mnt/f" || overall_status=1
ensure_runner "NUC-LINUX-4" "/mnt/g" || overall_status=1
ensure_runner "NUC-LINUX-5" "/mnt/h" || overall_status=1

if (( overall_status != 0 )); then
	log "Completed with errors."
	exit 1
fi

log "Done."
exit 0
