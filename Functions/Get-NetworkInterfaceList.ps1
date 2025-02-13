## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Get-NetworkInterfaceList
Function Get-NetworkInterfaceList
    {
        <#
          .SYNOPSIS
          Returns a list of the network interface(s) available on the device this function is being executed on.
          
          .DESCRIPTION
          Slightly more detailed description of what your function does
          
          .PARAMETER InterfaceTypeExpression
          A valid regular expression that will allow for filtering the available network interface(s) based on their interface type.

          .PARAMETER OperationalStatusExpression
          A valid regular expression that will allow for filtering the available network interface(s) based on their operational status.
          
          .EXAMPLE
          Get-NetworkInterfaceList

          .EXAMPLE
          $GetNetworkInterfaceListParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	          $GetNetworkInterfaceListParameters.InterfaceTypeExpression = "(.*Ethernet.*)|(.*Wireless.*)"
	          $GetNetworkInterfaceListParameters.OperationalStatusExpression = "(^Up$)"
	          $GetNetworkInterfaceListParameters.ContinueOnError = $False
	          $GetNetworkInterfaceListParameters.Verbose = $True
	          $GetNetworkInterfaceListParameters.ErrorAction = [System.Management.Automation.Actionpreference]::Stop

          $GetNetworkInterfaceListResult = Get-NetworkInterfaceList @GetNetworkInterfaceListParameters

          Write-Output -InputObject ($GetNetworkInterfaceListResult)
  
          .NOTES
          Get Network Interface Types - '@(' + (([System.Enum]::GetNames('System.Net.NetworkInformation.NetworkInterfaceType') | Sort-Object | ForEach-Object {"'$($_)'"}) -Join ', ') + ')'

          Network Interface Type List - 'AsymmetricDsl', 'Atm', 'BasicIsdn', 'Ethernet', 'Ethernet3Megabit', 'FastEthernetFx', 'FastEthernetT', 'Fddi', 'GenericModem', 'GigabitEthernet', 'HighPerformanceSerialBus', 'IPOverAtm', 'Isdn', 'Loopback', 'MultiRateSymmetricDsl', 'Ppp', 'PrimaryIsdn', 'RateAdaptDsl', 'Slip', 'SymmetricDsl', 'TokenRing', 'Tunnel', 'Unknown', 'VeryHighSpeedDsl', 'Wireless80211', 'Wman', 'Wwanpp', 'Wwanpp2'

          Get Operational Status List - '@(' + (([System.Enum]::GetNames('System.Net.NetworkInformation.OperationalStatus') | Sort-Object | ForEach-Object {"'$($_)'"}) -Join ', ') + ')'
          
          Operational Status List - 'Dormant', 'Down', 'LowerLayerDown', 'NotPresent', 'Testing', 'Unknown', 'Up'
       
          .LINK
          https://learn.microsoft.com/en-us/dotnet/api/system.net.networkinformation
        #>
        
        [CmdletBinding(ConfirmImpact = 'Low', DefaultParameterSetName = '__AllParameterSets', HelpURI = 'https://learn.microsoft.com/en-us/dotnet/api/system.net.networkinformation', PositionalBinding = $True)]
       
        Param
          (        
              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Regex]$InterfaceTypeExpression,
                
              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Regex]$OperationalStatusExpression,
                                            
              [Parameter(Mandatory=$False)]
              [Switch]$ContinueOnError        
          )
                    
        Begin
          {

              
              Try
                {
                    $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
                    [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
                    $DateTimeMessageFormat = 'MM/dd/yyyy HH:mm:ss.FFF'  ###03/23/2022 11:12:48.347###
                    [ScriptBlock]$GetCurrentDateTimeMessageFormat = {(Get-Date).ToString($DateTimeMessageFormat)}
                    $DateFileFormat = 'yyyyMMdd'  ###20190403###
                    [ScriptBlock]$GetCurrentDateFileFormat = {(Get-Date).ToString($DateFileFormat)}
                    $DateTimeFileFormat = 'yyyyMMdd_HHmmss'  ###20190403_115354###
                    [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
                    $TextInfo = (Get-Culture).TextInfo
                    $LoggingDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'    
                      $LoggingDetails.Add('LogMessage', $Null)
                      $LoggingDetails.Add('WarningMessage', $Null)
                      $LoggingDetails.Add('ErrorMessage', $Null)
                    $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
                      $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

                    [ScriptBlock]$ErrorHandlingDefinition = {
                                                                $ErrorMessageList = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $ErrorMessageList.Add('Message', $_.Exception.Message)
                                                                  $ErrorMessageList.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                                                  $ErrorMessageList.Add('Script', $_.InvocationInfo.ScriptName)
                                                                  $ErrorMessageList.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                                                  $ErrorMessageList.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                                                  $ErrorMessageList.Add('Code', $_.InvocationInfo.Line.Trim())

                                                                ForEach ($ErrorMessage In $ErrorMessageList.GetEnumerator())
                                                                  {
                                                                      $LoggingDetails.ErrorMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) -  ERROR: $($ErrorMessage.Key): $($ErrorMessage.Value)"
                                                                      Write-Warning -Message ($LoggingDetails.ErrorMessage)
                                                                  }

                                                                Switch (($ContinueOnError.IsPresent -eq $False) -or ($ContinueOnError -eq $False))
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {                  
                                                                            Throw
                                                                        }
                                                                  }
                                                            }
                    
                    #Determine the date and time we executed the function
                      $FunctionStartTime = (Get-Date)
                    
                    [String]$FunctionName = $MyInvocation.MyCommand
                    [System.IO.FileInfo]$InvokingScriptPath = $MyInvocation.PSCommandPath
                    [System.IO.DirectoryInfo]$InvokingScriptDirectory = $InvokingScriptPath.Directory.FullName
                    [System.IO.FileInfo]$FunctionPath = "$($InvokingScriptDirectory.FullName)\Functions\$($FunctionName).ps1"
                    [System.IO.DirectoryInfo]$FunctionDirectory = "$($FunctionPath.Directory.FullName)"
                    
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is beginning. Please Wait..."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      
                    [String[]]$AvailableScriptParameters = (Get-Command -Name ($FunctionName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Available Function Parameter(s) = $($AvailableScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of $($FunctionName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                        
                    #Create an object that will contain the functions output.
                      $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

                    #Set default parameter value(s)
                      Switch ($True)
                        {
                            {([String]::IsNullOrEmpty($InterfaceTypeExpression) -eq $True) -or ([String]::IsNullOrWhiteSpace($InterfaceTypeExpression) -eq $True)}
                              {
                                  [Regex]$InterfaceTypeExpression = '(.*)'
                              }

                            {([String]::IsNullOrEmpty($OperationalStatusExpression) -eq $True) -or ([String]::IsNullOrWhiteSpace($OperationalStatusExpression) -eq $True)}
                              {
                                  [Regex]$OperationalStatusExpression = '(.*)'
                              }
                        }

                    #Define additional variables
                      $AddressFamilyTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                        $AddressFamilyTable.IPv4 = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $AddressFamilyTable.IPv4.Add('InterNetwork')
                        $AddressFamilyTable.IPv6 = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $AddressFamilyTable.IPv6.Add('InterNetworkV6')

                    $NetworkAdapterConfigurationClass = Get-CIMInstance -Namespace 'Root\CIMv2' -ClassName 'Win32_NetworkAdapterConfiguration' -Property @('*') -Verbose:$False
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
              Finally
                {
                    
                }
          }

        Process
          {           
              Try
                {  
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to get the list of available network adapter(s). Please Wait..." 
                    Write-Verbose -Message ($LoggingDetails.LogMessage)
                                    
                    #region Network Adapter Information
                      Switch ([System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable())
                        {
                            {($_ -eq $True)}
                              {
                                  $LogMessage = "Attempting to enumerate network interface(s). Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)"
    
                                  $NetworkInterfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {($_.NetworkInterfaceType -imatch $InterfaceTypeExpression) -and ($_.OperationalStatus -imatch $OperationalStatusExpression)}

                                  $NetworkInterfacesCount = ($NetworkInterfaces | Measure-Object).Count

                                  $LogMessage = "Found $($NetworkInterfacesCount) available network interface(s) with an interface type matching `"$($InterfaceTypeExpression)`" and an operational status matching `"$($OperationalStatusExpression)`"."
                                  Write-Verbose -Message "$($LogMessage)"

                                  :NetworkInterfaceLoop ForEach ($NetworkInterface In $NetworkInterfaces)
                                    {                                        
                                        $NetworkInterfaceProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                          $NetworkInterfaceProperties.InterfaceName = $Null                  
                                          $NetworkInterfaceProperties.Type = $Null
                                          $NetworkInterfaceProperties.Status = $Null  
                                          $NetworkInterfaceProperties.Speed = 0   
                                          $NetworkInterfaceProperties.MACAddress = $Null
                                          $NetworkInterfaceProperties.IPv4DHCPServer = $Null
                                          $NetworkInterfaceProperties.IPv4Address = $Null
                                          $NetworkInterfaceProperties.IPv4Gateway = $Null
                                          $NetworkInterfaceProperties.IPv4SubnetMask = $Null
                                          $NetworkInterfaceProperties.IPv4PrefixLength = 0
                                          $NetworkInterfaceProperties.IPv4DNSServers = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                          $NetworkInterfaceProperties.IPv6Address = $Null
                                          $NetworkInterfaceProperties.DNSEnabled = $Null
                                          $NetworkInterfaceProperties.DynamicDNSEnabled = $Null
                                          $NetworkInterfaceProperties.DNSSuffix = $Null
                                          $NetworkInterfaceProperties.Description = $Null
                                          $NetworkInterfaceProperties.DNSServerSearchOrder = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                          $NetworkInterfaceProperties.DNSDomainSuffixSearchOrder = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                          $NetworkInterfaceProperties.ID = $Null
                                
                                        $NetworkInterfaceProperties.InterfaceName = $NetworkInterface.Name
                                        $NetworkInterfaceProperties.Description = $NetworkInterface.Description
                                        $NetworkInterfaceProperties.Type = $NetworkInterface.NetworkInterfaceType -As [String]
                                        $NetworkInterfaceProperties.Status = $NetworkInterface.OperationalStatus -As [String]
                                        $NetworkInterfaceProperties.Speed = Try {($NetworkInterface.Speed / 1000000) -As [Int]} Catch {0 -As [Int]}
                                        $NetworkInterfaceProperties.ID = $NetworkInterface.ID
                                                    
                                        $NetworkInterfaceMACAddress = If ($NetworkInterface.GetPhysicalAddress() -imatch '.*\:.*') {$NetworkInterface.GetPhysicalAddress()} Else {($NetworkInterface.GetPhysicalAddress() -ireplace '([a-zA-Z0-9]{2,2})', '$1:').TrimEnd(':').ToUpper()}
      
                                        $NetworkInterfaceProperties.MACAddress = $NetworkInterfaceMACAddress
                              
                                        $NetworkInterfaceIPProperties = $NetworkInterface.GetIPProperties()

                                        $NetworkInterfaceProperties.DNSEnabled = $NetworkInterfaceIPProperties.IsDnsEnabled
                                        $NetworkInterfaceProperties.DynamicDNSEnabled = $NetworkInterfaceIPProperties.IsDynamicDnsEnabled
                                        $NetworkInterfaceProperties.DNSSuffix = $NetworkInterfaceIPProperties.DnsSuffix

                                        $NetworkInterfaceConfiguration = $NetworkAdapterConfigurationClass | Where-Object {($_.SettingID -ieq $NetworkInterface.ID)}

                                        Switch ($Null -ine $NetworkInterfaceConfiguration)
                                          {
                                              {($_ -eq $True)}
                                                {
                                                    $NetworkInterfaceProperties.DNSServerSearchOrder = $NetworkInterfaceConfiguration.DNSServerSearchOrder
                                                    $NetworkInterfaceProperties.DNSDomainSuffixSearchOrder = $NetworkInterfaceConfiguration.DNSDomainSuffixSearchOrder
                                                }
                                          }
                              
                                        ForEach ($UnicastAddress In $NetworkInterfaceIPProperties.UnicastAddresses)
                                          {
                                              Switch (([String]::IsNullOrEmpty($UnicastAddress.Address) -eq $False) -and ([String]::IsNullOrWhiteSpace($UnicastAddress.Address) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          Switch ($UnicastAddress.Address.AddressFamily)
                                                            {
                                                                {($_ -iin $AddressFamilyTable.IPv4)}
                                                                  {
                                                                      $NetworkInterfaceProperties.IPv4Address = $UnicastAddress.Address.IPAddressToString -As [String]
                                                                      $NetworkInterfaceProperties.IPv4SubnetMask = $UnicastAddress.IPv4Mask -As [String]
                                                                      $NetworkInterfaceProperties.IPv4PrefixLength = $UnicastAddress.PrefixLength
                                                                  }
                                            
                                                                {($_ -iin $AddressFamilyTable.IPv6)}
                                                                  {
                                                                      $NetworkInterfaceProperties.IPv6Address = $UnicastAddress.Address.IPAddressToString.ToUpper()
                                                                  }
                                                            } 
                                                      }
                                                }   
                                          }

                                        ForEach ($GatewayAddress In $NetworkInterfaceIPProperties.GatewayAddresses)
                                          {
                                              Switch (([String]::IsNullOrEmpty($GatewayAddress.Address.Address) -eq $False) -and ([String]::IsNullOrWhiteSpace($GatewayAddress.Address.Address) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          Switch ($GatewayAddress.Address.AddressFamily)
                                                            {
                                                                {($_ -iin $AddressFamilyTable.IPv4)}
                                                                  {
                                                                      $NetworkInterfaceProperties.IPv4Gateway = $GatewayAddress.Address.IPAddressToString.ToString()
                                                                  }
                                                            }
                                                      }
                                                }
                                          }

                                        ForEach ($DHCPServerAddress In $NetworkInterfaceIPProperties.DhcpServerAddresses)
                                          {
                                              Switch (([String]::IsNullOrEmpty($DHCPServerAddress.Address) -eq $False) -and ([String]::IsNullOrWhiteSpace($DHCPServerAddress.Address) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          Switch ($DHCPServerAddress.AddressFamily)
                                                            {
                                                                {($_ -iin $AddressFamilyTable.IPv4)}
                                                                  {
                                                                      $NetworkInterfaceProperties.IPv4DHCPServer = $DHCPServerAddress.IPAddressToString.ToString()
                                                                  }
                                                            }
                                                      }
                                                }   
                                          }

                                        ForEach ($DNSAddress In $NetworkInterfaceIPProperties.DnsAddresses)
                                          {
                                              Switch (([String]::IsNullOrEmpty($DNSAddress.Address) -eq $False) -and ([String]::IsNullOrWhiteSpace($DNSAddress.Address) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          Switch ($DNSAddress.AddressFamily)
                                                            {
                                                                {($_ -iin $AddressFamilyTable.IPv4)}
                                                                  {
                                                                      $NetworkInterfaceProperties.IPv4DNSServers.Add($DNSAddress.ToString())
                                                                  }   
                                                            }
                                                      }
                                                }   
                                          }
                                
                                        $NetworkInterfaceObject = New-Object -TypeName 'PSObject' -Property ($NetworkInterfaceProperties)
                          
                                        $OutputObjectList.Add($NetworkInterfaceObject)
                                    }
              
                                  For ($NetworkInterfaceObjectListIndex = 0; $NetworkInterfaceObjectListIndex -lt $OutputObjectList.Count; $NetworkInterfaceObjectListIndex++)
                                    {
                                        $NetworkInterfaceItem = $OutputObjectList[$NetworkInterfaceObjectListIndex]
                  
                                        $NetworkInterfaceNumber = ($NetworkInterfaceObjectListIndex + 1).ToString('00')
              
                                        $NetworkInterfacePropertyList = New-Object -TypeName 'System.Collections.Generic.List[String]'
              
                                        $Null = $NetworkInterfaceItem.PSObject.Properties | ForEach-Object {$NetworkInterfacePropertyList.Add("[$($_.Name): $($_.Value -Join ', ')]")}
              
                                        $LogMessage = "Network Interface #$($NetworkInterfaceNumber) - $($NetworkInterfacePropertyList -Join ' ')"
                                        Write-Verbose -Message "$($LogMessage)"
                                    }
                              }
        
                            {($_ -eq $False)}
                              {
                                  $WarningMessage = "There are no available network connections!"
                                  Write-Warning -Message "$($WarningMessage)"
                              }
                        }
                    #endregion
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
              Finally
                {
                    
                }
          }
        
        End
          {                                        
              Try
                {
                    #Determine the date and time the function completed execution
                      $FunctionEndTime = (Get-Date)

                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of $($FunctionName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    #Log the total script execution time  
                      $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                    
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is completed."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
              Finally
                {
                    #Write the object to the powershell pipeline
                      $OutputObjectList = $OutputObjectList.ToArray()

                      Write-Output -InputObject ($OutputObjectList | Sort-Object -Property @('Status'))
                }
          }
    }
#endregion