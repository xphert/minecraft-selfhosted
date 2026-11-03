# Buat user khusus
useradd -m -s /bin/bash minecraft

# Buat direktori project
mkdir -p /opt/reality-mc/{frp,minecraft}

# Atur kepemilikan
chown -R minecraft:minecraft /opt/reality-mc

# Izinkan user menggunakan Docker
usermod -aG docker minecraft

# Verifikasi
id minecraft
su - minecraft
