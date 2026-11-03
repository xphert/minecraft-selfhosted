cd /opt/reality-mc/frp

# --- Auto-install Docker Compose if missing ---
if ! docker compose &>/dev/null; then
    echo "Docker Compose not found. Attempting installation..."

    if sudo apt-get install -y docker-compose-plugin 2>/dev/null; then
        echo "Installed via apt-get."
    else
        echo "apt-get failed. Installing manually..."
        DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
        mkdir -p "$DOCKER_CONFIG/cli-plugins"
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
            -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
        chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
    fi

    if ! docker compose &>/dev/null; then
        echo "ERROR: Failed to install Docker Compose." >&2
        exit 1
    fi
fi
# --- End auto-install ---

# --- User Input ---
read -rp "Enter VPS IP address: " VPS_IP
read -rp "Enter FRP token: " TOKEN

if [ -z "$VPS_IP" ] || [ -z "$TOKEN" ]; then
    echo "ERROR: VPS_IP and TOKEN cannot be empty." >&2
    exit 1
fi
# --- End User Input ---

cat > docker-compose.yml <<'EOF'
services:
  frpc:
    image: snowdreamtech/frpc:latest
    container_name: frpc
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./frpc.toml:/etc/frp/frpc.toml:ro
    command: ["-c", "/etc/frp/frpc.toml"]
EOF

cat > frpc.toml <<EOF
serverAddr = "$VPS_IP"
serverPort = 7000

auth.method = "token"
auth.token = "$TOKEN"

transport.tls.enable = true

[[proxies]]
name = "minecraft-java"
type = "tcp"
localIP = "127.0.0.1"
localPort = 25565
remotePort = 25565

[[proxies]]
name = "minecraft-bedrock"
type = "tcp"
localIP = "127.0.0.1"
localPort = 19132
remotePort = 19132

[[proxies]]
name = "minecraft-bedrock"
type = "udp"
localIP = "127.0.0.1"
localPort = 19132
remotePort = 19132

[[proxies]]
name = "minecraft-bedrock"
type = "tcp"
localIP = "127.0.0.1"
localPort = 19133
remotePort = 19133

[[proxies]]
name = "minecraft-bedrock"
type = "udp"
localIP = "127.0.0.1"
localPort = 19133
remotePort = 19133
EOF

chmod 600 frpc.toml
docker compose up -d   
