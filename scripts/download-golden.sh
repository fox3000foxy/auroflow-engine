#!/usr/bin/env bash
set -euo pipefail

REPO="${GOLDEN_REPO:-fox3000foxy/windows10-golden}"
TAG="${GOLDEN_TAG:-golden-v1.0}"
R="${VM_ROOT:?VM_ROOT is required}"

CACHE="${RUNNER_TEMP:-/tmp}/golden-cache"
HASH="7479cbf22ad8ec2e9d7cc6ec6d79c45ded8f46d52894521d7b20f7f2f5b52366"

mkdir -p "$CACHE"

if [[ -f "$CACHE/windows10-golden.qcow2" && -f "$CACHE/vm-state.tar.gz" ]]; then
    echo "$HASH  $CACHE/windows10-golden.qcow2" | sha256sum -c -
    qemu-img check "$CACHE/windows10-golden.qcow2"

    ln "$CACHE/windows10-golden.qcow2" "$R/windows10-golden.qcow2"
    tar -xzf "$CACHE/vm-state.tar.gz" -C "$R"

    chmod 444 "$R/windows10-golden.qcow2"

    echo "[GOLDEN] Restored from cache"
    exit 0
fi

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

mv windows10-golden.qcow2 "$CACHE/"
cp vm-state.tar.gz "$CACHE/"
ln "$CACHE/windows10-golden.qcow2" "$R/windows10-golden.qcow2"
tar -xzf vm-state.tar.gz -C "$R"

chmod 444 "$R/windows10-golden.qcow2"

cd "$R"
rm -rf "$R/download"

echo "[GOLDEN] Image ready"
