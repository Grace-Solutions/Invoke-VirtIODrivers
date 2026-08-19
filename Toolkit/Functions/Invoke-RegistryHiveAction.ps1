#region Invoke-RegistryHiveAction
Function Invoke-RegistryHiveAction
  {
      <#
          .SYNOPSIS
          Reads registry key(s) and value(s) directly from a registry hive file without loading or mounting the hive into the live registry.

          .DESCRIPTION
          This function parses the raw registry hive file format (REGF) using the Eric Zimmerman "Registry" library, which allows registry hive data to be read from offline operating system volumes (such as within Windows PE) without mounting the hive, locking the file, or requiring backup/restore privileges.

          The required libraries are loaded into memory (In dependency order) from the "Libraries\Registry" directory located within the Toolkit directory, which avoids file locks on the library files themselves.

          Within Windows PowerShell (Desktop edition), the libraries are byte loaded directly into the application domain. Within PowerShell (Core edition), the libraries are stream loaded into a single dedicated assembly load context so that their dependencies resolve against each other.

          .PARAMETER HivePath
          A valid file path to a valid registry hive.

          .PARAMETER KeyPath
          One or more registry key paths that are relative to the specified registry hive. A leading "Root\" segment is accepted for backwards compatibility and both forms resolve identically.

          .PARAMETER ValueNameExpression
          One or more regular expressions that will determine which registry value names will be extracted from the specified registry hive.

          .PARAMETER ContinueOnError
          Ignore failures.

          .EXAMPLE
          Invoke-RegistryHiveAction -HivePath "D:\Windows\System32\Config\SOFTWARE" -KeyPath @('Root\Microsoft\Windows NT\CurrentVersion') -ValueNameExpression @('.*') -Verbose

          .EXAMPLE
          $InvokeRegistryHiveActionParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $InvokeRegistryHiveActionParameters.HivePath = "D:\Windows\System32\Config\SOFTWARE"
            $InvokeRegistryHiveActionParameters.KeyPath = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $InvokeRegistryHiveActionParameters.KeyPath.Add('Root\Microsoft\Windows NT\CurrentVersion')
            $InvokeRegistryHiveActionParameters.ValueNameExpression = New-Object -TypeName 'System.Collections.Generic.List[Regex]'
              $InvokeRegistryHiveActionParameters.ValueNameExpression.Add('.*')
            $InvokeRegistryHiveActionParameters.ContinueOnError = $False
            $InvokeRegistryHiveActionParameters.Verbose = $True

          $InvokeRegistryHiveActionResult = Invoke-RegistryHiveAction @InvokeRegistryHiveActionParameters

          $ProductName = $InvokeRegistryHiveActionResult[0].ValueTable['ProductName'].Value

          Write-Output -InputObject ($InvokeRegistryHiveActionResult)

          .NOTES
          Please ensure that the specified registry hive is not in use!

          The returned object list contains one object per requested key path, each exposing the following properties: Path, and ValueTable.

          ValueTable is a case insensitive dictionary keyed by registry value name, so individual values can be accessed directly without filtering, such as $Result[0].ValueTable['UBR'].Value. Each entry exposes the following properties: Name, Alias, Type, Value, ValueAsDecimal, and ValueAsHex.

          .LINK
          https://github.com/EricZimmerman/Registry

          .LINK
          https://www.nuget.org/packages/Registry
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
                  #Determine the date and time we executed the function
                    $FunctionStartTime = (Get-Date)

                  [String]$CmdletName = $MyInvocation.MyCommand.Name

                  $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is beginning. Please Wait..."))

                  #Define Default Action Preferences
                    $ErrorActionPreference = 'Stop'

                  [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
                  $WriteLogMessage.Invoke(0, @("Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"))

                  #region Load the required registry parsing libraries into memory (In dependency order)
                    $RegistryAssembly = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {($_.GetName().Name -ieq 'Registry')} | Select-Object -First 1

                    Switch ($Null -ine $RegistryAssembly)
                      {
                          {($_ -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("The registry parsing library has already been loaded. [Assembly: $($RegistryAssembly.FullName)]"))
                            }

                          Default
                            {
                                $RegistryLibraryDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ToolkitScriptDirectory.FullName, 'Libraries', 'Registry')

                                Switch ([System.IO.Directory]::Exists($RegistryLibraryDirectory.FullName))
                                  {
                                      {($_ -eq $False)}
                                        {
                                            $WriteLogMessage.Invoke(2, @("The registry parsing library directory could not be found.", "Expected Path: $($RegistryLibraryDirectory.FullName)"))

                                            Throw "The registry parsing library directory `"$($RegistryLibraryDirectory.FullName)`" could not be found."
                                        }
                                  }

                                #The libraries must be loaded in dependency order so that each assembly can resolve the assemblies it references
                                  $LibraryLoadOrderList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                    $LibraryLoadOrderList.Add('System.Runtime.CompilerServices.Unsafe.dll')
                                    $LibraryLoadOrderList.Add('System.Buffers.dll')
                                    $LibraryLoadOrderList.Add('System.Numerics.Vectors.dll')
                                    $LibraryLoadOrderList.Add('System.Memory.dll')
                                    $LibraryLoadOrderList.Add('System.ValueTuple.dll')
                                    $LibraryLoadOrderList.Add('System.Threading.Channels.dll')
                                    $LibraryLoadOrderList.Add('System.Diagnostics.DiagnosticSource.dll')
                                    $LibraryLoadOrderList.Add('System.Text.Encoding.CodePages.dll')
                                    $LibraryLoadOrderList.Add('Serilog.dll')
                                    $LibraryLoadOrderList.Add('Registry.dll')

                                Switch ($PSVersionTable.PSEdition)
                                  {
                                      {($_ -ieq 'Desktop')}
                                        {
                                            #Windows PowerShell resolves byte loaded assemblies against each other within the application domain
                                              For ($LibraryLoadOrderListIndex = 0; $LibraryLoadOrderListIndex -lt $LibraryLoadOrderList.Count; $LibraryLoadOrderListIndex++)
                                                {
                                                    $LibraryPath = [System.IO.FileInfo][System.IO.Path]::Combine($RegistryLibraryDirectory.FullName, $LibraryLoadOrderList[$LibraryLoadOrderListIndex])

                                                    $WriteLogMessage.Invoke(1, @("Attempting to byte load assembly `"$($LibraryPath.FullName)`". Please Wait..."))

                                                    [Byte[]]$LibraryBytes = [System.IO.File]::ReadAllBytes($LibraryPath.FullName)

                                                    $LoadedAssembly = [System.Reflection.Assembly]::Load($LibraryBytes)

                                                    Switch ($LoadedAssembly.GetName().Name -ieq 'Registry')
                                                      {
                                                          {($_ -eq $True)}
                                                            {
                                                                $RegistryAssembly = $LoadedAssembly
                                                            }
                                                      }
                                                }
                                        }

                                      Default
                                        {
                                            #PowerShell (Core) isolates byte loaded assemblies from each other, so a single dedicated assembly load context is required for their dependencies to resolve against each other
                                              $RegistryAssemblyLoadContext = New-Object -TypeName 'System.Runtime.Loader.AssemblyLoadContext' -ArgumentList @('RegistryHiveLibraries')

                                              For ($LibraryLoadOrderListIndex = 0; $LibraryLoadOrderListIndex -lt $LibraryLoadOrderList.Count; $LibraryLoadOrderListIndex++)
                                                {
                                                    $LibraryPath = [System.IO.FileInfo][System.IO.Path]::Combine($RegistryLibraryDirectory.FullName, $LibraryLoadOrderList[$LibraryLoadOrderListIndex])

                                                    $WriteLogMessage.Invoke(1, @("Attempting to stream load assembly `"$($LibraryPath.FullName)`". Please Wait..."))

                                                    [Byte[]]$LibraryBytes = [System.IO.File]::ReadAllBytes($LibraryPath.FullName)

                                                    $LibraryStream = New-Object -TypeName 'System.IO.MemoryStream' -ArgumentList @(,$LibraryBytes)

                                                    $LoadedAssembly = $RegistryAssemblyLoadContext.LoadFromStream($LibraryStream)

                                                    $Null = $LibraryStream.Dispose()

                                                    Switch ($LoadedAssembly.GetName().Name -ieq 'Registry')
                                                      {
                                                          {($_ -eq $True)}
                                                            {
                                                                $RegistryAssembly = $LoadedAssembly
                                                            }
                                                      }
                                                }
                                        }
                                  }

                                $WriteLogMessage.Invoke(0, @("The registry parsing library was loaded successfully. [Assembly: $($RegistryAssembly.FullName)]"))
                            }
                      }

                    #The registry parsing library types are instantiated through the loaded assembly reference because types within a dedicated assembly load context are not visible to the PowerShell type resolver
                      $RegistryHiveOnDemandType = $RegistryAssembly.GetType('Registry.RegistryHiveOnDemand')
                  #endregion

                  #Create an object that will contain the functions output
                    $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

                  #Set default parameter values (If necessary)
                    $ValueNameExpressionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.Regex]'

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
                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
              }
        }

      Process
        {
            Try
              {
                  $WriteLogMessage.Invoke(0, @("Attempting to load registry hive `"$($HivePath.FullName)`" on demand. Please Wait..."))

                  $RegistryHive = [System.Activator]::CreateInstance($RegistryHiveOnDemandType, @($HivePath.FullName))

                  ForEach ($Key In $KeyPath)
                    {
                        Try
                          {
                              $WriteLogMessage.Invoke(0, @("Attempting to retrieve the details of registry key path `"$($Key)`". Please Wait..."))

                              $RegistryKeyProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                $RegistryKeyProperties.Path = $Key
                                $RegistryKeyProperties.ValueTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)

                              $RegistryKey = $RegistryHive.GetKey($Key)

                              Switch ($Null -ine $RegistryKey)
                                {
                                    {($_ -eq $True)}
                                      {
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
                                                                                }
                                                                          }
                                                                    }

                                                                  $ValueObject = New-Object -TypeName 'PSObject' -Property ($ValueProperties)

                                                                  $RegistryKeyProperties.ValueTable[$ValueProperties.Name] = $ValueObject
                                                              }
                                                        }
                                                  }
                                            }
                                      }

                                    Default
                                      {
                                          $WriteLogMessage.Invoke(2, @("The registry key path `"$($Key)`" could not be found within registry hive `"$($HivePath.FullName)`"."))
                                      }
                                }

                              $RegistryKeyObject = New-Object -TypeName 'PSObject' -Property ($RegistryKeyProperties)

                              $OutputObjectList.Add($RegistryKeyObject)
                          }
                        Catch
                          {
                              $ErrorHandlingDefinition.Invoke($Error[0], 2, $True)
                          }
                    }
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
              }
        }

      End
        {
            Try
              {
                  #Determine the date and time the function completed execution
                    $FunctionEndTime = (Get-Date)

                  #Log the total function execution time
                    $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                    $WriteLogMessage.Invoke(0, @("Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)."))

                    $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is completed."))
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
              }
            Finally
              {
                  Write-Output -InputObject ($OutputObjectList.ToArray())
              }
        }
  }
#endregion
