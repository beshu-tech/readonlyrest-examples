determine_ror_es_dockerfile () {
  ROR_API_RESPONSE=$1

  ES_VERSIONS_ARR=($(echo "$ROR_API_RESPONSE" | jq .[0] | jq 'to_entries | map(.value)' | jq .[].esVersions.es -cr | jq .[] -cr | uniq))

  # Only versions without "-" and suffix are taken into account when determining the default version
  ES_VERSIONS_ARR_FILTERED=()
  for v in "${ES_VERSIONS_ARR[@]}"; do
    if [[ "$v" != *"-"* ]]; then
      ES_VERSIONS_ARR_FILTERED+=("$v")
    fi
  done

  DEFAULT_ES_VERSION=$(echo ${ES_VERSIONS_ARR_FILTERED[0]})
  ES_VERSIONS_STR=$(printf "%s," "${ES_VERSIONS_ARR[@]}")

  read_es_version "$DEFAULT_ES_VERSION" "$ES_VERSIONS_STR"
  source .env

  PICKED_ES_VERSION=$ES_VERSION
  DEFAULT_CHOICE=1

  while true; do
    read -p "Use ES ROR (default $DEFAULT_CHOICE):
1. From API
2. From FILE

Your choice: " choice

    if [ -z "$choice" ]; then
      choice=$DEFAULT_CHOICE
    fi

    case "$choice" in
      1 )
        echo "ES_DOCKERFILE=Dockerfile-use-ror-binaries-from-api" >> .env

        ES_ROR_VERSIONS_ARR=($(echo "$ROR_API_RESPONSE" | jq .[0] | jq 'to_entries | map(.value)' | jq .[].pluginVersion -cr))
        DEFAULT_ES_ROR_VERSION=$(echo ${ES_ROR_VERSIONS_ARR[0]})
        ES_ROR_VERSIONS_STR=$(printf "%s," "${ES_ROR_VERSIONS_ARR[@]}")

        read_ror_es_version "$DEFAULT_ES_ROR_VERSION" "$ES_ROR_VERSIONS_STR" "$ROR_API_RESPONSE" "$PICKED_ES_VERSION"
        break
        ;;
      2 )
        echo "ES_DOCKERFILE=Dockerfile-use-ror-binaries-from-file" >> .env
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
  DEFAULT_ES_VERSION=$1
  AVAILABLE_ES_VERSIONS=$2

  while true; do
    read -p "Enter Elasticsearch version (default: $DEFAULT_ES_VERSION): " esVersion
    if [ -z "$esVersion" ]; then
      echo "ES_VERSION=$DEFAULT_ES_VERSION" >> .env
      break
    fi

    if [[ $AVAILABLE_ES_VERSIONS == *"$esVersion"* ]]; then
      echo "ES_VERSION=$esVersion" >> .env
      break
    else
      echo "ES $esVersion is not available. Please try again ..."
      continue
    fi
  done
}

read_ror_es_version () {
  DEFAULT_ES_ROR_VERSION=$1
  AVAILABLE_ES_ROR_VERSIONS=$2
  ROR_API_RESPONSE=$3
  PICKED_ES_VERSION=$4

  while true; do
    read -p "Enter ROR Elasticsearch version (default: $DEFAULT_ES_ROR_VERSION): " rorVersion
    if [ -z "$rorVersion" ]; then
      echo "ROR_ES_VERSION=$DEFAULT_ES_ROR_VERSION" >> .env
      break
    fi

    if [[ $AVAILABLE_ES_ROR_VERSIONS == *"$rorVersion"* ]]; then
      ES_VERSIONS_ARR=($(echo "$ROR_API_RESPONSE" | jq .[0] | jq '."'$rorVersion'".esVersions.es[]' -cr))
      for i in "${ES_VERSIONS_ARR[@]}"
      do
        if [[ $i == "$PICKED_ES_VERSION" ]]; then
          echo "ROR_ES_VERSION=$rorVersion" >> .env
          break 2
        fi
      done

      echo "ROR Elasticsearch $rorVersion is not available for Elasticsearch $PICKED_ES_VERSION. Please try again ..."
      continue
    else
      echo "ROR Elasticsearch $rorVersion is not available. Please try again ..."
      continue
    fi
  done
}

read_es_ror_file_path () {
  while true; do
    read -p "Enter ROR Elasticsearch file path (it has to be placed in $(dirname "$0")): " path
    if [ -f "$path" ]; then
      echo "ES_ROR_FILE=$path" >> .env
      break
    else
      echo "Cannot find file $path. Please try again ..."
      continue
    fi
  done
}

