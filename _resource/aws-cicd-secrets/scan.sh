#!/usr/bin/env bash
# Scan a Git repository's history for secrets with gitleaks (exit code 1 if it finds any).
#   ./scan.sh /path/to/repo
set -euo pipefail
docker run --rm -v "$(cd "${1:-.}" && pwd):/repo" ghcr.io/gitleaks/gitleaks:latest git /repo --no-banner -v
