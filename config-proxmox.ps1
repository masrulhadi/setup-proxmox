<#
  setup-lab.ps1 - Seragamkan jaringan lab Proxmox (VMware Workstation / VirtualBox)

  Hasil akhir (sama untuk semua kelompok):
    Host-only : 192.168.56.0/24   (Windows = 192.168.56.1)
    NAT       : 192.168.221.0/24  (Windows = 192.168.221.1, gateway = 192.168.221.2)
    Web Proxmox: https://192.168.56.10X:8006   (X = nomor kelompok)

  Cara pakai (PowerShell sebagai Administrator):
    powershell -ExecutionPolicy Bypass -File .\setup-lab.ps1
#>
#Requires -RunAsAdministrator

$HO_NET  = '192.168.56'
$NAT_NET = '192.168.221'

function Say($m, $c = 'Cyan') { Write-Host $m -ForegroundColor $c }

$BannerA = @'
         ______  ____    ____    __  __  __          __  __  ______  ____    ______
 /'\_/`\/\  _  \/\  _`\ /\  _`\ /\ \/\ \/\ \        /\ \/\ \/\  _  \/\  _`\ /\__  _\
/\      \ \ \L\ \ \,\L\_\ \ \L\ \ \ \ \ \ \ \       \ \ \_\ \ \ \L\ \ \ \/\ \/_/\ \/
\ \ \__\ \ \  __ \/_\__ \\ \ ,  /\ \ \ \ \ \ \  __   \ \  _  \ \  __ \ \ \ \ \ \ \ \
 \ \ \_/\ \ \ \/\ \/\ \L\ \ \ \\ \\ \ \_\ \ \ \L\ \   \ \ \ \ \ \ \/\ \ \ \_\ \ \_\ \__
  \ \_\\ \_\ \_\ \_\ `\____\ \_\ \_\ \_____\ \____/    \ \_\ \_\ \_\ \_\ \____/ /\_____\
   \/_/ \/_/\/_/\/_/\/_____/\/_/\/ /\/_____/\/___/      \/_/\/_/\/_/\/_/\/___/  \/_____/
'@

$BannerB = @'
 __    __  _____   __  __  ____    ____    ____    ____    _____   _____   ______
/\ \  /\ \/\  __`\/\ \/\ \/\  _`\ /\  _`\ /\  _`\ /\  _`\ /\  __`\/\  __`\/\__  _\
\ `\`\\/'/\ \ \/\ \ \ \ \ \ \,\L\_\ \ \L\_\ \ \L\ \ \ \L\ \ \ \/\ \ \ \/\ \/_/\ \/
 `\ `\ /'  \ \ \ \ \ \ \ \ \/_\__ \\ \  _\L\ \ ,  /\ \ ,  /\ \ \ \ \ \ \ \ \ \ \ \
   `\ \ \   \ \ \_\ \ \ \_\ \/\ \L\ \ \ \L\ \ \ \\ \\ \ \\ \\ \ \_\ \ \ \_\ \ \ \ \
     \ \_\   \ \_____\ \_____\ `\____\ \____/\ \_\ \_\ \_\ \_\ \_____\ \_____\ \ \_\
      \/_/    \/_____/\/_____/\/_____/\/___/  \/_/\/ /\/_/\/ /\/_____/\/_____/  \/_/
'@

function Show-Banner {
    Write-Host ''
    Write-Host $BannerA -ForegroundColor Cyan
    Write-Host ''
    Write-Host $BannerB -ForegroundColor Magenta
    Write-Host ''
    Write-Host ('  ' + 'Masrul Hadi | Youserroot') -ForegroundColor Yellow
    Write-Host ('  Proxmox Lab Network Setup') -ForegroundColor DarkGray
    Write-Host ''
}
Show-Banner

# ---------- input nomor kelompok ----------
do { $g = Read-Host 'Nomor kelompok (1-99)' } until ($g -match '^\d+$' -and [int]$g -ge 1 -and [int]$g -le 99)
$g = [int]$g
$ProxIP = "$HO_NET." + (100 + $g)

# ---------- deteksi hypervisor ----------
function Find-Tool($exe, $regKeys, $subDirs) {
    $cands = @()
    # 1. registry
    foreach ($k in $regKeys) {
        $p = Get-ItemProperty -Path $k.Path -ErrorAction SilentlyContinue
        if ($p -and $p.($k.Value)) { $cands += (Join-Path $p.($k.Value) $exe) }
    }
    # 2. PATH
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if ($cmd) { $cands += $cmd.Source }
    # 3. semua drive lokal: Program Files / Program Files (x86) / root drive
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
        foreach ($pf in @('Program Files', 'Program Files (x86)', '')) {
            foreach ($sub in $subDirs) { $cands += (Join-Path (Join-Path $d.Root $pf) "$sub\$exe") }
        }
    }
    $cands | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

$vmwReg = @(
    @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation'; Value = 'InstallPath' },
    @{ Path = 'HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation';             Value = 'InstallPath' }
)
# VMware versi lama: vnetlib64.exe, versi baru: vnetlib.exe (64-bit)
$vnet = Find-Tool 'vnetlib64.exe' $vmwReg @('VMware\VMware Workstation')
if (-not $vnet) { $vnet = Find-Tool 'vnetlib.exe' $vmwReg @('VMware\VMware Workstation') }

$vbox = Find-Tool 'VBoxManage.exe' @(
    @{ Path = 'HKLM:\SOFTWARE\Oracle\VirtualBox'; Value = 'InstallDir' }
) @('Oracle\VirtualBox')

if (-not $vnet -and -not $vbox) {
    Say 'VMware Workstation / VirtualBox tidak ditemukan otomatis.' Yellow
    Say 'Masukkan path lengkap ke vnetlib64.exe (VMware) atau VBoxManage.exe (VirtualBox).'
    $manual = (Read-Host 'Path').Trim('"', ' ')
    if (-not (Test-Path $manual)) { Say 'Path tidak valid.' Red; exit 1 }
    if ($manual -like '*vnetlib64.exe' -or $manual -like '*vnetlib.exe') { $vnet = $manual }
    elseif ($manual -like '*VBoxManage.exe') { $vbox = $manual }
    else { Say 'File harus vnetlib64.exe atau VBoxManage.exe.' Red; exit 1 }
}
if ($vnet) { Say "VMware     : $vnet" Gray }
if ($vbox) { Say "VirtualBox : $vbox" Gray }

$mode = $null
if ($vnet -and $vbox) {
    $a = Read-Host 'Terdeteksi VMware dan VirtualBox. Pakai yang mana? (1=VMware, 2=VirtualBox)'
    $mode = if ($a -eq '2') { 'vbox' } else { 'vmware' }
} elseif ($vnet) { $mode = 'vmware' } else { $mode = 'vbox' }

# ---------- VMware ----------
function Set-VMware {
    Say "`n[VMware] Mengatur VMnet1 (host-only) dan VMnet8 (NAT)..."
    Say '  Pastikan VMware Workstation tertutup / semua VM mati.' Yellow
    $steps = @(
        'stop dhcp', 'stop nat',
        'set vnet vmnet1 mask 255.255.255.0', "set vnet vmnet1 addr $HO_NET.0",
        'set vnet vmnet8 mask 255.255.255.0', "set vnet vmnet8 addr $NAT_NET.0",
        "set adapter vmnet1 addr $HO_NET.1",  "set adapter vmnet8 addr $NAT_NET.1",
        'update adapter vmnet1', 'update adapter vmnet8',
        'update dhcp vmnet1', 'update dhcp vmnet8', 'update nat vmnet8',
        'start dhcp', 'start nat'
    )
    # vnetlib harus dipanggil lewat cmd /c dari folder instalasinya, supaya '--' sampai apa adanya
    $vnetDir  = Split-Path $vnet -Parent
    $vnetName = Split-Path $vnet -Leaf
    Push-Location $vnetDir
    foreach ($s in $steps) {
        # exit code vnetlib versi baru tidak bisa dipercaya (selalu 1), jadi diabaikan;
        # keberhasilan dicek lewat IP adapter di bawah.
        & cmd.exe /c "$vnetName -- $s" 2>&1 | Out-Null
    }
    Pop-Location
    # verifikasi hasil sebenarnya
    $okHO  = [bool](Get-NetIPAddress -IPAddress "$HO_NET.1"  -ErrorAction SilentlyContinue)
    $okNAT = [bool](Get-NetIPAddress -IPAddress "$NAT_NET.1" -ErrorAction SilentlyContinue)
    if ($okHO -and $okNAT) { Say "  [OK] VMnet1 = $HO_NET.1, VMnet8 = $NAT_NET.1" Green }
    else {
        Say "  [GAGAL] IP adapter VMnet belum sesuai (VMnet1 $HO_NET.1 / VMnet8 $NAT_NET.1)." Red
        Say '  Atur manual lewat Virtual Network Editor (vmnetcfg.exe), lihat panduan.' Red
    }
    $natConf = 'C:\ProgramData\VMware\vmnetnat.conf'
    if (Test-Path $natConf) {
        Say '  Cek gateway NAT di vmnetnat.conf (harus ip = 192.168.221.2):'
        Select-String -Path $natConf -Pattern '^\s*ip\s*=' | ForEach-Object { Say "    $($_.Line.Trim())" Gray }
    }
    Say "`n  Di Settings VM Proxmox, atur urutan NIC:" Yellow
    Say '    Network Adapter 1 -> Custom: VMnet1 (host-only)'
    Say '    Network Adapter 2 -> NAT (VMnet8)'
}

