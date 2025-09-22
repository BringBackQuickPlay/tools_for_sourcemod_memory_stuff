# strict converter with ?, -prepverify/-pverify/-pv, and clean errors (PS 5.1 compatible)

function Show-Help {
@'
Usage:
  sm_hex_converter.ps1 [options...] "INPUT"
  sm_hex_converter.ps1 [options...] -filelist "PATH\TO\LIST.TXT"

Modes (case-insensitive; combine, order preserved):
  -tomems | -m       -> "AA BB ..." (2A -> "?", and input "?" stays "?")
  -tohex  | -x       -> "AA BB ..." ("?" -> "2A")
  -togamedata | -g   -> "\xAA\xBB\xCC" ("?" -> "\x2A")

Extra:
  -prepverify | -pverify | -pv | -prepareverify
      With -g, also prints a quoted, ready line:
      "verify:" "\xAA\xBB..."

Strict input only:
  • Space-hex or '?' tokens: ^([0-9A-Fa-f]{2}|\?)( ([0-9A-Fa-f]{2}|\?))*$
  • Gamedata bytes:          ^(\\x[0-9A-Fa-f]{2})+$   (no '?' allowed)

-filelist: lines starting with '#' or leading whitespace are ignored.
'@
}

# --- parse args from automatic $args ---
$lower = $args | ForEach-Object { $_.ToLowerInvariant() }
if ($lower -contains '-h' -or $lower -contains '-help') { Show-Help; exit 0 }

$modes = @()
$filelist = $null
$PrepVerify = $false

for ($i=0; $i -lt $args.Count; $i++) {
  $tok = $args[$i].ToLowerInvariant()
  switch ($tok) {
    '-filelist'       { if ($i+1 -ge $args.Count) { Write-Output "-filelist requires a path"; exit 1 }
                        $filelist = $args[$i+1]; $i++; continue }
    '-tomems'         { $modes += '-tomems'; continue }
    '-m'              { $modes += '-tomems'; continue }
    '-tohex'          { $modes += '-tohex'; continue }
    '-x'              { $modes += '-tohex'; continue }
    '-togamedata'     { $modes += '-togamedata'; continue }
    '-g'              { $modes += '-togamedata'; continue }
    '-prepverify'     { $PrepVerify = $true; continue }
    '-pverify'        { $PrepVerify = $true; continue }
    '-pv'             { $PrepVerify = $true; continue }
    '-prepareverify'  { $PrepVerify = $true; continue }
  }
}
if ($modes.Count -eq 0) { Write-Output "No conversion mode given."; Show-Help; exit 1 }

$reSpaceHexQ = '^([0-9A-Fa-f]{2}|\?)( ([0-9A-Fa-f]{2}|\?))*$'
$reGameData  = '^(\\x[0-9A-Fa-f]{2})+$'

function Parse-StrictBytes([string]$lineIn) {
  if ($null -eq $lineIn) { $line = '' } else { $line = $lineIn }
  $line = $line.Trim()
  if ($line -match $reSpaceHexQ) {
    $tokens = $line -split ' '
    return ($tokens | ForEach-Object { if ($_ -eq '?') { '?' } else { $_.ToUpperInvariant() } })
  } elseif ($line -match $reGameData) {
    $parts = ($line -split '\\x') | Where-Object { $_ -ne '' }
    return ($parts | ForEach-Object { $_.ToUpperInvariant() })
  } else {
    return $null
  }
}

function Emit-Tomems([string[]]$bytes) {
  $mapped = $bytes | ForEach-Object { if ($_ -eq '?' -or $_ -eq '2A') { '?' } else { $_ } }
  Write-Output 'tomems conversion (Used to memory search in for example Ghidra or IDA):'
  Write-Output ($mapped -join ' ')
}
function Emit-ToHex([string[]]$bytes) {
  $mapped = $bytes | ForEach-Object { if ($_ -eq '?') { '2A' } else { $_ } }
  Write-Output 'tohex conversion (Raw hex output, keeps 2A bytes):'
  Write-Output ($mapped -join ' ')
}
function Emit-ToGameData([string[]]$bytes, [bool]$DoPrepVerify) {
  $gamedata = ($bytes | ForEach-Object { if ($_ -eq '?') { '\x2A' } else { '\x' + $_ } }) -join ''
  Write-Output 'togamedata conversion (Used for SourceMod Address stuff and SourceScramble):'
  Write-Output $gamedata
  if ($DoPrepVerify) {
    Write-Output 'prepped for verify - copy the next line exactly:'
    Write-Output ('"verify:" "{0}"' -f $gamedata)
  }
}

if ($filelist) {
  if (-not (Test-Path -LiteralPath $filelist)) { Write-Output "File not found: $filelist"; exit 1 }
  $lines = Get-Content -LiteralPath $filelist -Encoding UTF8
  for ($ln=0; $ln -lt $lines.Count; $ln++) {
    $line = $lines[$ln]
    if ($line -match '^\s' -or $line -match '^#') { continue }
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    Write-Output ""
    Write-Output ('[file "{0}", line {1}]' -f $filelist, ($ln+1))

    $bytes = Parse-StrictBytes $line
    if ($null -eq $bytes) {
      Write-Output "REJECTED: invalid format. Expected 'AA 00 CC' or '\xAA\x00\xCC'."
      continue
    }

    foreach ($m in $modes) {
      switch ($m) {
        '-tomems'     { Emit-Tomems $bytes }
        '-tohex'      { Emit-ToHex $bytes }
        '-togamedata' { Emit-ToGameData $bytes $PrepVerify }
      }
    }
  }
} else {
  if ($args.Count -lt 1) { Write-Output "No input provided."; exit 2 }
  $rawInput = $args[-1]
  $bytes = Parse-StrictBytes $rawInput
  if ($null -eq $bytes) {
    Write-Output "REJECTED: invalid format. Expected 'AA 00 CC' or '\xAA\x00\xCC'."
    exit 2
  }
  foreach ($m in $modes) {
    switch ($m) {
      '-tomems'     { Emit-Tomems $bytes }
      '-tohex'      { Emit-ToHex $bytes }
      '-togamedata' { Emit-ToGameData $bytes $PrepVerify }
    }
  }
}
