# crear_llave_firma.ps1
# ---------------------------------------------------------------------------
# Crea la LLAVE DE FIRMA de Hanzi Dojo. Se hace UNA SOLA VEZ en la vida de la
# app: todas las versiones futuras se firman con esta misma llave. Android
# solo instala una actualización encima de la anterior si viene firmada con la
# misma llave; si la llave se pierde, nadie podrá actualizar: tendrían que
# desinstalar (y perder su progreso si no lo exportaron).
#
# Qué hace:
#   1. Busca keytool (viene con Android Studio).
#   2. Te pide una contraseña y crea la llave en
#      Documentos\Hanzi Dojo - llave de firma\hanzi_dojo_lanzamiento.jks
#      (si ya existe, NO la toca).
#   3. Escribe android\key.properties (no se sube a GitHub) para que tus
#      compilaciones locales en modo release se firmen con ella.
#   4. Guarda la llave en los secretos del repositorio de GitHub (si tienes
#      la herramienta "gh" con sesión iniciada) para que el flujo
#      "Lanzamiento" publique APK firmados. Si no, te dice cómo hacerlo a mano.
#
# Cómo correrlo (PowerShell, desde la carpeta del proyecto):
#   powershell -ExecutionPolicy Bypass -File .\herramientas\crear_llave_firma.ps1
#
# DESPUÉS: copia la carpeta de la llave a una memoria USB y a tu nube, y guarda
# la contraseña en un gestor de contraseñas. Ver docs\publicar.md.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$Repo      = Split-Path -Parent $PSScriptRoot
$Carpeta   = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Hanzi Dojo - llave de firma'
$Jks       = Join-Path $Carpeta 'hanzi_dojo_lanzamiento.jks'
$Alias     = 'hanzi_dojo'
$KeyProps  = Join-Path $Repo 'android\key.properties'
$RepoGitHub = 'AbraKdabra1/hanzi_dojo'

function Paso($texto)  { Write-Host "`n== $texto ==" -ForegroundColor Cyan }
function Ok($texto)    { Write-Host "   OK  $texto" -ForegroundColor Green }
function Aviso($texto) { Write-Host "   !!  $texto" -ForegroundColor Yellow }
function Preguntar($texto) {
    $r = Read-Host "   $texto (s/n)"
    return $r -match '^(s|si|sí|y|yes)$'
}
function Texto($seguro) {
    $puntero = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($puntero) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($puntero) }
}
function Escribir-SinBom($ruta, $contenido) {
    [IO.File]::WriteAllText($ruta, $contenido, (New-Object Text.UTF8Encoding $false))
}

