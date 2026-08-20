## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Import-TrustedPublisherCertificate
Function Import-TrustedPublisherCertificate
    {
        <#
          .SYNOPSIS
          Imports the signing certificate(s) of the specified signed file(s) into the trusted publishers certificate store.

          .DESCRIPTION
          Driver packages that are signed by a publisher that is not already trusted will produce an interactive prompt during their installation.

          Importing the signing certificate of each driver catalog into the trusted publishers store ahead of the installation suppresses those prompts, which allows the installation to complete without user interaction.

          The signing certificates are read directly from the signed files, so no assumptions are made about which publisher signed the content.

          Certificates that are already present within the store are skipped, and duplicate signing certificates are only processed one time.

          .PARAMETER SearchDirectory
          One or more directories that will be recursively searched for signed files.

          .PARAMETER SearchFilter
          The file filter that will be used to locate the signed files within each search directory. The default filter locates driver catalog files.

          .PARAMETER StoreName
          The certificate store that the signing certificate(s) will be imported into. The default store is the trusted publishers store, which is the store that suppresses the driver installation prompts.

          .PARAMETER StoreLocation
          The certificate store location. The default store location is the local machine, which requires administrative rights.

          .PARAMETER ContinueOnError
          Continues processing even if an error has occured.

          .EXAMPLE
          $ImportTrustedPublisherCertificateParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $ImportTrustedPublisherCertificateParameters.SearchDirectory = 'C:\Temp\ExtractedInstaller'
            $ImportTrustedPublisherCertificateParameters.SearchFilter = '*.cat'
            $ImportTrustedPublisherCertificateParameters.ContinueOnError = $True
            $ImportTrustedPublisherCertificateParameters.Verbose = $True

          $ImportTrustedPublisherCertificateResult = Import-TrustedPublisherCertificate @ImportTrustedPublisherCertificateParameters

          Write-Output -InputObject ($ImportTrustedPublisherCertificateResult)

          .NOTES
          The static "CreateFromSignedFile" method returns the base certificate type, therefore the returned certificate is wrapped so that the thumbprint and the subject are available.
        #>

        [CmdletBinding()]
          Param
            (
                [Parameter(Mandatory=$True)]
                [ValidateNotNullOrEmpty()]
                [Alias('Path', 'SD')]
                [System.IO.DirectoryInfo[]]$SearchDirectory,

                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('SF')]
                [String]$SearchFilter = '*.cat',

                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('SN')]
                [System.Security.Cryptography.X509Certificates.StoreName]$StoreName = [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPublisher,

                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('SL')]
                [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine,

                [Parameter(Mandatory=$False)]
                [Alias('COE')]
                [Switch]$ContinueOnError
            )

        Begin
            {
                Try
                    {
                        $DateTimeLogFormat = 'dddd, MMMM dd, yyyy @ hh:mm:ss.FFF tt'
                        [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
                        $DateFileFormat = 'yyyyMMdd'
                        [ScriptBlock]$GetCurrentDateFileFormat = {(Get-Date).ToString($DateFileFormat)}
                        $DateTimeFileFormat = 'yyyyMMdd_HHmmss'
                        [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}

                        $CertificateList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

                        $ProcessedThumbprintList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
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
                        #region Locate every signed file within the specified search directory list
                          $SignedFileList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.FileInfo]'

                          ForEach ($SearchDirectoryItem In $SearchDirectory)
                            {
                                Switch ([System.IO.Directory]::Exists($SearchDirectoryItem.FullName))
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $LocatedFileList = Get-ChildItem -Path ($SearchDirectoryItem.FullName) -Filter ($SearchFilter) -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])}

                                            ForEach ($LocatedFile In $LocatedFileList)
                                              {
                                                  $SignedFileList.Add($LocatedFile)
                                              }
                                        }

                                      Default
                                        {
                                            Write-Verbose -Message "$($GetCurrentDateTimeLogFormat.Invoke()) - The search directory `"$($SearchDirectoryItem.FullName)`" does not exist and will be skipped." -Verbose
                                        }
                                  }
                            }

                          Write-Verbose -Message "$($GetCurrentDateTimeLogFormat.Invoke()) - Located $($SignedFileList.Count) signed file(s) matching the `"$($SearchFilter)`" filter." -Verbose
                        #endregion

                        #region Read the signing certificate of each signed file and import the distinct certificates into the trusted publishers store
                          Switch ($SignedFileList.Count -gt 0)
                            {
                                {($_ -eq $True)}
                                  {
                                      $CertificateStore = New-Object -TypeName 'System.Security.Cryptography.X509Certificates.X509Store' -ArgumentList @($StoreName, $StoreLocation)

                                      Try
                                        {
                                            $CertificateStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

                                            For ($SignedFileListIndex = 0; $SignedFileListIndex -lt $SignedFileList.Count; $SignedFileListIndex++)
                                              {
                                                  $SignedFile = $SignedFileList[$SignedFileListIndex]

                                                  Try
                                                    {
                                                        $SignerCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile($SignedFile.FullName)

                                                        #The static method returns the base certificate type, therefore it is wrapped so that the thumbprint and the subject are available
                                                          $SignerCertificate = New-Object -TypeName 'System.Security.Cryptography.X509Certificates.X509Certificate2' -ArgumentList @($SignerCertificate)

                                                        Switch ($ProcessedThumbprintList -icontains $SignerCertificate.Thumbprint)
                                                          {
                                                              {($_ -eq $False)}
                                                                {
                                                                    $ProcessedThumbprintList.Add($SignerCertificate.Thumbprint)

                                                                    $ExistingCertificateList = $CertificateStore.Certificates.Find([System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint, $SignerCertificate.Thumbprint, $False)

                                                                    [Boolean]$AlreadyPresent = ($ExistingCertificateList.Count -gt 0)

                                                                    Switch ($AlreadyPresent)
                                                                      {
                                                                          {($_ -eq $False)}
                                                                            {
                                                                                $CertificateStore.Add($SignerCertificate)

                                                                                Write-Verbose -Message "$($GetCurrentDateTimeLogFormat.Invoke()) - Imported the signing certificate of `"$($SignerCertificate.Subject)`" into the `"$($StoreLocation)\$($StoreName)`" store. [Thumbprint: $($SignerCertificate.Thumbprint)]" -Verbose
                                                                            }

                                                                          Default
                                                                            {
                                                                                Write-Verbose -Message "$($GetCurrentDateTimeLogFormat.Invoke()) - The signing certificate of `"$($SignerCertificate.Subject)`" is already present within the `"$($StoreLocation)\$($StoreName)`" store. [Thumbprint: $($SignerCertificate.Thumbprint)]" -Verbose
                                                                            }
                                                                      }

                                                                    $CertificateProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                      $CertificateProperties.Subject = $SignerCertificate.Subject
                                                                      $CertificateProperties.Issuer = $SignerCertificate.Issuer
                                                                      $CertificateProperties.Thumbprint = $SignerCertificate.Thumbprint
                                                                      $CertificateProperties.NotBefore = $SignerCertificate.NotBefore
                                                                      $CertificateProperties.NotAfter = $SignerCertificate.NotAfter
                                                                      $CertificateProperties.AlreadyPresent = $AlreadyPresent
                                                                      $CertificateProperties.SourceFile = $SignedFile

                                                                    $CertificateList.Add((New-Object -TypeName 'System.Management.Automation.PSObject' -Property ($CertificateProperties)))
                                                                }
                                                          }
                                                    }
                                                  Catch
                                                    {
                                                        Write-Verbose -Message "$($GetCurrentDateTimeLogFormat.Invoke()) - The signing certificate could not be read from `"$($SignedFile.FullName)`". [Error: $($_.Exception.Message)]"
                                                    }
                                              }
                                        }
                                      Finally
                                        {
                                            $Null = Try {$CertificateStore.Close()} Catch {}
                                        }
                                  }
                            }
                        #endregion

                        Write-Verbose -Message "$($GetCurrentDateTimeLogFormat.Invoke()) - Located $($CertificateList.Count) distinct signing certificate(s) and imported $(($CertificateList | Where-Object {($_.AlreadyPresent -eq $False)} | Measure-Object).Count) of them into the `"$($StoreLocation)\$($StoreName)`" store." -Verbose
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
                        Write-Output -InputObject ($CertificateList.ToArray())
                    }
                Catch
                    {
                        $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
                    }
            }
    }
#endregion
