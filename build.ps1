param(
    [switch]$Obfuscate,
    [string]$Output = "liomarket.luau"
)

$ErrorActionPreference = "Stop"

$srcDir = Join-Path $PSScriptRoot "src"
$outPath = Join-Path $PSScriptRoot $Output

$parts = Get-ChildItem -Path $srcDir -Filter "*.luau" | Sort-Object Name

if ($parts.Count -eq 0) {
    throw "Tidak ada file .luau di $srcDir"
}

$builder = New-Object System.Text.StringBuilder

$null = $builder.AppendLine("--[[")
$null = $builder.AppendLine("    liomarket.luau")
$null = $builder.AppendLine("    Auto-generated. Edit src/*.luau lalu run: .\build.ps1")
$null = $builder.AppendLine("]]")
$null = $builder.AppendLine()

foreach ($part in $parts) {
    $null = $builder.AppendLine("--==================================================")
    $null = $builder.AppendLine("-- " + $part.Name)
    $null = $builder.AppendLine("--==================================================")

    $content = Get-Content -Path $part.FullName -Raw

    if ($Obfuscate) {
        $lines = $content -split "`r?`n"
        $kept = New-Object System.Collections.Generic.List[string]
        $inBlock = $false

        foreach ($line in $lines) {
            $trimmed = $line.Trim()

            if ($inBlock) {
                # Cari penutup ]] di baris ini
                if ($trimmed -match '\]\]') {
                    $inBlock = $false

                    # Kalau ada sisa kode setelah ]] , ambil sisanya
                    $rest = $trimmed.Substring($trimmed.IndexOf(']]') + 2).Trim()
                    if ($rest -ne "") {
                        $null = $kept.Add($rest)
                    }
                }

                continue
            }

            # Buka blok komentar --[[
            if ($trimmed -match '^\s*--\[\[') {
                # Kalau ada ]] di baris yang sama, blok langsung tertutup
                $after = $trimmed.Substring($trimmed.IndexOf('[[') + 2)
                if ($after -notmatch '\]\]') {
                    $inBlock = $true
                }

                continue
            }

            # Komentar baris penuh
            if ($trimmed.StartsWith("--")) {
                continue
            }

            # Baris kosong
            if ($trimmed -eq "") {
                continue
            }

            $null = $kept.Add($line)
        }

        $content = $kept -join "`n"
    }

    $null = $builder.AppendLine($content)
    $null = $builder.AppendLine()
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $builder.ToString(), $utf8)

Write-Host "Build selesai: $outPath"
Write-Host ("Parts digabung: " + $parts.Count)
Write-Host ("Obfuscate: " + $Obfuscate)
Write-Host ("Ukuran: " + (Get-Item $outPath).Length + " bytes")