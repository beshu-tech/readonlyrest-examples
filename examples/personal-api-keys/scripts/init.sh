#!/bin/bash -ex

# `bash init.sh` (how cluster-initializer invokes this) ignores the shebang
# flags, so set them here.
set -exo pipefail

source /usr/local/lib/ror-utils.sh

createIndex "logstash-sales-2026" && generate_log_documents 20 | putDocument "logstash-sales-2026"

createIndex "logstash-finance-2026" && generate_log_documents 20 | putDocument "logstash-finance-2026"
