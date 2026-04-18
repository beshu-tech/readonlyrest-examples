#!/bin/bash -x
#
# Generates continuous HTTP traffic against demo-app so APM traces and errors
# appear in Kibana without any manual interaction.
# ~10% of requests hit /error to produce a visible error rate in APM.

while true; do
  RAND=$(( RANDOM % 10 + 1 ))

  if [ "$RAND" -le 1 ]; then
    URL="http://demo-app:3000/error"
  else
    URL="http://demo-app:3000"
  fi

  curl -s -o /dev/null -w "%{http_code}" "$URL"

  sleep 5
done
