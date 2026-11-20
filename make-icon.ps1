# 아이콘 생성: icons\QuickUnzip.ico (앱) + icons\<형식>.ico (형식 이름 라벨)
Add-Type -AssemblyName System.Drawing
$outDir = Join-Path $PSScriptRoot 'icons'
New-Item -ItemType Directory -Force $outDir | Out-Null
$sizes = 16, 24, 32, 48, 64, 128, 256

# 형식별 라벨 색
$labels = [ordered]@{
    'QuickUnzip' = $null
    'ZIP' = '#2F6FDE'; '7Z' = '#2E9E4F'; 'RAR' = '#8E3FC7'; 'TAR' = '#6B6B6B'
    'GZ' = '#D9532B'; 'TGZ' = '#D9532B'; 'BZ2' = '#C0392B'; 'XZ' = '#B8860B'; 'ZST' = '#16A0A0'
    'CAB' = '#3A5BA0'; 'ISO' = '#455A64'; 'LZH' = '#7A4E2D'; 'JAR' = '#E07B00'
}

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath; $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); $p
}

function New-IconPng([int]$s, [string]$label, [string]$color) {
    $bmp = New-Object Drawing.Bitmap $s, $s
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([Drawing.Color]::Transparent)
    $g.ScaleTransform($s / 256.0, $s / 256.0)   # 256 기준 좌표로 그림
    $back = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(230, 160, 20))
    $g.FillPath($back, (New-RoundRect 16 40 100 50 14))
    $g.FillPath($back, (New-RoundRect 16 64 224 168 18))
    $lg = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.PointF]::new(0, 84)), ([Drawing.PointF]::new(0, 236)),
          ([Drawing.Color]::FromArgb(255, 214, 90)), ([Drawing.Color]::FromArgb(250, 180, 40))
    $g.FillPath($lg, (New-RoundRect 16 84 224 152 18))
    # 지퍼
    $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 70, 40))), 112, 84, 32, 60)
    if ($s -ge 32) { for ($y = 88; $y -lt 140; $y += 12) {
        $g.FillRectangle([Drawing.Brushes]::WhiteSmoke, 116, $y, 11, 6); $g.FillRectangle([Drawing.Brushes]::WhiteSmoke, 129, $y + 6, 11, 6) } }

    if (-not $label) {
        # 앱 아이콘: 파란 아래 화살표
        $g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30, 120, 230))), 88, 140, 80, 80)
        $pen = New-Object Drawing.Pen ([Drawing.Color]::White), ([single][Math]::Max(12, 1.5 * 256 / $s))
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
        $g.DrawLine($pen, 128, 158, 128, 200)
        $g.DrawLines($pen, [Drawing.PointF[]]@([Drawing.PointF]::new(108, 182), [Drawing.PointF]::new(128, 202), [Drawing.PointF]::new(148, 182)))
    } else {
        # 형식 라벨 배지
        $c = [Drawing.ColorTranslator]::FromHtml($color)
        $g.FillPath((New-Object Drawing.SolidBrush $c), (New-RoundRect 24 150 208 74 14))
        $fontSize = if ($label.Length -ge 3) { 54 } else { 62 }
        if ($s -le 24) { $fontSize += 10 }   # 작은 크기에선 글자를 더 크게
        $font = New-Object Drawing.Font 'Segoe UI', $fontSize, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString($label, $font, [Drawing.Brushes]::White, [Drawing.RectangleF]::new(14, 148, 228, 80), $sf)
    }
    $g.Dispose()
    $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    , $ms.ToArray()
}

function Write-Ico([string]$path, $pngs) {
    $fs = [IO.File]::Create($path); $w = New-Object IO.BinaryWriter $fs
    $w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $b = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([UInt16]1); $w.Write([UInt16]32); $w.Write([UInt32]$pngs[$i].Length); $w.Write([UInt32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($p in $pngs) { $w.Write($p) }
    $w.Close()
}

# 미리보기 시트
$sheet = New-Object Drawing.Bitmap (128 * 7), (128 * 2)
$sg = [Drawing.Graphics]::FromImage($sheet); $sg.Clear([Drawing.Color]::White); $n = 0
foreach ($k in $labels.Keys) {
    $label = if ($k -eq 'QuickUnzip') { $null } else { $k }
    $pngs = foreach ($s in $sizes) { , (New-IconPng $s $label $labels[$k]) }
    Write-Ico (Join-Path $outDir "$k.ico") $pngs
    $img = [Drawing.Image]::FromStream((New-Object IO.MemoryStream (, $pngs[5])))
    $sg.DrawImage($img, ($n % 7) * 128, [Math]::Floor($n / 7) * 128, 128, 128); $n++
}
$sheet.Save((Join-Path $PSScriptRoot 'icon-preview.png'))
