#!/bin/sh
set -e

if [ "$SERVICE_TYPE" = "sidekiq" ]; then
  echo "==> Starting Sidekiq..."
  exec bundle exec sidekiq -C config/sidekiq.yml
else
  rm -f /app/tmp/pids/server.pid
  echo "==> Running database migrations..."
  bundle exec rails db:chatwoot_prepare
  echo "==> Updating branding configs..."
  bundle exec rails runner "
    { 'INSTALLATION_NAME' => 'Fluxo Digital Tech', 'BRAND_NAME' => 'Fluxo Digital Tech', 'BRAND_URL' => 'https://fluxodigitaltech.com.br', 'WIDGET_BRAND_URL' => 'https://fluxodigitaltech.com.br' }.each do |name, value|
      config = InstallationConfig.find_by(name: name)
      next unless config

      config.value = value
      config.save!
    end
  "
  export INSTALLATION_PRICING_PLAN="${INSTALLATION_PRICING_PLAN:-enterprise}"
  export INSTALLATION_PRICING_PLAN_QUANTITY="${INSTALLATION_PRICING_PLAN_QUANTITY:-10000}"
  export INSTALLATION_IDENTIFIER="${INSTALLATION_IDENTIFIER:-e04t63ee-5gg8-4b94-8914-ed8137a7d938}"
  echo "==> Syncing installation metadata from environment..."
  bundle exec rails installation_configs:sync_from_env
  echo "==> Starting Rails server..."
  exec bundle exec rails server -b 0.0.0.0 -p 3000
fi
