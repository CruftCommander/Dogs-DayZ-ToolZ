# PboExtract.ps1
# Unpacks a PBO file into an 'unpacked' subdirectory using Mikero's ExtractPbo.
# Validates tooling, dependencies, and input before attempting extraction.
# Inspects the raw PBO header to distinguish corruption from obfuscation.
# When a reversible obfuscation pattern is detected (known reversed-marker scheme),
# automatically attempts a header patch on a copy and retries extraction before
# failing hard.

$ErrorActionPreference = 'Stop'

# --- Configuration ---
$BinDir     = 'C:\Program Files (x86)\Mikero\DePboTools\bin'
$ExtractPbo = Join-Path $BinDir 'ExtractPbo.exe'
$Pbo        = 'C:\Backup\hosthavoc\dayz\@DayzUnderground\Addons\items.pbo'
$OutRoot    = 'C:\Backup\hosthavoc\dayz\@DayzUnderground\Addons\unpacked'

# Runtime dependencies ExtractPbo needs present in the bin dir.
$RequiredDlls = @('DePbo64.dll')

# --- PBO entry-marker reference values (Bohemia Interactive PBO File Format spec) ---
# The first entry in a PBO's header table is a null-terminated filename (empty for a
# header-extension entry) followed by a 4-byte "MimeType"/packing-method marker.
# Only four byte sequences are documented as valid for that marker:
#   'Vers' (56 65 72 73) - properties/header-extension entry (most PBOs have this first)
#   'Cprs' (43 70 72 73) - compressed file entry
#   'Encr' (45 6E 63 72) - legacy VBS/Resistance-era encryption marker
#   00 00 00 00           - uncompressed entry / dummy terminator
# Anything else in that field is not a documented PBO marker. That's exactly the
# condition that produces DePbo's "unknown header type" error - it can mean outright
# corruption, but it's also the known signature of third-party PBO protection tools
# that deliberately mangle this field to defeat extractors while the file may still
# load fine through whatever loader the protection tool ships with.
$KnownMarkers = @(
    [PSCustomObject]@{ Bytes = [byte[]](0x56,0x65,0x72,0x73); Name = "'Vers' - properties/header-extension entry (standard)" }
    [PSCustomObject]@{ Bytes = [byte[]](0x43,0x70,0x72,0x73); Name = "'Cprs' - compressed entry marker (standard)" }
    [PSCustomObject]@{ Bytes = [byte[]](0x45,0x6e,0x63,0x72); Name = "'Encr' - legacy VBS encryption marker (standard, rare)" }
    [PSCustomObject]@{ Bytes = [byte[]](0x00,0x00,0x00,0x00); Name = "0x00000000 - uncompressed/no-header-extension marker (standard)" }
)

# Known reversible obfuscation patterns: marker bytes that are a simple transformation
# of a valid marker and can be corrected by patch. Maps obfuscated -> correct bytes.
# Extend this table as new patterns are encountered.
$PatchableMarkers = @(
    [PSCustomObject]@{
        Obfuscated  = [byte[]](0x73,0x72,0x65,0x56)   # sreV - Vers reversed (byte-for-byte)
        Corrected   = [byte[]](0x56,0x65,0x72,0x73)   # Vers
        Description = "sreV (Vers reversed) - lightweight obfuscation, likely FPacker/PboObscure family"
    }
    [PSCustomObject]@{
        Obfuscated  = [byte[]](0x73,0x72,0x70,0x43)   # srpC - Cprs reversed
        Corrected   = [byte[]](0x43,0x70,0x72,0x73)   # Cprs
        Description = "srpC (Cprs reversed) - same obfuscation family, compressed-entry variant"
    }
)

