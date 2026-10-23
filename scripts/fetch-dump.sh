#!/usr/bin/env bash
# Usage: scripts/fetch-dump.sh <dataset-version> <size>
# Downloads the demo dump into ./dumps (skipped when present) and verifies its sha256 from versions.json.
set -Eeuo pipefail
cd "$(dirname "$0")/.."

version=${1:?dataset version, e.g. 20250901}
size=${2:?size, e.g. 3m}

read -r url sha < <(python3 -I - "$version" "$size" <<'PY'
import json, sys
v, s = sys.argv[1:3]
cfg = json.load(open("versions.json"))
ds = next(d for d in cfg["datasets"] if d["version"] == v)
print(cfg["url"].format(version=v, size=s), ds["sizes"][s]["sha256"])
PY
)

mkdir -p dumps
file="dumps/demo-${version}-${size}.sql.gz"

actual() { (shasum -a 256 "$file" 2>/dev/null || sha256sum "$file") | cut -d' ' -f1; }
verify() {
  if [ -z "$sha" ]; then
    echo "fetch-dump: WARNING no sha256 recorded in versions.json for ${version}/${size}; computed: $(actual)" >&2
    return 0
  fi
  [ "$(actual)" = "$sha" ]
}

if [ -f "$file" ] && verify; then
  echo "fetch-dump: ${file} present and verified"
  exit 0
fi

echo "fetch-dump: downloading ${url}"
curl -fL --retry 5 --retry-delay 10 -o "${file}.part" "$url"
mv "${file}.part" "$file"
verify || { echo "fetch-dump: sha256 mismatch for ${file}" >&2; exit 1; }
echo "fetch-dump: ${file} verified"
