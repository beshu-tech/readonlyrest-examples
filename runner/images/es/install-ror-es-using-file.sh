#!/bin/bash -e

function greater_than_or_equal() {
  # Strip the -pre part (or any suffix starting with -) from both versions
  version_1=$(echo "$1" | sed 's/-pre.*//')
  version_2=$(echo "$2" | sed 's/-pre.*//')
  [ "$version_1" = "$(echo -e "$version_1\n$version_2" | sort -V | tail -n 1)" ];
}

if [[ -z "$ES_VERSION" ]]; then
  echo "No ES_VERSION variable is set"
  exit 1
fi

echo "Installing ES ROR from file..."
/usr/share/elasticsearch/bin/elasticsearch-plugin install --batch file:///tmp/ror.zip
ROR_VERSION=$(unzip -p /tmp/ror.zip plugin-descriptor.properties | grep -oP '^version=\K.*')

if [[ ! -v ROR_VERSION || -z "$ROR_VERSION" ]]; then
  echo "No ROR_VERSION variable is set"
  exit 2
fi

echo "Patching ES ROR $ROR_VERSION..."

# Set Java path based on ES version
if greater_than_or_equal "$ES_VERSION" "7.0.0"; then
  JAVA_BIN_PATH="/usr/share/elasticsearch/jdk/bin/java"
elif greater_than_or_equal "$ES_VERSION" "6.7.0"; then
  JAVA_BIN_PATH="$JAVA_HOME/bin/java"
else
  echo "Unsupported ES version: $ES_VERSION"
  exit 1
fi

# Set OPTIONS based on ROR version
if greater_than_or_equal "$ROR_VERSION" "1.64.0"; then
  OPTIONS="--I_UNDERSTAND_AND_ACCEPT_ES_PATCHING=yes"
else
  OPTIONS=""
fi

$JAVA_BIN_PATH -jar /usr/share/elasticsearch/plugins/readonlyrest/ror-tools.jar patch $OPTIONS
echo "DONE!"