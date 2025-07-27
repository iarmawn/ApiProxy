#!/bin/bash

# OpenAI Proxy Installer
# Usage: curl -sSL https://raw.githubusercontent.com/iarmawn/OpenAiProxy/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT=5050
DEFAULT_DEBUG=false
DEFAULT_API_BASE_URL="https://api.openai.com/v1"
DEFAULT_REQUEST_TIMEOUT=18000
DEFAULT_MAX_CONTENT_LENGTH=16777216
DEFAULT_WORKERS=4
DEFAULT_INSTALL_DIR="/opt/api-proxy"
DEFAULT_USER="api-proxy"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  API Proxy Installer${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_menu() {
    echo
    echo -e "${BLUE}Installation Options:${NC}"
    echo -e "1. ${GREEN}Quick Install${NC} (Recommended - uses defaults)"
    echo -e "2. ${YELLOW}Custom Install${NC} (Configure all options)"
    echo -e "3. ${BLUE}Install Dependencies Only${NC}"
    echo -e "4. ${RED}Exit${NC}"
    echo
}

print_api_menu() {
    echo
    echo -e "${BLUE}API Provider Selection:${NC}"
    echo -e "1. ${GREEN}OpenAI API${NC} (ChatGPT, GPT-4, etc.)"
    echo -e "2. ${YELLOW}GitLab API${NC} (GitLab repositories, issues, etc.)"
    echo -e "3. ${BLUE}Custom API${NC} (Your own API endpoint)"
    echo -e "4. ${RED}Back${NC}"
    echo
}

print_port_menu() {
    echo
    echo -e "${BLUE}Port Selection:${NC}"
    echo -e "1. ${GREEN}Port 5050${NC} (Default)"
    echo -e "2. ${YELLOW}Port 8080${NC} (Common web port)"
    echo -e "3. ${BLUE}Port 3000${NC} (Development port)"
    echo -e "4. ${RED}Custom Port${NC}"
    echo -e "5. ${RED}Back${NC}"
    echo
}

print_worker_menu() {
    echo
    echo -e "${BLUE}Worker Configuration:${NC}"
    echo -e "1. ${GREEN}2 Workers${NC} (Development/Low traffic)"
    echo -e "2. ${YELLOW}4 Workers${NC} (Recommended for most servers)"
    echo -e "3. ${BLUE}8 Workers${NC} (High traffic servers)"
    echo -e "4. ${RED}Custom Workers${NC}"
    echo -e "5. ${RED}Back${NC}"
    echo
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\${input:-$default}"
    else
        read -p "$prompt: " input
        eval "$var_name=\$input"
    fi
}

# Function to validate port
validate_port() {
    local port=$1
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Function to validate URL
validate_url() {
    local url=$1
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate timeout
validate_timeout() {
    local timeout=$1
    if [[ "$timeout" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$timeout > 0" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

# Function to validate max content length
validate_max_content_length() {
    local max_length=$1
    if [[ "$max_length" =~ ^[0-9]+$ ]] && [ "$max_length" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to validate workers
validate_workers() {
    local workers=$1
    if [[ "$workers" =~ ^[0-9]+$ ]] && [ "$workers" -ge 1 ] && [ "$workers" -le 32 ]; then
        return 0
    else
        return 1
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        print_status "Run: sudo ./install.sh"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check Python
    if ! command_exists python3; then
        print_error "Python 3 is required but not installed"
        print_status "The installer will attempt to install it automatically"
    fi
    
    # Check pip
    if ! command_exists pip3; then
        print_error "pip3 is required but not installed"
        print_status "The installer will attempt to install it automatically"
    fi
    
    print_status "System requirements check complete ✓"
}

# Install system dependencies
install_system_deps() {
    print_status "Installing system dependencies..."
    
    # Detect OS and install dependencies
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        print_status "Detected macOS"
        if command_exists brew; then
            print_status "Installing dependencies via Homebrew..."
            brew install python3 curl
        else
            print_error "Homebrew not found on macOS"
            print_status "Please install Homebrew first:"
            print_status "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            print_status "Then run this installer again"
            exit 1
        fi
    elif command_exists apt-get; then
        # Ubuntu/Debian
        print_status "Detected Ubuntu/Debian"
        apt-get update
        apt-get install -y python3-pip python3-venv curl
        print_status "Dependencies installed via apt ✓"
    elif command_exists yum; then
        # CentOS/RHEL
        print_status "Detected CentOS/RHEL"
        yum install -y python3-pip python3-venv curl
        print_status "Dependencies installed via yum ✓"
    elif command_exists dnf; then
        # Fedora
        print_status "Detected Fedora"
        dnf install -y python3-pip python3-venv curl
        print_status "Dependencies installed via dnf ✓"
    else
        print_error "Could not detect supported package manager"
        print_status "Supported systems: Ubuntu, Debian, CentOS, RHEL, Fedora, macOS"
        exit 1
    fi
    
    print_status "System dependencies installed ✓"
}

# Create user and directory
setup_user_and_dir() {
    print_status "Setting up user and directory..."
    
    # Create user if it doesn't exist (Linux only)
    if [[ "$OSTYPE" != "darwin"* ]]; then
        if ! id "$DEFAULT_USER" &>/dev/null; then
            useradd -r -s /bin/false -d "$DEFAULT_INSTALL_DIR" "$DEFAULT_USER"
            print_status "Created user: $DEFAULT_USER"
        else
            print_status "User $DEFAULT_USER already exists"
        fi
    else
        # macOS - use current user
        DEFAULT_USER=$(whoami)
        print_status "Using current user: $DEFAULT_USER"
    fi
    
    # Create installation directory
    mkdir -p "$DEFAULT_INSTALL_DIR"
    if [[ "$OSTYPE" != "darwin"* ]]; then
        chown "$DEFAULT_USER:$DEFAULT_USER" "$DEFAULT_INSTALL_DIR"
    else
        # macOS - use current user ownership
        chown "$DEFAULT_USER" "$DEFAULT_INSTALL_DIR"
    fi
    
    print_status "Directory setup complete ✓"
}

# Quick install with defaults
quick_install() {
    print_status "Using default configuration..."
    PORT=$DEFAULT_PORT
    DEBUG=$DEFAULT_DEBUG
    API_BASE_URL=$DEFAULT_API_BASE_URL
    REQUEST_TIMEOUT=$DEFAULT_REQUEST_TIMEOUT
    MAX_CONTENT_LENGTH=$DEFAULT_MAX_CONTENT_LENGTH
    WORKERS=$DEFAULT_WORKERS
    INSTALL_DIR=$DEFAULT_INSTALL_DIR
    SERVICE_USER=$DEFAULT_USER
    
    print_status "Configuration:"
    echo -e "  Port: ${BLUE}$PORT${NC}"
    echo -e "  API: ${BLUE}$API_BASE_URL${NC}"
    echo -e "  Workers: ${BLUE}$WORKERS${NC}"
    echo -e "  Directory: ${BLUE}$INSTALL_DIR${NC}"
    echo
}

# Get configuration from user with menus
get_configuration() {
    print_status "Configuring the proxy..."
    echo
    
    # Port selection
    while true; do
        print_port_menu
        read -p "Choose port option (1-5): " port_choice
        case $port_choice in
            1) PORT=5050; break ;;
            2) PORT=8080; break ;;
            3) PORT=3000; break ;;
            4) 
                while true; do
                    get_input "Enter custom port number" "$DEFAULT_PORT" "PORT"
                    if validate_port "$PORT"; then
                        break
                    else
                        print_error "Invalid port number. Please enter a number between 1 and 65535."
                    fi
                done
                break
                ;;
            5) continue ;;
            *) print_error "Invalid choice. Please select 1-5." ;;
        esac
    done
    
    # Debug mode
    get_input "Enable debug mode (true/false)" "$DEFAULT_DEBUG" "DEBUG"
    
    # API selection
    while true; do
        print_api_menu
        read -p "Choose API provider (1-4): " api_choice
        case $api_choice in
            1)
                API_BASE_URL="https://api.openai.com/v1"
                print_status "Selected: OpenAI API"
                break
                ;;
            2)
                API_BASE_URL="https://gitlab.com/api"
                print_status "Selected: GitLab API"
                break
                ;;
            3)
                while true; do
                    get_input "Enter custom API base URL" "$DEFAULT_API_BASE_URL" "API_BASE_URL"
                    if validate_url "$API_BASE_URL"; then
                        break
                    else
                        print_error "Invalid URL. Please enter a valid HTTP/HTTPS URL."
                    fi
                done
                break
                ;;
            4) continue ;;
            *) print_error "Invalid choice. Please select 1-4." ;;
        esac
    done
    
    # Request timeout
    while true; do
        get_input "Enter request timeout (seconds)" "$DEFAULT_REQUEST_TIMEOUT" "REQUEST_TIMEOUT"
        if validate_timeout "$REQUEST_TIMEOUT"; then
            break
        else
            print_error "Invalid timeout. Please enter a positive number."
        fi
    done
    
    # Max content length
    while true; do
        get_input "Enter max content length (bytes)" "$DEFAULT_MAX_CONTENT_LENGTH" "MAX_CONTENT_LENGTH"
        if validate_max_content_length "$MAX_CONTENT_LENGTH"; then
            break
        else
            print_error "Invalid max content length. Please enter a positive number."
        fi
    done
    
    # Worker selection
    while true; do
        print_worker_menu
        read -p "Choose worker configuration (1-5): " worker_choice
        case $worker_choice in
            1) WORKERS=2; break ;;
            2) WORKERS=4; break ;;
            3) WORKERS=8; break ;;
            4) 
                while true; do
                    get_input "Enter custom number of workers (1-32)" "$DEFAULT_WORKERS" "WORKERS"
                    if validate_workers "$WORKERS"; then
                        break
                    else
                        print_error "Invalid number of workers. Please enter a number between 1 and 32."
                    fi
                done
                break
                ;;
            5) continue ;;
            *) print_error "Invalid choice. Please select 1-5." ;;
        esac
    done
    
    # Install directory
    get_input "Enter installation directory" "$DEFAULT_INSTALL_DIR" "INSTALL_DIR"
    
    # Service user
    get_input "Enter service user" "$DEFAULT_USER" "SERVICE_USER"
    
    print_status "Configuration complete ✓"
    echo
    print_status "Selected configuration:"
    echo -e "  Port: ${BLUE}$PORT${NC}"
    echo -e "  API: ${BLUE}$API_BASE_URL${NC}"
    echo -e "  Workers: ${BLUE}$WORKERS${NC}"
    echo -e "  Directory: ${BLUE}$INSTALL_DIR${NC}"
    echo
}

