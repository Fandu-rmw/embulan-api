FROM php:8.2-apache

# Install ekstensi PDO MySQL untuk Laravel
RUN docker-php-ext-install pdo pdo_mysql

# Copy seluruh kodingan ke server
COPY . /var/www/html

# Set izin folder storage & cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Aktifkan mod_rewrite Apache untuk routing Laravel
RUN a2enmod rewrite
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/conf-available/*.conf