#!/usr/bin/env bash
set -euo pipefail

BINARY_NAME="clip"
INSTALL_DIR="/usr/local/bin"

# If a pre-built 'clip' binary sits next to this script (i.e. running from DMG),
# use it directly. Otherwise build from source.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLED_BINARY="${SCRIPT_DIR}/${BINARY_NAME}"

if [ -f "${BUNDLED_BINARY}" ] && [ -x "${BUNDLED_BINARY}" ]; then
    echo "Using bundled clip binary..."
    BUILT_PATH="${BUNDLED_BINARY}"
else
    echo "Building ${BINARY_NAME} (release)..."
    # Must be run from the repo root when building from source
    swift build -c release --product "clip-tool"
    BUILT_PATH=".build/release/clip-tool"
fi

if [ ! -f "${BUILT_PATH}" ]; then
    echo "ERROR: Binary not found at ${BUILT_PATH}" >&2
    exit 1
fi

# Warn if 'clip' already resolves to something other than the install target
EXISTING=$(which "${BINARY_NAME}" 2>/dev/null || true)
if [ -n "${EXISTING}" ] && [ "${EXISTING}" != "${INSTALL_DIR}/${BINARY_NAME}" ]; then
    echo "WARNING: '${BINARY_NAME}' already exists at ${EXISTING}"
    echo "         It will be shadowed by the new install at ${INSTALL_DIR}/${BINARY_NAME}"
    read -r -p "Continue? [y/N] " confirm
    case "${confirm}" in
        [yY]) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

echo "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
mkdir -p "${INSTALL_DIR}"
sudo cp "${BUILT_PATH}" "${INSTALL_DIR}/${BINARY_NAME}"
sudo chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

echo "Done. Run: clip --help"
