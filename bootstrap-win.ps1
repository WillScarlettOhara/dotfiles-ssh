# ══════════════════════════════════════════════════════════════════════════════
#  bootstrap-win.ps1 — Ready-to-work Windows 11 dev environment
#  Inspired by https://github.com/WillScarlettOhara/dotfiles-ssh/blob/main/bootstrap-ssh.sh
#
#  Usage (from PowerShell, any version >=5.1):
#    irm https://raw.githubusercontent.com/WillScarlettOhara/dotfiles-ssh/main/bootstrap-win.ps1 | iex
#    # or local:
#    powershell -ExecutionPolicy Bypass -File .\bootstrap-win.ps1
#    powershell -ExecutionPolicy Bypass -File .\bootstrap-win.ps1 -Stage WingetOnly
# ══════════════════════════════════════════════════════════════════════════════
#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('All', 'WingetOnly', 'Tools', 'Bitwarden', 'Dotfiles', 'Docker', 'SshServer', 'Profile')]
    [string]$Stage = 'All',

    [switch]$NoElevate,
    [switch]$SkipDocker,
    [switch]$SkipSshServer
)

$ErrorActionPreference = 'Continue'   # Stop breaks native-exe stderr in PS 5.1
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
$Script:Config = @{
    DotfilesRepo = 'https://github.com/WillScarlettOhara/dotfiles-ssh'
    DotfilesDir  = Join-Path $env:USERPROFILE '.dotfiles-ssh'
    NvimRepo     = 'git@github.com:WillScarlettOhara/.dotfiles.git'
    NvimDir      = Join-Path $env:USERPROFILE '.dotfiles-nvim'
    BwItemSshKey = 'SSH GitHub'
    BwItemOcAuth = 'OpenCode Auth'
    SshKeyPath   = Join-Path $env:USERPROFILE '.ssh\id_ed25519'
    GitName      = 'WillScarlettOhara'
    GitEmail     = '39462014+WillScarlettOhara@users.noreply.github.com'
    TimeZoneId   = 'Romance Standard Time'   # Europe/Paris on Windows
    NodeVersion  = '24'
}

