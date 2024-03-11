FROM node:18-alpine as nginx-node-alpine

RUN NPM_CONFIG_PREFIX=/app/joplin npm install --production --silent -g joplin; ln -s /app/joplin/bin/joplin /usr/bin/joplin; /usr/bin/joplin status

RUN apk add nginx; adduser -D -g 'www' www; mkdir /www; chown -R www:www /var/lib/nginx; chown -R www:www /www; mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
COPY nginx.conf /etc/nginx/nginx.conf.template

EXPOSE 41184 41185 9967

COPY entrypoint.sh /usr/bin
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]