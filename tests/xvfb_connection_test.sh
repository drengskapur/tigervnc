#!/bin/bash
# TigerVNC connection test with Xvfb

# Start Xvfb with a virtual display
Xvfb :1 -screen 0 1024x768x24 &
XVFB_PID=$!

# Wait for Xvfb to initialize
sleep 2

# Start TigerVNC server on the virtual display
tigervncserver :1 -localhost -SecurityTypes None -geometry 1024x768
VNC_CMD="tigervncviewer"

# Wait for VNC server to initialize
sleep 3

# Test connection with viewer in non-interactive mode
$VNC_CMD -listen 0 localhost:1 &
VIEWER_PID=$!

# Run a simple graphical test command
DISPLAY=:1 xterm -e "echo 'TigerVNC Test Successful' > /tmp/tigervnc_test.log" &
TEST_PID=$!

# Wait and check if test succeeded
sleep 5
if [ -f /tmp/tigervnc_test.log ] && grep -q "TigerVNC Test Successful" /tmp/tigervnc_test.log; then
  echo "✅ TigerVNC connection test passed"
  RESULT=0
else
  echo "❌ TigerVNC connection test failed"
  RESULT=1
fi

# Cleanup
kill $TEST_PID $VIEWER_PID
tigervncserver -kill :1
kill $XVFB_PID
rm -f /tmp/tigervnc_test.log

exit $RESULT 