# ── 1. keytool ─────────────────────────────────────────────────────────────
Paso '1. Buscando keytool'
$candidatos = @()
if ($env:JAVA_HOME) { $candidatos += (Join-Path $env:JAVA_HOME 'bin\keytool.exe') }
$candidatos += 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
$candidatos += 'C:\Program Files\Android\Android Studio\jre\bin\keytool.exe'
if ($env:LOCALAPPDATA) { $candidatos += (Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr\bin\keytool.exe') }
$Keytool = $candidatos | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $Keytool) {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { $Keytool = $cmd.Source }
}
if (-not $Keytool) {
    throw 'No encontré keytool. Instala Android Studio (trae Java) o define la variable JAVA_HOME.'
}
Ok $Keytool

# ── 2. La llave ────────────────────────────────────────────────────────────
Paso '2. Llave de firma'
New-Item -ItemType Directory -Force -Path $Carpeta | Out-Null
if (Test-Path -LiteralPath $Jks) {
    Aviso "Ya existe $Jks"
    Aviso 'No se crea otra (perder la llave actual impediría actualizar la app).'
    $clave = Texto (Read-Host '   Escribe la contraseña de esa llave' -AsSecureString)
    & $Keytool -list -keystore $Jks -storepass $clave -alias $Alias | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'La contraseña no abre la llave existente.' }
    Ok 'Contraseña correcta'
} else {
    Write-Host '   Elige una contraseña larga (12+ caracteres). Guárdala en un gestor de'
    Write-Host '   contraseñas: sin ella la llave no sirve y no hay forma de recuperarla.'
    while ($true) {
        $clave = Texto (Read-Host '   Contraseña' -AsSecureString)
        $otra  = Texto (Read-Host '   Repítela' -AsSecureString)
        if ($clave -ne $otra) { Aviso 'No coinciden. Otra vez.'; continue }
        if ($clave.Length -lt 8) { Aviso 'Muy corta (mínimo 8). Otra vez.'; continue }
        break
    }
    & $Keytool -genkeypair -keystore $Jks -storetype PKCS12 -alias $Alias `
        -keyalg RSA -keysize 4096 -validity 10000 `
        -storepass $clave -keypass $clave `
        -dname 'CN=Hanzi Dojo, O=AbraKdabra, C=MX'
    if ($LASTEXITCODE -ne 0) { throw 'keytool no pudo crear la llave.' }
    Ok "Llave creada: $Jks"
    Escribir-SinBom (Join-Path $Carpeta 'LEEME.txt') @"
Llave de firma de Hanzi Dojo (com.abrakdabra.hanzidojo)

- Archivo: hanzi_dojo_lanzamiento.jks   (alias: $Alias, PKCS12, RSA 4096)
- Creada: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- La contraseña NO está aquí: búscala en tu gestor de contraseñas.

Guarda copias de esta carpeta en al menos dos lugares (memoria USB y nube).
Si se pierde la llave o la contraseña, las próximas versiones no se podrán
instalar como actualización. Nunca la subas a GitHub ni la compartas.
"@
}

$huella = (& $Keytool -list -v -keystore $Jks -storepass $clave -alias $Alias |
    Select-String 'SHA256:' | Select-Object -First 1).ToString().Trim()
Ok "Huella del certificado: $huella"

# ── 3. key.properties ──────────────────────────────────────────────────────
Paso '3. android\key.properties'
# En .properties la diagonal invertida es un escape: se usan diagonales normales.
$rutaJks = $Jks -replace '\\', '/'
Escribir-SinBom $KeyProps @"
storeFile=$rutaJks
storePassword=$clave
keyAlias=$Alias
keyPassword=$clave
"@
Ok "$KeyProps (está en .gitignore: no se sube)"
Aviso 'Tus próximas compilaciones release ya salen firmadas con esta llave.'
Aviso 'La PRIMERA vez que instales una así, Android pedirá desinstalar la versión'
Aviso 'anterior (firmada con la llave de depuración): EXPORTA tu progreso antes.'

# ── 4. Secretos de GitHub ──────────────────────────────────────────────────
Paso '4. Secretos del repositorio en GitHub'
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Jks))
$gh = Get-Command gh -ErrorAction SilentlyContinue
$hecho = $false
if ($gh) {
    & gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Preguntar "¿Guardar la llave en los secretos de $RepoGitHub con gh?")) {
        $base64 | & gh secret set LLAVE_BASE64 --repo $RepoGitHub
        & gh secret set LLAVE_CLAVE --repo $RepoGitHub --body $clave
        & gh secret set LLAVE_ALIAS --repo $RepoGitHub --body $Alias
        if ($LASTEXITCODE -eq 0) { Ok 'Secretos guardados'; $hecho = $true }
    }
}
if (-not $hecho) {
    $archivo = Join-Path $Carpeta 'llave_base64.txt'
    Escribir-SinBom $archivo $base64
    Aviso 'Hazlo a mano en GitHub: repositorio → Settings → Secrets and variables →'
    Aviso 'Actions → New repository secret. Crea estos tres:'
    Write-Host "     LLAVE_BASE64  = todo el contenido de $archivo"
    Write-Host '     LLAVE_CLAVE   = tu contraseña'
    Write-Host "     LLAVE_ALIAS   = $Alias"
    Aviso "Después BORRA $archivo (es la llave en forma de texto)."
}

# ── Listo ──────────────────────────────────────────────────────────────────
Paso 'Listo'
Write-Host @"
   Ahora, por favor:
   1. Copia la carpeta "$Carpeta"
      a una memoria USB y a tu nube (Google Drive, OneDrive…).
   2. Guarda la contraseña en un gestor de contraseñas.
   3. Para publicar una versión: ver docs\publicar.md (git tag v2.1.0 y push).
"@
if (Preguntar '¿Abrir la carpeta de la llave?') { Start-Process explorer.exe $Carpeta }
