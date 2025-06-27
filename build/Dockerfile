# PHP_VERSION is the minor PHP version to use as a base - uses the php repo tag, e.g. php-8.0
ARG PHP_VERSION=8.0

# RUNTIME is the runtime to use, e.g. apache, fpm or cli. uses the php repo tag, e.g. FROM php-apache
ARG RUNTIME=apache

# BASE_IMAGE is the image to use as a base. Can be used to override the base with a pull-through cache, for example.
ARG BASE_IMAGE=php

FROM ${BASE_IMAGE}:${PHP_VERSION}-${RUNTIME} AS production

# MCRYPT_VERSION overrides the version of Mcrypt installed from PECL. Use this if your PHP version is too old for the most current version. Use "disabled" to completely disable Mcrypt.
ARG MCRYPT_VERSION=

# MCRYPT_VERSION overrides the version of Imagemagick installed from PECL. Use this if your PHP version is too old for the most current version.
ARG IMAGICK_VERSION=

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y libpng-dev $([ "x${MCRYPT_VERSION}" != "xdisabled" ] && echo libmcrypt-dev) libmagickwand-dev libicu-dev libxml2-dev libzip-dev libfreetype-dev libgd-dev unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) mysqli gd pdo_mysql opcache exif zip intl \
    && pecl install $([ "x${MCRYPT_VERSION}" != "xdisabled" ] && echo mcrypt$([ "x${MCRYPT_VERSION}" != "x" ] && echo "-${MCRYPT_VERSION}")) imagick$([ "x${IMAGICK_VERSION}" != "x" ] && echo "-${IMAGICK_VERSION}") \
    && pecl install -o -f redis \
    && docker-php-ext-enable redis $([ "x${MCRYPT_VERSION}" != "xdisabled" ] && echo mcrypt) imagick \
    && rm -rf /tmp/pear \
    && docker-php-source delete

RUN a2enmod alias ext_filter headers rewrite remoteip

COPY ./php-conf.d/ /usr/local/etc/php/conf.d
COPY ./apache-conf.d/ /etc/apache2/conf-enabled

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# dev includes Xdebug and other useful development settings by default
FROM production AS dev

# XDEBUG_VERSION overrides the version of Xdebug installed from PECL. Use this if your PHP version is too old for the most current version.
ARG XDEBUG_VERSION=

# Install Xdebug
RUN pecl install xdebug$([ "x${XDEBUG_VERSION}" != "x" ] && echo "-${XDEBUG_VERSION}") \
    && docker-php-ext-enable xdebug \
    && rm -rf /tmp/pear \
    && docker-php-source delete

COPY ./dev-php-conf.d/ /usr/local/etc/php/conf.d

RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
