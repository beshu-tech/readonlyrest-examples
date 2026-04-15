#!/bin/bash -e

echo "Waiting 10 seconds for APM Server to be fully ready..."
sleep 10

exec node /example-app/app.js