# Create virtual environment
setup_python_env() {
    print_status "Setting up Python virtual environment..."
    
    cd "$INSTALL_DIR"
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    print_status "Python environment setup complete ✓"
}

# Install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    cd "$INSTALL_DIR"
    source venv/bin/activate
    
    # Create requirements.txt
    cat > requirements.txt << EOF
Flask==3.0.0
requests==2.31.0
python-dotenv==1.0.0
gunicorn==21.2.0
EOF
    
    pip install -r requirements.txt
    
    print_status "Python dependencies installed ✓"
}

# Create proxy application
create_proxy_app() {
    print_status "Creating proxy application..."
    
    cd "$INSTALL_DIR"
    
    # Create proxy.py
    cat > proxy.py << 'EOF'
# proxy.py

#!/usr/bin/env python3
import os
import sys
import time
import uuid
import logging
from flask import Flask, request, Response, jsonify
import requests
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# ─── Logging Filter ─────────────────────────────────────────────────────────────
class RequestIDFilter(logging.Filter):
    def filter(self, record):
        try:
            record.request_id = request.request_id
        except Exception:
            record.request_id = "-"
        return True

# ─── Basic Logging Setup ────────────────────────────────────────────────────────
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(request_id)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

# Attach filter to root, werkzeug, and our logger
root_logger = logging.getLogger()
root_logger.addFilter(RequestIDFilter())
logging.getLogger("werkzeug").addFilter(RequestIDFilter())
logging.getLogger("urllib3.connectionpool").setLevel(logging.WARNING)

logger = logging.getLogger("openai-proxy")
logger.addFilter(RequestIDFilter())

# ─── Configuration ──────────────────────────────────────────────────────────────
PORT            = int(os.getenv("PORT", 5050))
DEBUG           = os.getenv("DEBUG", "false").lower() in ("1", "true", "t")
OPENAI_BASE     = os.getenv("OPENAI_BASE", "https://api.openai.com")
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", 10))
MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", 16 * 1024 * 1024))  # 16MB default

# ─── Flask App ─────────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# Security headers
@app.after_request
def add_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    return response

@app.before_request
def start_request():
    request.request_id = uuid.uuid4().hex[:8]
    request.start_time = time.time()

@app.after_request
def log_request(response):
    latency_ms = (time.time() - request.start_time) * 1000
    logger.info(f"{request.method} {request.full_path} → {response.status_code} in {latency_ms:.1f}ms")
    return response

# ─── Error Handlers ────────────────────────────────────────────────────────────
@app.errorhandler(413)
def too_large(e):
    return jsonify(error="Request too large"), 413

@app.errorhandler(404)
def not_found(e):
    return jsonify(error="Not found"), 404

@app.errorhandler(500)
def internal_error(e):
    return jsonify(error="Internal server error"), 500

# ─── Health Check ──────────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify(status="ok", timestamp=time.time()), 200

# ─── Proxy Endpoint ─────────────────────────────────────────────────────────────
@app.route("/<path:path>", methods=[
    "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"
])
def proxy(path):
    upstream_path = path if path.startswith("v1/") else f"v1/{path}"
    url = f"{OPENAI_BASE}/{upstream_path}"

    # Copy headers, drop Host and Accept-Encoding
    headers = {
        k: v
        for k, v in request.headers.items()
        if k.lower() not in ("host", "accept-encoding")
    }
    headers["Accept-Encoding"] = "identity"

    try:
        upstream = requests.request(
            method=request.method,
            url=url,
            params=request.args,
            headers=headers,
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False,
            stream=True,
            timeout=REQUEST_TIMEOUT
        )
    except requests.Timeout:
        logger.error("Upstream request timed out")
        return jsonify(error="Upstream timeout"), 502
    except requests.RequestException as e:
        logger.error(f"Upstream request failed: {e!r}")
        return jsonify(error="Bad gateway"), 502

    excluded = {
        "connection", "keep-alive", "proxy-authenticate",
        "proxy-authorization", "te", "trailers",
        "transfer-encoding", "upgrade", "content-encoding"
    }
    response_headers = [
        (name, value)
        for name, value in upstream.raw.headers.items()
        if name.lower() not in excluded
    ]

    return Response(
        upstream.raw,
        status=upstream.status_code,
        headers=response_headers
    )

# ─── Entrypoint ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logger.info(f"Starting proxy on 0.0.0.0:{PORT}")
    if DEBUG:
        app.run(host="0.0.0.0", port=PORT, debug=DEBUG)
    else:
        # Production mode - use gunicorn
        from gunicorn.app.base import BaseApplication
        
        class StandaloneApplication(BaseApplication):
            def __init__(self, app, options=None):
                self.options = options or {}
                self.application = app
                super().__init__()

            def load_config(self):
                for key, value in self.options.items():
                    self.cfg.set(key.lower(), value)

            def load(self):
                return self.application

        options = {
            'bind': f'0.0.0.0:{PORT}',
            'workers': int(os.getenv("WORKERS", 4)),
            'worker_class': 'sync',
            'timeout': 120,
            'keepalive': 2,
            'max_requests': 1000,
            'max_requests_jitter': 50,
        }
        
        StandaloneApplication(app, options).run()
EOF
    
    # Create .env file
    cat > .env << EOF
# API Proxy Configuration
PORT=$PORT
DEBUG=$DEBUG
API_BASE_URL=$API_BASE_URL
REQUEST_TIMEOUT=$REQUEST_TIMEOUT
MAX_CONTENT_LENGTH=$MAX_CONTENT_LENGTH
WORKERS=$WORKERS

# Optional: Add your API key if you want to add authentication
# API_KEY=your_api_key_here
EOF
    
    # Make proxy.py executable
    chmod +x proxy.py
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    
    print_status "Proxy application created ✓"
}

