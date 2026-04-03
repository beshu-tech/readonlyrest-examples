#!/bin/bash -e

function greater_than_or_equal() {
  [ "$1" = "$(echo -e "$1\n$2" | sort -V | tail -n 1)" ];
}

if [[ -z "$KBN_VERSION" ]]; then
  echo "No KBN_VERSION variable is set"
  exit 1
fi

echo "Installing KBN ROR $ROR_VERSION..."
if ! greater_than_or_equal "$KBN_VERSION" "7.0.0"; then
  export NODE_OPTIONS="--max-old-space-size=8192" 
fi

if greater_than_or_equal "$KBN_VERSION" "7.11.0" ; then
  /usr/share/kibana/bin/kibana-plugin install file:///tmp/ror.zip
else
  /usr/share/kibana/bin/kibana-plugin install --allow-root file:///tmp/ror.zip
fi

if greater_than_or_equal "$KBN_VERSION" "8.15.0" ; then
  echo "Patching KBN $KBN_VERSION (ROR $ROR_VERSION)..."
  /usr/share/kibana/node/glibc-217/bin/node plugins/readonlyrestkbn/ror-tools.js patch --I_UNDERSTAND_AND_ACCEPT_KBN_PATCHING=yes
elif greater_than_or_equal "$KBN_VERSION" "7.9.0" ; then
  echo "Patching KBN $KBN_VERSION (ROR $ROR_VERSION)..."
  /usr/share/kibana/node/bin/node plugins/readonlyrestkbn/ror-tools.js patch --I_UNDERSTAND_AND_ACCEPT_KBN_PATCHING=yes
fi

   if greater_than_or_equal "$KBN_VERSION" "7.9.0"; then
       case "${ROR_LICENSE_EDITION:-}" in
         ENT)
           mv /usr/share/kibana/config/enterprise-ror-newplatform-kibana.yml \
              /usr/share/kibana/config/kibana.yml
           ;;
        PRO)
        mv /usr/share/kibana/config/pro-ror-newplatform-kibana.yml \
                   /usr/share/kibana/config/kibana.yml
            ;;
         FREE)
           mv /usr/share/kibana/config/free-ror-newplatform-kibana.yml \
              /usr/share/kibana/config/kibana.yml
           ;;
         "")
           echo "ERROR: ROR_LICENSE_EDITION is not set" >&2
           exit 1
           ;;
         *)
           echo "ERROR: Unsupported ROR_LICENSE_EDITION='${ROR_LICENSE_EDITION}'" >&2
           exit 2
           ;;
       esac
    else
      mv /usr/share/kibana/config/ror-oldplatform-kibana.yml /usr/share/kibana/config/kibana.yml
      rm -rf /usr/share/kibana/optimize # for some reason we have to remove it and let kibana optimize it on startup
    fi

echo "DONE!"