# ─── UI HELPERS ───────────────────────────────────────────────────────────────
function Write-Step  { param([string]$m) Write-Host ""; Write-Host "==> $m" -ForegroundColor Blue }
function Write-Ok    { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Warn2 { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Err2  { param([string]$m) Write-Host "  [ERR]  $m" -ForegroundColor Red }
function Write-Info2 { param([string]$m) Write-Host "  ->     $m" -ForegroundColor DarkGray }

function Show-Banner {
    Write-Host ""
    Write-Host '  ██████╗  ██████╗  ██████╗ ████████╗███████╗████████╗██████╗  █████╗ ██████╗ ' -ForegroundColor Cyan
    Write-Host '  ██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗' -ForegroundColor Cyan
    Write-Host '  ██████╔╝██║   ██║██║   ██║   ██║   ███████╗   ██║   ██████╔╝███████║██████╔╝' -ForegroundColor Cyan
    Write-Host '  ██╔══██╗██║   ██║██║   ██║   ██║   ╚════██║   ██║   ██╔══██╗██╔══██║██╔═══╝ ' -ForegroundColor Cyan
    Write-Host '  ██████╔╝╚██████╔╝╚██████╔╝   ██║   ███████║   ██║   ██║  ██║██║  ██║██║     ' -ForegroundColor Cyan
    Write-Host '  ╚═════╝  ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Windows 11 Dev Bootstrap — $env:COMPUTERNAME — $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── PREDICATES ───────────────────────────────────────────────────────────────
function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Cmd { param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-DevMode {
    try {
        $v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
            -Name AllowDevelopmentWithoutDevLicense -ErrorAction Stop
        return [bool]$v.AllowDevelopmentWithoutDevLicense
    } catch { return $false }
}

function Update-PathFromRegistry {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH = (@($machine, $user) | Where-Object { $_ } ) -join ';'
}

# ─── ELEVATION ────────────────────────────────────────────────────────────────
function Invoke-SelfElevate {
    if (Test-Admin) { return }
    if ($NoElevate) {
        Write-Warn2 "Not running as Administrator. Steps requiring admin will be skipped."
        return
    }
    Write-Info2 "Relaunching as Administrator..."
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Stage', $Stage)
    if ($SkipDocker) { $argList += '-SkipDocker' }
    if ($SkipSshServer) { $argList += '-SkipSshServer' }
    $pwshPath = (Get-Process -Id $PID).Path
    Start-Process -FilePath $pwshPath -Verb RunAs -ArgumentList $argList
    exit 0
}

# ─── STEP: TIMEZONE ───────────────────────────────────────────────────────────
function Set-TimeZoneParis {
    Write-Step "Setting timezone to $($Config.TimeZoneId)"
    if (-not (Test-Admin)) {
        Write-Warn2 "Admin required for timezone — skipping"
        return
    }
    try {
        Set-TimeZone -Id $Config.TimeZoneId
        Write-Ok "Timezone set to $($Config.TimeZoneId)"
    } catch {
        Write-Warn2 "Set-TimeZone failed: $($_.Exception.Message)"
    }
}

# ─── STEP: WINGET REPAIR ──────────────────────────────────────────────────────
function Install-Winget {
    Write-Step "Checking/repairing winget (App Installer)"

    # Path fix first — frequent cause on this user's VMs
    $waPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (Test-Path $waPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $userPath) { $userPath = '' }
        if ($userPath -notlike "*$waPath*") {
            $newPath = if ($userPath) { "$userPath;$waPath" } else { $waPath }
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-Info2 "Added $waPath to User PATH"
        }
        if ($env:PATH -notlike "*$waPath*") { $env:PATH = "$env:PATH;$waPath" }
    }

    # Functional?
    if (Test-Cmd winget) {
        $ver = $null
        try { $ver = & winget --version 2>$null } catch { }
        if ($LASTEXITCODE -eq 0 -and $ver) {
            Write-Ok "winget functional ($ver)"
            return $true
        }
    }

    Write-Info2 "winget broken or absent — fetching App Installer msixbundle from GitHub releases"
    $tmp = $env:TEMP
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -UseBasicParsing
    } catch {
        Write-Err2 "Cannot reach GitHub API: $($_.Exception.Message)"
        return $false
    }

    $bundleAsset = $rel.assets | Where-Object { $_.name -like 'Microsoft.DesktopAppInstaller_*.msixbundle' } | Select-Object -First 1
    $licenseAsset = $rel.assets | Where-Object { $_.name -like '*_License*.xml' } | Select-Object -First 1
    $depsAsset = $rel.assets | Where-Object { $_.name -like 'DesktopAppInstaller_Dependencies.zip' } | Select-Object -First 1

    if (-not $bundleAsset) {
        Write-Err2 "msixbundle not in latest release"
        return $false
    }

    $bundle = Join-Path $tmp $bundleAsset.name
    Write-Info2 "Downloading $($bundleAsset.name)..."
    Invoke-WebRequest $bundleAsset.browser_download_url -OutFile $bundle -UseBasicParsing

    # VCLibs Desktop UWP dependency
    $vcLibs = Join-Path $tmp 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
    Write-Info2 "Downloading VCLibs dependency..."
    try {
        Invoke-WebRequest 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vcLibs -UseBasicParsing
    } catch {
        Write-Warn2 "VCLibs download failed: $($_.Exception.Message)"
    }

    # Dependencies zip (UI.Xaml bundles)
    $extraDeps = @()
    if ($depsAsset) {
        $depZip = Join-Path $tmp $depsAsset.name
        Write-Info2 "Downloading dependencies bundle..."
        Invoke-WebRequest $depsAsset.browser_download_url -OutFile $depZip -UseBasicParsing
        $depDir = Join-Path $tmp 'winget-deps'
        Remove-Item -Recurse -Force $depDir -ErrorAction SilentlyContinue
        Expand-Archive -Path $depZip -DestinationPath $depDir -Force
        $extraDeps = Get-ChildItem -Path $depDir -Recurse -Filter '*.appx' |
                     Where-Object { $_.FullName -match 'x64' } |
                     Select-Object -ExpandProperty FullName
    }

    Write-Info2 "Installing Appx packages..."
    try {
        if (Test-Path $vcLibs) {
            Add-AppxPackage -Path $vcLibs -ForceApplicationShutdown -ErrorAction SilentlyContinue
        }
        foreach ($d in $extraDeps) {
            Add-AppxPackage -Path $d -ForceApplicationShutdown -ErrorAction SilentlyContinue
        }
        Add-AppxPackage -Path $bundle -ForceApplicationShutdown -ErrorAction Stop
        Write-Ok "App Installer installed"
    } catch {
        Write-Err2 "Add-AppxPackage failed: $($_.Exception.Message)"
        Write-Warn2 "Try installing manually from Microsoft Store: 'App Installer'"
        return $false
    }

    Update-PathFromRegistry
    Start-Sleep -Seconds 2

    if (Test-Cmd winget) {
        try {
            $ver = & winget --version
            Write-Ok "winget now functional ($ver)"
            # Accept source agreements once, non-interactively
            & winget source update --accept-source-agreements 2>$null | Out-Null
            return $true
        } catch { }
    }

    Write-Warn2 "winget command still not callable in current session — open a new shell"
    return $false
}

# ─── STEP: SCOOP (FALLBACK) ───────────────────────────────────────────────────
function Install-Scoop {
    if (Test-Cmd scoop) {
        Write-Ok "scoop already present"
        return $true
    }
    Write-Step "Installing scoop (user-scope fallback)"
    try {
        if ((Get-ExecutionPolicy -Scope CurrentUser) -in 'Restricted', 'Undefined', 'AllSigned') {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        }
        Invoke-Expression (Invoke-RestMethod -Uri 'https://get.scoop.sh' -UseBasicParsing)
        Update-PathFromRegistry
        if (Test-Cmd scoop) {
            & scoop bucket add extras 2>$null | Out-Null
            & scoop bucket add nerd-fonts 2>$null | Out-Null
            Write-Ok "scoop installed (+ extras, nerd-fonts buckets)"
            return $true
        }
    } catch {
        Write-Err2 "scoop install failed: $($_.Exception.Message)"
    }
    return $false
}

# ─── STEP: BASE PACKAGES ──────────────────────────────────────────────────────
function Install-WingetPackage {
    param([string]$Id, [string]$Display = $Id)
    if (-not (Test-Cmd winget)) { Write-Warn2 "winget unavailable — skipping $Display"; return $false }
    # Probe install status without prompting
    $listOutput = & winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and ($listOutput -match $Id)) {
        Write-Ok "$Display already installed"
        return $true
    }
    Write-Info2 "winget install $Display ($Id)"
    & winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements `
        --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -in 0, -1978335189) {
        # -1978335189 = APPINSTALLER_CLI_ERROR_INSTALLED_PACKAGE_VERSION_NOT_FOUND (already present)
        Write-Ok "$Display installed"
        return $true
    }
    Write-Warn2 "$Display install returned exit $LASTEXITCODE"
    return $false
}

function Install-BasePackages {
    Write-Step "Installing base packages via winget"
    $pkgs = @(
        @{ Id = 'Git.Git';                      Display = 'git' }
        @{ Id = 'Microsoft.PowerShell';         Display = 'PowerShell 7' }
        @{ Id = 'Microsoft.WindowsTerminal';    Display = 'Windows Terminal' }
        @{ Id = 'JernejSimoncic.Wget';          Display = 'wget' }
        @{ Id = 'jqlang.jq';                    Display = 'jq' }
        @{ Id = '7zip.7zip';                    Display = '7-Zip' }
        @{ Id = 'GitHub.cli';                   Display = 'gh' }
    )
    foreach ($p in $pkgs) { Install-WingetPackage -Id $p.Id -Display $p.Display | Out-Null }
    Update-PathFromRegistry
    Write-Ok "Base packages done"
}

# ─── STEP: BITWARDEN CLI ──────────────────────────────────────────────────────
function Install-BitwardenCli {
    Write-Step "Installing Bitwarden CLI"
    if (Test-Cmd bw) {
        try {
            $v = & bw --version 2>$null
            Write-Ok "bw already present ($v)"
            return
        } catch { }
    }
    Install-WingetPackage -Id 'Bitwarden.CLI' -Display 'Bitwarden CLI' | Out-Null
    Update-PathFromRegistry
    if (Test-Cmd bw) { Write-Ok "bw installed: $(& bw --version)" }
}

# ─── STEP: SSH KEYS VIA BITWARDEN ─────────────────────────────────────────────
function Get-SecretsFromBitwarden {
    Write-Step "Fetching SSH keys + OpenCode auth from Bitwarden vault"

    $sshDir = Join-Path $env:USERPROFILE '.ssh'
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }

    if (-not (Test-Cmd bw)) { Write-Err2 "bw not on PATH — abort SSH key step"; return }
    if (-not (Test-Cmd jq)) { Write-Warn2 "jq not on PATH — using ConvertFrom-Json fallback" }

    $bwStatus = & bw status 2>$null | ConvertFrom-Json
    if ($bwStatus.status -eq 'unauthenticated') {
        Write-Info2 "Bitwarden login required..."
        & bw login
        $bwStatus = & bw status 2>$null | ConvertFrom-Json
    }

    $session = $null
    for ($i = 1; $i -le 3; $i++) {
        Write-Host ""
        $secure = Read-Host -Prompt "  Master password (attempt $i/3)" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null

        $session = & bw unlock $plain --raw 2>$null
        $plain = $null
        if ($LASTEXITCODE -eq 0 -and $session) {
            $env:BW_SESSION = $session
            Write-Ok "Vault unlocked"
            break
        }
        Write-Err2 "Wrong password"
        if ($i -eq 3) {
            Write-Warn2 "3 attempts failed — skipping SSH key step"
            return
        }
    }

    Write-Info2 "Syncing vault..."
    & bw sync --session $env:BW_SESSION 2>$null | Out-Null

    # SSH key item
    Write-Info2 "Retrieving '$($Config.BwItemSshKey)'..."
    $itemJson = & bw get item $Config.BwItemSshKey --session $env:BW_SESSION 2>$null
    if (-not $itemJson) {
        Write-Warn2 "Item '$($Config.BwItemSshKey)' not found"
    } else {
        $item = $itemJson | ConvertFrom-Json
        $priv = $item.sshKey.privateKey
        $pub = $item.sshKey.publicKey

        if ($priv) {
            # Write raw bytes: LF-only, no BOM, one trailing newline
            $privClean = ($priv -replace "`r`n", "`n").Trim() + "`n"
            [System.IO.File]::WriteAllBytes($Config.SshKeyPath, [System.Text.Encoding]::UTF8.GetBytes($privClean))
            if ($pub) {
                $pubClean = ($pub -replace "`r`n", "`n").Trim() + "`n"
                [System.IO.File]::WriteAllBytes("$($Config.SshKeyPath).pub", [System.Text.Encoding]::UTF8.GetBytes($pubClean))
            }
            # Strict ACL: only current user
            $acl = Get-Acl $Config.SshKeyPath
            $acl.SetAccessRuleProtection($true, $false)
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $env:USERNAME, 'FullControl', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $Config.SshKeyPath -AclObject $acl
            Write-Ok "SSH key written -> $($Config.SshKeyPath)"
        } else {
            Write-Warn2 "sshKey.privateKey empty for '$($Config.BwItemSshKey)'"
        }
    }

    # OpenCode auth (optional)
    $ocDir = Join-Path $env:LOCALAPPDATA 'opencode'
    if (-not (Test-Path $ocDir)) { New-Item -ItemType Directory -Path $ocDir -Force | Out-Null }
    $ocItem = & bw list items --search $Config.BwItemOcAuth --session $env:BW_SESSION 2>$null | ConvertFrom-Json
    $ocMatch = $ocItem | Where-Object { $_.name -eq $Config.BwItemOcAuth } | Select-Object -First 1
    if ($ocMatch -and $ocMatch.notes) {
        $ocMatch.notes | Set-Content -Path (Join-Path $ocDir 'auth.json') -Encoding utf8
        Write-Ok "OpenCode auth tokens restored"
    } else {
        Write-Warn2 "'$($Config.BwItemOcAuth)' item not found — skipped"
    }

    # known_hosts — use GitHub API meta endpoint instead of ssh-keyscan
    # (Windows OpenSSH capability is too old for GitHub's sntrup761x25519 KEX)
    Write-Info2 "Fetching github.com SSH host keys from api.github.com/meta..."
    $kh = Join-Path $sshDir 'known_hosts'
    try {
        $meta = Invoke-RestMethod 'https://api.github.com/meta' -UseBasicParsing
        $existing = if (Test-Path $kh) { Get-Content $kh -Raw } else { '' }
        $added = 0
        foreach ($key in $meta.ssh_keys) {
            if ($existing -notlike "*$key*") {
                Add-Content -Path $kh -Value "github.com $key" -Encoding ascii
                $added++
            }
        }
        Write-Ok "known_hosts updated ($added new keys, $($meta.ssh_keys.Count) total)"
    } catch {
        Write-Warn2 "Could not fetch GitHub host keys via API: $($_.Exception.Message)"
    }

    # Lock vault
    & bw lock 2>$null | Out-Null
    $env:BW_SESSION = $null
}

# ─── STEP: GIT CONFIG ─────────────────────────────────────────────────────────
function Set-GitConfig {
    Write-Step "Configuring git identity (anonymized GitHub noreply)"
    if (-not (Test-Cmd git)) { Write-Warn2 "git not installed yet — skipped"; return }
    $existing = & git config --global --get user.name 2>$null
    if ([string]::IsNullOrEmpty($existing)) {
        & git config --global user.name $Config.GitName
        & git config --global user.email $Config.GitEmail
        & git config --global init.defaultBranch main
        & git config --global core.autocrlf input
        & git config --global pull.rebase false
        Write-Ok "git identity set to $($Config.GitName) / $($Config.GitEmail)"
    } else {
        Write-Ok "Existing git identity preserved ($existing)"
    }
}

# ─── STEP: ESSENTIAL TOOLS ────────────────────────────────────────────────────
function Install-Tools {
    Write-Step "Installing essential CLI tools"
    $tools = @(
        @{ Id = 'ajeetdsouza.zoxide';        Display = 'zoxide' }
        @{ Id = 'lsd-rs.lsd';                Display = 'lsd' }
        @{ Id = 'junegunn.fzf';              Display = 'fzf' }
        @{ Id = 'Neovim.Neovim';             Display = 'Neovim' }
        @{ Id = 'JesseDuffield.lazygit';     Display = 'lazygit' }
        @{ Id = 'BurntSushi.ripgrep.MSVC';   Display = 'ripgrep' }
        @{ Id = 'sharkdp.fd';                Display = 'fd' }
        @{ Id = 'sharkdp.bat';               Display = 'bat' }
        @{ Id = 'CoreyButler.NVMforWindows'; Display = 'nvm-windows' }
    )
    foreach ($t in $tools) { Install-WingetPackage -Id $t.Id -Display $t.Display | Out-Null }
    Update-PathFromRegistry
    Write-Ok "Tools installed"
}

# ─── STEP: NODE VIA NVM-WINDOWS ───────────────────────────────────────────────
function Install-NodeViaNvm {
    Write-Step "Installing Node.js $($Config.NodeVersion) via nvm-windows"
    if (-not (Test-Cmd nvm)) {
        Update-PathFromRegistry
        if (-not (Test-Cmd nvm)) {
            Write-Warn2 "nvm not on PATH yet — open a new shell and re-run -Stage Tools"
            return
        }
    }
    & nvm install $Config.NodeVersion 2>&1 | Out-Null
    & nvm use $Config.NodeVersion 2>&1 | Out-Null
    Update-PathFromRegistry
    if (Test-Cmd node) {
        Write-Ok "Node $(& node -v) / npm $(& npm -v) ready"
    } else {
        Write-Warn2 "Node still not on PATH — manual nvm use $($Config.NodeVersion)"
    }
}

# ─── STEP: NEOVIM CONFIG SYNC ─────────────────────────────────────────────────
function Sync-NeovimConfig {
    Write-Step "Syncing Neovim config (sparse checkout from private dotfiles)"
    if (-not (Test-Path $Config.SshKeyPath)) {
        Write-Warn2 "SSH key absent — rerun -Stage Bitwarden first"
        return
    }
    if (-not (Test-Cmd git)) { Write-Warn2 "git missing"; return }
    if (-not (Test-Cmd nvim)) { Write-Warn2 "nvim missing"; return }

    $nvimConfigDir = Join-Path $env:LOCALAPPDATA 'nvim'
    if (Test-Path $Config.NvimDir) {
        Write-Info2 "Updating existing nvim dotfiles repo..."
        & git -C $Config.NvimDir fetch origin master 2>$null | Out-Null
        & git -C $Config.NvimDir reset --hard origin/master 2>$null | Out-Null
    } else {
        Write-Info2 "Cloning nvim dotfiles repo (sparse)..."
        & git clone --depth=1 --filter=blob:none --sparse --branch master `
            $Config.NvimRepo $Config.NvimDir 2>$null
        & git -C $Config.NvimDir sparse-checkout set 'nvim/.config/nvim' 2>$null | Out-Null
    }

    $nvimSrc = Join-Path $Config.NvimDir 'nvim\.config\nvim'
    if (-not (Test-Path $nvimSrc)) {
        Write-Err2 "nvim/.config/nvim absent from repo"
        return
    }

    # Backup existing config if it's a real dir
    if ((Test-Path $nvimConfigDir) -and -not ((Get-Item $nvimConfigDir).LinkType)) {
        $bak = "$nvimConfigDir.bak.$([int][double]::Parse((Get-Date -UFormat %s)))"
        Move-Item $nvimConfigDir $bak
        Write-Warn2 "Backed up existing nvim config -> $bak"
    } elseif ((Test-Path $nvimConfigDir) -and (Get-Item $nvimConfigDir).LinkType) {
        Remove-Item $nvimConfigDir -Force
    }

    New-Item -ItemType Directory -Path (Split-Path $nvimConfigDir) -Force | Out-Null
    if (Test-Admin -or (Test-DevMode)) {
        New-Item -ItemType SymbolicLink -Path $nvimConfigDir -Target $nvimSrc -Force | Out-Null
        Write-Ok "Neovim config symlinked -> $nvimConfigDir"
    } else {
        # Fallback: junction (no admin needed for directories)
        & cmd /c mklink /J $nvimConfigDir $nvimSrc 2>&1 | Out-Null
        Write-Ok "Neovim config junction created -> $nvimConfigDir"
    }

    Write-Info2 "Headless Lazy sync..."
    & nvim --headless "+Lazy! sync" '+qa' 2>$null
    Write-Ok "Neovim config + plugins synced"
}

