# Downloads に落ちた .patch を WSL(Ubuntu) の /path/to/target/.patch に移動する
# - ダウンロード中ファイル(.crdownload/.tmp/.part)は無視
# - ファイルサイズが安定 + 読み取りで開けることを確認してから実行（破損防止）
# - 同名が既にWSL側にあれば何もしない（= Downloadsに残るのは許容）
# - 同名の再ダウンロードにも対応（ProcessedFilesを掃除する）

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Distro     = "Ubuntu"
$Downloads  = Join-Path $env:USERPROFILE "Downloads"
$AllowedExt = @(".patch")
$IgnoreExt  = @(".crdownload", ".tmp", ".part")

# これを消してもOK（ログ抑制用）
$ProcessedFiles = @{}

function Invoke-Wsl {
  param(
    [Parameter(Mandatory)]
    [string[]]$Args
  )
  $out = & wsl.exe -d $Distro -- @Args 2>&1
  $exit = $LASTEXITCODE
  [pscustomobject]@{
    ExitCode = $exit
    Text     = (($out | ForEach-Object { $_ }) -join "`n")
  }
}

function Wait-FileStable {
  param(
    [Parameter(Mandatory)]
    [string]$Path,
    [int]$Checks = 2,
    [int]$IntervalMs = 400,
    [int]$MaxLoops = 40
  )

  $lastSize = -1
  $stableCount = 0

  for ($i = 0; $i -lt $MaxLoops; $i++) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    try {
      $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
      $size = $fi.Length

      # ロック/書き込み中対策：読み取りで開けることを確認
      $fs = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
      )
      $fs.Close()
    } catch {
      Start-Sleep -Milliseconds $IntervalMs
      continue
    }

    if ($size -eq $lastSize) {
      $stableCount++
      if ($stableCount -ge $Checks) { return $true }
    } else {
      $stableCount = 0
      $lastSize = $size
    }

    Start-Sleep -Milliseconds $IntervalMs
  }

  return $false
}

# WSLのHOMEを一度だけ取得して、以降は絶対パスで扱う（$HOME展開を毎回やらない）
$homeRes = Invoke-Wsl @("bash", "-c", 'printf "%s" "$HOME"')
if ($homeRes.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($homeRes.Text)) {
  throw "Failed to get WSL HOME. Exit=$($homeRes.ExitCode) Output=$($homeRes.Text)"
}
$LinuxHome = $homeRes.Text.Trim()
$TargetLinuxDir = "$LinuxHome/repos/work/tdx/.patch"

# 念のため作成（ここで失敗するなら権限やWSL側の状態）
$mkRes = Invoke-Wsl @("mkdir", "-p", $TargetLinuxDir)
if ($mkRes.ExitCode -ne 0) {
  throw "Failed to mkdir target dir: $TargetLinuxDir. Output=`n$($mkRes.Text)"
}

function Get-LinuxPathFromWindowsPath {
  param([Parameter(Mandatory)][string]$WinPath)

  # wslpathが使えるならそれが最強
  $r = Invoke-Wsl @("wslpath", "-a", $WinPath)
  if ($r.ExitCode -eq 0) {
    $p = $r.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($p)) { return $p }
  }

  # フォールバック（C:\... → /mnt/c/...）
  $p2 = $WinPath.Replace('\','/')
  if ($p2 -match '^([A-Za-z]):/(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $rest  = $Matches[2]
    return "/mnt/$drive/$rest"
  }

  return $null
}

function Move-FileToWSL {
  param([Parameter(Mandatory)][string]$FilePath)

  $ext = [IO.Path]::GetExtension($FilePath).ToLowerInvariant()
  if ($IgnoreExt -contains $ext) { return $false }
  if ($AllowedExt -notcontains $ext) { return $false }
  if (-not (Wait-FileStable -Path $FilePath)) { return $false }
  if (-not (Test-Path -LiteralPath $FilePath)) { return $false }

  $fileName = Split-Path -Leaf $FilePath

  $srcLinux = Get-LinuxPathFromWindowsPath -WinPath $FilePath
  if ([string]::IsNullOrWhiteSpace($srcLinux)) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] NG Could not convert path: $FilePath" -ForegroundColor Red
    return $false
  }

  $destLinux = "$TargetLinuxDir/$fileName"

  # 既に存在するなら何もしない（成功扱い）
  $testRes = Invoke-Wsl @("test", "-e", $destLinux)
  if ($testRes.ExitCode -eq 0) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] SKIP Exists: $fileName" -ForegroundColor Yellow
    return $true
  } elseif ($testRes.ExitCode -ne 1) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] NG test failed: $fileName`n$($testRes.Text)" -ForegroundColor Red
    return $false
  }

  # mv（上書きしない）
  $mvRes = Invoke-Wsl @("mv", "-n", $srcLinux, $destLinux)
  if ($mvRes.ExitCode -ne 0) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] NG mv failed: $fileName`n$($mvRes.Text)" -ForegroundColor Red
    return $false
  }

  # 念のため：Windows側にまだ残っているなら「移動されてない」扱い（稀な競合用）
  if (Test-Path -LiteralPath $FilePath) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] SKIP Not moved (maybe exists): $fileName" -ForegroundColor Yellow
    return $true
  }

  Write-Host "[$(Get-Date -Format 'HH:mm:ss')] OK Moved: $fileName" -ForegroundColor Green
  return $true
}

Write-Host "Watching Downloads folder..."
Write-Host "Target: WSL($Distro) -> $TargetLinuxDir"
Write-Host "Extensions: $(($AllowedExt -join ', '))"
Write-Host "Press Ctrl+C to stop.`n"

try {
  while ($true) {

    # ★重要：Downloadsから消えたキーは掃除する（同名再DLを阻害しない）
    foreach ($k in @($ProcessedFiles.Keys)) {
      if (-not (Test-Path -LiteralPath $k)) {
        [void]$ProcessedFiles.Remove($k)
      }
    }

    Get-ChildItem -Path $Downloads -File -Filter *.patch -ErrorAction SilentlyContinue | ForEach-Object {
      $key = $_.FullName
      if (-not $ProcessedFiles.ContainsKey($key)) {
        $ok = Move-FileToWSL -FilePath $key
        if ($ok) {
          $ProcessedFiles[$key] = $true
        }
      }
    }

    Start-Sleep -Seconds 2
  }
} finally {
  Write-Host "`nStopped."
}
