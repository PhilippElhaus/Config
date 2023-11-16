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
	alias dir='ls -alhS --color=auto --group-directories-first'
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
unalias install_apache 2> /dev/null
unalias install_php 2> /dev/null
unalias install_mysql 2> /dev/null
unalias install_nginx 2> /dev/null
unalias install_ftp 2> /dev/null

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear -x'
alias nano='nano --linenumbers'
alias list='dpkg --get-selections | grep -i'
alias hex='xxd'
alias dc='cd'
alias st='status'

alias ips="ip addr show | awk '/inet / {print \$2}' | cut -d' ' -f1"
alias nameserver="grep '^nameserver' /etc/resolv.conf | awk '{print}'"
alias ns='nameserver'
alias gateway="ip route | awk '/default/ {print $3}' | cut -d' ' -f1-3"
alias gw='gateway'
alias net='ips; nameserver; gateway'
alias linux='lsb_release -s -d'

	# Helper Functions

colorize_errors() {
	while IFS= read -r line; do
		echo -e "\e[93m$line\e[0m" >&2
	done
}

check_repository() {
	local repo="$1"
	if grep -q "$repo" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
		return 0
	else
		return 1
	fi
}

cleanup() {
  if [ "$EUID" -ne 0 ]; then
    echo "You need to be root."
    return
  fi
  apt autoremove
  dpkg --get-selections | grep -E 'deinstall$' | cut -f 1 | while read -r package; do dpkg --purge "$package" 2>/dev/null; done
  dpkg --purge $(dpkg -l | grep ^rc | awk '{print $2}') 2>/dev/null
  echo "Done."
}

remove() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: remove <package1> [<package2> <package3> ...]"
    return 1
  fi

  if [ "$EUID" -ne 0 ]; then
    echo "You need to be root."
    return
  fi

    local choice
  read -p "Wipe the package(s) and anything related (Y/N): " choice
  if [ "${choice^^}" = "Y" ]; then

    sudo apt remove -y "$@" 2>/dev/null && sudo apt autoremove || echo "No such package.";
    sudo dpkg --get-selections | grep -E 'deinstall$' | cut -f 1 | while read -r package; do dpkg --purge "$package" 2>/dev/null; done
    sudo dpkg --purge $(dpkg -l | grep ^rc | awk '{print $2}') 2>/dev/null

  fi
}

	# Default Software Installs

