#!/bin/bash -ex

set -o pipefail

source /usr/local/lib/ror-utils.sh

createIndex "frontend-logs" && generate_log_documents 5 | putDocument "frontend-logs"
createIndex "business-reports" && generate_log_documents 5 | putDocument "business-reports"
