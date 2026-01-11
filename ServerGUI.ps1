# ServerGUI.ps1
# Run: powershell -ExecutionPolicy Bypass -File .\ServerGUI.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----------------------------
# CONFIG (edit these)
# ----------------------------
$RepoDir     = $PSScriptRoot
$GitExe      = "git"

$JavaExe     = "java"  # or full path to java.exe
$ServerJar   = Join-Path $RepoDir "minecraft_server.1.21.10.jar"
$MaxMemory   = "8G"

$PlayitExe   = Join-Path $RepoDir "playit.exe"

# Optional: args like "--nogui"
$ServerArgs  = @()

# ----------------------------
# GUI
# ----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Minecraft Server Manager"
$form.Size = New-Object System.Drawing.Size(980, 650)
$form.StartPosition = "CenterScreen"

$btnPull = New-Object System.Windows.Forms.Button
$btnPull.Text = "Pull (rebase)"
$btnPull.Location = New-Object System.Drawing.Point(20, 20)
$btnPull.Size = New-Object System.Drawing.Size(140, 35)

$btnPush = New-Object System.Windows.Forms.Button
$btnPush.Text = "Commit + Push"
$btnPush.Location = New-Object System.Drawing.Point(175, 20)
$btnPush.Size = New-Object System.Drawing.Size(140, 35)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Server"
$btnStart.Location = New-Object System.Drawing.Point(330, 20)
$btnStart.Size = New-Object System.Drawing.Size(140, 35)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop Server"
$btnStop.Location = New-Object System.Drawing.Point(485, 20)
$btnStop.Size = New-Object System.Drawing.Size(140, 35)
$btnStop.Enabled = $false

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Output"
$btnClear.Location = New-Object System.Drawing.Point(640, 20)
$btnClear.Size = New-Object System.Drawing.Size(140, 35)

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = New-Object System.Drawing.Point(20, 70)
$txtOut.Size = New-Object System.Drawing.Size(920, 520)
$txtOut.Multiline = $true
$txtOut.ScrollBars = "Vertical"
$txtOut.ReadOnly = $true
$txtOut.Font = New-Object System.Drawing.Font("Consolas", 10)

$txtCmd = New-Object System.Windows.Forms.TextBox
$txtCmd.Location = New-Object System.Drawing.Point(20, 600)
$txtCmd.Size = New-Object System.Drawing.Size(800, 24)
$txtCmd.Font = New-Object System.Drawing.Font("Consolas", 10)

$btnSend = New-Object System.Windows.Forms.Button
$btnSend.Text = "Send"
$btnSend.Location = New-Object System.Drawing.Point(840, 596)
$btnSend.Size = New-Object System.Drawing.Size(100, 30)

$form.Controls.AddRange(@($btnPull, $btnPush, $btnStart, $btnStop, $btnClear, $txtOut, $txtCmd, $btnSend))

function Invoke-UI([scriptblock]$action) {
    try {
        if ($form -and $form.IsHandleCreated) {
            $form.BeginInvoke([Action]$action) | Out-Null
        } else {
            & $action
        }
    } catch {
        & $action
    }
}

function Wait-ProcessPump([System.Diagnostics.Process]$p) {
    try {
        while (-not $p.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }
    } catch {}
}

function Run-LoggedProcessAndOnExit {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [scriptblock]$OnExit,
        [switch]$KeepStdin
    )

    $proc = Start-LoggedProcess -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $WorkingDirectory -KeepStdin:$KeepStdin
    if ($proc.HasExited) {
        try { if ($OnExit) { & $OnExit $proc } } catch {}
    } else {
        try {
            $null = Register-ObjectEvent -InputObject $proc -EventName Exited -Action {
                try { if ($OnExit) { & $OnExit $Event.Sender } } catch {}
            }
        } catch {
            # Fallback: if registration failed, poll once
            Start-Sleep -Milliseconds 50
            try { if ($OnExit) { & $OnExit $proc } } catch {}
        }
    }
    return $proc
}

