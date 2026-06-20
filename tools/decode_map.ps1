# decode_map_blocks.ps1 - 用 Windows WIC 解码地图块 JPEG
$mapPath = "D:\Godot\传梦之路1.5\新建游戏项目\maps\1211.map"
$outDir = "D:\Godot\传梦之路1.5\新建游戏项目\maps\blocks"

# 创建输出目录
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# 读取 map 文件
[byte[]]$data = [System.IO.File]::ReadAllBytes($mapPath)

# 解析头
$flag = [System.Text.Encoding]::ASCII.GetString($data[0..3])
$w = [System.BitConverter]::ToUInt32($data, 4)
$h = [System.BitConverter]::ToUInt32($data, 8)
$colNum = [int][Math]::Ceiling($w / 320.0)
$rowNum = [int][Math]::Ceiling($h / 240.0)
$blockNum = $rowNum * $colNum
Write-Host "地图: $flag ${w}x${h} 块=$blockNum 行=$rowNum 列=$colNum"

# 读块偏移
$pos = 12
$blockOff = @()
for ($i = 0; $i -lt $blockNum; $i++) {
    $blockOff += [System.BitConverter]::ToUInt32($data, $pos)
    $pos += 4
}
$pos += 4

if ($flag -eq "0.1M") {
    $maskCount = [System.BitConverter]::ToUInt32($data, $pos)
    $pos += 4
    $pos += $maskCount * 4
}

function Repair-Jpeg {
    param([byte[]]$src)
    $out = New-Object System.Collections.Generic.List[byte]
    $i = 0; $n = $src.Length; $inScan = $false
    
    while ($i -lt $n) {
        $b = $src[$i]
        if ($b -eq 0xFF -and ($i + 1) -lt $n) {
            $m = $src[$i + 1]
            if ((-not $inScan) -and $m -eq 0xA0) { $i += 2; continue }
            if ($m -eq 0xDA) {
                $inScan = $true
                $out.Add(0xFF); $out.Add(0xDA); $i += 2
                $segLen = ($src[$i] -shl 8) -bor $src[$i+1]
                $out.Add($src[$i]); $out.Add($src[$i+1]); $i += 2
                for ($k = 2; $k -lt $segLen -and $i -lt $n; $k++) { $out.Add($src[$i]); $i++ }
                continue
            }
            if ($m -eq 0xD9) { $out.Add(0xFF); $out.Add(0xD9); $i += 2; $inScan = $false; continue }
            if ($inScan -and $m -ge 0xD0 -and $m -le 0xD7) { $out.Add(0xFF); $out.Add($m); $i += 2; continue }
            if ($inScan -and $m -eq 0x00) { $out.Add(0xFF); $out.Add(0x00); $i += 2; continue }
            if ($inScan) { $out.Add(0xFF); $out.Add(0x00); $i += 1; continue }
        }
        $out.Add($b); $i++
    }
    return $out.ToArray()
}

$ok = 0; $fail = 0
# 加载 WIC
Add-Type -AssemblyName System.Drawing

for ($bi = 0; $bi -lt $blockNum; $bi++) {
    $p = $blockOff[$bi]
    $eat = [System.BitConverter]::ToUInt32($data, $p)
    $p += 4
    if ($flag -eq "0.1M") { $p += $eat * 4 }

    # 找 GEPJ
    $jOff = 0; $jSz = 0; $found = $false
    for ($t = 0; $t -lt 20; $t++) {
        $tag = [System.Text.Encoding]::ASCII.GetString($data[$p..($p+3)])
        $sz = [System.BitConverter]::ToUInt32($data, $p+4)
        if ($tag -eq "GEPJ" -or $tag -eq "2GPJ") { $jOff = $p + 8; $jSz = $sz; $found = $true; break }
        $p += 8 + $sz
    }
    if (-not $found) { $fail++; continue }

    $jpeg = $data[$jOff..($jOff+$jSz-1)]
    $fixed = Repair-Jpeg -src $jpeg
    
    try {
        $ms = New-Object System.IO.MemoryStream($fixed, 0, $fixed.Length)
        $img = [System.Drawing.Image]::FromStream($ms)
        $outPath = "$outDir\block_$bi.png"
        $img.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose()
        $ms.Dispose()
        $ok++
    } catch {
        $fail++
    }
}

Write-Host "结果: 成功 $ok / 失败 $fail / 共 $blockNum"
