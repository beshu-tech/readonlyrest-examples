#!/bin/bash -e

source "$(dirname "$0")/collect-info-about-ror-es-kbn-without-hints-common.sh"

> .env
echo "-----------------"
determine_ror_es_dockerfile
echo "-----------------"
determine_ror_kbn_dockerfile
echo "-----------------"
