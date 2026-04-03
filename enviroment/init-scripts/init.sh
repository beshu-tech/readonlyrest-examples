#!/bin/bash -ex

set -o pipefail

cd "$(dirname "$0")"

source utils/lib.sh

createIndex "test" && generate_log_documents 5 | putDocument "test"