# ---------------------------------------------------------------------------
# FUNCTION: Test-PboHeader
# Reads the first header-table entry of a PBO (filename + 4-byte marker) and
# checks the marker against the four documented values. Read-only.
# ---------------------------------------------------------------------------
function Test-PboHeader {
    param([Parameter(Mandatory)][string]$Path)

    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $reader = New-Object System.IO.BinaryReader($fs)

        $nameBytes  = New-Object System.Collections.Generic.List[byte]
        $maxNameLen = 260
        while ($true) {
            if ($nameBytes.Count -gt $maxNameLen) {
                return [PSCustomObject]@{
                    Recognized   = $false
                    Patchable    = $false
                    PatchEntry   = $null
                    FirstName    = $null
                    MarkerHex    = $null
                    MarkerAscii  = $null
                    Description  = "No null byte found in the first $maxNameLen bytes - not a valid PBO header (wrong file or severe corruption)."
                }
            }
            $b = $reader.ReadByte()
            if ($b -eq 0) { break }
            [void]$nameBytes.Add($b)
        }
        $firstName = if ($nameBytes.Count -gt 0) {
            [System.Text.Encoding]::ASCII.GetString($nameBytes.ToArray())
        } else { '' }

        $markerBytes = $reader.ReadBytes(4)
        if ($markerBytes.Length -lt 4) {
            return [PSCustomObject]@{
                Recognized   = $false
                Patchable    = $false
                PatchEntry   = $null
                FirstName    = $firstName
                MarkerHex    = $null
                MarkerAscii  = $null
                Description  = "File ended before a full 4-byte marker could be read - file is truncated."
            }
        }

        $markerHex   = ($markerBytes | ForEach-Object { $_.ToString('X2') }) -join ' '
        $markerAscii = -join ($markerBytes | ForEach-Object {
            if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { '.' }
        })

        $knownMatch = $KnownMarkers | Where-Object {
            $c = $_.Bytes
            $c[0] -eq $markerBytes[0] -and $c[1] -eq $markerBytes[1] -and
            $c[2] -eq $markerBytes[2] -and $c[3] -eq $markerBytes[3]
        } | Select-Object -First 1

        $patchEntry = $PatchableMarkers | Where-Object {
            $o = $_.Obfuscated
            $o[0] -eq $markerBytes[0] -and $o[1] -eq $markerBytes[1] -and
            $o[2] -eq $markerBytes[2] -and $o[3] -eq $markerBytes[3]
        } | Select-Object -First 1

        [PSCustomObject]@{
            Recognized  = [bool]$knownMatch
            Patchable   = [bool]$patchEntry
            PatchEntry  = $patchEntry
            FirstName   = $firstName
            MarkerHex   = $markerHex
            MarkerAscii = $markerAscii
            Description = if ($knownMatch) { $knownMatch.Name }
                          elseif ($patchEntry) { "PATCHABLE: $($patchEntry.Description)" }
                          else { "UNRECOGNIZED - does not match any documented PBO entry marker (Vers/Cprs/Encr/0x00000000)." }
        }
    }
    finally {
        $reader.Dispose()
        $fs.Dispose()
    }
}

# ---------------------------------------------------------------------------
# FUNCTION: Test-PboPrefixPresent
# Searches the first 64 KB of the file for the literal string '$PBOPREFIX$'.
# Legitimate addon PBOs almost always contain this near the start. Read-only.
# ---------------------------------------------------------------------------
function Test-PboPrefixPresent {
    param([Parameter(Mandatory)][string]$Path, [int]$ScanBytes = 65536)

    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $len = [Math]::Min($ScanBytes, $fs.Length)
        $buf = New-Object byte[] $len
        [void]$fs.Read($buf, 0, $len)
        return ([System.Text.Encoding]::ASCII.GetString($buf)).Contains('$PBOPREFIX$')
    }
    finally { $fs.Dispose() }
}

# ---------------------------------------------------------------------------
# FUNCTION: Test-PatchPrerequisites
# Validates that a header-patch operation can proceed:
#   - Destination directory is writable
#   - Sufficient free disk space exists for the patched copy
#   - ExtractPbo is present (re-verified; needed to attempt post-patch extraction)
# Returns a PSCustomObject with Pass (bool) and Reason (string).
# ---------------------------------------------------------------------------
function Test-PatchPrerequisites {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestPath,
        [Parameter(Mandatory)][string]$ExtractPboPath
    )

    # ExtractPbo must be present - the patch is pointless without it.
    if (-not (Test-Path $ExtractPboPath)) {
        return [PSCustomObject]@{
            Pass   = $false
            Reason = "ExtractPbo.exe not found at '$ExtractPboPath'. Cannot attempt post-patch extraction."
        }
    }

    # Destination directory must exist and be writable.
    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) {
        return [PSCustomObject]@{
            Pass   = $false
            Reason = "Destination directory '$destDir' does not exist. Cannot write patched copy."
        }
    }

    $testFile = Join-Path $destDir ("__writetest_" + [System.IO.Path]::GetRandomFileName())
    try {
        [System.IO.File]::WriteAllBytes($testFile, [byte[]](0x00))
        Remove-Item $testFile -Force
    } catch {
        return [PSCustomObject]@{
            Pass   = $false
            Reason = "Cannot write to '$destDir': $($_.Exception.Message)"
        }
    }

    # Sufficient free space: source file size + 10% headroom.
    $sourceSize  = (Get-Item $SourcePath).Length
    $required    = [long]($sourceSize * 1.1)
    $driveLetter = (Split-Path $destDir -Qualifier)
    try {
        $drive     = Get-PSDrive -Name ($driveLetter.TrimEnd(':')) -ErrorAction Stop
        $freeBytes = $drive.Free
        if ($freeBytes -lt $required) {
            $reqMB  = [math]::Round($required  / 1MB, 1)
            $freeMB = [math]::Round($freeBytes / 1MB, 1)
            return [PSCustomObject]@{
                Pass   = $false
                Reason = "Insufficient disk space on $driveLetter. Need ~$reqMB MB, have $freeMB MB free."
            }
        }
    } catch {
        # If drive query fails, warn but don't block - most common reason is a UNC path.
        Write-Host "  [WARN] Could not check free disk space on '$driveLetter': $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  [WARN] Proceeding without space check." -ForegroundColor Yellow
    }

    return [PSCustomObject]@{ Pass = $true; Reason = 'All prerequisites met.' }
}

