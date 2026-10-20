$ErrorActionPreference = "Stop"

$androidDirectory = $PSScriptRoot
$projectRoot = Split-Path -Parent $androidDirectory
$keystoreDirectory = Join-Path $HOME ".android"
$keystorePath = Join-Path $keystoreDirectory "jesus_worship_upload_key.jks"
$keyAlias = "jesus-worship-upload"
$storePasswordVariable = "JESUS_WORSHIP_UPLOAD_STORE_PASSWORD"
$keyPasswordVariable = "JESUS_WORSHIP_UPLOAD_KEY_PASSWORD"
$environmentNames = @(
    "JESUS_WORSHIP_UPLOAD_STORE_FILE",
    $storePasswordVariable,
    "JESUS_WORSHIP_UPLOAD_KEY_ALIAS",
    $keyPasswordVariable,
    "GRADLE_OPTS"
)
$previousEnvironment = @{}

foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

function ConvertTo-PlainText {
    param([Security.SecureString]$Value)

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Invoke-Keytool {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $keytool @Arguments 2>&1 | ForEach-Object { Write-Host "$_" }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw $FailureMessage
    }
}

try {
    $javaHome = $env:JAVA_HOME
    if ([string]::IsNullOrWhiteSpace($javaHome)) {
        $javaHome = "C:\Program Files\Android\Android Studio\jbr"
    }
    $keytool = Join-Path $javaHome "bin\keytool.exe"
    if (-not (Test-Path $keytool)) {
        throw "keytool.exe was not found under the configured Java home: $javaHome"
    }

    $localProperties = Join-Path $androidDirectory "local.properties"
    if (-not (Test-Path $localProperties)) {
        throw "android\local.properties was not found. Run a Flutter command once to configure the Android project."
    }
    $flutterSdkLine = Get-Content $localProperties |
        Where-Object { $_ -match "^flutter\.sdk=" } |
        Select-Object -First 1
    if (-not $flutterSdkLine) {
        throw "The Flutter SDK path is missing from android\local.properties."
    }
    $flutterSdk = ($flutterSdkLine -replace "^flutter\.sdk=", "") -replace "\\\\", "\"
    $flutter = Join-Path $flutterSdk "bin\flutter.bat"
    if (-not (Test-Path $flutter)) {
        throw "flutter.bat was not found at the SDK path in android\local.properties."
    }

    $keystoreExists = Test-Path $keystorePath
    if ($keystoreExists) {
        $reuse = Read-Host "Existing upload keystore found. Type USE_EXISTING to continue"
        if ($reuse -cne "USE_EXISTING") {
            throw "Keystore use cancelled; the existing key was not changed."
        }

        $password = Read-Host "Enter the EXISTING upload-key password" -AsSecureString
        $passwordText = ConvertTo-PlainText $password
    }
    else {
        $password = Read-Host "Create a NEW upload-key password (12 or more characters)" -AsSecureString
        if ($password.Length -lt 12) {
            throw "Use an upload-key password with at least 12 characters."
        }

        $confirmation = Read-Host "Confirm the NEW upload-key password" -AsSecureString
        $passwordText = ConvertTo-PlainText $password
        $confirmationText = ConvertTo-PlainText $confirmation
        if ($passwordText -cne $confirmationText) {
            throw "The passwords did not match."
        }
        New-Item -ItemType Directory -Path $keystoreDirectory -Force | Out-Null
    }

    $env:JESUS_WORSHIP_UPLOAD_STORE_FILE = $keystorePath
    $env:JESUS_WORSHIP_UPLOAD_KEY_ALIAS = $keyAlias
    [Environment]::SetEnvironmentVariable($storePasswordVariable, $passwordText, "Process")
    [Environment]::SetEnvironmentVariable($keyPasswordVariable, $passwordText, "Process")

    if ($keystoreExists) {
        Invoke-Keytool -Arguments @(
            "-list",
            "-keystore", $keystorePath,
            "-alias", $keyAlias,
            "-storepass:env", $storePasswordVariable
        ) -FailureMessage "Could not verify the existing keystore. The password may be incorrect or the expected alias '$keyAlias' may be missing. The keystore was not changed."
    }
    else {
        Invoke-Keytool -Arguments @(
            "-genkeypair",
            "-v",
            "-keystore", $keystorePath,
            "-storetype", "JKS",
            "-alias", $keyAlias,
            "-keyalg", "RSA",
            "-keysize", "2048",
            "-validity", "10000",
            "-dname", "CN=Jesus Worship Calendar, C=KR",
            "-storepass:env", $storePasswordVariable,
            "-keypass:env", $keyPasswordVariable
        ) -FailureMessage "Upload-key generation failed."
        Write-Host "Upload keystore created outside the repository: $keystorePath"
        Write-Host "Back up the keystore and password securely. Never upload either to source control."
    }

    $existingGradleOpts = $previousEnvironment["GRADLE_OPTS"]
    $gradleOptions = @($existingGradleOpts, "-Dorg.gradle.daemon=false") |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $env:GRADLE_OPTS = $gradleOptions -join " "

    Push-Location $projectRoot
    try {
        & $flutter build appbundle --release
        if ($LASTEXITCODE -ne 0) {
            throw "Release AAB build failed."
        }
    }
    finally {
        Pop-Location
    }

    $aab = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
    if (-not (Test-Path $aab)) {
        throw "Flutter reported success, but the release AAB was not found."
    }
    Write-Host "Release AAB created: $aab"
    Write-Host "Upload keystore: $keystorePath"
    Write-Host "Back up the keystore and password securely. Never upload either to source control."
}
finally {
    $passwordText = $null
    $confirmationText = $null
    if ($password) {
        $password.Dispose()
    }
    if ($confirmation) {
        $confirmation.Dispose()
    }
    foreach ($name in $environmentNames) {
        $previousValue = $previousEnvironment[$name]
        if ($null -eq $previousValue) {
            Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
        }
        else {
            [Environment]::SetEnvironmentVariable($name, $previousValue, "Process")
        }
    }
}
