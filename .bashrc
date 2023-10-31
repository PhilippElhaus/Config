# ~/.bashrc [non-login shells]

case $- in
    *i*) ;;
      *) return;;
esac

# Default

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
PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\@ \[\033[01;35m\]\w \[\033[00m\]$ "

# Alias

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir -alhS --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

unalias upgrade 2> /dev/null
unalias services 2> /dev/null
unalias status 2> /dev/null
unalias proc 2> /dev/null
unalias search 2> /dev/null
unalias route 2> /dev/null
unalias df 2> /dev/null
unalias du 2> /dev/null
unalias pushd 2> /dev/null
unalias tree 2> /dev/null

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear -x'
alias nano='nano --linenumbers'
alias list='dpkg --get-selections'
alias hex='xxd'

alias ips="ip addr show | awk '/inet / {print \$2}' | cut -d' ' -f1"
alias nameserver="grep '^nameserver' /etc/resolv.conf | awk '{print}'"
alias ns='nameserver'
alias gateway="ip route | awk '/default/ {print $3}' | cut -d' ' -f1-3"
alias gw='gateway'
alias net='ips; nameserver; gateway'
alias linux='lsb_release -s -d'

alias install_php='sudo apt -y install php php-{curl,zip,bz2,gd,imagick,intl,apcu,memcache,imap,mysql,cas,ldap,tidy,pear,xmlrpc,pspell,mbstring,json,iconv,xml,gd,xsl}'
alias install_apache='sudo apt -y install apache2 libapache2-mod-{php,ssl,rewrite,headers,proxy,security2,deflate,expires} mod-{cache,gzip,evasive}'

upgrade() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "?" ]; then
    echo "upgrade               # executes the script"
    echo "upgrade arg1          # additional change to hostname in welcome text"
    echo "upgrade arg1 arg2     # additional change to the actual hostname"
    return
  fi

  if [ "$EUID" -ne 0 ]; then
    echo "Superuser priviliges required for execution."
    return
  fi

  echo -e "\e[91m--- Upgrading System ---\e[0m"
  timedatectl set-timezone CET
  adapters=$(ip -o link show | awk -F': ' '{print $2}')
  for adapter in $adapters; do
    if [[ "$adapter" == "eth"* ]] || [[ "$adapter" == "ens"* ]]; then
      sudo ip link set dev "$adapter" mtu 1000
    fi
  done

  if grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
    sudo sed -i 's/net.ipv6.conf.all.disable_ipv6 = 0/net.ipv6.conf.all.disable_ipv6 = 1/g' /etc/sysctl.conf
  else
    echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  fi

  if grep -q "net.ipv6.conf.default.disable_ipv6" /etc/sysctl.conf; then
    sudo sed -i 's/net.ipv6.conf.default.disable_ipv6 = 0/net.ipv6.conf.default.disable_ipv6 = 1/g' /etc/sysctl.conf
  else
    echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  fi

  if grep -q "net.ipv6.conf.lo.disable_ipv6" /etc/sysctl.conf; then
    sudo sed -i 's/net.ipv6.conf.lo.disable_ipv6 = 0/net.ipv6.conf.lo.disable_ipv6 = 1/g' /etc/sysctl.conf
  else
    echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
  fi

  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
  sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

  sudo sysctl -p

  sudo add-apt-repository -y ppa:ondrej/php
  sudo add-apt-repository -y ppa:ondrej/apache2

  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get autoclean
  sudo apt-get -y autoremove

  for package in net-tools curl lsof nano nmap tree unzip; do
    dpkg-query -W --showformat="${Status}" $package | grep -q "installed" || sudo apt-get -y install $package
  done

  sudo curl -o /root/.bashrc https://raw.githubusercontent.com/PhilippElhaus/Config/main/.bashrc

  local root_bashrc="/root/.bashrc"
  
  if [ -f "$root_bashrc" ]; then
      for user_home in /home/*; do
        if [ -d "$user_home" ]; then
          user_bashrc="$user_home/.bashrc"
          sudo cp "$root_bashrc" "$user_bashrc"
        fi
      done
  fi

  for adapter in $adapters; do
    if [[ "$adapter" == "eth"* ]] || [[ "$adapter" == "ens"* ]]; then
      sudo ip link set dev "$adapter" mtu 1500
    fi
  done
  
  source ~/.bashrc

  if [ -n "$1" ]; then
    if [ -n "$2" ]; then
      new_hostname="$2"
      sudo sh -c "echo '$new_hostname' > /etc/hostname"
      sudo sed -i "s/127.0.1.1.*/127.0.1.1 $new_hostname/" /etc/hosts
    fi

    sudo rm -f /etc/update-motd.d/*
    sudo tee /etc/update-motd.d/99-custom-motd <<EOL
#!/bin/bash
echo -e "\n  \e[1;31m---  $1  ---\e[0m\n"
echo -e " " $(lsb_release -s -d);
/usr/share/landscape/landscape-sysinfo.wrapper* 2> /dev/null;
echo -e " ";
EOL
    sudo chmod +x /etc/update-motd.d/99-custom-motd
    sudo run-parts /etc/update-motd.d/
  fi

  echo -e "\e[91m---  Upgrade Complete ---\e[0m"
}

# Usability

services() {
    local service_output
    local plus_lines
    local minus_lines

    service_output=$(service --status-all)
    plus_lines=$(echo "$service_output" | grep " \[ + \]")
    minus_lines=$(echo "$service_output" | grep " \[ - \]")

    echo -e "$plus_lines\n---\n$minus_lines"
}

status() {
  if [ -z "$1" ]; then
    echo "Usage: status <SERVICENAME>"
    return 1
  fi

  if ! systemctl list-units --type service --all | awk '{print $1}' | grep -q "\<$1\>"; then
    echo "Service $1 does not exist."
    return 1
  fi

  echo -e "\e[31m---\e[0m Ports \e[31m---\e[0m"
  netstat -tulnp | grep "$1" | awk '{sub(/.*:/,"",$4); print $1 " " $4}'
  echo -e "\e[31m---\e[0m End \e[31m---\e[0m "
  service "$1" status
}

proc() {
    if [ $# -ne 1 ]; then
        echo "Usage: proc <process_name>"
        return 1
    fi

    process_name="$1"
    pids=$(ps aux | grep "$process_name" | grep -v "grep" | awk '{print $2, $11}')

    if [ -z "$pids" ]; then
        echo "No PID's found for $process_name"
    else
        echo -e "\e[31m---\e[0m PID's containing '$process_name' \e[31m---\e[0m"
        echo "$pids"
        echo -e "\e[31m---\e[0m End \e[31m---\e[0m "
    fi
}

ports() {
    if [ $# -ne 1 ]; then
        echo "Usage: ports <process_name>"
        return 1
    fi

    process_name="$1"
    pids=$(pgrep "$process_name")

    if [ -z "$pids" ]; then
        echo "No processes found for: $process_name"
    else
        echo "NAME | PID : TYPE | PROTOCOL | PORT"
        echo "-----------------------------------"
        sudo lsof -i -P -n -a -p $(echo $pids | tr ' ' ',') | awk 'NR>1{split($9, parts, ":"); printf "%s | %s : %s | %s | %s\n", $1, $2, $5, $8, parts[2]}'
    fi
}

search() {
        echo "Searching..."
        find / -iname "$1" 2> /dev/null
        echo "Search done."
}

# Shorthand

route() {
    if [ $# -eq 0 ]; then
        command route -n
    else
        command route "$@"
    fi
}

df() {
    if [ $# -eq 0 ]; then
        command df -h
    else
        command df "$@"
    fi
}

du() {
    if [ $# -eq 0 ]; then
        command du -sh
    else
        command du "$@"
    fi
}

pushd() {
    if [ $# -eq 0 ]; then
        command pushd .
    else
        command pushd "$@"
    fi
}

tree() {
    if [ $# -eq 0 ]; then
        command tree -L 1 --dirsfirst
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