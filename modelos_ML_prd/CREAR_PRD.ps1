$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "crear_prd.py"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python no está disponible en PATH." -ForegroundColor Red
    exit 1
}

# Si el paquete se extrajo dentro de D:\pry_dataloto\modelos_ML, usa esa carpeta.
# Si no, el instalador usa D:\pry_dataloto\modelos_ML por defecto.
python $PythonScript @args
exit $LASTEXITCODE
