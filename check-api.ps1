param(
    [string]$Target = "liomarket.luau"
)

# Validasi pemakaian API Rayfield.
# Script ini catching error SEBELUM crash, lalu lanjut.

$ErrorActionPreference = "Stop"

$rayfieldPath = "$env:TEMP\rayfield_sig.txt"

if (-not (Test-Path $rayfieldPath)) {
    Invoke-WebRequest -Uri "https://sirius.menu/rayfield" `
        -OutFile $rayfieldPath -UseBasicParsing -TimeoutSec 30
}

$rf = Get-Content $rayfieldPath -Raw

# Method yang WAJIB pakai argumen string (bukan table settings)
$stringArgMethods = @(
    "CreateSection",
    "CreateLabel",
    "CreateDivider"
)

# Method yang WAJIB pakai table settings
$tableArgMethods = @(
    "CreateButton",
    "CreateInput",
    "CreateToggle",
    "CreateDropdown",
    "CreateKeybind",
    "CreateSlider"
)

$errors = @()

foreach ($m in $stringArgMethods) {
    if ($rf -notmatch "function Tab:$m\(") {
        $errors += "METHOD HILANG: Tab:$m tidak ada di Rayfield."
    }
}

foreach ($m in $tableArgMethods) {
    if ($rf -notmatch "function Tab:$m\(") {
        $errors += "METHOD HILANG: Tab:$m tidak ada di Rayfield."
    }
}

# RayfieldLibrary methods
foreach ($m in @("Notify", "Destroy", "LoadConfiguration", "IsVisible", "SetVisibility")) {
    if ($rf -notmatch "function RayfieldLibrary:$m\(") {
        $errors += "METHOD HILANG: RayfieldLibrary:$m tidak ada."
    }
}

# Cek pemakaian di script kita
$src = Get-Content $Target -Raw

# Tab:CreateXxx({ ... }) untuk method string-arg = SALAH
foreach ($m in $stringArgMethods) {
    if ($src -match "$m\s*\(\s*\{") {
        $errors += "SALAH: $m dipanggil dengan table. Harus string."
    }
}

# Tab:CreateXxx("...") untuk method table-arg = SALAH
foreach ($m in $tableArgMethods) {
    if ($src -match "$m\s*\(\s*(`"|')") {
        $errors += "SALAH: $m dipanggil dengan string. Harus table."
    }
}

# Rayfield:Toggle() tidak ada di versi ini
if ($src -match "Rayfield\s*:\s*Toggle\s*\(") {
    $errors += "SALAH: Rayfield:Toggle() tidak ada. Pakai SetVisibility(not IsVisible())."
}

# CreateParagraph: template-nya tidak ada di UI asset
if ($src -match "CreateParagraph") {
    $errors += "SALAH: CreateParagraph memakai template yang tidak ada. Pakai CreateLabel."
}

# foreach dengan tangkapan i untuk Tab
if ($src -match "for\s+i\s*=\s*1\s*,\s*2\s+do[\s\S]{0,400}?Callback\s*=\s*function[\s\S]{0,200}?End\s*=\s*i") {
    $errors += "PERIKSA: pastikan i di-capture lokal (local idx = i)."
}

if ($errors.Count -eq 0) {
    Write-Host "API OK: $Target"
    exit 0
}

Write-Host "MASALAH API di ${Target}:"
$errors | ForEach-Object { Write-Host "  - $_" }
exit 1