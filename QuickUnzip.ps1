param([Parameter(Mandatory)][string]$ArchivePath,
      [ValidateSet('auto','utf8','cp949','cp932','cp936')][string]$Encoding = 'auto')
# Mac처럼: 압축 파일 옆에 폴더로 바로 풀고 탐색기로 열기
# zip: .NET (한글 CP949 이름 지원) / 그 외: Windows 내장 tar.exe (libarchive: 7z, rar, tar.*, cab, iso, lzh 등)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem, System.Windows.Forms
$ErrorActionPreference = 'Stop'
$tmp = $null
try {
    $arc  = (Resolve-Path -LiteralPath $ArchivePath).Path
    $dir  = Split-Path $arc -Parent
    $name = Split-Path $arc -Leaf
    $ext  = [IO.Path]::GetExtension($name).ToLower()
    $base = $name -replace '(?i)(\.tar)?\.[^.]+$', ''
    if (-not $base) { $base = $name }

    function Get-FreePath([string]$p) {
        if (-not (Test-Path -LiteralPath $p)) { return $p }
        $i = 2; while (Test-Path -LiteralPath "$p $i") { $i++ }; return "$p $i"
    }

    $tmp = Join-Path $dir (".quickunzip_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $tmp | Out-Null

    if ($ext -in '.zip', '.jar', '.apk', '.epub') {
        # 파일 이름 인코딩 (UTF-8 플래그가 있는 항목은 항상 UTF-8)
        $cp = switch ($Encoding) { 'utf8' { 65001 } 'cp949' { 949 } 'cp932' { 932 } 'cp936' { 936 } default {
            # 자동: 플래그 없는 이름들이 올바른 UTF-8이면 UTF-8(Mac/Linux zip), 아니면 CP949
            $raw = [IO.Compression.ZipFile]::Open($arc, 'Read', [Text.Encoding]::GetEncoding(28591))
            $strict = New-Object Text.UTF8Encoding $false, $true; $isUtf8 = $true
            foreach ($e in $raw.Entries) {
                try { [void]$strict.GetString([Text.Encoding]::GetEncoding(28591).GetBytes($e.FullName)) } catch { $isUtf8 = $false; break }
            }
            $raw.Dispose(); if ($isUtf8) { 65001 } else { 949 } } }
        [IO.Compression.ZipFile]::ExtractToDirectory($arc, $tmp, [Text.Encoding]::GetEncoding($cp))
    } elseif ($ext -eq '.gz' -and $name -notmatch '(?i)\.tar\.gz$' -and
              ((& tar.exe -tf $arc 2>$null) -eq $null)) {
        # tar가 아닌 단일 .gz 파일
        $in = [IO.File]::OpenRead($arc); $gz = New-Object IO.Compression.GZipStream $in, ([IO.Compression.CompressionMode]::Decompress)
        $out = [IO.File]::Create((Join-Path $tmp ($name -replace '(?i)\.gz$', '')))
        $gz.CopyTo($out); $out.Close(); $gz.Close()
    } else {
        $err = & tar.exe -xf $arc -C $tmp 2>&1
        if ($LASTEXITCODE -ne 0) { throw ("지원하지 않거나 손상된 압축 파일입니다.`n" + ($err | Out-String)) }
    }

    Remove-Item -LiteralPath (Join-Path $tmp '__MACOSX') -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $tmp -Recurse -Force -Filter '.DS_Store' | Remove-Item -Force -ErrorAction SilentlyContinue

    $items = @(Get-ChildItem -LiteralPath $tmp -Force)
    if ($items.Count -eq 1) {
        # 안에 폴더(또는 파일) 하나뿐이면 그것만 꺼냄
        $target = Get-FreePath (Join-Path $dir $items[0].Name)
        Move-Item -LiteralPath $items[0].FullName -Destination $target
        Remove-Item -LiteralPath $tmp -Recurse -Force
        $open = if ($items[0].PSIsContainer) { $target } else { $null }
    } else {
        $target = Get-FreePath (Join-Path $dir $base)
        Move-Item -LiteralPath $tmp -Destination $target
        $open = $target
    }
    $tmp = $null
    if (-not $env:QUICKUNZIP_NOOPEN) {
        if ($open) { Start-Process explorer.exe "`"$open`"" } else { Start-Process explorer.exe "/select,`"$target`"" }
    }
} catch {
    if ($tmp -and (Test-Path -LiteralPath $tmp)) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    [Windows.Forms.MessageBox]::Show("압축 풀기 실패: $ArchivePath`n`n$($_.Exception.Message)", 'QuickUnzip', 'OK', 'Error') | Out-Null
    exit 1
}
