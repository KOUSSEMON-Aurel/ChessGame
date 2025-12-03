# Binaries Directory

This directory contains the compiled Go binaries for the UDP server that communicates with the chess engine.

## Structure

```
bin/
├── linux/          # Linux x86_64 binaries
│   ├── iopiper
│   ├── sampler
│   └── ping-server
├── windows/        # Windows x86_64 binaries
│   ├── iopiper.exe
│   ├── sampler.exe
│   └── ping-server.exe
└── macos/          # macOS binaries (Intel + Apple Silicon)
    ├── iopiper-amd64
    ├── iopiper-arm64
    └── ...
```

## How to Generate

Run the setup script for your platform:

**Linux/macOS:**
```bash
./setup.sh
```

**Windows:**
```cmd
setup.bat
```

Or build manually with Make:
```bash
make build-linux
make build-windows
make build-macos
```

## Source Files

The Go source files are located in: `src/engine/*.go`
- `iopiper.go` - UDP server to CLI bridge (main component)
- `sampler.go` - Echo test program
- `ping-server.go` - UDP ping test server
