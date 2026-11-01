#!/bin/bash
# setup-proxmox.sh - Atur jaringan Proxmox untuk lab (host-only + NAT)
#
# Pemakaian (di console Proxmox, sebagai root):
#   bash setup-proxmox.sh <nomor_kelompok>
#
# Hasil:
#   vmbr0 = host-only  192.168.56.10X/24   (X = nomor kelompok) -> akses web UI
#   vmbr1 = NAT        192.168.221.10/24   gateway 192.168.221.2 -> internet
#
# NIC pertama (urutan alamat PCI) dianggap host-only, NIC kedua dianggap NAT.
# Jadi di VMware/VirtualBox: Adapter 1 = host-only, Adapter 2 = NAT.

set -e

printf '\033[36m\n'
cat <<'BANNER_A'
         ______  ____    ____    __  __  __          __  __  ______  ____    ______
 /'\_/`\/\  _  \/\  _`\ /\  _`\ /\ \/\ \/\ \        /\ \/\ \/\  _  \/\  _`\ /\__  _\
/\      \ \ \L\ \ \,\L\_\ \ \L\ \ \ \ \ \ \ \       \ \ \_\ \ \ \L\ \ \ \/\ \/_/\ \/
\ \ \__\ \ \  __ \/_\__ \\ \ ,  /\ \ \ \ \ \ \  __   \ \  _  \ \  __ \ \ \ \ \ \ \ \
 \ \ \_/\ \ \ \/\ \/\ \L\ \ \ \\ \\ \ \_\ \ \ \L\ \   \ \ \ \ \ \ \/\ \ \ \_\ \ \_\ \__
  \ \_\\ \_\ \_\ \_\ `\____\ \_\ \_\ \_____\ \____/    \ \_\ \_\ \_\ \_\ \____/ /\_____\
   \/_/ \/_/\/_/\/_/\/_____/\/_/\/ /\/_____/\/___/      \/_/\/_/\/_/\/_/\/___/  \/_____/
BANNER_A
printf '\033[35m\n'
cat <<'BANNER_B'
 __    __  _____   __  __  ____    ____    ____    ____    _____   _____   ______
/\ \  /\ \/\  __`\/\ \/\ \/\  _`\ /\  _`\ /\  _`\ /\  _`\ /\  __`\/\  __`\/\__  _\
\ `\`\\/'/\ \ \/\ \ \ \ \ \ \,\L\_\ \ \L\_\ \ \L\ \ \ \L\ \ \ \/\ \ \ \/\ \/_/\ \/
 `\ `\ /'  \ \ \ \ \ \ \ \ \/_\__ \\ \  _\L\ \ ,  /\ \ ,  /\ \ \ \ \ \ \ \ \ \ \ \
   `\ \ \   \ \ \_\ \ \ \_\ \/\ \L\ \ \ \L\ \ \ \\ \\ \ \\ \\ \ \_\ \ \ \_\ \ \ \ \
     \ \_\   \ \_____\ \_____\ `\____\ \____/\ \_\ \_\ \_\ \_\ \_____\ \_____\ \ \_\
      \/_/    \/_____/\/_____/\/_____/\/___/  \/_/\/ /\/_/\/ /\/_____/\/_____/  \/_/
BANNER_B
printf '\033[33m\n  Masrul Hadi | Youserroot\033[90m\n  Proxmox Lab Network Setup\033[0m\n\n'

[ "$(id -u)" -eq 0 ] || { echo "Jalankan sebagai root."; exit 1; }

G="${1:-}"
[ -n "$G" ] || read -rp "Nomor kelompok (1-99): " G
[[ "$G" =~ ^[0-9]+$ ]] && [ "$G" -ge 1 ] && [ "$G" -le 99 ] || { echo "Nomor kelompok harus 1-99."; exit 1; }

HOST_IP="192.168.56.$((100 + G))"
NAT_IP="192.168.221.10"
NAT_GW="192.168.221.2"

# --- deteksi NIC fisik, urut berdasarkan alamat PCI ---
mapfile -t NICS < <(
  for d in /sys/class/net/*; do
    n=$(basename "$d")
    [ -e "$d/device" ] || continue
    echo "$(basename "$(readlink -f "$d/device")") $n"
  done | sort | awk '{print $2}'
)

if [ "${#NICS[@]}" -lt 2 ]; then
  echo "Hanya ditemukan ${#NICS[@]} NIC fisik. Proxmox harus punya 2 adapter (host-only + NAT)."
  exit 1
fi

HOSTIF="${NICS[0]}"
NATIF="${NICS[1]}"

echo "Kelompok      : $G"
echo "Host-only     : $HOSTIF -> vmbr0 -> $HOST_IP/24"
echo "NAT           : $NATIF -> vmbr1 -> $NAT_IP/24 (gw $NAT_GW)"
read -rp "Lanjut? [y/N] " ok
[[ "$ok" =~ ^[Yy]$ ]] || { echo "Dibatalkan."; exit 0; }

# --- backup ---
TS=$(date +%Y%m%d-%H%M%S)
cp /etc/network/interfaces "/etc/network/interfaces.bak.$TS"
cp /etc/hosts "/etc/hosts.bak.$TS"

# --- /etc/network/interfaces ---
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

iface $HOSTIF inet manual
iface $NATIF inet manual

auto vmbr0
iface vmbr0 inet static
        address $HOST_IP/24
        bridge-ports $HOSTIF
        bridge-stp off
        bridge-fd 0

auto vmbr1
iface vmbr1 inet static
        address $NAT_IP/24
        gateway $NAT_GW
        bridge-ports $NATIF
        bridge-stp off
        bridge-fd 0

source /etc/network/interfaces.d/*
EOF

# --- /etc/hosts: hostname harus resolve ke IP baru, kalau tidak web UI Proxmox rusak ---
HN=$(hostname)
DOM=$(hostname -d 2>/dev/null || true)
FQDN="$HN"; [ -n "$DOM" ] && FQDN="$HN.$DOM"
sed -i "/^[0-9.]\+[[:space:]].*\b$HN\b/d" /etc/hosts
echo "$HOST_IP $FQDN $HN" >> /etc/hosts

# --- DNS ---
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf

# --- terapkan ---
echo "Menerapkan konfigurasi (koneksi SSH bisa putus, gunakan console)..."
ifreload -a
systemctl restart pveproxy pvedaemon pvestatd 2>/dev/null || true

# --- cek ---
echo; ip -br a | grep -E 'vmbr|lo'
echo; ip r
echo
ping -c2 -W2 "$NAT_GW"   >/dev/null && echo "[OK] gateway $NAT_GW"   || echo "[GAGAL] gateway $NAT_GW"
ping -c2 -W2 8.8.8.8     >/dev/null && echo "[OK] internet (8.8.8.8)" || echo "[GAGAL] internet"
ping -c2 -W2 google.com  >/dev/null && echo "[OK] DNS"               || echo "[GAGAL] DNS"
echo
echo "Buka dari Windows: https://$HOST_IP:8006"
echo "IP container/VM di vmbr1 pakai 192.168.221.11-99/24, gateway $NAT_GW"