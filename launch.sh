#!/bin/bash
# Quick launcher for Godot Chess Game
# This script ensures Go is in PATH and launches Godot

# Add Go to PATH if installed in home directory
if [ -d "$HOME/go/bin" ]; then
    export PATH=$PATH:$HOME/go/bin
fi

# Check if Godot is installed
if command -v godot4 &> /dev/null; then
    GODOT_CMD="godot4"
elif command -v godot &> /dev/null; then
    GODOT_CMD="godot"
else
    echo "ERROR: Godot not found in PATH"
    echo "Please install Godot 4 from https://godotengine.org/download"
    echo ""
    echo "Or specify the path to Godot manually:"
    echo "  /path/to/godot src/project.godot"
    exit 1
fi

echo "Launching Chess Game in Godot..."
cd src && $GODOT_CMD project.godot
