#!/bin/bash

# API Proxy Installer
# Usage: bash <(curl -Ls https://raw.githubusercontent.com/iarmawn/ApiProxy/main/install.sh)

set -e

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
plain='\033[0m'

cur_dir=$(pwd)

# Default values
DEFAULT_PORT=5050
DEFAULT_DEBUG=false
DEFAULT_API_BASE_URL="https://api.openai.com/v1"
DEFAULT_REQUEST_TIMEOUT=18000
DEFAULT_MAX_CONTENT_LENGTH=16777216
DEFAULT_WORKERS=4
DEFAULT_INSTALL_DIR="/opt/api-proxy"
DEFAULT_USER="api-proxy"

# Function to clear screen
clear_screen() {
    clear
}

# Function to get server IP
get_server_ip() {
    local server_ip=$(curl -s --max-time 3 https://api.ipify.org)
    if [ -z "$server_ip" ]; then
        server_ip=$(curl -s --max-time 3 https://4.ident.me)
    fi
    if [ -z "$server_ip" ]; then
        server_ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$server_ip"
}

# Function to open firewall port
open_firewall_port() {
    local port=$1
    print_status "Opening firewall port $port..."
    
    case "${release}" in
    ubuntu | debian | armbian)
        if command_exists ufw; then
            ufw allow $port/tcp
            print_status "UFW port $port opened ✓"
        elif command_exists iptables; then
            iptables -A INPUT -p tcp --dport $port -j ACCEPT
            print_status "iptables port $port opened ✓"
        fi
        ;;
    centos | rhel | almalinux | rocky | ol)
        if command_exists firewall-cmd; then
            firewall-cmd --permanent --add-port=$port/tcp
            firewall-cmd --reload
            print_status "firewalld port $port opened ✓"
        elif command_exists iptables; then
            iptables -A INPUT -p tcp --dport $port -j ACCEPT
            print_status "iptables port $port opened ✓"
        fi
        ;;
    fedora | amzn | virtuozzo)
        if command_exists firewall-cmd; then
            firewall-cmd --permanent --add-port=$port/tcp
            firewall-cmd --reload
            print_status "firewalld port $port opened ✓"
        elif command_exists iptables; then
            iptables -A INPUT -p tcp --dport $port -j ACCEPT
            print_status "iptables port $port opened ✓"
        fi
        ;;
    *)
        if command_exists ufw; then
            ufw allow $port/tcp
            print_status "UFW port $port opened ✓"
        elif command_exists iptables; then
            iptables -A INPUT -p tcp --dport $port -j ACCEPT
            print_status "iptables port $port opened ✓"
        fi
        ;;
    esac
}

# Check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain}Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo -e "${green}The OS release is: ${release}${plain}"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${red}Unsupported CPU architecture! ${plain}" && exit 1 ;;
    esac
}

echo -e "${green}Arch: $(arch)${plain}"

# Function to print colored output
print_status() {
    echo -e "${green}[INFO]${plain} $1"
}

print_warning() {
    echo -e "${yellow}[WARNING]${plain} $1"
}

print_error() {
    echo -e "${red}[ERROR]${plain} $1"
}

print_header() {
    echo -e "${blue}================================${plain}"
    echo -e "${blue}  API Proxy Installer${plain}"
    echo -e "${blue}================================${plain}"
}

print_menu() {
    clear_screen
    echo
    echo -e "${blue}================================${plain}"
    echo -e "${blue}  API Proxy Installation Menu${plain}"
    echo -e "${blue}================================${plain}"
    echo
    echo -e "${green}1. Quick Install${plain} (Recommended)"
    echo -e "   • Uses default settings"
    echo -e "   • Port: 5050, API: OpenAI, Workers: 4"
    echo -e "   • Perfect for most users"
    echo
    echo -e "${yellow}2. Custom Install${plain}"
    echo -e "   • Choose port, API provider, workers"
    echo -e "   • Configure all options interactively"
    echo -e "   • For advanced users"
    echo
    echo -e "${cyan}3. Dependencies Only${plain}"
    echo -e "   • Install Python dependencies only"
    echo -e "   • Manual setup required"
    echo -e "   • For developers"
    echo
    echo -e "${red}4. Exit${plain}"
    echo -e "   • Cancel installation"
    echo
}

print_api_menu() {
    clear_screen
    echo
    echo -e "${blue}API Provider Selection:${plain}"
    echo -e "1. ${green}OpenAI API${plain} (ChatGPT, GPT-4, etc.)"
    echo -e "2. ${yellow}GitLab API${plain} (GitLab repositories, issues, etc.)"
    echo -e "3. ${blue}Custom API${plain} (Your own API endpoint)"
    echo -e "4. ${red}Back${plain}"
    echo
}

