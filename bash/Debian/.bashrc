# ==============================================================================
# BASH Config [Debian]
# Public Domain, 2026 — Philipp Elhaus
# ==============================================================================

case $- in
	*i*) ;;
	*) return ;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

shopt -s histappend
shopt -s checkwinsize

if [ -x /usr/bin/lesspipe ]; then
	eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"
fi

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
	debian_chroot=$(< /etc/debian_chroot)
fi

if command -v tput >/dev/null 2>&1 &&
	[ "${TERM:-dumb}" != dumb ] &&
	tput setaf 1 >/dev/null 2>&1; then
	if [ "$(id -u)" -eq 0 ]; then
		PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@\[\033[00m\] \[\033[01;35m\]\w\[\033[00m\]# "
	else
		PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@\[\033[00m\] \[\033[01;35m\]\w\[\033[00m\]\$ "
	fi
else
	PS1="${debian_chroot:+($debian_chroot)}\u@\h \@ \w\\$ "
fi

if command -v dircolors >/dev/null 2>&1; then
	if [ -r "$HOME/.dircolors" ]; then
		eval "$(dircolors -b "$HOME/.dircolors")"
	else
		eval "$(dircolors -b)"
	fi
	alias ls='ls --color=auto'
	alias dir='ls -alhS --color=auto --group-directories-first'
	alias vdir='vdir --color=auto'
	alias grep='grep --color=auto'
	alias fgrep='grep -F --color=auto'
	alias egrep='grep -E --color=auto'
fi

for custom_name in \
	upgrade services status restart proc ports search route \
	df du pushd netstat tree; do
	unalias "$custom_name" 2>/dev/null || true
done
unset custom_name

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

ll() {
	local -a ls_cmd=(ls -aldhF --color=auto)
	local entry

	while IFS= read -r -d '' entry; do
		"${ls_cmd[@]}" -- "${entry#./}"
	done < <(find . -mindepth 1 -maxdepth 1 -type d -print0 | LC_ALL=C sort -z)
	while IFS= read -r -d '' entry; do
		"${ls_cmd[@]}" -- "${entry#./}"
	done < <(find . -mindepth 1 -maxdepth 1 -type l -print0 | LC_ALL=C sort -z)
	while IFS= read -r -d '' entry; do
		"${ls_cmd[@]}" -- "${entry#./}"
	done < <(find . -mindepth 1 -maxdepth 1 ! -type d ! -type l -print0 | LC_ALL=C sort -z)
}

alias la='ls -A'
alias l='ls -CF'
alias dc='cd'
alias st='status'
alias hi='history'
alias copy='cp'
if command -v nano >/dev/null 2>&1; then
	alias nano='nano --linenumbers'
fi
if command -v dpkg-query >/dev/null 2>&1; then
	alias list='dpkg-query -W -f="${binary:Package}\t${db:Status-Abbrev}\n"'
fi

cls() {
	command clear -x 2>/dev/null || printf '\033c'
}

hex() {
	if command -v xxd >/dev/null 2>&1; then
		command xxd "$@"
	else
		command od -Ax -tx1z "$@"
	fi
}

ips() {
	ip -brief -4 address show | awk '$1 != "lo" { print $1, $3 }'
}

nameserver() {
	awk '$1 == "nameserver" { print $2 }' /etc/resolv.conf
}

gateway() {
	ip -4 route show default
}

net() {
	printf '%s\n' '--- Addresses ---'
	ips
	printf '%s\n' '--- Name servers ---'
	nameserver
	printf '%s\n' '--- Default route ---'
	gateway
}

linux() {
	if [ -r /etc/os-release ]; then
		(
			. /etc/os-release
			printf '%s\n' "${PRETTY_NAME:-${NAME:-Debian}}"
		)
	else
		uname -sr
	fi
}

as_root() {
	if [ "$EUID" -eq 0 ]; then
		command "$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo -- "$@"
	else
		echo "Root privileges are required and sudo is unavailable." >&2
		return 1
	fi
}

clean() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: clean <file>" >&2
		return 1
	fi
	if [ ! -f "$1" ]; then
		echo "File not found: $1" >&2
		return 1
	fi
	: >"$1"
	echo "Cleaned: $1"
}

validate() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: validate <file.json>" >&2
		return 1
	fi
	if [ ! -f "$1" ]; then
		echo "File not found: $1" >&2
		return 1
	fi
	if command -v jq >/dev/null 2>&1; then
		jq empty -- "$1"
	elif command -v python3 >/dev/null 2>&1; then
		python3 -m json.tool "$1" >/dev/null
	else
		echo "JSON validation requires jq or python3." >&2
		return 127
	fi
}

cleanup() {
	local -a residual=()

	if ! command -v apt-get >/dev/null 2>&1; then
		echo "cleanup requires apt-get." >&2
		return 127
	fi
	as_root apt-get autoremove || return
	mapfile -t residual < <(
		dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null |
			awk '$1 == "rc" { print $2 }'
	)
	if [ "${#residual[@]}" -gt 0 ]; then
		as_root dpkg --purge "${residual[@]}"
	fi
}

remove() {
	local answer

	if [ "$#" -eq 0 ]; then
		echo "Usage: remove <package> [...]" >&2
		return 1
	fi
	read -r -p "Remove the package(s) and related data (Y/N): " answer
	if [ "${answer^^}" != Y ]; then
		return 0
	fi
	as_root apt-get remove --purge -- "$@" &&
		as_root apt-get autoremove
}

services() {
	systemctl list-units \
		--type=service --all --no-pager --plain --legend=no |
		awk '{
			state = ($4 == "running") ? "[ + ]" : "[ - ]"
			name = $1
			sub(/\.service$/, "", name)
			printf " %s  %s\n", state, name
		}' |
		LC_ALL=C sort -k2
}

status() {
	local unit pid

	if [ "$#" -ne 1 ]; then
		echo "Usage: status <service>" >&2
		return 1
	fi
	unit=$1
	[[ $unit == *.service ]] || unit+=.service
	if [ "$(systemctl show -p LoadState --value "$unit" 2>/dev/null)" != loaded ]; then
		echo "Service $unit does not exist." >&2
		return 1
	fi
	pid=$(systemctl show -p MainPID --value "$unit")
	if [[ $pid =~ ^[1-9][0-9]*$ ]] && command -v lsof >/dev/null 2>&1; then
		printf '%s\n' '--- Listening ports ---'
		as_root lsof -Pan -p "$pid" -i 2>/dev/null || true
	fi
	systemctl status --no-pager "$unit"
}

restart() {
	local unit

	if [ "$#" -ne 1 ]; then
		echo "Usage: restart <service>" >&2
		return 1
	fi
	unit=$1
	[[ $unit == *.service ]] || unit+=.service
	as_root systemctl restart "$unit" &&
		systemctl is-active --quiet "$unit"
}

proc() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: proc <process-pattern>" >&2
		return 1
	fi
	pgrep -af -- "$1" || {
		echo "No processes found for: $1"
		return 1
	}
}

ports() {
	local pids

	if [ "$#" -gt 1 ]; then
		echo "Usage: ports [process-pattern]" >&2
		return 1
	fi
	if [ "$#" -eq 0 ]; then
		as_root ss -lntup
		return
	fi
	if ! command -v lsof >/dev/null 2>&1; then
		echo "Filtered port lookup requires lsof." >&2
		return 127
	fi
	pids=$(pgrep -d, -f -- "$1")
	if [ -z "$pids" ]; then
		echo "No processes found for: $1"
		return 1
	fi
	as_root lsof -Pan -i -a -p "$pids"
}

search() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: search <name-pattern>" >&2
		return 1
	fi
	find / -iname "$1" -printf '%y:%p\n' 2>/dev/null |
		LC_ALL=C sort -t: -k1,1 -k2,2
}

string() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: string <pattern>" >&2
		return 1
	fi
	find . -type f -exec grep -nH -a -- "$1" {} + 2>/dev/null
}