# ─── STEP: DOCKER DESKTOP ─────────────────────────────────────────────────────
function Install-Docker {
    if ($SkipDocker) { Write-Info2 "-SkipDocker — Docker step skipped"; return }
    Write-Step "Installing Docker Desktop (requires WSL2 + Hyper-V/virtualization)"
    if (Test-Cmd docker) {
        Write-Ok "docker already present ($(& docker --version))"
        return
    }
    # WSL2 prerequisite (Win11 includes WSL but the kernel/distro may be missing)
    if (Test-Admin) {
        Write-Info2 "Ensuring WSL2 enabled..."
        & wsl --install --no-distribution 2>&1 | Out-Null
    } else {
        Write-Warn2 "Not admin — cannot enable WSL2. Docker may fail to start."
    }
    Install-WingetPackage -Id 'Docker.DockerDesktop' -Display 'Docker Desktop' | Out-Null
    Write-Warn2 "Reboot required to finish Docker Desktop setup. Add yourself to 'docker-users' group."
    try {
        Add-LocalGroupMember -Group 'docker-users' -Member $env:USERNAME -ErrorAction Stop
        Write-Ok "Added $env:USERNAME to docker-users"
    } catch {
        Write-Warn2 "Could not add to docker-users (may need admin or group not yet created)"
    }
}

