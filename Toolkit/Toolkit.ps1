#Requires -Version 3

<#
    .SYNOPSIS
    PowerShell Toolkit providing reusable functions, modules, and infrastructure for parent scripts.

    .DESCRIPTION
    This toolkit serves as a comprehensive foundation for PowerShell scripts, providing:

    - Automatic logging infrastructure with transcript support
    - Error handling and reporting mechanisms
    - Environment detection (Windows PE, Task Sequence, Full OS)
    - WMI/CIM class loading for hardware and OS information
    - Dynamic function and module loading from Toolkit directories
    - Standardized date/time formatting
    - Process execution helpers
    - Network connectivity validation
    - Special folder path resolution
    - Log file rotation and cleanup

    The toolkit is designed to be dot-sourced by parent scripts, automatically initializing the
    execution environment, loading dependencies, and providing consistent logging and error handling.

    Key Features:
    - Automatic log directory detection based on environment (PE, TS, Full OS)
    - Loads all functions from Toolkit\Functions directory
    - Imports all modules from Toolkit\Modules directory
    - Provides standardized scriptblocks for common operations
    - Hardware information gathering and logging
    - Exit code management with categorized ranges (Success, Warning, Error)

    .PARAMETER CallingScriptInvocationInfo
    The invocation information from the calling script ($MyInvocation). This parameter is used to
    determine the calling script's path, parameters, and execution context.

    Alias: CSIO
    Type: System.Management.Automation.InvocationInfo
    Required: False

    .PARAMETER CallingScriptParameterSetName
    The parameter set name from the calling script ($PSCmdlet.ParameterSetName). Used for logging
    which parameter set was invoked.

    Alias: CSPSN
    Type: System.String
    Required: False

    .EXAMPLE
    # Basic toolkit initialization from a parent script
    Try
    {
        [System.IO.FileInfo]$ToolkitScriptPath = "$([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition))\Toolkit\Toolkit.ps1"
        . "$($ToolkitScriptPath.FullName)" -CallingScriptInvocationInfo ($MyInvocation) -CallingScriptParameterSetName ($PSCmdlet.ParameterSetName)
    }
    Catch
    {
        [System.Environment]::ExitCode = 6000
        Throw
    }

    Description:
    Standard toolkit initialization pattern used by parent scripts. Loads all toolkit functionality
    and initializes logging.

    .EXAMPLE
    # Using toolkit logging functions after initialization
    $WriteLogMessage.Invoke(0, @("This is an informational message"))
    $WriteLogMessage.Invoke(1, @("This is a verbose message"))
    $WriteLogMessage.Invoke(2, @("This is a warning message"))
    $WriteLogMessage.Invoke(3, @("This is an error message"))

    Description:
    After toolkit initialization, use the $WriteLogMessage scriptblock to write log entries with
    different severity levels.

    .EXAMPLE
    # Using toolkit error handling
    Try {
        # Your code here
    }
    Catch {
        $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
    }

    Description:
    Use the toolkit's standardized error handling scriptblock to process exceptions consistently.

    .EXAMPLE
    # Accessing hardware information loaded by toolkit
    Write-Host "Computer Name: $($ComputerSystem.Name)"
    Write-Host "Serial Number: $($Bios.SerialNumber)"
    Write-Host "Manufacturer: $($MSSystemInformation.SystemManufacturer)"
    Write-Host "Model: $($MSSystemInformation.SystemProductName)"

    Description:
    The toolkit automatically loads WMI/CIM classes for hardware information into variables.

    .EXAMPLE
    # Using toolkit directory variables
    Write-Host "Script Directory: $($CallingScriptDirectory.FullName)"
    Write-Host "Toolkit Directory: $($ToolkitScriptDirectory.FullName)"
    Write-Host "Content Directory: $($ContentDirectory.FullName)"
    Write-Host "Tools Directory: $($ToolsDirectory_OSArchSpecific.FullName)"

    Description:
    The toolkit provides pre-defined directory variables for common paths.

    .EXAMPLE
    # Pausing script execution
    $PauseScriptExecution.Invoke([System.TimeSpan]::FromSeconds(5))

    Description:
    Use the toolkit's pause scriptblock to delay execution with logging.

    .EXAMPLE
    # Finalizing script execution
    Try {
        # Your script logic
    }
    Finally {
        $FinalizationActions.Invoke()
    }

    Description:
    Always call the finalization scriptblock in the Finally block to properly close logs and
    report execution time.

    .NOTES
    Author: Toolkit Author
    Version: 1.0
    Requirements:
    - PowerShell 3.0 or higher
    - Must be dot-sourced by parent scripts
    - Expects specific directory structure (Functions, Modules, Tools, Content)

    The toolkit automatically:
    - Creates log directories if they don't exist
    - Rotates logs (keeps 3 most recent)
    - Detects Windows PE environment
    - Loads all .ps1 files from Functions directory
    - Imports all modules from Modules directory
    - Provides consistent date/time formatting

    .LINK
    https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands
#>

[CmdletBinding(SupportsShouldProcess=$True)]
  Param
    (
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('CSIO')]
        [System.Management.Automation.InvocationInfo]$CallingScriptInvocationInfo,
     
        [Parameter(Mandatory=$False)]
        [AllowEmptyString()]
        [AllowNull()]
        [Alias('CSPSN')]
        [System.String]$CallingScriptParameterSetName
    )

