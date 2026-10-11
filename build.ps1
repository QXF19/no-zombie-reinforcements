param(
    [string[]]$MinecraftVersions = @('26.1', '26.1.1', '26.1.2', '26.2', '26.3'),
    [string[]]$Loaders = @('fabric', 'forge', 'neoforge'),
    [string]$JavaHome = $env:JAVA_HOME
)
$ErrorActionPreference = 'Stop'
$modVersion = '1.1.0'
$root = $PSScriptRoot
$tools = Join-Path $root 'tools'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $tools, $dist -Force | Out-Null
if (-not $JavaHome) {
    $localJdk = Get-ChildItem (Join-Path $tools 'jdk25') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localJdk) { $JavaHome = $localJdk.FullName }
    else { $JavaHome = Split-Path (Split-Path (Get-Command javac -ErrorAction Stop).Source) }
}
$javac = Join-Path $JavaHome 'bin/javac.exe'
$jarTool = Join-Path $JavaHome 'bin/jar.exe'
if (-not (Test-Path $javac)) { throw 'Use -JavaHome to specify a Java 25 or newer JDK.' }

function Get-VerifiedFile([string]$Url, [string]$Path, [string]$Algorithm, [string]$Digest) {
    if ((Test-Path $Path) -and ((Get-FileHash $Path -Algorithm $Algorithm).Hash -eq $Digest)) { return }
    Invoke-WebRequest -Uri $Url -OutFile $Path
    if ((Get-FileHash $Path -Algorithm $Algorithm).Hash -ne $Digest) { throw "Digest mismatch: $Path" }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$loaderVersion = '0.19.5'
$legacyMixin = Join-Path $tools 'mixin-0.8.7.jar'
$legacyUrl = 'https://maven.minecraftforge.net/org/spongepowered/mixin/0.8.7/mixin-0.8.7.jar'
if (-not (Test-Path $legacyMixin)) { Invoke-WebRequest $legacyUrl -OutFile $legacyMixin }
$legacyResponse = (Invoke-WebRequest "$legacyUrl.sha1").Content
if ($legacyResponse -is [byte[]]) { $legacyResponse = [Text.Encoding]::UTF8.GetString($legacyResponse) }
$legacyDigest = ([string]$legacyResponse).Trim().Split(' ')[0]
if ((Get-FileHash $legacyMixin -Algorithm SHA1).Hash -ne $legacyDigest) { throw 'Mixin digest mismatch' }
$loaderJar = Join-Path $tools "fabric-loader-$loaderVersion.jar"
$loaderBase = "https://maven.fabricmc.net/net/fabricmc/fabric-loader/$loaderVersion/fabric-loader-$loaderVersion"
if (-not (Test-Path $loaderJar)) { Invoke-WebRequest "$loaderBase.jar" -OutFile $loaderJar }
$digestResponse = (Invoke-WebRequest "$loaderBase.jar.sha256").Content
if ($digestResponse -is [byte[]]) { $digestResponse = [Text.Encoding]::UTF8.GetString($digestResponse) }
$loaderDigest = ([string]$digestResponse).Trim().Split(' ')[0]
if ((Get-FileHash $loaderJar -Algorithm SHA256).Hash -ne $loaderDigest) { throw 'Fabric Loader digest mismatch' }
$profilePath = Join-Path $tools "fabric-loader-$loaderVersion.json"
if (-not (Test-Path $profilePath)) { Invoke-WebRequest "$loaderBase.json" -OutFile $profilePath }
$profile = Get-Content $profilePath -Raw | ConvertFrom-Json
$fabricLibs = Join-Path $tools 'fabric-libraries'
New-Item -ItemType Directory -Path $fabricLibs -Force | Out-Null
foreach ($lib in $profile.libraries.common) {
    $parts = $lib.name.Split(':')
    $relative = $parts[0].Replace('.', '/') + '/' + $parts[1] + '/' + $parts[2] + '/' + $parts[1] + '-' + $parts[2] + '.jar'
    Get-VerifiedFile ($lib.url + $relative) (Join-Path $fabricLibs ($parts[1] + '-' + $parts[2] + '.jar')) 'SHA256' $lib.sha256
}

$manifest = Invoke-RestMethod 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
foreach ($version in $MinecraftVersions) {
    $entry = $manifest.versions | Where-Object { $_.id -eq $version -and $_.type -eq 'release' } | Select-Object -First 1
    if (-not $entry) { throw "Not a published Minecraft release: $version" }
    $metaPath = Join-Path $tools "version-$version.json"
    if (-not (Test-Path $metaPath)) { Invoke-WebRequest $entry.url -OutFile $metaPath }
    $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
    $versionTools = Join-Path $tools $version
    $libraries = Join-Path $versionTools 'libraries'
    New-Item -ItemType Directory -Path $libraries -Force | Out-Null
    $bundlePath = Join-Path $versionTools 'server-bundle.jar'
    Get-VerifiedFile $meta.downloads.server.url $bundlePath 'SHA1' $meta.downloads.server.sha1
    $bundle = [IO.Compression.ZipFile]::OpenRead($bundlePath)
    try {
        foreach ($member in $bundle.Entries) {
            if ($member.FullName -match '^META-INF/versions/.+\.jar$') {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($member, (Join-Path $versionTools 'minecraft.jar'), $true)
            } elseif ($member.FullName -match '^META-INF/libraries/.+\.jar$') {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($member, (Join-Path $libraries $member.Name), $true)
            }
        }
    } finally { $bundle.Dispose() }
    $build = Join-Path $root "build/$version"
    $classes = Join-Path $build 'classes'
    New-Item -ItemType Directory -Path $classes -Force | Out-Null
    $classpath = (Join-Path $versionTools 'minecraft.jar') + ';' + $legacyMixin + ';' + $libraries + '\*'
    $sources = @(Get-ChildItem (Join-Path $root 'src/main/java') -Filter '*.java' -Recurse | ForEach-Object FullName)
    & $javac --release 21 -encoding UTF-8 -proc:none -classpath $classpath -d $classes @sources
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed for Minecraft $version" }
    Copy-Item (Join-Path $root 'src/main/resources/*') -Destination $classes -Recurse -Force
    $modMetaPath = Join-Path $classes 'fabric.mod.json'
    $modMeta = Get-Content $modMetaPath -Raw | ConvertFrom-Json
    $modMeta.version = "$modVersion+mc$version"
    $modMeta.depends.minecraft = $version
    $modMeta.depends.fabricloader = '>=0.19.5'
    $modMeta | ConvertTo-Json -Depth 8 | Set-Content $modMetaPath -Encoding utf8NoBOM
    Copy-Item (Join-Path $root 'LICENSE') -Destination $classes
    $versions = Get-Content (Join-Path $root 'loader-versions.json') -Raw | ConvertFrom-Json
    $row = $versions | Where-Object minecraft -eq $version
    foreach ($loaderName in $Loaders) {
        $package = Join-Path $build "package-$loaderName"
        New-Item -ItemType Directory -Path $package -Force | Out-Null
        Copy-Item (Join-Path $classes 'dev') $package -Recurse -Force
        Copy-Item (Join-Path $classes 'no_zombie_reinforcements.mixins.json') $package -Force
        Copy-Item (Join-Path $root 'LICENSE') $package -Force
        $manifestText = "Manifest-Version: 1.0`n"
        if ($loaderName -eq 'fabric') {
            Copy-Item $modMetaPath $package -Force
        } else {
            $metaDir = Join-Path $package 'META-INF'
            New-Item -ItemType Directory $metaDir -Force | Out-Null
            $lv = $row.$loaderName
            if (-not $lv) { throw "Missing supported $loaderName version for $version" }
            if ($loaderName -eq 'forge') {
                $language = 'lowcodefml'; $languageRange = "[$($lv.Split('.')[0]),)"
                $file = 'mods.toml'; $required = 'mandatory=true'; $mixins = ''
                $manifestText += "MixinConfigs: no_zombie_reinforcements.mixins.json`n"
            } else {
                $language = 'javafml'; $languageRange = '[1,)'
                $file = 'neoforge.mods.toml'; $required = 'type="required"'
                $mixins = "[[mixins]]`nconfig=`"no_zombie_reinforcements.mixins.json`""
            }
            $toml = @"
modLoader="$language"
loaderVersion="$languageRange"
license="MIT"
[[mods]]
modId="no_zombie_reinforcements"
version="$modVersion+mc$version"
displayName="No Zombie Reinforcements"
displayTest="IGNORE_SERVER_VERSION"
description='''Disables damage-triggered zombie reinforcements. Server installation is sufficient.'''
[[dependencies.no_zombie_reinforcements]]
modId="$loaderName"
$required
versionRange="[$lv,)"
ordering="NONE"
side="BOTH"
[[dependencies.no_zombie_reinforcements]]
modId="minecraft"
$required
versionRange="[$version]"
ordering="NONE"
side="BOTH"
[features.no_zombie_reinforcements]
javaVersion="[25,)"
$mixins
"@
            Set-Content (Join-Path $metaDir $file) $toml -Encoding utf8NoBOM
        }
        $manifestFile = Join-Path $build "manifest-$loaderName.mf"
        Set-Content $manifestFile ($manifestText + "`n") -Encoding utf8NoBOM
        $output = Join-Path $dist "no-zombie-reinforcements-$modVersion-$loaderName+mc$version.jar"
        & $jarTool "-J-Djava.io.tmpdir=$build" --create --file $output --manifest $manifestFile --date '2026-10-11T00:00:00Z' -C $package .
        if ($LASTEXITCODE -ne 0) { throw "Packaging failed: $loaderName Minecraft $version" }
        Write-Output "Built $output"
    }
}
