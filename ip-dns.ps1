# Put samba.txt and primary.txt in same folder as this script

# Modify Execution policy for the computer, Default=Restricted
Set-ExecutionPolicy RemoteSigned
cd c:\temp

# Get/set active ipv4 address and gateway
$ipc=gwmi -Class win32_networkadapterconfiguration | Where-Object {$_.ipenabled -eq $true}
$ip=$ipc.ipaddress[0]
$gw=$ipc.DefaultIPGateway
$ipc.EnableStatic($ip,"255.255.255.0")
$ipc.SetGateways($gw,1)

# Split then Join to get Network id - based on /24 mask 
$j=$ip.split(".")
$join= $j[0],$j[1],$j[2] -join "."

# Search samba.txt for match, assign samba ip/name/domain vars
$s=Get-Content c:\temp\samba.txt | Select-String -Pattern $join\s
$s=$s.tostring()
$s=$s.split(" ")
$net=$s[0]
$pdc_ip=$s[1]
$pdc_name=$s[2]
$dom=$s[3]

#Get/set primary and secundary DNS
$dns=Get-Content c:\temp\dns.txt | Select-String -Pattern $join\s
$dns=$dns.tostring()
$dns=$dns.split(" ")
$primary=$dns[1]
$secundary=$dns[2]
$dns= $dns[1], $dns[2]
$ipc.SetDNSServerSearchOrder($dns)


# Modify Hosts
If (Test-Path "C:\windows\system32\drivers\etc\hosts")
 {copy-item -force C:\WINDOWS\system32\drivers\etc\hosts -destination C:\WINDOWS\system32\drivers\etc\hosts.old;
 add-Content -force $env:windir\system32\drivers\etc\hosts -value ("$pdc_ip" + "     " + "$pdc_name")
 }
Else {write-host "Hosts file not found"}

# Add 2 reg entries for Win7/Samba domain compatibility
$LM= 'HKLM:\SYSTEM\CurrentControlSet\services\LanmanWorkstation\Parameters'
New-ItemProperty -Path $LM  -Name DomainCompatibilityMode -PropertyType DWord -Value 1 -ErrorAction:SilentlyContinue | Out-Null
New-ItemProperty -Path $LM  -Name DNSNameResolutionRequired -PropertyType DWord -Value 0 -ErrorAction:SilentlyContinue | Out-Null
Restart-Service Workstation -force
Start-Sleep -s 5

#Stop/disable Offline files, Com+ events, System Event notification service
Stop-Service EventSystem -force
#Stop-Service CscService
#Stop-Service SENS

foreach ($p in (get-wmiobject win32_service -filter "name='CscService' OR name='SENS'")) {if ($p.state -eq "running") `
{$p.StopService()}} ; {if($p.startmode -ne "disabled") {$p.ChangeStartMode("disabled")}}  | Out-Null -ErrorAction:SilentlyContinue

# Samba Domain joining
 function JoinDomain ([string]$Domain, [string]$user, [string]$Password) {
 $domainUser= $Domain + "\" + $User
 $OU= $null
 $computersystem= gwmi Win32_Computersystem
 $computerSystem.JoinDomainOrWorkgroup($Domain,$Password,$DomainUser,$OU,3)
 }
write-host -ForegroundColor blue -BackgroundColor white "Joining domain $dom..."
 
#if join succeeds, restart computer
 if (JoinDomain $dom admin pipadmin) {Write-host -ForegroundColor blue -BackgroundColor white "Successfully joined $dom domain!"}
 Start-Sleep 3


 
 
 
