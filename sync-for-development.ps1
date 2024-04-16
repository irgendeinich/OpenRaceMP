get-content .env | foreach {
  $name, $value = $_.split('=')
  set-content env:\$name $value
}

function create-7zip([String] $aDirectory, [String] $aZipfile) {
  [string]$pathToZipExe = "$($Env:ProgramFiles)\7-Zip\7z.exe";
  [Array]$arguments = "a", "-tzip", "$aZipfile", "$aDirectory\*", "-r";
  & $pathToZipExe $arguments;
}

Write-Output $Env:BEAM_NG_MODS_FOLDER

$unpackedModPath = Join-Path $Env:BEAM_NG_MODS_FOLDER '\unpacked\openracemp'

# Copy the client part to the mods folder for single player development.
# Copy-Item -Path .\Client\ -Destination $unpackedModPath -PassThru -Force -Recurse

# Copy the server part to the server folder
$serverPath = Join-Path $Env:BEAM_MP_SERVER_FOLDER '\Resources\Server\OpenRaceMP'
New-Item -Path $serverPath -ItemType Directory
Copy-Item -Path .\Server\* -Destination $serverPath -PassThru -Recurse -Force

# Prepare the file structure for a release.
Remove-Item '.\Release' -Recurse -Force
New-Item -Path '.\Release' -ItemType Directory
New-Item -Path '.\Release\Resources' -ItemType Directory
New-Item -Path '.\Release\Resources\Client' -ItemType Directory
New-Item -Path '.\Release\Resources\Server' -ItemType Directory
New-Item -Path '.\Release\Resources\Server\OpenRaceMP' -ItemType Directory

Copy-Item -Path .\Client\ -Destination '.\Release\openracemp' -PassThru -Force -Recurse
create-7zip '.\Release\openracemp' '.\Release\openracemp.zip' 

Copy-Item -Path '.\Release\openracemp.zip' -Destination '.\Release\Resources\Client' -PassThru -Force
Copy-Item -Path .\Server\* -Destination  '.\Release\Resources\Server\OpenRaceMP' -PassThru -Recurse -Force

$packedModPath = Join-Path $Env:BEAM_NG_MODS_FOLDER '\openracemp.zip'
Copy-Item -Path '.\Release\openracemp.zip' -Destination $packedModPath -PassThru -Force

Remove-Item '.\Release\openracemp.zip' -Recurse -Force
Remove-Item '.\Release\openracemp' -Recurse -Force
create-7zip '.\Release\' '.\Release\release.zip'
