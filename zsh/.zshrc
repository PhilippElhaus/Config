# ==============================================================================
# ZSH Config [Apple]
# Public Domain, 2026 — Philipp Elhaus
# ==============================================================================

autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit

HISTSIZE=1000
SAVEHIST=2000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt APPEND_HISTORY

PROMPT='%F{green}%n@%m%f %F{blue}%* %F{magenta}%~ %f$ '

export CLICOLOR=1
alias ls='ls -G'
alias grep='grep --color=auto'

alias la='ls -A'
alias ll='ls -lahr'
alias l='ls -CF'
alias cls='clear'
alias hex='xxd'
alias dc='cd'
alias hi='history'
alias copy='cp'

alias ips="ifconfig | grep -w inet | grep -v 127.0.0.1 | awk '{print \$2}'"
alias nameserver="networksetup -getdnsservers Wi-Fi 2>/dev/null || cat /etc/resolv.conf"
alias ns='nameserver'
alias gateway="netstat -nr | grep default | awk '{print \$2}' | head -n 1"
alias gw='gateway'
alias net='ips; nameserver; gateway'

df() { [ "$#" -eq 0 ] && command df -h || command df "$@"; }
du() { [ "$#" -eq 0 ] && command du -sh || command du "$@"; }

validate() {
    if [ -z "$1" ]; then
        echo "ERROR: missing file argument"
        echo "Usage: validate <file.json>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "ERROR: file not found: $1"
        return 1
    fi

    local err
    err=$(jq empty "$1" 2>&1 >/dev/null)

    if [ $? -eq 0 ]; then
        echo "OK     $1 is valid JSON"
        return 0
    else
        echo "FAIL   $1 is invalid JSON"
        echo "------"
        echo "$err"
        echo "------"
        return 1
    fi
}

proc() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: proc <process_name>"
        return 1
    fi
    echo -e "\033[31m---\033[0m PIDs containing '$1' \033[31m---\033[0m"
    ps aux | grep -i "$1" | grep -v grep | awk '{print $2, $11}'
}

search() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: search <filename>"
        return 1
    fi
    echo "Searching..."
    find . -iname "*$1*" 2>/dev/null
}

string() {
    if [ "$#" -eq 1 ]; then
        grep -rnI "$1" . 2>/dev/null
    else
        echo "Usage: string <pattern>"
    fi
}

tree() {
    if command -v tree >/dev/null 2>&1; then
        command tree "$@"
    else
        find . -maxdepth 2 -not -path '*/.*'
    fi
}

if [[ -o interactive ]]; then
    echo "ZShell Terminal Ready"
    echo "Commands: proc, search, string, net, hi, cls"
fi