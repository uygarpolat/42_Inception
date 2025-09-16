### Inception (42)

A minimal Docker Compose stack running WordPress (PHP-FPM) behind Nginx with MariaDB. Data is persisted on your host under `~/data`.

Spec reference: [42 Inception subject](https://cdn.intra.42.fr/pdf/pdf/163427/en.subject.pdf)

### Stack

- Nginx (HTTPS, self-signed cert)
- WordPress (PHP-FPM 7.4 + WP-CLI)
- MariaDB 10.x

### Prerequisites

- Docker and Docker Compose plugin
- Port 443 free on your host (Nginx binds to 443)
- Hosts entry for local domain

Add this to `/etc/hosts` (macOS/Linux):

```bash
127.0.0.1 upolat.42.fr
```

Note: A self-signed TLS cert is generated at container start. Your browser will warn about this on your first visit.

### Quick start

1) Create `.env` next to `srcs/docker-compose.yml` (see template below).

2) Build and start:

```bash
make up
```

3) Open the site:

- https://upolat.42.fr
- Admin: `https://upolat.42.fr/wp-admin` (use your admin credentials from `.env`)

### .env template

```dotenv
# MariaDB
MYSQL_ROOT_PASSWORD=change-me-root
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD=change-me-user

# WordPress DB connection (usually mirror MariaDB values)
WORDPRESS_DB_NAME=${MYSQL_DATABASE}
WORDPRESS_DB_USER=${MYSQL_USER}
WORDPRESS_DB_PASSWORD=${MYSQL_PASSWORD}
WORDPRESS_DB_HOST=mariadb:3306

# WordPress site and users
WORDPRESS_TITLE=Inception
WORDPRESS_ADMIN_USER=admin
WORDPRESS_ADMIN_PASSWORD=change-me-admin
WORDPRESS_ADMIN_EMAIL=admin@example.com
WORDPRESS_USER=author
WORDPRESS_USER_PASSWORD=change-me-author
WORDPRESS_USER_EMAIL=author@example.com

# Public domain and port used by Nginx and WordPress URLs
DOMAIN_NAME=upolat.42.fr
PUBLIC_HTTPS_PORT=443
```

Data paths (host):

- MariaDB: `~/data/mariadb`
- WordPress: `~/data/wordpress`

These are bind-mounted via Compose and preserved across restarts.

That’s it! Keep `.env` safe and enjoy your local HTTPS WordPress.


