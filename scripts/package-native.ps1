$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
[IO.Directory]::CreateDirectory((Join-Path $root 'artifacts')) | Out-Null
$archivePath = Join-Path $root 'artifacts/吞食戰國-M1-v0.15-Windows.zip'
$selectedArt = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($version in @('v11', 'v12', 'v13', 'v14', 'v15')) {
    $registration = Get-Content -LiteralPath (Join-Path $root "game/assets/$version/registration.json") -Raw | ConvertFrom-Json
    foreach ($actor in $registration.actors.PSObject.Properties.Value) {
        [void]$selectedArt.Add("$version/$($actor.file)")
        foreach ($source in $actor.frame_files.PSObject.Properties.Value) { [void]$selectedArt.Add("$version/$source") }
    }
}
$files = @()
$files += Get-ChildItem -LiteralPath (Join-Path $root 'game') -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' -and ($_.FullName -notmatch '[\\/]assets[\\/](v11|v12|v13|v14|v15)[\\/].*\.png$' -or $selectedArt.Contains(($_.Directory.Name + '/' + $_.Name))) }
$files += Get-ChildItem -LiteralPath (Join-Path $root 'tools/godot-4.7.2') -File
foreach ($relative in @('啟動雙人合作.cmd', '啟動六武將試戰.cmd', '啟動毛利軍試戰.cmd', '啟動鍵盤練習場.cmd', '啟動戰鬥原型.cmd', '啟動素材循環展示.cmd', 'README-試玩.md', 'scripts/test-native.mjs', 'scripts/test-art-native.mjs', 'scripts/test-v09.mjs', 'scripts/test-v10.mjs', 'scripts/test-v11.mjs', 'scripts/test-v12.mjs', 'scripts/verify-package-v12.py', 'docs/角色連續圖片規格-v0.12.md', 'scripts/package-native.ps1', 'docs/回饋審查-v0.2.md')) {
    $files += Get-Item -LiteralPath (Join-Path $root $relative)
}
Add-Type -AssemblyName System.IO.Compression
foreach ($relative in @('scripts/test-v13.mjs', 'scripts/verify-package-v13.py', 'docs/招式與連續圖-v0.13.md')) {
    $files += Get-Item -LiteralPath (Join-Path $root $relative)
}
foreach ($relative in @('scripts/test-v14.mjs', 'scripts/verify-package-v14.py', 'scripts/generate-voices-v11.py', 'scripts/generate-voices-v14.py', 'scripts/generate-bgm-v14.py', 'scripts/register-v12.py', 'scripts/register-v14.py', 'scripts/audit-v14-art.py', 'docs/招式與正式毛利軍-v0.14.md', 'artifacts/art-native-v14/boss-run-full-provenance.json')) {
    $files += Get-Item -LiteralPath (Join-Path $root $relative)
}
foreach ($relative in @('scripts/test-v15.mjs', 'scripts/verify-package-v15.py', 'scripts/generate-voices-v15.py', 'scripts/register-v15.py', 'scripts/preview-sfx-v15.py', 'scripts/build-asset-standard-v15.mjs', 'docs/character-assets-v15.json', 'docs/角色動作與素材標準-v0.15.html', 'artifacts/art-native-v15/victory-full-provenance.json')) {
    $files += Get-Item -LiteralPath (Join-Path $root $relative)
}
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
try {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
        $entry = $archive.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
        $inputStream = $file.OpenRead()
        $entryStream = $entry.Open()
        try { $inputStream.CopyTo($entryStream) }
        finally { $entryStream.Dispose(); $inputStream.Dispose() }
    }
}
finally { $archive.Dispose(); $stream.Dispose() }
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
[IO.File]::WriteAllText("$archivePath.sha256", "$hash  吞食戰國-M1-v0.15-Windows.zip`n", [Text.UTF8Encoding]::new($false))
[pscustomobject]@{ archive = $archivePath; files = $files.Count; bytes = (Get-Item -LiteralPath $archivePath).Length; sha256 = $hash } | ConvertTo-Json

