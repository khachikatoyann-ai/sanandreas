import http.server
import socketserver
import os

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(__file__), "build", "web")

class GodotHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Enable Cross-Origin Isolation for Godot WebAssembly
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".pck"):
            return "application/octet-stream"
        return super().guess_type(path)

if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    with socketserver.TCPServer(("", PORT), GodotHTTPRequestHandler) as httpd:
        print(f"==========================================================")
        print(f"  LOS SANTOS ADVANCED: LOCAL WEB SERVER RUNNING")
        print(f"==========================================================")
        print(f"  Local PC URL   : http://localhost:{PORT}")
        print(f"  iPhone Wi-Fi   : http://192.168.129.12:{PORT}")
        print(f"==========================================================")
        print(f"Press Ctrl+C in this terminal to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")
