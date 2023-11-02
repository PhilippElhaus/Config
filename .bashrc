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

alias install_php='sudo apt -y install php php-{curl,zip,bz2,gd,imagick,intl,apcu,memcache,imap,mysql,cas,ldap,tidy,pear,xmlrpc,pspell,mbstring,json,gd,xml} php8.1-xsl php8.1-common'
alias install_apache='sudo apt -y install apache2 libapache2-mod-{php,security2}'

	# Helper Functions

colorize_errors() {
	while IFS= read -r line; do
		echo -e "\e[93m$line\e[0m" >&2
	done
}

check_repository() {
	local repo="$1"
	if grep -q "$repo" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
		return 0  # Repository found
	else
		return 1  # Repository not found
	fi
}

	# Full System Upgrade

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
  
{

  timedatectl set-timezone CET
  
	#Temporary MTU @ 500

  adapters=$(ip -o link show | awk -F': ' '{print $2}')
  for adapter in $adapters; do
	if [[ "$adapter" == "eth"* ]] || [[ "$adapter" == "ens"* ]]; then
	  sudo ip link set dev "$adapter" mtu 500
	fi
  done

	# Shutdown IPV6

  sudo sysctl -w -q net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
  sudo sysctl -w -q net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1
  sudo sysctl -w -q net.ipv6.conf.lo.disable_ipv6=1 > /dev/null 2>&1

  sudo sysctl -p

	# Disable IPV6 Permanent

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

	# Import Public Keys for 3rd Party Repos

  keys=("ABF5BD827BD9BF62" "7FCC7D46ACCC4CF8" "467B942D3A79BD29")
  descriptions=("nginx" "postgre" "mysql")
  
  for i in "${!keys[@]}"; do
    key="${keys[$i]}"
    description="${descriptions[$i]}"
    gpg_file="/etc/apt/trusted.gpg.d/$description.gpg"
  
    if ! sudo gpg --list-keys | grep -q "$key"; then
      echo "Receiving and exporting GPG key for $description..."
      sudo gpg --keyserver keyserver.ubuntu.com --recv-keys "$key"
      sudo gpg --export "$key" > "$gpg_file"
    fi
  done

	# Add Additional Repos

  if ! check_repository "deb http://repo.mysql.com/apt/ubuntu/ $(lsb_release -c -s) mysql-8.0"; then
	  sudo add-apt-repository -y "deb http://repo.mysql.com/apt/ubuntu/ $(lsb_release -c -s) mysql-8.0"
  fi
  
  if ! check_repository "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -c -s)-pgdg main"; then
	  sudo add-apt-repository -y "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -c -s)-pgdg main"
  fi
  
  if ! check_repository "deb http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -c -s) nginx"; then
	  sudo add-apt-repository -y "deb http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -c -s) nginx"
  fi

  local repos=("ondrej/php" "ondrej/apache2")
  for repo in "${repos[@]}"; do
	if ! grep -q "$repo" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
	  echo "Adding ppa:$repo Repository..."
	  sudo add-apt-repository -y "ppa:$repo"
	fi
  done

	# Execute Updates & Install necessities

  export DEBIAN_FRONTEND=noninteractive

  local packages_to_install=()
  for package in net-tools wget cmatrix curl lsof nano nmap tree unzip; do
	  if ! dpkg -l | awk '{print $2}' | grep -q "^$package$"; then
		  packages_to_install+=("$package")
	  fi
  done  
  if [ ${#packages_to_install[@]} -gt 0 ]; then
	  sudo apt-get -y install "${packages_to_install[@]}"
  fi

  sudo apt-get update
  
  upgrade_out=$(sudo apt-get -s upgrade)
  autoremove_out=$(sudo apt-get -s autoremove)
  
  if echo "$upgrade_out" | grep -q 'upgraded [1-9]\+'; then
      sudo apt-get -y upgrade
  fi
  
  sudo apt-get autoclean
  
  if echo "$autoremove_out" | grep -q 'to remove [1-9]\+'; then
      sudo apt-get -y autoremove
  fi
  
	# Update and spread latest .bashrc

  sudo curl -o /root/.bashrc https://raw.githubusercontent.com/PhilippElhaus/Config/main/.bashrc
  source ~/.bashrc

  local root_bashrc="/root/.bashrc"
  
  if [ -f "$root_bashrc" ]; then
	  for user_home in /home/*; do
		if [ -d "$user_home" ]; then
		  user_bashrc="$user_home/.bashrc"
		  sudo cp "$root_bashrc" "$user_bashrc"
		fi
	  done
  fi

	# Reset MTU to 1500

  for adapter in $adapters; do
	if [[ "$adapter" == "eth"* ]] || [[ "$adapter" == "ens"* ]]; then
	  sudo ip link set dev "$adapter" mtu 1500
	fi
  done

	# Optional MOTD and Hostname Change

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
  
} 2> >(colorize_errors)
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