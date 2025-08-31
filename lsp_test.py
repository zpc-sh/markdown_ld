#!/usr/bin/env python3
import json
import socket
import threading
import time

class LSPClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        
    def connect(self):
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(30)
            self.socket.connect((self.host, self.port))
            self.connected = True
            print(f"Connected to {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"Failed to connect: {e}")
            return False
            
    def send_message(self, message):
        if not self.connected:
            print("Not connected")
            return None
            
        try:
            # Convert message to JSON string if it's a dict
            if isinstance(message, dict):
                message_str = json.dumps(message)
            else:
                message_str = message
                
            # Calculate content length
            content_length = len(message_str.encode('utf-8'))
            
            # Format with LSP headers
            headers = f"Content-Length: {content_length}\r\n\r\n"
            full_message = headers + message_str
            
            print(f"Sending:\n{full_message}")
            
            # Send the message
            self.socket.send(full_message.encode('utf-8'))
            
            # Try to receive response
            response = self.receive_message()
            return response
            
        except Exception as e:
            print(f"Error sending message: {e}")
            return None
            
    def receive_message(self):
        try:
            # Read headers first
            headers = b""
            while b"\r\n\r\n" not in headers:
                chunk = self.socket.recv(1)
                if not chunk:
                    break
                headers += chunk
                
            if not headers:
                return None
                
            headers_str = headers.decode('utf-8')
            print(f"Received headers: {repr(headers_str)}")
            
            # Parse Content-Length
            content_length = 0
            for line in headers_str.split('\r\n'):
                if line.startswith('Content-Length:'):
                    content_length = int(line.split(':')[1].strip())
                    break
                    
            if content_length == 0:
                print("No Content-Length found")
                return headers_str
                
            # Read the content
            content = b""
            while len(content) < content_length:
                chunk = self.socket.recv(content_length - len(content))
                if not chunk:
                    break
                content += chunk
                
            response_str = content.decode('utf-8')
            print(f"Received content: {response_str}")
            
            try:
                return json.loads(response_str)
            except:
                return response_str
                
        except Exception as e:
            print(f"Error receiving message: {e}")
            return None
            
    def initialize(self, root_uri):
        initialize_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "processId": None,
                "rootUri": root_uri,
                "capabilities": {
                    "textDocument": {
                        "hover": {
                            "contentFormat": ["markdown", "plaintext"]
                        },
                        "completion": {
                            "completionItem": {
                                "snippetSupport": True
                            }
                        }
                    }
                },
                "workspaceFolders": [{
                    "uri": root_uri,
                    "name": "markdown_ld"
                }]
            }
        }
        
        return self.send_message(initialize_request)
        
    def close(self):
        if self.socket:
            self.socket.close()
            self.connected = False

def main():
    client = LSPClient("localhost", 4000)
    
    if client.connect():
        print("Attempting to initialize...")
        response = client.initialize("file:///Users/locnguyen/src/code/markdown_ld")
        
        if response:
            print(f"Initialize response: {response}")
        else:
            print("No response to initialize")
            
        client.close()
    else:
        print("Failed to connect to LSP server")

if __name__ == "__main__":
    main()