# ─── STEP: DOTFILES ───────────────────────────────────────────────────────────
function Sync-Dotfiles {
    Write-Step "Cloning + linking SSH dotfiles"
    if (-not (Test-Cmd git)) { Write-Warn2 "git missing"; return }

    if (Test-Path $Config.DotfilesDir) {
        Write-Info2 "Updating existing $($Config.DotfilesDir)..."
        & git -C $Config.DotfilesDir fetch origin 2>$null
        & git -C $Config.DotfilesDir reset --hard origin/HEAD 2>$null
    } else {
        Write-Info2 "Cloning $($Config.DotfilesRepo)..."
        & git clone --depth=1 $Config.DotfilesRepo $Config.DotfilesDir 2>$null
    }

    # .zshrc is for WSL/Linux SSH; on Windows we generate a PS profile instead.
    # We do link .gitconfig if present.
    $linkable = @{
        '.gitconfig' = Join-Path $env:USERPROFILE '.gitconfig'
    }
    foreach ($k in $linkable.Keys) {
        $src = Join-Path $Config.DotfilesDir $k
        $dst = $linkable[$k]
        if (-not (Test-Path $src)) { continue }
        if ((Test-Path $dst) -and -not (Get-Item $dst -Force).LinkType) {
            $bak = "$dst.bak.$([int][double]::Parse((Get-Date -UFormat %s)))"
            Move-Item $dst $bak
            Write-Warn2 "Backed up $dst -> $bak"
        } elseif (Test-Path $dst) {
            Remove-Item $dst -Force
        }
        if (Test-Admin -or (Test-DevMode)) {
            New-Item -ItemType SymbolicLink -Path $dst -Target $src -Force | Out-Null
        } else {
            Copy-Item $src $dst -Force
            Write-Warn2 "DevMode off + non-admin: copied $k instead of symlinking"
        }
        Write-Ok "Linked $k -> $dst"
    }
}