function Send-ServerCommand([string]$cmd) {
    $cmd = ($cmd | ForEach-Object { $_ })
    if ($null -eq $cmd) { return }
    $cmd = $cmd.Trim()
    if ([string]::IsNullOrWhiteSpace($cmd)) { return }

    if (-not $global:ServerProc -or $global:ServerProc.HasExited) {
        Write-Log "Server is not running."
        return
    }

    try {
        $global:ServerProc.StandardInput.WriteLine($cmd)
        $global:ServerProc.StandardInput.Flush()
        Write-Log ("CMD> " + $cmd)
        Invoke-UI { $txtCmd.Clear() }
    } catch {
        Write-Log "ERR: Could not send command to server stdin."
    }
}

function Write-Log([string]$line) {
    $ts = (Get-Date).ToString("HH:mm:ss")
    $msg = "[$ts] $line"

    $write = {
        $txtOut.AppendText($msg + "`r`n")
        $txtOut.SelectionStart = $txtOut.TextLength
        $txtOut.ScrollToCaret()
    }

    try {
        if ($txtOut -and $txtOut.IsHandleCreated) {
            if ($txtOut.InvokeRequired) {
                $null = $txtOut.BeginInvoke([Action]$write)
            } else {
                & $write
            }
        } else {
            Write-Host $msg
        }
    } catch {
        Write-Host $msg
    }
}

# ----------------------------
# Process runner that streams output to the textbox
# ----------------------------
function Start-LoggedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [switch]$KeepStdin,
        [switch]$StdErrAsInfo
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($Arguments -join " ")
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    if ($KeepStdin) { $psi.RedirectStandardInput = $true }

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $p.EnableRaisingEvents = $true
    try { $p.SynchronizingObject = $form } catch {}

    $handlerOut = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $e)
        if ($e.Data) { Write-Log $e.Data }
    }
    $handlerErr = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $e)
        if ($e.Data) {
            if ($StdErrAsInfo) {
                Write-Log $e.Data
            } else {
                Write-Log ("ERR: " + $e.Data)
            }
        }
    }

    $null = $p.add_OutputDataReceived($handlerOut)
    $null = $p.add_ErrorDataReceived($handlerErr)

    Write-Log ("RUN: " + $FilePath + " " + ($psi.Arguments))
    $null = $p.Start()
    $p.BeginOutputReadLine()
    $p.BeginErrorReadLine()

    return $p
}

# ----------------------------
# Managed processes
# ----------------------------
$global:ServerProc = $null
$global:PlayitProc = $null

function Ensure-Repo {
    if (-not (Test-Path $RepoDir)) { throw "RepoDir not found: $RepoDir" }
    try {
        $null = Get-Command $GitExe -ErrorAction Stop
    } catch {
        throw "Git not found: $GitExe"
    }
}

function Do-Pull {
    Ensure-Repo
    Write-Log "=== PULL (rebase) ==="
    Invoke-UI { $btnPull.Enabled = $false }
    $p = Start-LoggedProcess -FilePath $GitExe -Arguments @("pull","--rebase") -WorkingDirectory $RepoDir -StdErrAsInfo
    Wait-ProcessPump $p
    Write-Log ("Pull exit code: " + $p.ExitCode)
    Invoke-UI { $btnPull.Enabled = $true }
}

function Do-Push {
    Ensure-Repo
    Write-Log "=== COMMIT + PUSH ==="
    Invoke-UI { $btnPush.Enabled = $false }

    # Add like push_world.bat (use '.' rather than -A)
    $p1 = Start-LoggedProcess -FilePath $GitExe -Arguments @("add", ".") -WorkingDirectory $RepoDir -StdErrAsInfo
    Wait-ProcessPump $p1
    Write-Log ("Add exit code: " + $p1.ExitCode)

    # Commit
    $p2 = Start-LoggedProcess -FilePath $GitExe -Arguments @("commit", "-m", '"World update"') -WorkingDirectory $RepoDir -StdErrAsInfo
    Wait-ProcessPump $p2
    Write-Log ("Commit exit code: " + $p2.ExitCode)

    # Push
    $p3 = Start-LoggedProcess -FilePath $GitExe -Arguments @("push") -WorkingDirectory $RepoDir -StdErrAsInfo
    Wait-ProcessPump $p3
    Write-Log ("Push exit code: " + $p3.ExitCode)
    Invoke-UI { $btnPush.Enabled = $true }
}

