FROM php:8.4-apache

# Systempakete
RUN apt-get update && apt-get install -y --no-install-recommends \
    msmtp msmtp-mta \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libicu-dev \
    libmagickwand-dev imagemagick \
    libonig-dev \ 
    unzip git mariadb-client \
  && rm -rf /var/lib/apt/lists/*

# PHP-Extensions: GD, intl, zip, exif, mbstring, PDO MySQL, Opcache, Imagick, Redis, (optional) APCu
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-configure intl \
 && docker-php-ext-install -j$(nproc) gd intl zip exif mbstring pdo_mysql opcache \
 && if ! pecl list | grep -qi imagick; then pecl install imagick; fi && docker-php-ext-enable imagick \
 && if ! php -m | grep -qi redis;   then pecl install redis   && docker-php-ext-enable redis;   fi \
 && if ! php -m | grep -qi apcu;    then pecl install apcu    && docker-php-ext-enable apcu;    fi

# Apache: mod_rewrite + DocumentRoot auf /public
RUN a2enmod rewrite \
 && sed -ri 's!DocumentRoot /var/www/html!DocumentRoot /var/www/html/public!g' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's!</VirtualHost>!<Directory /var/www/html/public>\n    AllowOverride All\n    Require all granted\n</Directory>\n</VirtualHost>!g' /etc/apache2/sites-available/000-default.conf

# Optional: eigene php.ini übernehmen (du hast bereits docker/php.ini)
COPY docker/php/php.ini /usr/local/etc/php/conf.d/app.ini

# (Optional) msmtp Konfiguration einspielen, falls vorhanden
# COPY docker/msmtprc /etc/msmtprc
# RUN chown www-data:www-data /etc/msmtprc && chmod 600 /etc/msmtprc

# Composer (falls du im Image bauen willst; sonst weglassen und per Volumes entwickeln)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

# Composer nur ausführen, wenn Symfony-Code vorhanden
RUN if [ -f symfony/composer.json ]; then \
      cd symfony && \
      composer install --no-dev --optimize-autoloader --no-interaction && \
      chown -R www-data:www-data var; \
    else \
      echo "⚠️  Keine Symfony-App gefunden – überspringe Composer install."; \
    fi
 
RUN mkdir -p var/cache var/log && chown -R www-data:www-data var

EXPOSE 80
CMD ["apache2-foreground"]