# ─── STEP: POWERSHELL PROFILE ─────────────────────────────────────────────────
function Install-PSProfile {
    Write-Step "Installing PowerShell 7 profile (zshrc equivalent)"
    $pwshProfileDir = Join-Path $env:USERPROFILE 'Documents\PowerShell'
    if (-not (Test-Path $pwshProfileDir)) {
        New-Item -ItemType Directory -Path $pwshProfileDir -Force | Out-Null
    }
    $profilePath = Join-Path $pwshProfileDir 'Microsoft.PowerShell_profile.ps1'

    $profileSrc = Join-Path $Config.DotfilesDir 'Microsoft.PowerShell_profile.ps1'
    if (Test-Path $profileSrc) {
        Copy-Item $profileSrc $profilePath -Force
        Write-Ok "Profile copied from dotfiles repo"
    } else {
        # Embed minimal default
        $default = Get-DefaultPSProfile
        Set-Content -Path $profilePath -Value $default -Encoding utf8
        Write-Ok "Default profile written -> $profilePath"
    }

    # Modules
    Write-Info2 "Installing PSReadLine, PSFzf, posh-git, Terminal-Icons..."
    if (-not (Get-PSRepository PSGallery -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Default
    }
    Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    foreach ($m in @('PSReadLine', 'PSFzf', 'posh-git', 'Terminal-Icons', 'CompletionPredictor')) {
        if (-not (Get-Module -ListAvailable $m)) {
            Install-Module $m -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -AcceptLicense -ErrorAction SilentlyContinue
        }
    }
    Write-Ok "Modules installed"
}

function Get-DefaultPSProfile {
    @'
# ───────────────────────────────────────────────────────────────────────────
#  PowerShell 7 profile — zshrc equivalent
#  Generated by bootstrap-win.ps1
# ───────────────────────────────────────────────────────────────────────────

# PSReadLine: history-as-you-type prediction, emacs keys
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
}

# zoxide (smarter cd)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# fzf integration
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Icons + git prompt
if (Get-Module -ListAvailable Terminal-Icons) { Import-Module Terminal-Icons }
if (Get-Module -ListAvailable posh-git)       { Import-Module posh-git }

# Aliases — ls -> lsd
if (Get-Command lsd -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls  { lsd @args }
    function ll  { lsd -l @args }
    function la  { lsd -la @args }
    function lt  { lsd --tree @args }
}

# Aliases — bat / cat
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat -Option AllScope -Force -ErrorAction SilentlyContinue
}

