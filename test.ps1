param(
    [string[]]$MinecraftVersions = @('26.1', '26.1.1', '26.1.2', '26.2', '26.3'),
    [string]$JavaHome = $env:JAVA_HOME
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $JavaHome) {
    $jdk = Get-ChildItem (Join-Path $root 'tools/jdk25') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jdk) { $JavaHome = $jdk.FullName }
    else { $JavaHome = Split-Path (Split-Path (Get-Command javac -ErrorAction Stop).Source) }
}
$javac = Join-Path $JavaHome 'bin/javac.exe'
$java = Join-Path $JavaHome 'bin/java.exe'
$jarTool = Join-Path $JavaHome 'bin/jar.exe'
$loader = Join-Path $root 'tools/fabric-loader-0.19.5.jar'
$reports = @()
foreach ($version in $MinecraftVersions) {
    $versionTools = Join-Path $root "tools/$version"
    $classpath = (Join-Path $versionTools 'minecraft.jar') + ';' + $loader + ';' + (Join-Path $root 'tools/fabric-libraries/*') + ';' + (Join-Path $versionTools 'libraries/*')
    $testClasses = Join-Path $root "build/$version/test-classes"
    New-Item -ItemType Directory -Path $testClasses -Force | Out-Null
    $testSources = @(Get-ChildItem (Join-Path $root 'src/test/java') -Recurse -Filter '*.java' | ForEach-Object FullName)
    & $javac --release 25 -encoding UTF-8 -proc:none -classpath $classpath -d $testClasses @testSources
    if ($LASTEXITCODE -ne 0) { throw "Verification harness compilation failed: $version" }
    Copy-Item (Join-Path $root 'src/test/resources/*') -Destination $testClasses -Recurse -Force
    $harness = Join-Path $root "build/$version/verification-harness.jar"
    & $jarTool "-J-Djava.io.tmpdir=$testClasses" --create --file $harness -C $testClasses .
    if ($LASTEXITCODE -ne 0) { throw 'Verification harness packaging failed' }
    foreach ($mode in @('baseline', 'mod')) {
        $run = Join-Path $root "test-run/$version/$mode"
        $mods = Join-Path $run 'mods'
        New-Item -ItemType Directory -Path $mods -Force | Out-Null
        Copy-Item $harness -Destination $mods -Force
        if ($mode -eq 'mod') { Copy-Item (Join-Path $root "dist/no-zombie-reinforcements-1.0.0+mc$version.jar") -Destination $mods -Force }
        Push-Location $run
        try {
            $gameJar = Join-Path $versionTools 'minecraft.jar'
            & $java --sun-misc-unsafe-memory-access=allow "-Djava.io.tmpdir=$run" "-Dfabric.gameJarPath=$gameJar" "-Dfabric.gameVersion=$version" -classpath $classpath net.fabricmc.loader.impl.launch.knot.KnotServer nogui *> 'console.log'
            if ($LASTEXITCODE -ne 0) {
                Get-Content 'console.log' -Tail 60 | Write-Output
                throw "Fabric runtime verification failed: $version ($mode)"
            }
            $report = Get-Content 'verification.txt' -Raw
            if ($report -notmatch '^PASS:') { throw "Missing verification result: $version ($mode)" }
            $expectedMode = if ($mode -eq 'mod') { 'mod=true' } else { 'mod=false' }
            if ($report.Split("`n")[0] -notmatch [regex]::Escape($expectedMode)) { throw "Incorrect control/mod setup: $version ($mode)" }
            $reports += $report
            Write-Output ($report.Split("`n")[0])
        } finally { Pop-Location }
    }
}
[IO.File]::WriteAllText((Join-Path $root 'TEST-RESULTS.txt'), (($reports -join "`n").TrimEnd() + "`n"), [Text.UTF8Encoding]::new($false))
