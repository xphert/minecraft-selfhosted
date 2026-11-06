
# --- Firewall Setup: UFW / iptables Fallback ---

echo
echo "========== FIREWALL SETUP =========="

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    echo "[FIREWALL] UFW is active. Using UFW."

    ufw allow 7000/tcp
    ufw allow 25565/tcp
    ufw allow 19132/tcp
    ufw allow 19132/udp
    ufw allow 19133/udp

else
    echo "[FIREWALL] UFW unavailable or inactive."
    echo "[FIREWALL] Falling back to iptables."

    IPTABLES_RULES=(
        "-p tcp --dport 7000 -j ACCEPT"
        "-p tcp --dport 25565 -j ACCEPT"
        "-p tcp --dport 19132 -j ACCEPT"
        "-p udp --dport 19132 -j ACCEPT"
        "-p udp --dport 19133 -j ACCEPT"
    )

    for rule in "${IPTABLES_RULES[@]}"; do
        # shellcheck disable=SC2086
        iptables -C INPUT $rule 2>/dev/null ||
        # shellcheck disable=SC2086
        iptables -I INPUT $rule
    done

    # Persistent iptables rules
    cat > /usr/local/sbin/frps-firewall-rules.sh <<'SCRIPT'
#!/bin/bash
set -e

RULES=(
    "-p tcp --dport 7000 -j ACCEPT"
    "-p tcp --dport 25565 -j ACCEPT"
    "-p tcp --dport 19132 -j ACCEPT"
    "-p udp --dport 19132 -j ACCEPT"
    "-p udp --dport 19133 -j ACCEPT"
)

for rule in "${RULES[@]}"; do
    # shellcheck disable=SC2086
    iptables -w -C INPUT $rule 2>/dev/null ||
    # shellcheck disable=SC2086
    iptables -w -I INPUT $rule
done
SCRIPT

    chmod +x /usr/local/sbin/frps-firewall-rules.sh

    cat > /etc/systemd/system/frps-firewall-rules.service <<'EOF'
[Unit]
Description=Restore FRPS iptables firewall rules

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/frps-firewall-rules.sh
EOF

    cat > /etc/systemd/system/frps-firewall-rules.timer <<'EOF'
[Unit]
Description=Periodically restore FRPS firewall rules

[Timer]
OnBootSec=15s
OnUnitActiveSec=30s
AccuracySec=5s
Unit=frps-firewall-rules.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now frps-firewall-rules.timer
    systemctl start frps-firewall-rules.service
fi

echo
echo "========== GLASS FIREWALL BYPASS =========="

cat > /usr/local/sbin/minecraft-glass-whitelist.sh <<'SCRIPT'
#!/bin/bash
set -e

for chain in GLASS_UPSTREAM GLASS_RT_30100; do
    iptables -w -nL "$chain" >/dev/null 2>&1 || continue

    iptables -w -C "$chain" -p tcp -m multiport \
        --dports 25565,19132 -j RETURN 2>/dev/null ||
        iptables -w -I "$chain" 1 -p tcp -m multiport \
        --dports 25565,19132 -j RETURN

    iptables -w -C "$chain" -p udp -m multiport \
        --dports 19132,19133 -j RETURN 2>/dev/null ||
        iptables -w -I "$chain" 1 -p udp -m multiport \
        --dports 19132,19133 -j RETURN
done
SCRIPT

chmod +x /usr/local/sbin/minecraft-glass-whitelist.sh

cat > /etc/systemd/system/minecraft-glass-whitelist.service <<'EOF'
[Unit]
Description=Keep Minecraft ports whitelisted in GLASS firewall

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/minecraft-glass-whitelist.sh
EOF

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

systemctl daemon-reload
systemctl enable --now minecraft-glass-whitelist.timer
systemctl start minecraft-glass-whitelist.service

echo "[FIREWALL] Configuration completed."
