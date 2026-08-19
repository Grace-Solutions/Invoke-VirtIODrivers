#region Start-ProcessWithOutput
Function Start-ProcessWithOutput
  {
      <#
          .SYNOPSIS
          Allows for the execution of processes with the ability to return their output without first dumping the content to a file. It can all be kept in memory.
          
          .DESCRIPTION
          This is not the best option when your process returns a large enough amount of output to cause a memory leak or overflow.
          
          .PARAMETER FilePath
	        Your parameter description

          .PARAMETER WorkingDirectory
	        Your parameter description

          .PARAMETER ArgumentList
	        Your parameter description

          .PARAMETER AcceptableExitCodeList
	        A * can be used to accept all exit codes.

          .PARAMETER WindowStyle
	        Your parameter description

          .PARAMETER CreateNoWindow
	        Your parameter description

          .PARAMETER ExecutionTimeout
	        Your parameter description

          .PARAMETER ExecutionTimeoutInterval
	        Your parameter description

          .PARAMETER StandardInputObject
	        Your parameter description

          .PARAMETER ParsingExpression
	        A valid regular expression that will allow for the output to be parsed into objects.

          .PARAMETER SecureArgumentList
	        Your parameter description

          .PARAMETER LogOutput
	        Your parameter description
          
          .EXAMPLE
          Start-ProcessWithOutput -FilePath 'cmd.exe' -ArgumentList '/c ipconfig /all' -AcceptableExitCodeList @('*') -CreateNoWindow -NoWait -Verbose
          
          .EXAMPLE
          Start-ProcessWithOutput -FilePath 'cmd.exe' -ArgumentList '/c ipconfig /all' -AcceptableExitCodeList @('*') -CreateNoWindow -Timeout ([System.TimeSpan]::FromSeconds(30)) -Verbose

          .EXAMPLE
          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	          $StartProcessWithOutputParameters.FilePath = "dsregcmd.exe"
	          $StartProcessWithOutputParameters.WorkingDirectory = "$([System.Environment]::SystemDirectory)"
	          $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
		          $StartProcessWithOutputParameters.ArgumentList.Add('/status')
	          $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[String]'
		          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
	          $StartProcessWithOutputParameters.WindowStyle = "Hidden"
            $StartProcessWithOutputParameters.Priority = "Normal"
	          $StartProcessWithOutputParameters.ParsingExpression = "(?:\s+)(?<PropertyName>.+)(?:\s+\:\s+)(?<PropertyValue>.+)"
	          $StartProcessWithOutputParameters.LogOutput = $True
	          $StartProcessWithOutputParameters.ExecutionTimeout = [Timespan]::FromMinutes(1)
	          $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [Timespan]::FromSeconds(30)
	          $StartProcessWithOutputParameters.StandardInputObjectList = New-Object -TypeName 'System.Collections.Generic.List[System.Object]'
		          $StartProcessWithOutputParameters.StandardInputObjectList.Add('S')
            $StartProcessWithOutputParameters.SecureArgumentList = $False
	          $StartProcessWithOutputParameters.Verbose = $True

          $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

          Write-Output -InputObject ($StartProcessWithOutputResult)

          .EXAMPLE
          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
	          $StartProcessWithOutputParameters.FilePath = "dsregcmd.exe"
	          $StartProcessWithOutputParameters.WorkingDirectory = "$([System.Environment]::SystemDirectory)"
	          $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
		          $StartProcessWithOutputParameters.ArgumentList.Add('/status')
	          $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[String]'
		          $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
	          $StartProcessWithOutputParameters.WindowStyle = "Hidden"
            $StartProcessWithOutputParameters.Priority = "Normal"
	          $StartProcessWithOutputParameters.ParsingExpression = "(?:\s+)(?<PropertyName>.+)(?:\s+\:\s+)(?<PropertyValue>.+)"
	          $StartProcessWithOutputParameters.LogOutput = $True
	          $StartProcessWithOutputParameters.ExecutionTimeout = [Timespan]::FromMinutes(1)
	          $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [Timespan]::FromSeconds(30)
	          $StartProcessWithOutputParameters.StandardInputObjectList = New-Object -TypeName 'System.Collections.Generic.List[System.Object]'
		          $StartProcessWithOutputParameters.StandardInputObjectList.Add('S')
            $StartProcessWithOutputParameters.SecureArgumentList = $True
	          $StartProcessWithOutputParameters.Verbose = $True

          $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

          Write-Output -InputObject ($StartProcessWithOutputResult)
  
          .NOTES
          Mileage may vary when parsing output and may have to be done using additional code outside of this function to address specific needs.
          
          .LINK
          Place any useful link here where your function or cmdlet can be referenced
      #>
      
      [CmdletBinding(DefaultParameterSetName = 'WindowStyle')] 
        Param
          (        
              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [Alias('FP')]
              [String]$FilePath,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('WD')]
              [System.IO.DirectoryInfo]$WorkingDirectory,
                
              [Parameter(Mandatory=$False)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [Alias('AL')]
              [String[]]$ArgumentList,

              [Parameter(Mandatory=$False)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [Alias('AECL')]
              [String[]]$AcceptableExitCodeList,

              [Parameter(Mandatory=$False, ParameterSetName = 'WindowStyle')]
              [ValidateNotNullOrEmpty()]
              [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
              [Alias('WS')]
              [String]$WindowStyle,

              [Parameter(Mandatory=$False, ParameterSetName = 'CreateNoWindow')]
              [Alias('CNW')]
              [Switch]$CreateNoWindow,

              [Parameter(Mandatory=$False)]
              [Alias('NW')]
              [Switch]$NoWait,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [ValidateSet('AboveNormal', 'BelowNormal', 'High', 'Idle', 'Normal', 'RealTime')]
              [Alias('P')]
              [String]$Priority,

              [Parameter(Mandatory=$False)]
              [Alias('ET')]
              [System.Timespan]$ExecutionTimeout,

              [Parameter(Mandatory=$False)]
              [Alias('ETI')]
              [System.Timespan]$ExecutionTimeoutInterval,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('SIO')]
              [System.Object[]]$StandardInputObjectList,
              
              [Parameter(Mandatory=$False)]
              [AllowEmptyString()]
              [AllowNull()]
              [Alias('StandardOutputParsingExpression', 'SOPE', 'PE')]
              [Regex]$ParsingExpression,

              [Parameter(Mandatory=$False)]
              [Alias('SAL')]
              [Switch]$SecureArgumentList,

              [Parameter(Mandatory=$False)]
              [Alias('LO')]
              [Switch]$LogOutput,

              [Parameter(Mandatory=$False)]
              [Alias('COE')]
              [Switch]$ContinueOnError
          )
                  
      Try
        {
            $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'  ###Monday, January 01, 2019 @ 10:15:34.000 AM###
            [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
            

            

            
            $CommonParameterList = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::CommonParameters)
              $CommonParameterList.AddRange([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

            #Determine the date and time we executed the function
            $FunctionStartTime = (Get-Date)
            
            [String]$CmdletName = $MyInvocation.MyCommand.Name
            
            $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is beginning. Please Wait..."))
      
            #Define Default Action Preferences
              $ErrorActionPreference = 'Stop'
              
            [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
            $WriteLogMessage.Invoke(0, @("Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"))

            $WriteLogMessage.Invoke(0, @("Execution of $($CmdletName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"))

            $WriteLogMessage.Invoke(0, @("Parameter Set Name: $($PSCmdlet.ParameterSetName)"))

            #Set default parameter values (If necessary)
              Switch ($True)
                {
                    {([String]::IsNullOrEmpty($WindowStyle) -eq $True) -or ([String]::IsNullOrWhiteSpace($WindowStyle) -eq $True)}
                      {
                          [String]$WindowStyle = 'Hidden'
                      }

                    {([String]::IsNullOrEmpty($Priority) -eq $True) -or ([String]::IsNullOrWhiteSpace($Priority) -eq $True)}
                      {
                          [String]$Priority = 'Normal'
                      }

                    {($Null -ine $ExecutionTimeout)}
                      {
                          Switch ($Null -ieq $ExecutionTimeoutInterval)
                            {
                                {($_ -eq $True)}
                                  {
                                      $ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(15)
                                  }
                            }
                      }
                }

            [ScriptBlock]$GetTimeSpanMessage = {
                                                    Param
                                                      (
                                                          [System.TimeSpan]$InputObject
                                                      )

                                                    $InputObjectMessageBuilder = New-Object -TypeName 'System.Text.StringBuilder'

                                                    $InputObjectProperties = $InputObject | Select-Object -Property @('Days', 'Hours', 'Minutes', 'Seconds', 'Milliseconds')
                                        
                                                    $InputObjectPropertyNameList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'

                                                    ($InputObjectProperties.PSObject.Properties | Where-Object {($_.Value -gt 0)}).Name | ForEach-Object {($InputObjectPropertyNameList.Add($_))}

                                                    $InputObjectPropertyNameListUpperBound = $InputObjectPropertyNameList.ToArray().GetUpperBound(0)
                                        
                                                    For ($InputObjectPropertyNameListIndex = 0; $InputObjectPropertyNameListIndex -lt $InputObjectPropertyNameList.Count; $InputObjectPropertyNameListIndex++)
                                                      {
                                                          $InputObjectPropertyName = $InputObjectPropertyNameList[$InputObjectPropertyNameListIndex]
                                              
                                                          $InputObjectPropertyValue = $InputObject.$($InputObjectPropertyName)

                                                          Switch ($True)
                                                            {
                                                                {($InputObjectPropertyNameList.Count -gt 1) -and ($InputObjectPropertyNameListIndex -eq $InputObjectPropertyNameListUpperBound)}
                                                                  {
                                                                      $Null = $InputObjectMessageBuilder.Append('and ')
                                                                  }
                                                    
                                                                {($InputObjectPropertyValue -eq 1)}
                                                                  {                                                          
                                                                      $Null = $InputObjectMessageBuilder.Append("$($InputObjectPropertyValue) $($InputObjectPropertyName.TrimEnd('s').ToLower())")
                                                                  }

                                                                {($InputObjectPropertyValue -gt 1)}
                                                                  {
                                                                      $Null = $InputObjectMessageBuilder.Append("$($InputObjectPropertyValue) $($InputObjectPropertyName.ToLower())")
                                                                  }

                                                                {($InputObjectPropertyNameList.Count -gt 1) -and ($InputObjectPropertyNameListIndex -ne $InputObjectPropertyNameListUpperBound)}
                                                                  {
                                                                      $Null = $InputObjectMessageBuilder.Append(', ')
                                                                  }
                                                            }
                                                      }

                                                    $OutputObject = $InputObjectMessageBuilder.ToString()
                                        
                                                    Switch ($InputObjectMessageBuilder.Length -gt 0)
                                                      {
                                                          {($_ -eq $True)}
                                                            { 
                                                                $OutputObject = $InputObjectMessageBuilder.ToString()
                                                            }

                                                          Default
                                                            {
                                                                $OutputObject = 'N/A'
                                                            }
                                                      }
                                        
                                                    Write-Output -InputObject ($OutputObject)
                                                }

            [ScriptBlock]$WriteStandardOutputStream = {
                                                          Param
                                                            (
                                                                [System.Object[]]$StandardInputObjectList,
                                                                [Switch]$SecureArgumentList
                                                            )
                                                          
                                                          Switch (($Null -ine $StandardInputObjectList) -and ($StandardInputObjectList.Count -gt 0))
                                                            {
                                                                {($_ -eq $True)}
                                                                  {
                                                                      $StandardInputObjectListCounter = 1
                                    
                                                                      For ($StandardInputObjectListIndex = 0; $StandardInputObjectListIndex -lt $StandardInputObjectList.Count; $StandardInputObjectListIndex++)
                                                                        {
                                                                            Try
                                                                              {
                                                                                  $StandardInputObject = $StandardInputObjectList[$StandardInputObjectListIndex]

                                                                                  Switch ($SecureArgumentList.IsPresent)
                                                                                    {
                                                                                        {($_ -eq $True)}
                                                                                          {
                                                                                              $ObfuscationCharacter = '*'

                                                                                              $ObfuscationCharacterCount = Get-Random -Minimum 5 -Maximum 20

                                                                                              $ObfuscationValue = $ObfuscationCharacter.PadRight($ObfuscationCharacterCount, $ObfuscationCharacter)
                                    
                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to write standard input object $($StandardInputObjectListCounter) of $($StandardInputObjectList.Count) to the standard input stream for process ID $($Process.ID). Please Wait..."))

                                                                                              $WriteLogMessage.Invoke(0, @("Object Value: $($ObfuscationValue)"))
                                                                                          }

                                                                                        Default
                                                                                          {
                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to write standard input object $($StandardInputObjectListCounter) of $($StandardInputObjectList.Count) to the standard input stream for process ID $($Process.ID). Please Wait..."))

                                                                                              $WriteLogMessage.Invoke(0, @("Object Value: $($StandardInputObject)"))
                                                                                          }
                                                                                    }

                                                                                  $Null = $Process.StandardInput.WriteLine($StandardInputObject)
                                                                              }
                                                                            Catch
                                                                              {
                                                                                  $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                    $ExceptionPropertyDictionary.Add('Message', $_.Exception.Message)
                                                                                    $ExceptionPropertyDictionary.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
                                                                                    $ExceptionPropertyDictionary.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
                                                                                    $ExceptionPropertyDictionary.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
                                                                                    $ExceptionPropertyDictionary.Add('Code', $_.InvocationInfo.Line.Trim())

                                                                                  $ExceptionMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'

                                                                                  ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
                                                                                    {
                                                                                        $ExceptionMessageList.Add("[$($ExceptionProperty.Key): $($ExceptionProperty.Value)]")
                                                                                    }

                                                                                  $WriteLogMessage.Invoke(2, @("$($ExceptionMessageList -Join ' ')"))
                                                                              }
                                                                            Finally
                                                                              {
                                                                                  $StandardInputObjectListCounter++
                                                                              }     
                                                                        }  
                                                                  }
                                                            }
                                                      }
            
            $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $OutputObjectProperties.ExitCode = -1
              $OutputObjectProperties.ExitCodeAsHex = $Null
              $OutputObjectProperties.ExitCodeAsInteger = $Null
              $OutputObjectProperties.ExitCodeAsDecimal = $Null
              $OutputObjectProperties.ProcessObject = $Null
              $OutputObjectProperties.StandardOutput = $Null
              $OutputObjectProperties.StandardOutputObject = $Null
              $OutputObjectProperties.StandardError = $Null
              $OutputObjectProperties.StandardErrorObject = $Null
        
            $Process = New-Object -TypeName 'System.Diagnostics.Process'
              $Process.StartInfo.FileName = $FilePath
              $Process.StartInfo.UseShellExecute = $False          
              $Process.StartInfo.RedirectStandardOutput = $True
              $Process.StartInfo.RedirectStandardError = $True
              $Process.StartInfo.RedirectStandardInput = $True

            Switch ($True)
              {
                  {([String]::IsNullOrEmpty($WorkingDirectory.FullName) -eq $False) -and ([String]::IsNullOrWhiteSpace($WorkingDirectory.FullName) -eq $False)}
                    {
                        Switch ($True)
                          {
                              {([System.IO.Directory]::Exists($WorkingDirectory.FullName) -eq $False)}
                                {
                                    $WriteLogMessage.Invoke(0, @("Attempting to create the non-existing process working directory. Please Wait..."))

                                    $WriteLogMessage.Invoke(0, @("Path: $($WorkingDirectory.FullName)"))
                                    
                                    $Null = [System.IO.Directory]::CreateDirectory($WorkingDirectory.FullName)
                                }
                          }
                        
                        $Process.StartInfo.WorkingDirectory = $WorkingDirectory.FullName
                    }
              }
                  
            Switch ($PSCmdlet.ParameterSetName)
              {
                  {($_ -iin @('CreateNoWindow'))}
                    {
                        $Process.StartInfo.CreateNoWindow = $True
                    }

                  {($_ -iin @('WindowStyle'))}
                    {
                        $Process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::"$($WindowStyle)"     
                    }
              }
 
            Switch (($Null -ieq $AcceptableExitCodeList) -or ($AcceptableExitCodeList.Count -eq 0))
              {
                  {($_ -eq $True)}
                    {
                        $DefaultExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $DefaultExitCodeList.Add('0')
                          $DefaultExitCodeList.Add('3010')
                        
                        $AcceptableExitCodeList = $DefaultExitCodeList.ToArray()     
                    }
              }
            
            $CommandExecutionMessageBuilder = New-Object -TypeName 'System.Text.StringBuilder'
            
            $Null = $CommandExecutionMessageBuilder.Append('Attempting to execute the following command:')          
            $Null = $CommandExecutionMessageBuilder.Append(' ')
            $Null = $CommandExecutionMessageBuilder.Append($Process.StartInfo.FileName)
            
            Switch (($Null -ine $ArgumentList) -and ($ArgumentList.Count -gt 0))
              {
                  {($_ -eq $True)}
                    {
                        $Process.StartInfo.Arguments = $ArgumentList -Join ' '

                        Switch ($SecureArgumentList.IsPresent)
                          {
                              {($_ -eq $True)}
                                {
                                    $ObfuscationCharacter = '*'

                                    $ObfuscationCharacterCount = Get-Random -Minimum 5 -Maximum ($Process.StartInfo.Arguments.Length)

                                    $ObfuscationValue = $ObfuscationCharacter.PadRight($ObfuscationCharacterCount, $ObfuscationCharacter)
                                    
                                    $Null = $CommandExecutionMessageBuilder.Append(' ')   
                                    $Null = $CommandExecutionMessageBuilder.Append($ObfuscationValue)
                                }

                              Default
                                {
                                    $Null = $CommandExecutionMessageBuilder.Append(' ')   
                                    $Null = $CommandExecutionMessageBuilder.Append($Process.StartInfo.Arguments)
                                }
                          } 
                    }
              }
              
            $WriteLogMessage.Invoke(0, @("$($CommandExecutionMessageBuilder.ToString())"))

            $WriteLogMessage.Invoke(0, @("Acceptable Exit Code List: $($AcceptableExitCodeList -Join '; ')"))

            Switch ($NoWait.IsPresent)
              {
                  {($_ -eq $True)}
                    { 
                        $Null = $Process.Start()

                        $WriteLogMessage.Invoke(0, @("Skipping the execution wait for process ID $($Process.ID)."))

                        $WriteLogMessage.Invoke(0, @("[ProcessName: $([System.IO.Path]::GetFileName($Process.Path))] [ID: $($Process.ID)] [Version: $($Process.FileVersion)] [Description: $($Process.Description)] [Path: $($Process.Path)] "))

                        $Null = $WriteStandardOutputStream.InvokeReturnAsIs($StandardInputObjectList, $SecureArgumentList.IsPresent)

                        $OutputObjectProperties.StandardOutput = $Null
                        $OutputObjectProperties.StandardError = $Null
                    }

                  Default
                    {
                        Switch ($Null -ieq $ExecutionTimeout)
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("A timeout was not specified for process ID $($Process.ID)."))

                                    $WriteLogMessage.Invoke(0, @("The wait for process ID $($Process.ID) termination will be indefinite."))
                                }

                              Default
                                {                                    
                                    $ProcessTimeoutStopWatch = New-Object -TypeName 'System.Diagnostics.StopWatch'
                                    
                                    $Null = $ProcessTimeoutStopWatch.Start()
                                }
                          }

                        $Null = $Process.Start()
                        
                        Switch ($Process.PriorityClass -ine $Priority)
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("Attempting to change the process priority class for process ID $($Process.ID) from `"$($Process.PriorityClass)`" to `"$($Priority)`". Please Wait..."))
                        
                                    $Null = $Process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::"$($Priority)" 
                                }
                          }

                        $WriteLogMessage.Invoke(0, @("[ProcessName: $([System.IO.Path]::GetFileName($Process.Path))] [ID: $($Process.ID)] [Version: $($Process.FileVersion)] [Description: $($Process.Description)] [Path: $($Process.Path)] "))

                        $WriteLogMessage.Invoke(0, @("Process Start Time: $($Process.StartTime.ToString($DateTimeLogFormat))"))

                        Switch ($Null -ine $ExecutionTimeout)
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("Process Timeout Time: $($Process.StartTime.AddTicks($ExecutionTimeout.Ticks).ToString($DateTimeLogFormat))"))

                                    $WriteLogMessage.Invoke(0, @("Process Timeout Duration: $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeout))"))
                                }
                          }

                        $Null = $WriteStandardOutputStream.InvokeReturnAsIs($StandardInputObjectList, $SecureArgumentList.IsPresent)
                        
                        $OutputObjectProperties.StandardOutput = $Process.StandardOutput.ReadToEndAsync()
                        $OutputObjectProperties.StandardError = $Process.StandardError.ReadToEndAsync()

                        $ProcessTimeOutLoopCondition = {$Process.HasExited -eq $False}
                        
                        :ProcessTimeoutLoop While ($ProcessTimeOutLoopCondition.InvokeReturnAsIs() -eq $True)
                          {
                              $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) has been running for $($GetTimeSpanMessage.InvokeReturnAsIs($ProcessTimeoutStopWatch.Elapsed))."))

                              Switch ($Null -ine $ExecutionTimeout)
                                { 
                                    {($_ -eq $True)}  
                                      {
                                          Switch ($ProcessTimeoutStopWatch.Elapsed.TotalMilliseconds -le $ExecutionTimeout.TotalMilliseconds)
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) has not exceeded the maximum timeout duration of $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeout))."))
                                                  }

                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) has exceeded the maximum timeout duration of $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeout))."))
                                          
                                                      Try
                                                        {
                                                            $WriteLogMessage.Invoke(0, @("Attempting to forcibly terminate the process ID $($Process.ID). Please Wait..."))
                                                                        
                                                            $Null = $Process.Kill()

                                                            Switch ($?)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $WriteLogMessage.Invoke(0, @("Process ID $($Process.ID) was forcibly terminated successfully."))
                                                                    }
                                                              }
                                                        }
                                                      Catch
                                                        {
                                                            $WriteLogMessage.Invoke(2, @("$($_.Exception.Message)"))
                                                        }
                                          
                                                      Break ProcessTimeoutLoop
                                                  }
                                            }
                                      }
                                }

                              $WriteLogMessage.Invoke(0, @("Checking again in another $($GetTimeSpanMessage.InvokeReturnAsIs($ExecutionTimeoutInterval)). Please Wait..."))
                                          
                              $Null = Start-Sleep -Milliseconds ($ExecutionTimeoutInterval.TotalMilliseconds)
                          }
                                                
                        $OutputObjectProperties.ExitCode = Try {$Process.ExitCode} Catch {$Null}
                        $OutputObjectProperties.ExitCodeAsHex = Try {'0x' + [System.Convert]::ToString($OutputObjectProperties.ExitCode, 16).PadLeft(8, '0').ToUpper()} Catch {$Null}
                        $OutputObjectProperties.ExitCodeAsInteger = Try {$OutputObjectProperties.ExitCodeAsHex -As [Int]} Catch {$Null}
                        $OutputObjectProperties.ExitCodeAsDecimal = Try {[System.Convert]::ToString($OutputObjectProperties.ExitCodeAsHex, 10)} Catch {$Null}

                        $ExitCodeMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'
            
                        $Null = $OutputObjectProperties.GetEnumerator() | Where-Object {($_.Key -imatch '(^ExitCode.*$)')} | Sort-Object -Property @('Key') | ForEach-Object {$ExitCodeMessageList.Add("[$($_.Key): $($_.Value)]")}
            
                        $ProcessExecutionTimespan = New-TimeSpan -Start ($Process.StartTime) -End ($Process.ExitTime)

                        $OutputObjectProperties.ProcessObject = $Process | Select-Object -Property @('*') -ExcludeProperty @('ExitCode', 'StandardInput', 'StandardOutput', 'StandardError', 'SafeHandle', 'Threads', 'StartInfo')

                        $WriteLogMessage.Invoke(0, @("Process Exit Time: $($Process.ExitTime.ToString($DateTimeLogFormat))"))

                        #Dispose of the process object
                          Try {$Null = $Process.Dispose()} Catch {}
                                                                        
                        $WriteLogMessage.Invoke(0, @("The command execution took $($GetTimeSpanMessage.InvokeReturnAsIs($ProcessExecutionTimespan))."))

                        Switch (($AcceptableExitCodeList -icontains '*') -or ($OutputObjectProperties.ExitCode.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsHex.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsInteger.ToString() -iin $AcceptableExitCodeList) -or ($OutputObjectProperties.ExitCodeAsDecimal.ToString() -iin $AcceptableExitCodeList))
                          {
                              {($_ -eq $True)}
                                {
                                    $WriteLogMessage.Invoke(0, @("The command execution was successful. $($ExitCodeMessageList -Join ' ')"))
                                    
                                    [Boolean]$CommandExecutionErrorOccured = $False
                                }

                              {($_ -eq $False)}
                                {
                                    $WriteLogMessage.Invoke(2, @("The command execution was unsuccessful. $($ExitCodeMessageList -Join ' ')"))

                                    $ErrorMessage = "The command execution was unsuccessful. $($ExitCodeMessageList -Join ' ')"
                                    $Exception = [System.Exception]::New($ErrorMessage)        
                                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::New($Exception, [System.Management.Automation.ErrorCategory]::InvalidResult.ToString(), [System.Management.Automation.ErrorCategory]::InvalidResult, $Process)
                                    
                                    [Boolean]$CommandExecutionErrorOccured = $True
                                }
                          }
     
                        Switch (([String]::IsNullOrEmpty($ParsingExpression) -eq $False) -and ([String]::IsNullOrWhiteSpace($ParsingExpression) -eq $False))
                          {
                              {($_ -eq $True)}
                                {
                                    $RegexOptions = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions]'
                                      $RegexOptions.Add('IgnoreCase')
                                      $RegexOptions.Add('Multiline')

                                    $Regex = New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList @($ParsingExpression, $RegexOptions.ToArray())
                                                
                                    $OutputStreamDictionary = New-Object -TypeName 'System.Collections.Generic.Dictionary[[String], [String]]'
                                      $OutputStreamDictionary.Add('StandardOutput', $OutputObjectProperties.StandardOutput)
                                      $OutputStreamDictionary.Add('StandardError', $OutputObjectProperties.StandardError)

                                    ForEach ($OutputStream In $OutputStreamDictionary.GetEnumerator())
                                      {   
                                          Switch (([String]::IsNullOrEmpty($OutputStream.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($OutputStream.Value) -eq $False))
                                            {
                                                {($_ -eq $True)}
                                                  {                                                      
                                                      $WriteLogMessage.Invoke(0, @("Attempting to parse the `"$($OutputStream.Key)`" property value. Please Wait..."))

                                                      $WriteLogMessage.Invoke(0, @("Regular Expression: $($ParsingExpression)"))

                                                      $WriteLogMessage.Invoke(0, @("Regular Expression Options: $($RegexOptions -Join ', ')"))

                                                      $OutputStreamRegexResult = $Regex.IsMatch($OutputStream.Value)

                                                      Switch ($OutputStreamRegexResult)
                                                        {
                                                            {($_ -eq $True)}
                                                              {
                                                                  $RegexMatchList = $Regex.Matches($OutputStream.Value)

                                                                  $WriteLogMessage.Invoke(0, @("The `"$($OutputStream.Key)`" property value matches the regular expression. $($RegexMatchList.Count) matches were found."))

                                                                  $OutputObjectProperties."$($OutputStream.Key)Object" = $RegexMatchList
                                                              }

                                                            Default
                                                              {
                                                                  $WriteLogMessage.Invoke(0, @("The `"$($OutputStream.Key)`" property value does not match the regular expression."))

                                                                  $OutputObjectProperties."$($OutputStream.Key)Object" = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.Match]'     
                                                              }
                                                        }            
                                                  }

                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("Skipping the parsing of the `"$($OutputStream.Key)`" property value because it is blank."))
                                                  }
                                            }
                                      }
                                }
                          }
                          
                        $Null = $ProcessTimeoutStopWatch.Stop()
            
                        $Null = $ProcessTimeoutStopWatch.Reset()  
                    }
              }                               
        }
      Catch
        {
            $ExceptionPropertyDictionary = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $ExceptionPropertyDictionary.Add('Message', $_.Exception.Message)
              $ExceptionPropertyDictionary.Add('Category', $_.Exception.ErrorRecord.FullyQualifiedErrorID)
              $ExceptionPropertyDictionary.Add('LineNumber', $_.InvocationInfo.ScriptLineNumber)
              $ExceptionPropertyDictionary.Add('LinePosition', $_.InvocationInfo.OffsetInLine)
              $ExceptionPropertyDictionary.Add('Code', $_.InvocationInfo.Line.Trim())

            $ExceptionMessageList = New-Object -TypeName 'System.Collections.Generic.List[String]'

            ForEach ($ExceptionProperty In $ExceptionPropertyDictionary.GetEnumerator())
              {
                  $ExceptionMessageList.Add("[$($ExceptionProperty.Key): $($ExceptionProperty.Value)]")
              }

            $WriteLogMessage.Invoke(2, @("$($ExceptionMessageList -Join ' ')"))
        }
      Finally
        {                           
            $OutputObjectProperties.StandardOutput = Try {$OutputObjectProperties.StandardOutput.Result} Catch {$Null}
            $OutputObjectProperties.StandardError = Try {$OutputObjectProperties.StandardError.Result} Catch {$Null}
            
            $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)
            
            Switch (($LogOutput.IsPresent -eq $True) -or ($LogOutput -eq $True) -or ($CommandExecutionErrorOccured -eq $True))
              {
                  {($_ -eq $True)}
                    {
                        ForEach ($Property In $OutputObject.PSObject.Properties)
                          {
                              Switch ($Property.Name)
                                {
                                    {($_ -iin @('StandardOutput', 'StandardError'))}
                                      {
                                          Switch (([String]::IsNullOrEmpty($Property.Value) -eq $False) -and ([String]::IsNullOrWhiteSpace($Property.Value) -eq $False))
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("$($Property.Name): $($Property.Value)"))
                                                  }
                                                  
                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("$($Property.Name): N/A"))
                                                  }
                                            }
                                      }
                                }
                          }
                    }
              }
    
            Try
              {
                  Switch ($NoWait.IsPresent)
                    {
                        {($_ -eq $False)}
                          {
                              Switch ($Process.HasExited)
                                {
                                    {($_ -eq $False)}
                                      {
                                          $WriteLogMessage.Invoke(0, @("Attempting to forcibly terminate the process ID $($Process.ID). Please Wait..."))
            
                                          $Null = Try {$Process.CancelErrorRead()} Catch {}
                                          $Null = Try {$Process.CancelOutputRead()} Catch {}
                                          $Null = Try {$Process.Kill()} Catch {}
                                          $Null = Try {$Process.Dispose()} Catch {}
                                      }
                                }
                          }
                    }
              }
            Catch
              {
                  
              }

            #Determine the date and time the function completed execution
              $FunctionEndTime = (Get-Date)

              $WriteLogMessage.Invoke(0, @("Execution of $($CmdletName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"))

            #Log the total script execution time  
              $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

              $WriteLogMessage.Invoke(0, @("Function execution took $($GetTimeSpanMessage.InvokeReturnAsIs($FunctionExecutionTimespan))."))
            
            $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is completed."))
            
            Switch ($CommandExecutionErrorOccured)
              {
                  {($_ -eq $True)}
                    {
                        Write-Output -InputObject ($OutputObject)
                                    
                        If ($ContinueOnError.IsPresent -eq $False) {$PSCmdlet.ThrowTerminatingError($ErrorRecord)}
                    }
                                
                  Default
                    {
                        Write-Output -InputObject ($OutputObject)
                    }                                
              }
        }
  }
#endregion