determine_ror_kbn_dockerfile () {
  ROR_API_RESPONSE=$1
  PICKED_ES_VERSION=$2
  PICKED_ROR_ES_VERSION=$3

  KBN_VERSIONS_ARR=($(echo "$ROR_API_RESPONSE" | jq .[0] | jq 'to_entries | map(.value)' | jq .[].esVersions.kbn_universal -cr | jq .[] -cr | uniq))
  DEFAULT_KBN_VERSION=$PICKED_ES_VERSION
  KBN_VERSIONS_STR=$(printf "%s," "${KBN_VERSIONS_ARR[@]}")

  read_kbn_version "$DEFAULT_KBN_VERSION" "$KBN_VERSIONS_STR"
  source .env
  PICKED_KBN_VERSION=$KBN_VERSION
  DEFAULT_CHOICE=1

  while true; do
    read -p "Use KBN ROR (default $DEFAULT_CHOICE):
 1. From API
 2. From FILE

Your choice: " choice

    if [ -z "$choice" ]; then
      choice=$DEFAULT_CHOICE
    fi

    case "$choice" in
      1 )
        echo "KBN_DOCKERFILE=Dockerfile-use-ror-binaries-from-api" >> .env

        KBN_ROR_VERSIONS_ARR=($(echo "$ROR_API_RESPONSE" | jq .[0] | jq 'to_entries | map(.value)' | jq .[].pluginVersion -cr))
        if [[ " ${KBN_ROR_VERSIONS_ARR[@]} " =~ " ${PICKED_ROR_ES_VERSION} " ]]; then
          DEFAULT_KBN_ROR_VERSION=$PICKED_ROR_ES_VERSION
        else
          DEFAULT_KBN_ROR_VERSION=${KBN_ROR_VERSIONS_ARR[0]}
        fi
        KBN_ROR_VERSIONS_STR=$(printf "%s," "${KBN_ROR_VERSIONS_ARR[@]}")

        read_ror_kbn_version "$DEFAULT_KBN_ROR_VERSION" "$KBN_ROR_VERSIONS_STR" "$ROR_API_RESPONSE" "$PICKED_KBN_VERSION"
        break
        ;;
      2 )
        echo "KBN_DOCKERFILE=Dockerfile-use-ror-binaries-from-file" >> .env
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
  DEFAULT_KBN_VERSION=$1
  AVAILABLE_KBN_VERSIONS=$2

  while true; do
    read -p "Enter Kibana version (default: $DEFAULT_KBN_VERSION): " kbnVersion
    if [ -z "$kbnVersion" ]; then
      echo "KBN_VERSION=$DEFAULT_KBN_VERSION" >> .env
      break
    fi

    if [[ $AVAILABLE_KBN_VERSIONS == *"$kbnVersion"* ]]; then
      echo "KBN_VERSION=$kbnVersion" >> .env
      break
    else
      echo "Kibana $kbnVersion is not available. Please try again ..."
      continue
    fi
  done
}

read_ror_kbn_version () {
  DEFAULT_KBN_ROR_VERSION=$1
  AVAILABLE_KBN_ROR_VERSIONS=$2
  ROR_API_RESPONSE=$3
  PICKED_KBN_VERSION=$4

  while true; do
    read -p "Enter ROR Kibana version (default: $DEFAULT_KBN_ROR_VERSION): " rorVersion
    if [ -z "$rorVersion" ]; then
      echo "ROR_KBN_VERSION=$DEFAULT_KBN_ROR_VERSION" >> .env
      break
    fi

    if [[ $AVAILABLE_KBN_ROR_VERSIONS == *"$rorVersion"* ]]; then
      KBN_VERSIONS_ARR=($(echo "$ROR_API_RESPONSE" | jq .[0] | jq '."'$rorVersion'".esVersions.kbn_universal[]' -cr))
      for i in "${KBN_VERSIONS_ARR[@]}"
      do
        if [[ $i == "$PICKED_KBN_VERSION" ]]; then
          echo "ROR_KBN_VERSION=$rorVersion" >> .env
          break 2
        fi
      done

      echo "ROR Kibana $rorVersion is not available for Kibana $PICKED_KBN_VERSION. Please try again ..."
      continue
    else
      echo "ROR Kibana $rorVersion is not available. Please try again ..."
      continue
    fi
  done
}

read_kbn_ror_file_path () {
  while true; do
    read -p "Enter ROR Kibana file path (it has to be placed in $(dirname "$0")): " path
    if [ -f "$path" ]; then
      echo "KBN_ROR_FILE=$path" >> .env
      break
    else
      echo "Cannot find file $path. Please try again ..."
      continue
    fi
  done
}
