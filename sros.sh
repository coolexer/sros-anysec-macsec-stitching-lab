#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <pe1|pe2|pe3> <command...>" >&2
  exit 1
fi

NODE="$1"
shift

case "$NODE" in
  pe1)     IP="172.31.250.11" ;;
  pe2)     IP="172.31.250.12" ;;
  pe3)     IP="172.31.250.13" ;;
  *)       IP="$NODE" ;;
esac

{
  echo "environment more false"
  for cmd in "$@"; do
    echo "$cmd"
  done
  echo "logout"
} | sshpass -p admin ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "admin@${IP}" \
  | tr -d '\r' | sed -n '/^\[\/\]/,$p'   # drop CRs and the login banner
