import http.server
import socketserver
import os
import signal
import subprocess
import sys
import json
import time

# Ruta absoluta y configuración
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PORT = 8000
DATA_FILE = os.path.join(BASE_DIR, "data", "datos.json")
LOCK_FILE = os.path.join(BASE_DIR, "monitor.lock")

# Buffer de historial para los gráficos (Máximo 1200 muestras - 1 hora aprox)
HISTORY_BUFFER = []
MAX_HISTORY = 1200
LAST_RECORDED_TIME = 0

class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        global LAST_RECORDED_TIME
        
        if self.path.startswith('/data'):
            if os.path.exists(DATA_FILE):
                try:
                    with open(DATA_FILE, 'r', encoding='utf-8-sig') as f:
                        content = f.read()
                        
                    # Grabar en el historial si ha pasado suficiente tiempo
                    current_time = time.time()
                    if current_time - LAST_RECORDED_TIME >= 1.0:
                        try:
                            data = json.loads(content)
                            if data.get('cpu', {}).get('temp') != "N/A":
                                # Capturar temperaturas de discos
                                disk_temps = {}
                                for d in data.get('discos', []):
                                    try:
                                        disk_temps[d['letra']] = float(d['temp'])
                                    except: pass

                                snapshot = {
                                    'ts': time.strftime('%H:%M:%S'),
                                    'cpu_t': data['cpu']['temp'],
                                    'cpu_u': data['cpu']['uso'],
                                    'gpu_t': data['gpu']['temp'],
                                    'gpu_u': data['gpu']['uso'],
                                    'ram_p': data['ram']['porcentaje'],
                                    'disks': disk_temps
                                }
                                HISTORY_BUFFER.append(snapshot)
                                if len(HISTORY_BUFFER) > MAX_HISTORY:
                                    HISTORY_BUFFER.pop(0)
                                LAST_RECORDED_TIME = current_time
                        except Exception as e:
                            print(f"Error grabando historial: {e}")

                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
                    self.end_headers()
                    self.wfile.write(content.encode('utf-8'))
                except Exception as e:
                    self.send_error(500, f"Error leyendo datos: {str(e)}")
            else:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                default_data = {
                    "cpu": {"temp": "N/A", "uso": 0, "nombre": "Cargando...", "tag": "N/A"},
                    "ram": {"temp": "N/A", "porcentaje": 0, "nombre": "Cargando...", "tag": "N/A"},
                    "gpu": {"temp": "N/A", "uso": 0, "nombre": "Cargando...", "tag": "N/A"},
                    "discos": []
                }
                self.wfile.write(json.dumps(default_data).encode('utf-8'))
            return

        elif self.path == '/history':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(HISTORY_BUFFER).encode('utf-8'))
            return

        elif self.path == '/shutdown':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b"Shutting down...")
            
            if os.path.exists(LOCK_FILE):
                try: os.remove(LOCK_FILE)
                except: pass
            
            subprocess.run(['powershell', '-Command', "Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*UlanziEngine*' } | Stop-Process -Force"], capture_output=True)
            subprocess.run(['taskkill', '/F', '/IM', 'HWiNFO64.exe', '/T'], capture_output=True)
            os._exit(0)
        else:
            return http.server.SimpleHTTPRequestHandler.do_GET(self)

os.chdir(BASE_DIR)

if __name__ == "__main__":
    # Limpiar datos antiguos al arrancar el servidor
    data_file = os.path.join(BASE_DIR, 'data', 'datos.json')
    if os.path.exists(data_file):
        try:
            os.remove(data_file)
        except:
            pass

    try:
        with open(LOCK_FILE, "w") as f:
            f.write("running")
        with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
            print(f"Servidor ACTIVO en puerto {PORT}")
            httpd.serve_forever()
    finally:
        if os.path.exists(LOCK_FILE):
            try: os.remove(LOCK_FILE)
            except: pass
