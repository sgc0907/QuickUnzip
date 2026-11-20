# QuickUnzip 제거
$C = 'HKCU:\Software\Classes'
$exts = '.zip','.7z','.rar','.tar','.gz','.tgz','.bz2','.tbz','.tbz2','.xz','.txz','.zst','.tzst','.cab','.iso','.lzh','.lha','.jar'
foreach ($ext in $exts) {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$C\QuickUnzip$ext", "$C\SystemFileAssociations\$ext\shell\QuickUnzip"
    Remove-ItemProperty -ErrorAction SilentlyContinue "$C\$ext\OpenWithProgids" -Name "QuickUnzip$ext"
}
# 이전 버전 흔적
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$C\QuickUnzip.zip"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$C\Applications\QuickUnzip.exe", 'HKCU:\Software\QuickUnzip', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\QuickUnzip.exe'
Remove-ItemProperty -ErrorAction SilentlyContinue 'HKCU:\Software\RegisteredApplications' -Name 'QuickUnzip'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $env:LOCALAPPDATA 'QuickUnzip')
if (Test-Path 'HKLM:\SOFTWARE\QuickUnzip') {
    $cmd = "Remove-Item -Recurse -Force 'HKLM:\SOFTWARE\QuickUnzip'; Remove-ItemProperty 'HKLM:\SOFTWARE\RegisteredApplications' -Name 'QuickUnzip' -ErrorAction SilentlyContinue; " +
           "Get-ChildItem 'HKLM:\SOFTWARE\Classes' -Name | Where-Object { `$_ -like 'QuickUnzip.*' } | ForEach-Object { Remove-Item -Recurse -Force (Join-Path 'HKLM:\SOFTWARE\Classes' `$_) }"
    try { Start-Process powershell.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile -Command $cmd" } catch {}
}
Write-Host '제거 완료'
