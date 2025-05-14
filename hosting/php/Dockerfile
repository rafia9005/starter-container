FROM php:8.2-fpm
RUN docker-php-ext-install mysqli pdo pdo_mysql

WORKDIR /var/www/html
RUN apt-get update && apt-get install -y libpng-dev libjpeg-dev libfreetype6-dev
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd
