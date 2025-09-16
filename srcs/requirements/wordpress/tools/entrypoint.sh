#!/bin/bash

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
until mysql -h mariadb -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1" >/dev/null 2>&1; do
    echo "Waiting for MariaDB to be ready..."
    sleep 2
done

echo "MariaDB is ready!"

# Install WordPress core from image cache if docroot is missing core
if [ ! -d /var/www/html/wp-includes ]; then
    echo "Populating WordPress core from image cache..."
    cp -r /usr/src/wordpress/* /var/www/html/
    # Ensure proper ownership for web writes
    chown -R www-data:www-data /var/www/html
    # Create wp-config.php with DB env expansion and literal PHP superglobals (if not present)
    cat > /var/www/html/wp-config.php << EOF
<?php
define('DB_NAME', '$WORDPRESS_DB_NAME');
define('DB_USER', '$WORDPRESS_DB_USER');
define('DB_PASSWORD', '$WORDPRESS_DB_PASSWORD');
define('DB_HOST', '$WORDPRESS_DB_HOST');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

// Respect reverse proxy headers for HTTPS and port
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
if (isset(\$_SERVER['HTTP_X_FORWARDED_PORT'])) {
    \$_SERVER['SERVER_PORT'] = \$_SERVER['HTTP_X_FORWARDED_PORT'];
}
define('FORCE_SSL_ADMIN', true);

define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');

\$table_prefix = 'wp_';

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
EOF

    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    
    echo "WordPress core populated."
fi

# Configure WordPress if not already configured
if [ ! -f /var/www/html/.configured ]; then
    echo "Configuring WordPress..."
    
    # Wait a bit for WordPress to be ready
    sleep 5
    
    # Create admin user and configure WordPress
    cd /var/www/html
    
    # Derive public https base URL
    if [ -z "${PUBLIC_HTTPS_PORT}" ]; then
        PUBLIC_HTTPS_PORT=443
    fi
    if [ "${PUBLIC_HTTPS_PORT}" = "443" ]; then
        HTTPS_PORT_SUFFIX=""
    else
        HTTPS_PORT_SUFFIX=":${PUBLIC_HTTPS_PORT}"
    fi

    # Create admin user using WP-CLI
    wp core install --allow-root \
        --url=https://${DOMAIN_NAME}${HTTPS_PORT_SUFFIX} \
        --title="${WORDPRESS_TITLE}" \
        --admin_user=${WORDPRESS_ADMIN_USER} \
        --admin_password=${WORDPRESS_ADMIN_PASSWORD} \
        --admin_email=${WORDPRESS_ADMIN_EMAIL} \
        --skip-email
    
    # Configure WordPress settings
    wp option update --allow-root blogname "${WORDPRESS_TITLE}"
    wp option update --allow-root blogdescription "A WordPress site for the Inception project"
    wp option update --allow-root home "https://${DOMAIN_NAME}${HTTPS_PORT_SUFFIX}"
    wp option update --allow-root siteurl "https://${DOMAIN_NAME}${HTTPS_PORT_SUFFIX}"
    
    # Set up permalinks
    wp rewrite structure --allow-root '/%postname%/'
    wp rewrite flush --allow-root
    
    # Create a sample page
    wp post create --allow-root \
        --post_type=page \
        --post_title="Welcome to Inception" \
        --post_content="This is a WordPress site running on Docker with Nginx, MariaDB, and PHP-FPM." \
        --post_status=publish
    
    # Create regular user
    wp user create --allow-root \
        ${WORDPRESS_USER} \
        ${WORDPRESS_USER_EMAIL} \
        --user_pass=${WORDPRESS_USER_PASSWORD} \
        --role=author
    
    # Mark as configured
    touch /var/www/html/.configured
    
    echo "WordPress configured successfully!"
    echo "Admin credentials:"
    echo "Username: ${WORDPRESS_ADMIN_USER}"
    echo "Password: ${WORDPRESS_ADMIN_PASSWORD}"
    echo "Regular user credentials:"
    echo "Username: ${WORDPRESS_USER}"
    echo "Password: ${WORDPRESS_USER_PASSWORD}"
    echo "Login URL: https://${DOMAIN_NAME}${HTTPS_PORT_SUFFIX}/wp-admin"
fi

# Ensure uploads path exists and is writable on every start
mkdir -p /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content
chmod -R 775 /var/www/html/wp-content/uploads

# Ensure a minimal MU plugin exists to show a Login/Logout link on every page
mkdir -p /var/www/html/wp-content/mu-plugins
cat > /var/www/html/wp-content/mu-plugins/login-link.php << 'PHP'
<?php
/**
 * Plugin Name: Top Login/Logout Link
 * Description: Displays a small Login/Logout button at the top-right of every page.
 */
add_action('wp_body_open', function () {
    $url  = is_user_logged_in() ? wp_logout_url(home_url()) : wp_login_url();
    $text = is_user_logged_in() ? 'Logout' : 'Login';
    echo '<a href="' . esc_url($url) . '" style="position:fixed;top:10px;right:10px;z-index:9999;padding:8px 12px;background:#1e293b;color:#fff;border-radius:4px;text-decoration:none;font:14px/1 sans-serif;">' . esc_html($text) . '</a>';
});
PHP

# Idempotent safety: ensure required users/roles and site URLs on every start
if wp --allow-root --path=/var/www/html core is-installed >/dev/null 2>&1; then
    echo "Ensuring WordPress users and settings..."

    # Compute public HTTPS base URL
    if [ -z "${PUBLIC_HTTPS_PORT}" ]; then
        PUBLIC_HTTPS_PORT=443
    fi
    if [ "${PUBLIC_HTTPS_PORT}" = "443" ]; then
        HTTPS_PORT_SUFFIX=""
    else
        HTTPS_PORT_SUFFIX=":${PUBLIC_HTTPS_PORT}"
    fi

    # Ensure admin exists and has administrator role
    wp --allow-root --path=/var/www/html user get "$WORDPRESS_ADMIN_USER" >/dev/null 2>&1 || \
      wp --allow-root --path=/var/www/html user create "$WORDPRESS_ADMIN_USER" "$WORDPRESS_ADMIN_EMAIL" --role=administrator --user_pass="$WORDPRESS_ADMIN_PASSWORD"
    wp --allow-root --path=/var/www/html user update "$WORDPRESS_ADMIN_USER" --role=administrator >/dev/null 2>&1 || true

    # Ensure regular user exists and has author role
    wp --allow-root --path=/var/www/html user get "$WORDPRESS_USER" >/dev/null 2>&1 || \
      wp --allow-root --path=/var/www/html user create "$WORDPRESS_USER" "$WORDPRESS_USER_EMAIL" --role=author --user_pass="$WORDPRESS_USER_PASSWORD"
    wp --allow-root --path=/var/www/html user update "$WORDPRESS_USER" --role=author >/dev/null 2>&1 || true

    # Ensure site URL and home match current DOMAIN_NAME and PUBLIC_HTTPS_PORT
    wp --allow-root --path=/var/www/html option update home "https://${DOMAIN_NAME}${HTTPS_PORT_SUFFIX}" >/dev/null 2>&1 || true
    wp --allow-root --path=/var/www/html option update siteurl "https://${DOMAIN_NAME}${HTTPS_PORT_SUFFIX}" >/dev/null 2>&1 || true
fi

# Start PHP-FPM
echo "Starting PHP-FPM..."
exec php-fpm7.4 -F
