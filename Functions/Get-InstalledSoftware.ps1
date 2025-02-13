## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Get-InstalledSoftware
Function Get-InstalledSoftware
    {
        <#
          .SYNOPSIS
          Retrieves a list of software installed on the current device.
          
          .DESCRIPTION
          Supports filtering the resulting list of software by using regular expressions. 
          
          .PARAMETER FilterInclusionExpression
          Includes software based on their display name.

          .PARAMETER FilterInclusionExpression
          Excludes software based on their display name.

          .PARAMETER PropertyList
          Retrieves the value of each specified value name for a piece software. This will make the returned objects uniform.

          By default, the following properties are retrieved by default. Additional non specified properties are also added to the returned objects for easier locating of software outside of this function.

          .PARAMETER AllProperties
          Retrieves the value of each value name that is detected for a piece of software. This will make the returned objects non-uniform because of how software vendors have not standardized this process.

          .PARAMETER AllUserProfiles
          When this function is executed with the appropriate permissions, all user profile(s) can be searched for software by using their SIDs. The user profile(s) will be dynamically determined and associated with the pieces of software that are located.

          .PARAMETER AdditionalRegistryHiveObjects
          Allows for searching additional registry hives as necessary in order to extend the search. See examples below.
          
          .PARAMETER ContinueOnError
          Continues processing even if an error has occured.

          .EXAMPLE
          Get-InstalledSoftware -AllProperties
          
          .EXAMPLE
          $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $GetInstalledSoftwareParameters.FilterExpression = {($_.DisplayName -imatch '(^.*Google.*Chrome.*$)') -and ([Version]$_.DisplayVersion -ge [Version]'75.0.0.0')}
	          $GetInstalledSoftwareParameters.AllProperties = $False
	          $GetInstalledSoftwareParameters.AllUserProfiles = $True
	          $GetInstalledSoftwareParameters.ContinueOnError = $False
	          $GetInstalledSoftwareParameters.Verbose = $True

          $GetInstalledSoftwareResult = Get-InstalledSoftware @GetInstalledSoftwareParameters

          Write-Output -InputObject ($GetInstalledSoftwareResult)

          .EXAMPLE
          $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $GetInstalledSoftwareParameters.FilterExpression = {($_.DisplayName -imatch '(^.*$)') -and ($_.DisplayName -inotmatch '(^.{0,0}$)')}
            $GetInstalledSoftwareParameters.PropertyList = New-Object -TypeName 'System.Collections.Generic.List[String]'      
              $GetInstalledSoftwareParameters.PropertyList.Add('DisplayName')
              $GetInstalledSoftwareParameters.PropertyList.Add('DisplayVersion')
              $GetInstalledSoftwareParameters.PropertyList.Add('UninstallString')
              $GetInstalledSoftwareParameters.PropertyList.Add('InstallLocation')
              $GetInstalledSoftwareParameters.PropertyList.Add('Publisher')
              $GetInstalledSoftwareParameters.PropertyList.Add('InstallDate')
            $GetInstalledSoftwareParameters.ContinueOnError = $False
            $GetInstalledSoftwareParameters.Verbose = $False

          $GetInstalledSoftwareResult = Get-InstalledSoftware @GetInstalledSoftwareParameters

          Write-Output -InputObject ($GetInstalledSoftwareResult)

          .EXAMPLE
          $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
            $GetInstalledSoftwareParameters.FilterExpression = {($_.DisplayName -imatch '(^.*$)') -and ($_.DisplayName -inotmatch '(^.{0,0}$)')}
            $GetInstalledSoftwareParameters.AllProperties = $True
            $GetInstalledSoftwareParameters.AdditionalRegistryHiveObjects = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

            $RegistryHiveProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
              $RegistryHiveProperties.Add('Type', [Microsoft.Win32.RegistryHive]::Users)
              $RegistryHiveProperties.Add('KeyList', (New-Object -TypeName 'System.Collections.Generic.List[String]'))
                $RegistryHiveProperties.KeyList.Add("SID\Software\Microsoft\Windows\CurrentVersion\Uninstall")    
                                                    
            Switch ([System.Environment]::Is64BitOperatingSystem)
              {
                  {($_ -eq $True)}
                    {
                        $RegistryHiveProperties.KeyList.Add("SID\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
                    }
              }
                            
            $RegistryHiveObject = New-Object -TypeName 'PSObject' -Property ($RegistryHiveProperties)
                          
            $GetInstalledSoftwareParameters.AdditionalRegistryHiveObjects.Add($RegistryHiveObject)

            $GetInstalledSoftwareParameters.ContinueOnError = $False
            $GetInstalledSoftwareParameters.Verbose = $True

          $GetInstalledSoftwareResult = Get-InstalledSoftware @GetInstalledSoftwareParameters

          Write-Output -InputObject ($GetInstalledSoftwareResult)
        #>
        
        [CmdletBinding(DefaultParameterSetName = 'PropertyList')]
       
        Param
          (        
                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('IE')]
                [ScriptBlock]$FilterExpression,

                [Parameter(Mandatory=$False, ParameterSetName = 'PropertyList')]
                [Alias('PL')]
                [String[]]$PropertyList,

                [Parameter(Mandatory=$False, ParameterSetName = 'AllProperties')]
                [Alias('AP')]
                [Switch]$AllProperties,

                [Parameter(Mandatory=$False)]
                [Alias('AUP')]
                [Switch]$AllUserProfiles,

                [Parameter(Mandatory=$False)]
                [ValidateNotNullOrEmpty()]
                [Alias('ARH')]
                [PSObject[]]$AdditionalRegistryHiveObjects,
                                                    
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
                    $RegularExpressionTable = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                      $RegularExpressionTable.Base64 = '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$' -As [Regex]
                      $RegularExpressionTable.GUID = '(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}' -As [Regex]   
                    $RegexOptionList = New-Object -TypeName 'System.Collections.Generic.List[System.Text.RegularExpressions.RegexOptions[]]'
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                      $RegexOptionList.Add([System.Text.RegularExpressions.RegexOptions]::Multiline)

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
                     
                    [String]$FunctionName = $MyInvocation.MyCommand
                    [System.IO.FileInfo]$InvokingScriptPath = $MyInvocation.PSCommandPath
                    [System.IO.DirectoryInfo]$InvokingScriptDirectory = $InvokingScriptPath.Directory.FullName
                    [System.IO.FileInfo]$FunctionPath = "$($InvokingScriptDirectory.FullName)\Functions\$($FunctionName).ps1"
                    [System.IO.DirectoryInfo]$FunctionDirectory = "$($FunctionPath.Directory.FullName)"
                    
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is beginning. Please Wait..."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      
                    [String[]]$AvailableScriptParameters = (Get-Command -Name ($FunctionName)).Parameters.GetEnumerator() | Where-Object {($_.Value.Name -inotin $CommonParameterList)} | ForEach-Object {"-$($_.Value.Name):$($_.Value.ParameterType.Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Available Function Parameter(s) = $($AvailableScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    [String[]]$SuppliedScriptParameters = $PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key):$($_.Value.GetType().Name)"}
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Supplied Function Parameter(s) = $($SuppliedScriptParameters -Join ', ')"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Execution of $($FunctionName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    #region Set Default Parameter Values
                        Switch ($True)
                          {
                              {($Null -ieq $PropertyList) -or ($PropertyList.Count -eq 0)}
                                {
                                    $OutputObjectValueList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                      $OutputObjectValueList.Add('DisplayName')
                                      $OutputObjectValueList.Add('DisplayVersion')
                                      $OutputObjectValueList.Add('UninstallString')
                                      $OutputObjectValueList.Add('QuietUninstallString')
                                      $OutputObjectValueList.Add('InstallLocation')
                                      $OutputObjectValueList.Add('Publisher')
                                      $OutputObjectValueList.Add('InstallDate')
                                    
                                    [String[]]$PropertyList = $OutputObjectValueList.ToArray()
                                }
                          }
                    #endregion

                    #Create a table for the conversion of dates
                      $DateTimeProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                        $DateTimeProperties.FormatList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                          $DateTimeProperties.FormatList.AddRange(([System.Globalization.DateTimeFormatInfo]::CurrentInfo.GetAllDateTimePatterns()))
                          $DateTimeProperties.FormatList.AddRange(([System.Globalization.DateTimeFormatInfo]::InvariantInfo.GetAllDateTimePatterns()))
                          $DateTimeProperties.FormatList.Add('yyyyMM')
                          $DateTimeProperties.FormatList.Add('yyyyMMdd')
                        $DateTimeProperties.Culture = $Null
                        $DateTimeProperties.Styles = New-Object -TypeName 'System.Collections.Generic.List[System.Globalization.DateTimeStyles]'
                          $DateTimeProperties.Styles.Add([System.Globalization.DateTimeStyles]::AssumeLocal)
                          $DateTimeProperties.Styles.Add([System.Globalization.DateTimeStyles]::AllowWhiteSpaces)
                                        
                    #Create an object that will contain the functions output.
                      $OutputObjectList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
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
                    $RegistryHiveList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
                    
                    $RegistryHiveProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                      $RegistryHiveProperties.Add('Type', [Microsoft.Win32.RegistryHive]::LocalMachine)
                      $RegistryHiveProperties.Add('KeyList', (New-Object -TypeName 'System.Collections.Generic.List[String]'))
                        $RegistryHiveProperties.KeyList.Add('Software\Microsoft\Windows\CurrentVersion\Uninstall')

                    Switch ([System.Environment]::Is64BitOperatingSystem)
                      {
                          {($_ -eq $True)}
                            {
                                $RegistryHiveProperties.KeyList.Add('Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
                            }
                      }
                        
                    $RegistryHiveObject = New-Object -TypeName 'PSObject' -Property ($RegistryHiveProperties)
                    
                    $RegistryHiveList.Add($RegistryHiveObject)
      
                    Switch ($AllUserProfiles.IsPresent)
                      {
                          {($_ -eq $True)}
                            {
                                $UserProfilePropertyList = New-Object -TypeName 'System.Collections.Generic.List[Object]'
                                  $UserProfilePropertyList.Add('LocalPath')
                                  $UserProfilePropertyList.Add('SID')
                                  $UserProfilePropertyList.Add(@{Name = 'NTAccount'; Expression = {Try {(New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList @($_.SID)).Translate([System.Security.Principal.NTAccount]).Value} Catch {$Null}}})
                                  $UserProfilePropertyList.Add('Special')
                                  $UserProfilePropertyList.Add('Loaded')

                                $UserProfileList = Get-CIMInstance -Namespace 'root\CIMv2' -Class 'Win32_UserProfile' | Where-Object {($_.Special -eq $False)} | Select-Object -Property ($UserProfilePropertyList) | Where-Object {([String]::IsNullOrEmpty($_.NTAccount) -eq $False) -and ([String]::IsNullOrWhiteSpace($_.NTAccount) -eq $False)}

                                ForEach ($UserProfile In $UserProfileList)
                                  { 
                                      $RegistryHiveProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                        $RegistryHiveProperties.Add('Type', [Microsoft.Win32.RegistryHive]::Users)
                                        $RegistryHiveProperties.Add('NTAccount', $UserProfile.NTAccount)
                                        $RegistryHiveProperties.Add('SID', $UserProfile.SID)
                                        $RegistryHiveProperties.Add('KeyList', (New-Object -TypeName 'System.Collections.Generic.List[String]'))
                                          $RegistryHiveProperties.KeyList.Add("$($RegistryHiveProperties.SID)\Software\Microsoft\Windows\CurrentVersion\Uninstall")    
                          
                                      $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to add user profile `"$($RegistryHiveProperties.NTAccount)`" [SID: $($RegistryHiveProperties.SID)] to the search for installed software. Please Wait..."
                                      Write-Verbose -Message ($LoggingDetails.LogMessage)
                          
                                      Switch ([System.Environment]::Is64BitOperatingSystem)
                                        {
                                            {($_ -eq $True)}
                                              {
                                                  $RegistryHiveProperties.KeyList.Add("$($RegistryHiveProperties.SID)\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
                                              }
                                        }
                            
                                      $RegistryHiveObject = New-Object -TypeName 'PSObject' -Property ($RegistryHiveProperties)
                          
                                      $RegistryHiveList.Add($RegistryHiveObject)
                                  }
                            }
                      }
                    
                    ForEach ($AdditionalRegistryHiveObject In $AdditionalRegistryHiveObjects) {$RegistryHiveList.Add($AdditionalRegistryHiveObject)}
      
                    For ($RegistryHiveListIndex = 0; $RegistryHiveListIndex -lt $RegistryHiveList.Count; $RegistryHiveListIndex++)
                      {
                          $RegistryHive = $RegistryHiveList[$RegistryHiveListIndex]

                          $RegistryHivePropertyList = $RegistryHive.PSObject.Properties

                          [Char[]]$HiveNameCharacterArray = ForEach ($Character in $RegistryHive.Type.ToString().ToCharArray())
                            {
                                If ([Char]::IsUpper($Character))
                                  {
                                      '_'
                                  }
      
                                $Character
                            }

                          $HiveName = 'HKEY' + ($HiveNameCharacterArray -Join '').Trim().ToUpper()
      
                          $RegistryHiveObject = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive.Type, [Microsoft.Win32.RegistryView]::Default)
      
                          For ($KeyListIndex = 0; $KeyListIndex -lt $RegistryHive.KeyList.Count; $KeyListIndex++)
                            {
                                $RegistryKey = $RegistryHive.KeyList[$KeyListIndex]

                                $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Attempting to search registry key path `"$($HiveName)\$($RegistryKey)`". Please Wait..."
                                Write-Verbose -Message ($LoggingDetails.LogMessage)
      
                                $RegistryKeyObject = $RegistryHiveObject.OpenSubKey($RegistryKey)
                                
                                Switch ($Null -ine $RegistryKeyObject)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            $SubKeyNameList = $RegistryKeyObject.GetSubKeyNames() | Sort-Object
      
                                            For ($SubKeyNameListIndex = 0; $SubKeyNameListIndex -lt $SubKeyNameList.Count; $SubKeyNameListIndex++)
                                              {
                                                  Try
                                                    {
                                                        $SubKeyName = $SubKeyNameList[$SubKeyNameListIndex]
      
                                                        $SubKeyObject = $RegistryKeyObject.OpenSubKey($SubKeyName)
      
                                                        $SubKeyObjectSegments = $SubKeyObject.Name.Split('\')
      
                                                        $OutputObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                          $OutputObjectProperties.RegistryPath = $SubKeyObject.Name
                                                          $OutputObjectProperties.RegistryHive = $RegistryHive.Type.value__
                                                          $OutputObjectProperties.RegistryHiveName = $HiveName
                                                          $OutputObjectProperties.RegistryLocation = ($SubKeyObjectSegments[1..$($SubKeyObjectSegments.GetUpperBound(0))]) -Join '\'
                                                             
                                                        ForEach ($OutputObjectValueName In $PropertyList)
                                                          {
                                                              $OutputObjectProperties.$($OutputObjectValueName) = $Null
                                                          }
            
                                                        Switch ($AllProperties.IsPresent)
                                                          {
                                                              {($_ -eq $True)}
                                                                {
                                                                    $ValueNameList = $SubKeyObject.GetValueNames() | Sort-Object
                                                                }

                                                              Default
                                                                {
                                                                    $ValueNameList = $PropertyList
                                                                }
                                                          }
                                                        
                                                        $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Now processing entry `"$($OutputObjectProperties.RegistryPath)`" [ValueCount: $($ValueNameList.Count)]. Please Wait..."
                                                        Write-Verbose -Message ($LoggingDetails.LogMessage)
              
                                                        Switch ($ValueNameList.Count -gt 0)
                                                          {
                                                              {($_ -eq $True)}
                                                                {      
                                                                    For ($ValueNameListIndex = 0; $ValueNameListIndex -lt $ValueNameList.Count; $ValueNameListIndex++)
                                                                      {
                                                                          Try
                                                                            {
                                                                                $ValueName = $ValueNameList[$ValueNameListIndex]
            
                                                                                $ValueKind = $SubKeyObject.GetValueKind($ValueName)
              
                                                                                Switch ($ValueKind)
                                                                                  {
                                                                                      {($_ -ieq 'PlaceHolder')}
                                                                                        {
      
                                                                                        }
      
                                                                                      Default
                                                                                        {
                                                                                            $Value = $SubKeyObject.GetValue($ValueName)
                                                                                        }
                                                                                  }
      
                                                                                $OutputObjectProperties.$($ValueName) = $Value
                                                                            }
                                                                          Catch
                                                                            {
                                                                                $OutputObjectProperties.$($ValueName) = $Null
                                                                            }
                                                                          Finally
                                                                            {
                                                                                
                                                                            }
                                                                      }

                                                                    $ProductCodePropertyList = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                                                      $ProductCodePropertyList.Add('UninstallString')
                                                                      $ProductCodePropertyList.Add('QuietUninstallString')
                                                                      $ProductCodePropertyList.Add('ModifyPath')
                                                                      $ProductCodePropertyList.Add('RegistryLocation')
                                                                      $ProductCodePropertyList.Add('RegistryPath')

                                                                    $OutputObjectProperties.ProductCode = $Null

                                                                    :ProductCodePropertyLoop ForEach ($ProductCodeProperty In $ProductCodePropertyList)
                                                                      {
                                                                          $ProductCodePropertyValue = $OutputObjectProperties.$($ProductCodeProperty)
                                                                          
                                                                          $ProductCodeMatch = [Regex]::Match($ProductCodePropertyValue, $RegularExpressionTable.GUID.ToString(), $RegexOptionList.ToArray())

                                                                          Switch ($ProductCodeMatch.Success)
                                                                            {
                                                                                {($_ -eq $True)}
                                                                                  {
                                                                                      Switch (([String]::IsNullOrEmpty($OutputObjectProperties.ProductCode) -eq $True) -or ([String]::IsNullOrWhiteSpace($OutputObjectProperties.ProductCode) -eq $True))
                                                                                        {
                                                                                            {($_ -eq $True)}
                                                                                              {
                                                                                                  $OutputObjectProperties.ProductCode = Try {"`{$($ProductCodeMatch.Value.Trim().ToUpper() -ireplace '(\{)|(\})', '')`}"} Catch {$Null}                                                                                        
                                                                                      
                                                                                                  Break ProductCodePropertyLoop
                                                                                              }
                                                                                        }  
                                                                                  }
                                                                            }
                                                                      }
                                                                             
                                                                    Switch ($Null -ine $FilterExpression)
                                                                      {
                                                                          {($_ -eq $True)}
                                                                            {
                                                                                $FilterExpressionResult = [Boolean]($OutputObjectProperties | Where-Object -FilterScript $FilterExpression)
                                                                            }

                                                                          Default
                                                                            {
                                                                                $FilterExpressionResult = $True
                                                                            }
                                                                      }
                                                                                                                                        
                                                                    Switch ($FilterExpressionResult)
                                                                      {
                                                                          {($_ -eq $True)}
                                                                            {
                                                                                ForEach ($OutputObjectProperty In ($OutputObjectProperties.Keys | Sort-Object))
                                                                                  {
                                                                                      $OutputObjectPropertyName = $OutputObjectProperty

                                                                                      $OutputObjectPropertyValue = $OutputObjectProperties.$($OutputObjectPropertyName)

                                                                                      Switch ($OutputObjectPropertyName)
                                                                                        {
                                                                                            {($_ -iin @('DisplayVersion'))}
                                                                                              {
                                                                                                  $ParsedVersion = New-Object -TypeName 'System.Version'

                                                                                                  $ParseVersionResult = [Version]::TryParse($OutputObjectPropertyValue, [Ref]$ParsedVersion)

                                                                                                  Switch ($ParseVersionResult)
                                                                                                    {
                                                                                                        {($_ -eq $True)}
                                                                                                          {
                                                                                                              $OutputObjectPropertyValue = $ParsedVersion
                                                                                                          }
                                                                                                    }
                                                                                              }

                                                                                            {($_ -iin @('InstallDate'))}
                                                                                              {
                                                                                                  $DateTime = New-Object -TypeName 'DateTime'

                                                                                                  $DateTimeProperties.Input = $OutputObjectPropertyValue
                                                                                                  $DateTimeProperties.Successful = [DateTime]::TryParseExact($DateTimeProperties.Input, $DateTimeProperties.FormatList, $DateTimeProperties.Culture, $DateTimeProperties.Styles.ToArray(), [Ref]$DateTime)
                                                                                                  $DateTimeProperties.DateTime = $DateTime

                                                                                                  $DateTimeObject = New-Object -TypeName 'PSObject' -Property ($DateTimeProperties)

                                                                                                  Switch ($DateTimeObject.Successful)
                                                                                                    {
                                                                                                        {($_ -eq $True)}
                                                                                                          {
                                                                                                              $OutputObjectPropertyValue = $DateTimeObject.DateTime
                                                                                                          }
                                                                                                    }
                                                                                              }

                                                                                            {($_ -iin @('UninstallString'))}
                                                                                              {
                                                                                                  Switch (([String]::IsNullOrEmpty($OutputObjectPropertyValue) -eq $True) -or ([String]::IsNullOrWhiteSpace($OutputObjectPropertyValue) -eq $True))
                                                                                                    {
                                                                                                        {($_ -eq $True)}
                                                                                                          {
                                                                                                              Switch (([String]::IsNullOrEmpty($OutputObjectProperties.ProductCode) -eq $False) -and ([String]::IsNullOrWhiteSpace($OutputObjectProperties.ProductCode) -eq $False))
                                                                                                                {
                                                                                                                    {($_ -eq $True)}
                                                                                                                      {
                                                                                                                          $OutputObjectPropertyValue = "msiexec.exe /x `"$($OutputObjectProperties.ProductCode)`""
                                                                                                                      }
                                                                                                                }
                                                                                                          }
                                                                                                    }    
                                                                                              }

                                                                                            {($_ -iin @('QuietUninstallString'))}
                                                                                              {
                                                                                                  Switch (([String]::IsNullOrEmpty($OutputObjectPropertyValue) -eq $True) -or ([String]::IsNullOrWhiteSpace($OutputObjectPropertyValue) -eq $True))
                                                                                                    {
                                                                                                        {($_ -eq $True)}
                                                                                                          {
                                                                                                              Switch (([String]::IsNullOrEmpty($OutputObjectProperties.ProductCode) -eq $False) -and ([String]::IsNullOrWhiteSpace($OutputObjectProperties.ProductCode) -eq $False))
                                                                                                                {
                                                                                                                    {($_ -eq $True)}
                                                                                                                      {
                                                                                                                          $OutputObjectPropertyValue = "msiexec.exe /x `"$($OutputObjectProperties.ProductCode)`" /qn /norestart REBOOT=ReallySuppress /L*v `"$($Env:Windir)\Temp\$(($OutputObjectProperties.DisplayName.Split([System.IO.Path]::GetInvalidFileNameChars()) -Join '') -ireplace '(\s+)', '_')_Removal.log`""
                                                                                                                      }
                                                                                                                }
                                                                                                          }
                                                                                                    }    
                                                                                              }

                                                                                            Default
                                                                                              {
                                                                                                  Switch ($OutputObjectPropertyValue)
                                                                                                    {
                                                                                                        {($_ -imatch '(^\d+$)')}
                                                                                                          {
                                                                                                              $OutputObjectPropertyValue = $OutputObjectPropertyValue -As [Int32]
                                                                                                          }
                                                                                                    }
                                                                                              }
                                                                                        }
    
                                                                                      $OutputObjectProperties.Remove($OutputObjectPropertyName)
            
                                                                                      $OutputObjectProperties.$($OutputObjectPropertyName) = $OutputObjectPropertyValue
                                                                                  }
 
                                                                                Switch (($RegistryHivePropertyList.Name -icontains 'NTAccount') -and ($RegistryHivePropertyList.Name -icontains 'SID'))
                                                                                  {
                                                                                      {($_ -eq $True)}
                                                                                        {
                                                                                            $OutputObjectProperties.ProfileNTAccount = $RegistryHive.NTAccount -As [String]
                                                                                            $OutputObjectProperties.ProfileSID = $RegistryHive.SID -As [String]
                                                                                        }

                                                                                      Default
                                                                                        {
                                                                                            $OutputObjectProperties.ProfileNTAccount = $Null -As [String]
                                                                                            $OutputObjectProperties.ProfileSID = $Null -As [String]
                                                                                        }
                                                                                  }

                                                                                $OutputObject = New-Object -TypeName 'PSObject' -Property ($OutputObjectProperties)
                                                                    
                                                                                $OutputObjectList.Add($OutputObject)
                                                                            }
                                                                      }         
                                                                }
                                                          }
      
                                                        Try {$Null = $SubKeyObject.Close()} Catch {}
                                                    }
                                                  Catch
                                                    {
      
                                                    }
                                                  Finally
                                                    {
      
                                                    }     
                                              }
                                        }
                                  }
      
                                Try {$Null = $RegistryKeyObject.Close()} Catch {}
                            }
          
                          Try {$Null = $RegistryHiveObject.Close()} Catch {}
                      }

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Software Detection Filter: $($FilterExpression)"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Found $($OutputObjectList.Count) installed software entries matching the specified criteria."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
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
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose

                  #Log the total script execution time  
                    $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
                  
                    $LoggingDetails.LogMessage = "$($GetCurrentDateTimeMessageFormat.Invoke()) - Function `'$($FunctionName)`' is completed."
                    Write-Verbose -Message ($LoggingDetails.LogMessage) -Verbose
              }
            Catch
              {
                  $ErrorHandlingDefinition.Invoke()
              }
            Finally
              {
                    $OutputObjectList = $OutputObjectList.ToArray()

                    Write-Output -InputObject ($OutputObjectList)
              }
          }
    }
#endregion