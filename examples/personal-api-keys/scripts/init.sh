#!/bin/bash -ex

# `bash init.sh` (how cluster-initializer invokes this) ignores the shebang
# flags, so set them here.
set -exo pipefail

source /usr/local/lib/ror-utils.sh

# Members of readAccessToIndex-banana can read this index with their API keys
createIndex "logstash-banana-2026" && generate_log_documents 20 | putDocument "logstash-banana-2026"

# Members of readAccessToIndex-apple can read this index with their API keys
createIndex "logstash-apple-2026" && generate_log_documents 20 | putDocument "logstash-apple-2026"
