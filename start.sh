#!/bin/bash

set -e

echo "[cyber_erp] Starting Cyber ERP..."

# Fix permissions if needed
if [ -d "_build" ]; then
  OWNER=$(stat -c '%U' _build 2>/dev/null || echo "dvg")
  if [ "$OWNER" = "root" ]; then
    echo "[cyber_erp] Fixing file permissions..."
    sudo chown -R dvg:dvg .
  fi
fi

# Get dependencies
echo "[cyber_erp] Installing dependencies..."
mix deps.get

# Run migrations
echo "[cyber_erp] Running database migrations..."
cd apps/cyber_core && mix ecto.migrate && cd ../..

# Start server
echo "[cyber_erp] Starting Phoenix server..."
cd apps/cyber_web && mix phx.server
