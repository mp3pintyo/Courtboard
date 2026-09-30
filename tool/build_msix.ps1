<#
.SYNOPSIS
  Courtboard MSIX csomag készítése (Windows, x64).

.DESCRIPTION
  1. Kiolvassa a verziót a pubspec.yaml-ből (x.y.z+n → MSIX: x.y.z.0).
  2. Release buildet készít (a -SkipBuild kapcsolóval kihagyható).
  3. `dart run msix:create --build-windows false` futtatásával elkészíti a
     csomagot (a pubspec.yaml `msix_config` szakasza szerint).
  4. A kész .msix-et a dist\Courtboard-<verzió>-Windows-x64.msix néven ÁTHELYEZI
     (nem másolja): a msix a build\windows\x64\runner\Release mappába írja a
     courtboard.msix-et, és ha ott maradna, bekerülne a kiadási ZIP-be.

  Saját aláíró tanúsítvány nélkül a msix csomag beépített teszttanúsítványával
  ír alá („CN=Msix Testing…”). A script SEMMIT nem telepít: se tanúsítványt,
  se alkalmazást. A telepítés módját lásd a README „MSIX csomag” szakaszában.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\build_msix.ps1

.EXAMPLE
  tool\build_msix.ps1 -SkipBuild -CertificatePath C:\cert\courtboard.pfx -CertificatePassword titok
#>
[CmdletBinding()]
param(
  [switch]$SkipBuild,
  [string]$CertificatePath,
  [string]$CertificatePassword
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)')
if (-not $match.Success) { throw 'A pubspec.yaml nem tartalmaz x.y.z verziót.' }
$version = '{0}.{1}.{2}' -f $match.Groups[1].Value, $match.Groups[2].Value, $match.Groups[3].Value
$msixVersion = "$version.0"
Write-Host "Courtboard $version → MSIX $msixVersion"

if (-not $SkipBuild) {
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'A Windows release build nem sikerült.' }
}

$exe = Join-Path $root 'build\windows\x64\runner\Release\courtboard.exe'
if (-not (Test-Path $exe)) { throw "Nem található a release build: $exe" }

$arguments = @('run', 'msix:create', '--build-windows', 'false', '--version', $msixVersion)
if ($CertificatePath) {
  $arguments += @('--certificate-path', $CertificatePath)
  if ($CertificatePassword) { $arguments += @('--certificate-password', $CertificatePassword) }
}
dart @arguments
if ($LASTEXITCODE -ne 0) { throw 'Az MSIX csomag elkészítése nem sikerült.' }

$msix = Join-Path $root 'build\windows\x64\runner\Release\courtboard.msix'
if (-not (Test-Path $msix)) { throw "Nem jött létre az MSIX: $msix" }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$target = Join-Path $dist "Courtboard-$version-Windows-x64.msix"
# Áthelyezés (nem másolás), hogy a Release mappa tiszta maradjon a ZIP-hez.
Move-Item -LiteralPath $msix -Destination $target -Force
if (Test-Path $msix) { throw "Az MSIX nem került át a dist mappába: $msix" }

$signature = Get-AuthenticodeSignature $target
Write-Host "Kész: $target"
Write-Host ("Aláíró: {0}" -f $signature.SignerCertificate.Subject)
if ($signature.Status -ne 'Valid') {
  Write-Host 'A tanúsítvány ezen a gépen nem megbízható (tesztaláírás) – a telepítéshez lásd a README „MSIX csomag” szakaszát.'
}