# ---------- VirtualBox ----------
function Set-VBox {
    Say "`n[VirtualBox] Mengatur host-only dan NAT..."
    $vms = @(& $vbox list vms | ForEach-Object { if ($_ -match '^"(.+)"\s+\{') { $Matches[1] } })
    if ($vms.Count -eq 0) { Say 'Belum ada VM di VirtualBox. Buat VM Proxmox dulu.' Red; exit 1 }
    for ($i = 0; $i -lt $vms.Count; $i++) { Say "  [$($i+1)] $($vms[$i])" Gray }
    $n = [int](Read-Host 'Pilih nomor VM Proxmox')
    $vm = $vms[$n - 1]

    if (& $vbox showvminfo $vm --machinereadable | Select-String '^VMState="running"') {
        Say "VM '$vm' sedang berjalan. Matikan dulu (Power Off), lalu jalankan ulang." Red; exit 1
    }

    # host-only adapter
    $name = (& $vbox list hostonlyifs | Select-String '^Name:\s+(.+)$' | Select-Object -First 1)
    if (-not $name) {
        & $vbox hostonlyif create | Out-Null
        $name = (& $vbox list hostonlyifs | Select-String '^Name:\s+(.+)$' | Select-Object -First 1)
    }
    $ifName = $name.Matches[0].Groups[1].Value.Trim()
    & $vbox hostonlyif ipconfig "$ifName" --ip "$HO_NET.1" --netmask 255.255.255.0 | Out-Null
    & $vbox dhcpserver remove --interface "$ifName" 2>$null | Out-Null   # IP Proxmox statis, DHCP tidak perlu

    # NIC1 = host-only, NIC2 = NAT dengan subnet 192.168.221.0/24 (gateway otomatis .2)
    & $vbox modifyvm $vm --nic1 hostonly --hostonlyadapter1 "$ifName" --nictype1 82540EM --cableconnected1 on
    & $vbox modifyvm $vm --nic2 nat --nictype2 82540EM --natnet2 "$NAT_NET.0/24" --cableconnected2 on
    & $vbox modifyvm $vm --nested-hw-virt on 2>$null | Out-Null
    Say "  VM '$vm': NIC1 = host-only ($ifName), NIC2 = NAT ($NAT_NET.0/24)"
}

