#!/usr/bin/env bash
set -euo pipefail

REPO="${GOLDEN_REPO:-fox3000foxy/windows10-golden}"
TAG="${GOLDEN_TAG:-golden-v1.0}"
R="${VM_ROOT:?VM_ROOT is required}"

mkdir -p "$R/download"
cd "$R/download"

URL="https://github.com/$REPO/releases/download/$TAG"

echo "[GOLDEN] Downloading $REPO@$TAG"

pids=()

for part in 00 01 02; do
    curl -fL --retry 3 \
        "$URL/windows10-golden.qcow2.part-$part" \
        -o "windows10-golden.qcow2.part-$part" &
    pids+=("$!")
done

failed=0

for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
done

test "$failed" -eq 0

curl -fL --retry 3 \
    "$URL/windows10-golden.qcow2.sha256" \
    -o windows10-golden.qcow2.sha256

curl -fL --retry 3 \
    "$URL/vm-state.tar.gz" \
    -o vm-state.tar.gz

cat windows10-golden.qcow2.part-* \
    > windows10-golden.qcow2

sha256sum -c windows10-golden.qcow2.sha256
qemu-img check windows10-golden.qcow2

mv windows10-golden.qcow2 "$R/"
tar -xzf vm-state.tar.gz -C "$R"

chmod 444 "$R/windows10-golden.qcow2"

cd "$R"
rm -rf "$R/download"

echo "[GOLDEN] Image ready"
