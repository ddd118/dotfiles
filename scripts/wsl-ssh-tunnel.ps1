$WslUser = "zanth"
$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"   # 必要なら変更
$LocalPort = 2222
$RemoteHost = "127.0.0.1"
$RemotePort = 22

while ($true) {
    try {
        # WSL の eth0 の IPv4 を取得（WSL2の実体側IP）
        $wslIp = (wsl.exe -e hostname -I).Trim()

        if ([string]::IsNullOrWhiteSpace($wslIp)) {
            Start-Sleep -Seconds 3
            continue
        }

        $args = @(
            "-N",
            "-i", $KeyPath,
            "-L", "0.0.0.0:${LocalPort}:${RemoteHost}:${RemotePort}",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-o", "BatchMode=yes",
            "$WslUser@$wslIp"
        )

        # ssh が落ちるまで待つ（落ちたらループで再接続）
        & ssh.exe @args
    }
    catch {
        # 何かあっても再試行
    }

    Start-Sleep -Seconds 3
}
