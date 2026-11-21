# Заставка FT2: 360x288, 256-цветный режим TS-Config. Реально - 64 цвета: по 4 уровня DAC
# на канал (0/8/16/24 из 31, без ШИМ - иначе полосы на Evo без VDAC). Дизеринга нет:
# хром - чёткими ступенями, каждая точка - ближайший цвет.
# Выход (в каталог OutDir):
#   splash3..5.bin - страницы #23..#25 = строки экрана 96..191 (полоса с надписью): строка 512
#                    байт (360 точек + пусто), 32 строки на страницу. Остальное - фон, его заливает код;
#   splash_pal.bin - 64 слова CRAM для цветов 64..127 (точка = 64 + r*16 + g*4 + b);
#   splash.png     - как будет на экране (превью).
param([string]$OutDir = "srs/splash")
Add-Type -AssemblyName System.Drawing
$W = 360; $H = 288; $P0 = 3; $NP = 3          # в файлы - страницы 3..5 (строки 96..191)
$lv = @(0, 66, 132, 197)                       # уровни DAC -> 8 бит
function C([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($lv[$r], $lv[$g], $lv[$b]) }
$bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear((C 0 0 1))                            # фон - тёмно-синий, ровный
$g.SmoothingMode = 'None'
$g.TextRenderingHint = 'SingleBitPerPixelGridFit'

# заголовок: путь по шрифту, на ширину 330
$fam = New-Object System.Drawing.FontFamily "Arial Black"
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddString("FAST TRACKER 2", $fam, [int][System.Drawing.FontStyle]::Regular, 60, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
$b = $path.GetBounds()
$s = 330 / $b.Width
$m = New-Object System.Drawing.Drawing2D.Matrix
$m.Translate(15, 104)
$m.Scale($s, ($s * 1.15))
$m.Translate(-$b.X, -$b.Y)
$path.Transform($m)
$b = $path.GetBounds()
$top = $b.Y; $hh = $b.Height
# тень - сплошная чёрная, со сдвигом
$sh = $path.Clone(); $ms = New-Object System.Drawing.Drawing2D.Matrix; $ms.Translate(4, 4); $sh.Transform($ms)
$g.FillPath((New-Object System.Drawing.SolidBrush (C 0 0 0)), $sh)
# хром ступенями: белый верх, светлый, тёмная полоса, светлый низ
$bands = @(@(0.00, (C 3 3 3)), @(0.34, (C 2 2 3)), @(0.50, (C 1 1 2)), @(0.62, (C 2 2 2)), @(0.86, (C 3 3 3)))
$g.SetClip($path)
for ($i = 0; $i -lt $bands.Count; $i++) {
  $y0 = $top + $hh * $bands[$i][0]
  if ($i + 1 -lt $bands.Count) { $y1 = $top + $hh * $bands[$i + 1][0] } else { $y1 = $top + $hh + 1 }
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $bands[$i][1]), ($b.X - 1), [float]$y0, ($b.Width + 2), [float]($y1 - $y0))
}
$g.ResetClip()
$g.DrawPath((New-Object System.Drawing.Pen (C 0 0 1), 1), $path)   # контур - цветом фона: буквы чётче

# подписи
$f2 = New-Object System.Drawing.Font "Arial", 11, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$gray = New-Object System.Drawing.SolidBrush (C 2 2 3)
$g.DrawString("v2.01b", $f2, $gray, 15, ($b.Bottom + 12))
$g.DrawString("by Orion/DR", $f2, $gray, 15, ($b.Bottom + 26))

# полосы Спектрума: маленькие, справа под надписью, 45 градусов
$cols = @((C 3 0 0), (C 3 3 0), (C 0 3 0), (C 0 3 3))
$yb = [int]($b.Bottom + 40); $yt = $yb - 26
for ($i = 0; $i -lt 4; $i++) {
  $x = 270 + $i * 8
  $pts = @((New-Object System.Drawing.PointF $x, $yb), (New-Object System.Drawing.PointF ($x + 8), $yb),
           (New-Object System.Drawing.PointF ($x + 8 + 26), $yt), (New-Object System.Drawing.PointF ($x + 26), $yt))
  $g.FillPolygon((New-Object System.Drawing.SolidBrush $cols[$i]), $pts)
}
$g.Dispose()

# каждая точка - ближайший из 64 цветов
New-Item -ItemType Directory -Force $OutDir | Out-Null; $OutDir = (Resolve-Path $OutDir).Path
$pages = @(); for ($p = 0; $p -lt 9; $p++) { $pages += ,(New-Object byte[] 16384) }
$prev = New-Object System.Drawing.Bitmap $W, $H
for ($y = 0; $y -lt $H; $y++) {
  for ($x = 0; $x -lt $W; $x++) {
    $c = $bmp.GetPixel($x, $y)
    $r = [int][math]::Round($c.R / 66.0); if ($r -gt 3) { $r = 3 }
    $gg = [int][math]::Round($c.G / 66.0); if ($gg -gt 3) { $gg = 3 }
    $bb = [int][math]::Round($c.B / 66.0); if ($bb -gt 3) { $bb = 3 }
    $pages[[math]::Floor($y / 32)][($y % 32) * 512 + $x] = [byte](64 + $r * 16 + $gg * 4 + $bb)
    $prev.SetPixel($x, $y, (C $r $gg $bb))
  }
}
for ($p = $P0; $p -lt $P0 + $NP; $p++) { [IO.File]::WriteAllBytes((Join-Path $OutDir "splash$p.bin"), $pages[$p]) }
$pal = New-Object byte[] 128
for ($i = 0; $i -lt 64; $i++) {
  $r = [math]::Floor($i / 16); $gg = [math]::Floor($i / 4) % 4; $bb = $i % 4
  $w = ($r * 8 -shl 10) -bor ($gg * 8 -shl 5) -bor ($bb * 8)
  $pal[$i * 2] = [byte]($w -band 255); $pal[$i * 2 + 1] = [byte]($w -shr 8)
}
[IO.File]::WriteAllBytes((Join-Path $OutDir "splash_pal.bin"), $pal)
$ms2 = New-Object System.IO.MemoryStream; $prev.Save($ms2, [System.Drawing.Imaging.ImageFormat]::Png)
[IO.File]::WriteAllBytes((Join-Path $OutDir "splash.png"), $ms2.ToArray())
"ok"
