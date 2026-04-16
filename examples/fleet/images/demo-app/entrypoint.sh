#!/bin/bash -e

echo "Waiting for APM Server to be ready at https://apm-agent:8200 ..."
until curl -fksS --cacert /certs/ca.crt https://apm-agent:8200/ >/dev/null 2>&1; do
  sleep 5
done
echo "APM Server is ready."

exec node /example-app/app.js
