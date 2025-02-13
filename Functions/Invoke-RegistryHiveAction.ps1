## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Invoke-RegistryHiveAction
Function Invoke-RegistryHiveAction
    {
        <#
          .SYNOPSIS
          A brief overview of what your function does
          
          .DESCRIPTION
          Slightly more detailed description of what your function does
          
          .PARAMETER HivePath
          A valid file path to a valid registry hive. 

          .PARAMETER KeyPath
          One or more registry key paths that are relative to the specified registry hive.

          .PARAMETER ValueNameExpression
          One or more regular expressions that will determine which registry value names will be extracted from the specified registry hive.
          
          .EXAMPLE
          Invoke-RegistryHiveAction -HivePath "$($Env:Userprofile)\Downloads\RegistryHives\SOFTWARE" -KeyPath @('Root\Microsoft\Windows NT\CurrentVersion') -ValueNameExpression @('.*') -Verbose

          .EXAMPLE
          $InvokeRegistryHiveActionParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $InvokeRegistryHiveActionParameters.HivePath = "$($Env:Userprofile)\Downloads\RegistryHives\SOFTWARE"
            $InvokeRegistryHiveActionParameters.KeyPath = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $InvokeRegistryHiveActionParameters.KeyPath.Add('Root\Microsoft\Windows NT\CurrentVersion')
            $InvokeRegistryHiveActionParameters.ValueNameExpression = New-Object -TypeName 'System.Collections.Generic.List[Regex]'
              $InvokeRegistryHiveActionParameters.ValueNameExpression.Add('.*')
            $InvokeRegistryHiveActionParameters.ContinueOnError = $False
            $InvokeRegistryHiveActionParameters.Verbose = $True

          $InvokeRegistryHiveActionResult = Invoke-RegistryHiveAction @InvokeRegistryHiveActionParameters

          Write-Output -InputObject ($InvokeRegistryHiveActionResult)
  
          .NOTES
          Please ensure that the specified registry hive is not in use!
          
          .LINK
          https://github.com/EricZimmerman/Registry
        #>
        
        [CmdletBinding()]
       
        Param
          (                        
              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [ValidateScript({(Test-Path -Path $_)})]
              [System.IO.FileInfo]$HivePath,

              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [ValidatePattern('^Root\\.+')]
              [String[]]$KeyPath,

              [Parameter(Mandatory=$False)]
              [Regex[]]$ValueNameExpression,
                                                            
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
                    [System.IO.DirectoryInfo]$System32Directory = [System.Environment]::SystemDirectory    
                    $RegexOptionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions]'
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    $ValueNameExpressionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.Regex]'

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
                    Write-Verbose -Message ($LoggingDetails.LogMessage)
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      
                    [String[]]$AvailableScriptParameters = (Get-Command -Name ($FunctionName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Available Function Parameter(s) = $($AvailableScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage)

                    [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage)

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of $($FunctionName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message ($LoggingDetails.LogMessage)

                    #region Load any required libraries
                      [System.IO.DirectoryInfo]$LibariesDirectory = "$($FunctionDirectory.FullName)\Libraries"

                      Switch ([System.IO.Directory]::Exists($LibariesDirectory.FullName))
                        {
                            {($_ -eq $True)}
                              {
                                  $LibraryPatternList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                    $LibraryPatternList.Add('NFluent.dll')
                                    $LibraryPatternList.Add('NLog.dll')
                                    $LibraryPatternList.Add('Registry.dll')

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
              
                                                                [Byte[]]$LibraryBytes = [System.IO.File]::ReadAllBytes($Library.FullName)
              
                                                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to load assembly `"$($Library.FullName)`". Please Wait..."
                                                                Write-Verbose -Message ($LoggingDetails.LogMessage)
              
                                                                $Null = [System.Reflection.Assembly]::Load($LibraryBytes)     
                                                            }
                                                      }
                                                }
                                          }
                                    }        
                              }
                        }
                    #endregion
                                        
                    #Create an object that will contain the functions output.
                      $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

                    #Set default parameter values
                      Switch ($True)
                        {
                            {($Null -ieq $ValueNameExpression) -or ($ValueNameExpression.Count -eq 0)}
                              {        
                                  $ValueNameExpression += '.*'
                              }
                          
                            {($Null -ine $ValueNameExpression) -or ($ValueNameExpression.Count -gt 0)}
                              {        
                                  $ValueNameExpression | ForEach-Object {$ValueNameExpressionList.Add((New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList @($_, $RegexOptionList)))}
                              }
                        }      
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
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to load registry hive `"$($HivePath.FullName)`" on demand. Please Wait..." 
                    Write-Verbose -Message ($LoggingDetails.LogMessage)

                    $RegistryHive = New-Object -TypeName 'Registry.RegistryHiveOnDemand' -ArgumentList ($HivePath.FullName)
                    
                    ForEach ($Key In $KeyPath)
                      {                        
                          Try
                            {
                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to retrieve the details of registry key path `"$($Key)`". Please Wait..." 
                                Write-Verbose -Message ($LoggingDetails.LogMessage)
                            
                                $RegistryKeyProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                  $RegistryKeyProperties.Path = $Key
                                  $RegistryKeyProperties.ValueList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                              
                                $RegistryKey = $RegistryHive.GetKey($Key)
      
                                ForEach ($Item In $RegistryKey.Values)
                                  {
                                      ForEach ($Expression In $ValueNameExpressionList)
                                        {
                                            $ExpressionEvaluation = $Expression.Match($Item.ValueName)
      
                                            Switch ($ExpressionEvaluation.Success)
                                              {
                                                  {($_ -eq $True)}
                                                    {
                                                        $ValueProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $ValueProperties.Name = $Item.ValueName
                                                          $ValueProperties.Alias = $ValueProperties.Name -ireplace '(\s+)', ''
                                                          $ValueProperties.Type = $Item.ValueType
                                                          $ValueProperties.Value = $Null
                                                          $ValueProperties.ValueAsDecimal = $Null
                                                          $ValueProperties.ValueAsHex = $Null

                                                        #$LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to retrieve the registry key value of `"$($ValueProperties.Name)`" because the value name matches the regular expression of `"$($Expression.ToString())`". Please Wait..." 
                                                        #Write-Verbose -Message ($LoggingDetails.LogMessage)
      
                                                        Switch ($Null -ine $Item.ValueData)
                                                          {
                                                              {($_ -eq $True)}
                                                                {
                                                                    $ValueProperties.Value = $Item.ValueData
      
                                                                    Switch ($ValueProperties.Type)
                                                                      {
                                                                          {($_ -iin @('RegDword', 'RegQword'))}
                                                                            {
                                                                                $ValueProperties.ValueAsDecimal = Try {[System.Convert]::ToString($ValueProperties.Value, 10)} Catch {}
                                                                                $ValueProperties.ValueAsHex = Try {'0x' + [System.Convert]::ToString($ValueProperties.Value, 16).PadLeft(8, '0').ToUpper()} Catch {}  
                                                                            }
      
                                                                          {($_ -iin @('RegBinary'))}
                                                                            {
                                                                                #$ValueProperties.ValueAsDecimal = Try {} Catch {}
                                                                                #$ValueProperties.ValueAsHex = Try {} Catch {}
                                                                            }
                                                                      }
                                                                }
                                                          }
                                                            
                                                        $ValueObject = New-Object -TypeName 'PSObject' -Property ($ValueProperties)
                                                      
                                                        $RegistryKeyProperties.ValueList.Add($ValueObject)
                                                    }
                                              }
                                        }
                                  }
      
                                $RegistryKeyObject = New-Object -TypeName 'PSObject' -Property ($RegistryKeyProperties)
      
                                $OutputObjectList.Add($RegistryKeyObject)
                            }
                          Catch
                            {
                                $ErrorMessageList = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                $ErrorMessageList.Add('Message', $_.Exception.Message)
                                $ErrorMessageList.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                $ErrorMessageList.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                $ErrorMessageList.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                $ErrorMessageList.Add('Code', $_.InvocationInfo.Line.Trim())

                                ForEach ($ErrorMessage In $ErrorMessageList.GetEnumerator())
                                  {
                                      $LoggingDetails.ErrorMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) -  ERROR: $($ErrorMessage.Key): $($ErrorMessage.Value)"
                                      Write-Warning -Message ($LoggingDetails.ErrorMessage)
                                  }
                            }
                          Finally
                            {

                            }             
                      }                        
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
                      Write-Verbose -Message ($LoggingDetails.LogMessage)

                    #Log the total script execution time  
                      $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                      Write-Verbose -Message ($LoggingDetails.LogMessage)
                    
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is completed."
                    Write-Verbose -Message ($LoggingDetails.LogMessage)
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
              Finally
                {
                    #Write the object to the powershell pipeline
                      $OutputObjectList = $OutputObjectList.ToArray()

                      Write-Output -InputObject ($OutputObjectList)
                }
          }
    }
#endregion