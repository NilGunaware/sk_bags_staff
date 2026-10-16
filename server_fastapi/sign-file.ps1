param([Parameter(Mandatory = $true)][string]$FilePath)
$ErrorActionPreference = 'Stop'
if (-not $env:SKBAGS_CERT_THUMBPRINT) { throw 'Signing certificate was not prepared.' }
$tool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $tool) { throw 'Windows SDK SignTool is required.' }
& $tool.FullName sign /sha1 $env:SKBAGS_CERT_THUMBPRINT /fd SHA256 `
    /tr http://timestamp.digicert.com /td SHA256 $FilePath
if ($LASTEXITCODE -ne 0) { throw "SignTool failed for $FilePath" }
$signature = Get-AuthenticodeSignature -FilePath $FilePath
$allowed = @('Valid')
if ($env:SKBAGS_SIGNING_MODE -eq 'self-signed') { $allowed += 'NotTrusted' }
if ($signature.SignerCertificate.Thumbprint -ne $env:SKBAGS_CERT_THUMBPRINT -or
    $signature.Status.ToString() -notin $allowed -or
    -not $signature.TimeStamperCertificate) {
    throw "Signature verification failed: $($signature.Status) - $($signature.StatusMessage)"
}
Write-Host "Verified timestamped signature: $FilePath ($env:SKBAGS_SIGNING_MODE)"
