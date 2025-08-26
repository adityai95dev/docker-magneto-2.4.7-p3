#!/bin/bash
set -e
source .env

# 🧠 Generate random admin URI
export ADMIN_URI="admin_$(tr -dc a-z0-9 </dev/urandom | head -c 6)"
export ADMIN_URI_LOG="./admin-uri.txt"

echo "🔄 Running Magento setup script..."
echo "🧩 Random Admin URI will be: $ADMIN_URI"

# Run inside PHP container
docker exec -i \
  -e MAGENTO_VERSION="$MAGENTO_VERSION" \
  -e MAGENTO_BASE_URL="$MAGENTO_BASE_URL" \
  -e DB_HOST="$DB_HOST" \
  -e DB_NAME="$DB_NAME" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e ADMIN_FIRSTNAME="${ADMIN_FIRSTNAME:-Admin}" \
  -e ADMIN_LASTNAME="${ADMIN_LASTNAME:-User}" \
  -e ADMIN_EMAIL="$ADMIN_EMAIL" \
  -e ADMIN_USERNAME="$ADMIN_USERNAME" \
  -e ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  -e INSTALL_SAMPLE_DATA="$INSTALL_SAMPLE_DATA" \
  -e MAGENTO_USERNAME="$MAGENTO_USERNAME" \
  -e MAGENTO_PASSWORD="$MAGENTO_PASSWORD" \
  -e ADMIN_URI="$ADMIN_URI" \
  clientb-08-php bash <<EOF

echo "📁 Changing to Magento directory"
cd /var/www/html

# 🧹 Clean old content
echo "🧹 Cleaning Magento directory..."
shopt -s dotglob
rm -rf -- *

echo "🔐 Setting up Composer authentication..."
export COMPOSER_AUTH='{
  "http-basic": {
    "repo.magento.com": {
      "username": "'"${MAGENTO_USERNAME}"'",
      "password": "'"${MAGENTO_PASSWORD}"'"
    }
  }
}'

echo "⬇️ Downloading Magento version ${MAGENTO_VERSION}..."
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition="${MAGENTO_VERSION}" .

echo "⚙️ Installing Magento..."
bin/magento setup:install \
  --base-url="${MAGENTO_BASE_URL}" \
  --db-host="${DB_HOST}" \
  --db-name="${DB_NAME}" \
  --db-user="${DB_USER}" \
  --db-password="${DB_PASSWORD}" \
  --admin-firstname="${ADMIN_FIRSTNAME}" \
  --admin-lastname="${ADMIN_LASTNAME}" \
  --admin-email="${ADMIN_EMAIL}" \
  --admin-user="${ADMIN_USERNAME}" \
  --admin-password="${ADMIN_PASSWORD}" \
  --backend-frontname="${ADMIN_URI}" \
  --language=en_US \
  --currency=USD \
  --timezone=Asia/Kolkata \
  --use-rewrites=1 \
  --search-engine=opensearch \
  --opensearch-host=opensearch \
  --opensearch-port=9200

# 📦 Optional: Deploy sample data if required
if [ "\$INSTALL_SAMPLE_DATA" = "true" ]; then
  echo "📦 Deploying sample data..."
  bin/magento sampledata:deploy
  bin/magento setup:upgrade
fi

echo "🔒 Disabling 2FA modules..."
bin/magento module:disable Magento_TwoFactorAuth Magento_AdminAdobeImsTwoFactorAuth

echo "🔧 Setting base URLs again..."
bin/magento setup:store-config:set --base-url="${MAGENTO_BASE_URL}/"
bin/magento setup:store-config:set --base-url-secure="${MAGENTO_BASE_URL}/"

echo "🧹 Cleaning cache, compiling DI, and deploying static content..."
bin/magento cache:flush
bin/magento setup:di:compile
bin/magento setup:static-content:deploy -f

echo "👥 Fixing permissions..."
chown -R i95devteam:www-data /var/www/html

echo ""
echo "✅ Magento setup complete!"
echo "🔗 Store URL     : ${MAGENTO_BASE_URL}"
echo "🔐 Admin Login   : ${MAGENTO_BASE_URL}/${ADMIN_URI}"
echo "👤 Admin Username: ${ADMIN_USERNAME}"
echo "🔑 Admin Password: ${ADMIN_PASSWORD}"

EOF

# Save the Admin URI on host
echo "${MAGENTO_BASE_URL}/${ADMIN_URI}" > "$ADMIN_URI_LOG"
echo "📝 Saved Admin URL to $ADMIN_URI_LOG"

