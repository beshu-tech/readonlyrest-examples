#!/bin/bash -e

cd /scripts

for script in *.sh; do
  if [ -f "$script" ]; then
    echo "Running $script..."
    bash "$script"
    echo "--------------------------------"
  fi
done

touch /tmp/init_done
tail -f /dev/null
