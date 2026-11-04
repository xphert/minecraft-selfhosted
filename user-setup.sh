# Buat user khusus
useradd -m -s /bin/bash minecraft

# Buat direktori project
mkdir -p /data/opt/reality-mc/{frp,minecraft}

# Atur kepemilikan
chown -R minecraft:minecraft /data/opt/reality-mc

# Izinkan user menggunakan Docker
usermod -aG docker minecraft

# Verifikasi
id minecraft
su - minecraft
