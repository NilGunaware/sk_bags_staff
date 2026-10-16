$ErrorActionPreference = 'Stop'
if ($env:WINDOWS_SIGNING_PFX_BASE64) {
    if (-not $env:WINDOWS_SIGNING_PFX_PASSWORD) { throw 'PFX password secret is missing.' }
    $pfxPath = Join-Path $env:RUNNER_TEMP 'skbags-signing.pfx'
    try {
        [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($env:WINDOWS_SIGNING_PFX_BASE64))
        $password = ConvertTo-SecureString $env:WINDOWS_SIGNING_PFX_PASSWORD -AsPlainText -Force
        $imported = Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\CurrentUser\My -Password $password
        $cert = $imported | Where-Object { $_.HasPrivateKey -and
            ($_.EnhancedKeyUsageList.ObjectId -contains '1.3.6.1.5.5.7.3.3') } | Select-Object -First 1
        if (-not $cert) { throw 'PFX does not contain a code-signing certificate with a private key.' }
        $mode = if ($cert.Subject -eq $cert.Issuer) { 'self-signed' } else { 'provided-certificate' }
    } finally {
        Remove-Item $pfxPath -Force -ErrorAction SilentlyContinue
    }
} else {
    $cert = New-SelfSignedCertificate -Type CodeSigningCert `
        -Subject 'CN=SK Bags Desktop, O=SK Bags, C=IN' `
        -FriendlyName 'SK Bags Desktop Code Signing' `
        -CertStoreLocation Cert:\CurrentUser\My -KeyAlgorithm RSA -KeyLength 3072 `
        -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(3)
    $mode = 'self-signed'
}
if ($cert.NotAfter -le (Get-Date)) { throw 'Signing certificate has expired.' }
"SKBAGS_CERT_THUMBPRINT=$($cert.Thumbprint)" | Out-File $env:GITHUB_ENV -Encoding utf8 -Append
"SKBAGS_SIGNING_MODE=$mode" | Out-File $env:GITHUB_ENV -Encoding utf8 -Append
Export-Certificate -Cert $cert -FilePath 'dist/SKBagsDesktop-Certificate.cer' | Out-Null
@"
SK Bags Desktop release signing
Mode: $mode
Subject: $($cert.Subject)
Certificate thumbprint: $($cert.Thumbprint)
Expires: $($cert.NotAfter.ToUniversalTime().ToString('o'))

Self-signed certificates are not automatically trusted by Windows.
No certificate trust stores or antivirus exclusions are changed by the installer.
The certificate exported here contains no private key.
For a stable publisher identity, configure the same code-signing PFX for each build.
"@ | Set-Content 'dist/SIGNING.txt' -Encoding utf8
