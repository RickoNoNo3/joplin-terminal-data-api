#!/bin/sh
echo "---------------------------"
echo "Clearning aborted temp lock files..."
rm /tmp/*
echo "Running Joplin version: $JOPLIN_VERSION"
if [ "$JOPLIN_VERSION" = "dynamic" ]; then
  echo "Checking for Joplin updates..."
  current=$(NPM_CONFIG_PREFIX=/app/joplin npm list -g joplin --depth=0 2>/dev/null | grep -E 'joplin@[0-9.]*\s*$' | tail -n 1 | sed 's/^.*joplin@\([0-9.]*\).*$/\1/')
  latest=$(npm show joplin@latest version 2>/dev/null)
  echo "Current Joplin version: $current"
  echo "Latest Joplin version: $latest"
  if [ "$current" != "$latest" ]; then
    echo "Installing joplin@$latest..."
    NPM_CONFIG_PREFIX=/app/joplin npm install --omit=dev -g joplin@$latest
    ln -sf /app/joplin/bin/joplin /usr/bin/joplin
  else
    echo "Joplin is already up to date."
  fi
fi
shift

echo "Importing Joplin configuration..."
if [ -r "/root/joplin/joplin-config.json" ]; then
  joplin config --import </root/joplin/joplin-config.json
fi

echo "Starting Joplin server..."
joplin server start &

sleep 10

echo "Configuring Nginx..."
export TOKEN=$(cat /root/.config/joplin/settings.json | grep 'token' | sed 's/^.*"\([^"]*\)".*$/\1/g')
cp /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf
sed -i 's/__TOKEN__/'"$TOKEN"'/g' /etc/nginx/nginx.conf

echo "Starting Nginx..."
nginx -g 'daemon on;'

while true; do
  joplin_total=$(joplin status | grep 'Total' | sed 's/^Total: [0-9]\{1,\}\/\([0-9]\{1,\}\)\s*$/\1/g')
  if [ -z "$joplin_total" ]; then
    echo "Joplin is in a blank state, synchronization is paused"
  else
    echo "Starting Joplin sync..."
    joplin sync
  fi
  sync_interval=$(cat /root/.config/joplin/settings.json | grep 'sync.interval' | sed 's/^.*"\([^"]*\)".*:[^0-9]*\([0-9]*\)[^0-9]*$/\2/g')
  if [ -z "$sync_interval" ]; then
    sync_interval=600
  fi
  if [ "$sync_interval" -lt 300 ]; then
    sync_interval=300
  fi
  sleep $sync_interval
done

wait
