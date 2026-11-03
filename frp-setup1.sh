mkdir -p ./frp-server && cd ./frp-server

TOKEN=$(openssl rand -hex 32)

cat > docker-compose.yml <<'EOF'
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

cat > frps.toml <<EOF
bindAddr = "0.0.0.0"
bindPort = 7000

auth.method = "token"
auth.token = "$TOKEN"

transport.tls.force = true

allowPorts = [
  { start = 25565, end = 25565 },
  { start = 19132, end = 19132 }
]
EOF

chmod 600 frps.toml
docker compose up -d