# ---------------------------------------------------------------------------
# FUNCTION: Invoke-PboHeaderPatch
# Writes a copy of the source PBO to DestPath with the obfuscated marker bytes
# at offset 1 replaced by the correct Vers marker. Does not modify the source.
# Returns the destination path on success; throws on any validation failure.
# ---------------------------------------------------------------------------
function Invoke-PboHeaderPatch {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestPath,
        [Parameter(Mandatory)][byte[]]$ObfuscatedMarker,
        [Parameter(Mandatory)][byte[]]$CorrectedMarker
    )

    if (Test-Path $DestPath) {
        Remove-Item $DestPath -Force
        Write-Host "  Removed existing patched copy at '$DestPath'."
    }

    $bytes = [System.IO.File]::ReadAllBytes($SourcePath)

    # Validate the expected marker bytes are present at offset 1 before writing anything.
    $found = $bytes[1..4]
    for ($i = 0; $i -lt 4; $i++) {
        if ($found[$i] -ne $ObfuscatedMarker[$i]) {
            $foundHex    = ($found         | ForEach-Object { $_.ToString('X2') }) -join ' '
            $expectedHex = ($ObfuscatedMarker | ForEach-Object { $_.ToString('X2') }) -join ' '
            throw "Marker mismatch at offset $($i+1): expected $expectedHex, found $foundHex. Source file may have changed. Aborting patch."
        }
    }

    # Apply the correction in memory only, then write the copy.
    $bytes[1] = $CorrectedMarker[0]
    $bytes[2] = $CorrectedMarker[1]
    $bytes[3] = $CorrectedMarker[2]
    $bytes[4] = $CorrectedMarker[3]

    [System.IO.File]::WriteAllBytes($DestPath, $bytes)
    return $DestPath
}

# ---------------------------------------------------------------------------
# FUNCTION: Invoke-ExtractPbo
# Runs ExtractPbo against a given PBO path into a given output directory.
# Returns a PSCustomObject with ExitCode (int) and Output (string[]).
# ---------------------------------------------------------------------------
function Invoke-ExtractPbo {
    param(
        [Parameter(Mandatory)][string]$ExtractPboPath,
        [Parameter(Mandatory)][string]$PboPath,
        [Parameter(Mandatory)][string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
    }

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lines = & $ExtractPboPath -P $PboPath $OutputPath 2>&1 | ForEach-Object {
        Write-Host "  $_"
        $_.ToString()
    }
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    return [PSCustomObject]@{ ExitCode = $exit; Output = $lines }
}

# ===========================================================================
# MAIN
# ===========================================================================

# --- 1. Verify the extractor and its dependencies ---
Write-Host "=== Checking Mikero tooling ===" -ForegroundColor Cyan

if (-not (Test-Path $ExtractPbo)) {
    throw "ExtractPbo.exe not found at '$ExtractPbo'. Reinstall Mikero's DePboTools AIO."
}
Write-Host "  [OK] ExtractPbo.exe found: $ExtractPbo"

$missingDlls = @()
foreach ($dll in $RequiredDlls) {
    $dllPath = Join-Path $BinDir $dll
    if (Test-Path $dllPath) {
        Write-Host "  [OK] $dll found"
    } else {
        $missingDlls += $dll
        Write-Host "  [MISSING] $dll" -ForegroundColor Red
    }
}
if ($missingDlls.Count -gt 0) {
    throw "Missing required DLL(s): $($missingDlls -join ', '). ExtractPbo cannot run. Reinstall the Mikero DePboTools AIO so these land in '$BinDir'."
}

# --- 2. Verify the PBO exists and is a plausible size ---
Write-Host "`n=== Checking source PBO ===" -ForegroundColor Cyan

if (-not (Test-Path $Pbo)) {
    throw "PBO not found at '$Pbo'. Verify the path or re-copy the file from your source."
}

$pboFile = Get-Item $Pbo
$sizeMB  = [math]::Round($pboFile.Length / 1MB, 2)
Write-Host "  [OK] PBO found: $($pboFile.Name) ($sizeMB MB / $($pboFile.Length) bytes)"

if ($pboFile.Length -lt 1024) {
    throw "PBO is suspiciously small ($($pboFile.Length) bytes) - likely corrupt or overwritten. Re-copy the original."
}

# --- 3. Inspect the PBO header ---
Write-Host "`n=== Inspecting PBO header ===" -ForegroundColor Cyan

$headerInfo    = Test-PboHeader -Path $Pbo
$hasPrefix     = Test-PboPrefixPresent -Path $Pbo
$looksObfuscated = $false

Write-Host "  First entry filename : '$($headerInfo.FirstName)'"
Write-Host "  Marker bytes (hex)   : $($headerInfo.MarkerHex)"
Write-Host "  Marker bytes (ascii) : $($headerInfo.MarkerAscii)"
Write-Host "  `$PBOPREFIX`$ found    : $hasPrefix"

if ($headerInfo.Recognized) {
    Write-Host "  [OK] Marker recognized: $($headerInfo.Description)" -ForegroundColor Green
} else {
    $looksObfuscated = $true
    if ($headerInfo.Patchable) {
        Write-Host "  [PATCHABLE] $($headerInfo.Description)" -ForegroundColor Yellow
    } else {
        Write-Host "  [WARNING] $($headerInfo.Description)" -ForegroundColor Yellow
        Write-Host "  [WARNING] No known patch exists for this marker pattern." -ForegroundColor Yellow
    }
}

if (-not $hasPrefix) {
    $looksObfuscated = $true
    Write-Host "  [WARNING] No `$PBOPREFIX`$ found in first 64 KB - second obfuscation signal." -ForegroundColor Yellow
}

# --- 4. If obfuscated and patchable, validate prerequisites and patch ---
$patchedPboPath = $null

if ($looksObfuscated -and $headerInfo.Patchable) {
    Write-Host "`n=== Attempting header patch ===" -ForegroundColor Cyan
    Write-Host "  Pattern identified: $($headerInfo.PatchEntry.Description)"

    $patchedPboPath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetDirectoryName($Pbo),
        [System.IO.Path]::GetFileNameWithoutExtension($Pbo) + '_patched' +
        [System.IO.Path]::GetExtension($Pbo)
    )
    Write-Host "  Patch destination  : $patchedPboPath"

    $prereqs = Test-PatchPrerequisites -SourcePath $Pbo -DestPath $patchedPboPath -ExtractPboPath $ExtractPbo

    if (-not $prereqs.Pass) {
        Write-Host "  [SKIP] Patch prerequisites not met: $($prereqs.Reason)" -ForegroundColor Yellow
        Write-Host "  Falling back to direct extraction attempt (expected to fail)." -ForegroundColor Yellow
        $patchedPboPath = $null
    } else {
        Write-Host "  [OK] Prerequisites met. Writing patched copy..."
        try {
            Invoke-PboHeaderPatch `
                -SourcePath        $Pbo `
                -DestPath          $patchedPboPath `
                -ObfuscatedMarker  $headerInfo.PatchEntry.Obfuscated `
                -CorrectedMarker   $headerInfo.PatchEntry.Corrected
            Write-Host "  [OK] Patched copy written: $patchedPboPath" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] Patch write failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Falling back to direct extraction (expected to fail)." -ForegroundColor Yellow
            $patchedPboPath = $null
        }
    }
} elseif ($looksObfuscated -and -not $headerInfo.Patchable) {
    Write-Host "`n  [WARNING] Obfuscation detected but no automatic patch is available for" -ForegroundColor Yellow
    Write-Host "  this marker pattern ($($headerInfo.MarkerHex)). Extraction will likely fail." -ForegroundColor Yellow
    Write-Host "  See the PBO de-obfuscation runbook for manual approaches." -ForegroundColor Yellow
}

