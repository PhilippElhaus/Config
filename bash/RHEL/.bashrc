# ==============================================================================
# BASH Config [RHEL]
# Public Domain, 2025 — Philipp Elhaus
# ==============================================================================

case $- in
	*i*) ;;
	*) return;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

shopt -s histappend
shopt -s checkwinsize

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
	debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
	xterm-color|*-256color) color_prompt=yes;;
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
	PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@ \[\033[01;35m\]\w \[\033[00m\]# "
else
	PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@ \[\033[01;35m\]\w \[\033[00m\]$ "
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

ll() {
	local -a ls_cmd=(ls -aldhF --color=auto)

	find . -mindepth 1 -maxdepth 1 -type d -printf '%p\0' | sort -z | sed -z 's#^\./##' | xargs -0r "${ls_cmd[@]}"
	find . -mindepth 1 -maxdepth 1 -type l -printf '%p\0' | sort -z | sed -z 's#^\./##' | xargs -0r "${ls_cmd[@]}"
	find . -mindepth 1 -maxdepth 1 ! -type d ! -type l -printf '%p\0' | sort -z | sed -z 's#^\./##' | xargs -0r "${ls_cmd[@]}"
}
alias la='ls -A'
alias l='ls -CF'
alias cls='clear -x'
alias nano='nano --linenumbers'
alias list='dpkg --get-selections | grep -i'
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
alias linux='lsb_release -s -d'

if ! command -v clear >/dev/null 2>&1; then
	clear() { printf '\033c'; }
fi
alias cls='clear'

if command -v lsb_release >/dev/null 2>&1 && [ "$(lsb_release -si)" = "Debian" ]; then
	alias su='su --login'
	alias sudo=''
fi

# Default to /work for interactive shells in the lab containers.
if [ -d /work ] && [ "$PWD" = "$HOME" ]; then
	cd /work
fi

cleanup() {
	if [ "$EUID" -ne 0 ]; then
		echo "You need to be root."
		return
	fi
	apt autoremove
	dpkg --get-selections | grep -E 'deinstall$' | cut -f1 | while read -r p; do dpkg --purge "$p" 2>/dev/null; done
	dpkg --purge $(dpkg -l | grep ^rc | awk '{print $2}') 2>/dev/null
	echo "Done."
}

remove() {
	if [ "$#" -eq 0 ]; then
		echo "Usage: remove <package1> [...]"
		return 1
	fi
	if [ "$EUID" -ne 0 ]; then
		echo "You need to be root."
		return
	fi
	local c
	read -p "Wipe the package(s) and related data (Y/N): " c
	if [ "${c^^}" = "Y" ]; then
		apt remove -y "$@" 2>/dev/null && apt autoremove || echo "No such package."
		dpkg --get-selections | grep -E 'deinstall$' | cut -f1 | while read -r p; do dpkg --purge "$p" 2>/dev/null; done
		dpkg --purge $(dpkg -l | grep ^rc | awk '{print $2}') 2>/dev/null
	fi
}

services() {
	local sysv_services sysv_up sysv_down systemd_up combined sorted filtered
	systemd_up=$(systemctl list-units --type=service --state=running --no-pager --plain --quiet | awk '{gsub(".service$", "", $1); print " [ + ]  " $1}')
	sysv_services=$(service --status-all 2>/dev/null)
	sysv_up=$(echo "$sysv_services" | grep " \[ + \]" || true)
	sysv_down=$(echo "$sysv_services" | grep " \[ - \]" || true)
	combined="$sysv_up\n$systemd_up\n"
	sorted=$(echo -e "$combined" | tr '\n' '\0' | sort -z | tr '\0' '\n')
	filtered=$(echo -e "$sorted" | uniq)
	echo -e "$filtered\n---\n$sysv_down\n"
}

status() {
	if [ -z "$1" ]; then
		echo "Usage: status <service>"
		return 1
	fi
	local serviceName="$1" processName="$1"
	[ "$serviceName" = "postgresql" ] && processName="postgre"
	if ! systemctl list-units --type service --all | awk '{print $1}' | grep -q "\<$serviceName\>"; then
		echo "Service $serviceName does not exist."
		return 1
	fi
	echo -e "\e[31m---\e[0m Ports \e[31m---\e[0m"
	netstat -tulnp | grep "$processName" | awk '{sub(/.*:/,"",$4); print $1 " " $4}'
	echo -e "\e[31m---\e[0m End \e[31m---\e[0m"
	service "$serviceName" status
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
	local name="$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"
	if ! service --status-all 2>/dev/null | grep -Fq "$1"; then
		echo "Service $name does not exist."
		return
	fi
	if service "$1" restart >/dev/null 2>&1; then
		echo -e "\e[32mSuccess: $name\e[0m"
	else
		echo -e "\e[31mFailure: $name\e[0m"
	fi
}

proc() {
	if [ "$#" -ne 1 ]; then
		echo "Usage: proc <process>"
		return 1
	fi
	local pids
	pids=$(ps aux | grep "$1" | grep -v grep | awk '{print $2, $11}')
	if [ -z "$pids" ]; then
		echo "No PID's found for $1"
	else
		echo -e "\e[31m---\e[0m PID's containing '$1' \e[31m---\e[0m"
		echo "$pids"
		echo -e "\e[31m---\e[0m End \e[31m---\e[0m"
	fi
}

ports() {
	if [ "$#" -gt 1 ]; then
		echo "Usage: ports <process>"
		return 1
	fi
	if [ "$#" -eq 0 ]; then
		nmap --top-ports 65535 localhost | grep --color=never '^[0-9]'
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
	sudo lsof -i -P -n -a -p "$(echo "$pids" | tr ' ' ',')" |
		awk 'NR>1{split($9, parts, ":"); printf "%s | %s : %s | %s | %s\n", $1, $2, $5, $8, parts[2]}'
}

search() {
	if [ "$#" -eq 0 ]; then
		echo "Usage: search <file>"
		return 1
	fi
	echo "Searching..."
	find / -iname "$1" 2>/dev/null | while read -r f; do
		if [ -d "$f" ]; then printf "D:\033[34m%s\033[0m\n" "$f"
		elif [ -x "$f" ]; then printf "E:\033[92m%s\033[0m\n" "$f"
		elif [ -f "$f" ]; then printf "F:%s\n" "$f"
		elif [ -L "$f" ]; then printf "L:\033[94m%s\033[0m\n" "$f"
		else printf "O:\033[33m%s\033[0m\n" "$f"
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

route() { [ "$#" -eq 0 ] && command route -n || command route "$@"; }
df()    { [ "$#" -eq 0 ] && command df -h   || command df "$@"; }
du()    { [ "$#" -eq 0 ] && command du -sh  || command du "$@"; }
pushd() { [ "$#" -eq 0 ] && command pushd . || command pushd "$@"; }
netstat(){ [ "$#" -eq 0 ] && command netstat -tulnp4 || command netstat "$@"; }

tree() {
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
	echo "  cleanup   remove   services   status   restart"
	echo "  proc      ports    search     string    users"
	echo "  route     df       du         pushd     netstat   tree"
	echo
fi
