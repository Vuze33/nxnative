#!/usr/bin/env bash
# Recreate the local nxnative build environment.
# Usage: bash scripts/setup_build_env.sh
#
# This creates only local, ignored files:
#   .venv/                 Python 3.12 environment
#   .toolchain-bin/xcrun   routes Metal 922 calls to the mounted toolchain
#
# The Apple MetalToolchain DMG is not part of this repository. The existing
# shell 'build' function mounts it from the local Games folder before checks.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Run this script from a nxnative Git checkout." >&2
    exit 1
fi

PYTHON="${PYTHON:-python3.12}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    echo "ERROR: Python 3.12 was not found. Install/use Python 3.12, then rerun." >&2
    exit 1
fi

PY_VERSION="$("$PYTHON" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')"
if [[ "$PY_VERSION" != "3.12" ]]; then
    echo "ERROR: This pinned environment expects Python 3.12; found $PY_VERSION." >&2
    echo "Set PYTHON to a Python 3.12 executable and rerun." >&2
    exit 1
fi

echo "=== Creating Python environment ==="
"$PYTHON" -m venv .venv
.venv/bin/python -m pip install --upgrade "pip==26.3"
.venv/bin/python -m pip install -r requirements-build.txt

echo
echo "=== Creating the Metal 922 xcrun wrapper ==="
mkdir -p .toolchain-bin
cat > .toolchain-bin/xcrun <<'WRAPPER'
#!/usr/bin/env bash
set -e

TOOLCHAIN="/Volumes/MetalToolchainCryptex/Metal.xctoolchain/usr/bin"

if [[ "${1:-}" == "-sdk" || "${1:-}" == "--sdk" ]]; then
    tool="${3:-}"
    if [[ "$tool" == "metal" || "$tool" == "metallib" ]]; then
        if [[ ! -x "$TOOLCHAIN/$tool" ]]; then
            echo "ERROR: MetalToolchain 32023.922 is not mounted at /Volumes/MetalToolchainCryptex." >&2
            echo "Run the existing 'build' shell function to mount it, then retry." >&2
            exit 1
        fi
        shift 3
        exec "$TOOLCHAIN/$tool" "$@"
    fi
fi

exec /usr/bin/xcrun "$@"
WRAPPER
chmod +x .toolchain-bin/xcrun

echo
echo "=== Excluding local environment files from Git ==="
EXCLUDE="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$EXCLUDE")"
touch "$EXCLUDE"
for entry in '/.venv/' '/.toolchain-bin/'; do
    if ! grep -Fqx "$entry" "$EXCLUDE"; then
        printf '%s\n' "$entry" >> "$EXCLUDE"
    fi
done

echo
echo "=== Environment created ==="
.venv/bin/python --version
.venv/bin/python -m pip list
echo
echo "The MetalToolchain DMG is not downloaded or copied by this script."
echo "Run your existing 'build' shell function to mount Metal 32023.922,"
echo "activate .venv, add .toolchain-bin to PATH and verify dmsh_chain.lock."
