#!/bin/bash
# TigerVNC connection test

set -e

# Function to test VNC connection
test_vnc_connection() {
  local container_name=$1
  local vnc_port=$2
  local novnc_port=$3
  
  echo "Testing connection to $container_name..."
  
  # Check if container is running
  if ! docker ps | grep -q $container_name; then
    echo "❌ Container $container_name is not running"
    return 1
  fi
  
  # Test VNC port
  if nc -z localhost $vnc_port; then
    echo "✅ VNC port $vnc_port is open"
  else
    echo "❌ VNC port $vnc_port is not accessible"
    return 1
  fi
  
  # Test noVNC port
  if curl -s http://localhost:$novnc_port > /dev/null; then
    echo "✅ noVNC web interface on port $novnc_port is accessible"
  else
    echo "❌ noVNC web interface on port $novnc_port is not accessible"
    return 1
  fi
  
  # Check container logs for errors
  if docker logs $container_name 2>&1 | grep -i "error\|fatal\|failed"; then
    echo "⚠️ Found errors in container logs"
  else
    echo "✅ No errors found in container logs"
  fi
  
  echo "✅ Connection test for $container_name passed"
  return 0
}

# Start container if not already running
if ! docker ps | grep -q vnc-tigervnc-1; then
  echo "Starting TigerVNC container..."
  docker-compose up -d tigervnc
  sleep 10  # Give container time to start
fi

# Test TigerVNC container
echo "=== Testing TigerVNC ==="
test_vnc_connection "vnc-tigervnc-1" 5901 6080
TIGER_RESULT=$?

# Summary
echo "=== Test Summary ==="
if [ $TIGER_RESULT -eq 0 ]; then
  echo "TigerVNC: PASSED"
  exit 0
else
  echo "TigerVNC: FAILED"
  exit 1
fi 