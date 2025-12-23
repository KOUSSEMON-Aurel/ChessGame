package main

// This program is spawned as a sub process from the Godot UDP interface script
// It serves as a pipe between Godot and a running CLI process
// The CLI process is spawned from the path that is passed as a command line arg
// But we should spawn it after receiving the first UDP packet so that we know the address
// of the client to send any initial stdout text to.

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
)

func main() {
	f, _ := os.OpenFile("/tmp/iopiper.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if f != nil {
		log.SetOutput(f)
	}
	log.Println("IOPiper started")
	var clientAddr net.Addr

	// Expect an executable path as 2nd arg
	args := os.Args
	if len(args) < 2 {
		os.Exit(1)
	}

	// Set up UDP listner
	pc, err := net.ListenPacket("udp", "0.0.0.0:7070")
	if err != nil {
		log.Println("Failed to listen:", err)
		os.Exit(2)
	}
	defer pc.Close()

	// Set up external process
	proc := exec.Command(args[1])

	// The process input is obtained in the form of an io.WriteCloser. The underlying implementation uses the os.Pipe
	stdin, _ := proc.StdinPipe()
	defer stdin.Close()

	// Watch the output of the executed process
	stdout, _ := proc.StdoutPipe()
	defer stdout.Close()

	// Run the stdout scanner in a thread
	// It will write the stdout text via a pipe to our UDP client
	go func() {
		s := bufio.NewScanner(stdout)
		for s.Scan() {
			txt := s.Text()
			if _, err := pc.WriteTo([]byte(txt), clientAddr); err != nil {
				os.Exit(3)
			}
		}
	}()

	// Pipe text packets received from our UDP client to stdin
	buffer := make([]byte, 1024)
	for {
		n, addr, err := pc.ReadFrom(buffer)
		if err == nil {
			log.Printf("Received %d bytes from %v: %s", n, addr, string(buffer[:n]))
			clientAddr = addr
			if proc.Process == nil {
				// Start the subprocess
				log.Println("Starting subprocess")
				err := proc.Start()
				if err != nil {
					log.Println("Failed to start subprocess:", err)
					os.Exit(5)
				}
			}
			// Only write the first line of the buffer (not the whole buffer)
			io.WriteString(stdin, fmt.Sprintf("%s\n", buffer[:n]))

		} else {
			os.Exit(4)
		}
	}
}
