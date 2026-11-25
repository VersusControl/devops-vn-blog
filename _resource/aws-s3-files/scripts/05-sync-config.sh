#!/usr/bin/env bash
# Optional: tune what S3 Files copies onto its high-performance storage, and for how long.
#   - reports/ : small files read often -> import data up to 1 MiB when the directory is opened
#   - everything else : metadata only (sizeLessThan=0), every read streams from S3
#   - data not read for 7 days is removed from the file system (it stays in S3)
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

aws s3files put-synchronization-configuration \
  --file-system-id "$FS_ID" \
  --import-data-rules \
      'prefix="",trigger=ON_FILE_ACCESS,sizeLessThan=0' \
      'prefix=reports/,trigger=ON_DIRECTORY_FIRST_ACCESS,sizeLessThan=1048576' \
  --expiration-data-rules daysAfterLastAccess=7

aws s3files get-synchronization-configuration --file-system-id "$FS_ID"
