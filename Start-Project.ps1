$ErrorActionPreference = "Stop"

$projectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDirectory = Join-Path $projectDirectory "logs"
$url = "http://127.0.0.1:3000"
$stdoutLog = Join-Path $logDirectory "dev-server.out.log"
$stderrLog = Join-Path $logDirectory "dev-server.err.log"
$installLog = Join-Path $logDirectory "install.log"
$launcherLog = Join-Path $logDirectory "launcher.log"
$databaseDirectory = Join-Path $projectDirectory "database"
$databaseComposeFile = Join-Path $databaseDirectory "compose.yaml"
$apiDirectory = Join-Path $projectDirectory "apps\api"
$apiUrl = "http://127.0.0.1:4000/api/v1/health/ready"

function Show-StartError([string]$message) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "PanizStyle",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    catch {
        # Keep the launcher silent if a Windows message box is unavailable.
    }
}

function Test-PanizStyleReady {
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 2 -UseBasicParsing
        return ($response.StatusCode -eq 200 -and $response.Content.Contains("PanizStyle"))
    }
    catch {
        return $false
    }
}

function Test-PanizApiReady {
    try {
        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 2 -UseBasicParsing
        return ($response.StatusCode -eq 200 -and $response.Content.Contains('"database":"connected"'))
    }
    catch {
        return $false
    }
}

function Test-PanizCustomerApi {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:4000/api/v1/customer/auth/me" -Method Get -TimeoutSec 2 -UseBasicParsing
        return ($response.StatusCode -eq 200)
    }
    catch {
        if ($_.Exception.Response) {
            return ([int]$_.Exception.Response.StatusCode -eq 401)
        }
        return $false
    }
}

function Test-PanizAdminCredentialsApi {
    try {
        Invoke-WebRequest `
            -Uri "http://127.0.0.1:4000/api/v1/admin/auth/credentials" `
            -Method Patch `
            -Body "{}" `
            -ContentType "application/json" `
            -TimeoutSec 2 `
            -UseBasicParsing | Out-Null
        return $false
    }
    catch {
        if ($_.Exception.Response) {
            return ([int]$_.Exception.Response.StatusCode -eq 401)
        }
        return $false
    }
}

function Invoke-LoggedCommand([string]$commandPath, [string[]]$arguments, [string]$workingDirectory, [string]$logPath) {
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $commandPath
    $processInfo.WorkingDirectory = $workingDirectory
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $quotedArguments = foreach ($argument in $arguments) {
        '"' + $argument.Replace('"', '\"') + '"'
    }
    $processInfo.Arguments = $quotedArguments -join ' '

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()

    $logContents = New-Object System.Text.StringBuilder
    if ($stdoutTask.Result) {
        [void]$logContents.AppendLine($stdoutTask.Result.TrimEnd())
    }
    if ($stderrTask.Result) {
        [void]$logContents.AppendLine($stderrTask.Result.TrimEnd())
    }
    [System.IO.File]::WriteAllText($logPath, $logContents.ToString(), [System.Text.Encoding]::UTF8)
    return $process.ExitCode
}

function Open-InChrome {
    $chromeCandidates = @()
    if ($env:ProgramFiles) {
        $chromeCandidates += Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"
    }
    if (${env:ProgramFiles(x86)}) {
        $chromeCandidates += Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"
    }
    if ($env:LOCALAPPDATA) {
        $chromeCandidates += Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"
    }

    $chromePath = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($chromePath) {
        Start-Process -FilePath $chromePath -ArgumentList $url | Out-Null
    }
    else {
        Start-Process -FilePath $url | Out-Null
    }
}

