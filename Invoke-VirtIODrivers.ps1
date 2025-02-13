#Requires -Version 3 -Modules Storage

<#
    .SYNOPSIS
    A short synopsis of of what the script does
          
    .DESCRIPTION
    A meaningful description of what the script does
          
    .PARAMETER TaskSequenceVariables
    One or more task sequence variable(s) to retrieve during task sequence execution.
    If this parameter is not specified, all task sequence variable(s) will be stored into the variable 'TSVariableTable'.
    Any task sequence variables that are new or have been updated will be saved back to the task sequence engine for futher usage.

    $TSVariable.MyCustomVariableName = "MyCustomVariableValue"
    $TSVariable.Make = "MyDeviceModel"

    .PARAMETER LogDir
    A valid folder path. If the folder does not exist, it will be created. This parameter can also be specified by the alias "LogPath".

    .PARAMETER ContinueOnError
    Ignore failures.
          
    .EXAMPLE
    Use this command to execute a VBSCript that will launch this powershell script automatically with the specified parameters. This is useful to avoid powershell execution complexities.
    
    cscript.exe /nologo "%FolderPathContainingScript%\%ScriptName%.vbs" /SwitchParameter /ScriptParameter:"%ScriptParameterValue%" /ScriptParameterArray:"%ScriptParameterValue1%,%ScriptParameterValue2%"

    wscript.exe /nologo "%FolderPathContainingScript%\%ScriptName%.vbs" /SwitchParameter /ScriptParameter:"%ScriptParameterValue%" /ScriptParameterArray:"%ScriptParameterValue1%,%ScriptParameterValue2%"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\%ScriptName%.ps1" -SwitchParameter -ScriptParameter "%ScriptParameterValue%"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -NoLogo -WindowStyle Hidden -Command "& '%FolderPathContainingScript%\%ScriptName%.ps1' -ScriptParameter1 '%ScriptParameter1Value%' -ScriptParameter2 %ScriptParameter2Value% -SwitchParameter"
  
    .NOTES
    Any useful tidbits
          
    .LINK
    A useful link    
#>

[CmdletBinding(SupportsShouldProcess=$True)]
  Param
    (        	     
        [Parameter(Mandatory=$False)]
        [Alias('I')]
        [Switch]$Install,
        
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('URI', 'URL', 'DURL')]
        [System.URI]$DownloadURL,
        
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('DDD', 'Destination', 'DownloadDirectory')]
        [System.IO.DirectoryInfo]$DownloadDestinationDirectory,
        
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('TSVars', 'TSVs')]
        [String[]]$TaskSequenceVariables,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('TSVD', 'TSVDL')]
        [String[]]$TSVariableDecodeList,
            
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('LogDir', 'LogPath')]
        [System.IO.DirectoryInfo]$LogDirectory,
            
        [Parameter(Mandatory=$False)]
        [Switch]$ContinueOnError
    )
        
