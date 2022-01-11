FROM elmarit/harbour:3.2 as builder

RUN apt-get update && apt-get install -y apt-utils
RUN apt-get install -y \
        libfcgi-dev \
        libapache2-mod-fcgid
COPY ../../ /src
WORKDIR /src/Examples/echo
RUN mkdir -p build/lin64/clang/release/hbmk2
RUN BuildMode=release EXEName=FCGIecho hbmk2 echo_linux.hbp -w3 -static

FROM ubuntu 


## for apt to be noninteractive
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install \
    apache2 \
    libfcgi-dev \
    libgpm2

## preesed tzdata, update package index, upgrade packages and install needed software
RUN echo "tzdata tzdata/Areas select Europe" > /tmp/preseed.txt; \
    echo "tzdata tzdata/Zones/Europe select Berlin" >> /tmp/preseed.txt; \
    debconf-set-selections /tmp/preseed.txt && \
    apt-get update && \
    apt-get install -y tzdata

RUN apt-get -y install libapache2-mod-fcgid
RUN apt-get clean 

RUN a2enmod rewrite
RUN mkdir -p /var/www/Harbour_websites/fcgi_echo/apache-logs/

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

ADD ./Examples/echo/FilesForPublishedWebsites/LinuxApache2/echo.conf /etc/apache2/sites-enabled/000-default.conf


COPY ./Examples/echo/FilesForPublishedWebsites/backend /var/www/Harbour_websites/fcgi_echo/backend
COPY --from=builder /src/Examples/echo/build/lin64/clang/release/FCGIecho.exe /var/www/Harbour_websites/fcgi_echo/backend/
COPY ./Examples/echo/FilesForPublishedWebsites/website /var/www/Harbour_websites/fcgi_echo/website

RUN chown -R www-data:www-data /var/www/Harbour_websites

EXPOSE 80 
CMD apache2ctl -D FOREGROUND