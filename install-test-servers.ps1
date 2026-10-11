param(
    [string[]]$MinecraftVersions = @('26.1','26.1.1','26.1.2','26.2','26.3'),
    [string[]]$Loaders = @('forge','neoforge'),
    [string]$JavaHome
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $JavaHome) { $JavaHome = (Get-ChildItem "$root/tools/jdk25" -Directory | Select-Object -First 1).FullName }
$java = Join-Path $JavaHome 'bin/java.exe'
$versions = Get-Content "$root/loader-versions.json" -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Download([string]$url, [string]$path, [string]$sha1) {
    if ((Test-Path $path) -and ((-not $sha1) -or ((Get-FileHash $path -Algorithm SHA1).Hash -eq $sha1))) { return }
    New-Item -ItemType Directory (Split-Path $path) -Force | Out-Null
    for ($attempt=0; $attempt -lt 3; $attempt++) {
        try {
            Invoke-WebRequest $url -OutFile $path -TimeoutSec 120
            if ($sha1 -and (Get-FileHash $path -Algorithm SHA1).Hash -ne $sha1) { throw "Checksum mismatch: $path" }
            return
        } catch { if ($attempt -eq 2) { throw } }
    }
}
foreach ($version in $MinecraftVersions) {
    foreach ($loaderName in $Loaders) {
        $row = $versions | Where-Object minecraft -eq $version
        $lv = $row.$loaderName
        $server = Join-Path $root "tools/servers/$loaderName/$version"
        if (Test-Path "$server/run.bat") { Write-Output "Already installed $loaderName $version"; continue }
        New-Item -ItemType Directory $server -Force | Out-Null
        $base = if ($loaderName -eq 'forge') { "https://maven.minecraftforge.net/net/minecraftforge/forge/$version-$lv/forge-$version-$lv" } else { "https://maven.neoforged.net/releases/net/neoforged/neoforge/$lv/neoforge-$lv" }
        $installer = Join-Path $root "tools/$loaderName-$version-installer.jar"
        Download "$base-installer.jar" $installer ''
        $zip = [IO.Compression.ZipFile]::OpenRead($installer)
        try {
            $libs = @()
            foreach ($name in @('version.json','install_profile.json')) {
                $reader = [IO.StreamReader]::new($zip.GetEntry($name).Open())
                try { $profile = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                $libs += $profile.libraries
            }
            foreach ($lib in $libs) {
                $artifact = $lib.downloads.artifact
                if (-not $artifact.url) { continue }
                $cache = Join-Path $root "tools/maven-cache/$($artifact.path)"
                Download $artifact.url $cache $artifact.sha1
                $target = Join-Path $server "libraries/$($artifact.path)"
                New-Item -ItemType Directory (Split-Path $target) -Force | Out-Null
                Copy-Item $cache $target -Force
            }
        } finally { $zip.Dispose() }
        $log = Join-Path $root "tools/$loaderName-$version-install.log"
        & $java '-Djava.net.preferIPv4Stack=true' "-Djava.io.tmpdir=$server" -jar $installer --installServer $server *> $log
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$server/run.bat")) { Get-Content $log -Tail 25; throw "Installation failed: $loaderName $version" }
        Write-Output "Installed $loaderName $lv for Minecraft $version"
    }
}
