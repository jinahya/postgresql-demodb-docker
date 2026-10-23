#!/usr/bin/env bash
# Usage: scripts/smoke-test.sh <image> [timeout-seconds]
# Starts the image, waits for the first-start load to finish, checks the demo data, removes everything.
set -Eeuo pipefail

image=${1:?image reference}
timeout=${2:-3600}
name="demodb-smoke-$$"

cleanup() { docker rm -f -v "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$name" -e POSTGRES_PASSWORD=postgres "$image" >/dev/null
echo "smoke-test: started $name from $image, waiting up to ${timeout}s for the load"

start=$(date +%s)
# The temporary init server listens on the unix socket only, so TCP readiness means the load finished.
until docker exec "$name" pg_isready -h 127.0.0.1 -U postgres -q 2>/dev/null; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != "true" ]; then
    echo "smoke-test: container exited during load" >&2
    docker logs "$name" | tail -50 >&2
    exit 1
  fi
  if (( $(date +%s) - start > timeout )); then
    echo "smoke-test: timed out" >&2
    docker logs "$name" | tail -50 >&2
    exit 1
  fi
  sleep 5
done
echo "smoke-test: ready after $(( $(date +%s) - start ))s"

q() { docker exec "$name" psql -h 127.0.0.1 -U postgres -d demo -tAc "$1"; }
flights=$(q "SELECT count(*) FROM bookings.flights")
bookings=$(q "SELECT count(*) FROM bookings.bookings")
lang=$(q "SHOW bookings.lang")
echo "smoke-test: flights=${flights} bookings=${bookings} bookings.lang=${lang}"
[ "${flights:-0}" -gt 0 ] && [ "${bookings:-0}" -gt 0 ] || { echo "smoke-test: demo tables are empty" >&2; exit 1; }
echo "smoke-test: OK"