print_port_menu() {
    clear_screen
    echo
    echo -e "${blue}Port Selection:${plain}"
    echo -e "1. ${green}Port 5050${plain} (Default)"
    echo -e "2. ${yellow}Port 8080${plain} (Common web port)"
    echo -e "3. ${blue}Port 3000${plain} (Development port)"
    echo -e "4. ${red}Custom Port${plain}"
    echo -e "5. ${red}Back${plain}"
    echo
}

print_worker_menu() {
    clear_screen
    echo
    echo -e "${blue}Worker Configuration:${plain}"
    echo -e "1. ${green}2 Workers${plain} (Development/Low traffic)"
    echo -e "2. ${yellow}4 Workers${plain} (Recommended for most servers)"
    echo -e "3. ${blue}8 Workers${plain} (High traffic servers)"
    echo -e "4. ${red}Custom Workers${plain}"
    echo -e "5. ${red}Back${plain}"
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

# Install base dependencies
install_base() {
    print_status "Installing system dependencies..."
    
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q python3-pip python3-venv python3.10-venv curl wget
        ;;
    centos | rhel | almalinux | rocky | ol)
        yum -y update && yum install -y -q python3-pip python3-venv curl wget
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q python3-pip python3-venv curl wget
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm python-pip python-virtualenv curl wget
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y python3-pip python3-venv curl wget
        ;;
    *)
        apt-get update && apt install -y -q python3-pip python3-venv python3.10-venv curl wget
        ;;
    esac
    
    print_status "System dependencies installed ✓"
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check if curl is available
    if ! command_exists curl; then
        print_warning "curl not found, will install it"
    fi
    
    # Check if python3 is available
    if ! command_exists python3; then
        print_warning "python3 not found, will install it"
    fi
    
    print_status "System requirements check complete ✓"
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

# Create custom installation directory
create_custom_dir() {
    print_status "Creating custom installation directory..."
    
    # Create the custom installation directory
    mkdir -p "$INSTALL_DIR"
    if [[ "$OSTYPE" != "darwin"* ]]; then
        chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    else
        # macOS - use current user ownership
        chown "$SERVICE_USER" "$INSTALL_DIR"
    fi
    
    print_status "Custom directory created ✓"
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
    
    # Set service name for default port
    SERVICE_NAME="api-proxy"
    
    print_status "Configuration:"
    echo -e "  Port: ${blue}$PORT${plain}"
    echo -e "  API: ${blue}$API_BASE_URL${plain}"
    echo -e "  Workers: ${blue}$WORKERS${plain}"
    echo -e "  Directory: ${blue}$INSTALL_DIR${plain}"
    echo
}

# Get configuration from user with menus
get_configuration() {
    print_status "Configuring the proxy..."
    echo
    
    # Check for existing installations
    local existing_ports=()
    local existing_dirs=()
    
    # Find existing api-proxy services
    if [[ "$OSTYPE" != "darwin"* ]]; then
        for service in /etc/systemd/system/api-proxy*.service; do
            if [[ -f "$service" ]]; then
                local port=$(grep -o 'PORT=[0-9]*' "$service" | cut -d'=' -f2)
                local dir=$(grep -o 'WorkingDirectory=[^ ]*' "$service" | cut -d'=' -f2)
                if [[ -n "$port" ]]; then
                    existing_ports+=("$port")
                fi
                if [[ -n "$dir" ]]; then
                    existing_dirs+=("$dir")
                fi
            fi
        done
    fi
    
    # Show existing installations
    if [[ ${#existing_ports[@]} -gt 0 ]]; then
        echo -e "${yellow}Existing API Proxy installations found:${plain}"
        for i in "${!existing_ports[@]}"; do
            echo -e "  Port: ${blue}${existing_ports[$i]}${plain}, Directory: ${blue}${existing_dirs[$i]}${plain}"
        done
        echo
    fi
    
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
                        # Check if port is already in use
                        if [[ " ${existing_ports[@]} " =~ " ${PORT} " ]]; then
                            print_error "Port $PORT is already in use by another proxy. Please choose a different port."
                            continue
                        fi
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
        
        # Check if selected port is already in use
        if [[ " ${existing_ports[@]} " =~ " ${PORT} " ]]; then
            print_error "Port $PORT is already in use by another proxy. Please choose a different port."
            continue
        fi
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
        get_input "Enter request timeout in seconds" "$DEFAULT_REQUEST_TIMEOUT" "REQUEST_TIMEOUT"
        if validate_timeout "$REQUEST_TIMEOUT"; then
            break
        else
            print_error "Invalid timeout. Please enter a positive number."
        fi
    done
    
    # Max content length
    while true; do
        get_input "Enter max content length in bytes" "$DEFAULT_MAX_CONTENT_LENGTH" "MAX_CONTENT_LENGTH"
        if validate_max_content_length "$MAX_CONTENT_LENGTH"; then
            break
        else
            print_error "Invalid max content length. Please enter a positive number."
        fi
    done
    
    # Worker configuration
    while true; do
        print_worker_menu
        read -p "Choose worker configuration (1-5): " worker_choice
        case $worker_choice in
            1) WORKERS=2; break ;;
            2) WORKERS=4; break ;;
            3) WORKERS=8; break ;;
            4)
                while true; do
                    get_input "Enter number of workers" "$DEFAULT_WORKERS" "WORKERS"
                    if [[ "$WORKERS" =~ ^[0-9]+$ ]] && [ "$WORKERS" -gt 0 ]; then
                        break
                    else
                        print_error "Invalid number of workers. Please enter a positive integer."
                    fi
                done
                break
                ;;
            5) continue ;;
            *) print_error "Invalid choice. Please select 1-5." ;;
        esac
    done
    
    # Generate unique installation directory
    if [[ $PORT -eq 5050 ]]; then
        INSTALL_DIR="/opt/api-proxy"
    else
        INSTALL_DIR="/opt/api-proxy-$PORT"
    fi
    
    # Generate unique service name
    if [[ $PORT -eq 5050 ]]; then
        SERVICE_NAME="api-proxy"
    else
        SERVICE_NAME="api-proxy-$PORT"
    fi
    
    SERVICE_USER=$DEFAULT_USER
    
    print_status "Configuration complete ✓"
}

