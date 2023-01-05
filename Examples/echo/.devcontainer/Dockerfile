FROM ubuntu:22.04

# for apt to be noninteractive
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

# Used by running apps to detect if inside a docker container. Testing for existence of /.dockerenv may not always work.
ENV InDocker=True

RUN apt-get update && apt-get install -y apt-utils

RUN apt-get install -y \
        git \
        build-essential \
        libgpm2 \
        gnupg \
        wget \
        psmisc \
        libcurl4-openssl-dev

# install harbour from src
RUN mkdir /src
WORKDIR /src
RUN git clone --branch master https://github.com/harbour/core.git harbour
WORKDIR /src/harbour

ENV HB_WITH_CURL=/usr/include/x86_64-linux-gnu/

# Will request the make app to use up to 8 core.
RUN make -j 8 install

#To fix symlinks
RUN ldconfig

RUN apt-get install -y \
        apache2 \
        libfcgi-dev \
        libapache2-mod-fcgid


# The following are optional instructions if you need to change timezone.
# preesed tzdata, update package index, upgrade packages and install needed software
# RUN echo "tzdata tzdata/Areas select Europe" > /tmp/preseed.txt; \
#     echo "tzdata tzdata/Zones/Europe select Berlin" >> /tmp/preseed.txt; \
#     debconf-set-selections /tmp/preseed.txt && \
#     apt-get update && \
#     apt-get install -y tzdata

RUN a2enmod rewrite
RUN mkdir -p /var/www/Harbour_websites/fcgi_echo/apache-logs/

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

ADD ./FilesForPublishedWebsites/LinuxApache2/echo.conf /etc/apache2/sites-enabled/000-default.conf

COPY ./FilesForPublishedWebsites/backend /var/www/Harbour_websites/fcgi_echo/backend
COPY ./FilesForPublishedWebsites/website /var/www/Harbour_websites/fcgi_echo/website

RUN chown -R www-data:www-data /var/www/Harbour_websites

# Following 2 lines not needed since starting the apache server as a service and opening port 80 is set in devcontainer.json
# EXPOSE 80
# CMD apache2ctl -D FOREGROUND

# The COPY of parent folder to the project root does not work. Mounting folder instead.
# RUN mkdir -p /src/Harbour_FastCGI
# COPY ../../ /src/Harbour_FastCGI
