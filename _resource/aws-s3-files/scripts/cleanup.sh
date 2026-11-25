#!/usr/bin/env bash
# Delete everything the demo created, in reverse order. Before running it:
#   - on the instance: sudo umount /mnt/s3files
#   - wait at least a minute after your last write, so S3 Files has exported every change.
#
# The script stops if the file system can't be deleted (for example, changes still waiting to
# be exported), and keeps .state, so you can simply run it again later.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

if [[ -n "${INSTANCE_ID:-}" ]]; then
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
  echo "Instance $INSTANCE_ID terminated"
fi

if [[ -n "${FS_ID:-}" ]]; then
  for mt in $(aws s3files list-mount-targets --file-system-id "$FS_ID" \
                --query 'mountTargets[].mountTargetId' --output text); do
    aws s3files delete-mount-target --mount-target-id "$mt"
  done
  # The file system can only be deleted after its mount targets are gone.
  until [[ "$(aws s3files list-mount-targets --file-system-id "$FS_ID" \
                --query 'length(mountTargets)' --output text)" == "0" ]]; do sleep 10; done

  # Fails, and stops the script, if changes are still waiting to be exported to S3.
  # Wait and run the script again; use --force-delete only if you accept losing them.
  aws s3files delete-file-system --file-system-id "$FS_ID"
  # Keep the IAM role until the file system is fully gone: S3 Files uses it until then.
  while status="$(aws s3files get-file-system --file-system-id "$FS_ID" \
                    --query status --output text 2>/dev/null)" && [[ "$status" != "deleted" ]]; do
    echo "  $FS_ID: $status"; sleep 15
  done
  echo "File system $FS_ID deleted"
fi

# Security groups can be deleted once the mount target's and instance's network interfaces are gone.
for sg in "${MT_SG:-}" "${CLIENT_SG:-}"; do
  [[ -z "$sg" ]] && continue
  until aws ec2 delete-security-group --group-id "$sg" 2>/dev/null; do sleep 10; done
  echo "Security group $sg deleted"
done

# IAM. "|| true" lets a second run skip what is already gone.
aws iam remove-role-from-instance-profile --instance-profile-name "$NAME-client-profile" \
  --role-name "$NAME-client-role" 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name "$NAME-client-profile" 2>/dev/null || true
for arn in arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess \
           arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore; do
  aws iam detach-role-policy --role-name "$NAME-client-role" --policy-arn "$arn" 2>/dev/null || true
done
aws iam delete-role-policy --role-name "$NAME-client-role" --policy-name s3-direct-read 2>/dev/null || true
aws iam delete-role --role-name "$NAME-client-role" 2>/dev/null || true
aws iam delete-role-policy --role-name "$NAME-fs-role" --policy-name s3files-bucket-access 2>/dev/null || true
aws iam delete-role --role-name "$NAME-fs-role" 2>/dev/null || true
echo "IAM roles deleted"

rm -f .state
echo "Done. The bucket $BUCKET is kept. It is versioned, so deleting it means deleting every"
echo "object version first: https://docs.aws.amazon.com/AmazonS3/latest/userguide/delete-bucket.html"
