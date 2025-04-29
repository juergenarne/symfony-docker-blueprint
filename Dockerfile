FROM php:8.4-apache

# Install msmtp as lightweight sendmail replacement
RUN apt-get update && \
    apt-get install -y msmtp msmtp-mta \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libmagickwand-dev \
    imagemagick \
    unzip \
    git \
    mariadb-client \
    --no-install-recommends \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-install gd mysqli zip intl exif \
    && if ! pecl list | grep imagick; then pecl install imagick; fi \
    && docker-php-ext-enable imagick \
    && if ! php -m | grep -i redis; then pecl install redis && docker-php-ext-enable redis; fi \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache mod_rewrite for WordPress permalinks
RUN a2enmod rewrite

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Link msmtp to sendmail path
RUN ln -sf /usr/bin/msmtp /usr/sbin/sendmail

COPY msmtprc /etc/msmtprc
RUN chmod 600 /etc/msmtprc
