FROM debian:bullseye

# Install Nginx and required packages
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY conf/ /etc/nginx/
COPY tools/entrypoint.sh /usr/local/bin/

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

EXPOSE 443

ENTRYPOINT ["entrypoint.sh"]
