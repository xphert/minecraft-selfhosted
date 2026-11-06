
#!/bin/bash
set -euo pipefail

CONFIG="/etc/sysctl.d/99-minecraft-network.conf"

echo "======================================"
echo "   Minecraft Connection Optimizer"
echo "======================================"

# Require root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

echo "[1/4] Checking kernel BBR support..."

modprobe tcp_bbr 2>/dev/null || true

AVAILABLE=$(sysctl -n net.ipv4.tcp_available_congestion_control)

if ! grep -qw bbr <<< "$AVAILABLE"; then
    echo "ERROR: BBR is not supported by this kernel."
    echo "Available: $AVAILABLE"
    exit 1
fi

echo "BBR is available."

echo
echo "[2/4] Applying network optimization..."

cat > "$CONFIG" <<'EOF'
# Minecraft TCP Connection Optimization

# Fair Queue packet scheduling
net.core.default_qdisc = fq

# BBR congestion control
net.ipv4.tcp_congestion_control = bbr

# TCP Path MTU discovery/probing
net.ipv4.tcp_mtu_probing = 1

# Avoid restarting slow start after idle
net.ipv4.tcp_slow_start_after_idle = 0
EOF

echo
echo "[3/4] Applying sysctl configuration..."

sysctl --system >/dev/null

echo
echo "[4/4] Verification..."

echo
echo "--- Congestion Control ---"
sysctl net.ipv4.tcp_congestion_control

echo
echo "--- Default Qdisc ---"
sysctl net.core.default_qdisc

echo
echo "--- TCP MTU Probing ---"
sysctl net.ipv4.tcp_mtu_probing

echo
echo "--- Slow Start After Idle ---"
sysctl net.ipv4.tcp_slow_start_after_idle

echo
echo "======================================"
echo " Optimization completed successfully"
echo "======================================"
echo
echo "Config saved: $CONFIG"
echo
echo "IMPORTANT:"
echo "- Existing TCP connections retain their old congestion control."
echo "- Restart FRPS/FRPC during maintenance to apply BBR to new connections."
echo "- No MTU, firewall, or Minecraft timeout settings were changed."
