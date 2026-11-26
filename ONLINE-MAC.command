#!/bin/bash
set -eu
cd "$(dirname "$0")"
if ! command -v python3 >/dev/null 2>&1; then
  echo "Online mode requires Python 3.11+ (python.org)."
  read -r -p "Press Enter to close."
  exit 1
fi
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)' || { echo "Python 3.11+ required"; exit 1; }
if ! curl -fsS --max-time 2 http://127.0.0.1:8769/health >/dev/null; then
  python3 server.py > server.log 2>&1 &
  for i in {1..30}; do
    curl -fsS --max-time 1 http://127.0.0.1:8769/health >/dev/null 2>&1 && break
    sleep 0.3
  done
fi
curl -fsS --max-time 2 http://127.0.0.1:8769/health >/dev/null || { echo "Server failed; see server.log."; exit 1; }
open http://127.0.0.1:8769/