# Convenience
function which { param([string]$Name) (Get-Command $Name -ErrorAction SilentlyContinue).Source }
function touch { param([string]$Path) if (-not (Test-Path $Path)) { New-Item -ItemType File -Path $Path | Out-Null } else { (Get-Item $Path).LastWriteTime = Get-Date } }
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# Lazygit
Set-Alias -Name lg -Value lazygit -ErrorAction SilentlyContinue

# Git shortcuts mirroring zshrc habits
function gs { git status @args }
function gd { git diff @args }
function gl { git log --oneline --graph --decorate -20 @args }
function gp { git push @args }
function gpl { git pull @args }
function gco { git checkout @args }
function gcm { git commit -m @args }

# nvm-windows post-install PATH refresh helper
function nvm-refresh {
    $env:PATH = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}

# Welcome
$user = $env:USERNAME
$host_name = $env:COMPUTERNAME
Write-Host ""
Write-Host "  $user@$host_name " -NoNewline -ForegroundColor Cyan
Write-Host "— $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor DarkGray
Write-Host ""
'@
}

# ─── STEP: OPENSSH SERVER ─────────────────────────────────────────────────────
function Install-OpenSshServer {
    if ($SkipSshServer) { Write-Info2 "-SkipSshServer — skipped"; return }
    Write-Step "Installing + hardening OpenSSH Server"
    if (-not (Test-Admin)) { Write-Warn2 "Admin required — skipped"; return }

    $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($cap.State -ne 'Installed') {
        Write-Info2 "Add-WindowsCapability OpenSSH.Server..."
        Add-WindowsCapability -Online -Name $cap.Name | Out-Null
    } else {
        Write-Ok "OpenSSH Server capability already installed"
    }

    Start-Service sshd
    Set-Service -Name sshd -StartupType Automatic
    Write-Ok "sshd running"

    # Firewall
    if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        Write-Ok "Firewall rule added (port 22 inbound)"
    } else {
        Write-Ok "Firewall rule already present"
    }

    # Default shell -> PowerShell 7 if installed, else Windows PowerShell
    $pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwshExe) { $pwshExe = (Get-Command powershell).Source }
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
        -Value $pwshExe -PropertyType String -Force | Out-Null
    Write-Ok "Default SSH shell: $pwshExe"

    # Harden sshd_config
    $sshdConf = 'C:\ProgramData\ssh\sshd_config'
    if (Test-Path $sshdConf) {
        $bak = "$sshdConf.bak"
        if (-not (Test-Path $bak)) { Copy-Item $sshdConf $bak; Write-Info2 "Original sshd_config backed up" }
        $hardened = @"
# Configured by bootstrap-win.ps1
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PrintMotd no
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
"@
        Set-Content -Path $sshdConf -Value $hardened -Encoding ascii
        Restart-Service sshd
        Write-Ok "sshd hardened (key-only) + service restarted"
    } else {
        Write-Warn2 "sshd_config not found at $sshdConf"
    }

    # Add Bitwarden-restored public key to authorized_keys
    $pubKey = "$($Config.SshKeyPath).pub"
    if (Test-Path $pubKey) {
        $isAdminUser = (Get-LocalGroupMember -Group 'Administrators' -Member $env:USERNAME -ErrorAction SilentlyContinue) -ne $null
        $authKeys = if ($isAdminUser) {
            'C:\ProgramData\ssh\administrators_authorized_keys'
        } else {
            Join-Path $env:USERPROFILE '.ssh\authorized_keys'
        }
        $existing = if (Test-Path $authKeys) { Get-Content $authKeys -Raw } else { '' }
        $pubContent = Get-Content $pubKey -Raw
        if ($existing -notlike "*$pubContent*") {
            Add-Content -Path $authKeys -Value $pubContent
        }
        # ACL: only SYSTEM + Administrators on admin file
        if ($isAdminUser) {
            icacls $authKeys /inheritance:r /grant 'SYSTEM:F' 'Administrators:F' 2>&1 | Out-Null
        }
        Write-Ok "Public key added to $authKeys"
    } else {
        Write-Warn2 "No public key in $pubKey — run -Stage Bitwarden first"
    }
}

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
function Write-Summary {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║         Bootstrap completed                              ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps:"
    Write-Host "  1. Open a new PowerShell 7 (pwsh) session to load the new profile"
    Write-Host "  2. Reboot if Docker Desktop / WSL2 were freshly installed"
    Write-Host "  3. Enable Developer Mode (Settings > For developers) for symlinks without admin"
    Write-Host "  4. Customize:  $($Config.DotfilesDir)"
    Write-Host ""
    Write-Host "  Dotfiles dir       : $($Config.DotfilesDir)" -ForegroundColor DarkGray
    Write-Host "  SSH private key    : $($Config.SshKeyPath)" -ForegroundColor DarkGray
    Write-Host "  PS profile         : $(Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── INTERACTIVE MENU ─────────────────────────────────────────────────────────
function Invoke-InteractiveMenu {
    Show-Banner
    Write-Host "What do you want to install?"
    Write-Host "  [1] Everything (recommended)"      -ForegroundColor Cyan
    Write-Host "  [2] Repair winget only"            -ForegroundColor Cyan
    Write-Host "  [3] Packages + tools (skip Bitwarden)" -ForegroundColor Cyan
    Write-Host "  [4] Bitwarden + SSH keys only"     -ForegroundColor Cyan
    Write-Host "  [5] Dotfiles + PS profile only"    -ForegroundColor Cyan
    Write-Host "  [6] Docker Desktop only"           -ForegroundColor Cyan
    Write-Host "  [7] OpenSSH server only"           -ForegroundColor Cyan
    Write-Host "  [q] Quit"                          -ForegroundColor Cyan
    Write-Host ""
    $choice = Read-Host "  Choice [1]"
    if (-not $choice) { $choice = '1' }
    switch ($choice) {
        '1' { Invoke-Stage -Stage 'All' }
        '2' { Install-Winget | Out-Null }
        '3' { Set-TimeZoneParis; Install-Winget | Out-Null; Install-BasePackages; Install-Tools; Install-NodeViaNvm; Sync-Dotfiles; Install-PSProfile }
        '4' { Install-Winget | Out-Null; Install-BitwardenCli; Get-SecretsFromBitwarden; Set-GitConfig }
        '5' { Sync-Dotfiles; Install-PSProfile }
        '6' { Install-Winget | Out-Null; Install-Docker }
        '7' { Install-OpenSshServer }
        'q' { exit 0 }
        'Q' { exit 0 }
        default { Write-Warn2 "Invalid — running All"; Invoke-Stage -Stage 'All' }
    }
    Write-Summary
}

# ─── STAGE DISPATCH ───────────────────────────────────────────────────────────
function Invoke-Stage {
    param([string]$Stage)
    switch ($Stage) {
        'All' {
            Set-TimeZoneParis
            Install-Winget | Out-Null
            Install-Scoop | Out-Null
            Install-BasePackages
            Install-BitwardenCli
            Get-SecretsFromBitwarden
            Set-GitConfig
            Install-Tools
            Install-NodeViaNvm
            Sync-Dotfiles
            Install-PSProfile
            Sync-NeovimConfig
            Install-Docker
            Install-OpenSshServer
        }
        'WingetOnly' { Install-Winget | Out-Null }
        'Tools'      { Install-Winget | Out-Null; Install-BasePackages; Install-Tools; Install-NodeViaNvm }
        'Bitwarden'  { Install-Winget | Out-Null; Install-BitwardenCli; Get-SecretsFromBitwarden; Set-GitConfig }
        'Dotfiles'   { Sync-Dotfiles; Install-PSProfile; Sync-NeovimConfig }
        'Docker'     { Install-Winget | Out-Null; Install-Docker }
        'SshServer'  { Install-OpenSshServer }
        'Profile'    { Install-PSProfile }
    }
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────
Show-Banner
Write-Info2 "PS version: $($PSVersionTable.PSVersion) | Admin: $(Test-Admin) | DevMode: $(Test-DevMode)"
Invoke-SelfElevate

if ($Host.UI.RawUI -and $PSBoundParameters.Count -eq 0 -and [Environment]::UserInteractive) {
    Invoke-InteractiveMenu
} else {
    Invoke-Stage -Stage $Stage
    Write-Summary
}
