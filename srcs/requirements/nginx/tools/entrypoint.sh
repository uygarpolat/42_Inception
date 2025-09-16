#!/bin/bash

# Generate SSL certificate
if [ ! -f /etc/nginx/ssl/certificate.crt ]; then
    echo "Generating SSL certificate for ${DOMAIN_NAME}..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/private.key \
        -out /etc/nginx/ssl/certificate.crt \
        -subj "/C=FR/ST=France/L=Paris/O=42/OU=Inception/CN=${DOMAIN_NAME}"
fi

# Compute HTTPS port suffix and export defaults
if [ -z "${PUBLIC_HTTPS_PORT}" ]; then
    PUBLIC_HTTPS_PORT=443
fi

if [ "${PUBLIC_HTTPS_PORT}" = "443" ]; then
    HTTPS_PORT_SUFFIX=""
else
    HTTPS_PORT_SUFFIX=":${PUBLIC_HTTPS_PORT}"
fi
export PUBLIC_HTTPS_PORT
export HTTPS_PORT_SUFFIX

# Substitute environment variables in nginx configuration
echo "Substituting environment variables in nginx configuration..."
envsubst '${DOMAIN_NAME} ${PUBLIC_HTTPS_PORT} ${HTTPS_PORT_SUFFIX}' < /etc/nginx/nginx.conf > /tmp/nginx.conf
mv /tmp/nginx.conf /etc/nginx/nginx.conf

# Start Nginx
exec nginx -g "daemon off;"
