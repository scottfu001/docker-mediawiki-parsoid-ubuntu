FROM ubuntu:xenial
MAINTAINER  Scott Fu <scott.fu@oulook.com>

#enviroment variables
ENV TZ=UTC

# some missing pkgs
RUN apt-get update && apt-get install -y --no-install-recommends dialog apt-utils

# build required libs
RUN apt-get install -y locales curl vim git software-properties-common && locale-gen en_US.UTF-8 

# add repositories
RUN add-apt-repository -y ppa:nginx/stable && \
	apt-get update


# install Nginx.
RUN apt-get install -y nginx && \
  # for docker
  echo "\ndaemon off;" >> /etc/nginx/nginx.conf && \
  chown -R www-data:www-data /var/lib/nginx && \
  chown -R www-data:www-data /var/www/html

# install PHP
RUN apt-get install -y \
	php-apcu \
	php-ast \
	php-bcmath \
	php-bz2 \
	php-calendar \
	php-cgi \
	php-cli \
	php-common \
	php-curl \
	php-date \
	php-db \
	php-deepcopy \
	php-directory-scanner \
	php-dompdf \
	php-email-validator \
	php-enchant \
	php-fdomdocument \
	php-fpdf \
	php-fpm \
	php-gd \
	php-geoip \
	php-imagick \
	php-gmp \
	php-imap \
	php-intl \
	php-json \
	php-ldap \
	php-mbstring \
	php-mysql \
	php-odbc \
	php-opcache \
	php-pgsql \
	php-phpdbg \
	php-pspell \
	php-readline \
	php-redis \
	php-recode \
	php-soap \
	php-sqlite3 \
	php-tidy \
	php-xml \
	php-xmlrpc \
	php-xsl \
	php-zip \
	php-mongodb
	
# basic php config
RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini
RUN sed -i "s/display_errors = Off/display_errors = On/" /etc/php/7.0/fpm/php.ini
RUN sed -i "s/upload_max_filesize = .*/upload_max_filesize = 10M/" /etc/php/7.0/fpm/php.ini
RUN sed -i "s/post_max_size = .*/post_max_size = 10M/" /etc/php/7.0/fpm/php.ini
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.0/fpm/php.ini

# make it docker friendly and runable by docker-compose
RUN sed -i -e "s/pid =.*/pid = \/var\/run\/php7.0-fpm.pid/" /etc/php/7.0/fpm/php-fpm.conf
RUN sed -i -e "s/error_log =.*/error_log = \/proc\/self\/fd\/2/" /etc/php/7.0/fpm/php-fpm.conf
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf
RUN sed -i "s/listen = .*/listen = 9000/" /etc/php/7.0/fpm/pool.d/www.conf
RUN sed -i "s/;catch_workers_output = .*/catch_workers_output = yes/" /etc/php/7.0/fpm/pool.d/www.conf

# intall Parsoid
RUN apt-get install -y dirmngr && \
	apt-key advanced --keyserver keys.gnupg.net --recv-keys 90E9F83F22250DD7 && \
	apt-add-repository "deb https://releases.wikimedia.org/debian jessie-mediawiki main" && \
	apt-get install -y apt-transport-https && \
	apt-get update && \
	apt-get install -y parsoid
	
#basic config for the parsoid
RUN sed -i "s/uri:.*/uri: \'https:\/\/localhost\/api.php\'/" /etc/mediawiki/parsoid/config.yaml
RUN sed -i "s/#strictSSL:.*/strictSSL: false" /etc/mediawiki/parsoid/config.yaml
RUN echo "num_workers: 4" >> /etc/mediawiki/parsoid/config.yaml

# install supervisor
RUN apt-get install -y supervisor
	
# clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && apt-get autoremove

# volumns
# mountable nginx directories.
VOLUME ["/etc/nginx/sites-enabled", "/etc/nginx/conf.d", "/var/log/nginx", "/var/www/html", "/etc/nginx/certs"]
# www directory
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html
VOLUME ["/var/www/html"]
WORKDIR /var/www/html

# add configuration for supervisord, we will use custom Nginx and Parsoid config from the host
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# port
EXPOSE 80 443

# use supervisored to start services
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisor/conf.d/supervisord.conf"]