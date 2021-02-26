#!/bin/bash

IP1="192.168.66.60"
IP2="192.168.66.61"

PORT="6666"

# Setup IP addresses
ip addr add $IP1 dev eth0
ip addr add $IP2 dev eth1

# Start WebServer
PYTHONUNBUFFERED=x python3 -m http.server $PORT &> http.server.log & echo $! > http.server.pid

# Test connectivity
curl $IP1:$PORT/test60-before > /dev/null
curl $IP2:$PORT/test60-before > /dev/null

# TODO - Change policy
#
#

# Test connectivity
curl $IP1:$PORT/test60-after > /dev/null
curl $IP2:$PORT/test60-after > /dev/null

# Stop WebServer
kill $(cat http.server.pid)

# Check WebServer Logs
cat http.server.log


