param([string]$DevEcoHome = 'D:\Huawei\DevEco Studio', [ValidateSet('sync','build','test')][string]$Task = 'build')
$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
$env:NODE_HOME = Join-Path $DevEcoHome 'tools\node'
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:NODE_HOME + ';' + $env:PATH
$node = Join-Path $env:NODE_HOME 'node.exe'
$hvigor = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.js'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  if ($Task -eq 'sync') { & $node $hvigor --sync --no-daemon }
  elseif ($Task -eq 'test') { & $node $hvigor test -p module=entry -p coverage=false --no-daemon }
  else { & $node $hvigor --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon }
  if ($LASTEXITCODE -ne 0) { throw "Hvigor failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }
