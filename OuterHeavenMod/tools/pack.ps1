# =====================================================================
# pack.ps1 - Outer Heaven PBO build wrapper (Windows-only by design;
#            BI Addon Builder has no Linux build).
#
# Usage:
#   .\pack.ps1 -Pbo Core
#   .\pack.ps1 -Pbo Seasonings
#   .\pack.ps1 -Pbo LoadingScreens
#   .\pack.ps1 -Pbo All
#
# Why this exists:
#   BI Addon Builder's GUI default file filter silently omits Enforce
#   Script sources (*.c;*.cpp), producing a valid but EMPTY pbo with no
#   error (documented gotcha, session 12/InitFix build). This wrapper
#   always passes tools\include.lst, which hardcodes *.c;*.cpp, so that
#   failure mode cannot recur.
#
# Verification after every build:
#   ExtractPbo (Mikero) the output and confirm scripts/ is present, OR
#   check the pbo size is non-trivial. Then RPT-verify the version
#   banner "[DOG] Outer Heaven package loaded" after deploy.
# =====================================================================

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Core", "Seasonings", "LoadingScreens", "All")]
    [string]$Pbo,

    # Default Steam install path for DayZ Tools; override if yours differs.
    [string]$AddonBuilder = "C:\Program Files (x86)\Steam\steamapps\common\DayZ Tools\Bin\AddonBuilder\AddonBuilder.exe"
)

$ErrorActionPreference = "Stop"

$repoRoot   = Split-Path -Parent $PSScriptRoot
$includeLst = Join-Path $PSScriptRoot "include.lst"
$distDir    = Join-Path $repoRoot "dist\Addons"

if (-not (Test-Path $AddonBuilder)) {
    Write-Error "AddonBuilder.exe not found at '$AddonBuilder'. Install DayZ Tools via Steam (App ID 830720) or pass -AddonBuilder."
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$targets = if ($Pbo -eq "All") { @("Core", "Seasonings", "LoadingScreens") } else { @($Pbo) }

foreach ($name in $targets) {
    $srcDir = Join-Path $repoRoot "src\DOG_$name"
    $prefix = "DOG\$name"

    Write-Host "=== Packing DOG_$name (prefix $prefix) ===" -ForegroundColor Cyan

    & $AddonBuilder $srcDir $distDir -clear -prefix="$prefix" -include="$includeLst"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AddonBuilder failed for DOG_$name (exit $LASTEXITCODE)."
    }

    # Addon Builder names output after the source folder.
    $out = Join-Path $distDir "DOG_$name.pbo"
    if (Test-Path $out) {
        $kb = [math]::Round((Get-Item $out).Length / 1KB, 1)
        Write-Host "OK  -> $out ($kb KB)" -ForegroundColor Green
        if ($kb -lt 1) {
            Write-Warning "DOG_$name.pbo is under 1 KB - likely the empty-PBO failure. Verify include.lst was applied."
        }
    } else {
        Write-Warning "Expected output '$out' not found - check AddonBuilder log/output naming."
    }
}

Write-Host ""
Write-Host "Done. Deploy: copy dist\Addons\*.pbo into @OuterHeaven\Addons\ on client/server." -ForegroundColor Cyan
