# QuickUnzip 설치 (현재 사용자만, 관리자 권한 불필요)
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'QuickUnzip'
# exe가 없으면 Windows 내장 C# 컴파일러로 빌드
if (-not (Test-Path (Join-Path $PSScriptRoot 'QuickUnzip.exe'))) {
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /codepage:65001 `
        "/win32icon:$PSScriptRoot\icons\QuickUnzip.ico" "/out:$PSScriptRoot\QuickUnzip.exe" /r:System.Windows.Forms.dll "$PSScriptRoot\QuickUnzip.cs"
    if ($LASTEXITCODE -ne 0) { throw 'QuickUnzip.exe 빌드 실패' }
}
New-Item -ItemType Directory -Force "$dest\icons" | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'QuickUnzip.exe'), (Join-Path $PSScriptRoot 'QuickUnzip.ps1') $dest
Copy-Item -Force (Join-Path $PSScriptRoot 'icons\*.ico') "$dest\icons"
$exe = "$dest\QuickUnzip.exe"
$cmd = "`"$exe`" `"%1`""

# 확장자 → 아이콘
$types = [ordered]@{
    '.zip'='ZIP'; '.7z'='7Z'; '.rar'='RAR'; '.tar'='TAR'
    '.gz'='GZ'; '.tgz'='TGZ'; '.bz2'='BZ2'; '.tbz'='BZ2'; '.tbz2'='BZ2'
    '.xz'='XZ'; '.txz'='XZ'; '.zst'='ZST'; '.tzst'='ZST'
    '.cab'='CAB'; '.iso'='ISO'; '.lzh'='LZH'; '.lha'='LZH'; '.jar'='JAR'
}

function Set-Default($path, $value) { New-Item -Force $path | Out-Null; Set-ItemProperty -LiteralPath $path '(default)' $value }
$C = 'HKCU:\Software\Classes'

# 앱 등록 (연결 프로그램 목록 / 설정 > 기본 앱 에 표시)
Set-Default "$C\Applications\QuickUnzip.exe\shell\open\command" $cmd
Set-ItemProperty "$C\Applications\QuickUnzip.exe" 'FriendlyAppName' 'QuickUnzip'
New-Item -Force "$C\Applications\QuickUnzip.exe\SupportedTypes" | Out-Null
$cap = 'HKCU:\Software\QuickUnzip\Capabilities'
New-Item -Force "$cap\FileAssociations" | Out-Null
Set-ItemProperty $cap 'ApplicationName' 'QuickUnzip'
Set-ItemProperty $cap 'ApplicationDescription' '더블클릭하면 압축 파일을 바로 풉니다'
Set-ItemProperty $cap 'ApplicationIcon' "$exe,0"
Set-Default 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\QuickUnzip.exe' $exe
New-Item -Force 'HKCU:\Software\RegisteredApplications' | Out-Null
Set-ItemProperty 'HKCU:\Software\RegisteredApplications' 'QuickUnzip' 'Software\QuickUnzip\Capabilities'

foreach ($ext in $types.Keys) {
    $prog = "QuickUnzip$ext"
    $icon = "$dest\icons\$($types[$ext]).ico"
    Set-Default "$C\$prog" "$($types[$ext]) 압축 파일"
    Set-ItemProperty "$C\$prog" 'FriendlyTypeName' "$($types[$ext]) 압축 파일"
    Set-Default "$C\$prog\DefaultIcon" $icon
    Set-Default "$C\$prog\shell\open" '바로 풀기'
    Set-Default "$C\$prog\shell\open\command" $cmd
    New-Item -Force "$C\$ext\OpenWithProgids" | Out-Null
    New-ItemProperty -Force "$C\$ext\OpenWithProgids" -Name $prog -Value '' | Out-Null
    New-ItemProperty -Force "$C\Applications\QuickUnzip.exe\SupportedTypes" -Name $ext -Value '' | Out-Null
    Set-ItemProperty "$cap\FileAssociations" $ext $prog
    # 우클릭 메뉴
    $ctx = "$C\SystemFileAssociations\$ext\shell\QuickUnzip"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $ctx
    if ($ext -in '.zip', '.jar') {
        # 파일 이름 인코딩을 고르는 하위 메뉴
        New-Item -Force $ctx | Out-Null
        Set-ItemProperty $ctx 'MUIVerb' 'QuickUnzip으로 풀기'
        Set-ItemProperty $ctx 'SubCommands' ''
        Set-ItemProperty $ctx 'Icon' "$dest\icons\QuickUnzip.ico"
        $i = 0
        foreach ($m in @(@('auto','자동 감지'), @('utf8','UTF-8 (Mac/Linux)'), @('cp949','한국어 (CP949/EUC-KR)'),
                         @('cp932','일본어 (Shift-JIS)'), @('cp936','중국어 간체 (GBK)'))) {
            $sub = "$ctx\shell\{0:D2}_{1}" -f $i++, $m[0]
            New-Item -Force $sub | Out-Null
            Set-ItemProperty $sub 'MUIVerb' $m[1]
            Set-Default "$sub\command" "`"$exe`" --enc=$($m[0]) `"%1`""
        }
    } else {
        Set-Default $ctx '여기에 바로 풀기'
        Set-ItemProperty $ctx 'Icon' "$dest\icons\QuickUnzip.ico"
        Set-Default "$ctx\command" $cmd
    }
}

# 설정 > 기본 앱 목록은 HKLM\SOFTWARE\RegisteredApplications 에 등록된 앱만 보여줌 (HKCU 등록은 무시됨)
# → 이 부분만 관리자 권한으로 한 번 등록
$assoc = ($types.Keys | ForEach-Object { "Set-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\QuickUnzip\Capabilities\FileAssociations' -Name '$_' -Value 'QuickUnzip$_'" }) -join '; '
$elev = @"
New-Item -Force 'HKLM:\SOFTWARE\QuickUnzip\Capabilities\FileAssociations' | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\QuickUnzip\Capabilities' 'ApplicationName' 'QuickUnzip'
Set-ItemProperty 'HKLM:\SOFTWARE\QuickUnzip\Capabilities' 'ApplicationDescription' 'Extract archives on double-click'
Set-ItemProperty 'HKLM:\SOFTWARE\QuickUnzip\Capabilities' 'ApplicationIcon' '$exe,0'
$assoc
Set-ItemProperty 'HKLM:\SOFTWARE\RegisteredApplications' 'QuickUnzip' 'SOFTWARE\QuickUnzip\Capabilities'
"@
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($elev))
try {
    $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList "-NoProfile -EncodedCommand $enc"
    if ($p.ExitCode -ne 0) { throw "exit $($p.ExitCode)" }
    # 사용자 단위 중복 등록 제거
    Remove-ItemProperty -ErrorAction SilentlyContinue 'HKCU:\Software\RegisteredApplications' -Name 'QuickUnzip'
} catch {
    Write-Warning "관리자 권한 등록을 건너뛰었습니다. 설정 > 기본 앱 목록에는 안 보이지만, 우클릭 > 연결 프로그램 에서는 선택할 수 있습니다."
}