# Create systemd service
create_systemd_service() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - create launchd service
        print_status "Creating launchd service for macOS..."
        
        cat > ~/Library/LaunchAgents/com.api-proxy.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.api-proxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/venv/bin/python</string>
        <string>$INSTALL_DIR/proxy.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/api-proxy.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/api-proxy.error.log</string>
</dict>
</plist>
EOF
        
        # Load the service
        launchctl load ~/Library/LaunchAgents/com.api-proxy.plist
        print_status "Launchd service created ✓"
    else
        # Linux - create systemd service
        print_status "Creating systemd service..."
        
        cat > /etc/systemd/system/api-proxy.service << EOF
[Unit]
Description=API Proxy
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/proxy.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd
        systemctl daemon-reload
        print_status "Systemd service created ✓"
    fi
}

# Create test script
create_test_script() {
    print_status "Creating test script..."
    
    cat > "$INSTALL_DIR/test_proxy.py" << 'EOF'
#!/usr/bin/env python3
"""
Simple test script for the OpenAI proxy
"""

import requests
import time

def test_health():
    """Test the health endpoint"""
    try:
        response = requests.get("http://localhost:5050/health", timeout=5)
        if response.status_code == 200:
            print("✅ Health check passed")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Health check failed: {e}")
        return False

def test_proxy():
    """Test the proxy with a simple OpenAI API call"""
    try:
        # Test with OpenAI models endpoint (doesn't require API key)
        response = requests.get("http://localhost:5050/v1/models", timeout=10)
        if response.status_code in [200, 401]:  # 401 is expected without API key
            print("✅ Proxy test passed")
            return True
        else:
            print(f"❌ Proxy test failed: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Proxy test failed: {e}")
        return False

if __name__ == "__main__":
    print("Testing OpenAI Proxy...")
    print("=" * 30)
    
    health_ok = test_health()
    proxy_ok = test_proxy()
    
    print("=" * 30)
    if health_ok and proxy_ok:
        print("🎉 All tests passed! Proxy is working correctly.")
    else:
        print("❌ Some tests failed. Check the proxy configuration.")
EOF
    
    chmod +x "$INSTALL_DIR/test_proxy.py"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/test_proxy.py"
    
    print_status "Test script created ✓"
}

