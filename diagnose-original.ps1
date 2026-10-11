param([string]$JavaHome)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $JavaHome) { $JavaHome = (Get-ChildItem "$root/tools/jdk25" -Directory | Select-Object -First 1).FullName }
# Run test.ps1 -MinecraftVersions '26.2' first to compile the current harness.
$run = Join-Path $root 'test-run/diagnostic/fabric-26.2-original'
New-Item -ItemType Directory "$run/mods" -Force | Out-Null
Copy-Item "$root/build/26.2/verification-harness.jar" "$run/mods" -Force
Copy-Item "$root/dist/no-zombie-reinforcements-1.0.0+mc26.2.jar" "$run/mods" -Force
$cp = "$root/tools/26.2/minecraft.jar;$root/tools/fabric-loader-0.19.5.jar;$root/tools/fabric-libraries/*;$root/tools/26.2/libraries/*"
if (Test-Path "$run/verification.txt") { Remove-Item -LiteralPath "$run/verification.txt" }
Push-Location $run
try {
    & "$JavaHome/bin/java.exe" --sun-misc-unsafe-memory-access=allow '-Dverification.mod=true' '-Dverification.original=true' "-Djava.io.tmpdir=$run" "-Dfabric.gameJarPath=$root/tools/26.2/minecraft.jar" '-Dfabric.gameVersion=26.2' -classpath $cp net.fabricmc.loader.impl.launch.knot.KnotServer nogui *> console.log
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path 'verification.txt')) { Get-Content console.log -Tail 30; throw 'Original version diagnosis failed' }
    Copy-Item 'verification.txt' "$root/TEST-ORIGINAL-26.2.txt" -Force
    Get-Content 'verification.txt'
} finally { Pop-Location }
