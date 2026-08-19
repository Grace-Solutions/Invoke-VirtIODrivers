#region Get-MSIPropertyList
Function Get-MSIPropertyList
  {
      <#
          .SYNOPSIS
          Retrieves the property table from one or more MSI database files.

          .DESCRIPTION
          Uses the 'WindowsInstaller.Installer' COM object to open each specified MSI database, query the Property table, and return the properties as objects.

          .PARAMETER Path
          One or more paths to valid MSI files.

          .PARAMETER ContinueOnError
          Continue processing even if an error occurs.

          .EXAMPLE
          Get-MSIPropertyList -Path 'C:\Path\To\Installer.msi'

          .EXAMPLE
          $GetMSIPropertyListParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $GetMSIPropertyListParameters.Path = 'C:\Path\To\Installer.msi'

          $GetMSIPropertyListResult = Get-MSIPropertyList @GetMSIPropertyListParameters

          Write-Output -InputObject ($GetMSIPropertyListResult)

          .NOTES
          Each returned object contains the source path, followed by the properties contained within the MSI database.

          .LINK
          Place any useful link here where your function or cmdlet can be referenced
      #>

      [CmdletBinding()]
        Param
          (
              [Parameter(Mandatory=$True)]
              [ValidateNotNullOrEmpty()]
              [ValidateScript({(Test-Path -Path $_)})]
              [System.IO.FileInfo[]]$Path,

              [Parameter(Mandatory=$False)]
              [Switch]$ContinueOnError
          )

      Begin
        {
            $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
        }

      Process
        {
            Try
              {
                  ForEach ($Item In $Path)
                    {
                        $ComObject = New-Object -ComObject 'WindowsInstaller.Installer'

                        $MSIDatabase = $ComObject.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $Null, $ComObject, @($Item.FullName, 0))

                        [String]$Query = 'SELECT * FROM Property'

                        $View = $MSIDatabase.GetType().InvokeMember('OpenView', 'InvokeMethod', $Null, $MSIDatabase, $Query)
                          $Null = $View.GetType().InvokeMember('Execute', 'InvokeMethod', $Null, $View, $Null)

                        $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                          $OutputObjectProperties.Add('Path', $Item)

                        While ($Record = $View.GetType().InvokeMember('Fetch', 'InvokeMethod', $Null, $View, $Null))
                          {
                              Switch ($Null -ine $Record)
                                {
                                    {($_ -eq $True)}
                                      {
                                          [String]$MSIPropertyName = $Record.GetType().InvokeMember('StringData', 'GetProperty', $Null, $Record, 1)
                                          [String]$MSIPropertyValue = $Record.GetType().InvokeMember('StringData', 'GetProperty', $Null, $Record, 2)

                                          Switch ($OutputObjectProperties.Contains($MSIPropertyName))
                                            {
                                                {($_ -eq $False)}
                                                  {
                                                      $OutputObjectProperties.Add($MSIPropertyName, $MSIPropertyValue)
                                                  }
                                            }
                                      }
                                }
                          }

                        $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)

                        $OutputObjectList.Add($OutputObject)

                        $Null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($MSIDatabase)

                        $Null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject)
                    }
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
              }
            Finally
              {
                  $OutputObjectList = $OutputObjectList.ToArray()

                  Write-Output -InputObject ($OutputObjectList)
              }
        }

      End
        {

        }
  }
#endregion
