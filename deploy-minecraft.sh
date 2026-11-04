mkdir -p /data/opt/reality-mc/minecraft
cd /data/opt/reality-mc/minecraft

cat > /data/opt/reality-mc/minecraft/docker-compose.yml <<EOF

services:
  minecraft:
    image: itzg/minecraft-server:java25
    container_name: reality-minecraft
    restart: unless-stopped

    ports:
      - "25565:25565/tcp"
      - "19132:19132/udp"

    environment:
      EULA: "TRUE"
      TYPE: "PAPER"
      VERSION: "LATEST"

      MEMORY: "5G"
      TZ: "Asia/Jakarta"

      ONLINE_MODE: "TRUE"
      SERVER_PORT: "25565"

      MOTD: "RealityMC - Minecraft Server"
      DIFFICULTY: "normal"
      MAX_PLAYERS: "30"

      VIEW_DISTANCE: "8"
      SIMULATION_DISTANCE: "6"

      ENABLE_RCON: "FALSE"

      PLUGINS: >-
        https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot,
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot

    volumes:
      - ./data:/data

    mem_limit: 6g
    cpus: 3.0
EOF

docker compose up -d
docker compose logs -f minecraft
echo "run after server showing Done!: docker exec reality-minecraft ls /data/plugins"
echo "run after server showing Done!: docker port reality-minecraft"
