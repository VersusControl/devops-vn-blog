#!/usr/bin/env bash
# Start AWS Emulator in Docker (macOS, Windows with WSL, or Linux).
# Run it in its own terminal. Press Ctrl+C to stop it; all emulated resources are deleted.
#
#   ./scripts/start-emulator.sh          # port 9297
#   EMULATOR_PORT=9300 ./scripts/start-emulator.sh
set -euo pipefail

PORT="${EMULATOR_PORT:-9297}"

# The emulator writes its credentials and certificate here. Create the directory
# yourself so Docker does not create it as root.
mkdir -p "$HOME/.aws/emulator"

user_args=()
if [[ "$(uname -s)" == "Linux" ]]; then
  # On Linux, make the files that the emulator writes belong to you.
  user_args=(--user "$(id -u):$(id -g)")
fi

# -p 127.0.0.1:... keeps the emulator reachable only from this machine.
# -e HOME makes the paths inside the container match the paths on your machine.
exec docker run --rm ${user_args[@]+"${user_args[@]}"} \
  --memory=2g --memory-swap=2g \
  -p "127.0.0.1:${PORT}:${PORT}" \
  -e HOME="$HOME" -v "$HOME/.aws/emulator:$HOME/.aws/emulator" \
  aws-emulator -p "$PORT" --telemetry off
