# ==============================================================================
# BASH Config [RedHat Enterprise Linux]
# Public Domain, 2025 — Philipp Elhaus
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

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

chroot_name="rhel"

if [ -f /.dockerenv ] || grep -qa container= /proc/1/environ 2>/dev/null; then
	chroot_name="cntr"
fi

case "$TERM" in
	xterm-color|*-256color) color_prompt=yes ;;
esac

if [ -n "$force_color_prompt" ]; then
	if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
		color_prompt=yes
	else
		color_prompt=
	fi
fi

unset color_prompt force_color_prompt

if [ "$(id -u)" -eq 0 ]; then
	PS1="\[\e]0;\u@\h: \w\a\]${chroot_name:+($chroot_name)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@ \[\033[01;35m\]\w \[\033[00m\]# "
else
	PS1="\[\e]0;\u@\h: \w\a\]${chroot_name:+($chroot_name)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@ \[\033[01;35m\]\w \[\033[00m\]$ "
fi

if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias dir='ls -alhS --color=auto --group-directories-first'
	alias vdir='vdir --color=auto'
	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

unalias upgrade 2>/dev/null
unalias services 2>/dev/null
unalias status 2>/dev/null
unalias proc 2>/dev/null
unalias search 2>/dev/null
unalias route 2>/dev/null
unalias df 2>/dev/null
unalias du 2>/dev/null
unalias pushd 2>/dev/null
unalias tree 2>/dev/null

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias ll='ls -alhF'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear -x'
alias nano='nano --linenumbers'
alias hex='xxd'
alias dc='cd'
alias st='status'
alias hi='history'
alias copy='cp'

alias ips="ip addr show | awk '/inet / {print \$2}' | cut -d' ' -f1"
alias nameserver="grep '^nameserver' /etc/resolv.conf | awk '{print}'"
alias ns='nameserver'
alias gateway="ip route | awk '/default/ {print \$3}' | cut -d' ' -f1-3"
alias gw='gateway'
alias net='ips; nameserver; gateway'

alias list='rpm -qa | sort'

if command -v rpm >/dev/null 2>&1; then
	alias linux="rpm -q --whatprovides redhat-release --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' 2>/dev/null || cat /etc/redhat-release 2>/dev/null"
else
	alias linux='cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION)="'
fi

cleanup() {
	if [ "$EUID" -ne 0 ]; then
		echo "You need to be root."
		return
	fi

	if command -v dnf >/dev/null 2>&1; then
		dnf -y autoremove || true
		dnf -y clean all || true
		echo "Done."
		return
	fi

	if command -v microdnf >/dev/null 2>&1; then
		microdnf -y remove --allowerasing || true
		microdnf -y clean all || true
		echo "Done."
		return
	fi

	echo "No dnf/microdnf found."
}

remove() {
	if [ "$#" -eq 0 ]; then
		echo "Usage: remove <package> [...]"
		return 1
	fi
	if [ "$EUID" -ne 0 ]; then
		echo "You need to be root."
		return
	fi

	local c
	read -r -p "Wipe the package(s) and related data (Y/N): " c
	if [ "${c^^}" != "Y" ]; then
		return
	fi

	if command -v dnf >/dev/null 2>&1; then
		dnf -y remove "$@" || { echo "No such package(s)."; return 1; }
		dnf -y autoremove || true
		dnf -y clean all || true
		return
	fi

	if command -v microdnf >/dev/null 2>&1; then
		microdnf -y remove "$@" || { echo "No such package(s)."; return 1; }
		microdnf -y clean all || true
		return
	fi

	echo "No dnf/microdnf found."
	return 1
}

services() {
	if command -v systemctl >/dev/null 2>&1; then
		systemctl list-units --type=service --all --no-pager --plain | \
			awk 'NR>1 && $1 ~ /\.service$/ {gsub(".service$","",$1); print $1 "\t" $3 "\t" $4}' | \
			sort
		return
	fi
	echo "systemctl not found."
}

status() {
	if [ -z "$1" ]; then
		echo "Usage: status <service>"
		return 1
	fi

	local serviceName="$1"

	if ! command -v systemctl >/dev/null 2>&1; then
		echo "systemctl not found."
		return 1
	fi

	if ! systemctl list-unit-files --type=service --no-pager | awk '{print $1}' | grep -q "^${serviceName}\.service$"; then
		echo "Service $serviceName does not exist."
		return 1
	fi

	echo "--- Ports ---"
	if command -v ss >/dev/null 2>&1; then
		ss -ltnup 2>/dev/null | grep -i --color=never "$serviceName" || true
	else
		echo "ss not found (install iproute)."
	fi
	echo "--- End ---"

	systemctl status --no-pager "$serviceName"
}

