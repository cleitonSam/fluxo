#!/bin/sh
set -e

if [ "$SERVICE_TYPE" = "sidekiq" ]; then
  echo "==> Starting Sidekiq..."
  exec bundle exec sidekiq -C config/sidekiq.yml
else
  rm -f /app/tmp/pids/server.pid
  echo "==> Running database migrations..."
  bundle exec rails db:chatwoot_prepare
  echo "==> Updating installation configs..."
  bundle exec rails runner "
    enterprise_features = %w[
      assignment_v2
      advanced_assignment
      audit_logs
      captain_integration
      captain_integration_v2
      channel_voice
      conversation_required_attributes
      csat_review_notes
      custom_roles
      disable_branding
      saml
      sla
    ]

    {
      'INSTALLATION_NAME' => ENV.fetch('INSTALLATION_NAME', 'Fluxo Digital Tech'),
      'BRAND_NAME' => ENV.fetch('BRAND_NAME', 'Fluxo Digital Tech'),
      'BRAND_URL' => ENV.fetch('BRAND_URL', 'https://fluxodigitaltech.com.br'),
      'WIDGET_BRAND_URL' => ENV.fetch('WIDGET_BRAND_URL', 'https://fluxodigitaltech.com.br'),
      'INSTALLATION_PRICING_PLAN' => ENV.fetch('INSTALLATION_PRICING_PLAN', 'enterprise'),
      'INSTALLATION_PRICING_PLAN_QUANTITY' => ENV.fetch('INSTALLATION_PRICING_PLAN_QUANTITY', '10000').to_i,
      'INSTALLATION_IDENTIFIER' => ENV.fetch('INSTALLATION_IDENTIFIER', 'e04t63ee-5gg8-4b94-8914-ed8137a7d938')
    }.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.save!
    end

    account_feature_defaults = YAML.safe_load(File.read(Rails.root.join('config/features.yml')))
    account_feature_defaults.each do |feature|
      feature['enabled'] = true if enterprise_features.include?(feature['name'])
    end

    feature_defaults_config = InstallationConfig.find_or_initialize_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    feature_defaults_config.value = account_feature_defaults
    feature_defaults_config.locked = true
    feature_defaults_config.save!

    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each do |account|
        account.enable_features(*enterprise_features)
        account.save! if account.changed?
      end
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
