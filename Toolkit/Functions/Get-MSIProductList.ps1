#region Get-MSIProductList
Function Get-MSIProductList
  {
      <#
          .SYNOPSIS
          Retrieves the list of installed MSI products from the Windows Installer database.

          .DESCRIPTION
          Uses the 'WindowsInstaller.Installer' COM object to enumerate the installed product codes and return the associated product information attributes as objects.

          .PARAMETER ContinueOnError
          Continue processing even if an error occurs.

          .EXAMPLE
          Get-MSIProductList

          .NOTES
          Attributes that cannot be read for a given product will be returned as null.

          .LINK
          Place any useful link here where your function or cmdlet can be referenced
      #>

      [CmdletBinding()]
        Param
          (
              [Parameter(Mandatory=$False)]
              [Switch]$ContinueOnError
          )

      Try
        {
            $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

            $ComObject = New-Object -ComObject 'WindowsInstaller.Installer'

            $ComObjectType = $ComObject.GetType()

            [String[]]$AttributeList = @('Language', 'ProductName', 'PackageCode', 'Transforms', 'AssignmentType', 'PackageName', 'InstalledProductName', 'VersionString', 'RegCompany', 'RegOwner', 'ProductID', 'ProductIcon', 'InstallLocation', 'InstallSource', 'InstallDate', 'Publisher', 'LocalPackage', 'HelpLink', 'HelpTelephone', 'URLInfoAbout', 'URLUpdateInfo') | Sort-Object

            $ProductList = $ComObjectType.InvokeMember('Products', [System.Reflection.BindingFlags]::GetProperty, $Null, $ComObject, $Null)

            ForEach ($Product In $ProductList)
              {
                  $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                    $OutputObjectProperties.Add('ProductCode', $Product)

                  For ($AttributeListIndex = 0; $AttributeListIndex -lt $AttributeList.Count; $AttributeListIndex++)
                    {
                        [String]$AttributeName = $AttributeList[$AttributeListIndex]

                        Switch ($OutputObjectProperties.Contains($AttributeName))
                          {
                              {($_ -eq $False)}
                                {
                                    $OutputObjectProperties.Add($AttributeName, $Null)
                                }
                          }

                        Try {$OutputObjectProperties."$($AttributeName)" = $ComObjectType.InvokeMember('ProductInfo', [System.Reflection.BindingFlags]::GetProperty, $Null, $ComObject, @($Product, $AttributeName))} Catch {}
                    }

                  $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)

                  $Null = $OutputObjectList.Add($OutputObject)
              }

            Write-Output -InputObject ($OutputObjectList)
        }
      Catch
        {
            $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
        }
  }
#endregion
