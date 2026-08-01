$ErrorActionPreference = 'Stop'

$key = [Environment]::GetEnvironmentVariable('FOOTBALL_DATA_KEY', 'User')
if (-not [string]::IsNullOrWhiteSpace($key)) {
  $env:FOOTBALL_DATA_KEY = $key
}
$exe = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release\courtboard.exe'
if (-not (Test-Path $exe)) {
  throw "Nem található a Courtboard kiadás: $exe"
}

Get-Process courtboard -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath $exe -WorkingDirectory $PSScriptRoot