# Start and enable service
start_service() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - start launchd service
        print_status "Starting launchd service..."
        launchctl start com.api-proxy
        
        # Wait a moment for service to start
        sleep 3
        
        # Check if service is running
        if launchctl list | grep -q com.api-proxy; then
            print_status "Service started successfully ✓"
        else
            print_error "Failed to start service"
            exit 1
        fi
    else
        # Linux - start systemd service
        print_status "Starting and enabling service..."
        
        systemctl enable api-proxy
        systemctl start api-proxy
        
        # Wait a moment for service to start
        sleep 3
        
        # Check if service is running
        if systemctl is-active --quiet api-proxy; then
            print_status "Service started successfully ✓"
        else
            print_error "Failed to start service"
            systemctl status api-proxy
            exit 1
        fi
    fi
}

# Test the installation
test_installation() {
    print_status "Testing installation..."
    
    # Wait a bit more for the service to fully start
    sleep 2
    
    # Test health endpoint
    if curl -s http://localhost:$PORT/health > /dev/null; then
        print_status "Health check passed ✓"
    else
        print_warning "Health check failed - service may still be starting"
    fi
    
    print_status "Installation test complete ✓"
}

# Display final information
show_final_info() {
    echo
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo
    echo -e "Proxy is now running on: ${BLUE}http://localhost:$PORT${NC}"
    echo -e "Health check: ${BLUE}http://localhost:$PORT/health${NC}"
    echo -e "Workers: ${BLUE}$WORKERS${NC}"
    echo
    echo -e "Service commands:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "  Start:   ${YELLOW}launchctl start com.api-proxy${NC}"
        echo -e "  Stop:    ${YELLOW}launchctl stop com.api-proxy${NC}"
        echo -e "  Status:  ${YELLOW}launchctl list | grep api-proxy${NC}"
        echo -e "  Logs:    ${YELLOW}tail -f /tmp/api-proxy.log${NC}"
    else
        echo -e "  Start:   ${YELLOW}sudo systemctl start api-proxy${NC}"
        echo -e "  Stop:    ${YELLOW}sudo systemctl stop api-proxy${NC}"
        echo -e "  Restart: ${YELLOW}sudo systemctl restart api-proxy${NC}"
        echo -e "  Status:  ${YELLOW}sudo systemctl status api-proxy${NC}"
        echo -e "  Logs:    ${YELLOW}sudo journalctl -u api-proxy -f${NC}"
    fi
    echo
    echo -e "Configuration file: ${BLUE}$INSTALL_DIR/.env${NC}"
    echo -e "Test script: ${BLUE}$INSTALL_DIR/test_proxy.py${NC}"
    echo
    echo -e "To test the proxy:"
    echo -e "  ${YELLOW}curl http://localhost:$PORT/health${NC}"
    echo -e "  ${YELLOW}python3 $INSTALL_DIR/test_proxy.py${NC}"
    echo
    echo -e "Example usage:"
    echo -e "  ${YELLOW}# OpenAI API${NC}"
    echo -e "  ${YELLOW}curl http://localhost:$PORT/chat/completions \\${NC}"
    echo -e "    ${YELLOW}-H \"Authorization: Bearer YOUR_API_KEY\" \\${NC}"
    echo -e "    ${YELLOW}-H \"Content-Type: application/json\" \\${NC}"
    echo -e "    ${YELLOW}-d '{\"model\": \"gpt-3.5-turbo\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'${NC}"
    echo -e "  ${YELLOW}# GitLab API${NC}"
    echo -e "  ${YELLOW}curl http://localhost:$PORT/v4/projects \\${NC}"
    echo -e "    ${YELLOW}-H \"Authorization: Bearer YOUR_GITLAB_TOKEN\"${NC}"
    echo
}

# Main installation function
main() {
    print_header
    
    # Check if running as root
    check_root
    
    # Check requirements
    check_requirements
    
    # Install system dependencies
    install_system_deps
    
    # Setup user and directory
    setup_user_and_dir
    
    # Show main menu
    while true; do
        print_menu
        read -p "Choose installation option (1-4): " menu_choice
        case $menu_choice in
            1)
                print_status "Starting Quick Install..."
                quick_install
                break
                ;;
            2)
                print_status "Starting Custom Install..."
                get_configuration
                break
                ;;
            3)
                print_status "Installing dependencies only..."
                setup_python_env
                install_python_deps
                print_status "Dependencies installed successfully!"
                print_status "You can now run: python3 proxy.py"
                exit 0
                ;;
            4)
                print_status "Installation cancelled."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please select 1-4."
                ;;
        esac
    done
    
    # Setup Python environment
    setup_python_env
    
    # Install Python dependencies
    install_python_deps
    
    # Create proxy application
    create_proxy_app
    
    # Create systemd service
    create_systemd_service
    
    # Create test script
    create_test_script
    
    # Start service
    start_service
    
    # Test installation
    test_installation
    
    # Show final information
    show_final_info
}

# Run main function
main "$@" 