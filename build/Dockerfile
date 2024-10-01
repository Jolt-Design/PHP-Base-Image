# PHP_VERSION is the minor PHP version to use as a base - uses the php repo tag, e.g. php-8.0
ARG PHP_VERSION=8.0

# RUNTIME is the runtime to use, e.g. apache, fpm or cli. uses the php repo tag, e.g. FROM php-apache
ARG RUNTIME=apache

FROM php:${PHP_VERSION}-${RUNTIME} AS production

# MCRYPT_VERSION overrides the version of Mcrypt installed from PECL. Use this if your PHP version is too old for the most current version.
ARG MCRYPT_VERSION=

RUN apt-get update \
    && apt-get install -y libpng-dev libmcrypt-dev libmagickwand-dev libicu-dev libxml2-dev libzip-dev libfreetype-dev libicu-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) mysqli gd pdo_mysql opcache exif zip intl \
    && pecl install mcrypt$([ "x${MCRYPT_VERSION}" != "x" ] && echo "-${MCRYPT_VERSION}") imagick \
    && pecl install -o -f redis \
    && docker-php-ext-enable redis mcrypt imagick \
    && rm -rf /tmp/pear \
    && docker-php-source delete

RUN a2enmod alias ext_filter headers rewrite

COPY ./php-conf.d/ /usr/local/etc/php/conf.d

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