Function Get-AdministrativePrivilege
    {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
        Write-Output -InputObject ($Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    }

If ((Get-AdministrativePrivilege) -eq $False)
    {
        [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Path)"

        $ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
          $ArgumentList.Add('-ExecutionPolicy Bypass')
          $ArgumentList.Add('-NoProfile')
          $ArgumentList.Add('-NoExit')
          $ArgumentList.Add('-NoLogo')
          $ArgumentList.Add("-File `"$($ScriptPath.FullName)`"")

        $ExecutionDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
          $ExecutionDictionary.PSLegacyPath = Try {Get-Command -Name 'powershell.exe'} Catch {$Null}
          $ExecutionDictionary.PSModernPath = Try {Get-Command -Name 'pwsh.exe'} Catch {$Null}
        
        Switch ($Null -ine $ExecutionDictionary.PSModernPath)
          {
              {($_ -eq $True)} {$ExecutionDictionary.PSPath = $ExecutionDictionary.PSModernPath.Path}
              Default {$ExecutionDictionary.PSPath = $ExecutionDictionary.PSLegacyPath.Path}
          }

        $Null = Start-Process -FilePath ($ExecutionDictionary.PSPath) -WorkingDirectory "$($Env:Temp.TrimEnd('\'))" -ArgumentList ($ArgumentList.ToArray()) -WindowStyle Normal -Verb RunAs -PassThru
    }
Else
    {
        #Determine the date and time we executed the function
          $ScriptStartTime = (Get-Date)
  
        #Define Default Action Preferences
            $Script:DebugPreference = 'SilentlyContinue'
            $Script:ErrorActionPreference = 'Stop'
            $Script:VerbosePreference = 'SilentlyContinue'
            $Script:WarningPreference = 'Continue'
            $Script:ConfirmPreference = 'None'
            $Script:WhatIfPreference = $False
    
        #Load WMI Classes
          $Baseboard = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_Baseboard" -Property *
          $Bios = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_Bios" -Property *
          $ComputerSystem = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_ComputerSystem" -Property *
          $OperatingSystem = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_OperatingSystem" -Property *
          $MSSystemInformation = Try {Get-CIMInstance -Namespace "root\WMI" -ClassName "MS_SystemInformation" -Property *} Catch {$Null}

        #Retrieve property values
          $OSArchitecture = $($OperatingSystem.OSArchitecture).Replace("-bit", "").Replace("32", "86").Insert(0,"x").ToUpper()

        #Define variable(s)
          $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
          [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
          $DateTimeMessageFormat = 'MM/dd/yyyy HH:mm:ss.FFF'  ###03/23/2022 11:12:48.347###
          [ScriptBlock]$GetCurrentDateTimeMessageFormat = {(Get-Date).ToString($DateTimeMessageFormat)}
          $DateFileFormat = 'yyyyMMdd'  ###20190403###
          [ScriptBlock]$GetCurrentDateFileFormat = {(Get-Date).ToString($DateFileFormat)}
          $DateTimeFileFormat = 'yyyyMMdd_HHmmss'  ###20190403_115354###
          [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
          [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Definition)"
          [System.IO.DirectoryInfo]$ScriptDirectory = "$($ScriptPath.Directory.FullName)"
          [System.IO.DirectoryInfo]$ContentDirectory = "$($ScriptDirectory.FullName)\Content"
          [System.IO.DirectoryInfo]$FunctionsDirectory = "$($ScriptDirectory.FullName)\Functions"
          [System.IO.DirectoryInfo]$ModulesDirectory = "$($ScriptDirectory.FullName)\Modules"
          [System.IO.DirectoryInfo]$ToolsDirectory = "$($ScriptDirectory.FullName)\Tools"
          [System.IO.DirectoryInfo]$ToolsDirectory_OSAll = "$($ToolsDirectory.FullName)\All"
          [System.IO.DirectoryInfo]$ToolsDirectory_OSArchSpecific = "$($ToolsDirectory.FullName)\$($OSArchitecture)"
          [System.IO.DirectoryInfo]$System32Directory = [System.Environment]::SystemDirectory
          [System.IO.DirectoryInfo]$ProgramFilesDirectory = "$($Env:SystemDrive)\Program Files"
          [System.IO.DirectoryInfo]$ProgramFilesx86Directory = "$($Env:SystemDrive)\Program Files (x86)"
          [System.IO.FileInfo]$PowershellPath = "$($System32Directory.FullName)\WindowsPowershell\v1.0\powershell.exe"
          [System.IO.DirectoryInfo]$System32Directory = "$([System.Environment]::SystemDirectory)"
          $IsWindowsPE = Test-Path -Path 'HKLM:\SYSTEM\ControlSet001\Control\MiniNT' -ErrorAction SilentlyContinue
          [ScriptBlock]$GetRandomGUID = {[System.GUID]::NewGUID().GUID.ToString().ToUpper()}
          [String]$ParameterSetName = "$($PSCmdlet.ParameterSetName)"
          $TextInfo = (Get-Culture).TextInfo
          $Script:LASTEXITCODE = 0
          $TerminationCodes = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $TerminationCodes.Add('Success', @(0))
            $TerminationCodes.Add('Warning', @(5000..5999))
            $TerminationCodes.Add('Error', @(6000..6999))
          $Script:WarningCodeIndex = 0
          [ScriptBlock]$GetAvailableWarningCode = {$TerminationCodes.Warning[$Script:WarningCodeIndex]; $Script:WarningCodeIndex++}
          $Script:ErrorCodeIndex = 0
          [ScriptBlock]$GetAvailableErrorCode = {$TerminationCodes.Error[$Script:ErrorCodeIndex]; $Script:ErrorCodeIndex++}
          $LoggingDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'    
            $LoggingDetails.Add('LogMessage', $Null)
            $LoggingDetails.Add('WarningMessage', $Null)
            $LoggingDetails.Add('ErrorMessage', $Null)
          $RegexOptionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions]'
            $RegexOptionList.Add('IgnoreCase')
            $RegexOptionList.Add('Multiline')
          $RegularExpressionTable = New-Object -TypeName 'System.Collections.Generic.Dictionary[[String], [System.Text.RegularExpressions.Regex]]'
            $RegularExpressionTable.Base64 = New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList @('^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$', $RegexOptionList.ToArray())
          $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
            $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
          $TextEncoder = [System.Text.Encoding]::Default

          #Define the error handling definition
            [ScriptBlock]$ErrorHandlingDefinition = {
                                                        Param
                                                          (
                                                              [Int16]$Severity,
                                                              [Boolean]$ContinueOnError
                                                          )
                                                                                                                
                                                        $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $ExceptionPropertyDictionary.Message = $_.Exception.Message
                                                          $ExceptionPropertyDictionary.Category = $_.Exception.ErrorRecord.FullyQualifiedErrorID
                                                          $ExceptionPropertyDictionary.Script = Try {[System.IO.Path]::GetFileName($_.InvocationInfo.ScriptName)} Catch {$Null}
                                                          $ExceptionPropertyDictionary.LineNumber = $_.InvocationInfo.ScriptLineNumber
                                                          $ExceptionPropertyDictionary.LinePosition = $_.InvocationInfo.OffsetInLine
                                                          $ExceptionPropertyDictionary.Code = $_.InvocationInfo.Line.Trim()

                                                        $ExceptionMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'

                                                        ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
                                                          {
                                                              Switch ($Null -ine $ExceptionProperty.Value)
                                                                {
                                                                    {($_ -eq $True)}
                                                                      {
                                                                          $ExceptionMessageList.Add("[$($ExceptionProperty.Key): $($ExceptionProperty.Value)]")
                                                                      }
                                                                }   
                                                          }

                                                        $LogMessageParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $LogMessageParameters.Message = $ExceptionMessageList -Join ' '
                                                          $LogMessageParameters.Verbose = $True
                              
                                                        Switch ($Severity)
                                                          {
                                                              {($_ -in @(1))} {Write-Verbose @LogMessageParameters}
                                                              {($_ -in @(2))} {Write-Warning @LogMessageParameters}
                                                              {($_ -in @(3))} {Write-Error @LogMessageParameters}
                                                          }

                                                        Switch ($ContinueOnError)
                                                          {
                                                              {($_ -eq $False)}
                                                                {                  
                                                                    If (($Null -ieq $Script:LASTEXITCODE) -or ($Script:LASTEXITCODE -eq 0))
                                                                      {
                                                                          [Int]$Script:LASTEXITCODE = 6000

                                                                          [System.Environment]::ExitCode = $Script:LASTEXITCODE
                                                                      }
                                                                    
                                                                    Throw
                                                                }
                                                          }
                                                    }
	
        #Log task sequence variables if debug mode is enabled within the task sequence
          Try
            {
                [System.__ComObject]$TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment"
              
                If ($Null -ine $TSEnvironment)
                  {
                      $IsRunningTaskSequence = $True
                      
                      [Boolean]$IsConfigurationManagerTaskSequence = [String]::IsNullOrEmpty($TSEnvironment.Value("_SMSTSPackageID")) -eq $False
                      
                      Switch ($IsConfigurationManagerTaskSequence)
                        {
                            {($_ -eq $True)}
                              {
                                  $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A Microsoft Endpoint Configuration Manager (MECM) task sequence was detected."
                                  Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                              }
                                      
                            {($_ -eq $False)}
                              {
                                  $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A Microsoft Deployment Toolkit (MDT) task sequence was detected."
                                  Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                              }
                        }
                  }
            }
          Catch
            {
                $IsRunningTaskSequence = $False
            }
            
        #Determine default parameter value(s)       
          Switch ($True)
            {
                {([String]::IsNullOrEmpty($DownloadURL) -eq $True) -or ([String]::IsNullOrWhiteSpace($DownloadURL) -eq $True)}
                  {
                      [System.URI]$DownloadURL = 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso'
                  }
                
                {([String]::IsNullOrEmpty($DownloadDestinationDirectory) -eq $True) -or ([String]::IsNullOrWhiteSpace($DownloadDestinationDirectory) -eq $True)}
                  {
                      [System.IO.DirectoryInfo]$DownloadDestinationDirectory = "$($ContentDirectory.FullName)\ISOs"
                  }
                
                {([String]::IsNullOrEmpty($LogDirectory) -eq $True) -or ([String]::IsNullOrWhiteSpace($LogDirectory) -eq $True)}
                  {
                      Switch ($IsRunningTaskSequence)
                        {
                            {($_ -eq $True)}
                              {
                                  Switch ($IsConfigurationManagerTaskSequence)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              [String]$_SMSTSLogPath = "$($TSEnvironment.Value('_SMSTSLogPath'))"
                                          }
                              
                                        {($_ -eq $False)}
                                          {
                                              [String]$_SMSTSLogPath = "$($TSEnvironment.Value('LogPath'))"
                                          }
                                    }

                                  Switch ([String]::IsNullOrEmpty($_SMSTSLogPath))
                                    {
                                        {($_ -eq $True)}
                                          {
                                              [System.IO.DirectoryInfo]$TSLogDirectory = "$($Env:Windir)\Temp\SMSTSLog"    
                                          }
                                    
                                        {($_ -eq $False)}
                                          {
                                              Switch ($True)
                                                {
                                                    {(Test-Path -Path ($_SMSTSLogPath) -PathType Container)}
                                                      {
                                                          [System.IO.DirectoryInfo]$TSLogDirectory = ($_SMSTSLogPath)
                                                      }
                                    
                                                    {(Test-Path -Path ($_SMSTSLogPath) -PathType Leaf)}
                                                      {
                                                          [System.IO.DirectoryInfo]$TSLogDirectory = Split-Path -Path ($_SMSTSLogPath) -Parent
                                                      }
                                                }    
                                          }
                                    }
                                         
                                  [System.IO.DirectoryInfo]$LogDirectory = "$($TSLogDirectory.FullName)\$($ScriptPath.BaseName)"
                              }
                  
                            {($_ -eq $False)}
                              {
                                  Switch ($IsWindowsPE)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              [System.IO.FileInfo]$MDTBootImageDetectionPath = "$($Env:SystemDrive)\Deploy\Scripts\Litetouch.wsf"
                                      
                                              [Boolean]$MDTBootImageDetected = Test-Path -Path ($MDTBootImageDetectionPath.FullName)
                                              
                                              Switch ($MDTBootImageDetected)
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          [System.IO.DirectoryInfo]$LogDirectory = "$($Env:SystemDrive)\MININT\SMSOSD\OSDLOGS\$($ScriptPath.BaseName)"
                                                      }
                                          
                                                    {($_ -eq $False)}
                                                      {
                                                          [System.IO.DirectoryInfo]$LogDirectory = "$($Env:Windir)\Temp\SMSTSLog"
                                                      }
                                                }
                                          }
                                          
                                        {($_ -eq $False)}
                                          {
                                              [System.IO.DirectoryInfo]$LogDirectory = "$($Env:Windir)\Logs\Software\$($ScriptPath.BaseName)"
                                          }
                                    }   
                              }
                        }
                  }       
            }

        #Start transcripting (Logging)
          Switch ($IsRunningTaskSequence)
            {
                {($_ -in @($True, $False))}
                  {
                      Switch ($IsWindowsPE)
                        {
                            {($_ -eq $True)}
                              {
                                  [System.IO.FileInfo]$ScriptLogPath = "$($LogDirectory.FullName)\$($ScriptPath.BaseName)_Offline_$($GetCurrentDateFileFormat.Invoke()).log"
                              }

                            Default
                              {
                                  [System.IO.FileInfo]$ScriptLogPath = "$($LogDirectory.FullName)\$($ScriptPath.BaseName)_Online_$($GetCurrentDateFileFormat.Invoke()).log"
                              }
                        }
                       
                      If ($ScriptLogPath.Directory.Exists -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($ScriptLogPath.Directory.FullName)}
                      
                      Start-Transcript -Path "$($ScriptLogPath.FullName)" -Force -WhatIf:$False
                  }
            }
	
        #Log any useful information                                     
          [String]$CmdletName = $MyInvocation.MyCommand.Name
                                                   
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of script `"$($CmdletName)`" began on $($ScriptStartTime.ToString($DateTimeLogFormat))"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Script Path = $($ScriptPath.FullName)"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          [String[]]$AvailableScriptParameters = (Get-Command -Name ($ScriptPath.FullName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Available Script Parameter(s) = $($AvailableScriptParameters -Join ', ')"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {Try {"-$($_.Key):$($_.Value.GetType().Name)"} Catch {"-$($_.Key):Unknown"}}
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Supplied Script Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
          
          Switch ($True)
            {
                {([String]::IsNullOrEmpty($ParameterSetName) -eq $False) -and ([String]::IsNullOrWhiteSpace($ParameterSetName) -eq $False)}
                  {
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Parameter Set Name = $($ParameterSetName)"
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  }
            }
          
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Command Line: $([System.Environment]::CommandLine)"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($PSBoundParameters.Count) command line parameter(s) were specified."
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

          $OperatingSystemDetailsTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $OperatingSystemDetailsTable.ProductName = $OperatingSystem.Caption -ireplace '(Microsoft\s+)', ''
            $OperatingSystemDetailsTable.Version = $OperatingSystem.Version
            $OperatingSystemDetailsTable.Architecture = $OperatingSystem.OSArchitecture

          $OperatingSystemRegistryDetails = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
            $OperatingSystemRegistryDetails.Add((New-Object -TypeName 'PSObject' -Property @{Alias = ''; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ValueName = 'UBR'; Value = $Null}))
            $OperatingSystemRegistryDetails.Add((New-Object -TypeName 'PSObject' -Property @{Alias = 'ReleaseVersion'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ValueName = 'ReleaseID'; Value = $Null}))
            $OperatingSystemRegistryDetails.Add((New-Object -TypeName 'PSObject' -Property @{Alias = 'ReleaseID'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ValueName = 'DisplayVersion'; Value = $Null}))

          ForEach ($OperatingSystemRegistryDetail In $OperatingSystemRegistryDetails)
            {
                $OperatingSystemRegistryDetail.Value = Try {(Get-Item -Path $OperatingSystemRegistryDetail.Path).GetValue($OperatingSystemRegistryDetail.ValueName)} Catch {}

                :NextOSDetail Switch (([String]::IsNullOrEmpty($OperatingSystemRegistryDetail.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($OperatingSystemRegistryDetail.Value) -eq $False))
                  {
                      {($_ -eq $True)}
                        {
                            Switch ($OperatingSystemRegistryDetail.ValueName)
                              {
                                  {($_ -ieq 'UBR')}
                                    {
                                        $OperatingSystemDetailsTable.Version = $OperatingSystemDetailsTable.Version + '.' + $OperatingSystemRegistryDetail.Value

                                        Break NextOSDetail
                                    }
                              }

                            Switch (([String]::IsNullOrEmpty($OperatingSystemRegistryDetail.Alias) -eq $False) -and ([String]::IsNullOrWhiteSpace($OperatingSystemRegistryDetail.Alias) -eq $False))
                              {
                                  {($_ -eq $True)}
                                    {
                                        $OperatingSystemDetailsTable.$($OperatingSystemRegistryDetail.Alias) = $OperatingSystemRegistryDetail.Value
                                    }

                                  Default
                                    {
                                        $OperatingSystemDetailsTable.$($OperatingSystemRegistryDetail.ValueName) = $OperatingSystemRegistryDetail.Value
                                    }
                              }
                        }

                      Default
                        {
                            $OperatingSystemDetailsTable.$($OperatingSystemRegistryDetail.ValueName) = $OperatingSystemRegistryDetail.Value
                        }
                  }   
            }

          $OperatingSystemDetailsTable.Version = $OperatingSystemDetailsTable.Version -As [System.Version]
    
          ForEach ($OperatingSystemDetail In $OperatingSystemDetailsTable.GetEnumerator())
            {
                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($OperatingSystemDetail.Key): $($OperatingSystemDetail.Value)"
                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            }
      
          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Powershell Version: $($PSVersionTable.PSVersion.ToString())"
          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
      
          $ExecutionPolicyList = Get-ExecutionPolicy -List
  
          For ($ExecutionPolicyListIndex = 0; $ExecutionPolicyListIndex -lt $ExecutionPolicyList.Count; $ExecutionPolicyListIndex++)
            {
                $ExecutionPolicy = $ExecutionPolicyList[$ExecutionPolicyListIndex]

                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The powershell execution policy is currently set to `"$($ExecutionPolicy.ExecutionPolicy.ToString())`" for the `"$($ExecutionPolicy.Scope.ToString())`" scope."
                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            }
    
        #Log hardware information
          $MSSystemInformationMembers = $MSSystemInformation.PSObject.Properties | Where-Object {($_.MemberType -imatch '^NoteProperty$|^Property$') -and ($_.Name -imatch '^Base.*|Bios.*|System.*$') -and ($_.Name -inotmatch '^.*Major.*|.*Minor.*|.*Properties.*$')} | Sort-Object -Property @('Name')
          
          Switch ($MSSystemInformationMembers.Count -gt 0)
            {
                {($_ -eq $True)}
                  {
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to display device information properties from the `"$($MSSystemInformation.CimSystemProperties.ClassName)`" WMI class located within the `"$($MSSystemInformation.CimSystemProperties.Namespace)`" WMI namespace. Please Wait..."
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
  
                      ForEach ($MSSystemInformationMember In $MSSystemInformationMembers)
                        {
                            [String]$MSSystemInformationMemberName = ($MSSystemInformationMember.Name)
                            [String]$MSSystemInformationMemberValue = $MSSystemInformation.$($MSSystemInformationMemberName)
        
                            Switch ([String]::IsNullOrEmpty($MSSystemInformationMemberValue))
                              {
                                  {($_ -eq $False)}
                                    {
                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($MSSystemInformationMemberName) = $($MSSystemInformationMemberValue)"
                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                    }
                              }
                        }
                  }

                Default
                  {
                      $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The `"MSSystemInformation`" WMI class could not be found."
                      Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                  }
            }

        #region Log Cleanup
          [Int]$MaximumLogHistory = 3
          
          $LogList = Get-ChildItem -Path ($LogDirectory.FullName) -Filter "$($ScriptPath.BaseName)_*" -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}

          $SortedLogList = $LogList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -Skip ($MaximumLogHistory)

          Switch ($SortedLogList.Count -gt 0)
            {
                {($_ -eq $True)}
                  {
                      $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - There are $($SortedLogList.Count) log file(s) requiring cleanup."
                      Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                      
                      For ($SortedLogListIndex = 0; $SortedLogListIndex -lt $SortedLogList.Count; $SortedLogListIndex++)
                        {
                            Try
                              {
                                  $Log = $SortedLogList[$SortedLogListIndex]

                                  $LogAge = New-TimeSpan -Start ($Log.LastWriteTime) -End (Get-Date)

                                  $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to cleanup log file `"$($Log.FullName)`". Please Wait... [Last Modified: $($Log.LastWriteTime.ToString($DateTimeMessageFormat))] [Age: $($LogAge.Days.ToString()) day(s); $($LogAge.Hours.ToString()) hours(s); $($LogAge.Minutes.ToString()) minute(s); $($LogAge.Seconds.ToString()) second(s)]."
                                  Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                  
                                  $Null = [System.IO.File]::Delete($Log.FullName)
                              }
                            Catch
                              {
                  
                              }   
                        }
                  }

                Default
                  {
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - There are $($SortedLogList.Count) log file(s) requiring cleanup."
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  }
            }
        #endregion

        #region Download And Install Dependency Package Provider(s) and Module(s)
          $RequiredAssemblyList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            #$RequiredAssemblyList.Add('System.DirectoryServices')
            #$RequiredAssemblyList.Add('System.Web')

          Switch ($RequiredAssemblyList.Count -gt 0)
            {
                {($_ -eq $True)}
                  {
                      ForEach ($RequiredAssembly In $RequiredAssemblyList)
                        {
                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to load required assembly `"$($RequiredAssembly)`". Please Wait..."
                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  
                            $Null = Add-Type -AssemblyName ($RequiredAssembly) -ErrorAction Stop
                        }
                  }
            }
        #endregion

        #region Import Dependency Modules
          If (($ModulesDirectory.Exists -eq $True) -and ($ModulesDirectory.GetDirectories().Count -gt 0))
            {
                Switch ($ModulesDirectory.FullName.StartsWith('\\'))
                  {
                      {($_ -eq $True)}
                        {
                            [System.IO.DirectoryInfo]$ModuleCacheRootDirectory = "$($Env:Windir)\Temp\PSMCache"
                            
                            $ModuleDirectoryList = $ModulesDirectory.GetDirectories()

                            $ModuleDirectoryListCount = ($ModuleDirectoryList | Measure-Object).Count

                            For ($ModuleDirectoryListIndex = 0; $ModuleDirectoryListIndex -lt $ModuleDirectoryListCount; $ModuleDirectoryListIndex++)
                              {
                                  $ModuleDirectoryListItem = $ModuleDirectoryList[$ModuleDirectoryListIndex]

                                  $ModuleCacheDirectory = New-Object -TypeName 'System.IO.DirectoryInfo' -ArgumentList "$($ModuleCacheRootDirectory.FullName)\$($ModuleDirectoryListItem.Name)"

                                  Switch ([System.IO.Directory]::Exists($ModuleCacheDirectory.FullName))
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Skipping the local cache of the powershell module `"$($ModuleDirectoryListItem.Name)`". [Reason: The powershell module has already been cached.]"
                                              Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                          }
                                        
                                        {($_ -eq $False)}
                                          {
                                              $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to locally cache the powershell module `"$($ModuleDirectoryListItem.Name)`". Please Wait..."
                                              Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                              If ([System.IO.Directory]::Exists($ModuleCacheDirectory.FullName) -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($ModuleCacheDirectory.FullName)}

                                              $Null = Start-Sleep -Milliseconds 500
                                              
                                              $NUll = Copy-Item -Path "$($ModuleDirectoryListItem.FullName)\*" -Destination "$($ModuleCacheDirectory.FullName)\" -Recurse -Force -Verbose:$False  
                                          }
                                    }
                              }

                            [System.IO.DirectoryInfo]$ModulesDirectory = $ModuleCacheRootDirectory.FullName
                        }
                  }
                
                $AvailableModules = Get-Module -Name "$($ModulesDirectory.FullName)\*" -ListAvailable -ErrorAction Stop 

                $AvailableModuleGroups = $AvailableModules | Group-Object -Property @('Name')

                ForEach ($AvailableModuleGroup In $AvailableModuleGroups)
                  {
                      $LatestAvailableModuleVersion = $AvailableModuleGroup.Group | Sort-Object -Property @('Version') -Descending | Select-Object -First 1
      
                      If ($Null -ine $LatestAvailableModuleVersion)
                        {
                            Switch ($LatestAvailableModuleVersion.RequiredModules.Count -gt 0)
                              {
                                  {($_ -eq $True)}
                                    {
                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - $($LatestAvailableModuleVersion.RequiredModules.Count) prerequisite powershell module(s) need to be imported before the powershell of `"$($LatestAvailableModuleVersion.Name)`" can be imported."
                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Prequisite Module List: $($LatestAvailableModuleVersion.RequiredModules.Name -Join '; ')"
                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                        
                                        ForEach ($RequiredModule In $LatestAvailableModuleVersion.RequiredModules)
                                          {
                                              Switch ($RequiredModule.Name -iin $AvailableModules.Name)
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          Switch ($Null -ine (Get-Module -Name $RequiredModule.Name -ErrorAction SilentlyContinue))
                                                            {
                                                                {($_ -eq $True)}
                                                                  {
                                                                      $RequiredModuleDetails = $AvailableModules | Where-Object {($_.Name -ieq $RequiredModule.Name)}
                                                                      
                                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to import prerequisite powershell module `"$($RequiredModuleDetails.Name)`" [Version: $($RequiredModuleDetails.Version.ToString())]. Please Wait..."
                                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Prerequisite Module Path: $($RequiredModuleDetails.ModuleBase)"
                                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                      
                                                                      $Null = Import-Module -Name "$($RequiredModuleDetails.Path)" -Global -DisableNameChecking -Force -ErrorAction Stop 
                                                                  }
                                                            }     
                                                      }
                                                }
                                          }
                                    }
                              }
 
                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to import dependency powershell module `"$($LatestAvailableModuleVersion.Name)`" [Version: $($LatestAvailableModuleVersion.Version.ToString())]. Please Wait..."
                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Module Path: $($LatestAvailableModuleVersion.Path)"
                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                            $Null = Import-Module -Name "$($LatestAvailableModuleVersion.Path)" -Global -DisableNameChecking -Force -ErrorAction Stop
                        }
                  }
            }
        #endregion
        
        #region Dot Source Dependency Scripts
          #Dot source any additional script(s) from the functions directory. This will provide flexibility to add additional functions without adding complexity to the main script and to maintain function consistency.
            Try
              {
                  If ($FunctionsDirectory.Exists -eq $True)
                    {
                        $AdditionalFunctionsFilter = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $AdditionalFunctionsFilter.Add('*.ps1')
        
                        $AdditionalFunctionsToImport = Get-ChildItem -Path "$($FunctionsDirectory.FullName)" -Include ($AdditionalFunctionsFilter) -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}
        
                        $AdditionalFunctionsToImportCount = $AdditionalFunctionsToImport | Measure-Object | Select-Object -ExpandProperty Count
        
                        If ($AdditionalFunctionsToImportCount -gt 0)
                          {                    
                              ForEach ($AdditionalFunctionToImport In $AdditionalFunctionsToImport)
                                {
                                    Try
                                      {
                                          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to dot source the functions contained within the dependency script `"$($AdditionalFunctionToImport.Name)`". Please Wait... [Script Path: `"$($AdditionalFunctionToImport.FullName)`"]"
                                          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                          
                                          . "$($AdditionalFunctionToImport.FullName)"
                                      }
                                    Catch
                                      {
                                          $ErrorHandlingDefinition.Invoke(2, $ContinueOnError.IsPresent)
                                      }
                                }
                          }
                    }
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke(2, $ContinueOnError.IsPresent)
              }
        #endregion

        #region Load any required libraries
          [System.IO.DirectoryInfo]$LibariesDirectory = "$($FunctionsDirectory.FullName)\Libraries"

          Switch ([System.IO.Directory]::Exists($LibariesDirectory.FullName))
            {
                {($_ -eq $True)}
                  {
                      $LibraryPatternList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                        #$LibraryPatternList.Add('ChilkatDotNet48.dll')
                        
                      Switch ($LibraryPatternList.Count -gt 0)
                        {
                            {($_ -eq $True)}
                              {
                                  $LibraryList = Get-ChildItem -Path ($LibariesDirectory.FullName) -Include ($LibraryPatternList.ToArray()) -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}

                                  $LibraryListCount = ($LibraryList | Measure-Object).Count
            
                                  Switch ($LibraryListCount -gt 0)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              For ($LibraryListIndex = 0; $LibraryListIndex -lt $LibraryListCount; $LibraryListIndex++)
                                                {
                                                    $Library = $LibraryList[$LibraryListIndex]

                                                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to load assembly `"$($Library.FullName)`". Please Wait..."
                                                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                    Switch ($Library.BaseName)
                                                      {
                                                          {($_ -imatch '(^Chilkat.*$)')}
                                                            {
                                                                $Null = Add-Type -Path ($Library.FullName)
                                                            }

                                                          Default
                                                            {
                                                                [Byte[]]$LibraryBytes = [System.IO.File]::ReadAllBytes($Library.FullName)
                                                    
                                                                $Null = [System.Reflection.Assembly]::Load($LibraryBytes)
                                                            }
                                                      }
                                                }
                                          }
                                    }
                              }
                        }          
                  }
            }
        #endregion

        #Perform script action(s)
          Try
            {                              
                #If necessary, create, get, and or set any task sequence variable(s).   
                  Switch ($IsRunningTaskSequence)
                    {
                        {($_ -eq $True)}
                          {
                              $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A task sequence is currently running."
                              Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                              
                              $TaskSequenceVariableRetrievalList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                
                              Switch ($TaskSequenceVariables.Count -gt 0)
                                {
                                    {($_ -eq $True)}
                                      {
                                          ForEach ($TaskSequenceVariable In $TaskSequenceVariables)
                                            {
                                                $TaskSequenceVariableRetrievalList.Add($TaskSequenceVariable)
                                            }
                                      }
                                }

                              $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to retrieve the task sequence variable list. Please Wait..."
                              Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                      
                              Switch ($TaskSequenceVariableRetrievalList.Count -gt 0)
                                {
                                    {($_ -eq $True)}
                                      {
                                          $TSVariableList = $TSEnvironment.GetVariables() | Where-Object {($_ -iin $TaskSequenceVariableRetrievalList)} | Sort-Object
                                      }
                                      
                                    Default
                                      {
                                          $TSVariableList = $TSEnvironment.GetVariables() | Sort-Object
                                      }
                                }

                              $TSVariableTable = [Ordered]@{}
                                                    
                              ForEach ($TSVariable In $TSVariableList)
                                {
                                    $TSVariableName = $TSVariable
                                    $TSVariableValue = $TSEnvironment.Value($TSVariableName)
                      
                                    Switch ($True)
                                      {
                                          {($TSVariableName -inotmatch '(^_SMSTSTaskSequence$)|(^TaskSequence$)|(^.*Pass.*word.*$)')}
                                            {
                                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to retrieve the value of task sequence variable `"$($TSVariableName)`". Please Wait... [Reference: `$TSVariableTable.`'$($TSVariableName)`']"
                                                Write-Verbose -Message ($LoggingDetails.LogMessage)
                                            }
                                            
                                          {($TSVariableName -iin $TSVariableDecodeList)}
                                            {
                                                Try
                                                  {
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to Base64 decode the `"$($TSVariableName)`" task sequence variable. Please Wait..."
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                      
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Original Value: $($TSVariableValue)"
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  
                                                      $TSVariableValueBytes = [System.Convert]::FromBase64String($TSVariableValue)
                                                      $TSVariableValue = [System.Text.Encoding]::ASCII.GetString($TSVariableValueBytes)
                                                      
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The Base64 decode attempt of the `"$($TSVariableName)`" task sequence variable was successful."
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  }
                                                Catch
                                                  {
                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The Base64 decode attempt of the `"$($TSVariableName)`" task sequence variable was unsuccessful. Setting the original value. Please Wait..."
                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  
                                                      $TSVariableValue = $TSEnvironment.Value($TSVariableName)
                                                  }
                                            }
                                                                            
                                          {($TSVariableTable.Contains($TSVariableName) -eq $False)}
                                            {
                                                $TSVariableTable.Add($TSVariableName, $TSVariableValue)    
                                            }             
                                      } 
                                }
                          }
                    }

                #Perform script actions
                  Switch ($IsWindowsPE)
                    {
                        {($_ -eq $True)}
                          {
                              $FixedVolumeList = [System.IO.DriveInfo]::GetDrives() | Where-Object {($_.DriveType -iin @('Fixed')) -and ($_.IsReady -eq $True) -and ($_.Name.TrimEnd('\') -inotin @($Env:SystemDrive)) -and (([String]::IsNullOrEmpty($_.Name) -eq $False) -or ([String]::IsNullOrWhiteSpace($_.Name) -eq $False))} | Sort-Object -Property @('TotalSize')

                              :FixedVolumeLoop ForEach ($FixedVolume In $FixedVolumeList)
                                  {
                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to check fixed volume `"$($FixedVolume.Name.TrimEnd('\'))`" for a valid installation of Windows."
                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  
                                      [System.IO.DirectoryInfo]$WindowsDirectory = "$($FixedVolume.Name.TrimEnd('\'))\Windows"
                                          
                                      Switch ([System.IO.Directory]::Exists($WindowsDirectory.FullName))
                                          {
                                              {($_ -eq $True)}
                                                  {
                                                      $WindowsDirectoryItemList = Get-ChildItem -Path ($WindowsDirectory.FullName) -ErrorAction SilentlyContinue
                                          
                                                      $WindowsDirectoryItemListCount = ($WindowsDirectoryItemList | Measure-Object).Count
                                          
                                                      Switch (($WindowsDirectoryItemListCount -ge 2) -and ($WindowsDirectoryItemList | Where-Object {($_.Name -ieq 'explorer.exe')}))
                                                          {
                                                              {($_ -eq $True)}
                                                                  {
                                                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Fixed volume `"$($FixedVolume.Name.TrimEnd('\'))`" contains a valid installation of Windows."
                                                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                      $WindowsImageDriveInfo = New-Object -TypeName 'System.IO.DriveInfo' -ArgumentList "$($FixedVolume.Name.TrimEnd('\'))"

                                                                      $HiveDefinitionList = New-Object -TypeName 'System.Collections.Generic.List[System.Collections.Hashtable]'
                                                                        $HiveDefinitionList.Add(@{HivePath = "$($WindowsImageDriveInfo.Name.TrimEnd('\').Toupper())\Windows\System32\Config\SOFTWARE"; KeyPathList = @('Root\Microsoft\Windows NT\CurrentVersion'); ValueNameExpressionList = @('.*'); Result = $Null})

                                                                      ForEach ($HiveDefinition In $HiveDefinitionList)
                                                                        {
                                                                            $InvokeRegistryHiveActionParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                              $InvokeRegistryHiveActionParameters.HivePath = $HiveDefinition.HivePath -As [System.IO.FileInfo]
                                                                              $InvokeRegistryHiveActionParameters.KeyPath = $HiveDefinition.KeyPathList
                                                                              $InvokeRegistryHiveActionParameters.ValueNameExpression = $HiveDefinition.ValueNameExpressionList
                                                                              $InvokeRegistryHiveActionParameters.ContinueOnError = $False
                                                                              $InvokeRegistryHiveActionParameters.Verbose = $True
                                      
                                                                            $HiveDefinition.Result = Invoke-RegistryHiveAction @InvokeRegistryHiveActionParameters

                                                                            Switch ($InvokeRegistryHiveActionParameters.HivePath.BaseName)
                                                                              {
                                                                                  {($_ -iin @('SOFTWARE'))}
                                                                                    {
                                                                                        $BuildLabEX = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'BuildLabEX')}).Value
                                                                                        
                                                                                        $WindowsImageDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                          $WindowsImageDetails.ProductName = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'ProductName')}).Value
                                                                                          $WindowsImageDetails.MajorVersionNumber = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'CurrentMajorVersionNumber')}).Value
                                                                                          $WindowsImageDetails.MinorVersionNumber = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'CurrentMinorVersionNumber')}).Value
                                                                                          $WindowsImageDetails.BuildNumber = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'CurrentBuildNumber')}).Value
                                                                                          $WindowsImageDetails.RevisionNumber = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'UBR')}).Value
                                                                                          $WindowsImageDetails.Version = New-Object -TypeName 'System.Version' -ArgumentList @($WindowsImageDetails.MajorVersionNumber, $WindowsImageDetails.MinorVersionNumber, $WindowsImageDetails.BuildNumber, $WindowsImageDetails.RevisionNumber)
                                                                                          $WindowsImageDetails.ReleaseNumber = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'ReleaseID')}).Value
                                                                                          $WindowsImageDetails.ReleaseID = ($HiveDefinition.Result[0].ValueList | Where-Object {($_.Name -ieq 'DisplayVersion')}).Value
                                                                                          
                                                                                          Switch ($True)
                                                                                            {
                                                                                                {($WindowsImageDetails.ProductName -inotmatch '(^.*Server.*$)') -and ($WindowsImageDetails.Version -ge [Version]'10.0.22000.0')}
                                                                                                  {
                                                                                                      $WindowsImageDetails.ProductName = $WindowsImageDetails.ProductName.Replace('10', '11')
                                                                                                  }
                                                                                            }
  
                                                                                          Switch ($BuildLabEX)
                                                                                            {
                                                                                                {($_ -imatch '.*amd64.*')}
                                                                                                  {
                                                                                                      $WindowsImageDetails.OSArchitecture = 'X64'
                                                                                                      $WindowsImageDetails.ProcessorArchitecture = 'amd64'
                                                                                                  }

                                                                                                Default
                                                                                                  {
                                                                                                      $WindowsImageDetails.OSArchitecture = 'X86'
                                                                                                      $WindowsImageDetails.ProcessorArchitecture = 'x86'
                                                                                                  }
                                                                                            }

                                                                                          $WindowsImageDetails.InstallLocation = $WindowsDirectory
                                                                                    }
                                                                              }
                                                                        }
                                                                                  
                                                                      Break FixedVolumeLoop
                                                                  }
                                                          }       
                                                  }
                                          }    
                                  }             
                          }

                        Default
                          {
                              [System.IO.DirectoryInfo]$WindowsDirectory = "$($Env:Windir)"
                              
                              $WindowsImageDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                $WindowsImageDetails.ProductName = $OperatingSystem.Caption -ireplace '(?:Microsoft\s+)?', ''
                                $WindowsImageDetails.MajorVersionNumber = $OperatingSystemDetailsTable.Version.Major
                                $WindowsImageDetails.MinorVersionNumber = $OperatingSystemDetailsTable.Version.Minor
                                $WindowsImageDetails.BuildNumber = $OperatingSystemDetailsTable.Version.Build
                                $WindowsImageDetails.RevisionNumber = $OperatingSystemDetailsTable.Version.Revision
                                $WindowsImageDetails.Version = $OperatingSystemDetailsTable.Version
                                $WindowsImageDetails.ReleaseNumber = $OperatingSystemDetailsTable.ReleaseVersion
                                $WindowsImageDetails.ReleaseID = $OperatingSystemDetailsTable.ReleaseID
                                $WindowsImageDetails.OSArchitecture = $OperatingSystemDetailsTable.Architecture
                                $WindowsImageDetails.ProcessorArchitecture = $Env:PROCESSOR_ARCHITECTURE
                                $WindowsImageDetails.InstallLocation = $WindowsDirectory
                          }
                    }

                  ForEach ($WindowsImageDetail In $WindowsImageDetails.GetEnumerator())
                    {
                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Deployed Operating System - $($WindowsImageDetail.Key): $($WindowsImageDetail.Value)"
                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                    }

                  #Download the VirtIO driver ISO and install the relevant drivers
                    Switch ($Install.IsPresent)
                      {
                          {($_ -eq $True)}
                            {
                                #Create the directory search list object
                                  $ISOSearchDirectoryList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.DirectoryInfo]'
                                
                                #Download the latest ISO (If necessary)
                                  $InvokeFileDownloadWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                  $InvokeFileDownloadWithProgressParameters.URL = $DownloadURL
	                                  $InvokeFileDownloadWithProgressParameters.Destination = $DownloadDestinationDirectory.FullName
	                                  $InvokeFileDownloadWithProgressParameters.FileName = [System.IO.Path]::GetFileName($InvokeFileDownloadWithProgressParameters.URL.OriginalString)
	                                  $InvokeFileDownloadWithProgressParameters.ContinueOnError = $False
	                                  $InvokeFileDownloadWithProgressParameters.Verbose = $True

                                  $InvokeFileDownloadWithProgressResult = Invoke-FileDownloadWithProgress @InvokeFileDownloadWithProgressParameters
                                  
                                #Copy the downloaded ISO file locally if a UNC path is detected, in order to avoid file lock issues.
                                  $ISOSearchDirectoryList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.DirectoryInfo]'
                                  
                                  Switch ($DownloadDestinationDirectory.FullName.StartsWith('\\'))
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - A UNC path was detected for the download destination directory. Attempting to copy the downloaded file locally. Please Wait..."
                                              Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                              
                                              $CopyItemWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                              $CopyItemWithProgressParameters.Path = $InvokeFileDownloadWithProgressResult.DownloadPath.FullName
	                                              $CopyItemWithProgressParameters.Destination = "$($WindowsImageDetails.InstallLocation.FullName)\Temp\ISOs"
	                                              $CopyItemWithProgressParameters.Include = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                              $CopyItemWithProgressParameters.Include.Add('*.iso')
	                                              $CopyItemWithProgressParameters.Force = $True
	                                              $CopyItemWithProgressParameters.SegmentSize = 16384
	                                              $CopyItemWithProgressParameters.ContinueOnError = $False
	                                              $CopyItemWithProgressParameters.Verbose = $True
	                                              $CopyItemWithProgressParameters.ErrorAction = [System.Management.Automation.Actionpreference]::Stop

                                              $CopyItemWithProgressResult = Copy-ItemWithProgress @CopyItemWithProgressParameters

                                              $ISOSearchDirectoryList.Add($CopyItemWithProgressResult[0].Destination.Directory.FullName)
                                          }

                                        Default
                                          {
                                              $ISOSearchDirectoryList.Add($InvokeFileDownloadWithProgressParameters.Destination)
                                          }
                                    } 

                              #Mount the ISO file (Extracting the ISO file for distrubution has too much of a processing cost)
                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to get a list of available ISO image(s). Please Wait..."
                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                $ISOSearchDirectoryListCounter = 1

                                ForEach ($ISOSearchDirectory In $ISOSearchDirectoryList)
                                  {
                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Directory #$($ISOSearchDirectoryListCounter.ToString('00')): $($ISOSearchDirectory.FullName)"
                                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                  
                                      $ISOSearchDirectoryListCounter++
                                  }

                                $ISOList = Get-ChildItem -Path ($ISOSearchDirectoryList.ToArray().FullName) -Filter '*.iso' -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])}
                                            
                                $ISOListCount = ($ISOList | Measure-Object).Count

                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Found $($ISOListCount) ISO image(s)."
                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                Switch ($ISOListCount -gt 0)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $ISO = $ISOList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -First 1

                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Lastest Available ISO Image: $($ISO.FullName)"
                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                            $ISOImageInfo = Get-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO

                                            Switch ($ISOImageInfo.Attached)
                                              {
                                                  {($_ -eq $True)}
                                                    {
                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The specified ISO image has already been mounted. Skipping operation."
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                    }
                                                              
                                                  {($_ -eq $False)}
                                                    {
                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The specified ISO image requires mounting. Please Wait..."
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                    
                                                        $ISOImageInfo = Mount-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO -Access ReadOnly -PassThru
                                                    }
                                              }

                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to get the volume information for the mounted ISO image. Please Wait..."
                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                            $ISOImageVolume = $ISOImageInfo | Get-Volume

                                            Switch (([String]::IsNullOrEmpty($ISOImageVolume.DriveLetter) -eq $False) -and ([String]::IsNullOrWhiteSpace($ISOImageVolume.DriveLetter) -eq $False))
                                              {
                                                  {($_ -eq $True)}
                                                    {
                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Mounted ISO Image Volume Letter: $($ISOImageVolume.DriveLetter)"
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                        #Get the operating system caption alias and install the relevant drivers
                                                          Try
                                                            {
                                                                $RegularExpression = '(?:Microsoft)?(?:\s+)?(?:Windows)?(?:\s+)?(?<OSReleaseType>Server|)?(?:\s+)?(?<OSReleaseVersion>\d+|\d+\.\d+)?(?:\s+)?(?<OSReleaseNumber>R\d+)?(?:\s+)?(?<OSReleaseEdition>.+)?'
      
                                                                $RegularExpressionObject = New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList ($RegularExpression, $RegexOptionList)
                  
                                                                Switch ($RegularExpressionObject.IsMatch($WindowsImageDetails.ProductName))
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {
                                                                            $RegularExpressionObjectResult = $RegularExpressionObject.Match($WindowsImageDetails.ProductName)

                                                                            $RegularExpressionGroupList = $RegularExpressionObjectResult.Groups

                                                                            Switch ($WindowsImageDetails.ProductName)
                                                                              {
                                                                                  {($_ -imatch '(^.*Server.*$)')}
                                                                                    {
                                                                                        [String]$OSReleaseNumber = $RegularExpressionGroupList['OSReleaseNumber'].Value

                                                                                        [String]$OSReleaseVersion = $RegularExpressionGroupList['OSReleaseVersion'].Value

                                                                                        [String]$OSReleaseVersion = $OSReleaseVersion.Substring($OSReleaseVersion.Length - 2).TrimStart('0')
                              
                                                                                        Switch (([String]::IsNullOrEmpty($OSReleaseNumber) -eq $False) -and ([String]::IsNullOrWhiteSpace($OSReleaseNumber) -eq $False))
                                                                                          {
                                                                                              {($_ -eq $True)}
                                                                                                {
                                                                                                    $OSCaptionAlias = "2k$($OSReleaseVersion)$($OSReleaseNumber)"
                                                                                                }

                                                                                              Default
                                                                                                {                                          
                                                                                                    $OSCaptionAlias = "2k$($OSReleaseVersion)"
                                                                                                }
                                                                                          }
                                                                                    }

                                                                                  Default
                                                                                    {
                                                                                        $OSReleaseVersion = $RegularExpressionGroupList['OSReleaseVersion'].Value
                              
                                                                                        $OSCaptionAlias = "w$($OSReleaseVersion)"
                                                                                    }
                                                                              }

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to search for relevant driver folder(s) located within `"$($ISOImageVolume.DriveLetter):\`". Please Wait..."
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Operating System Caption: $($WindowsImageDetails.ProductName)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Operating System Caption Alias: $($OSCaptionAlias)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Operating System Processor Architecture: $($WindowsImageDetails.ProcessorArchitecture)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                                        
                                                                            $VirtIODriverFolderList = Get-ChildItem -Path "$($ISOImageVolume.DriveLetter):\\*" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.DirectoryInfo]) -and ($_.FullName -imatch ".*$($OSCaptionAlias).*") -and ($_.FullName -imatch ".*$($WindowsImageDetails.ProcessorArchitecture).*")}

                                                                            $VirtIODriverFolderListCount = ($VirtIODriverFolderList | Measure-Object).Count

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Located $($VirtIODriverFolderListCount) relevant driver folder(s) within volume `"$($ISOImageVolume.DriveLetter):\`"."
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            Switch ($VirtIODriverFolderListCount -gt 0)
                                                                              {
                                                                                              {($_ -eq $True)}
                                                                                                {                                                                                                    
                                                                                                    [System.IO.FileInfo]$DISMLogRootDirectory = "$($LogDirectory.FullName)\WindowsPE\DISM"

                                                                                                    Switch ($True)
                                                                                                      {
                                                                                                          {([System.IO.Directory]::Exists($DISMLogRootDirectory.FullName) -eq $False)}
                                                                                                            {
                                                                                                                $Null = [System.IO.Directory]::CreateDirectory($DISMLogRootDirectory.FullName)
                                                                                                            }
                                                                                                      }
                                                                                                    
                                                                                                    $VirtIODriverFolderListCounter = 1
                                                                                                    
                                                                                                    For ($VirtIODriverFolderListIndex = 0; $VirtIODriverFolderListIndex -lt $VirtIODriverFolderListCount; $VirtIODriverFolderListIndex++)
                                                                                                      {
                                                                                                          $VirtIODriverFolder = $VirtIODriverFolderList[$VirtIODriverFolderListIndex]

                                                                                                          Switch ($IsWindowsPE)
                                                                                                            {
                                                                                                                {($_ -eq $True)}
                                                                                                                  {
                                                                                                                      [System.IO.FileInfo]$DISMLogPath = "$($DISMLogRootDirectory.FullName)\AddDrivers_VirtIO_Folder_$($VirtIODriverFolderListCounter.ToString('00')).log"
                                                                                              
                                                                                                                      $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                                                                                                      $StartProcessWithOutputParameters.FilePath = 'dism.exe'
	                                                                                                                      $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                                                                                                      $StartProcessWithOutputParameters.ArgumentList.Add('/Add-Driver')
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add("/Image:$($WindowsImageDetails.InstallLocation.Root.FullName.TrimEnd('\'))")
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add("/Driver:`"$($VirtIODriverFolder.FullName)`"")
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add('/Recurse')
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add('/LogLevel:3')
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add("/LogPath:`"$($DISMLogPath.FullName)`"")
	                                                                                                                      $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                                                                                                      $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                                                                                          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('2')
                                                                                                                          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('50')
	                                                                                                                      $StartProcessWithOutputParameters.CreateNoWindow = $True
	                                                                                                                      $StartProcessWithOutputParameters.ExecutionTimeout = [System.Timespan]::FromMinutes(15)
	                                                                                                                      $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.Timespan]::FromSeconds(5)
	                                                                                                                      $StartProcessWithOutputParameters.LogOutput = $True
	                                                                                                                      $StartProcessWithOutputParameters.ContinueOnError = $False
	                                                                                                                      $StartProcessWithOutputParameters.Verbose = $True
                                                                                                                  }

                                                                                                                Default
                                                                                                                  {
                                                                                                                      $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	                                                                                                                      $StartProcessWithOutputParameters.FilePath = 'pnputil.exe'
	                                                                                                                      $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                                                                                                      $StartProcessWithOutputParameters.ArgumentList.Add('/add-driver')
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add("`"$($VirtIODriverFolder.FullName)\*.inf`"")
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add('/subdirs')
                                                                                                                          $StartProcessWithOutputParameters.ArgumentList.Add('/install')
	                                                                                                                      $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
		                                                                                                                      $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                                                                                          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('259')
                                                                                                                          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('3010')
                                                                                                                          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('1641')
	                                                                                                                      $StartProcessWithOutputParameters.CreateNoWindow = $True
	                                                                                                                      $StartProcessWithOutputParameters.ExecutionTimeout = [System.Timespan]::FromMinutes(5)
	                                                                                                                      $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.Timespan]::FromSeconds(2)
	                                                                                                                      $StartProcessWithOutputParameters.LogOutput = $True
	                                                                                                                      $StartProcessWithOutputParameters.ContinueOnError = $False
	                                                                                                                      $StartProcessWithOutputParameters.Verbose = $True
                                                                                                                  }
                                                                                                            }
                                                                                  
                                                                                                          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to install the driver(s) located within driver folder #$($VirtIODriverFolderListCounter.ToString('00')). Please Wait..."
                                                                                                          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                                                          $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Path: $($VirtIODriverFolder.FullName)"
                                                                                                          Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                                                          $ProgressPercentage = [System.Math]::Round((($VirtIODriverFolderListCounter / $VirtIODriverFolderListCount) * 100), 2)

                                                                                                          $ProgressActivity = "Installing drivers from folder $($VirtIODriverFolderListCounter) of $($VirtIODriverFolderListCount). Please Wait... [Path: $($VirtIODriverFolder.FullName)]"
                                                                                                          
                                                                                                          $WriteProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                            $WriteProgressParameters.Activity = $ProgressActivity
                                                                                                            $WriteProgressParameters.Status = "Progress Percentage: $($ProgressPercentage)%"
                                                                                                            $WriteProgressParameters.PercentComplete = $ProgressPercentage
                                                                                                            $WriteProgressParameters.CurrentOperation = $VirtIODriverFolder.FullName

                                                                                                          Switch ($IsRunningTaskSequence)
                                                                                                            {
                                                                                                                {($_ -eq $True)}
                                                                                                                  {
                                                                                                                      $WriteProgressParameters.Status = $WriteProgressParameters.Activity
                                                                                                                  }

                                                                                                                Default
                                                                                                                  {
                                                                                                                      $WriteProgressParameters.Status = $WriteProgressParameters.CurrentOperation
                                                                                                                  }
                                                                                                            }

                                                                                                          Write-Progress @WriteProgressParameters
                                                                                                          
                                                                                                          $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                                                                                          $WriteProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                            $WriteProgressParameters.Activity = $ProgressActivity
                                                                                                            $WriteProgressParameters.Completed = $True

                                                                                                          Write-Progress @WriteProgressParameters
                                                                                                          
                                                                                                          $VirtIODriverFolderListCounter++                                                   
                                                                                                      }
                                                                                                }
                                                                                          }

                                                                            $ISOImageInfo = Get-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO
                                            
                                                                            Switch ($ISOImageInfo.Attached)
                                                                              {
                                                                                  {($_ -eq $True)}
                                                                                    {
                                                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to dismount the previously mounted ISO image. Please Wait..."
                                                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - ISO Image Path: $($ISO.FullName)"
                                                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                                        $Null = Try {Dismount-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO} Catch {}
                                                                                    }
                                                                              }
                                                                        }

                                                                      Default
                                                                        {
                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The operating system caption does not meet the specified regular expression."
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Operating System Caption: $($WindowsImageDetails.ProductName)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Regular Expression: $($RegularExpression)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                                        }
                                                                  }
                                                            }
                                                          Catch
                                                            {
                                                                $ISOImageInfo = Get-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO
                                            
                                                                Switch ($ISOImageInfo.Attached)
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {
                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to dismount the previously mounted ISO image. Please Wait..."
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - ISO Image Path: $($ISO.FullName)"
                                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                                                                            $Null = Try {Dismount-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO} Catch {}
                                                                        }
                                                                  }
                                                                
                                                                $ErrorHandlingDefinition.InvokeReturnAsIs(3, $False)
                                                            }
                                                    }

                                                  Default
                                                    {
                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Unable to get the volume information for the mounted ISO image. No further action will be taken."
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                    }
                                              }
                                        }
                                  }
                            }

                          Default
                            {
                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - The `"-Install`" parameter was not specified. No further action will be taken."
                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                            }
                      }
                             
                #If necessary, create, get, and or set any task sequence variable(s).   
                  Switch ($IsRunningTaskSequence)
                    {
                        {($_ -eq $True)}
                          {            
                              ForEach ($TSVariable In $TSVariableTable.GetEnumerator())
                                {
                                    [String]$TSVariableName = "$($TSVariable.Key)"
                                    [String]$TSVariableCurrentValue = $TSEnvironment.Value($TSVariableName)
                                    [String]$TSVariableNewValue = "$($TSVariable.Value -Join ',')"
                                                  
                                    Switch ($TSVariableName -inotin $TSVariableDecodeList)
                                      {
                                          {($_ -eq $True)}
                                            {
                                                Switch ($TSVariableCurrentValue -ine $TSVariableNewValue)
                                                  {
                                                      {($_ -eq $True)}
                                                        {
                                                            $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to set the task sequence variable of `"$($TSVariableName)`". Please Wait..."
                                                            Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                                      
                                                            $Null = $TSEnvironment.Value($TSVariableName) = "$($TSVariableNewValue)" 
                                                        }
                                                  }
                                            }
                                      }
                                }
                                
                              $Null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($TSEnvironment)       
                          }
                        
                        {($_ -eq $False)}
                          {
                              $LoggingDetails.WarningMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - There is no task sequence running."
                              Write-Warning -Message ($LoggingDetails.WarningMessage) -Verbose
                          }
                    }
                  
                $Script:LASTEXITCODE = $TerminationCodes.Success[0]
            }
          Catch
            {
                $ErrorHandlingDefinition.Invoke(2, $ContinueOnError.IsPresent)
            }
          Finally
            {                
                Try
                  {
                      #Determine the date and time the function completed execution
                        $ScriptEndTime = (Get-Date)

                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Script execution of `"$($CmdletName)`" ended on $($ScriptEndTime.ToString($DateTimeLogFormat))"
                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                      #Log the total script execution time  
                        $ScriptExecutionTimespan = New-TimeSpan -Start ($ScriptStartTime) -End ($ScriptEndTime)

                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Script execution took $($ScriptExecutionTimespan.Hours.ToString()) hour(s), $($ScriptExecutionTimespan.Minutes.ToString()) minute(s), $($ScriptExecutionTimespan.Seconds.ToString()) second(s), and $($ScriptExecutionTimespan.Milliseconds.ToString()) millisecond(s)."
                        Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            
                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Exiting script `"$($ScriptPath.FullName)`" with exit code $($Script:LASTEXITCODE)."
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
            
                      Stop-Transcript
                  }
                Catch
                  {
            
                  }
            }
    }