# Pilotage du jeu pendant un essai (JoVenGer ne tape aucune commande) : touches envoyées au jeu, seulement s'il est
# au premier plan, et captures d'écran rangées dans securite\captures du dépôt (hors de git).
# S'emploie par « . outils\pilotage\touches.ps1 », puis Capture, Touche, Marcher, Reculer, Tourner.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ("Cycle.U" -as [type])) {
  Add-Type -Namespace Cycle -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h); [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int n); [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, System.UIntPtr e); [DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t); [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, System.UIntPtr e);'
}
$script:Travail = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))) "securite\captures"
New-Item -ItemType Directory -Force $script:Travail | Out-Null

function Jeu-Au-Premier-Plan {
  $p = Get-Process -Name KingdomCome -ErrorAction SilentlyContinue
  return ($p -and ([Cycle.U]::GetForegroundWindow() -eq $p.MainWindowHandle))
}

# Noms : Entree, Echap, Haut, Bas.
function Touche([string]$nom) {
  if (-not (Jeu-Au-Premier-Plan)) { throw "le jeu n'est pas au premier plan : touche « $nom » non envoyée" }
  $codes = @{ Entree = @(0x0D, 0); Echap = @(0x1B, 0); Haut = @(0x26, 1); Bas = @(0x28, 1) }
  $vk = $codes[$nom][0]; $fl = $codes[$nom][1]
  $sc = [byte][Cycle.U]::MapVirtualKey($vk, 0)
  [Cycle.U]::keybd_event($vk, $sc, $fl, [System.UIntPtr]::Zero); Start-Sleep -Milliseconds 80
  [Cycle.U]::keybd_event($vk, $sc, ($fl -bor 2), [System.UIntPtr]::Zero); Start-Sleep -Milliseconds 600
}

# Capture une zone de l'écran (coordonnées réelles) dans le dossier de travail ; sans zone, tout l'écran à demi-taille.
function Capture([string]$nom, [int[]]$zone) {
  $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $img = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($img); $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $img.Size)
  $chemin = Join-Path $script:Travail "$nom.png"
  if ($zone) { $img.Clone((New-Object System.Drawing.Rectangle $zone[0], $zone[1], $zone[2], $zone[3]), $img.PixelFormat).Save($chemin, [System.Drawing.Imaging.ImageFormat]::Png) }
  else { $p = New-Object System.Drawing.Bitmap $img, ([int]($b.Width/2)), ([int]($b.Height/2)); $p.Save($chemin, [System.Drawing.Imaging.ImageFormat]::Png); $p.Dispose() }
  $g.Dispose(); $img.Dispose()
  return $chemin
}

# Henry avance (touche physique « avancer », code 0x11) pendant « secondes » ; avec -Course, Maj est tenue.
function Marcher([double]$secondes, [switch]$Course) {
  if (-not (Jeu-Au-Premier-Plan)) { throw "le jeu n'est pas au premier plan : Henry ne bouge pas" }
  if ($Course) { [Cycle.U]::keybd_event(0, 0x2A, 0x8, [System.UIntPtr]::Zero) }
  [Cycle.U]::keybd_event(0, 0x11, 0x8, [System.UIntPtr]::Zero)
  Start-Sleep -Milliseconds ([int]($secondes * 1000))
  [Cycle.U]::keybd_event(0, 0x11, 0xA, [System.UIntPtr]::Zero)
  if ($Course) { [Cycle.U]::keybd_event(0, 0x2A, 0xA, [System.UIntPtr]::Zero) }
  Start-Sleep -Milliseconds 600
}

# Tourne la vue d'Henry : pas positifs vers la droite (10 pas = un huitième de tour environ) ; « haut » négatif lève la vue.
function Tourner([int]$pas, [int]$haut = 0) {
  if (-not (Jeu-Au-Premier-Plan)) { throw "le jeu n'est pas au premier plan : la vue ne tourne pas" }
  $n = [Math]::Abs($pas); $dx = if ($pas -ge 0) { 40 } else { -40 }
  foreach ($k in 1..([Math]::Max($n,1))) { if ($n -gt 0) { [Cycle.U]::mouse_event(0x0001, $dx, 0, 0, [System.UIntPtr]::Zero) }; Start-Sleep -Milliseconds 15 }
  $m = [Math]::Abs($haut); $dy = if ($haut -ge 0) { 40 } else { -40 }
  if ($m -gt 0) { foreach ($k in 1..$m) { [Cycle.U]::mouse_event(0x0001, 0, $dy, 0, [System.UIntPtr]::Zero); Start-Sleep -Milliseconds 15 } }
  Start-Sleep -Milliseconds 600
}

# Henry recule (touche physique « reculer », code 0x1F) pendant « secondes ».
function Reculer([double]$secondes) {
  if (-not (Jeu-Au-Premier-Plan)) { throw "le jeu n'est pas au premier plan : Henry ne bouge pas" }
  [Cycle.U]::keybd_event(0, 0x1F, 0x8, [System.UIntPtr]::Zero)
  Start-Sleep -Milliseconds ([int]($secondes * 1000))
  [Cycle.U]::keybd_event(0, 0x1F, 0xA, [System.UIntPtr]::Zero)
  Start-Sleep -Milliseconds 600
}
