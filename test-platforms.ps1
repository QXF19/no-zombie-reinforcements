param(
    [string[]]$MinecraftVersions = @('26.1','26.1.1','26.1.2','26.2','26.3'),
    [string[]]$Loaders = @('forge','neoforge'),
    [string]$JavaHome
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $JavaHome) { $JavaHome = (Get-ChildItem "$root/tools/jdk25" -Directory | Select-Object -First 1).FullName }
$javac = Join-Path $JavaHome 'bin/javac.exe'
$java = Join-Path $JavaHome 'bin/java.exe'
$jarTool = Join-Path $JavaHome 'bin/jar.exe'
$versions = Get-Content "$root/loader-versions.json" -Raw | ConvertFrom-Json
$reports = @()
foreach ($version in $MinecraftVersions) {
    $cp = "$root/tools/$version/minecraft.jar;$root/tools/mixin-0.8.7.jar;$root/tools/$version/libraries/*"
    $classes = Join-Path $root "build/$version/platform-test"
    New-Item -ItemType Directory $classes -Force | Out-Null
    $sources = @(Get-ChildItem "$root/src/test/java" -Recurse -Filter '*.java' | Where-Object Name -ne 'FabricTest.java' | ForEach-Object FullName)
    & $javac --release 21 -encoding UTF-8 -proc:none -classpath $cp -d $classes @sources
    if ($LASTEXITCODE -ne 0) { throw "Test compilation failed: $version" }
    $mixins = Get-Content "$root/src/test/resources/verification.mixins.json" -Raw | ConvertFrom-Json
    $mixins.mixins += 'MainTestMixin'
    $mixins | ConvertTo-Json -Depth 6 | Set-Content "$classes/verification.mixins.json" -Encoding utf8NoBOM
    foreach ($loaderName in $Loaders) {
        $row = $versions | Where-Object minecraft -eq $version
        $lv = $row.$loaderName
        $server = Join-Path $root "tools/servers/$loaderName/$version"
        if (-not (Test-Path "$server/run.bat")) { throw "Install $loaderName $version first using install-test-servers.ps1" }
        $package = Join-Path $root "build/$version/test-$loaderName"
        New-Item -ItemType Directory "$package/META-INF" -Force | Out-Null
        Copy-Item "$classes/dev" $package -Recurse -Force
        Copy-Item "$classes/verification.mixins.json" $package -Force
        $language = if ($loaderName -eq 'forge') { 'lowcodefml' } else { 'javafml' }
        $range = if ($loaderName -eq 'forge') { "[$($lv.Split('.')[0]),)" } else { '[1,)' }
        $extra = if ($loaderName -eq 'neoforge') { "[[mixins]]`nconfig=`"verification.mixins.json`"" } else { '' }
        $toml = @"
modLoader="$language"
loaderVersion="$range"
license="MIT"
[[mods]]
modId="no_reinforcements_verification"
version="1.0.0"
displayName="Verification harness - DO NOT INSTALL FOR PLAY"
$extra
"@
        $file = if ($loaderName -eq 'forge') { 'mods.toml' } else { 'neoforge.mods.toml' }
        Set-Content "$package/META-INF/$file" $toml -Encoding utf8NoBOM
        $manifest = Join-Path $root "build/$version/test-$loaderName.mf"
        Set-Content $manifest "Manifest-Version: 1.0`nMixinConfigs: verification.mixins.json`n`n" -Encoding utf8NoBOM
        $harness = Join-Path $root "build/$version/$loaderName-verification-harness.jar"
        & $jarTool "-J-Djava.io.tmpdir=$package" --create --file $harness --manifest $manifest -C $package .
        if ($LASTEXITCODE -ne 0) { throw 'Test packaging failed' }
        $mods = Join-Path $server 'mods'
        New-Item -ItemType Directory $mods -Force | Out-Null
        Copy-Item $harness $mods -Force
        $modName = "no-zombie-reinforcements-1.1.0-$loaderName+mc$version.jar"
        foreach ($mode in @('baseline','mod')) {
            if (Test-Path (Join-Path $mods $modName)) { Remove-Item -LiteralPath (Join-Path $mods $modName) }
            if ($mode -eq 'mod') { Copy-Item "$root/dist/$modName" $mods -Force }
            $run = Join-Path $root "test-run/v1.1.0/$loaderName/$version/$mode"
            New-Item -ItemType Directory $run -Force | Out-Null
            if (Test-Path "$server/verification.txt") { Remove-Item -LiteralPath "$server/verification.txt" }
            $coord = if ($loaderName -eq 'forge') { "$version-$lv" } else { $lv }
            $argsFile = "libraries/net/$($loaderName -eq 'forge' ? 'minecraftforge' : 'neoforged')/$loaderName/$coord/win_args.txt"
            Push-Location $server
            try {
                & $java --sun-misc-unsafe-memory-access=allow '-Dverification.platform=true' "-Dverification.mod=$($mode -eq 'mod')" "-Djava.io.tmpdir=$server" "@$argsFile" nogui *> "$run/console.log"
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path 'verification.txt')) {
                    Get-Content "$run/console.log" -Tail 70
                    throw "Runtime test failed: $loaderName $version $mode"
                }
                $report = Get-Content 'verification.txt' -Raw
                if ($report -notmatch '^PASS:' -or $report -notmatch "mod=$($mode -eq 'mod' ? 'true' : 'false')") { throw 'Invalid test report' }
                Copy-Item 'verification.txt' $run -Force
                $reports += "Loader: $loaderName $lv`n$report"
                Write-Output "$loaderName $lv - $($report.Split("`n")[0])"
            } finally { Pop-Location }
        }
    }
}
[IO.File]::WriteAllText("$root/TEST-PLATFORMS.txt", (($reports -join "`n").TrimEnd() + "`n"), [Text.UTF8Encoding]::new($false))
