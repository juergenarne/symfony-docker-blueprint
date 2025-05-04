FROM php:8.3-apache

RUN apt-get update && apt-get install -y \
    git unzip curl libicu-dev libzip-dev libpng-dev libjpeg-dev \
    libfreetype6-dev libxml2-dev mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql intl zip gd exif opcache xml

RUN pecl install redis && docker-php-ext-enable redis

RUN a2enmod rewrite

# Composer installieren
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# DocumentRoot anpassen
RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!/var/www/html/public!g' /etc/apache2/apache2.conf /etc/apache2/sites-available/*.conf