## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Copy-ItemWithProgress
Function Copy-ItemWithProgress
    {
        <#
          .SYNOPSIS
          Copies file(s) from a valid path in segments.

          .DESCRIPTION
          Supports the copying of files from a valid location in segments either directly or recursively.
          Supports the usage of filters and exclusions exactly the way that the Get-ChildItem or Copy-Item cmdlets work.

          .PARAMETER Path
          A valid file or folder location.

          .PARAMETER Destination
          The destination directory where the content will be copied.

          .PARAMETER Include
          One or more filter(s) to implicitly copy what is specified.

          .PARAMETER Exclude
          One or more filter(s) to implicitly skip the copying of what is specified.

          .PARAMETER Recurse
          Recurse through the specified directories.

          .PARAMETER Force
          Overwrite file(s) that have already been copied. The default behavior is to skip the copying of the file.

          .PARAMETER SegmentSize
          The segment size in megabytes that each file will be transferred with.

          .PARAMETER RandomDelay
          Adds a pulse in between the transfer of each segment.

          .PARAMETER ContinueOnError
          Continues processing even if an error has occured.

          .EXAMPLE
          Copy-ItemWithProgress -Path 'FileOrDirectoryPath' -Destination 'YourDestinationDirectory' -Verbose

          .EXAMPLE
          $CopyItemWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $CopyItemWithProgressParameters.Path = "FileOrDirectoryPath"
            $CopyItemWithProgressParameters.Destination = "YourDestinationDirectory"
            $CopyItemWithProgressParameters.Include = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $CopyItemWithProgressParameters.Include.Add('*.*')
            $CopyItemWithProgressParameters.Exclude = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $CopyItemWithProgressParameters.Exclude.Add('*.ini')
            $CopyItemWithProgressParameters.Recurse = $True
            $CopyItemWithProgressParameters.Force = $False
            $CopyItemWithProgressParameters.SegmentSize = 4096
            $CopyItemWithProgressParameters.RandomDelay = $False
            $CopyItemWithProgressParameters.ContinueOnError = $False
            $CopyItemWithProgressParameters.Verbose = $True

          $CopyItemWithProgressResult = Copy-ItemWithProgress @CopyItemWithProgressParameters

          Write-Output -InputObject ($CopyItemWithProgressResult)

          .NOTES
          A progress bar is displayed and can be useful for scripts where the copying of large file(s) is taking place.

          .LINK
          http://stackoverflow.com/questions/2434133/progress-during-large-file-copy-copy-item-write-progress

          .LINK
          https://stackoverflow.com/questions/13883404/custom-robocopy-progress-bar-in-powershell
        #>

        [CmdletBinding()]

        Param
          (
                [Parameter(Mandatory=$True)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({Test-Path -Path $_})]
                [Alias('P')]
                [String]$Path,

                [Parameter(Mandatory=$True)]
                [ValidateNotNullOrEmpty()]
                [Alias('D')]
                [System.IO.DirectoryInfo]$Destination,

                [Parameter(Mandatory=$False)]
                [Alias('I')]
                [String[]]$Include,

                [Parameter(Mandatory=$False)]
                [Alias('E')]
                [String[]]$Exclude,

                [Parameter(Mandatory=$False)]
                [Alias('R')]
                [Switch]$Recurse,

                [Parameter(Mandatory=$False)]
                [Alias('Overwrite')]
                [Switch]$Force,

                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('SS', 'BufferInMegabytes')]
                [Int]$SegmentSize,

                [Parameter(Mandatory=$False)]
                [Alias('RD')]
                [Switch]$RandomDelay,

                [Parameter(Mandatory=$False)]
                [Alias('COE')]
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

                    $WriteLogMessage.Invoke(0, @("Execution of $($CmdletName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"))

                    $FileSystemObject = New-Object -ComObject 'Scripting.FileSystemObject'

                    #region Set Default Parameter Values
                        Switch ($True)
                          {
                              {($Null -ieq $SegmentSize) -or ($SegmentSize -eq 0)}
                                {
                                    [Int]$SegmentSize = 8192
                                }
                          }
                    #endregion

                    #Create an object that will contain the functions output.
                      $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
                }
              Finally
                {

                }
          }

        Process
          {
              Try
                {
                    Switch ($Null -ine $Path)
                      {
                          {($_ -eq $True)}
                            {
                                $GetChildItemParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                    $GetChildItemParameters.Path = $Path
                                    $GetChildItemParameters.Force = $True
                                    $GetChildItemParameters.ErrorAction = [System.Management.Automation.Actionpreference]::SilentlyContinue

                                Switch ($True)
                                  {
                                      {([String]::IsNullOrEmpty($Include) -eq $False) -and ([String]::IsNullOrWhiteSpace($Include) -eq $False)}
                                        {
                                            $GetChildItemParameters.Include = $Include

                                            $WriteLogMessage.Invoke(1, @("File(s) matching $($GetChildItemParameters.Include -Join ', ') will be included."))
                                        }

                                      {([String]::IsNullOrEmpty($Exclude) -eq $False) -and ([String]::IsNullOrWhiteSpace($Exclude) -eq $False)}
                                        {
                                            $GetChildItemParameters.Exclude = $Exclude

                                            $WriteLogMessage.Invoke(1, @("File(s) matching $($GetChildItemParameters.Exclude -Join ', ') will be excluded."))
                                        }

                                      {($Recurse.IsPresent -eq $True)}
                                        {
                                            $GetChildItemParameters.Recurse = $True

                                            $WriteLogMessage.Invoke(1, @("The search will be performed recursively."))
                                        }
                                  }

                                $FileList = Get-ChildItem @GetChildItemParameters | Where-Object {($_ -is [System.IO.FileInfo])}

                                $FileListDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                  $FileListDetails.Count = ($FileList | Measure-Object).Count

                                Switch ($FileListDetails.Count -gt 0)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $WriteLogMessage.Invoke(0, @("$($FileListDetails.Count) file(s) will be copied in $($SegmentSize) MB segments to the destination directory of `"$($Destination.FullName)`". Please Wait..."))

                                            $FileListDetails.TotalBytes = ($FileList | Measure-Object -Sum 'Length').Sum
                                            $FileListDetails.TransferredBytes = 0
                                            $FileListDetails.PercentComplete = 0

                                            $WriteLogMessage.Invoke(0, @("A total of $([System.Math]::Round(($FileListDetails.TotalBytes / 1MB), 2)) MB needs to be transferred."))

                                            $StopWatchTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                              $StopWatchTable.Primary = New-Object -TypeName 'System.Diagnostics.Stopwatch'
                                              $StopWatchTable.Secondary = New-Object -TypeName 'System.Diagnostics.Stopwatch'

                                            $Null = $StopWatchTable.Primary.Start()

                                            For ($FileListIndex = 0; $FileListIndex -lt $FileListDetails.Count; $FileListIndex++)
                                              {
                                                  Try
                                                    {
                                                        $FileObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $FileObjectProperties.Source = ($FileList[$FileListIndex]) -As [System.IO.FileInfo]

                                                        Switch ($Recurse.IsPresent)
                                                          {
                                                              {($_ -eq $True)}
                                                                {
                                                                    $FileObjectProperties.SourceSegmentList = $FileObjectProperties.Source.FullName.Replace($Path, '').Split('\', [System.StringSplitOptions]::RemoveEmptyEntries) -As [System.Collections.Generic.List[String]]

                                                                    $FileObjectProperties.Destination = [System.IO.FileInfo][System.IO.Path]::Combine("$($Destination.FullName)", "$($FileObjectProperties.SourceSegmentList -Join '\')")

                                                                    $FileObjectProperties.Remove('SourceSegmentList')
                                                                }

                                                              Default
                                                                {
                                                                    $FileObjectProperties.Destination = [System.IO.FileInfo][System.IO.Path]::Combine("$($Destination.FullName)", "$($FileObjectProperties.Source.Name)")
                                                                }
                                                          }

                                                        Switch ($True)
                                                          {
                                                              {([System.IO.Directory]::Exists($FileObjectProperties.Destination.Directory.FullName) -eq $False)}
                                                                {
                                                                    $Null = [System.IO.Directory]::CreateDirectory($FileObjectProperties.Destination.Directory.FullName)
                                                                }
                                                          }

                                                        Switch (([System.IO.File]::Exists($FileObjectProperties.Destination.FullName) -eq $False) -or ($Force.IsPresent -eq $True))
                                                          {
                                                              {($_ -eq $True)}
                                                                {
                                                                    $WriteLogMessage.Invoke(1, @("Attempting to copy `"$($FileObjectProperties.Source.FullName)`" to `"$($FileObjectProperties.Destination.FullName)`". Please Wait..."))

                                                                    $FileDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                      $FileDetails.Source = [System.IO.File]::OpenRead($FileObjectProperties.Source.FullName)
                                                                      $FileDetails.Destination = [System.IO.File]::Create($FileObjectProperties.Destination.FullName)
                                                                      $FileDetails.Buffer = New-Object -TypeName 'Byte[]' -ArgumentList ($SegmentSize * 1024)
                                                                      $FileDetails.SegmentBytes = 0
                                                                      $FileDetails.TransferredBytes = 0
                                                                      $FileDetails.Number = $FileListIndex + 1

                                                                    $Null = $StopWatchTable.Secondary.Start()

                                                                    Do
                                                                      {
                                                                          $FileDetails.SegmentBytes = $FileDetails.Source.Read($FileDetails.Buffer, 0, $FileDetails.Buffer.Length)

                                                                          $FileDetails.Destination.Write($FileDetails.Buffer, 0, $FileDetails.SegmentBytes)

                                                                          $FileDetails.TransferredBytes = $FileDetails.TransferredBytes + $FileDetails.SegmentBytes

                                                                          $FileListDetails.TransferredBytes = $FileListDetails.TransferredBytes + $FileDetails.SegmentBytes

                                                                          Switch ($FileDetails.Source.Length -gt 1)
                                                                            {
                                                                                {($_ -eq $True)}
                                                                                  {
                                                                                      $FileDetails.PercentComplete = (($FileDetails.TransferredBytes / $FileDetails.Source.Length) * 100) -As [Int]
                                                                                  }

                                                                                Default
                                                                                  {
                                                                                      $FileDetails.PercentComplete = (100) -As [Int]
                                                                                  }
                                                                            }

                                                                          $FileDetails.PercentComplete = [System.Math]::Round($FileDetails.PercentComplete, 2)

                                                                          $FileDetails.TotalSecondsElasped = $StopWatchTable.Secondary.Elapsed.TotalSeconds -As [Int]

                                                                          Switch ($FileDetails.TotalSecondsElasped -ne 0)
                                                                            {
                                                                                {($_ -eq $True)}
                                                                                  {
                                                                                      $FileDetails.TransferRate = ($FileDetails.TransferredBytes / $FileDetails.TotalSecondsElasped / 1MB) -As [Single]
                                                                                  }

                                                                                Default
                                                                                  {
                                                                                      $FileDetails.TransferRate = (0.0) -As [Single]
                                                                                  }
                                                                            }

                                                                          $FileDetails.TransferRate = [System.Math]::Round($FileDetails.TransferRate, 2)

                                                                          Switch (($Total % 1MB) -eq 0)
                                                                            {
                                                                                {($_ -eq $True)}
                                                                                  {
                                                                                      Switch ($FileDetails.PercentComplete -gt 0)
                                                                                        {
                                                                                            {($_ -eq $True)}
                                                                                              {
                                                                                                  $FileDetails.SecondsRemaining = ((($FileDetails.TotalSecondsElasped / $FileDetails.PercentComplete) * 100) - $FileDetails.TotalSecondsElasped) -As [Int]
                                                                                              }

                                                                                            Default
                                                                                              {
                                                                                                  $FileDetails.SecondsRemaining = (0) -As [Int]
                                                                                              }
                                                                                        }

                                                                                      $FileListDetails.PercentComplete = [System.Math]::Round((($FileListDetails.TransferredBytes / $FileListDetails.TotalBytes) * 100), 2)

                                                                                      $FileListDetails.TotalSecondsElasped = $StopWatchTable.Primary.Elapsed.TotalSeconds -As [Int]

                                                                                      Switch ($FileListDetails.PercentComplete -gt 0)
                                                                                        {
                                                                                            {($_ -eq $True)}
                                                                                              {
                                                                                                  $FileListDetails.SecondsRemaining = ((($FileListDetails.TotalSecondsElasped / $FileListDetails.PercentComplete) * 100) - $FileListDetails.TotalSecondsElasped) -As [Int]
                                                                                              }

                                                                                            Default
                                                                                              {
                                                                                                  $FileListDetails.SecondsRemaining = ((($FileListDetails.TotalSecondsElasped / $FileListDetails.PercentComplete) * 100) - $FileListDetails.TotalSecondsElasped) -As [Int]
                                                                                              }
                                                                                        }

                                                                                      $TaskSequence = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                        $TaskSequence.Environment = Try {New-Object -ComObject 'Microsoft.SMS.TSEnvironment'} Catch {$Null}
                                                                                        $TaskSequence.IsRunning = $Null -ine $TaskSequence.Environment

                                                                                      Switch ($TaskSequence.IsRunning)
                                                                                        {
                                                                                            {($_ -eq $True)}
                                                                                              {
                                                                                                  $FileProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                    $FileProgressParameters.ID = 1
                                                                                                    $FileProgressParameters.Activity = "$($FileDetails.PercentComplete)% - Downloading $($FileSystemObject.GetFile($FileObjectProperties.Destination.FullName).ShortName) @ $($FileDetails.TransferRate) Mbps ($($FileDetails.Number) of $($FileListDetails.Count))"
                                                                                                    $FileProgressParameters.Status = "$($FileDetails.PercentComplete)% - Downloading $($FileSystemObject.GetFile($FileObjectProperties.Destination.FullName).ShortName) @ $($FileDetails.TransferRate) Mbps ($($FileDetails.Number) of $($FileListDetails.Count))"
                                                                                                    $FileProgressParameters.PercentComplete = $FileDetails.PercentComplete
                                                                                                    $FileProgressParameters.SecondsRemaining = $FileDetails.SecondsRemaining

                                                                                                  Write-Progress @FileProgressParameters
                                                                                              }

                                                                                            Default
                                                                                              {
                                                                                                  $TotalProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                    $TotalProgressParameters.ID = 1
                                                                                                    $TotalProgressParameters.Activity = "$($FileListDetails.PercentComplete)% - Copying file $($FileDetails.Number) of $($FileListDetails.Count) ($($FileListDetails.Count - $($FileListIndex)) left)"
                                                                                                    $TotalProgressParameters.Status = $FileObjectProperties.Source.FullName
                                                                                                    $TotalProgressParameters.PercentComplete = $FileListDetails.PercentComplete
                                                                                                    $TotalProgressParameters.SecondsRemaining = $FileListDetails.SecondsRemaining

                                                                                                  Write-Progress @TotalProgressParameters

                                                                                                  $FileProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                    $FileProgressParameters.ParentID = $TotalProgressParameters.ID
                                                                                                    $FileProgressParameters.ID = $TotalProgressParameters.ID + 1
                                                                                                    $FileProgressParameters.Activity = "$($FileDetails.PercentComplete)% - Copying @ $($FileDetails.TransferRate) Mbps"
                                                                                                    $FileProgressParameters.Status = $FileObjectProperties.Destination.FullName
                                                                                                    $FileProgressParameters.PercentComplete = $FileDetails.PercentComplete
                                                                                                    $FileProgressParameters.SecondsRemaining = $FileDetails.SecondsRemaining

                                                                                                  Write-Progress @FileProgressParameters
                                                                                              }
                                                                                        }
                                                                                  }
                                                                            }

                                                                          Switch ($RandomDelay.IsPresent)
                                                                            {
                                                                                {($_ -eq $True)}
                                                                                  {
                                                                                      $Delay = Get-Random -Minimum 1 -Maximum 1500

                                                                                      $Null = Start-Sleep -Milliseconds ($Delay)
                                                                                  }
                                                                            }
                                                                      }
                                                                    While ($FileDetails.SegmentBytes -gt 0)

                                                                    $Null = $FileDetails.Source.Close()

                                                                    $Null = $FileDetails.Destination.Close()

                                                                    $Null = $StopWatchTable.Secondary.Stop()

                                                                    $FileDetails = Get-Item -Path $FileObjectProperties.Destination.FullName -Force

                                                                    $FileAttributeList = $FileDetails.PSObject.Properties | Where-Object {($_.MemberType -iin @('NoteProperty', 'Property')) -and ($_.TypeNameOfValue -ieq 'System.DateTime') -and ($_.IsSettable -eq $True) -and ($_.Name -inotmatch '.*UTC.*')}

                                                                    ForEach ($FileAttribute In $FileAttributeList)
                                                                      {
                                                                          #$WriteLogMessage.Invoke(1, @("Attempting to update file attribute `"$($FileAttribute.Name)`" on file `"$($FileDetails.FullName)`" from `"$($FileDetails.$($FileAttribute.Name))`" to `"$($FileObjectProperties.Source.$($FileAttribute.Name))`". Please Wait..."))

                                                                          $FileDetails.$($FileAttribute.Name) = $FileObjectProperties.Source.$($FileAttribute.Name)
                                                                      }

                                                                    $FileObjectProperties.Destination = $FileDetails

                                                                    $FileObjectProperties.Status = 'Successful'
                                                                }

                                                              Default
                                                                {
                                                                    $WriteLogMessage.Invoke(1, @("File `"$($FileObjectProperties.Destination.FullName)`" already exists. Skipping."))

                                                                    $FileObjectProperties.Status = 'Skipped'
                                                                }
                                                          }
                                                    }
                                                  Catch
                                                    {
                                                        $FileObjectProperties.Status = 'Error'

                                                        $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
                                                    }
                                                  Finally
                                                    {
                                                        $FileObjectProperties.TimeToTransfer = $StopWatchTable.Secondary.Elapsed

                                                        $Null = $StopWatchTable.Secondary.Reset()

                                                        $FileObject = New-Object -TypeName 'PSObject' -Property ($FileObjectProperties)

                                                        $OutputObjectList.Add($FileObject)
                                                    }
                                              }

                                            $Null = $StopWatchTable.Primary.Stop()

                                            $Null = $StopWatchTable.Primary.Reset()

                                            $FileListStatusGroups = $OutputObjectList | Group-Object -Property 'Status' | Sort-Object -Property @('Name')

                                            ForEach ($FileListStatusGroup In $FileListStatusGroups)
                                              {
                                                  $WriteLogMessage.Invoke(0, @("$($FileListStatusGroup.Count) of $($FileListDetails.Count) file(s) have a status of `"$($FileListStatusGroup.Name)`"."))
                                              }
                                        }

                                      Default
                                        {
                                            $WriteLogMessage.Invoke(0, @("There are $($FileListDetails.Count) file(s) to copy to `"$($Destination.FullName)`". No further action will be taken."))
                                        }
                                  }
                            }

                          Default
                            {
                                $WriteLogMessage.Invoke(2, @("There were 0 paths specified to search. No further action will be taken."))
                            }
                      }
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
                }
              Finally
                {
                    $Null = Start-Sleep -Seconds 3
                }
          }

        End
          {
              Try
                {
                    #Determine the date and time the function completed execution
                      $FunctionEndTime = (Get-Date)

                      $WriteLogMessage.Invoke(0, @("Execution of $($CmdletName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"))

                    #Log the total script execution time
                      $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                      $WriteLogMessage.Invoke(0, @("Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"))

                    $WriteLogMessage.Invoke(0, @("Function `'$($CmdletName)`' is completed."))
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
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
