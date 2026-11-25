#!/bin/bash
# Runs once at first boot. The mount helper for S3 Files ships in amazon-efs-utils (3.0.0+).
dnf -y install amazon-efs-utils