# 탐색기 아이콘 새로고침
Add-Type -Namespace Win32 -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int e, int f, IntPtr a, IntPtr b);'
[Win32.Shell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)

Write-Host "설치 완료: $exe"
# 기본 앱 지정 여부 묻기
# Windows는 프로그램이 기본 앱을 직접 바꾸지 못하게 막으므로, 설정 화면을 열어 사용자가 한 번 누르게 합니다
Add-Type -AssemblyName System.Windows.Forms
$ans = [Windows.Forms.MessageBox]::Show(
    "QuickUnzip을 압축 파일의 기본 앱으로 지정할까요?`n`n'예'를 누르면 설정 화면이 열립니다.`n맨 위의 [기본값으로 설정] 버튼을 한 번 누르면 모든 형식이 지정됩니다.`n(버튼이 없으면 형식별로 QuickUnzip을 선택하세요.)",
    'QuickUnzip 설치', 'YesNo', 'Question')
if ($ans -eq 'Yes') {
    # 이미 열린 설정 앱은 앱 목록을 캐시하므로 닫고 새로 엽니다
    Get-Process SystemSettings -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    Start-Process 'ms-settings:defaultapps?registeredAppUser=QuickUnzip'
} else {
    Write-Host "나중에 설정 > 앱 > 기본 앱 > QuickUnzip 에서 지정할 수 있습니다."
}
