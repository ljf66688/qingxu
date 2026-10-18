param(
    [string]$FlutterSdk = $env:FLUTTER_ROOT,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$AndroidSdk = $env:ANDROID_HOME,
    [string]$BuildDirectory = (Join-Path $env:TEMP 'qingxu-build'),
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$buildRoot = [IO.Path]::GetFullPath($BuildDirectory)
if ($buildRoot -match '[^\x00-\x7F]') {
    throw 'BuildDirectory must use an ASCII path because the Windows Dart AOT builder rejects some Unicode paths.'
}
if ($buildRoot.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or $buildRoot -eq $sourceRoot -or
    $sourceRoot.StartsWith($buildRoot.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose a build directory outside the source checkout.'
}
if (-not $FlutterSdk) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutterCommand) { throw 'Set -FlutterSdk to the Flutter 3.44.6 SDK folder.' }
    $FlutterSdk = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
}
$flutter = Join-Path $FlutterSdk 'bin\flutter.bat'
$dart = Join-Path $FlutterSdk 'bin\dart.bat'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Flutter SDK not found.' }
if ($JavaHome) { $env:JAVA_HOME = $JavaHome; $env:Path = "$JavaHome\bin;$env:Path" }
if ($AndroidSdk) { $env:ANDROID_HOME = $AndroidSdk; $env:ANDROID_SDK_ROOT = $AndroidSdk }

# Java/Gradle does not automatically inherit the Windows proxy used by PowerShell.
# Apply it only to this build process; never save machine-specific settings in Git.
try {
    $target = [Uri]'https://services.gradle.org/'
    $proxy = [Net.WebRequest]::DefaultWebProxy.GetProxy($target)
    if ($proxy.Host -ne $target.Host -and -not $proxy.UserInfo) {
        $env:JAVA_TOOL_OPTIONS = "$env:JAVA_TOOL_OPTIONS -Dhttps.proxyHost=$($proxy.Host) -Dhttps.proxyPort=$($proxy.Port) -Dhttp.proxyHost=$($proxy.Host) -Dhttp.proxyPort=$($proxy.Port) -Dhttp.nonProxyHosts=localhost|127.* -Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NONE"
    }
} catch { Write-Verbose 'No automatic Windows proxy could be resolved.' }

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
& robocopy $sourceRoot $buildRoot /E /XJ /XD .git .dart_tool build .fvm .local-dev outputs /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw 'Copying sources to the build directory failed.' }

function Invoke-Checked([string]$Program, [string[]]$CommandArguments) {
    & $Program @CommandArguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Program $($CommandArguments -join ' ')" }
}

Push-Location $buildRoot
try {
    if (-not (Test-Path -LiteralPath '.env')) {
        Copy-Item -LiteralPath '.env.example' -Destination '.env'
    }
    Invoke-Checked $flutter @('pub', 'get')
    Invoke-Checked $flutter @('gen-l10n')
    Invoke-Checked $dart @('run', 'build_runner', 'build')
    Invoke-Checked $flutter @('analyze', '--no-pub')
    if (-not $SkipTests) {
        Invoke-Checked $flutter @('test', 'test/offline',
            'test/unit_test/meal_nutriments_entity_test.dart', '--no-pub')
    }
    $signing = Join-Path $buildRoot 'android\key.properties'
    if (-not (Test-Path -LiteralPath $signing)) {
        throw 'Release signing is required. Configure android/key.properties using your local keystore, then run this script again. Do not commit keys or passwords.'
    }
    # A release build must regenerate the production-only plugin registrant.
    # --no-pub skips that step and can leave integration_test registered after
    # pub get / flutter test, while Gradle excludes it from the release classpath.
    Invoke-Checked $flutter @('build', 'apk', '--release', '--flavor', 'offline',
        '--target', 'lib/offline_main.dart',
        '--build-name', '0.1.1', '--build-number', '2')
    $apk = Join-Path $buildRoot 'build\app\outputs\flutter-apk\app-offline-release.apk'
    if (-not (Test-Path -LiteralPath $apk)) { throw 'APK output was not found.' }
    $outputRoot = Join-Path $sourceRoot 'outputs'
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    $destination = Join-Path $outputRoot '轻序-0.1.1.apk'
    Copy-Item -LiteralPath $apk -Destination $destination -Force
    Get-FileHash -LiteralPath $destination -Algorithm SHA256 | Select-Object Path,Hash
} finally {
    Pop-Location
}
