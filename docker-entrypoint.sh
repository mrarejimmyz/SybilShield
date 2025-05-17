#!/bin/bash
set -e

# Docker entrypoint script for AptosSybilShield

# Function to wait for a service to be ready
wait_for_service() {
  local host="$1"
  local port="$2"
  local service="$3"
  local timeout="${4:-30}"
  
  echo "Waiting for $service to be ready at $host:$port..."
  for i in $(seq 1 $timeout); do
    if nc -z "$host" "$port"; then
      echo "$service is ready!"
      return 0
    fi
    echo "Waiting for $service... $i/$timeout"
    sleep 1
  done
  echo "Timeout reached waiting for $service at $host:$port"
  return 1
}

# Create data directories if they don't exist
mkdir -p /app/data
mkdir -p /app/logs

# Set up Python path
export PYTHONPATH=/app:$PYTHONPATH

# Command router
case "$1" in
  api)
    echo "Starting API server..."
    cd /app/api/endpoints
    exec python3 api_server.py
    ;;
    
  ml)
    echo "Starting ML service..."
    # Wait for API to be ready
    wait_for_service api 8000 "API Server" 60
    cd /app/off-chain/ml
    exec python3 -m data.indexer_integration
    ;;
    
  dashboard)
    echo "Starting Dashboard..."
    # Wait for API to be ready
    wait_for_service api 8000 "API Server" 60
    cd /app/dashboard/frontend
    exec npm start
    ;;
    
  compile-move)
    echo "Compiling Move modules..."
    cd /app/on-chain/move
    exec aptos move compile --named-addresses aptos_sybil_shield=default
    ;;
    
  test)
    echo "Running tests..."
    cd /app
    # Run Python tests
    python3 -m pytest off-chain/ml/tests
    # Run Move tests
    cd /app/on-chain/move
    aptos move test
    echo "All tests passed!"
    ;;
    
  shell)
    echo "Starting shell..."
    exec /bin/bash
    ;;
    
  *)
    echo "Unknown command: $1"
    echo "Available commands: api, ml, dashboard, compile-move, test, shell"
    exit 1
    ;;
esac
