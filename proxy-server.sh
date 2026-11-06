
#!/bin/bash
set -e

mkdir -p ./frp-server

TOKEN=$(openssl rand -hex 32)

# --- FRPS Docker Compose ---
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

# --- FRPS Configuration ---
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

# --- UFW ---
ufw allow 7000/tcp
ufw allow 25565/tcp
ufw allow 19132/tcp
ufw allow 19132/udp
ufw allow 19133/udp

# --- GLASS Firewall Bypass ---
cat > /usr/local/sbin/minecraft-glass-whitelist.sh <<'SCRIPT'
#!/bin/bash

for chain in GLASS_UPSTREAM GLASS_RT_30100; do
    iptables -w -nL "$chain" >/dev/null 2>&1 || continue

    # Allow Minecraft TCP ports before GLASS filtering rules
    iptables -w -C "$chain" -p tcp -m multiport \
        --dports 25565,19132 -j RETURN 2>/dev/null ||
        iptables -w -I "$chain" 1 -p tcp -m multiport \
        --dports 25565,19132 -j RETURN

    # Allow Minecraft UDP ports before GLASS filtering rules
    iptables -w -C "$chain" -p udp -m multiport \
        --dports 19132,19133 -j RETURN 2>/dev/null ||
        iptables -w -I "$chain" 1 -p udp -m multiport \
        --dports 19132,19133 -j RETURN
done
SCRIPT

chmod +x /usr/local/sbin/minecraft-glass-whitelist.sh

# --- Systemd Service ---
cat > /etc/systemd/system/minecraft-glass-whitelist.service <<'EOF'
[Unit]
Description=Keep Minecraft ports whitelisted in GLASS firewall

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/minecraft-glass-whitelist.sh
EOF

# --- Systemd Timer ---
cat > /etc/systemd/system/minecraft-glass-whitelist.timer <<'EOF'
[Unit]
Description=Periodically restore Minecraft GLASS firewall whitelist

[Timer]
OnBootSec=15s
OnUnitActiveSec=30s
AccuracySec=5s
Unit=minecraft-glass-whitelist.service

[Install]
WantedBy=timers.target
EOF

# Activate GLASS bypass
systemctl daemon-reload
systemctl enable --now minecraft-glass-whitelist.timer
systemctl start minecraft-glass-whitelist.service

echo "GLASS firewall bypass installed."

# --- Auto-install Docker Compose if missing ---
if ! docker compose &>/dev/null; then
    echo "Docker Compose not found. Attempting installation..."

    if apt-get install -y docker-compose-plugin 2>/dev/null; then
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

# --- Start FRPS ---
cd ./frp-server
docker compose up -d

echo
echo "========== FRPS TOKEN =========="
echo "$TOKEN"
echo "================================"
echo

docker compose ps
docker compose logs --tail=50 frps

echo
echo "========== GLASS RULES =========="
iptables -vnL GLASS_UPSTREAM --line-numbers 2>/dev/null || true
iptables -vnL GLASS_RT_30100 --line-numbers 2>/dev/null || true
echo "================================="
