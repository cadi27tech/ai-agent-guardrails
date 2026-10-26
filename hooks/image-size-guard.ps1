# PreToolUse guard: keeps images under the API's 2000px per-side many-image limit.
# 1. Blocks fullPage Playwright screenshots (they render thousands of px tall).
# 2. Downscales any oversized image before Read, pointing at the copy.
$ErrorActionPreference = 'Stop'
$LIMIT = 1400

try { $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$tool = [string]$payload.tool_name
$inp = $payload.tool_input

function Block([string]$msg) { [Console]::Error.Write($msg); exit 2 }

if ($tool -like '*browser_take_screenshot*') {
    if ($inp.fullPage -eq $true) {
        Block @"
BLOCKED: fullPage screenshots render thousands of pixels tall, exceed the 2000px many-image limit, and poison the whole session once several accumulate.
Capture viewport chunks instead:
  browser_evaluate { function: "() => window.scrollTo(0, N)" }
  browser_take_screenshot { scale: "css", filename: "chunk-N.png" }   // no fullPage
Step N by roughly the viewport height and repeat down the page. To inspect one
component, pass its selector as `target` instead of shooting the whole page.
"@
    }
    exit 0
}

if ($tool -eq 'Read') {
    $path = [string]$inp.file_path
    if (-not $path) { exit 0 }
    if ($path -notmatch '\.(png|jpg|jpeg|gif|bmp)$') { exit 0 }
    if ($path -match '\.small\.png$') { exit 0 }
    if (-not (Test-Path -LiteralPath $path)) { exit 0 }

    try {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($path)
    } catch { exit 0 }

    $longest = [Math]::Max($img.Width, $img.Height)
    if ($longest -le $LIMIT) { $img.Dispose(); exit 0 }

    $scale = $LIMIT / $longest
    $w = [Math]::Max(1, [int]($img.Width * $scale))
    $h = [Math]::Max(1, [int]($img.Height * $scale))
    $out = Join-Path ([IO.Path]::GetDirectoryName($path)) ([IO.Path]::GetFileNameWithoutExtension($path) + '.small.png')

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $w, $h)
    $g.Dispose(); $img.Dispose()
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    Block "BLOCKED: that image is oversized for the many-image limit. A downscaled copy was written to:`n$out`nRead that path instead. If detail is lost, re-shoot a smaller region rather than reading the original."
}

exit 0
