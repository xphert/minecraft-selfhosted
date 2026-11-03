set -euo pipefail

FRP_VERSION="0.65.0"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Arsitektur tidak didukung: $ARCH"; exit 1 ;;
esac

apt-get update
apt-get install -y curl tar

cd /tmp
curl -fL \
  "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz" \
  -o frp.tar.gz

tar -xzf frp.tar.gz
install -m 755 "frp_${FRP_VERSION}_linux_${ARCH}/frps" /usr/local/bin/frps

mkdir -p /etc/frp
TOKEN="$(openssl rand -hex 32)"

cat > /etc/frp/frps.toml <<CONFIG
bindAddr = "0.0.0.0"
bindPort = 7000

auth.method = "token"
auth.token = "${TOKEN}"

transport.tls.force = true

[[allowPorts]]
start = 25565
end = 25565

[[allowPorts]]
start = 19132
end = 19132
CONFIG

cat > /etc/systemd/system/frps.service <<'SERVICE'
[Unit]
Description=FRP Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICE

chmod 600 /etc/frp/frps.toml
systemctl daemon-reload
systemctl enable --now frps

if command -v ufw >/dev/null 2>&1; then
  ufw allow 7000/tcp
  ufw allow 25565/tcp
  ufw allow 19132/udp
fi

echo
echo "===== FRP SERVER READY ====="
echo "VPS IP: $(curl -4 -s https://api.ipify.org || true)"
echo "FRP TOKEN: $TOKEN"
echo "FRP CONTROL PORT: 7000"
echo "JAVA PORT: 25565/TCP"
echo "BEDROCK PORT: 19132/UDP"
echo
systemctl status frps --no-pager
