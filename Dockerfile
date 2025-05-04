FROM php:8.4-apache

# Systemabhängige Tools & Bibliotheken installieren
RUN apt-get update && apt-get install -y \
    unzip \
    git \
    curl \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxml2-dev \
    libmagickwand-dev \
    imagemagick \
    mariadb-client \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# PHP-Erweiterungen installieren
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install \
        pdo \
        pdo_mysql \
        intl \
        zip \
        gd \
        exif \
        opcache \
        xml

# Redis & Imagick via PECL
RUN pecl install redis imagick && \
    docker-php-ext-enable redis imagick

# mod_rewrite aktivieren (für Symfony Routing)
RUN a2enmod rewrite

# Composer installieren
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Arbeitsverzeichnis setzen
WORKDIR /var/www/html

# Apache DocumentRoot auf /public setzen
ENV APACHE_DOCUMENT_ROOT /var/www/html/public

# VirtualHost entsprechend anpassen
RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!/var/www/html/public!g' /etc/apache2/apache2.conf /etc/apache2/sites-available/*.conf

# Berechtigungen (wenn gewünscht)
RUN chown -R www-data:www-data /var/www/html
