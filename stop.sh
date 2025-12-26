#!/bin/bash

echo "[cyber_erp] Stopping Cyber ERP..."

# Kill Phoenix server
lsof -ti:4000 | xargs kill -9 2>/dev/null || true

# Kill any remaining beam processes for this project
pkill -f "beam.*cyber_erp" || true

echo "[cyber_erp] Stopped successfully"
