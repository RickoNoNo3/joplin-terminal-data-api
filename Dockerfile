FROM node:18-alpine AS nginx-node-alpine
ARG JOPLIN_VERSION=dynamic
ENV JOPLIN_VERSION=${JOPLIN_VERSION}

RUN apk add nginx; adduser -D -g 'www' www; mkdir /www; chown -R www:www /var/lib/nginx; chown -R www:www /www; mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig; \
    if [ "${JOPLIN_VERSION}" != "dynamic" ]; then NPM_CONFIG_PREFIX=/app/joplin npm install --omit=dev -g joplin@${JOPLIN_VERSION} && ln -s /app/joplin/bin/joplin /usr/bin/joplin; fi
COPY nginx.conf /etc/nginx/nginx.conf.template

EXPOSE 41184 41185 9967

COPY entrypoint.sh /usr/bin
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]