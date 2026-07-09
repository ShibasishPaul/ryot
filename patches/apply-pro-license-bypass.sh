#!/usr/bin/env bash
# Applies the Pro license-check bypass to a checked-out Ryot source tree using
# comby's structural match (not a line-based diff), so it keeps applying even
# if upstream reformats or tweaks the internals of the target function - only
# the function's name and return type need to stay the same.
#
# Ryot is GPLv3 (verified: no separate Pro license, no BSL/Elastic carve-out),
# so this fork is self-built and self-hosted rather than paid for. Every Pro
# feature-flag check ultimately calls get_is_server_key_validated(), so this
# one structural rewrite is the entire patch - see PRO_BYPASS.md for details.
#
# Usage: apply-pro-license-bypass.sh <path-to-ryot-checkout>
# Requires: docker (runs comby/comby via the host's docker, no local comby install needed)

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <path-to-ryot-checkout>" >&2
  exit 1
fi

TARGET_DIR="$(realpath "$1")"
TARGET_FILE="crates/utils/dependent/core/src/lib.rs"

if [ ! -f "$TARGET_DIR/$TARGET_FILE" ]; then
  echo "error: $TARGET_FILE not found under $TARGET_DIR - has the file moved?" >&2
  exit 1
fi

MATCH='async fn get_is_server_key_validated(:[params]) -> Result<bool> {
    :[body]
}'
REWRITE='async fn get_is_server_key_validated(:[params]) -> Result<bool> {
    Ok(true)
}'

docker run --rm -v "$TARGET_DIR":/src -w /src comby/comby \
  "$MATCH" "$REWRITE" \
  -matcher .rs -directory "$(dirname "$TARGET_FILE")" -in-place

# The authoritative check is this post-condition, not whether comby changed
# anything - re-running against an already-patched file is a legitimate no-op
# (idempotent), not a failure. Only a signature mismatch (upstream renamed the
# function or changed its return type) leaves api.unkey.com still present.
if grep -q "api.unkey.com" "$TARGET_DIR/$TARGET_FILE"; then
  echo "error: patch didn't take - $TARGET_FILE still references api.unkey.com." >&2
  echo "       The function's name/return type likely changed upstream and no" >&2
  echo "       longer matches this patch's structural template. Needs manual" >&2
  echo "       review before building." >&2
  exit 2
fi

echo "Pro license-check bypass is in place in $TARGET_FILE."