try {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

    $dockerCommand = Get-Command docker.exe -ErrorAction SilentlyContinue
    if (-not $dockerCommand) {
        Show-StartError "Docker Desktop is required to start PanizStyle's database. Install or open Docker Desktop, then run Start.bat again."
        exit 1
    }

    $dockerLog = Join-Path $logDirectory "database-start.log"
    $dockerExitCode = Invoke-LoggedCommand $dockerCommand.Source @(
        "compose", "--project-directory", $databaseDirectory, "-f", $databaseComposeFile, "up", "-d"
    ) $projectDirectory $dockerLog
    if ($dockerExitCode -ne 0) {
        Show-StartError "The database did not start. Open Docker Desktop and see logs\database-start.log for details."
        exit 1
    }

    $databaseReady = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        $databaseHealth = & $dockerCommand.Source inspect --format "{{.State.Health.Status}}" panizstyle-mysql 2>$null
        if ($databaseHealth -eq "healthy") {
            $databaseReady = $true
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $databaseReady) {
        Show-StartError "The database did not become ready. See logs\database-start.log and Docker Desktop for details."
        exit 1
    }

    $apiNpmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $apiNpmCommand) {
        Show-StartError "Node.js and npm are required to start PanizStyle. Install Node.js, then run Start.bat again."
        exit 1
    }

    if (-not (Test-Path -LiteralPath (Join-Path $apiDirectory "node_modules\prisma\build\index.js")) -or
        -not (Test-Path -LiteralPath (Join-Path $apiDirectory "node_modules\argon2\package.json"))) {
        $apiInstallLog = Join-Path $logDirectory "api-install.log"
        $apiInstallCode = Invoke-LoggedCommand $apiNpmCommand.Source @("install") $apiDirectory $apiInstallLog
        if ($apiInstallCode -ne 0) {
            Show-StartError "API setup did not finish. See logs\api-install.log for details."
            exit 1
        }
    }

    $apiSchema = Join-Path $apiDirectory "prisma\schema.prisma"
    $generatedClientMarker = Join-Path $apiDirectory "node_modules\.prisma\client\index.d.ts"
    if ((Test-Path -LiteralPath $apiSchema) -and (
        -not (Test-Path -LiteralPath $generatedClientMarker) -or
        (Get-Item -LiteralPath $apiSchema).LastWriteTimeUtc -gt (Get-Item -LiteralPath $generatedClientMarker).LastWriteTimeUtc
    )) {
        $generateCode = Invoke-LoggedCommand $apiNpmCommand.Source @("run", "prisma:generate") $apiDirectory (Join-Path $logDirectory "api-generate.log")
        if ($generateCode -ne 0) {
            Show-StartError "The API database client could not be generated. See logs\api-generate.log for details."
            exit 1
        }
    }

    $apiEntry = Join-Path $apiDirectory "dist\main.js"
    $apiSourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $apiDirectory "src") -Filter "*.ts" -Recurse -File)
    $apiNeedsBuild = -not (Test-Path -LiteralPath $apiEntry)
    if (-not $apiNeedsBuild -and $apiSourceFiles.Count -gt 0) {
        $latestSourceUtc = ($apiSourceFiles | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
        $apiNeedsBuild = $latestSourceUtc -gt (Get-Item -LiteralPath $apiEntry).LastWriteTimeUtc
    }
    if (-not $apiNeedsBuild -and (Test-Path -LiteralPath $apiSchema)) {
        $apiNeedsBuild = (Get-Item -LiteralPath $apiSchema).LastWriteTimeUtc -gt (Get-Item -LiteralPath $apiEntry).LastWriteTimeUtc
    }
    if ($apiNeedsBuild) {
        $apiBuildCode = Invoke-LoggedCommand $apiNpmCommand.Source @("run", "build") $apiDirectory (Join-Path $logDirectory "api-build.log")
        if ($apiBuildCode -ne 0) {
            Show-StartError "The API could not be built. See logs\api-build.log for details."
            exit 1
        }
    }

    $migrationCode = Invoke-LoggedCommand $apiNpmCommand.Source @("run", "prisma:migrate:deploy") $apiDirectory (Join-Path $logDirectory "migration.log")
    if ($migrationCode -ne 0) {
        Show-StartError "The database migration failed. See logs\migration.log for details."
        exit 1
    }

    $seedCode = Invoke-LoggedCommand $apiNpmCommand.Source @("run", "prisma:seed") $apiDirectory (Join-Path $logDirectory "seed.log")
    if ($seedCode -ne 0) {
        Show-StartError "The sample catalog could not be prepared. See logs\seed.log for details."
        exit 1
    }

    $apiAlreadyReady = Test-PanizApiReady
    if ($apiAlreadyReady -and (-not (Test-PanizCustomerApi) -or -not (Test-PanizAdminCredentialsApi))) {
        $apiProcessId = (Get-NetTCPConnection -LocalPort 4000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess
        $processHint = if ($apiProcessId) { " End node.exe PID $apiProcessId in Task Manager, then run Start.bat again." } else { " Restart the API, then run Start.bat again." }
        Show-StartError ("An older PanizStyle API is running on port 4000 and does not include the latest customer or admin security routes." + $processHint)
        exit 1
    }

    if (-not $apiAlreadyReady) {
        $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
        if (-not $nodeCommand) {
            Show-StartError "Node.js was not found. Install Node.js, then run Start.bat again."
            exit 1
        }

        $apiOutLog = Join-Path $logDirectory "api-server.out.log"
        $apiErrLog = Join-Path $logDirectory "api-server.err.log"
        Start-Process `
            -FilePath $nodeCommand.Source `
            -ArgumentList "dist/main.js" `
            -WorkingDirectory $apiDirectory `
            -RedirectStandardOutput $apiOutLog `
            -RedirectStandardError $apiErrLog `
            -WindowStyle Hidden | Out-Null

        $apiReady = $false
        for ($attempt = 0; $attempt -lt 45; $attempt++) {
            Start-Sleep -Seconds 1
            if ((Test-PanizApiReady) -and (Test-PanizCustomerApi) -and (Test-PanizAdminCredentialsApi)) {
                $apiReady = $true
                break
            }
        }
        if (-not $apiReady) {
            Show-StartError "The PanizStyle API did not start. See logs\api-server.err.log for details."
            exit 1
        }
    }

    if (Test-PanizStyleReady) {
        "PanizStyle started successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." | Set-Content -LiteralPath $launcherLog -Encoding UTF8
        Open-InChrome
        exit 0
    }

    $nextCli = Join-Path $projectDirectory "node_modules\next\dist\bin\next"
    if (-not (Test-Path -LiteralPath $nextCli)) {
        $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if (-not $npmCommand) {
            Show-StartError "Node.js and npm are required. Install Node.js, then run Start.bat again."
            exit 1
        }

        Set-Location -LiteralPath $projectDirectory
        & $npmCommand.Source install *> $installLog
        if ($LASTEXITCODE -ne 0) {
            Show-StartError "Project setup did not finish. See logs\install.log for details."
            exit 1
        }
    }

    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $nodeCommand) {
        Show-StartError "Node.js was not found. Install Node.js, then run Start.bat again."
        exit 1
    }

    $serverArguments = '"' + $nextCli + '" dev --hostname 127.0.0.1 --port 3000'
    $serverProcess = Start-Process `
        -FilePath $nodeCommand.Source `
        -ArgumentList $serverArguments `
        -WorkingDirectory $projectDirectory `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -WindowStyle Hidden `
        -PassThru

    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 1
        if (Test-PanizStyleReady) {
            $ready = $true
            break
        }
        if ($serverProcess.HasExited) {
            break
        }
    }

    if ($ready) {
        "PanizStyle started successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." | Set-Content -LiteralPath $launcherLog -Encoding UTF8
        Open-InChrome
        exit 0
    }

    Show-StartError "PanizStyle did not start. See logs\dev-server.err.log and logs\dev-server.out.log for details."
    exit 1
}
catch {
    try {
        $_ | Out-String | Add-Content -LiteralPath $launcherLog -Encoding UTF8
    }
    catch {
        # Preserve the original launcher error if logging is unavailable.
    }
    Show-StartError "Could not start PanizStyle. See the logs folder for details."
    exit 1
}
