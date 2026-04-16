#!/bin/bash -e

determine_ror_es_dockerfile () {
  read_es_version

  while true; do
    read -p "Use ReadonlyREST ES:
1. From API
2. From FILE

Your choice: " choice

    case "$choice" in
      1 )
        echo "ROR_ES_PLUGIN_SOURCE=API" >> .env

        read_ror_es_version
        break
        ;;
      2 )
        echo "ROR_ES_PLUGIN_SOURCE=LOCAL_FILE" >> .env
        read_es_ror_file_path
        break
        ;;
      * )
        echo "There is no such option to pick. Please try again ..."
        continue
        ;;
    esac
  done
}

read_es_version () {
  while true; do
    read -p "Enter ES version: " esVersion
    if [ -z "$esVersion" ]; then
      echo "Empty ES version. Please try again ..."
      continue
    fi

    echo "ES_VERSION=$esVersion" >> .env
    break
  done
}

read_ror_es_version () {
  while true; do
    read -p "Enter ReadonlyREST ES version: " rorVersion
    if [ -z "$rorVersion" ]; then
      echo "Empty ReadonlyREST ES version. Please try again ..."
      continue
    fi

    echo "ROR_ES_VERSION=$rorVersion" >> .env
    break
  done
}

read_es_ror_file_path () {
  while true; do
    read -p "Enter ReadonlyREST ES file path (it has to be placed in $(dirname "$0")): " path
    if [ -f "$path" ]; then
      echo "ROR_ES_FILE=$path" >> .env
      break
    else
      echo "Cannot find file $path. Please try again ..."
      continue
    fi
  done
}

determine_ror_kbn_dockerfile () {
  read_kbn_version

  while true; do
    read -p "Use ReadonlyREST KBN:
 1. From API
 2. From FILE

Your choice: " choice

    case "$choice" in
      1 )
        echo "ROR_KBN_PLUGIN_SOURCE=API" >> .env

        read_ror_kbn_version
        break
        ;;
      2 )
        echo "ROR_KBN_PLUGIN_SOURCE=LOCAL_FILE" >> .env
        read_kbn_ror_file_path
        break
        ;;
      * )
        echo "There is no such option to pick. Please try again ..."
        continue
        ;;
    esac
  done
}

read_kbn_version () {
  while true; do
    read -p "Enter Kibana version: " kbnVersion
    if [ -z "$kbnVersion" ]; then
      echo "Empty Kibana version. Please try again ..."
      continue
    fi

    echo "KBN_VERSION=$kbnVersion" >> .env
    break
  done
}

read_ror_kbn_version () {
  while true; do
    read -p "Enter ReadonlyREST Kibana version: " rorVersion
    if [ -z "$rorVersion" ]; then
      echo "Empty ReadonlyREST Kibana version. Please try again ..."
      continue
    fi

    echo "ROR_KBN_VERSION=$rorVersion" >> .env
    break
  done
}

read_kbn_ror_file_path () {
  while true; do
    read -p "Enter ReadonlyREST KBN file path (it has to be placed in $(dirname "$0")): " path
    if [ -f "$path" ]; then
      echo "ROR_KBN_FILE=$path" >> .env
      break
    else
      echo "Cannot find file $path. Please try again ..."
      continue
    fi
  done
}