function Start-Playit {
    if ($global:PlayitProc -and -not $global:PlayitProc.HasExited) {
        Write-Log "playit already running."
        return
    }
    if (-not (Test-Path $PlayitExe)) { throw "playit.exe not found: $PlayitExe" }
    Write-Log "Starting playit..."
    $global:PlayitProc = Start-LoggedProcess -FilePath $PlayitExe -Arguments @() -WorkingDirectory $RepoDir
}

function Stop-Playit {
    if ($global:PlayitProc -and -not $global:PlayitProc.HasExited) {
        Write-Log "Stopping playit..."
        try { $global:PlayitProc.Kill() } catch {}
    }
    $global:PlayitProc = $null
}

function Start-Server {
    if ($global:ServerProc -and -not $global:ServerProc.HasExited) {
        Write-Log "Server already running."
        return
    }
    if (-not (Test-Path $ServerJar)) { throw "Server jar not found: $ServerJar" }

    Write-Log "Starting server..."
    Start-Playit

    # Run java directly so we can send "stop" on shutdown
    $args = @("-Xmx$MaxMemory","-jar","""$ServerJar""" ) + $ServerArgs
    $global:ServerProc = Start-LoggedProcess -FilePath $JavaExe -Arguments $args -WorkingDirectory $RepoDir -KeepStdin

    $btnStart.Enabled = $false
    $btnStop.Enabled  = $true
}

function Stop-Server {
    if (-not $global:ServerProc -or $global:ServerProc.HasExited) {
        Write-Log "Server is not running."
        Stop-Playit
        $btnStart.Enabled = $true
        $btnStop.Enabled  = $false
        return
    }

    Write-Log "Stopping server (sending 'stop')..."
    try {
        $global:ServerProc.StandardInput.WriteLine("stop")
        $global:ServerProc.StandardInput.Flush()
    } catch {
        Write-Log "Could not write to stdin; will kill process."
    }

    # Wait a bit; then force kill if needed
    Start-Sleep -Seconds 6
    if (-not $global:ServerProc.HasExited) {
        Write-Log "Server did not exit; killing..."
        try { $global:ServerProc.Kill() } catch {}
    }

    $global:ServerProc = $null
    Stop-Playit

    $btnStart.Enabled = $true
    $btnStop.Enabled  = $false
    Write-Log "Server stopped."
}

# ----------------------------
# Button handlers
# ----------------------------
$btnClear.Add_Click({ $txtOut.Clear() })

$btnPull.Add_Click({
    try { Do-Pull } catch { Write-Log ("ERR: " + $_.Exception.Message) }
})

$btnPush.Add_Click({
    try { Do-Push } catch { Write-Log ("ERR: " + $_.Exception.Message) }
})

$btnStart.Add_Click({
    try { Start-Server } catch { Write-Log ("ERR: " + $_.Exception.Message) }
})

$btnStop.Add_Click({
    try { Stop-Server } catch { Write-Log ("ERR: " + $_.Exception.Message) }
})

$btnSend.Add_Click({
    try { Send-ServerCommand $txtCmd.Text } catch { Write-Log ("ERR: " + $_.Exception.Message) }
})

$txtCmd.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $e.SuppressKeyPress = $true
        try { Send-ServerCommand $txtCmd.Text } catch { Write-Log ("ERR: " + $_.Exception.Message) }
    }
})

# Clean up on close
$form.Add_FormClosing({
    try { Stop-Server } catch {}
})

$form.Add_Shown({
    Write-Log "Ready. RepoDir=$RepoDir"
})
[void]$form.ShowDialog()
