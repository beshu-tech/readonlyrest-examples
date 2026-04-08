#!/bin/bash -ex

set -o pipefail

source /usr/local/lib/ror-utils.sh

createDataStream "logs-frontend-dev" && generate_log_documents 100 | putDocument "logs-frontend-dev"
createDataStream "logs-business-dev" && generate_log_documents 100 | putDocument "logs-business-dev"
createDataStream "logs-system-dev" && generate_log_documents 100 | putDocument "logs-system-dev"

createIndex "data-business-index" && generate_log_documents 100 | putDocument "data-business-index"
