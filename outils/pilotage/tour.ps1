# Tour de vue d'Henry en huit images (six pas font un tour complet), assemblées en une planche
# securite\captures\<Nom>.png. Le jeu doit être lancé ; il est mis au premier plan.
param([string]$Nom = "tour")
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")
Jeu-Au-Premier-Plan | Out-Null
$dir = Join-Path $script:Travail $Nom
New-Item -ItemType Directory -Force $dir | Out-Null; Remove-Item "$dir\*.png" -ErrorAction SilentlyContinue
foreach ($i in 0..7) {
  if ($i -gt 0) { foreach ($k in 1..10) { [Cycle.U]::mouse_event(0x0001, 40, 0, 0, [System.UIntPtr]::Zero); Start-Sleep -Milliseconds 15 } }
  Start-Sleep -Milliseconds 700; Capture ("{0}\{1:D2}" -f $Nom, $i) | Out-Null
}
$fichiers = Get-ChildItem "$dir\*.png" | Sort-Object Name
$w = 640; $hh = 360; $planche = New-Object System.Drawing.Bitmap ($w*2), ($hh*4)
$g = [System.Drawing.Graphics]::FromImage($planche); $police = New-Object System.Drawing.Font "Arial", 14, ([System.Drawing.FontStyle]::Bold); $i = 0
foreach ($f in $fichiers) { $im = [System.Drawing.Image]::FromFile($f.FullName); $x = ($i % 2)*$w; $y = [math]::Floor($i/2)*$hh; $g.DrawImage($im, $x, $y, $w, $hh); $g.FillRectangle([System.Drawing.Brushes]::Black, $x, $y, 40, 22); $g.DrawString($f.BaseName, $police, [System.Drawing.Brushes]::Yellow, $x+2, $y+1); $im.Dispose(); $i++ }
$chemin = Join-Path $script:Travail "$Nom.png"
$planche.Save($chemin, [System.Drawing.Imaging.ImageFormat]::Png)
"planche : $chemin"
