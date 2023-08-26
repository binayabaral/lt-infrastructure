#!/bin/bash

# Exit immediately if a command exits with a non zero status
set -e

ENV=${env}

# Install nginx
apt update -y
apt install -y nginx

SERVER_NAME=_
CONFIG_FILE=backend.$ENV.conf

# Populate nginx configuration
cat >/etc/nginx/sites-available/$CONFIG_FILE <<EOF
server {
  listen 80;
  listen [::]:80;

  server_name _;

  location / {
    proxy_pass http://localhost:5000;
    include proxy_params;
  }
}
EOF

ln -s /etc/nginx/sites-available/$CONFIG_FILE /etc/nginx/sites-enabled/

rm -rf /etc/nginx/sites-enabled/default

systemctl restart nginx

# Install nodejs
wget https://nodejs.org/dist/v18.14.2/node-v18.14.2-linux-x64.tar.xz
sudo tar -C /usr/local --strip-components 1 -xJf node-v18.14.2-linux-x64.tar.xz
npm install -g yarn pm2

# Install the codedeploy agent
apt install -y ruby-full wget

cd /tmp
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
