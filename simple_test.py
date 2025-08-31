#!/usr/bin/env python3
import socket
import time

def test_connection():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(("localhost", 4000))
        
        # Try sending just a simple string first
        sock.send(b"hello\n")
        
        # Try to receive any response
        sock.settimeout(2)
        response = sock.recv(1024)
        print(f"Response to 'hello': {response}")
        
        sock.close()
        
    except socket.timeout:
        print("Connection timed out - no response")
        sock.close()
    except Exception as e:
        print(f"Error: {e}")

def test_http():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(("localhost", 4000))
        
        # Try HTTP request
        http_request = "GET / HTTP/1.1\r\nHost: localhost:4000\r\n\r\n"
        sock.send(http_request.encode())
        
        sock.settimeout(2)
        response = sock.recv(1024)
        print(f"HTTP Response: {response}")
        
        sock.close()
        
    except socket.timeout:
        print("HTTP request timed out - no response")
        sock.close()
    except Exception as e:
        print(f"HTTP Error: {e}")

if __name__ == "__main__":
    print("Testing simple connection...")
    test_connection()
    
    print("\nTesting HTTP connection...")
    test_http()