# --- 5. Extract (patched copy if available, original otherwise) ---
$effectivePbo    = if ($patchedPboPath) { $patchedPboPath } else { $Pbo }
$usingPatch      = [bool]$patchedPboPath
$patchedOutRoot  = if ($usingPatch) { $OutRoot + '_patched' } else { $OutRoot }

Write-Host "`n=== Extracting ===" -ForegroundColor Cyan
if ($usingPatch) {
    Write-Host "  Source : $effectivePbo (patched copy)"
    Write-Host "  Output : $patchedOutRoot"
} else {
    Write-Host "  Source : $effectivePbo"
    Write-Host "  Output : $OutRoot"
}

$extractOutRoot = if ($usingPatch) { $patchedOutRoot } else { $OutRoot }
$result = Invoke-ExtractPbo -ExtractPboPath $ExtractPbo -PboPath $effectivePbo -OutputPath $extractOutRoot

if ($result.ExitCode -ne 0) {
    $sawHeaderError = ($result.Output -join "`n") -match 'unknown header type'

    # Clean up failed patched copy - it's not useful
    if ($usingPatch -and (Test-Path $patchedPboPath)) {
        Remove-Item $patchedPboPath -Force
        Write-Host "  Cleaned up failed patched copy." -ForegroundColor Gray
    }

    if ($usingPatch -and $sawHeaderError) {
        throw @"
ExtractPbo exited with code $($result.ExitCode) ('unknown header type') even after the header patch.
The obfuscation has more than one layer - the marker fix alone was not sufficient.
Next steps (see PBO de-obfuscation runbook in Notion):
  1. pbo-deobfuscator.com  - upload '$Pbo', download cleaned version, retry
  2. DayZExtract           - github.com/wrdg/DayZExtract (different parser)
  3. PBO Manager (Kegetys) - different extraction implementation
  4. DayZ Tools FileBank   - Steam > DayZ Tools > FileBank.exe (BI's own tooling)
  5. HEMTT                 - github.com/BrettMayson/HEMTT (open source Rust toolchain)
"@
    } elseif ($sawHeaderError -and $looksObfuscated) {
        throw @"
ExtractPbo exited with code $($result.ExitCode) ('unknown header type').
Header inspection flagged obfuscation but no automatic patch was available.
Next steps (see PBO de-obfuscation runbook in Notion):
  1. pbo-deobfuscator.com  - upload '$Pbo', download cleaned version, retry
  2. DayZExtract           - github.com/wrdg/DayZExtract (different parser)
  3. PBO Manager (Kegetys) - different extraction implementation
  4. DayZ Tools FileBank   - Steam > DayZ Tools > FileBank.exe (BI's own tooling)
  5. HEMTT                 - github.com/BrettMayson/HEMTT (open source Rust toolchain)
"@
    } elseif ($sawHeaderError) {
        throw "ExtractPbo exited with code $($result.ExitCode) ('unknown header type') but the pre-flight header check looked standard. This suggests corruption rather than obfuscation - re-copy '$Pbo' from its original source and retry."
    } else {
        throw "ExtractPbo exited with code $($result.ExitCode). Extraction failed."
    }
}

Write-Host "  [OK] Extraction completed (exit code 0)" -ForegroundColor Green

# Clean up the patched copy on success - it's a transient artefact.
if ($patchedPboPath -and (Test-Path $patchedPboPath)) {
    Remove-Item $patchedPboPath -Force
    Write-Host "  Cleaned up patched copy (no longer needed)." -ForegroundColor Gray
}

# --- 6. Report results ---
$finalOutRoot = if ($usingPatch) { $patchedOutRoot } else { $OutRoot }

Write-Host "`n=== Extracted tree ===" -ForegroundColor Cyan
Get-ChildItem -Path $finalOutRoot -Recurse -File |
    Select-Object FullName, @{Name='SizeKB';Expression={[math]::Round($_.Length/1KB,1)}} |
    Format-Table -AutoSize

Write-Host "`n=== Config files (paste these to read classnames) ===" -ForegroundColor Green
$configs = Get-ChildItem -Path $finalOutRoot -Recurse -File -Include 'config.cpp','config.bin'
if ($configs) {
    $configs | Select-Object FullName, Length | Format-Table -AutoSize
} else {
    Write-Warning "No config.cpp or config.bin found in the extracted output. The PBO may use a different config layout, or extraction was incomplete."
}