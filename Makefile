# Chess Game - Cross-Platform Build System
# Supports: Linux, Windows, macOS

# Go configuration
GOPATH := $(HOME)/go
GOBIN := $(GOPATH)/bin
export PATH := $(PATH):$(GOBIN)

# Directories
SRC_DIR := src/engine
BIN_DIR := bin
ENGINE_DIR := engine

# Source files
GO_SOURCES := $(SRC_DIR)/iopiper.go $(SRC_DIR)/sampler.go $(SRC_DIR)/ping-server.go

# Platform-specific settings
ifeq ($(OS),Windows_NT)
	CURRENT_OS := windows
	EXE_EXT := .exe
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		CURRENT_OS := linux
	endif
	ifeq ($(UNAME_S),Darwin)
		CURRENT_OS := macos
	endif
	EXE_EXT :=
endif

# Build targets
.PHONY: all build-all build-linux build-windows build-macos clean setup help

all: build-current

help:
	@echo "Chess Game - Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make all           - Build for current platform"
	@echo "  make build-all     - Build for all platforms"
	@echo "  make build-linux   - Build for Linux"
	@echo "  make build-windows - Build for Windows"
	@echo "  make build-macos   - Build for macOS"
	@echo "  make setup         - Create directories and download Stockfish"
	@echo "  make clean         - Remove built binaries"
	@echo ""
	@echo "Current platform: $(CURRENT_OS)"

# Create necessary directories
setup:
	@echo "Creating build directories..."
	@mkdir -p $(BIN_DIR)/linux
	@mkdir -p $(BIN_DIR)/windows
	@mkdir -p $(BIN_DIR)/macos
	@mkdir -p $(ENGINE_DIR)
	@echo "Build directories created."
	@echo ""
	@echo "Run './setup.sh' (Linux/Mac) or 'setup.bat' (Windows) to download Stockfish."

# Build for current platform only
build-current: setup
	@echo "Building for $(CURRENT_OS)..."
	@$(MAKE) build-$(CURRENT_OS)

# Build for all platforms (cross-compilation)
build-all: build-linux build-windows build-macos

# Linux builds
build-linux: setup
	@echo "Building for Linux (amd64)..."
	@GOOS=linux GOARCH=amd64 go build -o $(BIN_DIR)/linux/iopiper $(SRC_DIR)/iopiper.go
	@GOOS=linux GOARCH=amd64 go build -o $(BIN_DIR)/linux/sampler $(SRC_DIR)/sampler.go
	@GOOS=linux GOARCH=amd64 go build -o $(BIN_DIR)/linux/ping-server $(SRC_DIR)/ping-server.go
	@chmod +x $(BIN_DIR)/linux/*
	@echo "✓ Linux binaries built successfully"

# Windows builds
build-windows: setup
	@echo "Building for Windows (amd64)..."
	@GOOS=windows GOARCH=amd64 go build -o $(BIN_DIR)/windows/iopiper.exe $(SRC_DIR)/iopiper.go
	@GOOS=windows GOARCH=amd64 go build -o $(BIN_DIR)/windows/sampler.exe $(SRC_DIR)/sampler.go
	@GOOS=windows GOARCH=amd64 go build -o $(BIN_DIR)/windows/ping-server.exe $(SRC_DIR)/ping-server.go
	@echo "✓ Windows binaries built successfully"

# macOS builds
build-macos: setup
	@echo "Building for macOS (amd64 + arm64)..."
	@GOOS=darwin GOARCH=amd64 go build -o $(BIN_DIR)/macos/iopiper-amd64 $(SRC_DIR)/iopiper.go
	@GOOS=darwin GOARCH=arm64 go build -o $(BIN_DIR)/macos/iopiper-arm64 $(SRC_DIR)/iopiper.go
	@GOOS=darwin GOARCH=amd64 go build -o $(BIN_DIR)/macos/sampler-amd64 $(SRC_DIR)/sampler.go
	@GOOS=darwin GOARCH=arm64 go build -o $(BIN_DIR)/macos/sampler-arm64 $(SRC_DIR)/sampler.go
	@GOOS=darwin GOARCH=amd64 go build -o $(BIN_DIR)/macos/ping-server-amd64 $(SRC_DIR)/ping-server.go
	@GOOS=darwin GOARCH=arm64 go build -o $(BIN_DIR)/macos/ping-server-arm64 $(SRC_DIR)/ping-server.go
	@chmod +x $(BIN_DIR)/macos/*
	@echo "✓ macOS binaries built successfully (both Intel and Apple Silicon)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BIN_DIR)/linux/*
	@rm -rf $(BIN_DIR)/windows/*
	@rm -rf $(BIN_DIR)/macos/*
	@echo "✓ Clean complete"

# Test current platform build
test: build-current
	@echo "Testing $(CURRENT_OS) build..."
	@echo "Starting sampler (press Ctrl+C to stop)..."
	@$(BIN_DIR)/$(CURRENT_OS)/sampler$(EXE_EXT)
