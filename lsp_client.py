#!/usr/bin/env python3
import json
import socket
import sys

def send_lsp_request(host, port, message):
    """Send an LSP request to the server and return the response."""
    try:
        # Create socket connection
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)  # 10 second timeout
        sock.connect((host, port))
        
        # Send the JSON-RPC message
        message_bytes = message.encode('utf-8')
        content_length = len(message_bytes)
        
        # Format with LSP headers
        request = f"Content-Length: {content_length}\r\n\r\n{message}".encode('utf-8')
        
        print(f"Sending request:")
        print(f"Content-Length: {content_length}")
        print(f"Message: {message}")
        
        sock.send(request)
        
        # Read response
        response = sock.recv(4096).decode('utf-8')
        sock.close()
        
        return response
    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == "__main__":
    # Initialize request
    initialize_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "processId": None,
            "rootUri": "file:///Users/locnguyen/src/code/markdown_ld",
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
                "uri": "file:///Users/locnguyen/src/code/markdown_ld",
                "name": "markdown_ld"
            }]
        }
    }
    
    message = json.dumps(initialize_request)
    response = send_lsp_request("localhost", 4000, message)
    print(f"\nResponse:")
    print(response)