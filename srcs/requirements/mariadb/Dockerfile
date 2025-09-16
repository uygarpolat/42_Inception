FROM debian:bullseye

# Install MariaDB and required packages
RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/
COPY tools/entrypoint.sh /usr/local/bin/

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create necessary directories
RUN mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql

# Set proper permissions
RUN chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql

EXPOSE 3306

ENTRYPOINT ["entrypoint.sh"]


