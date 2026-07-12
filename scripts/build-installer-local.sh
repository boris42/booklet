#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

UNSIGNED=1 \
OUTDIR="${OUTDIR:-$ROOT/build/unsigned-installer}" \
WORKDIR="${WORKDIR:-$ROOT/build/unsigned-installer-work}" \
"$ROOT/scripts/build-release.sh"
