mkdir -p ./frp-server

TOKEN=$(openssl rand -hex 32)

cat > ./frp-server/docker-compose.yml <<'EOF'
services:
  frps:
    image: snowdreamtech/frps:latest
    container_name: frps
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./frps.toml:/etc/frp/frps.toml:ro
    command: ["-c", "/etc/frp/frps.toml"]
EOF

cat > ./frp-server/frps.toml <<EOF
bindAddr = "0.0.0.0"
bindPort = 7000

auth.method = "token"
auth.token = "$TOKEN"

transport.tls.force = true

allowPorts = [
  { start = 25565, end = 25565 },
  { start = 19132, end = 19133 }
]
EOF

chmod 600 ./frp-server/frps.toml
ufw allow 7000/tcp
ufw allow 25565/tcp
ufw allow 19132/tcp
ufw allow 19132/udp
ufw allow 19133/udp
echo "TOKEN: $TOKEN"

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

cd ./frp-server && docker compose up -d   
docker compose ps
docker compose logs --tail=50 frps
