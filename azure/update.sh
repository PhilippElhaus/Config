#! /bin/bash
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
NC=$'\e[0m'

echo -e "-- START NEW CONFIG --\n\n"
cat /home/nginx.conf
echo -e "\n\n-- END NEW CONFIG --"
cp /etc/nginx/nginx.conf /home/nginx.conf.old
cp /home/nginx.conf /etc/nginx/nginx.conf
service nginx restart

if [[ $? == 0 ]]; then 
    echo -e "-- ${GREEN}NEW CONFIG INITIALISED${NC} --"
else
    echo -e "-- ${RED}NEW CONFIG FAILED!${NC} --"
fi
