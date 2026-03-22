param(
    [string]$TargetDevice = "",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

function Ensure-JavaHome {
    if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
        $candidates = @(
            "D:\Android\Android Studio\jbr",
            "C:\Program Files\Android\Android Studio\jbr",
            "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
        )

        foreach ($candidate in $candidates) {
            if ($candidate -and (Test-Path $candidate)) {
                $env:JAVA_HOME = $candidate
                $env:Path = "$($env:JAVA_HOME)\bin;$env:Path"
                Write-Host "JAVA_HOME configurado a Android Studio JBR: $env:JAVA_HOME"
                return
            }
        }

        throw "JAVA_HOME no está configurado. Configúralo primero o instala Android Studio en la ruta por defecto."
    }
}

function Disable-AndroidAnimations {
    try {
        & adb shell settings put global window_animation_scale 0 | Out-Null
        & adb shell settings put global transition_animation_scale 0 | Out-Null
        & adb shell settings put global animator_duration_scale 0 | Out-Null
        Write-Host "Animaciones Android desactivadas (window/transition/animator = 0)."
    }
    catch {
        Write-Host "No se pudieron ajustar animaciones (adb no disponible o sin dispositivo)."
    }
}

Set-Location "$PSScriptRoot\.."

Ensure-JavaHome

if ($Clean) {
    Write-Host "Ejecutando flutter clean..."
    & flutter clean
}

Write-Host "Descargando/actualizando dependencias..."
& flutter pub get

Disable-AndroidAnimations

$runArgs = @("run", "--fast-start")
if ($TargetDevice -and $TargetDevice.Trim() -ne "") {
    $runArgs += @("-d", $TargetDevice)
}

Write-Host "Iniciando app en modo rápido: flutter $($runArgs -join ' ')"
& flutter @runArgs
