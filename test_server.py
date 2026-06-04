from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        print(f"\n--- Received POST request to {self.path} ---")
        print(f"Headers:\n{self.headers}")
        
        try:
            body_json = json.loads(post_data.decode('utf-8'))
            print("Parsed JSON Payload:")
            print(json.dumps(body_json, indent=2))
            
            # Check for our requested values
            if "location_data" in body_json:
                print("✅ Found httpRootProperty 'location_data'")
            else:
                print("❌ Missing httpRootProperty 'location_data'")
                
            if "user_id" in body_json.get("params", {}):
                print("✅ Found param 'user_id' inside 'params'")
            else:
                print("❌ Missing param 'user_id' inside 'params'")
                
        except json.JSONDecodeError:
            print("Raw Payload (Not JSON):")
            print(post_data.decode('utf-8'))

        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status": "success"}')
        print("-------------------------------------------\n")

    def log_message(self, format, *args):
        pass # Suppress default logging to keep output clean

def run(server_class=HTTPServer, handler_class=SimpleHTTPRequestHandler, port=8099):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting simple HTTP server on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    print("Server stopped.")

if __name__ == '__main__':
    run()
