#!/bin/sh
set -e

echo "==> Starting Sidekiq..."
exec bundle exec sidekiq -C config/sidekiq.yml
