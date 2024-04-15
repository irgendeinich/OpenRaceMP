get-content .env | foreach {
  $name, $value = $_.split('=')
  set-content env:\$name $value
}

Write-Output $Env:BEAM_NG_MODS_FOLDER
