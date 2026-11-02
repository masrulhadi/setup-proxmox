
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

**v1.2.0**

Seragamkan jaringan lab **Proxmox VE di VMware Workstation / VirtualBox** untuk satu kelas dengan satu klik.
Tidak perlu lagi mengoprek `Virtual Network Editor`, `/etc/network/interfaces`, atau bingung kenapa LXC tidak bisa ping ke internet.

Setiap kelompok mendapat IP web Proxmox sendiri:

```
https://192.168.56.10X:8006      (X = nomor kelompok, contoh kelompok 3 -> 192.168.56.103)
```

---

## Daftar isi

- [Panduan lengkap (mulai dari sini)](#panduan-lengkap-mulai-dari-sini)
- [Topologi jaringan](#topologi-jaringan)
- [Isi repositori](#isi-repositori)
- [Prasyarat](#prasyarat)
- [Cara pakai (ringkas)](#cara-pakai-ringkas)
- [**Menjalankan script di Windows — Panduan Lengkap**](#menjalankan-script-di-windows--panduan-lengkap)
- [Membuat container / VM di Proxmox](#membuat-container--vm-di-proxmox)
- [Troubleshooting](#troubleshooting)
- [Cara kerja](#cara-kerja)
- [Rollback](#rollback)
- [Status pengujian](#status-pengujian)
- [Catatan keamanan](#catatan-keamanan)
- [Kontribusi](#kontribusi)

---

## Panduan lengkap (mulai dari sini)

📖 **`PANDUAN_SETUP.md`** berisi langkah lengkap dari nol: pilih hypervisor, buat VM, install Proxmox, setup jaringan, sampai checklist pengumpulan tugas.

**Baca itu dulu** sebelum menyentuh script. README ini hanya menjelaskan **apa itu** dan **cara kerja** tool-nya, plus **cara menjalankan script di Windows** kalau kamu bingung kenapa file tidak bisa di-double-click.

---

## Topologi jaringan

```
+--------------------------------------------------------------------+
|                       Laptop Windows (host)                        |
|                                                                    |
|   Host-only  192.168.56.1      NAT  192.168.221.1                  |
|      |                              |                              |
|      |     +------------------------+--------+                     |
|      |     |       VM Proxmox VE            |                     |
|      +-----+ Adapter 1 -> vmbr0              |                     |
|            |  192.168.56.10X  (web UI)       |                     |
|            | Adapter 2 -> vmbr1              |                     |
|            |  192.168.221.10  (NAT) ---------+--> Internet         |
|            |                                 |                     |
|            |  LXC / VM: 192.168.221.11-99    |                     |
|            +---------------------------------+                     |
+--------------------------------------------------------------------+
```

| Jaringan | Subnet | IP Windows | IP Proxmox | Fungsi |
|---|---|---|---|---|
| Host-only (`vmbr0`) | `192.168.56.0/24` | `192.168.56.1` | `192.168.56.10X` | Akses web UI & SSH dari Windows |
| NAT (`vmbr1`) | `192.168.221.0/24` | `192.168.221.1` | `192.168.221.10` | Jalur ke internet, gateway `192.168.221.2`* |

\* Gateway NAT default `.2` (VMware). VirtualBox default `.1` — script `setup-proxmox.sh` v1.1.0 **auto-detect** gateway yang benar.

| Kelompok | IP Web Proxmox | Hostname |
|---|---|---|
| 1 | `192.168.56.101` | `pve-kel01.lab.local` |
| 2 | `192.168.56.102` | `pve-kel02.lab.local` |
| 3 | `192.168.56.103` | `pve-kel03.lab.local` |
| ... | ... | ... |
| 99 | `192.168.56.199` | `pve-kel99.lab.local` |

---

## Isi repositori

| File | Dijalankan di | Cara menjalankan | Fungsi |
|---|---|---|---|
| **`PANDUAN_SETUP.md`** | — | Baca saja | **Panduan lengkap** dari nol sampai selesai |
| **`run-lab.bat`** | Windows | **Double-click** | Launcher: minta Administrator, lalu jalankan `config-proxmox.ps1` |
| **`config-proxmox.ps1`** | Windows | **Jangan double-click** — jalankan lewat `run-lab.bat` | Setup jaringan host-only + NAT di VMware/VirtualBox, kirim `setup-proxmox.sh` via HTTP |
| **`setup-proxmox.sh`** | Proxmox (Linux) | `bash setup-proxmox.sh <nomor>` (dikirim via HTTP oleh PS1) | Setup `vmbr0`, `vmbr1`, `/etc/hosts`, DNS |
| **`modified-registry.bat`** | Windows | **Klik kanan → Run as administrator** | **[Hanya untuk VMware]** Matikan Hyper-V/VBS/HVCI supaya nested virtualization jalan. **Tidak perlu** untuk VirtualBox |
| `.gitattributes` | — | — | Enforce line ending LF untuk `.sh`, CRLF untuk `.bat`/`.ps1` |

> ⚠️ File `.ps1`, `.sh`, `.bat` harus berada di **satu folder yang sama**.

---

## Prasyarat

### Wajib

- Windows 10 / 11 (64-bit)
- **VMware Workstation** atau **VirtualBox** sudah terpasang
- Hak **Administrator** di laptop
- Intel VT-x atau AMD-V aktif di BIOS/UEFI
- VM Proxmox VE sudah dibuat dengan **2 network adapter**:
  - **Adapter 1** = Host-only
  - **Adapter 2** = NAT

### Khusus VMware (rekomendasi kuat)

- **`modified-registry.bat` sudah dijalankan** dan restart laptop
- **BitLocker recovery key sudah tersimpan** (kalau BitLocker aktif)
  - Backup: `manage-bde -protectors -get C:`

### Khusus VirtualBox

- **Tidak perlu** `modified-registry.bat`
- Cukup centang **"Enable Nested VT-x/AMD-V"** di Settings VM (sudah diotomatiskan oleh `config-proxmox.ps1`)

---

## Cara pakai (ringkas)

> Detail langkah menjalankan script di Windows → lihat [section khusus di bawah](#menjalankan-script-di-windows--panduan-lengkap).

1. **Ekstrak ZIP** → semua file di satu folder.
2. **Unblock file** kalau hasil unduhan:
   ```powershell
   Get-ChildItem | Unblock-File
   ```
3. **Matikan VM Proxmox** dan **tutup VMware/VirtualBox**.
4. **Klik kanan `run-lab.bat`** → **Run as administrator**.
5. Ikuti dialog:
   - Konfirmasi hostname → **`Y`**
   - Nomor kelompok (1-99)
   - Hypervisor (kalau terdeteksi keduanya)
   - Pilih VM Proxmox (khusus VirtualBox)
6. **Nyalakan VM Proxmox**, login sebagai `root`.
7. Di jendela PowerShell yang masih berjalan, jawab **`Y`** untuk kirim `setup-proxmox.sh` via HTTP.
8. **Ketik dua baris perintah** yang dicetak di console Proxmox (contoh kelompok 7):
   ```bash
   ip addr add 192.168.56.200/24 dev vmbr0 2>/dev/null || true
   curl -sO http://192.168.56.1:8000/setup-proxmox.sh && bash setup-proxmox.sh 7
   ```
9. Ikuti wizard `setup-proxmox.sh` (hostname check → NIC mapping → diff → apply).
10. **Ctrl+C** di PowerShell untuk stop server HTTP.
11. Buka `https://192.168.56.107:8006` (kelompok 7).
12. Setelah selesai tugas: jalankan `modified-registry.bat` → **[3] Mode Normal** → restart.

---

## Menjalankan script di Windows — Panduan Lengkap

> **Bagian ini khusus.** Kalau kamu bingung **kenapa script tidak bisa di-double-click**, **kenapa jendela nutup sekejap**, atau **kenapa PowerShell bilang "running scripts is disabled"** — **baca ini sampai habis**.

### Ringkasan cara menjalankan

| File | Cara terbaik | Cara alternatif |
|---|---|---|
| `run-lab.bat` | **Double-click** | PowerShell (admin): `.\run-lab.bat` |
| `modified-registry.bat` | **Klik kanan → Run as administrator** | PowerShell (admin): `.\modified-registry.bat` |
| `config-proxmox.ps1` | **Jalankan lewat `run-lab.bat`** | PowerShell (admin) dengan `-ExecutionPolicy Bypass` |

### 🚫 JANGAN double-click `config-proxmox.ps1`

Windows **secara default tidak menjalankan** `.ps1` saat di-double-click — demi keamanan (supaya script berbahaya dari internet tidak jalan sendiri). Kalau kamu double-click `.ps1`:

- **Windows akan membukanya di Notepad** (atau editor lain)
- Atau muncul dialog "How do you want to open this file?"
- **Bukan** menjalankannya

**Solusi:** selalu jalankan lewat **`run-lab.bat`** (yang sudah menangani bypass dan elevasi UAC).

---

### Cara 1 — Double-click `run-lab.bat` (direkomendasikan)

**Untuk siapa:** semua orang, khususnya yang tidak familiar PowerShell.

1. Pastikan **VMware Workstation / VirtualBox tertutup** dan **VM Proxmox dalam keadaan mati**.
2. **Klik dua kali** `run-lab.bat`.
3. Muncul prompt UAC "Do you want to allow this app to make changes?" → klik **Yes**.
4. Jendela Command Prompt terbuka dengan banner Proxmox Lab Network Setup.
5. Ikuti dialog interaktif (hostname → nomor kelompok → hypervisor → dst).
6. **Jangan tutup jendela** sampai muncul pesan "Tekan tombol apa saja untuk menutup".
7. Setelah semua selesai, tekan **Ctrl+C** di jendela PowerShell yang dijalankan oleh script untuk stop server HTTP — atau tunggu **auto-stop 30 menit idle**.

**Kenapa ini cara terbaik:**
- Otomatis bypass ExecutionPolicy
- Otomatis minta elevasi UAC
- Otomatis `cd` ke folder script (tidak perlu hafal path)
- Error tetap terlihat (`pause` di akhir)

---

### Cara 2 — PowerShell sebagai Administrator (manual)

**Untuk siapa:** kalau double-click gagal, atau kamu ingin melihat error lengkap.

1. **Klik kanan Start** → pilih **Terminal (Admin)** atau **PowerShell (Admin)**.
   - Windows 10: **Windows PowerShell (Admin)**
   - Windows 11: **Terminal (Admin)** lalu tab **PowerShell**
2. Klik **Yes** pada UAC.
3. **Pindah ke folder script:**
   ```powershell
   cd "C:\path\ke\folder\proxmox-lab-toolkit"
   ```
   > Bungkus path dengan **tanda kutip** kalau ada spasi (mis. `C:\My Folder\...`).
4. **Cek file sudah ada:**
   ```powershell
   Get-ChildItem
   ```
   Harus muncul minimal: `run-lab.bat`, `config-proxmox.ps1`, `setup-proxmox.sh`.
5. **Izinkan eksekusi script (per-sesi):**
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
   > Ini **hanya** berlaku untuk jendela PowerShell yang aktif — tidak mengubah setting global Windows. Aman.
6. **Jalankan launcher:**
   ```powershell
   .\run-lab.bat
   ```
   atau langsung ke script-nya (kalau `run-lab.bat` tidak ada / bermasalah):
   ```powershell
   .\config-proxmox.ps1
   ```
7. Ikuti dialog seperti di Cara 1.

---

### Cara 3 — Command Prompt (CMD) sebagai Administrator

**Untuk siapa:** kalau PowerShell tidak tersedia atau bermasalah.

1. **Klik kanan Start** → pilih **Command Prompt (Admin)** atau **Terminal (Admin)** → tab **Command Prompt**.
2. Klik **Yes** pada UAC.
3. **Pindah ke folder script:**
   ```cmd
   cd /d "C:\path\ke\folder\proxmox-lab-toolkit"
   ```
   > Flag `/d` penting kalau kamu pindah dari drive lain.
4. **Jalankan PowerShell dengan bypass:**
   ```cmd
   powershell -ExecutionPolicy Bypass -File .\config-proxmox.ps1
   ```
5. Ikuti dialog seperti di Cara 1.

---

### Cara 4 — Non-interaktif (untuk testing / automation)

**Untuk siapa:** kamu yang sudah tahu nomor kelompok dan mau skip prompt.

```powershell
.\config-proxmox.ps1 -Group 7
```

Ini akan:
- ✅ Skip prompt "Nomor kelompok"
- ⚠️ **Tetap** konfirmasi hostname (demi keamanan)
- ⚠️ **Tetap** tanya hypervisor kalau keduanya terdeteksi
- ⚠️ **Tetap** konfirmasi kirim file via HTTP

Untuk skip **semua** konfirmasi (hanya untuk testing otomatis):

```powershell
'Y','Y','Y','Y' | .\config-proxmox.ps1 -Group 7
```

> ⚠️ **Jangan pakai cara ini** di laptop yang benar-benar akan dijadikan lab — selalu verifikasi manual minimal sekali (terutama konfirmasi hostname).

---

### 🎯 Cek cepat: apakah saya siap menjalankan?

Jalankan langkah ini dulu kalau kamu tidak yakin:

**Langkah 1 — Cek folder dan file**

Buka PowerShell (biasa saja, belum perlu admin):

```powershell
cd "C:\path\ke\folder\proxmox-lab-toolkit"
Get-ChildItem
```

Harus muncul:
```
    Directory: C:\path\ke\folder\proxmox-lab-toolkit

Mode    LastWriteTime    Length  Name
----    -------------    ------  ----
-a---   ...              12345   config-proxmox.ps1
-a---   ...              4567    setup-proxmox.sh
-a---   ...              1234    run-lab.bat
...
```

Kalau ada yang hilang → ekstrak ZIP ulang atau download ulang.

**Langkah 2 — Cek ExecutionPolicy**

```powershell
Get-ExecutionPolicy -List
```

Kalau `CurrentUser` atau `LocalMachine` = **`Restricted`** atau **`AllSigned`**:

- **Tidak masalah** kalau kamu pakai `run-lab.bat` (sudah pakai `-ExecutionPolicy Bypass` internal)
- Kalau mau jalankan `.ps1` **manual**, pakai: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` dulu

**Langkah 3 — Cek hak administrator**

```powershell
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
```

- `True` → kamu sudah admin, siap
- `False` → buka PowerShell baru dengan **Run as administrator**

Kalau ketiga langkah lolos → **klik kanan `run-lab.bat` → Run as administrator**. Selesai.

---

### 📥 Kalau file diunduh lewat ZIP (WAJIB dibaca)

Windows 10/11 menandai file hasil ekstrak dari **ZIP yang diunduh dari internet** sebagai "blocked". Ini bisa mencegah script jalan, atau memunculkan SmartScreen "Windows protected your PC".

**Fix sekali jalan** — buka PowerShell, `cd` ke folder script, lalu:

```powershell
Get-ChildItem -Recurse | Unblock-File
```

Ini akan menghapus tanda "blocked" dari **semua** file di folder (termasuk subfolder).

**Alternatif manual per file:**

1. Klik kanan file (`.ps1`, `.bat`, `.sh`)
2. Pilih **Properties**
3. Di bagian bawah, centang ☑️ **Unblock**
4. Klik **OK**

Ulangi untuk setiap file `.ps1` / `.bat` / `.sh`.

---

### 🚨 Tabel masalah umum saat menjalankan di Windows

| Gejala | Penyebab | Solusi |
|---|---|---|
| **`.ps1` terbuka di Notepad** saat di-double-click | Windows by design tidak menjalankan `.ps1` dengan double-click | **Jangan double-click**. Jalankan lewat `run-lab.bat` atau `powershell -File .\config-proxmox.ps1` |
| **"running scripts is disabled on this system"** | ExecutionPolicy default `Restricted` | (a) Pakai `run-lab.bat` (sudah bypass). (b) Atau: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
| **`run-lab.bat` nutup dalam sekejap** | Script crash sebelum sempat `pause`, atau UAC dibatalkan | (a) Buka CMD, jalankan `run-lab.bat` untuk lihat error. (b) Jalankan via PowerShell manual (Cara 2) |
| **"The term '.\config-proxmox.ps1' is not recognized"** | Salah folder / typo | `cd` ke folder yang benar dulu, cek dengan `Get-ChildItem` |
| **"cannot be loaded because ... not digitally signed"** | Windows SmartScreen / AllSigned policy | Pakai `run-lab.bat`, atau `Unblock-File .\config-proxmox.ps1` |
| **"Access is denied"** | Tidak ada hak Administrator | Klik kanan → **Run as administrator** |
| **"No such file or directory"** | Path dengan spasi tanpa tanda kutip | Bungkus dengan kutip: `cd "C:\My Folder\..."` |
| **"Windows protected your PC"** (SmartScreen) | File hasil unduhan dari internet | Klik **More info** → **Run anyway**. Atau: `Unblock-File .\run-lab.bat` |
| **UAC muncul untuk `powershell.exe`, bukan `run-lab.bat`** | Normal — script memanggil `Start-Process -Verb RunAs` | Klik **Yes**. Ini perilaku yang benar |
| **Semua file "blocked" setelah ekstrak ZIP** | Windows menandai file dari internet | `Get-ChildItem \| Unblock-File` (sekali jalan untuk semua) |
| **"cannot find path" di OneDrive** | OneDrive on-demand mengganggu path | Pindah folder ke `C:\Lab\` (non-OneDrive) |
| **`powershell` tidak dikenali** | PowerShell tidak ada di PATH (sangat jarang di Windows 10/11) | Gunakan `pwsh` (PowerShell 7) atau `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |

---

## Membuat container / VM di Proxmox

Semua LXC dan VM memakai bridge **`vmbr1`** (NAT) supaya punya internet.

| Field | Isi |
|---|---|
| Bridge | `vmbr1` |
| IPv4/CIDR | `192.168.221.11/24` sampai `192.168.221.99/24` |
| Gateway (IPv4) | `192.168.221.2` (VMware) atau `192.168.221.1` (VirtualBox — cek dengan `ping` dulu) |
| DNS server | `8.8.8.8` |

Setiap container butuh IP yang berbeda. Jangan memakai `192.168.221.10` (IP Proxmox) dan jangan memakai rentang `192.168.221.128` ke atas (rentang DHCP bawaan VMware NAT).

---

## Troubleshooting

| Masalah | Penyebab & solusi |
|---|---|
| **`.ps1` terbuka di Notepad** | By design Windows. Lihat [Panduan Menjalankan Script](#menjalankan-script-di-windows--panduan-lengkap) |
| **"running scripts is disabled"** | Pakai `run-lab.bat`, atau `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
| **File terunduh ZIP semua "blocked"** | `Get-ChildItem -Recurse \| Unblock-File` di folder script |
| **`run-lab.bat` langsung menutup** | Jalankan dari CMD (`run-lab.bat`) atau PowerShell (admin) manual |
| **"The term '.\config-proxmox.ps1' is not recognized"** | Salah folder. `cd` ke folder script dulu |
| `Missing type name after '['` dan error `\|\|`, `&&` | File `.sh` dijalankan di PowerShell. `setup-proxmox.sh` hanya untuk Proxmox (Linux) |
| "VMware / VirtualBox tidak ditemukan" | Script mencari lewat registry, PATH, dan semua drive. Kalau gagal, masukkan path manual saat diminta |
| `[GAGAL] IP adapter VMnet belum sesuai` | Tutup VMware, matikan VM, jalankan lagi. Log: `vmware-vnetlib.log` |
| **Port 8000 sudah terpakai** | Script v1.1.0 **auto pindah** ke port lain. Baca baris `curl` yang dicetak |
| `curl` ke `192.168.56.1:8000` gagal | Coba subnet NAT (`192.168.221.x`). Cek port yang dicetak. Pastikan jendela PowerShell masih jalan |
| **`internet (8.8.8.8)` gagal — VirtualBox** | Gateway default `.1` vs `.2`. Script v1.1.0 auto-detect. Manual: `bash setup-proxmox.sh 7 --gw 192.168.221.1` |
| **`internet (8.8.8.8)` gagal — VMware** | Cek `vmnetnat.conf`: `ip = 192.168.221.2`. Atur di Virtual Network Editor |
| **Hostname salah** (`pve` bukan `pve-kelNN`) | `hostnamectl set-hostname pve-kelNN` lalu ulangi `.sh`. **Lebih aman: reinstall Proxmox** |
| VBS / Credential Guard masih nyala setelah Mode Lab | Jalankan `modified-registry.bat` lagi, jawab `Y` di pertanyaan UEFI unlock |
| **BitLocker recovery prompt** saat boot | Masukkan recovery key (`manage-bde -protectors -get C:`). Setelah masuk, restore Mode Normal |
| `ifreload -a` sangat lama | Script v1.1.0 sudah **peringatkan** sebelum lanjut. Kalau macet: Ctrl+C → `reboot` |
| LXC tidak mau start | NIC container masih menunjuk bridge lama (mis. `vmbr2`). Ubah ke `vmbr1` di tab *Network* |
| Web UI tidak bisa dibuka | `ping 192.168.56.10X` dari Windows. Cek `/etc/hosts` Proxmox |
| Ping dari Windows gagal padahal IP benar | Set adapter VMnet ke **Private**, atau izinkan ICMP di Windows Firewall |
| `$'\r': command not found` | Line ending CRLF. Pengiriman via HTTP sudah perbaiki. Manual: `sed -i 's/\r$//' setup-proxmox.sh` |
| **NIC adapter terbalik** (NAT di Adapter 1) | Script v1.1.0 menampilkan MAC + PCI dan opsi **swap** (`s`). Atau tukar di Settings VM |

**Mengatur VMware secara manual** (kalau script gagal): buka `vmnetcfg.exe` → *Change Settings* →
- `VMnet1` (Host-only): Subnet IP `192.168.56.0`, mask `255.255.255.0`, matikan DHCP.
- `VMnet8` (NAT): Subnet IP `192.168.221.0`, mask `255.255.255.0`; *NAT Settings* → Gateway `192.168.221.2`.

**Mengatur VirtualBox secara manual** (kalau script gagal): *File → Tools → Network Manager* →
- *Host-only Networks*: buat/pilih `vboxnet0`, IP `192.168.56.1`, mask `255.255.255.0`.
- Settings VM → Network: Adapter 1 = *Host-only Adapter* → `vboxnet0`, Adapter 2 = *NAT*.

---

## Cara kerja

### `config-proxmox.ps1` v1.1.0 (Windows)

- **Konfirmasi hostname** sebelum setup
- **Deteksi hypervisor** lewat registry, PATH, dan pemindaian semua drive
- **VMware**: `vnetlib.exe` set subnet VMnet1/VMnet8, verifikasi polling (5×500ms), log di `vmware-vnetlib.log`
- **VirtualBox**: `VBoxManage` buat/atur host-only adapter + NIC1/NIC2, aktifkan `--nested-hw-virt`, warning gateway `.1`
- **HTTP server sementara**: port auto-detect, bind hanya ke IP yang ada, firewall rule cleanup, request counter, auto-stop 30 menit idle
- **Parameter `-Group`** untuk non-interaktif

### `setup-proxmox.sh` v1.1.0 (Proxmox)

- Deteksi bukan-Proxmox → batal
- Verifikasi hostname → warning kalau salah
- Deteksi NIC fisik (PCI sort), cek `operstate`, dialog NIC dengan **swap**
- Cek CT/VM running → warning sebelum `ifreload`
- Backup `/etc/network/interfaces`, `/etc/hosts`, `/etc/resolv.conf` (timestamp)
- Tulis `vmbr0` (host-only) + `vmbr1` (NAT + gateway)
- Update `/etc/hosts` (hostname → IP baru) + `/etc/resolv.conf` (handling symlink)
- Tampilkan **diff LAMA vs BARU** (screenshot-friendly)
- Apply + restart service satu per satu
- Test gateway/internet/DNS **dengan retry 3×**
- **Auto-detect gateway `.1` ↔ `.2`** kalau internet gagal
- Ringkasan status akhir terstruktur
- Log di `/var/log/lab-setup.log`

### Opsi `setup-proxmox.sh`

```
Usage: bash setup-proxmox.sh <nomor_kelompok> [gateway] [opsi]

Arguments:
  nomor_kelompok   Nomor kelompok (1-99), wajib
  gateway          IP gateway NAT (opsional, default 192.168.221.2)

Options:
  --gw <IP>        Sama dengan argumen gateway
  -y, --yes        Skip konfirmasi interaktif
  -h, --help       Tampilkan bantuan

Examples:
  bash setup-proxmox.sh 7
  bash setup-proxmox.sh 7 192.168.221.1
  bash setup-proxmox.sh 7 --gw 192.168.221.1 --yes
```

---

## Rollback

Backup otomatis setiap kali `setup-proxmox.sh` dijalankan:

```
/etc/network/interfaces.bak.YYYYMMDD-HHMMSS
/etc/hosts.bak.YYYYMMDD-HHMMSS
/etc/resolv.conf.bak.YYYYMMDD-HHMMSS
```

Restore:
```bash
cp /etc/network/interfaces.bak.<STEMPEL> /etc/network/interfaces
cp /etc/hosts.bak.<STEMPEL> /etc/hosts
ifreload -a
```

Windows virtual network:
- **VMware**: Virtual Network Editor → *Restore Defaults*
- **VirtualBox**: *File → Tools → Network Manager* → hapus/edit host-only adapter
- **Setelah `modified-registry.bat`**: jalankan lagi → **[3] Mode Normal** → restart

---

## Status pengujian

| Komponen | Status | Mitigasi v1.1.0 |
|---|---|---|
| VMware Workstation (baru) + `setup-proxmox.sh` | ✅ Teruji | Polling verifikasi, log file |
| VMware Workstation versi lama (`vnetlib64.exe`) | ⚠️ Dukungan ada, belum teruji | Fallback otomatis |
| VirtualBox (host-only + NAT) | ⚠️ Belum teruji penuh | `--nested-hw-virt` otomatis, **auto-detect gateway `.1`↔`.2`**, warning di PS1 |
| Proxmox VE dengan container running | ✅ Teruji; `ifreload` bisa lambat | Warning + opsi batal |
| Windows Home / Pro / Enterprise | ⚠️ Belum diuji menyeluruh | Skip fitur `NotFound` |

**Laporan hasil uji VirtualBox sangat disambut** — buka issue atau PR.

---

## Catatan keamanan

### `config-proxmox.ps1`
- **Menimpa** `/etc/network/interfaces` (backup tetap tersimpan)
- HTTP server **hanya bind ke IP VMnet** (tidak terbuka ke WiFi)
- Firewall rule sementara **dihapus otomatis**
- Server **auto-stop** 30 menit idle

### `modified-registry.bat`
- **Menurunkan keamanan** (VBS, HVCI, Credential Guard mati)
- **Risiko BitLocker recovery** — backup key dulu
- **Fitur mati selama Mode Lab**: WSL2, Docker Desktop, Windows Sandbox, emulator Hyper-V, beberapa anti-cheat
- **Selalu jalankan Mode Normal** setelah selesai

### Umum
- Perlu hak Administrator
- **Baca isi script** sebelum dijalankan
- **Jangan pakai di Proxmox produksi** — untuk lab saja

---

## Kontribusi

Sangat disambut:
- **Pengujian VirtualBox** — apakah auto-detect gateway `.1` bekerja?
- **Pengujian VMware versi lama** (`vnetlib64.exe`)
- Dukungan Hyper-V
- Penyempurnaan deteksi NIC (multi-NIC server fisik)
- Perbaikan deteksi/pesan error di Windows (ExecutionPolicy, SmartScreen)

Pastikan `.sh` line ending **LF** (diatur lewat `.gitattributes`).

---

## Pembuat

**Masrul Hadi | Youserroot**

Dibuat untuk membantu teman-teman satu kelas mengerjakan Tugas Besar **Sistem dan Aplikasi Virtual** — Prodi Teknologi Informasi, FST UIN Ar-Raniry Banda Aceh.

---