install_apache() {
  if [ "$EUID" -ne 0 ]; then
	echo "You need to be root."
	return
  fi
  local choice
  read -p "Will overwrite any existing installation. Do you want to proceed? (Y/N): " choice
  if [ "${choice^^}" = "Y" ]; then

    sudo apt -y install apache2 libapache2-mod-{php,security2,fcgid}

    sudo rm -f /etc/apache2/sites-available/*
    sudo rm -f /etc/apache2/sites-enabled/*
    sudo rm -f /etc/apache2/ports.conf
    sudo rm -f /etc/apache2/apache2.conf
    sudo rm -rf /etc/apache2/sites-available
    sudo rm -rf /etc/apache2/sites-enabled
    sudo rm -rf /var/www/*
    echo "Deleted initial config files..."

sudo tee /etc/apache2/apache2.conf >/dev/null <<EOL
DefaultRuntimeDir \${APACHE_RUN_DIR}
PidFile \${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
User \${APACHE_RUN_USER}
Group \${APACHE_RUN_GROUP}
HostnameLookups Off
AccessFileName .htaccess

IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
IncludeOptional conf-enabled/*.conf

ErrorLog \${APACHE_LOG_DIR}/error.log
CustomLog \${APACHE_LOG_DIR}/access.log combined

LogLevel warn

LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent

Listen 80

<VirtualHost *:80>
    DocumentRoot /var/www/
</VirtualHost>

<Directory /var/www/>
        Options Indexes FollowSymLinks
        DirectoryIndex index.php
        Require all granted
        RewriteEngine On
        AllowOverride All

        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
</Directory>

<Directory />
        Options FollowSymLinks
        AllowOverride None
        Require all denied
</Directory>

<FilesMatch "^\.ht">
        Require all denied
</FilesMatch>
EOL

sudo tee /var/www/index.php >/dev/null <<EOL
<!DOCTYPE html>
<html>
  <head>
    <title>APACHE2 WebServer</title>
    <style>
      .green { color: green; font-weight: bold; }
    </style>
  </head>
  <body>
    <h1>APACHE2 WebServer</h1>
    <p>This file is reachable.</p>
    <p>PHP Status: <b class="green"><?php echo phpversion(); ?></b></p>
  </body>
</html>
EOL

    echo "Created new default config file."
    sudo chown -R www-data:www-data /var/www/
    sudo chmod -R 755 /var/www/
    sudo a2enmod rewrite ssl headers
    sudo systemctl restart apache2

    local ip_webserver=$(ip -4 addr show $(ip route | grep default | awk '{print $5}' | head -n 1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo -e "Webserver @ \033[0;31mhttp://$ip_webserver:80\033[0m"

    echo -e "\e[91m--- Done ---\e[0m"
  fi
}

install_nginx() {
  if [ "$EUID" -ne 0 ]; then
	  echo "You need to be root."
	return
  fi

  local choice
  read -p "Will overwrite any existing installation. Do you want to proceed? (Y/N): " choice
  if [ "${choice^^}" = "Y" ]; then

  export DEBIAN_FRONTEND=noninteractive
  sudo apt install -y -o Dpkg::Options::="--force-confnew" nginx

  rm -rf /etc/nginx/conf.d/
  rm /etc/nginx/nginx.conf
  sudo rm -rf /var/www/*
  mkdir -p /var/www

  echo "Deleted initial config files..."

  local installed_version=$(php -v 2>/dev/null | grep -oP '(PHP )\K[0-9]+\.[0-9]+' 2>/dev/null)

sudo tee /etc/nginx/nginx.conf >/dev/null <<EOL
user www-data;
worker_processes auto;

pid /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include /etc/nginx/mime.types;
    include fastcgi_params;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    error_log /var/log/nginx/error.critical.log crit;
    error_log /var/log/nginx/error.log notice;
 
    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    server {
        listen 8080;
        server_name localhost;
        root /var/www/;

        location / {
            index index.php;
        }
EOL

if [ -n "$installed_version" ]; then
    echo "        location ~ \.php$ {" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            include fastcgi_params;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_pass unix:/run/php/php$installed_version-fpm.sock;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_index index.php;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_split_path_info ^(.+\.php)(/.+)$;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_intercept_errors on;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_buffers 8 16k;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "            fastcgi_buffer_size 32k;" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
    echo "        }" | sudo tee -a /etc/nginx/nginx.conf >/dev/null
fi

sudo tee -a /etc/nginx/nginx.conf >/dev/null <<EOL
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOL

sudo tee /var/www/index.php >/dev/null <<EOL
<!DOCTYPE html>
<html>
  <head>
    <title>NGINX WebServer</title>
    <style>
      .green { color: green; font-weight: bold; }
    </style>
  </head>
  <body>
    <h1>NGINX WebServer</h1>
    <p>This file is reachable.</p>
    <p>PHP Status: <b class="green"><?php echo phpversion(); ?></b></p>
  </body>
</html>
EOL

  echo "Created new default config file."
  sudo chown -R www-data:www-data /var/www/
  sudo chmod -R 755 /var/www/

  sudo systemctl start nginx
  sudo systemctl enable nginx

  local ip_webserver=$(ip -4 addr show $(ip route | grep default | awk '{print $5}' | head -n 1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  echo -e "Webserver @ \033[0;31mhttp://$ip_webserver:8080\033[0m"

  echo -e "\e[91m--- Done ---\e[0m"
  fi
}

install_php() {
  if [ "$EUID" -ne 0 ]; then
	echo "You need to be root."
	return
  fi
    sudo apt -y install php php-{curl,zip,bz2,gd,imagick,intl,apcu,memcache,imap,mysql,cas,ldap,tidy,pear,xmlrpc,pspell,mbstring,json,gd,xml} php8.2-xsl php8.2-common
    sudo phpenmod curl zip bz2 gd imagick intl apcu memcache imap mysql cas ldap tidy pear xmlrpc pspell mbstring json gd xml xsl
    
    if systemctl is-active --quiet apache2; then
        echo "Restarting Apache2..."
        sudo systemctl restart apache2 && echo "Apache2 restarted successfully."
    elif systemctl is-active --quiet nginx; then
        echo "Restarting NGINX..."
        sudo systemctl restart nginx && echo "NGINX restarted successfully."
    fi

    version=$(php -v | head -n 1 | cut -d " " -f 1,2,3)
    echo -e "\e[32m$version\e[0m"
}

install_mysql() {
  if [ "$EUID" -ne 0 ]; then
    echo "You need to be root."
    return
  fi

  if [ "$#" -ne 3 ]; then
    echo "Database (1), Username (2), and Password (3) are required as arguments."
    return
  fi

  local initial_db_name="$1"
  local new_user="$2"
  local password="$3"

  sudo apt update
  sudo DEBIAN_FRONTEND=noninteractive apt -y install mysql-server
  sudo systemctl start mysql
  sudo systemctl enable mysql

   mysql -u root <<EOF
  CREATE DATABASE IF NOT EXISTS $initial_db_name;
  CREATE USER '$new_user'@'localhost' IDENTIFIED BY '$password';
  GRANT ALL PRIVILEGES ON $initial_db_name.* TO '$new_user'@'localhost';
  FLUSH PRIVILEGES;
EOF
  echo "MySQL installed. Database, user, and password created."
}

install_postgresql() {
  if [ "$EUID" -ne 0 ]; then
    echo "You need to be root."
    return
  fi

  if [ "$#" -ne 3 ]; then
    echo "Database (1), Username (2), and Password (3) are required as arguments."
    return
  fi

  local initial_db_name="$1"
  local new_user="$2"
  local password="$3"

  sudo apt update
  sudo apt -y install postgresql postgresql-contrib
  sudo systemctl start postgresql
  sudo systemctl enable postgresql

  sudo -u postgres psql -c "CREATE DATABASE $initial_db_name;"
  sudo -u postgres psql -c "CREATE USER $new_user WITH ENCRYPTED PASSWORD '$password';"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $initial_db_name TO $new_user;"

  echo "PostgreSQL installed. Database, user, and password created."
}


install_ftp() {
  if [ "$EUID" -ne 0 ]; then
	echo "You need to be root."
	return
  fi
  sudo apt update
  sudo apt install -y vsftpd

  sudo systemctl start vsftpd
  sudo systemctl enable vsftpd

  if command -v ufw &> /dev/null; then
  	sudo ufw allow 21/tcp
  fi

  sudo systemctl restart vsftpd
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
	echo "You need to be root."
	return
  fi

  echo -e "\e[91m--- Upgrading System ---\e[0m"
  
{

  # Basic Ubuntu Settings

  timedatectl set-timezone CET
  sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

	#Temporary MTU @ 500

  adapters=$(ip -o link show | awk -F': ' '{print $2}')
  for adapter in $adapters; do
	if [[ "$adapter" == "eth"* ]] || [[ "$adapter" == "ens"* ]]; then
	  sudo ip link set dev "$adapter" mtu 500
	fi
  done

	# Shutdown IPV6

  sudo sysctl -w -q net.ipv6.conf.all.disable_ipv6=1 > /dev/null
  sudo sysctl -w -q net.ipv6.conf.default.disable_ipv6=1 > /dev/null
  sudo sysctl -w -q net.ipv6.conf.lo.disable_ipv6=1 > /dev/null

  sudo sysctl -p

	# Disable IPV6 Permanent

  if grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
	sudo sed -i 's/net.ipv6.conf.all.disable_ipv6 = 0/net.ipv6.conf.all.disable_ipv6 = 1/g' /etc/sysctl.conf
  else
	echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
  fi

  if grep -q "net.ipv6.conf.default.disable_ipv6" /etc/sysctl.conf; then
	sudo sed -i 's/net.ipv6.conf.default.disable_ipv6 = 0/net.ipv6.conf.default.disable_ipv6 = 1/g' /etc/sysctl.conf
  else
	echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
  fi

  if grep -q "net.ipv6.conf.lo.disable_ipv6" /etc/sysctl.conf; then
	sudo sed -i 's/net.ipv6.conf.lo.disable_ipv6 = 0/net.ipv6.conf.lo.disable_ipv6 = 1/g' /etc/sysctl.conf
  else
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
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
  for package in net-tools wget cmatrix curl lsof nano nmap tree unzip jq; do
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
  local root_bashrc="/root/.bashrc"
  
  if [ -f "$root_bashrc" ]; then
	  for user_home in /home/*; do
		if [ -d "$user_home" ]; then
		  user_bashrc="$user_home/.bashrc"
		  sudo cp "$root_bashrc" "$user_bashrc"
		fi
	  done
  fi

  source ~/.bashrc

  # Display Version

  local data=$(curl -s "https://api.github.com/repos/PhilippElhaus/Config/commits?path=.bashrc")
  local commit_hash=$(echo $data | jq -r '.[0].sha' | cut -c 1-7)
  local now=$(date +%s)
  local commit_time=$(date -d "$(echo $data | jq -r '.[0].commit.committer.date')" +%s)
  local diff=$((now - commit_time))
  local time_ago=""

  if [ $diff -lt 60 ]; then
      time_ago="$diff seconds ago"
  elif [ $diff -lt 3600 ]; then
      time_ago=$((diff / 60))" minutes ago"
  elif [ $diff -lt 86400 ]; then
      time_ago=$((diff / 3600))" hours ago"
  else
      time_ago=$((diff / 86400))" days ago"
  fi

  echo -e ".bashrc Commit: [\033[0;32m$commit_hash\033[0m] ($time_ago)"

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

  local serviceName="$1"
  local processName="$1"

  case "$serviceName" in
    postgresql)
      processName="postgre"
      ;;
  esac

  if ! systemctl list-units --type service --all | awk '{print $1}' | grep -q "\<$serviceName\>"; then
    echo "Service $serviceName does not exist."
    return 1
  fi

  echo -e "\e[31m---\e[0m Ports \e[31m---\e[0m"
  netstat -tulnp | grep "$processName" | awk '{sub(/.*:/,"",$4); print $1 " " $4}'
  echo -e "\e[31m---\e[0m End \e[31m---\e[0m "
  service "$serviceName" status
}

restart() {
    if [ -z "$1" ]; then
        echo "Usage: restart <service-name>"
        return
    fi

    if [ "$EUID" -ne 0 ]; then
        echo "You need to be root."
        return
    fi

    local serviceName
    serviceName="$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"

    if ! service --status-all 2>/dev/null | grep -Fq "$1"; then
        echo "Service $serviceName does not exist."
        return
    fi

    if service "$1" restart > /dev/null 2>&1; then
        echo -e "\e[32mSuccess: $serviceName\e[0m"
    else
        echo -e "\e[31mFailure: $serviceName\e[0m"
    fi
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
		command tree -L 1 --dirsfirst -d --noreport
	elif [ $# -eq 1 ]; then
		command tree -L $1 --dirsfirst -d --noreport
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