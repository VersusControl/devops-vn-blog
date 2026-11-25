# Amazon S3 Files: Mount an S3 Bucket as a Shared File System

Example code for the article
[Amazon S3 Files: Mount an S3 Bucket as a Shared File System](https://devopsvn.tech/aws-s3-files-mount-s3-bucket-as-file-system/).

The commands were checked against AWS CLI 2.37.7 and the
[S3 Files documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files.html).
They create billable resources (an EC2 instance, an S3 file system, a mount target, an S3 bucket).
Run `scripts/cleanup.sh` when you finish.

| Path | Purpose |
| --- | --- |
| `scripts/env.sh` | Settings (Region, bucket name) and IDs saved by earlier steps. Source it. |
| `scripts/01-bucket.sh` | Versioned general purpose bucket with two sample files. |
| `scripts/02-iam.sh` | The file system role (assumed by S3 Files) and the EC2 client role + instance profile. |
| `scripts/03-file-system.sh` | `create-file-system`, security groups for NFS (TCP 2049), `create-mount-target`. |
| `scripts/04-ec2.sh` | Amazon Linux 2023 instance in the same subnet; connect with Session Manager. |
| `scripts/user-data.sh` | Installs `amazon-efs-utils` (the S3 Files mount helper, 3.0.0+) at first boot. |
| `scripts/05-sync-config.sh` | Optional: custom import and expiration rules. |
| `scripts/cleanup.sh` | Deletes everything except the bucket. |
| `iam/*.json` | Trust and permission policies. `ACCOUNT_ID`, `REGION`, `BUCKET` are filled in by `02-iam.sh`. |

## Run it

Requirements: AWS CLI v2.37+, credentials that can create IAM roles, EC2 instances, and S3
buckets, and the Session Manager plugin for the AWS CLI.

```sh
export BUCKET=s3files-demo-<your-unique-suffix>
source scripts/env.sh

./scripts/01-bucket.sh
./scripts/02-iam.sh
./scripts/03-file-system.sh
./scripts/04-ec2.sh

# Each script saves the IDs it creates in .state. Source env.sh again to load them here.
source scripts/env.sh
aws ssm start-session --target "$INSTANCE_ID"
# on the instance:
sudo mkdir -p /mnt/s3files
sudo mount -t s3files <file-system-id>:/ /mnt/s3files
ls -la /mnt/s3files
```

## Clean up

```sh
# on the instance
sudo umount /mnt/s3files
# on your machine, at least a minute after your last write
./scripts/cleanup.sh
```

The bucket is kept. It is versioned, so deleting it means deleting every object version first.