if ($mode -eq 'vmware') { Set-VMware } else { Set-VBox }

# ---------- ringkasan ----------
Say "`n=== Adapter Windows saat ini ===" Green
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -like "$HO_NET.*" -or $_.IPAddress -like "$NAT_NET.*" } |
    Format-Table InterfaceAlias, IPAddress, PrefixLength -AutoSize

Say '=== Langkah berikutnya ===' Green
Say '1. Nyalakan VM Proxmox, login di console sebagai root.'
Say "2. Jalankan:  bash setup-proxmox.sh $g"
Say "3. Buka dari Windows:  https://${ProxIP}:8006" Yellow
Say "`nCatatan: kalau Windows memblokir ping, set profil jaringan adapter ke Private."

# ---------- sajikan setup-proxmox.sh lewat HTTP ----------
function Start-Serve($shFile, $g) {
    $port  = 8000
    $rule  = 'lab-http-temp'
    # kirim dengan line ending Linux (LF)
    $bytes = [Text.Encoding]::UTF8.GetBytes(((Get-Content $shFile -Raw) -replace "`r`n", "`n"))

    New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol TCP -LocalPort $port `
        -Action Allow -Profile Any | Out-Null
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://${HO_NET}.1:$port/")
    $l.Prefixes.Add("http://${NAT_NET}.1:$port/")
    try { $l.Start() } catch {
        Say "Gagal memulai web server: $($_.Exception.Message)" Red
        Remove-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
        return
    }

    Say "`n=== Ketik ini di console Proxmox (login root) ===" Green
    Say "ip addr add ${HO_NET}.200/24 dev vmbr0" Yellow
    Say "curl -sO http://${HO_NET}.1:$port/setup-proxmox.sh && bash setup-proxmox.sh $g" Yellow
    Say "`nKalau curl gagal (Connection refused / timeout), ulangi dengan subnet NAT:" Gray
    Say "ip addr add ${NAT_NET}.200/24 dev vmbr0" Gray
    Say "curl -sO http://${NAT_NET}.1:$port/setup-proxmox.sh && bash setup-proxmox.sh $g" Gray
    Say "`nServer aktif. Tekan Ctrl+C kalau sudah selesai..." Cyan

    try {
        while ($true) {
            $task = $l.GetContextAsync()
            while (-not $task.AsyncWaitHandle.WaitOne(500)) { }
            $ctx = $task.Result
            $ctx.Response.ContentType     = 'text/plain; charset=utf-8'
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $ctx.Response.Close()
            Say "  File terkirim ke $($ctx.Request.RemoteEndPoint)" Green
        }
    } finally {
        $l.Stop()
        Remove-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
        Say 'Server dihentikan, aturan firewall sementara dihapus.' Gray
    }
}

$shFile = Join-Path $PSScriptRoot 'setup-proxmox.sh'
if (Test-Path $shFile) {
    $ans = Read-Host "`nKirim setup-proxmox.sh ke Proxmox lewat HTTP sekarang? [Y/n]"
    if ($ans -notmatch '^[Nn]') { Start-Serve $shFile $g }
} else {
    Say "`nsetup-proxmox.sh tidak ada di folder ini, taruh di folder yang sama dengan setup-lab.ps1 untuk fitur kirim otomatis." Yellow
}