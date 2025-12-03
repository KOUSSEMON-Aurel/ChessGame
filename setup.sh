#!/bin/bash
# Chess Game - Linux/macOS Setup Script
# This script prepares the development environment and downloads Stockfish

set -e  # Exit on error

echo "========================================="
echo "Chess Game - Setup Script (Linux/macOS)"
echo "========================================="
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     PLATFORM=linux;;
    Darwin*)    PLATFORM=macos;;
    *)          echo "Unsupported OS: ${OS}"; exit 1;;
esac

echo "Detected platform: ${PLATFORM}"
echo ""

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "ERROR: Go is not installed or not in PATH"
    echo ""
    echo "Go installation detected in ~/go/bin"
    echo "Adding to PATH for this session..."
    export PATH=$PATH:$HOME/go/bin
    
    if ! command -v go &> /dev/null; then
        echo "ERROR: Still cannot find Go. Please install Go from https://go.dev/dl/"
        exit 1
    fi
fi

GO_VERSION=$(go version)
echo "✓ Go found: ${GO_VERSION}"
echo ""

# Create directories
echo "Creating necessary directories..."
mkdir -p bin/linux
mkdir -p bin/windows
mkdir -p bin/macos
mkdir -p engine
echo "✓ Directories created"
echo ""

# Build Go binaries for current platform
echo "Building Go binaries for ${PLATFORM}..."
export PATH=$PATH:$HOME/go/bin
make build-${PLATFORM}
echo ""

# Download Stockfish
echo "Downloading Stockfish chess engine..."
STOCKFISH_DIR="engine"

if [ "${PLATFORM}" = "linux" ]; then
    STOCKFISH_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_16.1/stockfish-ubuntu-x86-64-avx2.tar"
    STOCKFISH_ARCHIVE="${STOCKFISH_DIR}/stockfish-linux.tar"
    STOCKFISH_BINARY="stockfish-linux-x64"
    
    echo "Downloading Stockfish for Linux..."
    wget -q --show-progress "${STOCKFISH_URL}" -O "${STOCKFISH_ARCHIVE}"
    
    echo "Extracting Stockfish..."
    tar -xf "${STOCKFISH_ARCHIVE}" -C "${STOCKFISH_DIR}"
    
    # Find the extracted binary and rename it
    EXTRACTED_BINARY=$(find "${STOCKFISH_DIR}" -type f -name "stockfish*" ! -name "*.tar" ! -name "*.gz" | head -1)
    if [ -n "${EXTRACTED_BINARY}" ]; then
        mv "${EXTRACTED_BINARY}" "${STOCKFISH_DIR}/${STOCKFISH_BINARY}"
        chmod +x "${STOCKFISH_DIR}/${STOCKFISH_BINARY}"
        echo "✓ Stockfish installed: ${STOCKFISH_DIR}/${STOCKFISH_BINARY}"
    else
        echo "WARNING: Could not find Stockfish binary in archive"
    fi
    
    # Clean up
    rm -f "${STOCKFISH_ARCHIVE}"
    
elif [ "${PLATFORM}" = "macos" ]; then
    # Detect architecture
    ARCH="$(uname -m)"
    if [ "${ARCH}" = "arm64" ]; then
        STOCKFISH_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_16.1/stockfish-macos-m1-apple-silicon.tar"
        STOCKFISH_BINARY="stockfish-macos-arm64"
    else
        STOCKFISH_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_16.1/stockfish-macos-x86-64-avx2.tar"
        STOCKFISH_BINARY="stockfish-macos-x64"
    fi
    
    STOCKFISH_ARCHIVE="${STOCKFISH_DIR}/stockfish-macos.tar"
    
    echo "Downloading Stockfish for macOS (${ARCH})..."
    curl -L "${STOCKFISH_URL}" -o "${STOCKFISH_ARCHIVE}"
    
    echo "Extracting Stockfish..."
    tar -xf "${STOCKFISH_ARCHIVE}" -C "${STOCKFISH_DIR}"
    
    # Find the extracted binary and rename it
    EXTRACTED_BINARY=$(find "${STOCKFISH_DIR}" -type f -name "stockfish*" ! -name "*.tar" ! -name "*.gz" | head -1)
    if [ -n "${EXTRACTED_BINARY}" ]; then
        mv "${EXTRACTED_BINARY}" "${STOCKFISH_DIR}/${STOCKFISH_BINARY}"
        chmod +x "${STOCKFISH_DIR}/${STOCKFISH_BINARY}"
        echo "✓ Stockfish installed: ${STOCKFISH_DIR}/${STOCKFISH_BINARY}"
    else
        echo "WARNING: Could not find Stockfish binary in archive"
    fi
    
    # Clean up
    rm -f "${STOCKFISH_ARCHIVE}"
fi

echo ""
echo "========================================="
echo "✓ Setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Open the project in Godot 4"
echo "2. Run the game from the Godot editor"
echo ""
echo "To build for other platforms:"
echo "  make build-windows  # Build Windows binaries"
echo "  make build-all      # Build for all platforms"
echo ""
