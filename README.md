# Godot Chess

This project implements a cross-platform PC chess board GUI compatible with UCI protocol to interface with chess engines.

The mouse is used to select, drag, and drop chess pieces around the board.

Each attempted move is evaluated for validity before the chess piece may be dropped into a new position.

Pieces may be taken and removed from the board.

Checks are made for:
* castling where a King is moved 2 steps horizontally
* check of a King
* check mate
* pawn promotion
* valid moves

A log of moves will be maintained.

There will be saving and loading of game moves.

When loading or inputing move data, the board may be initialized to a state other than the default starting positions.

![The Board](social/board.png)

## Platform Support

✅ **Linux** (tested on Ubuntu/Debian-based systems)  
✅ **Windows** (Windows 7+)  
✅ **macOS** (Intel and Apple Silicon)

## Chess Engine Interface

There are various Chess Engines available that use a standard interface protocol called UCI (Universal Chess Interface). We will use them as stand-alone applications (integration would entail using the source code and adhering to it's potentially restrictive licence).

See notes on UCI here: [Engine Interface](docs/engine-interface.txt)

A UDP (User Datagram Protocol) server program is used to communicate with UCI programs (chess engines). This is written in Golang (so as to be able to capture stdout data from a non-blocking process) whereas the GUI is developed in Godot Engine using GDScript.

The Chess Engines (CEs) have a command line interface (CLI) so we may pipe data in through stdin and out from stdout. The CE will be executed as a sub process from our UDP server which communicates with the CE. When the server shuts down, it will kill the sub-process.

The UDP server will listen on a particular port on the localhost for incoming data packets from a UDP client, and will pipe this data to a stdin pipe to the CE. When the CE produces output text, this is piped to the server from stdout and sent to the UDP client.

The UDP client is part of the Godot GUI application.

## Components
The game consists of three programs:
* GUI (Godot)
* UDP Server (Go)
* Chess Engine (Stockfish)

## Quick Start

### Prerequisites
* **Godot Engine 4** - Download from [godotengine.org](https://godotengine.org/download)
* **Go** - Download from [go.dev/dl](https://go.dev/dl/)

### Setup (Automated)

**On Linux/macOS:**
```bash
chmod +x setup.sh
./setup.sh
```

**On Windows:**
```cmd
setup.bat
```

The setup script will:
1. ✅ Check for Go installation
2. ✅ Create necessary directories (`bin/`, `engine/`)
3. ✅ Compile Go binaries for your platform
4. ✅ Download Stockfish chess engine automatically
5. ✅ Set executable permissions (Linux/macOS)

### Running the Game

1. Open the project in Godot 4
2. Press F5 or click "Run Project"
3. Select game mode and start playing!

## Manual Building

### Build System

The project uses a cross-platform Makefile:

```bash
# Build for your current platform
make

# Build for all platforms (requires Go)
make build-all

# Build for specific platforms
make build-linux
make build-windows
make build-macos

# Clean build artifacts
make clean

# Show help
make help
```

### Directory Structure

After running setup, your directory structure will look like:

```
ChessGame/
├── bin/
│   ├── linux/          # Linux binaries
│   │   ├── iopiper
│   │   ├── sampler
│   │   └── ping-server
│   ├── windows/        # Windows binaries
│   │   ├── iopiper.exe
│   │   ├── sampler.exe
│   │   └── ping-server.exe
│   └── macos/          # macOS binaries (Intel + Apple Silicon)
├── engine/
│   ├── stockfish-linux-x64
│   ├── stockfish-windows-x64.exe
│   └── stockfish-macos-x64
├── src/                # Godot project sources
└── ...
```

### Platform Detection

The game automatically detects your platform and uses the correct binaries:
- **Linux**: Uses `bin/linux/iopiper` and `engine/stockfish-linux-x64`
- **Windows**: Uses `bin/windows/iopiper.exe` and `engine/stockfish-windows-x64.exe`
- **macOS**: Uses `bin/macos/iopiper` and platform-specific Stockfish

## Manual Chess Engine Setup

If you prefer to manually download Stockfish:

1. Download from [stockfishchess.org/download](https://stockfishchess.org/download/)
2. Extract the archive
3. Place the executable in the `engine/` directory
4. Rename according to platform:
   - Linux: `stockfish-linux-x64`
   - Windows: `stockfish-windows-x64.exe`
   - macOS (Intel): `stockfish-macos-x64`
   - macOS (Apple Silicon): `stockfish-macos-arm64`

## Testing

`src/engine/sampler.go` is a program to echo back what is entered on the command line. Ctrl+C to exit.

`src/engine/ping-server.go` is a program to act as a UDP server that pings back what it receives from a UDP client

`src/engine/iopiper.go` is a program to act as a UDP server that pipes data between a UDP client and CLI program. This is the UDP Server component of the solution.

`src/engine/TestUDPClient.tscn` is a Godot scene used to test the UDPClient scene in conjunction with `iopiper` (UDP server) and `sampler` (Chess Engine substitute). It has export vars for the paths to these programs. It starts the server and passes it the path to the engine. The server then starts the engine. Then it sends a text string and times out if no return datagram is received. Otherwise, it continually sends a count value until the scene is closed.

The test scene should also, terminate the sub-process of the UDP Server which in turn should terminate it's sub-process of the engine.

Now there is a `src/engine/TestChessEngine.tscn` to test the actual engine that instantiates an `Engine` scene that finds the files rather than using the export vars to get the file paths.

A utility such as **Htop** is useful to monitor running processes. They may be displayed in a Tree, killed, and searched for.

## Exporting the Game

### Linux Export

1. In Godot: **Project → Export**
2. Add a **Linux/X11** preset
3. In the export settings, include:
   - `bin/linux/*`
   - `engine/stockfish-linux-x64`
4. Click **Export Project**

### Windows Export

1. In Godot: **Project → Export**
2. Add a **Windows Desktop** preset
3. In the export settings, include:
   - `bin/windows/*`
   - `engine/stockfish-windows-x64.exe`
4. Click **Export Project**

### macOS Export

1. In Godot: **Project → Export**
2. Add a **macOS** preset
3. In the export settings, include:
   - `bin/macos/*`
   - `engine/stockfish-macos-*` (appropriate for target architecture)
4. Click **Export Project**

## Troubleshooting

### "Missing iopiper" or "Missing chess engine" error

Run the setup script for your platform:
- Linux/macOS: `./setup.sh`
- Windows: `setup.bat`

### Go not found

Make sure Go is installed and in your PATH. After installation, restart your terminal.

### Stockfish not responding

1. Check that Stockfish is executable (Linux/macOS: `chmod +x engine/stockfish-*`)
2. Verify the file exists in the `engine/` directory
3. Check the Godot console for error messages

### Cross-compilation issues

If building for another platform fails, ensure you have Go installed and try:
```bash
go env -w CGO_ENABLED=0
make build-all
```

## Development

### Running in Development Mode

When running from the Godot editor in the `src/` directory, the game automatically detects this and adjusts paths accordingly. No special configuration needed!

### Building Go Binaries Only

```bash
# Your current platform
make build-current

# Specific platform
make build-linux
make build-windows
make build-macos
```

## Game Features

- **3 Game Modes**: Player vs AI, Player vs Player, AI vs AI
- **10 AI Difficulty Levels**: From beginner to master
- **2 Win Conditions**: Classic Checkmate/Stalemate or Total Elimination
- **Move History**: View and navigate through all moves
- **Save/Load Games**: Save your progress and resume later
- **Visual Feedback**: Highlighted moves, captured pieces display

## Credits

- Chess Engine: [Stockfish](https://stockfishchess.org/)
- Game Engine: [Godot](https://godotengine.org/)
- UDP Server: Custom Go implementation

## License

See [LICENSE](LICENSE) file for details.
