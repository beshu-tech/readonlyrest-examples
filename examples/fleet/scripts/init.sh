#!/bin/bash -ex

set -o pipefail

source /usr/local/lib/ror-utils.sh

createIndex "frontend_logs" && generate_log_documents 5 | putDocument "frontend_logs"
createIndex "business_logs" && generate_log_documents 5 | putDocument "business_logs"
