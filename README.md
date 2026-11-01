```text
         ______  ____    ____    __  __  __          __  __  ______  ____    ______
 /'\_/`\/\  _  \/\  _`\ /\  _`\ /\ \/\ \/\ \        /\ \/\ \/\  _  \/\  _`\ /\__  _\
/\      \ \ \L\ \ \,\L\_\ \ \L\ \ \ \ \ \ \ \       \ \ \_\ \ \ \L\ \ \ \/\ \/_/\ \/
\ \ \__\ \ \  __ \/_\__ \\ \ ,  /\ \ \ \ \ \ \  __   \ \  _  \ \  __ \ \ \ \ \ \ \ \
 \ \ \_/\ \ \ \/\ \/\ \L\ \ \ \\ \\ \ \_\ \ \ \L\ \   \ \ \ \ \ \ \/\ \ \ \_\ \ \_\ \__
  \ \_\\ \_\ \_\ \_\ `\____\ \_\ \_\ \_____\ \____/    \ \_\ \_\ \_\ \_\ \____/ /\_____\
   \/_/ \/_/\/_/\/_/\/_____/\/_/\/ /\/_____/\/___/      \/_/\/_/\/_/\/_/\/___/  \/_____/

 __    __  _____   __  __  ____    ____    ____    ____    _____   _____   ______
/\ \  /\ \/\  __`\/\ \/\ \/\  _`\ /\  _`\ /\  _`\ /\  _`\ /\  __`\/\  __`\/\__  _\
\ `\`\\/'/\ \ \/\ \ \ \ \ \ \,\L\_\ \ \L\_\ \ \L\ \ \ \L\ \ \ \/\ \ \ \/\ \/_/\ \/
 `\ `\ /'  \ \ \ \ \ \ \ \ \/_\__ \\ \  _\L\ \ ,  /\ \ ,  /\ \ \ \ \ \ \ \ \ \ \ \
   `\ \ \   \ \ \_\ \ \ \_\ \/\ \L\ \ \ \L\ \ \ \\ \\ \ \\ \\ \ \_\ \ \ \_\ \ \ \ \
     \ \_\   \ \_____\ \_____\ `\____\ \____/\ \_\ \_\ \_\ \_\ \_____\ \_____\ \ \_\
      \/_/    \/_____/\/_____/\/_____/\/___/  \/_/\/ /\/_/\/ /\/_____/\/_____/  \/_/
```

<p align="center"><b>Masrul Hadi | Youserroot</b></p>

# Proxmox Lab Network Setup

Seragamkan jaringan lab **Proxmox VE di VMware Workstation / VirtualBox** untuk satu kelas dengan satu klik.
Tidak perlu lagi mengoprek `Virtual Network Editor`, `/etc/network/interfaces`, atau bingung kenapa LXC tidak bisa ping ke internet.

Setiap kelompok mendapat IP web Proxmox sendiri:

```
https://192.168.56.10X:8006      (X = nomor kelompok, contoh kelompok 3 -> 192.168.56.103)
```

---

## Daftar isi

