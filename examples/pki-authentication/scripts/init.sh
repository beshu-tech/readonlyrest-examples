#!/bin/bash -ex

set -o pipefail

source /usr/local/lib/ror-utils.sh

createIndex "logs-2026" && generate_log_documents 5 | putDocument "logs-2026"
