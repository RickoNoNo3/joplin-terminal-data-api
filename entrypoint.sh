#!/bin/sh
export TOKEN=$(cat /root/.config/joplin/settings.json | grep 'token' | sed 's/^.*"\([^"]*\)".*$/\1/g')
cp /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf
sed -i 's/__TOKEN__/'"$TOKEN"'/g' /etc/nginx/nginx.conf

nginx -g 'daemon on;'

if [ -r "/root/joplin-config.json" ]; then
  joplin config --import </root/joplin-config.json
fi
joplin server start