# Setup Python environment
setup_python_env() {
    print_status "Setting up Python virtual environment..."
    
    cd "$INSTALL_DIR"
    
    # Try to create virtual environment
    if ! python3 -m venv venv; then
        print_warning "Virtual environment creation failed, trying alternative method..."
        
        # Try installing venv package if not available
        if ! python3 -c "import venv" 2>/dev/null; then
            print_status "Installing python3-venv package..."
            case "${release}" in
            ubuntu | debian | armbian)
                apt-get install -y python3-venv python3.10-venv
                ;;
            centos | rhel | almalinux | rocky | ol)
                yum install -y python3-venv
                ;;
            fedora | amzn | virtuozzo)
                dnf install -y python3-venv
                ;;
            *)
                apt-get install -y python3-venv python3.10-venv
                ;;
            esac
        fi
        
        # Try again
        if ! python3 -m venv venv; then
            print_error "Failed to create virtual environment. Please install python3-venv manually:"
            print_error "sudo apt install python3-venv python3.10-venv"
            exit 1
        fi
    fi
    
    print_status "Python environment setup complete ✓"
}

# Install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    cd "$INSTALL_DIR"
    source venv/bin/activate
    pip install --upgrade pip
    pip install Flask==3.0.0 requests==2.31.0 python-dotenv==1.0.0 gunicorn==21.2.0
    
    print_status "Python dependencies installed ✓"
}

