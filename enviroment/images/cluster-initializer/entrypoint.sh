#!/bin/bash -e

cd /scripts

if [ -f "init.sh" ]; then
  echo "Running init.sh..."
  bash init.sh
  echo "--------------------------------"
fi

touch /tmp/init_done
tail -f /dev/null
