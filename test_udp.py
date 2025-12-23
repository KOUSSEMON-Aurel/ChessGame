import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 7070

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(2.0)

try:
    print(f"Sending 'uci' to {HOST}:{PORT}")
    sock.sendto(b"uci", (HOST, PORT))
    
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            print(f"Received: {data.decode('utf-8')}")
            if "uciok" in data.decode('utf-8'):
                print("Success: uciok received")
                break
        except socket.timeout:
            print("Timeout waiting for response")
            break
except Exception as e:
    print(f"Error: {e}")
finally:
    sock.close()
