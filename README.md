# API Proxy

A production-ready proxy server for multiple API services that adds request logging, monitoring, and security features.

[![GitHub](https://img.shields.io/badge/GitHub-ApiProxy-blue)](https://github.com/iarmawn/ApiProxy)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- 🔄 **Multi-API Support**: Proxies OpenAI, GitLab, and custom APIs
- 📊 **Request Logging**: Unique request IDs and latency tracking
- 🛡️ **Security Headers**: Production-ready security configurations
- 🏥 **Health Checks**: Built-in health monitoring endpoint
- ⚡ **Production Mode**: Gunicorn WSGI server for production
- 🔧 **Environment Config**: Easy configuration via .env file
- 🚀 **One-Click Install**: Simple curl-to-install script
- 📦 **Systemd Service**: Automatic service management
- 🔧 **Multi-Proxy Support**: Run multiple proxy instances
- 🖥️ **Cross-Platform**: Works on Ubuntu, macOS, CentOS, and Fedora

## Quick Start

### 🚀 One-Click Installation (Recommended)

Install directly with curl:
```bash
curl -sSL https://raw.githubusercontent.com/iarmawn/ApiProxy/main/install.sh | sudo bash
```

Or download and run locally:
```bash
curl -sSL https://raw.githubusercontent.com/iarmawn/ApiProxy/main/install.sh -o install.sh
sudo bash install.sh
```



The installer will:
- ✅ Check system requirements
- ✅ Install dependencies
- ✅ Create service user
- ✅ Configure the proxy interactively
- ✅ Set up systemd service
- ✅ Start the proxy automatically

### Manual Setup

1. Clone the repository:
```bash
git clone https://github.com/iarmawn/ApiProxy.git
cd ApiProxy
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your settings
```

4. Run the proxy:
```bash
python proxy.py
```

## Project Structure

```
ApiProxy/
├── proxy.py              # Main proxy application
├── install.sh            # Interactive installer script
├── uninstall.sh          # Uninstaller script
├── test_proxy.py         # Test script
├── requirements.txt      # Python dependencies
├── .env.example          # Environment variables template
├── .gitignore           # Git ignore rules
├── LICENSE              # MIT License
└── README.md            # This file
```

## Multi-Proxy Architecture

The proxy supports running multiple instances for different APIs:

```
Proxy Instance 1 (OpenAI):
├── Port: 5050
├── API: https://api.openai.com/v1
└── Service: api-proxy

Proxy Instance 2 (GitLab):
├── Port: 5051
├── API: https://gitlab.com/api
└── Service: api-proxy-gitlab

Proxy Instance 3 (Custom):
├── Port: 5052
├── API: https://your-api.com
└── Service: api-proxy-custom
```

## Configuration

### Worker Configuration

The number of workers determines how many concurrent requests the proxy can handle:

- **1-4 workers**: Good for development and low-traffic servers
- **4-8 workers**: Recommended for most production servers
- **8-16 workers**: For high-traffic servers with multiple CPU cores
- **16-32 workers**: For very high-traffic servers (use with caution)

**Formula**: Generally, `(2 x CPU cores) + 1` is a good starting point.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `5050` | Port to run the proxy on |
| `DEBUG` | `false` | Enable debug mode |
| `API_BASE_URL` | `https://api.openai.com/v1` | Base URL for API (OpenAI, GitLab, etc.) |
| `REQUEST_TIMEOUT` | `18000` | Timeout for upstream requests (seconds) |
| `MAX_CONTENT_LENGTH` | `16777216` | Maximum request size in bytes (16MB) |
| `WORKERS` | `4` | Number of Gunicorn workers (1-32) |

### Example .env file:
```env
PORT=5050
DEBUG=false
API_BASE_URL=https://api.openai.com/v1
REQUEST_TIMEOUT=18000
MAX_CONTENT_LENGTH=16777216
WORKERS=4
```

## API Providers

The proxy supports multiple API providers:

### OpenAI API (Default)
- **Base URL**: `https://api.openai.com/v1`
- **Usage**: All OpenAI API endpoints work seamlessly
- **Example**: `/chat/completions`, `/models`, `/embeddings`

### GitLab API
- **Base URL**: `https://gitlab.com/api`
- **Usage**: All GitLab API endpoints work with `/v4/` prefix
- **Example**: `/v4/projects`, `/v4/users`, `/v4/groups`

### Custom API
- **Base URL**: Any HTTP/HTTPS URL
- **Usage**: Works with any REST API
- **Example**: Your own API endpoints

## Usage

### OpenAI API Usage

**With curl:**
```bash
curl http://localhost:5050/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-3.5-turbo", "messages": [{"role": "user", "content": "Hello!"}]}'
```

**With Python OpenAI library:**
```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-O0ykoqUhiFue5sO4zzcC-C_zlQVEdMWCh7Jy4paKymd1CQsk3qgNHyTCnRN6WknRGRCpMkA",
    base_url="http://localhost:5050",
)

response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### GitLab API Usage

**With curl:**
```bash
curl http://localhost:5050/v4/projects \
  -H "Authorization: Bearer YOUR_GITLAB_TOKEN"
```

**With Python requests:**
```python
import requests

response = requests.get(
    "http://localhost:5050/v4/projects",
    headers={"Authorization": "Bearer YOUR_GITLAB_TOKEN"}
)
```

### Health Check

```bash
curl http://localhost:5050/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": 1703123456.789
}
```

## Production Deployment

### Systemd Service Management

If installed via the installer script, the proxy runs as a systemd service:

```bash
# Start the service
sudo systemctl start api-proxy

# Stop the service
sudo systemctl stop api-proxy

# Restart the service
sudo systemctl restart api-proxy

# Check status
sudo systemctl status api-proxy

# View logs
sudo journalctl -u api-proxy -f

# Enable auto-start on boot
sudo systemctl enable api-proxy
```

### Multi-Proxy Support

You can run multiple proxy instances for different APIs:

```bash
# First proxy (OpenAI) on port 5050
sudo systemctl start api-proxy

# Second proxy (GitLab) on port 5051
sudo API_BASE_URL=https://gitlab.com/api PORT=5051 python3 proxy.py

# Third proxy (Custom) on port 5052
sudo API_BASE_URL=https://your-api.com PORT=5052 python3 proxy.py
```

### Development Setup

```bash
# Clone the repository
git clone https://github.com/iarmawn/ApiProxy.git
cd ApiProxy

# Install dependencies
pip install -r requirements.txt

# Run in development mode
DEBUG=true python proxy.py
```

### Kubernetes Deployment

Create a `k8s-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openai-proxy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: openai-proxy
  template:
    metadata:
      labels:
        app: openai-proxy
    spec:
      containers:
      - name: openai-proxy
        image: openai-proxy:latest
        ports:
        - containerPort: 5050
        env:
        - name: PORT
          value: "5050"
        - name: DEBUG
          value: "false"
        - name: REQUEST_TIMEOUT
          value: "10"
        livenessProbe:
          httpGet:
            path: /health
            port: 5050
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5050
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: openai-proxy-service
spec:
  selector:
    app: openai-proxy
  ports:
  - port: 80
    targetPort: 5050
  type: LoadBalancer
```

## Monitoring

### Logs

The proxy logs all requests with:
- Unique request ID
- HTTP method and path
- Response status code
- Request latency

Example log:
```
2024-01-15 10:30:45 INFO [a1b2c3d4] POST /v1/chat/completions → 200 in 1250.3ms
```

### Metrics

You can extend the proxy to add metrics collection using Prometheus or similar tools.

## Security Features

- **Security Headers**: XSS protection, content type options, frame options
- **Request Size Limits**: 16MB maximum request size
- **Error Handling**: Proper error responses for various scenarios
- **Non-root User**: Docker container runs as non-root user

## Development

### Running in Development Mode

```bash
DEBUG=true python proxy.py
```

### Testing

```bash
# Test health endpoint
curl http://localhost:5050/health

# Test proxy functionality
curl http://localhost:5050/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

## Uninstallation

To completely remove the proxy from your system:

```bash
curl -sSL https://raw.githubusercontent.com/iarmawn/ApiProxy/main/uninstall.sh | sudo bash
```

Or download and run locally:
```bash
curl -sSL https://raw.githubusercontent.com/iarmawn/ApiProxy/main/uninstall.sh -o uninstall.sh
sudo bash uninstall.sh
```

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the `PORT` in `.env`
2. **Timeout errors**: Increase `REQUEST_TIMEOUT` in `.env`
3. **Service not starting**: Check logs with `sudo journalctl -u api-proxy -f`
4. **Python not found**: Install Python 3 and pip3
5. **Permission denied**: Run installer with sudo
6. **Multiple proxies**: Use different ports for each proxy instance

### Logs

Check application logs:
```bash
# Systemd service
sudo journalctl -u api-proxy -f

# Direct (development)
python proxy.py
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details. 