restart() {
	if [ -z "$1" ]; then
		echo "Usage: restart <service>"
		return
	fi
	if [ "$EUID" -ne 0 ]; then
		echo "You need to be root."
		return
	fi

	if ! command -v systemctl >/dev/null 2>&1; then
		echo "systemctl not found."
		return 1
	fi

	if systemctl restart "$1" >/dev/null 2>&1; then
		echo "Success: $1"
	else
		echo "Failure: $1"
	fi
}

proc() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: proc <pattern>"
		return 1
	fi

	local pids
	pids=$(ps aux | grep "$1" | grep -v grep | awk '{print $2, $11}')
	if [ -z "$pids" ]; then
		echo "No PID's found for $1"
	else
		echo "--- PID's containing '$1' ---"
		echo "$pids"
		echo "--- End ---"
	fi
}

ports() {
	if [ "$#" -gt 1 ]; then
		echo "Usage: ports [process]"
		return 1
	fi

	if [ "$#" -eq 0 ]; then
		if command -v ss >/dev/null 2>&1; then
			ss -ltnup
		else
			echo "ss not found (install iproute)."
		fi
		return
	fi

	local pids
	pids=$(pgrep "$1")
	if [ -z "$pids" ]; then
		echo "No processes found for: $1"
		return
	fi

	echo "NAME | PID : TYPE | PROTOCOL | PORT"
	echo "-----------------------------------"

	if command -v lsof >/dev/null 2>&1; then
		sudo lsof -i -P -n -a -p "$(echo "$pids" | tr ' ' ',')" | \
			awk 'NR>1{split($9, parts, ":"); printf "%s | %s : %s | %s | %s\n", $1, $2, $5, $8, parts[2]}'
	else
		echo "lsof not found (dnf install lsof)."
	fi
}

search() {
	if [ "$#" -eq 0 ]; then
		echo "Usage: search <pattern>"
		return 1
	fi

	echo "Searching..."
	find / -iname "$1" 2>/dev/null | while read -r f; do
		if [ -d "$f" ]; then
			printf "D:\033[34m%s\033[0m\n" "$f"
		elif [ -x "$f" ]; then
			printf "E:\033[92m%s\033[0m\n" "$f"
		elif [ -f "$f" ]; then
			printf "F:%s\n" "$f"
		elif [ -L "$f" ]; then
			printf "L:\033[94m%s\033[0m\n" "$f"
		else
			printf "O:\033[33m%s\033[0m\n" "$f"
		fi
	done | sort -t: -k1,1 -k2 | sed 's/^[DEFLFO]://'
	echo "Search done."
}

string() {
	if [ "$#" -eq 1 ]; then
		find . -type f -exec grep -n -H -a "$1" {} + 2>/dev/null
	else
		echo "Usage: string <pattern>"
	fi
}

users() {
	if [ "$1" = "?" ]; then
		cut -d: -f1 /etc/passwd | sort
		echo "--- Active ---"
		{ who | awk '{print $1}'; [ "$(whoami)" = "root" ] && echo "root"; } | sort | uniq | tr '\n' ' '
		echo
	else
		/usr/bin/users "$@"
	fi
}

route() { [ "$#" -eq 0 ] && command ip route || command ip route "$@"; }
df() { [ "$#" -eq 0 ] && command df -h || command df "$@"; }
du() { [ "$#" -eq 0 ] && command du -sh || command du "$@"; }
pushd() { [ "$#" -eq 0 ] && command pushd . || command pushd "$@"; }

netstat() {
	if command -v ss >/dev/null 2>&1; then
		[ "$#" -eq 0 ] && ss -ltnup || ss "$@"
	else
		command netstat "$@"
	fi
}

tree() {
	if ! command -v tree >/dev/null 2>&1; then
		echo "tree not found (dnf install tree)."
		return 1
	fi

	if [ "$#" -eq 0 ]; then
		command tree -L 1 --dirsfirst -d --noreport
	elif [ "$#" -eq 1 ]; then
		command tree -L "$1" --dirsfirst -d --noreport
	else
		command tree "$@"
	fi
}

if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
fi

if [[ $- == *i* ]]; then
	echo
	echo "Custom Commands:"
	echo " cleanup remove services status restart"
	echo " proc ports search string users"
	echo " route df du pushd netstat tree"
	echo
fi