- [Topologi jaringan](#topologi-jaringan)
- [Isi repositori](#isi-repositori)
- [Prasyarat](#prasyarat)
- [Cara pakai](#cara-pakai)
- [Membuat container / VM di Proxmox](#membuat-container--vm-di-proxmox)
- [Troubleshooting](#troubleshooting)
- [Cara kerja](#cara-kerja)
- [Rollback](#rollback)
- [Status pengujian](#status-pengujian)
- [Catatan keamanan](#catatan-keamanan)

---

## Topologi jaringan

Semua kelompok memakai subnet yang sama di laptop masing-masing, kecuali IP Proxmox yang mengikuti nomor kelompok.

```
                          Laptop Windows
   ┌──────────────────────────────────────────────────────┐
   │  Host-only  192.168.56.1                             │
   │  NAT        192.168.221.1   (gateway NAT: .2)        │
   │      │                          │                    │
   │      │      ┌───────────────────┴───────┐            │
   │      │      │      VM Proxmox VE        │            │
   │      └──────┤ Adapter 1 -> vmbr0        │            │
   │             │   192.168.56.10X  (web UI)│            │
   │             │ Adapter 2 -> vmbr1        │            │
   │             │   192.168.221.10  (NAT)───┼─> Internet │
   │             │                           │            │
   │             │  LXC / VM: 192.168.221.11-99           │
   │             └───────────────────────────┘            │
   └──────────────────────────────────────────────────────┘
```

| Jaringan | Subnet | IP Windows | IP Proxmox | Fungsi |
|---|---|---|---|---|
| Host-only (`vmbr0`) | `192.168.56.0/24` | `192.168.56.1` | `192.168.56.10X` | Akses web UI & SSH dari Windows |
| NAT (`vmbr1`) | `192.168.221.0/24` | `192.168.221.1` | `192.168.221.10` | Jalur ke internet, gateway `192.168.221.2` |

Pembagian IP per kelompok:

| Kelompok | IP Web Proxmox |
|---|---|
| 1 | `192.168.56.101` |
| 2 | `192.168.56.102` |
| 3 | `192.168.56.103` |
| ... | ... |
| 99 | `192.168.56.199` |

---

## Isi repositori

| File | Dijalankan di | Fungsi |
|---|---|---|
| `run-lab.bat` | Windows | Launcher: minta hak Administrator lalu menjalankan `config-proxmox.ps1` |
| `config-proxmox.ps1` | Windows | Mengatur jaringan host-only dan NAT di VMware / VirtualBox, lalu mengirim `setup-proxmox.sh` ke Proxmox |
| `setup-proxmox.sh` | Proxmox (Linux) | Mengatur `vmbr0`, `vmbr1`, `/etc/hosts`, dan DNS sesuai nomor kelompok |

> Ketiga file harus berada di **satu folder yang sama**.

---

## Prasyarat

- Windows 10 / 11
- **VMware Workstation** atau **VirtualBox** sudah terpasang
- VM Proxmox VE sudah dibuat dengan **2 network adapter**:
  - **Adapter 1** = Host-only (di VMware: `VMnet1`)
  - **Adapter 2** = NAT (di VMware: `VMnet8`)
- Urutan adapter **penting**. Script menganggap adapter pertama adalah host-only dan adapter kedua adalah NAT.

---

## Cara pakai

### 1. Unduh dan siapkan

Unduh repositori ini (Code -> Download ZIP), ekstrak, dan pastikan tiga file ada dalam satu folder.

> Kalau Windows memblokir file, klik kanan file `.ps1` dan `.bat`, pilih **Properties**, lalu centang **Unblock**.

### 2. Matikan VM dan tutup VMware / VirtualBox

Perubahan jaringan virtual tidak bisa diterapkan dengan aman saat VM menyala. Untuk VirtualBox, VM Proxmox **harus** dalam keadaan *Power Off*.

### 3. Jalankan script Windows

Klik dua kali **`run-lab.bat`**, pilih **Yes** pada prompt UAC, lalu:

1. Masukkan **nomor kelompok** (1 sampai 99).
2. Kalau VMware dan VirtualBox sama-sama terpasang, pilih yang dipakai.
3. Untuk VirtualBox, pilih VM Proxmox dari daftar.
4. Pastikan hasil akhir menampilkan:
   ```
   [OK] VMnet1 = 192.168.56.1, VMnet8 = 192.168.221.1
   ```

### 4. Nyalakan VM Proxmox dan kirim script

Nyalakan VM Proxmox dan login di console sebagai `root`.

Kembali ke jendela PowerShell, jawab **`Y`** pada pertanyaan *"Kirim setup-proxmox.sh ke Proxmox lewat HTTP sekarang?"*. Script akan mencetak dua baris perintah. **Ketik keduanya di console Proxmox**, contoh untuk kelompok 3:

```bash
ip addr add 192.168.56.200/24 dev vmbr0
curl -sO http://192.168.56.1:8000/setup-proxmox.sh && bash setup-proxmox.sh 3
```

Jawab `y` pada pertanyaan konfirmasi.

> Kalau `curl` gagal (timeout / connection refused), `vmbr0` kemungkinan terpasang di adapter NAT. Pakai baris cadangan yang dicetak script (subnet `192.168.221.x`).

### 5. Buka web UI

Dari Windows, buka `https://192.168.56.10X:8006` (peringatan sertifikat di browser itu normal), login sebagai `root`.

Kembali ke PowerShell dan tekan **Ctrl+C** untuk menghentikan server HTTP sementara.

### 6. Cek hasil

Output `setup-proxmox.sh` harus menampilkan:

```
[OK] gateway 192.168.221.2
[OK] internet (8.8.8.8)
[OK] DNS
```

---

## Membuat container / VM di Proxmox

Semua LXC dan VM memakai bridge **`vmbr1`** (NAT) supaya punya internet.

| Field | Isi |
|---|---|
| Bridge | `vmbr1` |
| IPv4/CIDR | `192.168.221.11/24` sampai `192.168.221.99/24` |
| Gateway (IPv4) | `192.168.221.2` |
| DNS server | `8.8.8.8` |

Setiap container butuh IP yang berbeda. Jangan memakai `192.168.221.10` (itu IP Proxmox) dan jangan memakai rentang `192.168.221.128` ke atas (rentang DHCP bawaan VMware NAT).

Tes dari dalam container:

```bash
ping -c3 8.8.8.8      # tes koneksi
ping -c3 google.com   # tes DNS
```

---

## Troubleshooting

| Masalah | Penyebab & solusi |
|---|---|
| Jendela PowerShell langsung menutup | Jalankan lewat `run-lab.bat`, bukan klik kanan `.ps1`. Kalau perlu, buka PowerShell sebagai Administrator lalu: `powershell -ExecutionPolicy Bypass -File .\setup-lab.ps1` |
| `Missing type name after '['` dan error `||`, `&&` | File `.sh` dijalankan di PowerShell. `setup-proxmox.sh` hanya untuk Proxmox (Linux). Jangan ganti ekstensinya |
| "VMware / VirtualBox tidak ditemukan" | Script mencari lewat registry, PATH, dan semua drive. Kalau tetap gagal, masukkan path manual ke `vnetlib.exe` / `VBoxManage.exe` saat diminta |
| `[GAGAL] IP adapter VMnet belum sesuai` | Tutup VMware dan matikan VM, jalankan lagi. Kalau masih gagal, atur manual lewat Virtual Network Editor (lihat di bawah) |
| `curl` ke `192.168.56.1:8000` gagal | Coba subnet NAT (`192.168.221.x`). Pastikan script Windows masih berjalan (server HTTP aktif) dan Anda menjawab `Y` |
| `ifreload -a` sangat lama | Bridge lama masih dipakai container yang menyala. Tunggu 1-2 menit; kalau macet, `Ctrl+C` lalu `reboot`. Konfigurasi sudah tersimpan |
| LXC tidak mau start setelah setup | NIC container masih menunjuk bridge lama (mis. `vmbr2`). Ubah ke `vmbr1` di tab *Network* container |
| Web UI tidak bisa dibuka | Cek `ping 192.168.56.10X` dari Windows, dan pastikan `/etc/hosts` Proxmox berisi hostname dengan IP baru |
| Ping dari Windows gagal padahal IP benar | Set profil jaringan adapter VMnet ke **Private**, atau izinkan ICMP di Windows Firewall |
| `$'\r': command not found` | Line ending Windows (CRLF) pada `setup-proxmox.sh`. Pengiriman lewat HTTP sudah memperbaikinya; kalau menyalin manual: `sed -i 's/\r$//' setup-proxmox.sh` |

**Mengatur VMware secara manual** (kalau script gagal): buka `vmnetcfg.exe` (Virtual Network Editor) -> *Change Settings* ->
- `VMnet1` (Host-only): Subnet IP `192.168.56.0`, mask `255.255.255.0`, matikan DHCP.
- `VMnet8` (NAT): Subnet IP `192.168.221.0`, mask `255.255.255.0`; di *NAT Settings* pastikan Gateway `192.168.221.2`.

---

## Cara kerja

**`setup-lab.ps1` (Windows)**
- Mendeteksi VMware / VirtualBox lewat registry, PATH, dan pemindaian semua drive.
- **VMware**: memakai `vnetlib.exe` untuk mengatur subnet `VMnet1` dan `VMnet8`, lalu memverifikasi IP adapter yang sebenarnya.
- **VirtualBox**: memakai `VBoxManage` untuk membuat / mengatur host-only adapter dan memasang NIC1 (host-only) serta NIC2 (NAT `192.168.221.0/24`) ke VM yang dipilih.
- Menyajikan `setup-proxmox.sh` lewat server HTTP sementara (port 8000) dengan aturan firewall sementara yang dihapus otomatis.

**`setup-proxmox.sh` (Proxmox)**
- Mendeteksi NIC fisik dan mengurutkannya berdasarkan alamat PCI (pertama = host-only, kedua = NAT).
- Mem-backup `/etc/network/interfaces` dan `/etc/hosts`.
- Menulis konfigurasi `vmbr0` (host-only) dan `vmbr1` (NAT + gateway), memperbarui `/etc/hosts` agar hostname mengarah ke IP baru (wajib agar web UI Proxmox tetap berfungsi), dan mengatur DNS `8.8.8.8` / `1.1.1.1`.
- Menerapkan dengan `ifreload -a`, me-restart service web Proxmox, lalu mengetes gateway, internet, dan DNS.

---

## Rollback

Setiap kali dijalankan, `setup-proxmox.sh` menyimpan backup dengan stempel waktu. Untuk mengembalikan:

```bash
ls /etc/network/interfaces.bak.* /etc/hosts.bak.*
cp /etc/network/interfaces.bak.<STEMPEL> /etc/network/interfaces
cp /etc/hosts.bak.<STEMPEL> /etc/hosts
ifreload -a
```

Untuk jaringan virtual di Windows, buka Virtual Network Editor (VMware) lalu *Restore Defaults*, atau atur ulang host-only adapter di VirtualBox (*File -> Tools -> Network Manager*).

---

## Status pengujian

| Komponen | Status |
|---|---|
| VMware Workstation (versi baru, hanya ada `vnetlib.exe`) + `setup-proxmox.sh` | Teruji, jaringan, gateway, internet, dan DNS berfungsi |
| VMware Workstation versi lama (`vnetlib64.exe`) | Dukungan ada di script, belum teruji |
| VirtualBox | Dukungan ada di script, **belum teruji**. Laporan hasil dan perbaikan sangat disambut |
| Proxmox VE dengan container yang sudah berjalan | Teruji; proses `ifreload` bisa lambat dan container perlu dipindah ke `vmbr1` |

---

## Catatan keamanan

- Script **menimpa seluruh** `/etc/network/interfaces`. Konfigurasi jaringan kustom sebelumnya hilang (backup tetap tersimpan).
- Server HTTP sementara hanya aktif selama `setup-lab.ps1` berjalan dan hanya mendengarkan di IP VMnet (`192.168.56.1` dan `192.168.221.1`), jadi tidak terbuka ke WiFi atau internet.
- Script Windows memerlukan hak Administrator. Baca isi script terlebih dahulu sebelum menjalankannya; seluruh kodenya terbuka di repositori ini.
- Jangan memakai script ini di Proxmox produksi. Ini dibuat untuk lingkungan lab / belajar.

---

## Kontribusi

Issue dan pull request sangat disambut, terutama untuk:
- Pengujian di VirtualBox dan versi VMware lain
- Dukungan Hyper-V
- Penyempurnaan deteksi NIC

Pastikan file `.sh` disimpan dengan line ending **LF** (sudah diatur lewat `.gitattributes`).

## Pembuat

**Masrul Hadi | Youserroot**

## Lisensi

Tambahkan file `LICENSE` sesuai pilihan Anda (misalnya MIT).