# Create proxy application
create_proxy_app() {
    print_status "Creating proxy application..."
    
    cd "$INSTALL_DIR"
    
    cat > proxy.py << 'EOF'
#!/usr/bin/env python3
"""
API Proxy - A production-ready proxy server for multiple API services
"""

import os
import time
import uuid
import requests
from flask import Flask, request, Response, jsonify
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# ─── Configuration ──────────────────────────────────────────────────────────────
PORT            = int(os.getenv("PORT", 5050))
DEBUG           = os.getenv("DEBUG", "false").lower() in ("1", "true", "t")
API_BASE_URL    = os.getenv("API_BASE_URL", "https://api.openai.com/v1")
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", 18000))
MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", 16 * 1024 * 1024))  # 16MB default
WORKERS         = int(os.getenv("WORKERS", 4))

# ─── Flask App ─────────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# ─── Security Headers ──────────────────────────────────────────────────────────
@app.after_request
def add_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    return response

# ─── Error Handlers ───────────────────────────────────────────────────────────
@app.errorhandler(413)
def too_large(e):
    return jsonify({"error": "Request too large"}), 413

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Not found"}), 404

@app.errorhandler(500)
def internal_error(e):
    return jsonify({"error": "Internal server error"}), 500

# ─── Health Check ─────────────────────────────────────────────────────────────
@app.route('/health')
def health():
    return jsonify({
        "status": "ok",
        "timestamp": time.time()
    })

# ─── Proxy Endpoint ───────────────────────────────────────────────────────────
@app.route("/<path:path>", methods=[
    "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"
])
def proxy(path):
    # Generate unique request ID
    request_id = str(uuid.uuid4())[:8]
    start_time = time.time()
    
    # Log request
    print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} INFO [{request_id}] {request.method} /{path}")
    
    try:
        # Forward request to upstream API
        url = f"{API_BASE_URL}/{path}"
        
        # Prepare headers
        headers = dict(request.headers)
        headers.pop('Host', None)  # Remove Host header
        
        # Handle compression properly
        if 'Accept-Encoding' in headers:
            headers['Accept-Encoding'] = 'identity'
        
        # Make request to upstream
        response = requests.request(
            method=request.method,
            url=url,
            headers=headers,
            data=request.get_data(),
            params=request.args,
            timeout=REQUEST_TIMEOUT,
            stream=True
        )
        
        # Calculate latency
        latency = (time.time() - start_time) * 1000
        
        # Log response
        print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} INFO [{request_id}] {request.method} /{path} → {response.status_code} in {latency:.1f}ms")
        
        # Prepare response headers
        response_headers = dict(response.headers)
        
        # Remove problematic headers
        excluded_headers = {
            'connection', 'keep-alive', 'proxy-authenticate',
            'proxy-authorization', 'te', 'trailers',
            'transfer-encoding', 'upgrade', 'content-encoding'
        }
        
        filtered_headers = {
            name: value for name, value in response_headers.items()
            if name.lower() not in excluded_headers
        }
        
        # Return response
        return Response(
            response.iter_content(chunk_size=8192),
            status=response.status_code,
            headers=filtered_headers
        )
        
    except requests.exceptions.Timeout:
        latency = (time.time() - start_time) * 1000
        print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} ERROR [{request_id}] {request.method} /{path} → TIMEOUT in {latency:.1f}ms")
        return jsonify({"error": "Request timeout"}), 408
        
    except Exception as e:
        latency = (time.time() - start_time) * 1000
        print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} ERROR [{request_id}] {request.method} /{path} → ERROR: {str(e)} in {latency:.1f}ms")
        return jsonify({"error": "Internal server error"}), 500

# ─── Main ─────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    if DEBUG:
        app.run(host='0.0.0.0', port=PORT, debug=True)
    else:
        from gunicorn.app.base import BaseApplication
        
        class StandaloneApplication(BaseApplication):
            def __init__(self, app, options=None):
                self.options = options or {}
                self.application = app
                super().__init__()
            
            def load_config(self):
                for key, value in self.options.items():
                    self.cfg.set(key, value)
            
            def load(self):
                return self.application
        
        options = {
            'bind': f'0.0.0.0:{PORT}',
            'workers': WORKERS,
            'worker_class': 'sync',
            'timeout': 120,
            'keepalive': 2,
            'max_requests': 1000,
            'max_requests_jitter': 50,
        }
        
        StandaloneApplication(app, options).run()
EOF
    
    chmod +x proxy.py
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
        
        cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=API Proxy (Port $PORT)
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
Environment=PORT=$PORT
Environment=API_BASE_URL=$API_BASE_URL
Environment=REQUEST_TIMEOUT=$REQUEST_TIMEOUT
Environment=MAX_CONTENT_LENGTH=$MAX_CONTENT_LENGTH
Environment=WORKERS=$WORKERS
Environment=DEBUG=$DEBUG
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
        
        systemctl enable $SERVICE_NAME
        systemctl start $SERVICE_NAME
        
        # Wait a moment for service to start
        sleep 3
        
        # Check if service is running
        if systemctl is-active --quiet $SERVICE_NAME; then
            print_status "Service started successfully ✓"
        else
            print_error "Failed to start service"
            systemctl status $SERVICE_NAME
            exit 1
        fi
    fi
}