users() {
	if [ "${1:-}" = "?" ]; then
		cut -d: -f1 /etc/passwd | LC_ALL=C sort
		echo "--- Active ---"
		{ who | awk '{print $1}'; whoami; } | LC_ALL=C sort -u
	else
		command users "$@"
	fi
}

route() {
	if [ "$#" -eq 0 ]; then
		ip -4 route
	else
		ip route "$@"
	fi
}

df() {
	if [ "$#" -eq 0 ]; then
		command df -h
	else
		command df "$@"
	fi
}

du() {
	if [ "$#" -eq 0 ]; then
		command du -sh .
	else
		command du "$@"
	fi
}

pushd() {
	if [ "$#" -eq 0 ]; then
		builtin pushd .
	else
		builtin pushd "$@"
	fi
}

netstat() {
	if [ "$#" -eq 0 ]; then
		as_root ss -lntup
	else
		command ss "$@"
	fi
}

tree() {
	local depth=${1:-1}

	if type -P tree >/dev/null 2>&1; then
		if [ "$#" -eq 0 ]; then
			command tree -L 1 --dirsfirst -d --noreport
		elif [ "$#" -eq 1 ] && [[ $1 =~ ^[0-9]+$ ]]; then
			command tree -L "$1" --dirsfirst -d --noreport
		else
			command tree "$@"
		fi
		return
	fi
	if [ "$#" -gt 1 ] || ! [[ $depth =~ ^[0-9]+$ ]]; then
		echo "Usage without the tree package: tree [depth]" >&2
		return 1
	fi
	find . -maxdepth "$depth" -type d -print | LC_ALL=C sort
}

if ! shopt -oq posix; then
	if [ -r /usr/share/bash-completion/bash_completion ]; then
		. /usr/share/bash-completion/bash_completion
	elif [ -r /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
fi

echo
echo "Bash Terminal [Debian]"
echo "  cleanup   remove   services   status   restart"
echo "  proc      ports    search     string   users"
echo "  route     df       du         pushd    netstat   tree"
echo
