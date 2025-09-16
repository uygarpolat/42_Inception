FROM debian:bullseye

# Install PHP and required extensions
RUN apt-get update && apt-get install -y \
    php7.4-fpm \
    php7.4-mysql \
    php7.4-curl \
    php7.4-gd \
    php7.4-intl \
    php7.4-mbstring \
    php7.4-xml \
    php7.4-zip \
    php7.4-cli \
    wget \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Pre-fetch WordPress core at build time to avoid runtime network dependency
RUN curl -L https://wordpress.org/latest.tar.gz -o /usr/src/wordpress.tar.gz \
    && mkdir -p /usr/src/wordpress \
    && tar -xzf /usr/src/wordpress.tar.gz -C /usr/src \
    && rm -f /usr/src/wordpress.tar.gz

# Copy configuration files
COPY conf/www.conf /etc/php/7.4/fpm/pool.d/
COPY tools/entrypoint.sh /usr/local/bin/

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create necessary directories
RUN mkdir -p /var/www/html /run/php

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html /run/php

EXPOSE 9000

ENTRYPOINT ["entrypoint.sh"]


