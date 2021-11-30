<#
    .NOTES
    ===========================================================================
    Created by:  Gary Blake - Senior Staff Solutions Architect
    Date:   11/27/2021
    Copyright 2021 VMware, Inc.
    ===========================================================================
    
    .SYNOPSIS
    Configure Integration of vRealize Log Insight for Intelligent Logging and Analytics

    .DESCRIPTION
    The ilaConfigureVrealizeLogInsight.ps1 provides a single script to configure the intergration of vRealize Log Insight as
    defined by the Intelligent Logging and Analytics Validated Solution

    .EXAMPLE
    ilaConfigureVrealizeLogInsight.ps1 -sddcManagerFqdn sfo-vcf01.sfo.rainpole.io -sddcManagerUser administrator@vsphere.local -sddcManagerPass VMw@re1! -workbook F:\vvs\PnP.xlsx -filePath F:\vvs
    This example performs the integration configuration of vRealize Log Insight using the parameters provided within the Planning and Preparation Workbook
#>

Param (
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$sddcManagerFqdn,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$sddcManagerUser,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$sddcManagerPass,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$workbook,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$filePath
)

Clear-Host; Write-Host ""

Start-SetupLogFile -Path $filePath -ScriptName $MyInvocation.MyCommand.Name
Write-LogMessage -Type INFO -Message "Starting the Process of Integration Configuration of vRealize Log Insight Based on Intelligent Logging and Analytics for VMware Cloud Foundation" -Colour Yellow
Write-LogMessage -Type INFO -Message "Setting up the log file to path $logfile"


# Perform validation on inputs
Try {
    Write-LogMessage -Type INFO -Message "Checking a Connection to SDDC Manager: $sddcManagerFqdn"
    if (!(Test-Connection -ComputerName $sddcManagerFqdn -Count 1 -ErrorAction SilentlyContinue)) {
        Write-LogMessage -Type ERROR -Message "Unable to connect to server: $sddcManagerFqdn, check details and try again" -Colour Red
        Break
    }
    else {
        Write-LogMessage -Type INFO -Message "Connection to SDDC Manager: $sddcManagerFqdn was Successful"
    }
    Write-LogMessage -Type INFO -Message "Checking Existance of Planning and Preparation Workbook: $workbook"
    if (!(Test-Path $workbook )) {
        Write-LogMessage -Type ERROR -Message "Unable to Find Planning and Preparation Workbook: $workbook, check details and try again" -Colour Red
        Break
    }
    else {
        Write-LogMessage -Type INFO -Message "Found Planning and Preparation Workbook: $workbook"
    }
}
Catch {
    Debug-CatchWriter -object $_
}

Try {
    Write-LogMessage -Type INFO -Message "Attempting to connect to VMware Cloud Foundation to Gather System Details"
    $StatusMsg = Request-VCFToken -fqdn $sddcManagerFqdn -username $sddcManagerUser -password $sddcManagerPass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message $StatusMsg } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
    if ($accessToken) {
        Write-LogMessage -Type INFO -Message "Gathering Details from SDDC Manager Inventory and Extracting Worksheet Data from the Excel Workbook"

        Write-LogMessage -type INFO -message "Opening the Excel Workbook: $Workbook"
        $pnpWorkbook = Open-ExcelPackage -Path $Workbook

        Write-LogMessage -type INFO -message "Checking Valid Planning and Prepatation Workbook Provided"
        if ( ($pnpWorkbook.Workbook.Names["vcf_version"].Value -ne "v4.3.x") ) {
            Write-LogMessage -type INFO -message "Planning and Prepatation Workbook Provided Not Supported" -colour Red 
            Break
        }

        $sddcDomainName                         = $pnpWorkbook.Workbook.Names["mgmt_sddc_domain"].Value
        $sddcWldDomainName                      = $pnpWorkbook.Workbook.Names["wld_sddc_domain"].Value
        $domain                                 = $pnpWorkbook.Workbook.Names["parent_dns_zone"].Value

        $exportName                             = "ILA-VRLI"
        $vmNameNode1                            = $pnpWorkbook.Workbook.Names["xreg_wsa_nodea_hostname"].Value
        $vmNameNode2                            = $pnpWorkbook.Workbook.Names["xreg_wsa_nodeb_hostname"].Value
        $vmNameNode3                            = $pnpWorkbook.Workbook.Names["xreg_wsa_nodec_hostname"].Value
        $vmRootPass                             = $pnpWorkbook.Workbook.Names["vrslcm_xreg_env_password"].Value
        $vidmVmList                             = "$vmNameNode1.$domain","$vmNameNode2.$domain","$vmNameNode2.$domain"
        $photonVmList                           = "$($pnpWorkbook.Workbook.Names["sddc_mgr_hostname"].Value).$domain","$($pnpWorkbook.Workbook.Names["xreg_vrslcm_hostname"].Value).$domain","$vmNameNode1.$domain","$vmNameNode2.$domain","$vmNameNode2.$domain"       
    }
    else {
        Write-LogMessage -Type ERROR -Message "Unable to connect to SDDC Manager $server" -Colour Red
        Exit
    }
}
Catch {
    Debug-CatchWriter -object $_
}

Try {
    # Connect a VI Workload Domain to vRealize Log Insight
    Write-LogMessage -Type INFO -Message "Connect a VI Workload Domain to vRealize Log Insight"
    $StatusMsg = Register-vRLIWorkloadDomain -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -domain $sddcWldDomainName -status ENABLED -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

    # Configure the NSX Edge Nodes to Forward Log Events to vRealize Log Insight
    Write-LogMessage -Type INFO -Message "Configure the NSX Edge Nodes to Forward Log Events to vRealize Log Insight"
    $StatusMsg = Set-vRLISyslogEdgeCluster -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -domain $sddcDomainName -exportname $exportName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
    $StatusMsg = Set-vRLISyslogEdgeCluster -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -domain $sddcWldDomainName -exportname $exportName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

    # Download, Install and Configure the vRealize Log Insight Agent on the Clustered Workspace ONE Access Nodes
    Write-LogMessage -Type INFO -Message "Download, Install and Configure the vRealize Log Insight Agent on the Clustered Workspace ONE Access Nodes"
    $StatusMsg = Install-vRLIPhotonAgent -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -vmName $vmNameNode1 -vmRootPass $vmRootPass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
    $StatusMsg = Install-vRLIPhotonAgent -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -vmName $vmNameNode2 -vmRootPass $vmRootPass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
    $StatusMsg = Install-vRLIPhotonAgent -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -vmName $vmNameNode3 -vmRootPass $vmRootPass -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

    # Configure the vRealize Log Insight Agent Group for the Clustered Workspace ONE Access
    Write-LogMessage -Type INFO -Message "Configure the vRealize Log Insight Agent Group for the Clustered Workspace ONE Access"
    $StatusMsg = Add-vRLIAgentGroup -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -agentGroupType wsa -criteria $vidmVmList -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
    
    # Create a vRealize Log Insight Photon OS Agent Group for the Management Nodes
    Write-LogMessage -Type INFO -Message "Create a vRealize Log Insight Photon OS Agent Group for the Management Nodes"
    $StatusMsg = Add-vRLIAgentGroup -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -agentGroupType photon -criteria $photonVmList -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
    if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
}
Catch {
    Debug-CatchWriter -object $_
}