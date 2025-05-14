#!/bin/sh
echo "Running Joplin version: $JOPLIN_VERSION"
if [ "$JOPLIN_VERSION" = "dynamic" ]; then
  echo "Checking for Joplin updates..."
  current=$(npm show joplin version 2>/dev/null)
  latest=$(npm show joplin@latest version 2>/dev/null)
  if [ "$current" != "$latest" ]; then
    echo "Current Joplin version: $current"
    echo "Latest Joplin version: $latest"
    echo "Installing joplin@$latest..."
    NPM_CONFIG_PREFIX=/app/joplin npm install --omit=dev -g joplin@$latest
    ln -s /app/joplin/bin/joplin /usr/bin/joplin
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

wait