# ===== CONFIG =====
$csvPath = "/home/erik/monitoring/esxi_hosts.csv"
$outputPath = "/var/lib/node_exporter/textfile_collector/esxi_vm_inventory.prom"

$user = "monitor"
$pass = "123!@#qweQWE"

# ===== INIT =====
Import-Module VMware.PowerCLI

$securePass = ConvertTo-SecureString $pass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePass)

# Leeg output bestand
"" | Out-File $outputPath

# ===== LOOP =====
$hosts = Import-Csv $csvPath
write-host "gevonden hosts: "$hosts

foreach ($entry in $hosts) {
    $hostip = $entry.Host
    write-host "bezig met: " $entry.host, $hostip

    try {
        $vi = Connect-VIServer -Server $hostIp -Credential $cred # -ErrorAction Stop

        $vmlist = Get-VM
        write-host "op: " $hostip " vm's gevonden: " $vmlist
        # totaal aantal VM's
        $totalVMs = $vmlist.Count

        # powered on/off
        $poweredOn = ($vmlist | Where-Object {$_.PowerState -eq "PoweredOn"}).Count
        $poweredOff = ($vmlist | Where-Object {$_.PowerState -eq "PoweredOff"}).Count

        # schrijf host metrics
        Add-Content $outputPath "esxi_vm_total{host=`"$hostip`"} $totalVMs"
        Add-Content $outputPath "esxi_vm_powered_on{host=`"$hostip`"} $poweredOn"
        Add-Content $outputPath "esxi_vm_powered_off{host=`"$hostip`"} $poweredOff"

        # per VM metrics
        foreach ($vm in $vmlist) {
            $vmname = $vm.Name.Replace(" ", "_")
	    write-host "vm info :" $vmname, $cpu

            $cpu = $vm.NumCpu
            $mem = $vm.MemoryMB

            $power = if ($vm.PowerState -eq "PoweredOn") {1} else {0}

            Add-Content $outputPath "esxi_vm_cpu{host=`"$hostip`",vm=`"$vmname`"} $cpu"
            Add-Content $outputPath "esxi_vm_memory_mb{host=`"$hostip`",vm=`"$vmname`"} $mem"
            Add-Content $outputPath "esxi_vm_power_state{host=`"$hostip`",vm=`"$vmname`"} $power"
        }

        Disconnect-VIServer -Server $hostIp -Confirm:$false

    } catch {
        # host down of fout → markeer
	write-host "error gevonden op: "$hostip
        Add-Content $outputPath "esxi_host_up{host=`"$hostip`"} 0"
        continue
    }

    # host bereikbaar
    Add-Content $outputPath "esxi_host_up{host=`"$hostip`"} 1"
}
