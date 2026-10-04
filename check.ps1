param(
    [Parameter(Mandatory = $true)]
    [string]$File
)

# Cek keseimbangan bracket di luar string & komentar.
# Cukup untuk menangkap typo kurung kurawal/siku.

$src = Get-Content -Path $File -Raw
$i = 0
$len = $src.Length

$stack = New-Object System.Collections.Generic.Stack[object]
$line = 1
$inBlockComment = $false
$inLineComment = $false
$inString = $false
$quote = ""
$errors = @()

$pairs = @{ ")" = "("; "]" = "["; "}" = "{" }

while ($i -lt $len) {
    $c = $src[$i]
    $next = if ($i + 1 -lt $len) { $src[$i + 1] } else { "" }

    if ($c -eq "`n") { $line++ }

    if ($inLineComment) {
        if ($c -eq "`n") { $inLineComment = $false }
        $i++
        continue
    }

    if ($inBlockComment) {
        if ($c -eq "]" -and $next -eq "]") {
            $inBlockComment = $false
            $i += 2
            continue
        }
        $i++
        continue
    }

    if ($inString) {
        if ($c -eq "\") { $i += 2; continue }
        if ($c -eq $quote) { $inString = $false }
        $i++
        continue
    }

    if ($c -eq "-" -and $next -eq "-") {
        if ($i + 2 -lt $len -and $src[$i + 2] -eq "[" -and $src[$i + 3] -eq "[") {
            $inBlockComment = $true
            $i += 4
            continue
        }
        $inLineComment = $true
        $i += 2
        continue
    }

    if ($c -eq '"' -or $c -eq "'") {
        $inString = $true
        $quote = $c
        $i++
        continue
    }

    if ($c -eq "(" -or $c -eq "[" -or $c -eq "{") {
        $stack.Push(@{ ch = $c; line = $line })
        $i++
        continue
    }

    if ($pairs.ContainsKey([string]$c)) {
        if ($stack.Count -eq 0) {
            $errors += "Line ${line}: '$c' tanpa pasangan."
        }
        else {
            $top = $stack.Pop()
            if ($top.ch -ne $pairs[[string]$c]) {
                $errors += "Line ${line}: '$c' menutup '$($top.ch)' dari line $($top.line)."
            }
        }
        $i++
        continue
    }

    $i++
}

while ($stack.Count -gt 0) {
    $top = $stack.Pop()
    $errors += "Line $($top.line): '$($top.ch)' belum ditutup."
}

if ($inBlockComment) { $errors += "Blok komentar --[[ tidak ditutup." }
if ($inString) { $errors += "String tidak ditutup." }

if ($errors.Count -eq 0) {
    Write-Host "OK: bracket seimbang di $File"
    exit 0
}

Write-Host "MASALAH di ${File}:"
$errors | ForEach-Object { Write-Host "  $_" }
exit 1