# Create test script
create_test_script() {
    print_status "Creating test script..."
    
    cd "$INSTALL_DIR"
    
    cat > test_proxy.py << 'EOF'
#!/usr/bin/env python3
"""
Test script for API Proxy
"""

import requests
import sys

def test_health():
    """Test health endpoint"""
    try:
        response = requests.get('http://localhost:5050/health', timeout=5)
        if response.status_code == 200:
            print("✓ Health check passed")
            return True
        else:
            print(f"✗ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Health check failed: {e}")
        return False

def test_proxy():
    """Test proxy endpoint"""
    try:
        response = requests.get('http://localhost:5050/v1/models', timeout=5)
        print(f"✓ Proxy test completed: {response.status_code}")
        return True
    except Exception as e:
        print(f"✗ Proxy test failed: {e}")
        return False

if __name__ == '__main__':
    print("Testing API Proxy...")
    health_ok = test_health()
    proxy_ok = test_proxy()
    
    if health_ok and proxy_ok:
        print("✓ All tests passed!")
        sys.exit(0)
    else:
        print("✗ Some tests failed!")
        sys.exit(1)
EOF
    
    chmod +x test_proxy.py
    print_status "Test script created ✓"
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
    local server_ip=$(get_server_ip)
    
    echo
    echo -e "${green}================================${plain}"
    echo -e "${green}  Installation Complete!${plain}"
    echo -e "${green}================================${plain}"
    echo
    echo -e "Proxy is now running on:"
    echo -e "  Local:  ${blue}http://localhost:$PORT${plain}"
    echo -e "  Public: ${blue}http://$server_ip:$PORT${plain}"
    echo -e "Health check: ${blue}http://$server_ip:$PORT/health${plain}"
    echo -e "Workers: ${blue}$WORKERS${plain}"
    echo
    echo -e "Service commands:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "  Start:   ${yellow}launchctl start com.api-proxy${plain}"
        echo -e "  Stop:    ${yellow}launchctl stop com.api-proxy${plain}"
        echo -e "  Status:  ${yellow}launchctl list | grep api-proxy${plain}"
        echo -e "  Logs:    ${yellow}tail -f /tmp/api-proxy.log${plain}"
    else
        echo -e "  Start:   ${yellow}sudo systemctl start $SERVICE_NAME${plain}"
        echo -e "  Stop:    ${yellow}sudo systemctl stop $SERVICE_NAME${plain}"
        echo -e "  Restart: ${yellow}sudo systemctl restart $SERVICE_NAME${plain}"
        echo -e "  Status:  ${yellow}sudo systemctl status $SERVICE_NAME${plain}"
        echo -e "  Logs:    ${yellow}sudo journalctl -u $SERVICE_NAME -f${plain}"
    fi
    echo
    echo -e "Configuration file: ${blue}$INSTALL_DIR/.env${plain}"
    echo -e "Test script: ${blue}$INSTALL_DIR/test_proxy.py${plain}"
    echo
    echo -e "To test the proxy:"
    echo -e "  ${yellow}curl http://$server_ip:$PORT/health${plain}"
    echo -e "  ${yellow}python3 $INSTALL_DIR/test_proxy.py${plain}"
    echo
    echo -e "Example usage:"
    echo -e "  ${yellow}# OpenAI API${plain}"
    echo -e "  ${yellow}curl http://$server_ip:$PORT/chat/completions \\${plain}"
    echo -e "    ${yellow}-H \"Authorization: Bearer sk-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\" \\${plain}"
    echo -e "    ${yellow}-H \"Content-Type: application/json\" \\${plain}"
    echo -e "    ${yellow}-d '{\"model\": \"gpt-4.1\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'${plain}"
    echo -e "  ${yellow}# GitLab API${plain}"
    echo -e "  ${yellow}curl http://$server_ip:$PORT/v4/projects \\${plain}"
    echo -e "    ${yellow}-H \"Authorization: Bearer YOUR_GITLAB_TOKEN\"${plain}"
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
    install_base
    
    # Setup user and directory
    setup_user_and_dir
    
    # Show main menu (works in both interactive and non-interactive modes)
    print_menu
    if [ ! -t 0 ]; then
        # Non-interactive mode: wait a moment then use Quick Install
        echo
        print_status "Non-interactive mode detected (curl | sudo bash)"
        print_status "Starting Quick Install in 3 seconds..."
        print_status "Press Ctrl+C to cancel and run interactively."
        echo
        sleep 3
        menu_choice=1
    else
        # Interactive mode: get user input
        read -p "Choose installation option (1-4): " menu_choice
    fi
    
    case $menu_choice in
        1)
            print_status "Starting Quick Install..."
            quick_install
            ;;
        2)
            print_status "Starting Custom Install..."
            get_configuration
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
            print_error "Invalid choice. Using Quick Install..."
            quick_install
            ;;
    esac
    
    # Create custom directory if needed
    if [[ "$INSTALL_DIR" != "$DEFAULT_INSTALL_DIR" ]]; then
        create_custom_dir
    fi
    
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
    
    # Open firewall port
    open_firewall_port $PORT
    
    # Start service
    start_service
    
    # Test installation
    test_installation
    
    # Show final information
    show_final_info
}

echo -e "${green}Running...${plain}"
main "$@" 