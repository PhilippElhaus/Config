#! /bin/bash

cat /etc/nginx/sites-available/default > /home/backup/nginx_old.2.conf
cat /etc/nginx/nginx.conf > /home/backup/nginx_old.conf

rm -r /etc/nginx/sites-available/
rm -r /etc/nginx/sites-enabled/

cp /home/nginx.conf /etc/nginx/nginx.conf

service nginx restart

cp /home/.bashrc ~/
source ~/.bashrc

echo "--- Custom configuration loaded. ---"


