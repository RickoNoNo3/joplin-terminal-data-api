#!/bin/sh
echo "Running Joplin version: $JOPLIN_VERSION"
if [ "$JOPLIN_VERSION" = "dynamic" ]; then
  echo "Checking for Joplin updates..."
  current=$(npm list -g joplin --depth=0 --parseable 2>/dev/null)
  latest=$(npm show joplin@latest version 2>/dev/null)
  echo "Current Joplin version: $current"
  echo "Latest Joplin version: $latest\n"
  if [ "$current" != "$latest" ]; then
    echo "Installing joplin@$latest...\n"
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
    joplin sync 2>&1 1>/dev/null
  fi
  sync_interval=$(cat /root/.config/joplin/settings.json | grep 'sync.interval' | sed 's/^.*"\([^"]*\)".*$/\1/g')
  if [ -z "$sync_interval" ]; then
    sync_interval=300
  fi
  sleep $sync_interval
done

wait