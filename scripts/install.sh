#!/usr/bin/env bash
# Download and install the lsec binary into INSTALL_DIR.
# Inputs (env): VERSION (semver or "latest"), INSTALL_DIR.
# Outputs: writes INSTALL_DIR to $GITHUB_PATH and exports LSEC_BIN.
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${INSTALL_DIR:?INSTALL_DIR is required}"

mkdir -p "$INSTALL_DIR"

case "$(uname -s)" in
  Linux*)  os=linux ;;
  Darwin*) os=macos ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "::error::Unsupported OS: $(uname -s)"; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch=x86_64 ;;
  arm64|aarch64)
    if [ "$os" = "windows" ]; then
      echo "::error::lsec has no windows-arm64 release"; exit 1
    fi
    arch=arm64
    ;;
  *) echo "::error::Unsupported arch: $(uname -m)"; exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  VERSION=$(curl -fsSL https://api.github.com/repos/AfaanBilal/lsec/releases/latest \
    | grep '"tag_name"' \
    | head -1 \
    | sed 's/.*"v\([^"]*\)".*/\1/')
  if [ -z "$VERSION" ]; then
    echo "::error::Could not resolve latest lsec version"; exit 1
  fi
fi

if [ "$os" = "windows" ]; then
  asset="lsec-windows-${arch}.zip"
  url="https://github.com/AfaanBilal/lsec/releases/download/v${VERSION}/${asset}"
  echo "Downloading $url"
  curl -fsSL "$url" -o "$INSTALL_DIR/lsec.zip"
  unzip -o -q "$INSTALL_DIR/lsec.zip" -d "$INSTALL_DIR"
  rm "$INSTALL_DIR/lsec.zip"
  bin="$INSTALL_DIR/lsec.exe"
else
  asset="lsec-${os}-${arch}.tar.gz"
  url="https://github.com/AfaanBilal/lsec/releases/download/v${VERSION}/${asset}"
  echo "Downloading $url"
  curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR"
  bin="$INSTALL_DIR/lsec"
  chmod +x "$bin"
fi

echo "$INSTALL_DIR" >> "$GITHUB_PATH"
echo "LSEC_BIN=$bin" >> "$GITHUB_ENV"
echo "LSEC_VERSION=$VERSION" >> "$GITHUB_ENV"

echo "Installed lsec v${VERSION} → $bin"
