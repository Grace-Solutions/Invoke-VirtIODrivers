## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Invoke-CommandLineParser
Function Invoke-CommandLineParser
    {
        <#
          .SYNOPSIS
          Parses one or more command line strings
          
          .DESCRIPTION
          This makes dynamic software removal dramatically easier because once you have separated the command from the argument list, your can add/remove additional arguments and then perform execution.
          
          .PARAMETER CommandLine
          One or more command line string(s) that will be run through the parser
          
          .EXAMPLE
          Invoke-CommandLineParser -CommandLine 'MsiExec.exe /X{32DC821E-4A7D-4878-BEE8-337FA153D7F2}'

          .EXAMPLE
          $InvokeCommandLineParserParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $InvokeCommandLineParserParameters.CommandLine = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $InvokeCommandLineParserParameters.CommandLine.Add('MsiExec.exe /I{0AFA46DB-6E86-479E-BF66-B25C29324A5F}')
              $InvokeCommandLineParserParameters.CommandLine.Add('MsiExec.exe /X{1309CCD0-A923-4203-8A92-377F37EE2C29}')
              $InvokeCommandLineParserParameters.CommandLine.Add('"C:\ProgramData\Intel Package Cache {1CEAC85D-2590-4760-800F-8DE5E91F3700}\Setup.exe" -uninstall')
              $InvokeCommandLineParserParameters.CommandLine.Add('C:\WINDOWS\system32\sdbinst.exe -u "C:\WINDOWS\AppPatch\CustomSDB\{9f4f4a9b-eec5-4906-92fe-d1f43ccf5c8d}.sdb"')
              $InvokeCommandLineParserParameters.CommandLine.Add('"C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" scenario=install scenariosubtype=ARP sourcetype=None productstoremove=VisioProRetail.16_en-us_x-none culture=en-us version.16=16.0')
              $InvokeCommandLineParserParameters.CommandLine.Add('C:\WINDOWS\system32\rundll32.exe RtSetupAPI64.dll RealtekUSBAudioInstaller -r -m')
              $InvokeCommandLineParserParameters.CommandLine.Add('C:\Program Files (x86)\VideoLAN\VLC\uninstall.exe')
            $InvokeCommandLineParserParameters.ContinueOnError = $False
            $InvokeCommandLineParserParameters.Verbose = $True
            $InvokeCommandLineParserParameters.ErrorAction = [System.Management.Automation.Actionpreference]::Stop

          $InvokeCommandLineParserResult = Invoke-CommandLineParser @InvokeCommandLineParserParameters

          Write-Output -InputObject ($InvokeCommandLineParserResult)
  
          .NOTES
          Use the uninstall strings from the registry to dynamically remove software.
          
          .LINK
          https://github.com/beatcracker/Powershell-Misc/blob/master/Split-CommandLine.ps1
        #>
        
        [CmdletBinding(ConfirmImpact = 'Low', DefaultParameterSetName = '__AllParameterSets', HelpURI = '', SupportsShouldProcess = $True, PositionalBinding = $True)]
       
        Param
          (        
              [Parameter(Mandatory=$False, Position = 0)]
              [AllowEmptyCollection()]
              [AllowNull()]
              [AllowEmptyString()]
              [String[]]$CommandLine,
                                                            
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
                    $RegexOptionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions[]]'
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::Multiline)
                    $RegularExpressionTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                      $RegularExpressionTable.GUID = New-Object -TypeName 'Regex' -ArgumentList @('((?:\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(?:\}){0,1})', $RegexOptionList.ToArray())
                      $RegularExpressionTable.PathHasSpacesWithoutQuotes = New-Object -TypeName 'Regex' -ArgumentList @('^[^\"].+[ ].+[^\"]', $RegexOptionList.ToArray())
                      $RegularExpressionTable.AllTextBeforeFileExtension = New-Object -TypeName 'Regex' -ArgumentList @('^.+(?<=\.exe)', $RegexOptionList.ToArray())
                      $RegularExpressionTable.WindowsFilePath = New-Object -TypeName 'Regex' -ArgumentList @('(([a-z]|[A-Z]):(?=\\(?![\0-\37<>:\\\|?*])|\\(?![\0-\37<>:"\\\|?*])|$)|^\\(?=[\\\\][^\0-\37<>:"\\\|?*]+)|^(?=(\\|\\)$)|^\.(?=(\\|\\)$)|^\.\.(?=(\\|\\)$)|^(?=(\\|\\)[^\0-\37<>:"\\\|?*]+)|^\.(?=(\\|\\)[^\0-\37<>:"\\\|?*]+)|^\.\.(?=(\\|\\)[^\0-\37<>:"\\\|?*]+))((\\|\\)[^\0-\37<>:"\\\|?*]+|(\\|\\)$)*()', $RegexOptionList.ToArray())

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
                                                                      $LoggingDetails.ErrorMessage = " ERROR: $($ErrorMessage.Key): $($ErrorMessage.Value)"
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
                    
                    $LoggingDetails.LogMessage = "Function `'$($FunctionName)`' is beginning. Please Wait..."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      
                    [String[]]$AvailableScriptParameters = (Get-Command -Name ($FunctionName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                    $LoggingDetails.LogMessage = "Available Function Parameter(s) = $($AvailableScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
                    $LoggingDetails.LogMessage = "Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    $LoggingDetails.LogMessage = "Execution of $($FunctionName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                        
                    #Create an object that will contain the functions output.
                      $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                      
                    #Define additional variable(s)
                      $CommandLineList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                      
                    #Load the required types  
                      $Kernel32Definition = @'
[DllImport("kernel32")]
public static extern IntPtr GetCommandLineW();
[DllImport("kernel32")]
public static extern IntPtr LocalFree(IntPtr hMem);
'@
 
                      $Kernel32 = Add-Type -MemberDefinition $Kernel32Definition -Namespace 'Win32' -Name 'Kernel32' -PassThru

                      $Shell32Definition = @'
[DllImport("shell32.dll", SetLastError = true)]
public static extern IntPtr CommandLineToArgvW(
[MarshalAs(UnmanagedType.LPWStr)] string lpCmdLine,
out int pNumArgs);
'@

                    $Shell32 = Add-Type -MemberDefinition $Shell32Definition -Namespace 'Win32' -Name 'Shell32' -PassThru
                    
                    Switch (($CommandLine | Measure-Object).Count -eq 0)
                      {
                          {($_ -eq $True)}
                            {
                                $CommandLineList.Add([System.Environment]::CommandLine)
                            }        
                      }
                    
                    ForEach ($Item In $CommandLine)
                      {
                          Switch (([String]::IsNullOrEmpty($Item) -eq $True) -or ([String]::IsNullOrWhiteSpace($Item) -eq $True))
                            {
                                {($_ -eq $True)}
                                  {
                                      $LoggingDetails.LogMessage = "A blank command line list entry was detected. Skipping..." 
                                      Write-Verbose -Message ($LoggingDetails.LogMessage)
                          
                                      Continue
                                  }
                                  
                                Default
                                  {
                                      $CommandLineList.Add($Item)
                                  }
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
                    $LoggingDetails.LogMessage = "Command Line List Count: $($CommandLineList.Count)" 
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                    
                    For ($CommandLineListIndex = 0; $CommandLineListIndex -lt $CommandLineList.Count; $CommandLineListIndex++)
                      {                      
                          Try
                            {                                              
                                $CommandLineListItem = $CommandLineList[$CommandLineListIndex]
                                
                                $CommandLineObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                  $CommandLineObjectProperties.OriginalString = $CommandLineListItem
                                  $CommandLineObjectProperties.SanitizedString = $Null
                                  $CommandLineObjectProperties.ParsedArguments = $Null

                                $LoggingDetails.LogMessage = "Attempting to parse command line list entry at index $($CommandLineListIndex). Please Wait..." 
                                Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                                
                                $LoggingDetails.LogMessage = "Original String: $($CommandLineObjectProperties.OriginalString)" 
                                Write-Verbose -Message ($LoggingDetails.LogMessage)
                                   
                                Switch (([String]::IsNullOrEmpty($CommandLineObjectProperties.OriginalString) -eq $True) -or ([String]::IsNullOrWhiteSpace($CommandLineObjectProperties.OriginalString) -eq $True))
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $LoggingDetails.LogMessage = "The original string provided was blank. Skipping command line list entry..." 
                                            Write-Verbose -Message ($LoggingDetails.LogMessage)
                                    
                                            Continue
                                        }
                                  }

                                Switch ($RegularExpressionTable.PathHasSpacesWithoutQuotes.IsMatch($CommandLineObjectProperties.OriginalString))
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $CommandPath = $RegularExpressionTable.AllTextBeforeFileExtension.Match($CommandLineObjectProperties.OriginalString).Value
                  
                                            Switch ($CommandPath -imatch '.*\\.*')
                                              {
                                                  {($_ -eq $True)}
                                                    {
                                                        $NewCommandPath = '"' + $CommandPath + '"'
                                                    }

                                                  Default
                                                    {
                                                        $NewCommandPath = $CommandPath
                                                    }
                                              }

                                            $CommandLineObjectProperties.SanitizedString = $CommandLineObjectProperties.OriginalString.Replace($CommandPath, $NewCommandPath)

                                            $CommandLineObjectProperties.OriginalString = $CommandLineObjectProperties.SanitizedString
                                        }
                                  }
                                                                                                                            
                                $ParsedArgumentsObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                  $ParsedArgumentsObjectProperties.Command = $Null
                                  $ParsedArgumentsObjectProperties.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                            
                                $ParsedArgumentCount = 0
                    
                                $ParsedArgumentsPointer = $Shell32::CommandLineToArgvW($CommandLineObjectProperties.OriginalString, [Ref]$ParsedArgumentCount)
                            
                                For ($ParsedArgumentCounter = 0; $ParsedArgumentCounter -lt $ParsedArgumentCount; $ParsedArgumentCounter++)
                                  {
                                      $ParserArgumentPointer = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($ParsedArgumentsPointer, ($ParsedArgumentCounter * [IntPtr]::Size))
                                      
                                      $ParsedArgumentValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ParserArgumentPointer)
                                                                  
                                      Switch ($ParsedArgumentCounter)
                                        {
                                            {($_ -eq 0)}
                                              {
                                                  $ParsedArgumentsObjectProperties.Command = $ParsedArgumentValue       
                                              }
                                              
                                            Default
                                              {
                                                  Switch ($ParsedArgumentsObjectProperties.Command -imatch '.*msiexec.*')
                                                    {
                                                        {($_ -eq $True)}
                                                          {
                                                              $ParsedArgumentsObjectProperties.Command = $ParsedArgumentsObjectProperties.Command.ToLower()
                                                      
                                                              Switch ($ParsedArgumentValue -imatch $RegularExpressionTable.GUID.ToString())
                                                                {
                                                                    {($_ -eq $True)}
                                                                      {
                                                                          $ParsedArgumentValueSegments = $ParsedArgumentValue -isplit $RegularExpressionTable.GUID.ToString() | Where-Object {([String]::IsNullOrEmpty($_) -eq $False) -and ([String]::IsNullOrWhiteSpace($_) -eq $False)}
                                                                          
                                                                          ForEach ($ParsedArgumentValueSegment In $ParsedArgumentValueSegments)
                                                                            {
                                                                                Switch ($ParsedArgumentValueSegment)
                                                                                  {
                                                                                      {($_ -imatch $RegularExpressionTable.GUID.ToString())}
                                                                                        {
                                                                                            $ParsedArgumentValueSegment = '"{' + ($ParsedArgumentValue -ireplace '(\{)|(\})', '' -ireplace "(\`")|(\')", '') + '}"'
                                                                                        }
                                                                                      
                                                                                      {($_ -iin @('/I'))}
                                                                                        {
                                                                                            $ParsedArgumentValueSegment = '/x'
                                                                                        }
                                                                                        
                                                                                      {($_ -iin @('/X'))}
                                                                                        {
                                                                                            $ParsedArgumentValueSegment = $ParsedArgumentValueSegment.ToLower()
                                                                                        }
                                                                                  }
                                                                            
                                                                                $ParsedArgumentsObjectProperties.ArgumentList.Add($ParsedArgumentValueSegment)
                                                                            }
                                                                      }
                                                                      
                                                                    Default
                                                                      {
                                                                          $ParsedArgumentsObjectProperties.ArgumentList.Add($ParsedArgumentValue)
                                                                      }
                                                                }
                                                                
                                                              Switch ($True)
                                                                {
                                                                    {($ParsedArgumentsObjectProperties.ArgumentList | Where-Object {($_ -inotmatch '(^REBOOT\=.*$)')})}
                                                                      {
                                                                          $ParsedArgumentsObjectProperties.ArgumentList.Add('REBOOT=ReallySuppress')
                                                                      }

                                                                    {($ParsedArgumentsObjectProperties.ArgumentList | Where-Object {($_ -inotmatch '(^\/q.*$)')})}
                                                                      {
                                                                          $ParsedArgumentsObjectProperties.ArgumentList.Add('/qn')
                                                                      }

                                                                    {($ParsedArgumentsObjectProperties.ArgumentList | Where-Object {($_ -inotmatch '(^\/.*restart$)')})}
                                                                      {
                                                                          $ParsedArgumentsObjectProperties.ArgumentList.Add('/norestart')
                                                                      }
                                                                }          
                                                          }
                                                          
                                                        Default
                                                          {
                                                              $ParsedArgumentsObjectProperties.ArgumentList.Add($ParsedArgumentValue)
                                                          }
                                                    }
                                              }
                                        }
                                  }

                                Switch ($ParsedArgumentsObjectProperties.ArgumentList.Count -eq 0)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $ParsedArgumentsObjectProperties.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                        }

                                      Default
                                        {                                            
                                            For ($ArgumentIndex = 0; $ArgumentIndex -lt $ParsedArgumentsObjectProperties.ArgumentList.Count; $ArgumentIndex++)
                                              {
                                                  $Argument = $ParsedArgumentsObjectProperties.ArgumentList[$ArgumentIndex]
                                                  
                                                  Switch (([String]::IsNullOrEmpty($Argument) -eq $False) -and ([String]::IsNullOrWhiteSpace($Argument) -eq $False))
                                                    {
                                                        {($_ -eq $True)}
                                                          {
                                                              $ParsedArgumentsObjectProperties.ArgumentList.RemoveAt($ArgumentIndex)

                                                              $Argument = $Argument.Trim()
    
                                                              Switch ($True)
                                                                {
                                                                    {($RegularExpressionTable.GUID.IsMatch($Argument) -eq $True)}
                                                                      {
                                                                          $MatchList = $RegularExpressionTable.GUID.Matches($Argument)

                                                                          ForEach ($Match In $MatchList)
                                                                            {
                                                                                $ArgumentIndex = 1

                                                                                $OriginalMatch = $Match.Value

                                                                                $SanitizedMatch = $OriginalMatch

                                                                                $Argument = '"{' + "$($SanitizedMatch -ireplace '\{+|\}+', '')" + '}"'

                                                                                Break
                                                                            }
                                                                          
                                                                          Break
                                                                      }
                                                                    
                                                                    {($RegularExpressionTable.WindowsFilePath.IsMatch($Argument) -eq $True)}
                                                                      {
                                                                          $MatchList = $RegularExpressionTable.WindowsFilePath.Matches($Argument)

                                                                          ForEach ($Match In $MatchList)
                                                                            {
                                                                                $OriginalMatch = $Match.Value

                                                                                $SanitizedMatch = '"' + ($OriginalMatch -ireplace "(\`")|(\')", '') + '"'

                                                                                $Argument = $Argument.Replace($OriginalMatch, $SanitizedMatch)
                                                                            }
                                                                          
                                                                          Break
                                                                      }
                                                                }
                                                              
                                                              $ParsedArgumentsObjectProperties.ArgumentList.Insert($ArgumentIndex, $Argument)
                                                          }

                                                        Default
                                                          {
                                                              $ParsedArgumentsObjectProperties.ArgumentList.RemoveAt($ArgumentIndex)
                                                          }
                                                    }
                                              }
                                            
                                            $ParsedArgumentsObjectProperties.ArgumentList = ($ParsedArgumentsObjectProperties.ArgumentList | Select-Object -Unique) -As [System.Collections.Generic.List[String]]

                                            Switch ([System.Environment]::CommandLine)
                                              {
                                                  {($_ -imatch '.*Adaptiva.*')}
                                                    {
                                                        $ParsedArgumentsObjectProperties.ArgumentList = $ParsedArgumentsObjectProperties.ArgumentList.ToArray()
                                                    }
                                              } 
                                        }
                                  }   
                                                              
                                $ParsedArgumentsObject = New-Object -TypeName 'PSObject' -Property ($ParsedArgumentsObjectProperties)       
                                  
                                $CommandLineObjectProperties.ParsedArguments = $ParsedArgumentsObject      
                            }
                          Catch
                            {
                                $LoggingDetails.WarningMessage = "$($_.Exception.Message)"
                                Write-Warning -Message ($LoggingDetails.WarningMessage)
                            }
                          Finally
                            {                                                            
                                $CommandLineObjectProperties.OriginalString = $CommandLineListItem

                                Switch ($CommandLineObjectProperties.ParsedArguments.Command -imatch '.*\\.*')
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $CommandLineObjectProperties.SanitizedString = "`"$($CommandLineObjectProperties.ParsedArguments.Command)`" $($CommandLineObjectProperties.ParsedArguments.ArgumentList -Join ' ')".Trim()
                                        }

                                      Default
                                        {
                                            $CommandLineObjectProperties.SanitizedString = "$($CommandLineObjectProperties.ParsedArguments.Command) $($CommandLineObjectProperties.ParsedArguments.ArgumentList -Join ' ')".Trim()
                                        }
                                  }

                                $LoggingDetails.LogMessage = "Sanitized String: $($CommandLineObjectProperties.SanitizedString)" 
                                Write-Verbose -Message ($LoggingDetails.LogMessage)
                                
                                $CommandLineObject = New-Object -TypeName 'PSObject' -Property ($CommandLineObjectProperties)
                                                                
                                $OutputObjectList.Add($CommandLineObject)
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
              Try {$Null = $Kernel32::LocalFree($ParsedArgumentsPointer)} Catch {}
                                              
              Try
                {
                    #Determine the date and time the function completed execution
                      $FunctionEndTime = (Get-Date)

                      $LoggingDetails.LogMessage = "Execution of $($FunctionName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    #Log the total script execution time  
                      $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                      $LoggingDetails.LogMessage = "Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                      Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                    
                    $LoggingDetails.LogMessage = "Function `'$($FunctionName)`' is completed."
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

                      Write-Output -InputObject ($OutputObjectList)
                }
          }
    }
#endregion