Try
  {
      #region Define Exit Code Ranges
        $ExitCodeRangeQueueDictionary = New-Object 'System.Collections.Generic.Dictionary[[System.String],[System.Collections.Generic.Queue[System.Int32]]]'
          $ExitCodeRangeQueueDictionary["Success"] = New-Object 'System.Collections.Generic.Queue[System.Int32]' -ArgumentList (,[System.Int32[]](0..999))
          $ExitCodeRangeQueueDictionary["Warning"] = New-Object 'System.Collections.Generic.Queue[System.Int32]' -ArgumentList (,[System.Int32[]](1000..1999))
          $ExitCodeRangeQueueDictionary["Error"]   = New-Object 'System.Collections.Generic.Queue[System.Int32]' -ArgumentList (,[System.Int32[]](2000..2999))
      #endregion
            
      #region Define the error handling definition
        [ScriptBlock]$ErrorHandlingDefinition = {
                                                    Param
                                                      (
                                                          [System.Management.Automation.ErrorRecord]$ErrorRecord,
                                                          [Int16]$Severity,
                                                          [Boolean]$ContinueOnError
                                                      )
                                                    
                                                    [String]$LogMessageTimestampFormat = 'yyyy/MM/dd HH:mm:ss.FFF'
                                                    [ScriptBlock]$GetLogMessageTimestamp = {([DateTime]::UtcNow).ToString($LogMessageTimestampFormat)}
                                                    
                                                    $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                      $ExceptionPropertyDictionary.Message = $ErrorRecord.Exception.Message
                                                      $ExceptionPropertyDictionary.Category = $ErrorRecord.Exception.ErrorRecord.FullyQualifiedErrorID
                                                      $ExceptionPropertyDictionary.Script = Try {[System.IO.Path]::GetFileName($ErrorRecord.InvocationInfo.ScriptName)} Catch {$Null}
                                                      $ExceptionPropertyDictionary.LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
                                                      $ExceptionPropertyDictionary.LinePosition = $ErrorRecord.InvocationInfo.OffsetInLine
                                                      $ExceptionPropertyDictionary.Code = $ErrorRecord.InvocationInfo.Line.Trim()

                                                    Switch ($Severity)
                                                      {
                                                          {($_ -in @(0, 1, 2, 3))} {$SeverityAlias = 'ERROR'}
                                                      }

                                                    ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
                                                      {
                                                          Switch ($Null -ine $ExceptionProperty.Value)
                                                            {
                                                                {($_ -eq $True)}
                                                                  {
                                                                      $ExceptionMessage = "[$($GetLogMessageTimestamp.Invoke())] - [$($SeverityAlias)] - $($ExceptionProperty.Key): $($ExceptionProperty.Value)"
                                                                      
                                                                      $LogMessageParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                        $LogMessageParameters.Message = $ExceptionMessage
                                                                        $LogMessageParameters.Verbose = $True
                                                                                                    
                                                                      Switch ($Severity)
                                                                        {
                                                                            {($_ -in @(0, 1, 2, 3))} {Write-Verbose @LogMessageParameters}
                                                                        }
                                                                  }
                                                            }   
                                                      }

                                                    Switch ($ContinueOnError)
                                                      {
                                                          {($_ -eq $False)}
                                                            {                         
                                                                Switch (($Null -ieq [System.Environment]::ExitCode) -or ([System.Environment]::ExitCode -eq 0))
                                                                  {
                                                                      {($_ -eq $True)}
                                                                        {
                                                                            [System.Environment]::ExitCode = $ExitCodeRangeQueueDictionary["Error"].Dequeue()
                                                                        }
                                                                  }
                                                            
                                                                Throw
                                                            }
                                                      }
                                                }
      #endregion

      #region Define Date and Time Formats
        $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
        [ScriptBlock]$GetCurrentDateTimeLogFormat = {([System.DateTime]::UtcNow).ToString($DateTimeLogFormat)}
        $DateTimeMessageFormat = 'yyyy/MM/dd HH:mm:ss.FFF'  ###2022/03/22 11:12:48.347###
        [ScriptBlock]$GetCurrentDateTimeMessageFormat = {([System.DateTime]::UtcNow).ToString($DateTimeMessageFormat)}
        $DateFileFormat = 'yyyyMMdd'  ###20190403###
        [ScriptBlock]$GetCurrentDateFileFormat = {([System.DateTime]::UtcNow).ToString($DateFileFormat)}
        $DateTimeFileFormat = 'yyyyMMdd_HHmmss'  ###20190403_115354###
        [ScriptBlock]$GetCurrentDateTimeFileFormat = {([System.DateTime]::UtcNow).ToString($DateTimeFileFormat)}
        $DateTimeVersionFormat = 'yyyy.MM.dd.HHMM'  ###2019.04.03.1153###
        [ScriptBlock]$GetCurrentDateTimeVersionFormat = {([System.DateTime]::UtcNow).ToString($DateTimeVersionFormat)}
      #endregion

      #region Define Toolkit Path Variables    
        $ToolkitScriptPath = [System.IO.FileInfo][System.IO.Path]::Combine($MyInvocation.MyCommand.Definition)
        $ToolkitScriptDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolkitScriptPath.Directory.FullName)
        $ToolkitScriptVersion = [System.Version]$ToolkitScriptPath.LastWriteTimeUtc.ToString($DateTimeVersionFormat)
        $CallingScriptPath = [System.IO.FileInfo][System.IO.Path]::Combine($CallingScriptInvocationInfo.MyCommand.Definition)
        $CallingScriptDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($CallingScriptPath.Directory.FullName)
        $CallingScriptVersion = [System.Version]$CallingScriptPath.LastWriteTimeUtc.ToString($DateTimeVersionFormat)
        $CallingScriptProcess = [System.Diagnostics.Process]::GetCurrentProcess()
        $CallingScriptStartTime = $CallingScriptProcess.StartTime.ToUniversalTime()
        $CallingScriptBoundParameters = $CallingScriptInvocationInfo.BoundParameters
        $CallingScriptBoundParameterCount = $CallingScriptBoundParameters.Count
        $CallingScriptUnboundArguments = $CallingScriptInvocationInfo.UnboundArguments
        $CallingScriptUnboundArgumentCount = $CallingScriptUnboundArguments.Count
      #endregion
   
      #region Define the logging scriptblock 
        [ScriptBlock]$WriteLogMessage = {
                                            Param
                                              (
                                                  [Int16]$Severity,
                                                  [String[]]$LogMessageEntryList     
                                              )
                                                                                                            
                                            $LogMessageEntryListCount = ($LogMessageEntryList | Measure-Object).Count

                                            Switch (($Null -ine $Severity) -and ($LogMessageEntryListCount -gt 0))
                                              {
                                                  {($_ -eq $True)}
                                                    {
                                                        [String]$LogMessageTimestampFormat = 'yyyy/MM/dd HH:mm:ss.FFF'
                                                        [ScriptBlock]$GetLogMessageTimestamp = {([System.DateTime]::UTCNow).ToString($LogMessageTimestampFormat)}

                                                        Switch ($Severity)
                                                          {
                                                              {($_ -in @(0))} {$SeverityAlias = 'INFO'}
                                                              {($_ -in @(1))} {$SeverityAlias = 'VERBOSE'}
                                                              {($_ -in @(2))} {$SeverityAlias = 'WARNING'}
                                                              {($_ -in @(3))} {$SeverityAlias = 'ERROR'}
                                                              {($_ -in @(4))} {$SeverityAlias = 'DEBUG'}
                                                          }

                                                        For ($LogMessageEntryIndex = 0; $LogMessageEntryIndex -lt $LogMessageEntryListCount; $LogMessageEntryIndex++)
                                                          {
                                                              $LogMessageEntry = $LogMessageEntryList[$LogMessageEntryIndex]

                                                              $LogMessage = "[$($GetLogMessageTimestamp.Invoke())] - [$($SeverityAlias)] - $($LogMessageEntry)"

                                                              $LogMessageParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                $LogMessageParameters.Message = $LogMessage
                                                                $LogMessageParameters.Verbose = $True
                                                              
                                                              Switch ($Severity)
                                                                {
                                                                    {($_ -in @(0, 1))} {Write-Verbose @LogMessageParameters}
                                                                    {($_ -in @(2, 3, 4))} {Write-Verbose @LogMessageParameters}
                                                                }
                                                          }
                                                    }
                                              }
                                      }
      #endregion

      #region Load WMI Classes
        $Baseboard = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_Baseboard" -Property *
        $Bios = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_Bios" -Property *
        $ComputerSystem = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_ComputerSystem" -Property * 
        $MSSystemInformation = Get-CIMInstance -Namespace "root\WMI" -ClassName "MS_SystemInformation" -Property *
        $OperatingSystem = Get-CIMInstance -Namespace "root\CIMv2" -ClassName "Win32_OperatingSystem" -Property *
      #endregion

      #region Define Variables
          $OSArchitecture = $($OperatingSystem.OSArchitecture).Replace("-bit", "").Replace("32", "86").Insert(0,"x").ToUpper()
          $ContentDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolkitScriptDirectory.Parent.FullName, 'Content')
          $FunctionsDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolkitScriptDirectory.FullName, 'Functions')
          $ModulesDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolkitScriptDirectory.FullName, 'Modules')
          $ToolsDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolkitScriptDirectory.FullName, 'Tools')
          $ToolsDirectory_OSAll = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolsDirectory.FullName, 'All')
          $ToolsDirectory_OSArchSpecific = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolsDirectory.FullName, $OSArchitecture)
          $IsWindowsPE = Test-Path -Path 'HKLM:\SYSTEM\ControlSet001\Control\MiniNT' -ErrorAction SilentlyContinue
          [ScriptBlock]$GetRandomGUID = {[System.GUID]::NewGUID().GUID.ToString().ToUpper()}
          [String]$ParameterSetName = "$($PSCmdlet.ParameterSetName)"
          $TextInfo = (Get-Culture).TextInfo
          $RegexOptionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions]'
            $RegexOptionList.Add('IgnoreCase')
            $RegexOptionList.Add('Multiline')
          $RegularExpressionTable = New-Object -TypeName 'System.Collections.Generic.Dictionary[[String], [System.Text.RegularExpressions.Regex]]'
            $RegularExpressionTable.Base64 = New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList @('^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$', $RegexOptionList.ToArray())
          $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
            $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
          $TextEncoder = [System.Text.Encoding]::Default
          $DirectorySeparator = [System.IO.Path]::DirectorySeparatorChar
      #endregion

      #region Determine if a task sequence is running and any attributes
        Try
          {
              [System.__ComObject]$TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment"

              Switch ($Null -ine $TSEnvironment)
                {
                    {($_ -eq $True)}
                      {
                          $IsRunningTaskSequence = $True

                          $WriteLogMessage.Invoke(0, @("A task sequence is running."))
                      
                          [Boolean]$IsConfigurationManagerTaskSequence = [String]::IsNullOrEmpty($TSEnvironment.Value("_SMSTSPackageID")) -eq $False
                      
                          Switch ($IsConfigurationManagerTaskSequence)
                            {
                                {($_ -eq $True)}
                                  {
                                      $TaskSeqenceType = 'Microsoft Endpoint Configuration Manager (MECM)'
                                  }
                                      
                                {($_ -eq $False)}
                                  {
                                      $TaskSeqenceType = 'Microsoft Deployment Toolkit (MDT)'
                                  }
                            }
                      }

                    Default
                      {
                          $IsRunningTaskSequence = $False
                      }
                }
          }
        Catch
          {
              $IsRunningTaskSequence = $False
          }

        $WriteLogMessage.Invoke(0, @("Is Task Sequence Running: $($IsRunningTaskSequence)", "Task Seqence Type: $($TaskSeqenceType)"))
      #endregion

      #region Determine default parameter value(s)       
        Switch ($True)
          {
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
                                            $TSLogDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:Windir, 'Temp', 'SMSTSLog')   
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
                                              
                                $LogDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($TSLogDirectory.FullName, $CallingScriptPath.BaseName)
                            }
                        
                          Default
                            {
                                Switch ($IsWindowsPE)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $MDTBootImageDetectionPath = [System.IO.FileInfo][System.IO.Path]::Combine($Env:SystemDrive, 'Deploy', 'Scripts', 'Litetouch.wsf')
                                            
                                            [Boolean]$MDTBootImageDetected = Test-Path -Path ($MDTBootImageDetectionPath.FullName)
                                                    
                                            Switch ($MDTBootImageDetected)
                                              {
                                                  {($_ -eq $True)}
                                                    {
                                                        $LogDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:SystemDrive, 'MININT', 'SMSOSD', 'OSDLOGS', $CallingScriptPath.BaseName)
                                                    }
                                                
                                                  {($_ -eq $False)}
                                                    {
                                                        $LogDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:Windir, 'Temp', 'SMSTSLog')   
                                                    }
                                              }
                                        }
                                                
                                      Default
                                        {
                                            $LogDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:Windir, 'Logs', 'Software', $CallingScriptPath.BaseName)
                                        }
                                  }   
                            }
                      }
                }       
          }
      #endregion

      #region Define initialization actions  
        [ScriptBlock]$InitializationActions = {                                                                           
                                                  $CallingScriptLogPath = [System.IO.FileInfo][System.IO.Path]::Combine($LogDirectory.FullName, "$($CallingScriptPath.BaseName)_$($GetCurrentDateFileFormat.Invoke()).log")

                                                  If ($CallingScriptLogPath.Directory.Exists -eq $False) {$Null = $CallingScriptLogPath.Directory.Create()}

                                                  $Null = Start-Transcript -Path ($CallingScriptLogPath.FullName) -Force -WhatIf:$False -ErrorAction SilentlyContinue
                                                    
                                                  $WriteLogMessage.Invoke(0, @("Execution of script `"$($CallingScriptPath.Name)`" began on $($CallingScriptStartTime.ToString($DateTimeLogFormat))"))

                                                  $WriteLogMessage.Invoke(0, @("Script Path = $($CallingScriptPath.FullName)"))

                                                  $WriteLogMessage.Invoke(0, @("Script Log Path = $($CallingScriptLogPath.FullName)"))

                                                  $WriteLogMessage.Invoke(0, @("Script Version = $($CallingScriptVersion.ToString())"))

                                                  [String[]]$AvailableCallingScriptParameters = (Get-Command -Name ($CallingScriptPath.FullName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                                                  $WriteLogMessage.Invoke(0, @("Available Script Parameter(s): $($AvailableCallingScriptParameters -Join ', ')"))

                                                  [String[]]$SuppliedCallingScriptParameters = $CallingScriptBoundParameters.GetEnumerator() | ForEach-Object {Try {"-$($_.Key):$($_.Value.GetType().Name)"} Catch {"-$($_.Key):Unknown"}}
                                                  $WriteLogMessage.Invoke(0, @("Supplied Script Parameter(s): $($SuppliedCallingScriptParameters -Join ', ')"))

                                                  $WriteLogMessage.Invoke(0, @("$($CallingScriptBoundParameterCount) bound script parameter(s) were specified."))

                                                  $WriteLogMessage.Invoke(0, @("$($CallingScriptunboundArgumentCount) unbound script arguments were specified."))

                                                  $WriteLogMessage.Invoke(0, @("Process Command Line: $([System.Environment]::CommandLine)"))

                                                  $WriteLogMessage.Invoke(0, @("Process Working Directory: $([System.Environment]::CurrentDirectory)"))

                                                  $WriteLogMessage.Invoke(0, @("Process ID: $($PID)"))

                                                  $WriteLogMessage.Invoke(0, @("Process is 64-Bit: $([System.Environment]::Is64BitProcess)"))
                                              
                                                  Switch ($True)
                                                    {
                                                        {([String]::IsNullOrEmpty($CallingScriptParameterSetName) -eq $False) -and ([String]::IsNullOrWhiteSpace($CallingScriptParameterSetName) -eq $False)}
                                                          {
                                                              $WriteLogMessage.Invoke(0, @("Script Parameter Set Name: $($CallingScriptParameterSetName)"))
                                                          }
                                                    }

                                                  $WriteLogMessage.Invoke(0, @("Attempting to load all required functions, modules, libraries, and variables from the toolkit. Please Wait..."))

                                                  $WriteLogMessage.Invoke(0, @("Toolkit Script Path: $($ToolkitScriptPath.FullName)"))

                                                  $WriteLogMessage.Invoke(0, @("Toolkit Script Version: $($ToolkitScriptVersion.ToString())"))
                                              }
      #endregion

      #region Invoke initialization actions
        $InitializationActions.Invoke()
      #endregion
              
      #region Define finalization actions
        [ScriptBlock]$FinalizationActions = {          
                                                #region If required, save any updated task sequence variables back to the task seqence
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
                                                                                            $WriteLogMessage.Invoke(0, @("Attempting to save the updated task sequence variable of `"$($TSVariableName)`". Please Wait..."))
                                                      
                                                                                            $Null = $TSEnvironment.Value($TSVariableName) = "$($TSVariableNewValue)" 
                                                                                        }
                                                                                  }
                                                                            }
                                                                      }
                                                                }
                                
                                                              $Null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($TSEnvironment)       
                                                          }
                                                    }
                                                #endregion
                                                
                                                $CallingScriptEndTime = [System.DateTime]::UtcNow

                                                $WriteLogMessage.Invoke(0, @("Script execution of `"$($CallingScriptPath.Name)`" ended on $($CallingScriptEndTime.ToString($DateTimeLogFormat))"))
                                                
                                                $CallingScriptExecutionTimespan = New-TimeSpan -Start ($CallingScriptStartTime) -End ($CallingScriptEndTime)

                                                $WriteLogMessage.Invoke(0, @("Script execution took $($CallingScriptExecutionTimespan.Hours.ToString()) hour(s), $($CallingScriptExecutionTimespan.Minutes.ToString()) minute(s), $($CallingScriptExecutionTimespan.Seconds.ToString()) second(s), and $($CallingScriptExecutionTimespan.Milliseconds.ToString()) millisecond(s)."))
                                                
                                                $WriteLogMessage.Invoke(0, @("Exiting script `"$($CallingScriptPath.FullName)`" with exit code $([System.Environment]::ExitCode)."))
                                                
                                                Try {$Null = Stop-Transcript -ErrorAction SilentlyContinue} Catch {}
                                            }
      #endregion

      #region
        Switch ($IsRunningTaskSequence)
          {
              {($_ -eq $True)}
                {                              
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

                    $WriteLogMessage.Invoke(0, @("Attempting to retrieve the task sequence variable list. Please Wait..."))
                      
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

                    $TSVariableListCount = ($TSVariableList | Measure-Object).Count

                    $WriteLogMessage.Invoke(0, @("$($TSVariableListCount) task sequence variables were found."))
                                                                
                    $TSVariableTable = [Ordered]@{}
                                                    
                    ForEach ($TSVariable In $TSVariableList)
                      {
                          $TSVariableName = $TSVariable
                          $TSVariableValue = $TSEnvironment.Value($TSVariableName)
                      
                          Switch ($True)
                            {
                                {($TSVariableName -inotmatch '(^_SMSTSTaskSequence$)|(^TaskSequence$)|(^.*Pass.*word.*$)')}
                                  {
                                      $WriteLogMessage.Invoke(4, @("Attempting to retrieve the value of task sequence variable `"$($TSVariableName)`". Please Wait... [Reference: `$TSVariableTable.`'$($TSVariableName)`']"))
                                  }
                                            
                                {($TSVariableName -iin $TSVariableDecodeList)}
                                  {
                                      Try
                                        {
                                            $WriteLogMessage.Invoke(0, @("Attempting to Base64 decode the `"$($TSVariableName)`" task sequence variable. Please Wait..."))
                                                      
                                            $WriteLogMessage.Invoke(0, @("Original Value: $($TSVariableValue)"))
                                                  
                                            $TSVariableValueBytes = [System.Convert]::FromBase64String($TSVariableValue)
                                            $TSVariableValue = [System.Text.Encoding]::ASCII.GetString($TSVariableValueBytes)

                                            $WriteLogMessage.Invoke(0, @("Toolkit Script Version: The Base64 decode attempt of the `"$($TSVariableName)`" task sequence variable was successful."))
                                        }
                                      Catch
                                        {
                                            $WriteLogMessage.Invoke(0, @("The Base64 decode attempt of the `"$($TSVariableName)`" task sequence variable was unsuccessful. Setting the original value. Please Wait..."))
                                                  
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
      #endregion

      #region Log Powershell Environment Information
        $WriteLogMessage.Invoke(0, @("Powershell Version: $($PSVersionTable.PSVersion.ToString())"))
                    
        #$ExecutionPolicyList = Try {$Null = Get-ExecutionPolicy -List -ErrorAction SilentlyContinue -WarningAction SilentlyContinue} Catch {$Null}

        #$ExecutionPolicyListCount = ($ExecutionPolicyList | Measure-Object).Count
        
        For ($ExecutionPolicyListIndex = 0; $ExecutionPolicyListIndex -lt $ExecutionPolicyListCount; $ExecutionPolicyListIndex++)
          {
              $ExecutionPolicy = $ExecutionPolicyList[$ExecutionPolicyListIndex]

              $WriteLogMessage.Invoke(0, @("The powershell execution policy is currently set to `"$($ExecutionPolicy.ExecutionPolicy.ToString())`" for the `"$($ExecutionPolicy.Scope.ToString())`" scope."))   
          }

        Switch ($PSVersionTable.PSVersion)
          {
              {($_ -ge [Version]'6.0.0.0')}
                {
                    $WriteLogMessage.Invoke(0, @("Powershell Platform: $($PSVersionTable.Platform)", "Powershell Edition: $($PSVersionTable.PSEdition)"))
                    $WriteLogMessage.Invoke(0, @("IsWindows: $($IsWindows)", "IsLinux: $($IsLinux)", "IsMacOS: $($IsMacOS)"))
                }
          }
      #endregion

      #region Log Operating System Information
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
          
        ForEach ($OperatingSystemDetail In $OperatingSystemDetailsTable.GetEnumerator())
          {
              $WriteLogMessage.Invoke(0, @("Operating System $($OperatingSystemDetail.Key): $($OperatingSystemDetail.Value)"))    
          }
      #endregion

      #region Get the values of Windows special folders
        $SpecialFolderNameList = [System.Enum]::GetNames('System.Environment+SpecialFolder') | Sort-Object

        $SpecialFolderDictionary = New-Object -TypeName 'System.Collections.Generic.Dictionary[[System.String], [System.String]]'

        ForEach ($SpecialFolderName In $SpecialFolderNameList)
          {
              $SpecialFolderPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::$($SpecialFolderName))
          
              Switch (([System.String]::IsNullOrEmpty($SpecialFolderPath) -eq $False) -or ([System.String]::IsNullOrWhiteSpace($SpecialFolderPath) -eq $False))
                {
                    {($_ -eq $True)}
                      {
                          $SpecialFolderDictionary.$($SpecialFolderName) = [System.IO.DirectoryInfo][System.IO.Path]::Combine($SpecialFolderPath)
                      }

                    Default
                      {
                          $SpecialFolderDictionary.$($SpecialFolderName) = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:SystemDrive, 'DoesNotExist')
                      }
                }
          }
      #endregion

      #region Log hardware information
        $MSSystemInformationMembers = $MSSystemInformation.PSObject.Properties | Where-Object {($_.MemberType -imatch '^NoteProperty$|^Property$') -and ($_.Name -imatch '^Base.*|Bios.*|System.*$') -and ($_.Name -inotmatch '^.*Major.*|.*Minor.*|.*Properties.*$')} | Sort-Object -Property @('Name')
                
        Switch ($MSSystemInformationMembers.Count -gt 0)
          {
              {($_ -eq $True)}
                {
                    $WriteLogMessage.Invoke(0, @("Attempting to display device information properties from the `"$($MSSystemInformation.CimSystemProperties.ClassName)`" WMI class located within the `"$($MSSystemInformation.CimSystemProperties.Namespace)`" WMI namespace. Please Wait..."))
                    
                    ForEach ($MSSystemInformationMember In $MSSystemInformationMembers)
                      {
                          [String]$MSSystemInformationMemberName = ($MSSystemInformationMember.Name)
                          [String]$MSSystemInformationMemberValue = $MSSystemInformation.$($MSSystemInformationMemberName)
              
                          Switch ([String]::IsNullOrEmpty($MSSystemInformationMemberValue))
                            {
                                {($_ -eq $False)}
                                  {
                                      $WriteLogMessage.Invoke(0, @("$($MSSystemInformationMemberName) = $($MSSystemInformationMemberValue)"))     
                                  }
                            }
                      }
                }

              Default
                {
                    $WriteLogMessage.Invoke(2, @("The `"MSSystemInformation`" WMI class could not be found."))   
                }
          }
      #endregion

      #region Network Adapter and Interface Information
          [ScriptBlock]$GetNetworkConnectionInformation = {
                                                              $NetworkInterfaceObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

                                                              $NetworkIsAvailable = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()

                                                              $WriteLogMessage.Invoke(0, @("Network Connection Is Available: $($NetworkIsAvailable)"))

                                                              Switch ($NetworkIsAvailable)
                                                                {
                                                                    {($_ -eq $True)}
                                                                      {
                                                                          $NetworkInterfaceList = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {($_.NetworkInterfaceType -imatch 'Ethernet.*|Wireless.*') -and ($_.OperationalStatus -iin @('Up'))}

                                                                          $NetworkInterfaceListCount = ($NetworkInterfaceList | Measure-Object).Count

                                                                          $WriteLogMessage.Invoke(0, @("Detected $($NetworkInterfaceListCount) network interfaces that are Ethernet or Wireless and have an operational status of `"Up`"."))

                                                                          Switch ($NetworkInterfaceListCount -gt 0)
                                                                            {
                                                                                {($_ -eq $True)}
                                                                                  {
                                                                                      $NetworkIsConnected = $True
                                                                                    
                                                                                      For ($NetworkInterfaceListIndex = 0; $NetworkInterfaceListIndex -lt $NetworkInterfaceListCount; $NetworkInterfaceListIndex++)
                                                                                        {
                                                                                            $NetworkInterface = $NetworkInterfaceList[$NetworkInterfaceListIndex]
                                                                              
                                                                                            $NetworkInterfaceProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                              $NetworkInterfaceProperties.InterfaceName = $Null
                                                                                              $NetworkInterfaceProperties.Description = $Null
                                                                                              $NetworkInterfaceProperties.MACAddress = $Null
                                                                                              $NetworkInterfaceProperties.IPv4Address = $Null
                                                                                              $NetworkInterfaceProperties.IPv4SubnetMask = $Null
                                                                                              $NetworkInterfaceProperties.IPv4PrefixLength = $Null
                                                                                              $NetworkInterfaceProperties.IPv6Address = $Null
                                                                                              $NetworkInterfaceProperties.Status = $NetworkInterface.OperationalStatus
                                                                                              $NetworkInterfaceProperties.Type = $NetworkInterface.NetworkInterfaceType
                                                          
                                                                                            $NetworkInterfaceProperties.InterfaceName = $NetworkInterface.Name
                                                        
                                                                                            $NetworkInterfaceProperties.Description = $NetworkInterface.Description
                                                        
                                                                                            $NetworkInterfaceMACAddress = If ($NetworkInterface.GetPhysicalAddress() -imatch '.*\:.*') {$NetworkInterface.GetPhysicalAddress()} Else {($NetworkInterface.GetPhysicalAddress() -ireplace '([a-zA-Z0-9]{2,2})', '$1:').TrimEnd(':').ToUpper()}
                                                                                            $NetworkInterfaceProperties.MACAddress = $NetworkInterfaceMACAddress
                                                        
                                                                                            $NetworkInterfaceIPProperties = $NetworkInterface.GetIPProperties()
                                                        
                                                                                            ForEach ($Address In $NetworkInterfaceIPProperties.UnicastAddresses)
                                                                                              {
                                                                                                  Switch ($Address.Address.AddressFamily)
                                                                                                    {
                                                                                                        {($_ -imatch '(^InterNetwork$)')}
                                                                                                          {
                                                                                                              $NetworkInterfaceProperties.IPv4Address = ($Address.Address.IPAddressToString)
                                                                                                              $NetworkInterfaceProperties.IPv4SubnetMask = ($Address.IPv4Mask)
                                                                                                              $NetworkInterfaceProperties.IPv4PrefixLength = ($Address.PrefixLength)
                                                                                                          }
                                                                      
                                                                                                        {($_ -imatch '(^InterNetworkV6$)')}
                                                                                                          {
                                                                                                              $NetworkInterfaceProperties.IPv6Address = ($Address.Address.IPAddressToString.ToUpper())
                                                                                                          }
                                                                                                    }                 
                                                                                              }
                                                          
                                                                                            $NetworkInterfaceObject = New-Object -TypeName 'PSObject' -Property ($NetworkInterfaceProperties)
                                                    
                                                                                            $NetworkInterfaceObjectList.Add($NetworkInterfaceObject)
                                                                                        }
                                        
                                                                                      $NetworkInterfaceObjectListCounter = 1
                                                                        
                                                                                      For ($NetworkInterfaceObjectListIndex = 0; $NetworkInterfaceObjectListIndex -lt $NetworkInterfaceObjectList.Count; $NetworkInterfaceObjectListIndex++)
                                                                                        {
                                                                                            $NetworkInterface = $NetworkInterfaceObjectList[$NetworkInterfaceObjectListIndex]
                                                          
                                                                                            $NetworkInterfacePropertyList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                        
                                                                                            $Null = $NetworkInterface.PSObject.Properties | ForEach-Object {$NetworkInterfacePropertyList.Add("[$($_.Name): $($_.Value -Join ', ')]")}
                                        
                                                                                            $WriteLogMessage.Invoke(0, @("Network Interface #$($NetworkInterfaceObjectListCounter.ToString('00')) - $($NetworkInterfacePropertyList -Join ' ')"))

                                                                                            $NetworkInterfaceObjectListCounter++
                                                                                        }
                                                                                  }

                                                                                Default
                                                                                  {
                                                                                      $NetworkIsConnected = $False
                                                                                  }
                                                                            }
                                                                      }

                                                                    Default
                                                                      {
                                                                          $NetworkIsConnected = $False
                                                                      }
                                                                }

                                                              Write-Output -InputObject ($NetworkIsConnected)
                                                          }

        $IsNetworkConnected = $GetNetworkConnectionInformation.Invoke()
      #endregion

      #region Test Internet Connectivity
        [ScriptBlock]$TestNetworkConnectivity = {
                                                    Param
                                                      (
                                                          [System.URI]$NetworkConnectivityURI
                                                      )

                                                    Try
                                                      {
                                                          $Null = Add-Type -AssemblyName 'System.Net.Http' -IgnoreWarnings -Verbose:$False -ErrorAction SilentlyContinue
                                            
                                                          $HTTPClientHandler = New-Object -TypeName 'System.Net.Http.HttpClientHandler'
                                                            $HTTPClientHandler.AllowAutoRedirect = $True
                                                            $HTTPClientHandler.UseDefaultCredentials = $True
                                                            $HTTPClientHandler.UseCookies = $True

                                                          $HTTPClient = New-Object -TypeName 'System.Net.Http.HttpClient' -ArgumentList ($HTTPClientHandler)
                                                            $HTTPClient.Timeout = [System.TimeSpan]::FromSeconds(30)

                                                          $WriteLogMessage.Invoke(0, @("Attempting to test network connectivity by sending an outbound HTTP(s) request over TCP to `"$($NetworkConnectivityURI)`". Please Wait..."))

                                                          $HTTPResponse = $HTTPClient.GetAsync($NetworkConnectivityURI).GetAwaiter().GetResult()

                                                          $HTTPResponseContent = $HTTPResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                                                          $HTTPResponseContentTruncated = $HTTPResponseContent.Substring(0, [System.Math]::Min($HTTPResponseContent.Length, 256))
                          
                                                          $WriteLogMessage.Invoke(0, @("Network Connectivity Test Succeeded: $($HTTPResponse.IsSuccessStatusCode)", "Network Connectivity Test Status: $($HTTPResponse.StatusCode)", "Network Connectivity Test Status Code: $($HTTPResponse.StatusCode.value__)"))

                                                          Write-Output -InputObject ($HTTPResponse.IsSuccessStatusCode)
                                                      }
                                                    Catch
                                                      {

                                                      }
                                                    Finally
                                                      {
                                                          $Null = Try {$HTTPClient.Dispose()} Catch {}
                                                          $Null = Try {$HTTPClientHandler.Dispose()} Catch {}
                                                      }
                                                }

        $IsInternetConnected = $TestNetworkConnectivity.Invoke('https://www.google.com')
      #endregion

      #region Log Cleanup
        [Int]$MaximumLogHistory = 3
                
        $LogList = Get-ChildItem -Path ($LogDirectory.FullName) -Filter "$($CallingScriptPath.BaseName)_*" -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}

        $SortedLogList = $LogList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -Skip ($MaximumLogHistory)

        Switch ($SortedLogList.Count -gt 0)
          {
              {($_ -eq $True)}
                {
                    $WriteLogMessage.Invoke(0, @("There are $($SortedLogList.Count) log file(s) requiring cleanup."))
        
                    For ($SortedLogListIndex = 0; $SortedLogListIndex -lt $SortedLogList.Count; $SortedLogListIndex++)
                      {
                          Try
                            {
                                $Log = $SortedLogList[$SortedLogListIndex]

                                $LogAge = New-TimeSpan -Start ($Log.LastWriteTime.ToUniversalTime()) -End ([System.DateTime]::UtcNow)

                                $WriteLogMessage.Invoke(0, @("Attempting to cleanup log file `"$($Log.FullName)`". Please Wait... [Last Modified: $($Log.LastWriteTime.ToString($DateTimeMessageFormat))] [Age: $($LogAge.Days.ToString()) day(s); $($LogAge.Hours.ToString()) hours(s); $($LogAge.Minutes.ToString()) minute(s); $($LogAge.Seconds.ToString()) second(s)]."))
                                
                                $Null = [System.IO.File]::Delete($Log.FullName)
                            }
                          Catch
                            {
                        
                            }   
                      }
                }

              Default
                {
                    $WriteLogMessage.Invoke(0, @("There are $($SortedLogList.Count) log file(s) requiring cleanup."))
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
                          $WriteLogMessage.Invoke(0, @("Attempting to load required assembly `"$($RequiredAssembly)`". Please Wait..."))
                                            
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
                          $ModuleCacheRootDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:Windir, 'Temp', 'PSMCache')
                      
                          $ModuleDirectoryList = $ModulesDirectory.GetDirectories()

                          $ModuleDirectoryListCount = ($ModuleDirectoryList | Measure-Object).Count

                          For ($ModuleDirectoryListIndex = 0; $ModuleDirectoryListIndex -lt $ModuleDirectoryListCount; $ModuleDirectoryListIndex++)
                            {
                                $ModuleDirectoryListItem = $ModuleDirectoryList[$ModuleDirectoryListIndex]

                                $ModuleCacheDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ModuleCacheRootDirectory.FullName, $ModuleDirectoryListItem.Name)

                                Switch ([System.IO.Directory]::Exists($ModuleCacheDirectory.FullName))
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $WriteLogMessage.Invoke(0, @("Skipping the local cache of the powershell module `"$($ModuleDirectoryListItem.Name)`". [Reason: The powershell module has already been cached.]"))
                                        }
                                  
                                      {($_ -eq $False)}
                                        {
                                            $WriteLogMessage.Invoke(0, @("Attempting to locally cache the powershell module `"$($ModuleDirectoryListItem.Name)`". Please Wait..."))

                                            If ([System.IO.Directory]::Exists($ModuleCacheDirectory.FullName) -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($ModuleCacheDirectory.FullName)}

                                            $Null = Start-Sleep -Milliseconds 500
                                        
                                            $NUll = Copy-Item -Path ([System.IO.Path]::Combine($ModuleDirectoryListItem.FullName, '*')) -Destination ([System.IO.Path]::Combine("$($ModuleCacheDirectory.FullName)$($DirectorySeparator)")) -Recurse -Force -Verbose:$False  
                                        }
                                  }
                            }

                          $ModulesDirectory = [System.IO.DirectoryInfo]$ModuleCacheRootDirectory.FullName
                      }
                }
          
              $AvailableModules = Get-Module -Name ([System.IO.Path]::Combine($ModulesDirectory.FullName, '*')) -ListAvailable -ErrorAction Stop 

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
                                      $WriteLogMessage.Invoke(0, @("$($LatestAvailableModuleVersion.RequiredModules.Count) prerequisite powershell module(s) need to be imported before the powershell of `"$($LatestAvailableModuleVersion.Name)`" can be imported."))

                                      $WriteLogMessage.Invoke(0, @("Prequisite Module List: $($LatestAvailableModuleVersion.RequiredModules.Name -Join '; ')"))
                                  
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

                                                                    $WriteLogMessage.Invoke(0, @("Attempting to import prerequisite powershell module `"$($RequiredModuleDetails.Name)`" [Version: $($RequiredModuleDetails.Version.ToString())]. Please Wait..."))

                                                                    $WriteLogMessage.Invoke(0, @("Prerequisite Module Path: $($RequiredModuleDetails.ModuleBase)"))
                                                                
                                                                    $Null = Import-Module -Name "$($RequiredModuleDetails.Path)" -Global -DisableNameChecking -Force -ErrorAction Stop 
                                                                }
                                                          }     
                                                    }
                                              }
                                        }
                                  }
                            }

                          $WriteLogMessage.Invoke(0, @("Attempting to import dependency powershell module `"$($LatestAvailableModuleVersion.Name)`" [Version: $($LatestAvailableModuleVersion.Version.ToString())]. Please Wait..."))

                          $WriteLogMessage.Invoke(0, @("Module Path: $($LatestAvailableModuleVersion.Path)"))

                          $Null = Import-Module -Name "$($LatestAvailableModuleVersion.Path)" -Global -DisableNameChecking -Force
                      }
                }
          }
      #endregion
  
      #region Dot Source Dependency Scripts
        Switch ($FunctionsDirectory.Exists)
          {
              {($_ -eq $True)}
                {
                    $AdditionalFunctionsFilter = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      $AdditionalFunctionsFilter.Add('*.ps1')

                    $AdditionalFunctionsToImport = Get-ChildItem -Path "$($FunctionsDirectory.FullName)" -Include ($AdditionalFunctionsFilter) -Recurse -Force -ErrorAction SilentlyContinue| Where-Object {($_ -is [System.IO.FileInfo])}

                    $AdditionalFunctionsToImportCount = ($AdditionalFunctionsToImport | Measure-Object).Count

                    Switch ($AdditionalFunctionsToImportCount -gt 0)
                      {                    
                          {($_ -eq $True)}
                            {
                                $AdditionalFunctionsToImportCounter = 1  

                                For ($AdditionalFunctionsToImportIndex = 0; $AdditionalFunctionsToImportIndex -lt $AdditionalFunctionsToImportCount; $AdditionalFunctionsToImportIndex++)
                                  {
                                      $AdditionalFunctionToImport = $AdditionalFunctionsToImport[$AdditionalFunctionsToImportIndex]

                                      $WriteLogMessage.Invoke(0, @("Attempting to dot source the functions contained within the dependency script $($AdditionalFunctionsToImportCounter) of $($AdditionalFunctionsToImportCount). Please Wait... [Path: `"$($AdditionalFunctionToImport.FullName)`"]"))
                  
                                      . "$($AdditionalFunctionToImport.FullName)"

                                      $AdditionalFunctionsToImportCounter++
                                  }
                            }
                      }
                }
          }
      #endregion

      #region Load any required libraries
        $LibariesDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($FunctionsDirectory.FullName, 'Libraries')

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

                                                  $WriteLogMessage.Invoke(0, @("Attempting to load assembly `"$($Library.FullName)`". Please Wait..."))

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

      #region Scriptblock to pause script execution
        [ScriptBlock]$PauseScriptExecution = {
                                                  Param
                                                    (
                                                        [System.TimeSpan]$Duration
                                                    )

                                                  $WriteLogMessage.Invoke(0, @("Attempting to pause script execution for $($Duration.TotalSeconds). Please Wait..."))
                                    
                                                  $Null = Start-Sleep -Seconds ($Duration.TotalSeconds)
                                             }
      #endregion

      #region This should always be the last command of the toolkit
        $WriteLogMessage.Invoke(0, @("All required functions, modules, libraries, and variables have been loaded from the toolkit successfully."))
      #endregion
  }
Catch
  {
      $WriteLogMessage.Invoke(3, @("Some or all of the required functions, modules, libraries, and variables have failed to load from the toolkit. No further action will be taken.", "Message: $($_.Exception.Message)", "Code: $($_.InvocationInfo.Line)"))
            
      Throw
  }
Finally
  {
      
  }