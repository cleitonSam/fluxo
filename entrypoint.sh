#!/bin/sh
set -e

if [ "$SERVICE_TYPE" = "sidekiq" ]; then
  echo "==> Starting Sidekiq..."
  exec bundle exec sidekiq -C config/sidekiq.yml
else
  rm -f /app/tmp/pids/server.pid
  echo "==> Running database migrations..."
  bundle exec rails db:chatwoot_prepare
  echo "==> Starting Rails server..."
  exec bundle exec rails server -b 0.0.0.0 -p 3000
fi
