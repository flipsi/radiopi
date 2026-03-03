FROM php:8.4-fpm

## Install system dependencies and nginx
RUN apt-get update && apt-get install -y \
        lsof \
        gawk \
        pulseaudio \
        vlc \
        netcat-traditional \
        cron \
        nginx \
        supervisor \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

## Install PHP extensions
RUN docker-php-ext-install gettext

## Install and generate locales to make GNU gettext work
# RUN apt-get update && apt-get install -y locales \
#     && locale-gen en_US.UTF-8 de_DE._UTF-8
RUN apt-get update && apt-get install -y locales-all

# ENV LANG=en_US.UTF-8
# ENV LANGUAGE=en_US:en
# ENV LC_ALL=en_US.UTF-8

ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de:de
ENV LC_ALL=de_DE.UTF-8

ENV WWW_DATA_NAME=www-data
ENV WWW_DATA_UID=33
ENV WWW_DATA_GID=33

## Add custom PHP config
## File will be merged with default config.
COPY custom.php.ini /usr/local/etc/php/conf.d/99-custom.php.ini
RUN touch /var/log/php_errors.log && chown $WWW_DATA_UID:$WWW_DATA_GID /var/log/php_errors.log

## Copy backend code to document root
COPY ./radio.sh /opt/radio
## Copy frontend code to document root
# COPY ./frontend /var/www/html
## Mount host folder at runtime instead

## Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

## Configure supervisord to run php-fpm + nginx together
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

## Setup crontab
RUN touch /etc/crontab.empty && su -l $WWW_DATA_NAME -s /bin/bash -c 'crontab /etc/crontab.empty'

## Allow audio access for webserver
RUN usermod -aG audio $WWW_DATA_NAME

## Expose ports
EXPOSE 80

## Start both services
CMD ["/usr/bin/supervisord", "-n"]
