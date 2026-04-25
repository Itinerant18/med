$status = Get-MpComputerStatus
Write-Output "SmartAppControlState: $($status.SmartAppControlState)"
Write-Output "AMRunningMode:        $($status.AMRunningMode)"
Write-Output "IsTamperProtected:    $($status.IsTamperProtected)"
Write-Output "AntivirusEnabled:     $($status.AntivirusEnabled)"

Write-Output ""
Write-Output "--- Recent block events (last 25) ---"
Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 25 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, Message -AutoSize | Out-String -Width 200

Write-Output ""
Write-Output "--- Recent CodeIntegrity (WDAC) events (last 25) ---"
Get-WinEvent -LogName "Microsoft-Windows-CodeIntegrity/Operational" -MaxEvents 25 -ErrorAction SilentlyContinue | Where-Object { $_.LevelDisplayName -ne 'Information' } | Format-Table TimeCreated, Id, LevelDisplayName -AutoSize | Out-String -Width 200
