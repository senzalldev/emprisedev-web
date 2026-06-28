#!/bin/sh
# emprise installer — download and install the latest binary
# Usage: curl -fsSL https://emprise.dev/install.sh | sh
set -e

REPO="senzalldev/emprise-app"
INSTALL_DIR="/usr/local/bin"
BINARY="emprise"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  darwin) PLATFORM="darwin-${ARCH}" ;;
  linux)  PLATFORM="linux-${ARCH}" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

FILENAME="${BINARY}-${PLATFORM}"

echo ""
echo "  /|\\"
echo " / | \\   emprise installer"
echo "'--+--'   \"a bold undertaking\""
echo "   |"
echo ""
echo "Platform: ${OS}/${ARCH}"
echo ""

# Try GitHub Releases first, fall back to raw binary from repo
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/${FILENAME}"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/dist/${FILENAME}"

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

echo "Downloading emprise..."
if curl -fsSL -o "$TMPFILE" "$RELEASE_URL" 2>/dev/null; then
  echo "  Downloaded from GitHub Releases"
elif curl -fsSL -o "$TMPFILE" "$RAW_URL" 2>/dev/null; then
  echo "  Downloaded from repository"
else
  echo "Error: Could not download emprise for ${PLATFORM}"
  echo "Try building from source:"
  echo "  git clone https://github.com/${REPO}.git"
  echo "  cd emprise && go build -o emprise ./cmd/emprise"
  exit 1
fi

# Verify it's a binary (not an HTML error page)
if file "$TMPFILE" | grep -q "text"; then
  echo "Error: Downloaded file is not a binary. Check the URL."
  exit 1
fi

chmod +x "$TMPFILE"

# Clear quarantine. Keep the notarized Developer ID signature when present;
# only ad-hoc sign if the binary is unsigned (the raw-repo fallback), since
# an unsigned arm64 binary won't run on Apple Silicon otherwise.
if [ "$OS" = "darwin" ]; then
  xattr -d com.apple.quarantine "$TMPFILE" 2>/dev/null || true
  codesign -v "$TMPFILE" 2>/dev/null || codesign -s - "$TMPFILE" 2>/dev/null || true
fi

# Install
if [ -w "$INSTALL_DIR" ]; then
  mv "$TMPFILE" "${INSTALL_DIR}/${BINARY}"
else
  echo "Installing to ${INSTALL_DIR} (requires sudo)..."
  sudo mv "$TMPFILE" "${INSTALL_DIR}/${BINARY}"
fi

# Verify
if command -v emprise >/dev/null 2>&1; then
  VERSION=$(emprise --version 2>/dev/null || echo "installed")
  echo ""
  echo "Installed: ${VERSION}"
  echo ""
  echo "Get started:"
  echo "  emprise              # interactive mode (setup wizard on first run)"
  echo "  emprise \"hello\"      # single question"
  echo "  emprise --help       # all options"
  echo ""
else
  echo ""
  echo "Installed to ${INSTALL_DIR}/${BINARY}"
  echo "Make sure ${INSTALL_DIR} is in your PATH."
  echo ""
fi
