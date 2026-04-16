#!/bin/sh -e

if [ "$REWRITE_BASE_PATH_BY_KIBANA" = "true" ]; then
  exec httpd -DREWRITE_BASE_PATH_BY_KIBANA -DFOREGROUND
else
  exec httpd -DFOREGROUND
fi
