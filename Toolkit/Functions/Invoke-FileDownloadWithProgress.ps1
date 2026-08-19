#region Invoke-FileDownloadWithProgress
Function Invoke-FileDownloadWithProgress
  {
      <#
          .SYNOPSIS
          Downloads the specified URL to the specified destination directory with progress reporting and optional proxy support.

          .DESCRIPTION
          The file will only be downloaded if the last modified date of the source URL is different from the last modified date of the file that has already been downloaded or if the file has not already been downloaded.
          By default, the system default proxy is automatically detected: when a proxy applies to the download URL it is used with default credentials, and otherwise the connection is made directly. An explicit proxy can be specified with the ProxyURI parameter, optionally with a dedicated credential.
          When the download URL cannot be contacted (for example within Windows PE without internet access) and the destination file already exists, the existing local copy is used and no error is raised. The failure is only fatal when no local copy exists.

          .PARAMETER URL
          The URL where the file is located.

          .PARAMETER Destination
          The directory path where the URL will be downloaded to. If not specified, a default value will be used.

          .PARAMETER FileName
          The file name the download will be saved as. If not specified, the file name will be extracted from the URL.

          .PARAMETER ProxyURI
          An explicit proxy server URI (with full scheme) to route the download through. If not specified, the system default proxy will be used.

          .PARAMETER ProxyCredential
          The credential used to authenticate against the proxy specified by the ProxyURI parameter. If not specified, default credentials will be used.

          .PARAMETER ContinueOnError
          Ignore failures.

          .EXAMPLE
          Invoke-FileDownloadWithProgress -URL 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso' -Destination "$($Env:ProgramData)\ISOs" -Verbose

          .EXAMPLE
          $InvokeFileDownloadWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $InvokeFileDownloadWithProgressParameters.URL = 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso' -As [System.URI]
            $InvokeFileDownloadWithProgressParameters.Destination = "$($Env:ProgramData)\ISOs" -As [System.IO.DirectoryInfo]
            $InvokeFileDownloadWithProgressParameters.FileName = 'virtio-win.iso'
            $InvokeFileDownloadWithProgressParameters.ProxyURI = 'http://proxy.example.com:8080' -As [System.URI]
            $InvokeFileDownloadWithProgressParameters.ContinueOnError = $False
            $InvokeFileDownloadWithProgressParameters.Verbose = $True

          $InvokeFileDownloadWithProgressResult = Invoke-FileDownloadWithProgress @InvokeFileDownloadWithProgressParameters

          Write-Output -InputObject ($InvokeFileDownloadWithProgressResult)

          .NOTES
          The returned object exposes the following properties: DownloadRequired, Success, DownloadPath, URL, URLHeaders, and CompletionTimespan.

          .LINK
          https://learn.microsoft.com/en-us/dotnet/api/system.net.webclient
      #>

      [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess = $True)]
        Param
          (
              [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName = $True)]
              [ValidateNotNullOrEmpty()]
              [System.URI]$URL,

              [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName = $True)]
              [ValidateNotNullOrEmpty()]
              [System.IO.DirectoryInfo]$Destination,

              [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName = $True)]
              [ValidateNotNullOrEmpty()]
              [ValidatePattern('^.*\.(.*)$')]
              [String]$FileName,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('Proxy')]
              [System.URI]$ProxyURI,

              [Parameter(Mandatory=$False)]
              [ValidateNotNullOrEmpty()]
              [Alias('PC')]
              [System.Management.Automation.PSCredential]$ProxyCredential,

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

                  #Set default parameter values (If necessary)
                    Switch ($True)
                      {
                          {([String]::IsNullOrEmpty($Destination) -eq $True) -or ([String]::IsNullOrWhiteSpace($Destination) -eq $True)}
                            {
                                $Destination = [System.IO.DirectoryInfo][System.IO.Path]::Combine("$($Env:Windir)", 'Temp')
                            }

                          {([String]::IsNullOrEmpty($FileName) -eq $True) -or ([String]::IsNullOrWhiteSpace($FileName) -eq $True)}
                            {
                                [String]$FileName = [System.IO.Path]::GetFileName($URL.OriginalString)
                            }
                      }

                  $DestinationPath = [System.IO.FileInfo][System.IO.Path]::Combine($Destination.FullName, $FileName)

                  #Determine the proxy configuration for all outbound requests made by this function
                    Switch ($Null -ine $ProxyURI)
                      {
                          {($_ -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("An explicit proxy was specified. [Proxy URI: $($ProxyURI.AbsoluteURI)]"))

                                $WebProxy = New-Object -TypeName 'System.Net.WebProxy' -ArgumentList ($ProxyURI.AbsoluteURI)
                                  $WebProxy.BypassProxyOnLocal = $True

                                Switch ($Null -ine $ProxyCredential)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $WriteLogMessage.Invoke(0, @("The supplied proxy credential will be used for proxy authentication. [Username: $($ProxyCredential.UserName)]"))

                                            $WebProxy.Credentials = $ProxyCredential.GetNetworkCredential()
                                        }

                                      Default
                                        {
                                            $WriteLogMessage.Invoke(0, @("Default credentials will be used for proxy authentication."))

                                            $WebProxy.UseDefaultCredentials = $True
                                        }
                                  }
                            }

                          Default
                            {
                                #Determine whether the system default proxy actually applies to the download URL (If not, the connection will be made directly)
                                  $SystemProxy = [System.Net.WebRequest]::DefaultWebProxy

                                  $WebProxy = $Null

                                  Switch ($Null -ine $SystemProxy)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $ProxyURIForRequest = Try {$SystemProxy.GetProxy($URL)} Catch {$Null}

                                              Switch (($Null -ine $ProxyURIForRequest) -and ($ProxyURIForRequest.AbsoluteURI -ine $URL.AbsoluteURI) -and ($SystemProxy.IsBypassed($URL) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("A system default proxy was detected and will be used with default credentials. [Proxy: $($ProxyURIForRequest.AbsoluteURI)]"))

                                                          $SystemProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

                                                          $WebProxy = $SystemProxy
                                                      }

                                                    Default
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("No proxy was detected. The connection will be made directly."))
                                                      }
                                                }
                                          }

                                        Default
                                          {
                                              $WriteLogMessage.Invoke(0, @("No proxy was detected. The connection will be made directly."))
                                          }
                                    }
                            }
                      }

                  $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                    $OutputObjectProperties.DownloadRequired = $False
                    $OutputObjectProperties.Success = $True

                  #region Function Convert-FileSize
                  Function Convert-FileSize
                    {
                        <#
                          .SYNOPSIS
                          Converts a size in bytes to its upper most value.

                          .PARAMETER Size
                          The size in bytes to convert.

                          .PARAMETER DecimalPlaces
                          The number of decimal places to round the calculated size to.
                        #>

                        [CmdletBinding()]
                          Param
                            (
                                [Parameter(Mandatory=$True)]
                                [ValidateNotNullOrEmpty()]
                                [Alias('Length')]
                                $Size,

                                [Parameter(Mandatory=$False)]
                                [ValidateNotNullOrEmpty()]
                                [Alias('DP')]
                                [Int]$DecimalPlaces
                            )

                        Try
                          {
                              Switch ($True)
                                {
                                    {([String]::IsNullOrEmpty($DecimalPlaces) -eq $True) -or ([String]::IsNullOrWhiteSpace($DecimalPlaces) -eq $True)}
                                      {
                                          [Int]$DecimalPlaces = 2
                                      }
                                }

                              $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                $OutputObjectProperties.Size = $Size
                                $OutputObjectProperties.DecimalPlaces = $DecimalPlaces

                              Switch ($Size)
                                {
                                    {($_ -lt 1MB)}
                                      {
                                          $OutputObjectProperties.Divisor = 1KB
                                          $OutputObjectProperties.SizeUnit = 'KB'
                                          $OutputObjectProperties.SizeUnitAlias = 'Kilobytes'

                                          Break
                                      }

                                    {($_ -lt 1GB)}
                                      {
                                          $OutputObjectProperties.Divisor = 1MB
                                          $OutputObjectProperties.SizeUnit = 'MB'
                                          $OutputObjectProperties.SizeUnitAlias = 'Megabytes'

                                          Break
                                      }

                                    {($_ -lt 1TB)}
                                      {
                                          $OutputObjectProperties.Divisor = 1GB
                                          $OutputObjectProperties.SizeUnit = 'GB'
                                          $OutputObjectProperties.SizeUnitAlias = 'Gigabytes'

                                          Break
                                      }

                                    {($_ -ge 1TB)}
                                      {
                                          $OutputObjectProperties.Divisor = 1TB
                                          $OutputObjectProperties.SizeUnit = 'TB'
                                          $OutputObjectProperties.SizeUnitAlias = 'Terabytes'

                                          Break
                                      }
                                }

                              $OutputObjectProperties.CalculatedSize = [System.Math]::Round(($Size / $OutputObjectProperties.Divisor), $OutputObjectProperties.DecimalPlaces)
                              $OutputObjectProperties.CalculatedSizeStr = "$($OutputObjectProperties.CalculatedSize) $($OutputObjectProperties.SizeUnit)"
                          }
                        Catch
                          {
                              Write-Error -Exception $_
                          }
                        Finally
                          {
                              $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)

                              Write-Output -InputObject ($OutputObject)
                          }
                    }
                  #endregion
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
                  #region Attempt to contact the download URL for metadata (A failure here is only fatal when no local copy of the file exists)
                    $WebRequestSucceeded = $False

                    $URLLastModifiedAvailable = $False

                    Try
                      {
                          $WriteLogMessage.Invoke(0, @("Attempting to create a web request for `"$($URL.OriginalString)`". Please Wait..."))

                          $WebRequest = [System.Net.WebRequest]::Create($URL.AbsoluteURI)
                            $WebRequest.Proxy = $WebProxy
                            $WebRequest.UseDefaultCredentials = $True
                            $WebRequest.Timeout = [System.Convert]::ToInt32([System.TimeSpan]::FromSeconds(30).TotalMilliseconds)

                          $WebRequestResponse = $WebRequest.GetResponse()

                          $WriteLogMessage.Invoke(0, @("Web Request Response Status: $($WebRequestResponse.StatusCode) [Status Code: $($WebRequestResponse.StatusCode.value__)]"))

                          $WebRequestResponseHeaders = $WebRequestResponse.Headers

                          $WebRequestHeaderProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'

                          ForEach ($WebRequestResponseHeader In $WebRequestResponseHeaders.AllKeys)
                            {
                                $WebRequestHeaderProperties."$($WebRequestResponseHeader)" = ($WebRequestResponseHeaders.GetValues($WebRequestResponseHeader))[0]
                            }

                          $WebRequestHeaders = New-Object -TypeName 'PSObject' -Property ($WebRequestHeaderProperties)

                          #Determine whether the source URL exposes a last modified date (Not all web servers do)
                            $URLLastModifiedAvailable = ([String]::IsNullOrEmpty($WebRequestHeaders.'Last-Modified') -eq $False) -and ([String]::IsNullOrWhiteSpace($WebRequestHeaders.'Last-Modified') -eq $False)

                            Switch ($URLLastModifiedAvailable)
                              {
                                  {($_ -eq $True)}
                                    {
                                        $WebRequestHeaders.'Last-Modified' = (Get-Date -Date $WebRequestHeaders.'Last-Modified').ToUniversalTime()
                                    }

                                  {($_ -eq $False)}
                                    {
                                        $WriteLogMessage.Invoke(2, @("The source URL does not expose a `"Last-Modified`" header. The download will only be skipped if the destination file already exists."))
                                    }
                              }

                          $ContentLengthInMB = [System.Math]::Round(($WebRequestHeaders.'Content-Length' / 1MB), 2)

                          $WebRequestSucceeded = $True
                      }
                    Catch
                      {
                          $WriteLogMessage.Invoke(2, @("Unable to contact the download URL `"$($URL.OriginalString)`". [Error: $($_.Exception.Message)]"))
                      }
                  #endregion

                  $DownloadExecutionStopwatch = New-Object -TypeName 'System.Diagnostics.Stopwatch'

                  [ScriptBlock]$ExecuteDownload = {
                                                      Try
                                                        {
                                                            $WebClient = New-Object -TypeName 'System.Net.WebClient'
                                                              $WebClient.UseDefaultCredentials = $True
                                                              $WebClient.Proxy = $WebProxy

                                                            $WriteLogMessage.Invoke(0, @("Attempting to download URL `"$($URL.OriginalString)`" to `"$($DestinationPath.FullName)`". Please Wait..."))

                                                            $WriteLogMessage.Invoke(0, @("Download Size: $($ContentLengthInMB) MB"))

                                                            If ([System.IO.Directory]::Exists($DestinationPath.Directory.FullName) -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($DestinationPath.Directory.FullName)}

                                                            $Downloader = $WebClient.DownloadFileTaskAsync($URL.OriginalString, $DestinationPath.FullName)

                                                            $Null = Register-ObjectEvent -InputObject ($WebClient) -EventName 'DownloadProgressChanged' -SourceIdentifier 'WebClient.DownloadProgressChanged'

                                                            $Null = Start-Sleep -Seconds 3

                                                            $Null = $DownloadExecutionStopwatch.Start()

                                                            Switch ($Downloader.IsFaulted)
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        $WriteLogMessage.Invoke(2, @("A download error has occured. Attempting to generate the error record. Please Wait..."))

                                                                        Write-Error -Message ($Downloader.GetAwaiter().GetResult())
                                                                    }
                                                              }

                                                            While ($Downloader.IsCompleted -eq $False)
                                                              {
                                                                  Switch ($Downloader.IsFaulted)
                                                                    {
                                                                        {($_ -eq $True)}
                                                                          {
                                                                              $WriteLogMessage.Invoke(2, @("A download error has occured. Attempting to generate the error record. Please Wait..."))

                                                                              Write-Error -Message ($Downloader.GetAwaiter().GetResult())
                                                                          }
                                                                    }

                                                                  $EventData = Get-Event -SourceIdentifier 'WebClient.DownloadProgressChanged' | Select-Object -ExpandProperty 'SourceEventArgs' -Last 1

                                                                  $EventDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                    $EventDetails.Received = Convert-FileSize -Size ($EventData.BytesReceived) -DecimalPlaces 2
                                                                    $EventDetails.TotalToReceive = Convert-FileSize -Size ($EventData.TotalBytesToReceive) -DecimalPlaces 2
                                                                    $EventDetails.ProgressPercentage = $EventData.ProgressPercentage

                                                                  Switch ($DownloadExecutionStopwatch.Elapsed.TotalSeconds -gt 0)
                                                                    {
                                                                        {($_ -eq $True)}
                                                                          {
                                                                              [Single]$TransferRate = [System.Math]::Round(($EventData.BytesReceived / $DownloadExecutionStopwatch.Elapsed.TotalSeconds / 1MB), 2)
                                                                          }

                                                                        Default
                                                                          {
                                                                              [Single]$TransferRate = 0.00
                                                                          }
                                                                    }

                                                                  $WriteProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                    $WriteProgressParameters.Activity = "Downloading `"$($DestinationPath.Name)`""
                                                                    $WriteProgressParameters.Status = "Completion Percentage: $($EventDetails.ProgressPercentage)%"
                                                                    $WriteProgressParameters.PercentComplete = $EventDetails.ProgressPercentage
                                                                    $WriteProgressParameters.CurrentOperation = "Downloaded $($EventDetails.Received.CalculatedSizeStr) of $($EventDetails.TotalToReceive.CalculatedSizeStr) @ $($TransferRate) MB/s"

                                                                  Write-Progress @WriteProgressParameters

                                                                  $WriteLogMessage.Invoke(1, @("$($EventDetails.ProgressPercentage)% - $($WriteProgressParameters.CurrentOperation)"))

                                                                  $Null = Start-Sleep -Milliseconds 1500
                                                              }
                                                        }
                                                      Catch
                                                        {
                                                            Throw
                                                        }
                                                      Finally
                                                        {
                                                            $WriteProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                              $WriteProgressParameters.Activity = "Downloading `"$($DestinationPath.Name)`""
                                                              $WriteProgressParameters.Completed = $True

                                                            Write-Progress @WriteProgressParameters

                                                            $Null = Unregister-Event -SourceIdentifier 'WebClient.DownloadProgressChanged' -ErrorAction SilentlyContinue

                                                            Switch (($Downloader.IsCompleted -eq $False) -or ($Downloader.IsFaulted -eq $True))
                                                              {
                                                                  {($_ -eq $True)}
                                                                    {
                                                                        Try {$Null = $WebClient.CancelAsync()} Catch {}

                                                                        $WriteLogMessage.Invoke(2, @("Download failed. Attempting to remove incomplete file `"$($DestinationPath.FullName)`". Please Wait..."))

                                                                        $Null = [System.IO.File]::Delete($DestinationPath.FullName)
                                                                    }
                                                              }

                                                            Try {$Null = $WebClient.Dispose()} Catch {}

                                                            $Null = $DownloadExecutionStopwatch.Stop()
                                                        }

                                                      $WriteLogMessage.Invoke(0, @("Download completed in $($DownloadExecutionStopwatch.Elapsed.Hours.ToString()) hour(s), $($DownloadExecutionStopwatch.Elapsed.Minutes.ToString()) minute(s), $($DownloadExecutionStopwatch.Elapsed.Seconds.ToString()) second(s), and $($DownloadExecutionStopwatch.Elapsed.Milliseconds.ToString()) millisecond(s)."))

                                                      Switch ($URLLastModifiedAvailable)
                                                        {
                                                            {($_ -eq $True)}
                                                              {
                                                                  $WriteLogMessage.Invoke(0, @("Attempting to update the last modified date of `"$($DestinationPath.FullName)`" to match the last modified date of `"$($URL.OriginalString)`". Please Wait..."))

                                                                  $DestinationPathDetails = Get-Item -Path $DestinationPath.FullName -Force

                                                                  $Null = $DestinationPathDetails.LastWriteTimeUTC = $WebRequestHeaders.'Last-Modified'
                                                              }
                                                        }
                                                  }

                  Switch ($True)
                    {
                        {($WebRequestSucceeded -eq $False) -and ([System.IO.File]::Exists($DestinationPath.FullName) -eq $True)}
                          {
                              $WriteLogMessage.Invoke(2, @("The download URL could not be contacted, but destination path `"$($DestinationPath.FullName)`" already exists. The existing local copy will be used."))

                              Break
                          }

                        {($WebRequestSucceeded -eq $False) -and ([System.IO.File]::Exists($DestinationPath.FullName) -eq $False)}
                          {
                              Throw "The download URL `"$($URL.OriginalString)`" could not be contacted and destination path `"$($DestinationPath.FullName)`" does not exist."
                          }

                        {([System.IO.File]::Exists($DestinationPath.FullName) -eq $True)}
                          {
                              $WriteLogMessage.Invoke(0, @("Destination path `"$($DestinationPath.FullName)`" already exists."))

                              Switch ($URLLastModifiedAvailable)
                                {
                                    {($_ -eq $True)}
                                      {
                                          $WriteLogMessage.Invoke(0, @("Attempting to check the last modified date of `"$($DestinationPath.FullName)`" to see if a download is necessary."))

                                          $WriteLogMessage.Invoke(0, @("Last Modified Date UTC (Local File): $($DestinationPath.LastWriteTimeUTC.ToString('yyyy/MM/dd HH:mm:ss'))"))

                                          $WriteLogMessage.Invoke(0, @("Last Modified Date UTC (URL Header): $($WebRequestHeaders.'Last-Modified'.ToString('yyyy/MM/dd HH:mm:ss'))"))

                                          Switch ($DestinationPath.LastWriteTimeUTC -ine $WebRequestHeaders.'Last-Modified')
                                            {
                                                {($_ -eq $True)}
                                                  {
                                                      $WriteLogMessage.Invoke(2, @("A redownload of `"$($URL.OriginalString)`" is necessary."))

                                                      $OutputObjectProperties.DownloadRequired = $True

                                                      $ExecuteDownload.Invoke()
                                                  }

                                                Default
                                                  {
                                                      $WriteLogMessage.Invoke(0, @("A redownload of `"$($URL.OriginalString)`" is not necessary."))
                                                  }
                                            }
                                      }

                                    {($_ -eq $False)}
                                      {
                                          $WriteLogMessage.Invoke(0, @("A redownload of `"$($URL.OriginalString)`" is not necessary."))
                                      }
                                }

                              Break
                          }

                        Default
                          {
                              $WriteLogMessage.Invoke(2, @("Destination path `"$($DestinationPath.FullName)`" does not exist.", "A download of `"$($URL.OriginalString)`" is necessary."))

                              $OutputObjectProperties.DownloadRequired = $True

                              $ExecuteDownload.Invoke()
                          }
                    }
              }
            Catch
              {
                  $OutputObjectProperties.Success = $False

                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
              }
            Finally
              {
                  Try {$Null = $WebRequestResponse.Dispose()} Catch {}
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
                  $OutputObjectProperties.Success = $False

                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
              }
            Finally
              {
                  $DestinationPathDetails = Try {Get-Item -Path $DestinationPath.FullName -Force -ErrorAction SilentlyContinue} Catch {$Null}

                  $OutputObjectProperties.DownloadPath = $DestinationPathDetails
                  $OutputObjectProperties.URL = $URL
                  $OutputObjectProperties.URLHeaders = $WebRequestHeaders
                  $OutputObjectProperties.CompletionTimespan = $Null

                  Switch ($True)
                    {
                        {($OutputObjectProperties.DownloadRequired -eq $True)}
                          {
                              $OutputObjectProperties.CompletionTimespan = $DownloadExecutionStopwatch.Elapsed
                          }
                    }

                  $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)

                  Write-Output -InputObject ($OutputObject)
              }
        }
  }
#endregion
