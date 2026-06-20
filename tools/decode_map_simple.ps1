# decode_map_simple.ps1
param([string]$mapFile, [string]$outDir)

if (!$mapFile) { Write-Host "Usage: decode_map_simple.ps1 <mapfile> <outdir>"; exit 1 }
if (!$outDir) { $outDir = Split-Path $mapFile }

[byte[]]$data = [System.IO.File]::ReadAllBytes($mapFile)
$flag = [System.Text.Encoding]::ASCII.GetString($data[0..3])
$w = [System.BitConverter]::ToUInt32($data, 4)
$h = [System.BitConverter]::ToUInt32($data, 8)
$colNum = [int][Math]::Ceiling($w / 320.0)
$rowNum = [int][Math]::Ceiling($h / 240.0)
$blockNum = $rowNum * $colNum
Write-Host "MAP: $flag ${w}x${h} blocks=$blockNum"

$pos = 12
$blockOff = @()
for ($i = 0; $i -lt $blockNum; $i++) { $blockOff += [System.BitConverter]::ToUInt32($data, $pos); $pos += 4 }
$pos += 4
if ($flag -eq "0.1M") { $mc = [System.BitConverter]::ToUInt32($data, $pos); $pos += 4; $pos += $mc * 4 }

Add-Type -AssemblyName System.Drawing
$ok = 0; $fail = 0

for ($bi = 0; $bi -lt $blockNum; $bi++) {
    $p = $blockOff[$bi]
    $eat = [System.BitConverter]::ToUInt32($data, $p); $p += 4
    if ($flag -eq "0.1M") { $p += $eat * 4 }
    $jOff = 0; $jSz = 0; $found = $false
    for ($t = 0; $t -lt 20; $t++) {
        $tag = [System.Text.Encoding]::ASCII.GetString($data[$p..($p+3)])
        $sz = [System.BitConverter]::ToUInt32($data, $p+4)
        if ($tag -eq "GEPJ" -or $tag -eq "2GPJ") { $jOff = $p + 8; $jSz = $sz; $found = $true; break }
        $p += 8 + $sz
    }
    if (!$found) { $fail++; continue }

    $jpeg = $data[$jOff..($jOff+$jSz-1)]
    # 修复 JPEG
    $out = New-Object System.Collections.Generic.List[byte]
    $i = 0; $n = $jpeg.Length; $inScan = $false
    while ($i -lt $n) {
        $b = $jpeg[$i]
        if ($b -eq 0xFF -and ($i + 1) -lt $n) {
            $m = $jpeg[$i + 1]
            if ((-not $inScan) -and $m -eq 0xA0) { $i += 2; continue }
            if ($m -eq 0xDA) { $inScan = $true; $out.Add(0xFF); $out.Add(0xDA); $i += 2
                $segLen = ($jpeg[$i] -shl 8) -bor $jpeg[$i+1]
                $out.Add($jpeg[$i]); $out.Add($jpeg[$i+1]); $i += 2
                for ($k = 2; $k -lt $segLen -and $i -lt $n; $k++) { $out.Add($jpeg[$i]); $i++ }; continue }
            if ($m -eq 0xD9) { $out.Add(0xFF); $out.Add(0xD9); $i += 2; $inScan = $false; continue }
            if ($inScan -and $m -ge 0xD0 -and $m -le 0xD7) { $out.Add(0xFF); $out.Add($m); $i += 2; continue }
            if ($inScan -and $m -eq 0x00) { $out.Add(0xFF); $out.Add(0x00); $i += 2; continue }
            if ($inScan) { $out.Add(0xFF); $out.Add(0x00); $i += 1; continue }
        }
        $out.Add($b); $i++
    }
    $fixed = $out.ToArray()

    try {
        $ms = New-Object System.IO.MemoryStream($fixed, 0, $fixed.Length)
        $img = [System.Drawing.Image]::FromStream($ms)
        $outPath = Join-Path $outDir "block_$bi.png"
        $img.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose(); $ms.Dispose()
        $ok++
    } catch { $fail++ }
}
Write-Host "OK=$ok FAIL=$fail TOTAL=$blockNum"
