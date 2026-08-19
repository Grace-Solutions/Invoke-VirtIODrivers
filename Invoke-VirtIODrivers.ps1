#Requires -Version 5 -Modules Storage

<#
    .SYNOPSIS
    Downloads the latest VirtIO driver ISO and installs the relevant VirtIO drivers for the deployed operating system. Optionally installs the QEMU guest agent within the full operating system.

    .DESCRIPTION
    This script detects the deployed operating system details, downloads the VirtIO driver ISO (only when required), mounts the ISO, and installs the drivers that are relevant to the detected operating system version and processor architecture.

    Within Windows PE, the deployed operating system details are determined by reading the registry hive of the offline operating system volume, and the drivers are injected into the offline operating system using DISM.

    Within the full operating system, the drivers are installed using pnputil, and the QEMU guest agent can optionally be installed directly from the mounted ISO.

    .PARAMETER Install
    Download the VirtIO driver ISO (if required) and install the relevant VirtIO drivers for the deployed operating system.

    .PARAMETER InstallGuestAgent
    Install the QEMU guest agent from the mounted VirtIO driver ISO. This operation is only supported within the full operating system and will be skipped within Windows PE. The installation is also skipped when the installed version is already current, so this switch is safe to specify on every run.

    .PARAMETER DownloadURL
    The URL where the VirtIO driver ISO is located. If this parameter is not specified, the latest stable VirtIO ISO will be downloaded.
    The download is skipped entirely whenever any ISO image already exists within the download destination directory (regardless of its file name), and the latest existing ISO is used instead.

    .PARAMETER DownloadDestinationDirectory
    The directory path where the VirtIO driver ISO will be downloaded to. If this parameter is not specified, the "Content\ISOs" directory located within the script directory will be used.

    .PARAMETER LogDirectory
    A valid folder path. If the folder does not exist, it will be created. This parameter can also be specified by the alias "LogPath".

    .PARAMETER ContinueOnError
    Ignore failures.

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Invoke-VirtIODrivers.ps1" -Install -InstallGuestAgent

    .EXAMPLE
    pwsh.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Invoke-VirtIODrivers.ps1" -Install -InstallGuestAgent

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -NoLogo -WindowStyle Hidden -Command "& '%FolderPathContainingScript%\Invoke-VirtIODrivers.ps1' -Install -InstallGuestAgent -DownloadURL 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso'"

    .NOTES
    Within Windows PE, drivers are injected into the offline operating system using DISM. Within the full operating system, drivers are installed using pnputil.

    During OS deployment scenarios (DeployR, MDT, SCCM), the script runs twice with the same command line ("-Install -InstallGuestAgent"): once within the boot image (Windows PE) and once within the full operating system. The guest agent portion is skipped automatically within Windows PE and when the installed version is already current. OS detection is handled automatically in both passes. DeployR boot images only contain PowerShell 7, so the script must be launched with pwsh.exe there.

    The ISO download automatically detects and uses the system default proxy with default credentials.

    The QEMU guest agent installation requires the Windows Installer service and is therefore only performed within the full operating system.

    .LINK
    https://github.com/virtio-win/virtio-win-pkg-scripts

    .LINK
    https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/
#>

[CmdletBinding(SupportsShouldProcess=$True)]
  Param
    (
        [Parameter(Mandatory=$False)]
        [Alias('I')]
        [Switch]$Install,

        [Parameter(Mandatory=$False)]
        [Alias('IGA', 'IQGA')]
        [Switch]$InstallGuestAgent,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('URI', 'URL', 'DURL')]
        [System.URI]$DownloadURL,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('DDD', 'Destination', 'DownloadDirectory')]
        [System.IO.DirectoryInfo]$DownloadDestinationDirectory,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('LogDir', 'LogPath')]
        [System.IO.DirectoryInfo]$LogDirectory,

        [Parameter(Mandatory=$False)]
        [Switch]$ContinueOnError
    )

Function Test-ProcessElevationStatus
    {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList ($Identity)
        $Result = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

        Write-Output -InputObject ($Result)
    }

Switch (Test-ProcessElevationStatus)
  {
      Default
        {
            Try
              {
                  #region Define Default Action Preferences
                    $Script:InformationPreference = 'Continue'
                    $Script:DebugPreference = 'SilentlyContinue'
                    $Script:ErrorActionPreference = 'Stop'
                    $Script:VerbosePreference = 'SilentlyContinue'
                    $Script:WarningPreference = 'Continue'
                    $Script:ConfirmPreference = 'None'
                    $Script:WhatIfPreference = $False
                  #endregion

                  #region Set the default exit code for the script (By default, the script will exit with an exit code of 0)
                    [System.Environment]::ExitCode = 0
                  #endregion

                  #region Initialize Toolkit (This operation loads functions, modules, and variables into the current session, so if you do not see a variable defined below, it is because it is defined in the Toolkit)
                    Try
                      {
                          [System.IO.FileInfo]$ToolkitScriptPath = "$([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition))\Toolkit\Toolkit.ps1"

                          . "$($ToolkitScriptPath.FullName)" -CallingScriptInvocationInfo ($MyInvocation) -CallingScriptParameterSetName ($PSCmdlet.ParameterSetName)
                      }
                    Catch
                      {
                          [System.Environment]::ExitCode = 6000

                          Throw
                      }
                  #endregion

                  #region Set default parameter values
                    Switch ($True)
                      {
                          {([System.String]::IsNullOrEmpty($DownloadURL) -eq $True) -or ([System.String]::IsNullOrWhiteSpace($DownloadURL) -eq $True)}
                            {
                                [System.URI]$DownloadURL = 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso'
                            }

                          {([System.String]::IsNullOrEmpty($DownloadDestinationDirectory) -eq $True) -or ([System.String]::IsNullOrWhiteSpace($DownloadDestinationDirectory) -eq $True)}
                            {
                                $DownloadDestinationDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ContentDirectory.FullName, 'ISOs')
                            }
                      }
                  #endregion

                  #region Perform Script Actions

                  #region Determine the deployed operating system details
                    Switch ($IsWindowsPE)
                      {
                          {($_ -eq $True)}
                            {
                                $FixedVolumeList = [System.IO.DriveInfo]::GetDrives() | Where-Object {($_.DriveType -iin @('Fixed')) -and ($_.IsReady -eq $True) -and ($_.Name.TrimEnd('\') -inotin @($Env:SystemDrive)) -and (([String]::IsNullOrEmpty($_.Name) -eq $False) -or ([String]::IsNullOrWhiteSpace($_.Name) -eq $False))} | Sort-Object -Property @('TotalSize')

                                :FixedVolumeLoop ForEach ($FixedVolume In $FixedVolumeList)
                                  {
                                      $WriteLogMessage.Invoke(0, @("Attempting to check fixed volume `"$($FixedVolume.Name.TrimEnd('\'))`" for a valid installation of Windows."))

                                      $WindowsDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine("$($FixedVolume.Name.TrimEnd('\'))\", 'Windows')

                                      Switch ([System.IO.Directory]::Exists($WindowsDirectory.FullName))
                                        {
                                            {($_ -eq $True)}
                                              {
                                                  $WindowsDirectoryItemList = Get-ChildItem -Path ($WindowsDirectory.FullName) -ErrorAction SilentlyContinue

                                                  $WindowsDirectoryItemListCount = ($WindowsDirectoryItemList | Measure-Object).Count

                                                  Switch (($WindowsDirectoryItemListCount -ge 2) -and ($WindowsDirectoryItemList | Where-Object {($_.Name -ieq 'explorer.exe')}))
                                                    {
                                                        {($_ -eq $True)}
                                                          {
                                                              $WriteLogMessage.Invoke(0, @("Fixed volume `"$($FixedVolume.Name.TrimEnd('\'))`" contains a valid installation of Windows."))

                                                              $WindowsImageDriveInfo = New-Object -TypeName 'System.IO.DriveInfo' -ArgumentList "$($FixedVolume.Name.TrimEnd('\'))"

                                                              #Read the deployed operating system details from the offline registry hive without mounting it
                                                                $InvokeRegistryHiveActionParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $InvokeRegistryHiveActionParameters.HivePath = [System.IO.FileInfo][System.IO.Path]::Combine("$($WindowsImageDriveInfo.Name.TrimEnd('\').ToUpper())\", 'Windows', 'System32', 'Config', 'SOFTWARE')
                                                                  $InvokeRegistryHiveActionParameters.KeyPath = New-Object -TypeName 'System.Collections.Generic.List[String]'
                                                                    $InvokeRegistryHiveActionParameters.KeyPath.Add('Root\Microsoft\Windows NT\CurrentVersion')
                                                                  $InvokeRegistryHiveActionParameters.ValueNameExpression = New-Object -TypeName 'System.Collections.Generic.List[Regex]'
                                                                    $InvokeRegistryHiveActionParameters.ValueNameExpression.Add('.*')
                                                                  $InvokeRegistryHiveActionParameters.ContinueOnError = $False
                                                                  $InvokeRegistryHiveActionParameters.Verbose = $True

                                                                $InvokeRegistryHiveActionResult = Invoke-RegistryHiveAction @InvokeRegistryHiveActionParameters

                                                                $CurrentVersionValueTable = $InvokeRegistryHiveActionResult[0].ValueTable

                                                                $BuildLabEX = $CurrentVersionValueTable['BuildLabEX'].Value

                                                                $WindowsImageDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                  $WindowsImageDetails.ProductName = $CurrentVersionValueTable['ProductName'].Value
                                                                  $WindowsImageDetails.MajorVersionNumber = $CurrentVersionValueTable['CurrentMajorVersionNumber'].Value
                                                                  $WindowsImageDetails.MinorVersionNumber = $CurrentVersionValueTable['CurrentMinorVersionNumber'].Value
                                                                  $WindowsImageDetails.BuildNumber = $CurrentVersionValueTable['CurrentBuildNumber'].Value
                                                                  $WindowsImageDetails.RevisionNumber = $CurrentVersionValueTable['UBR'].Value
                                                                  $WindowsImageDetails.Version = New-Object -TypeName 'System.Version' -ArgumentList @($WindowsImageDetails.MajorVersionNumber, $WindowsImageDetails.MinorVersionNumber, $WindowsImageDetails.BuildNumber, $WindowsImageDetails.RevisionNumber)
                                                                  $WindowsImageDetails.ReleaseNumber = $CurrentVersionValueTable['ReleaseID'].Value
                                                                  $WindowsImageDetails.ReleaseID = $CurrentVersionValueTable['DisplayVersion'].Value

                                                                Switch ($True)
                                                                  {
                                                                      {($WindowsImageDetails.ProductName -inotmatch '(^.*Server.*$)') -and ($WindowsImageDetails.Version -ge [Version]'10.0.22000.0')}
                                                                        {
                                                                            $WindowsImageDetails.ProductName = $WindowsImageDetails.ProductName.Replace('10', '11')
                                                                        }
                                                                  }

                                                                Switch ($BuildLabEX)
                                                                  {
                                                                      {($_ -imatch '.*amd64.*')}
                                                                        {
                                                                            $WindowsImageDetails.OSArchitecture = 'X64'
                                                                            $WindowsImageDetails.ProcessorArchitecture = 'amd64'
                                                                        }

                                                                      Default
                                                                        {
                                                                            $WindowsImageDetails.OSArchitecture = 'X86'
                                                                            $WindowsImageDetails.ProcessorArchitecture = 'x86'
                                                                        }
                                                                  }

                                                                $WindowsImageDetails.InstallLocation = $WindowsDirectory

                                                              Break FixedVolumeLoop
                                                          }
                                                    }
                                              }
                                        }
                                  }
                            }

                          Default
                            {
                                $WindowsDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine("$($Env:Windir)")

                                #The toolkit stores the operating system version as a string, so it is converted into a version object so that the individual version segments can be extracted
                                  $OperatingSystemVersion = $OperatingSystemDetailsTable.Version -As [System.Version]

                                $WindowsImageDetails = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                  $WindowsImageDetails.ProductName = $OperatingSystem.Caption -ireplace '(?:Microsoft\s+)?', ''
                                  $WindowsImageDetails.MajorVersionNumber = $OperatingSystemVersion.Major
                                  $WindowsImageDetails.MinorVersionNumber = $OperatingSystemVersion.Minor
                                  $WindowsImageDetails.BuildNumber = $OperatingSystemVersion.Build
                                  $WindowsImageDetails.RevisionNumber = $OperatingSystemVersion.Revision
                                  $WindowsImageDetails.Version = $OperatingSystemVersion
                                  $WindowsImageDetails.ReleaseNumber = $OperatingSystemDetailsTable.ReleaseVersion
                                  $WindowsImageDetails.ReleaseID = $OperatingSystemDetailsTable.ReleaseID
                                  $WindowsImageDetails.OSArchitecture = $OperatingSystemDetailsTable.Architecture
                                  $WindowsImageDetails.ProcessorArchitecture = $Env:PROCESSOR_ARCHITECTURE
                                  $WindowsImageDetails.InstallLocation = $WindowsDirectory
                            }
                      }

                    Switch ($Null -ieq $WindowsImageDetails)
                      {
                          {($_ -eq $True)}
                            {
                                $WriteLogMessage.Invoke(2, @("Unable to determine the deployed operating system details. No further action will be taken."))

                                Throw "Unable to determine the deployed operating system details."
                            }
                      }

                    ForEach ($WindowsImageDetail In $WindowsImageDetails.GetEnumerator())
                      {
                          $WriteLogMessage.Invoke(0, @("Deployed Operating System - $($WindowsImageDetail.Key): $($WindowsImageDetail.Value)"))
                      }
                  #endregion

                  #region Determine whether the VirtIO driver ISO is required
                    $DriverInstallationRequired = ($Install.IsPresent -eq $True)

                    $GuestAgentInstallationRequired = ($InstallGuestAgent.IsPresent -eq $True) -and ($IsWindowsPE -eq $False)

                    Switch ($True)
                      {
                          {($InstallGuestAgent.IsPresent -eq $True) -and ($IsWindowsPE -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("The QEMU guest agent installation will be skipped because it is not supported within Windows PE."))
                            }
                      }

                    $ISORequired = ($DriverInstallationRequired -eq $True) -or ($GuestAgentInstallationRequired -eq $True)
                  #endregion

                  #region Download, mount, and process the VirtIO driver ISO
                    Switch ($ISORequired)
                      {
                          {($_ -eq $True)}
                            {
                                #region Stage the ISO (Any existing ISO within the download destination directory is used as-is regardless of its file name, otherwise the ISO is downloaded)
                                  $ExistingISOList = Get-ChildItem -Path ($DownloadDestinationDirectory.FullName) -Filter '*.iso' -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])}

                                  $ExistingISOListCount = ($ExistingISOList | Measure-Object).Count

                                  Switch ($ExistingISOListCount -gt 0)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $StagedISOPath = $ExistingISOList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -First 1

                                              $WriteLogMessage.Invoke(0, @("Found $($ExistingISOListCount) existing ISO image(s) within `"$($DownloadDestinationDirectory.FullName)`". The download will be skipped.", "Latest Existing ISO Image: $($StagedISOPath.FullName)"))
                                          }

                                        Default
                                          {
                                              $InvokeFileDownloadWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                $InvokeFileDownloadWithProgressParameters.URL = $DownloadURL
                                                $InvokeFileDownloadWithProgressParameters.Destination = $DownloadDestinationDirectory.FullName
                                                $InvokeFileDownloadWithProgressParameters.FileName = [System.IO.Path]::GetFileName($DownloadURL.OriginalString)
                                                $InvokeFileDownloadWithProgressParameters.ContinueOnError = $False
                                                $InvokeFileDownloadWithProgressParameters.Verbose = $True

                                              $InvokeFileDownloadWithProgressResult = Invoke-FileDownloadWithProgress @InvokeFileDownloadWithProgressParameters

                                              $StagedISOPath = $InvokeFileDownloadWithProgressResult.DownloadPath
                                          }
                                    }
                                #endregion

                                #region Copy the downloaded ISO file locally if a UNC path is detected, in order to avoid file lock issues
                                  $ISOSearchDirectoryList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.DirectoryInfo]'

                                  Switch ($DownloadDestinationDirectory.FullName.StartsWith('\\'))
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $WriteLogMessage.Invoke(0, @("A UNC path was detected for the download destination directory. Attempting to copy the downloaded file locally. Please Wait..."))

                                              $CopyItemWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                $CopyItemWithProgressParameters.Path = $StagedISOPath.FullName
                                                $CopyItemWithProgressParameters.Destination = [System.IO.Path]::Combine($WindowsImageDetails.InstallLocation.FullName, 'Temp', 'ISOs')
                                                $CopyItemWithProgressParameters.Include = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                  $CopyItemWithProgressParameters.Include.Add('*.iso')
                                                $CopyItemWithProgressParameters.Force = $True
                                                $CopyItemWithProgressParameters.SegmentSize = 16384
                                                $CopyItemWithProgressParameters.ContinueOnError = $False
                                                $CopyItemWithProgressParameters.Verbose = $True
                                                $CopyItemWithProgressParameters.ErrorAction = [System.Management.Automation.ActionPreference]::Stop

                                              $CopyItemWithProgressResult = Copy-ItemWithProgress @CopyItemWithProgressParameters

                                              $ISOSearchDirectoryList.Add($CopyItemWithProgressResult[0].Destination.Directory.FullName)
                                          }

                                        Default
                                          {
                                              $ISOSearchDirectoryList.Add($DownloadDestinationDirectory.FullName)
                                          }
                                    }
                                #endregion

                                #region Locate and mount the latest available ISO image (Extracting the ISO file for distribution has too much of a processing cost)
                                  $WriteLogMessage.Invoke(0, @("Attempting to get a list of available ISO image(s). Please Wait..."))

                                  $ISOSearchDirectoryListCounter = 1

                                  ForEach ($ISOSearchDirectory In $ISOSearchDirectoryList)
                                    {
                                        $WriteLogMessage.Invoke(0, @("Directory #$($ISOSearchDirectoryListCounter.ToString('00')): $($ISOSearchDirectory.FullName)"))

                                        $ISOSearchDirectoryListCounter++
                                    }

                                  $ISOList = Get-ChildItem -Path ($ISOSearchDirectoryList.ToArray().FullName) -Filter '*.iso' -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])}

                                  $ISOListCount = ($ISOList | Measure-Object).Count

                                  $WriteLogMessage.Invoke(0, @("Found $($ISOListCount) ISO image(s)."))

                                  Switch ($ISOListCount -gt 0)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $ISO = $ISOList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -First 1

                                              $WriteLogMessage.Invoke(0, @("Latest Available ISO Image: $($ISO.FullName)"))

                                              $ISOImageInfo = Get-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO

                                              Switch ($ISOImageInfo.Attached)
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("The specified ISO image has already been mounted. Skipping operation."))
                                                      }

                                                    {($_ -eq $False)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("The specified ISO image requires mounting. Please Wait..."))

                                                          $ISOImageInfo = Mount-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO -Access ReadOnly -PassThru
                                                      }
                                                }

                                              $WriteLogMessage.Invoke(0, @("Attempting to get the volume information for the mounted ISO image. Please Wait..."))

                                              $ISOImageVolume = $ISOImageInfo | Get-Volume

                                              Switch (([String]::IsNullOrEmpty($ISOImageVolume.DriveLetter) -eq $False) -and ([String]::IsNullOrWhiteSpace($ISOImageVolume.DriveLetter) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("Mounted ISO Image Volume Letter: $($ISOImageVolume.DriveLetter)"))

                                                          Try
                                                            {
                                                                #region Install the relevant VirtIO drivers
                                                                  Switch ($DriverInstallationRequired)
                                                                    {
                                                                        {($_ -eq $True)}
                                                                          {
                                                                              #Get the operating system caption alias in order to determine the relevant driver folder(s)
                                                                                $RegularExpression = '(?:Microsoft)?(?:\s+)?(?:Windows)?(?:\s+)?(?<OSReleaseType>Server|)?(?:\s+)?(?<OSReleaseVersion>\d+|\d+\.\d+)?(?:\s+)?(?<OSReleaseNumber>R\d+)?(?:\s+)?(?<OSReleaseEdition>.+)?'

                                                                                $RegularExpressionObject = New-Object -TypeName 'System.Text.RegularExpressions.Regex' -ArgumentList ($RegularExpression, $RegexOptionList)

                                                                                Switch ($RegularExpressionObject.IsMatch($WindowsImageDetails.ProductName))
                                                                                  {
                                                                                      {($_ -eq $True)}
                                                                                        {
                                                                                            $RegularExpressionObjectResult = $RegularExpressionObject.Match($WindowsImageDetails.ProductName)

                                                                                            $RegularExpressionGroupList = $RegularExpressionObjectResult.Groups

                                                                                            Switch ($WindowsImageDetails.ProductName)
                                                                                              {
                                                                                                  {($_ -imatch '(^.*Server.*$)')}
                                                                                                    {
                                                                                                        [String]$OSReleaseNumber = $RegularExpressionGroupList['OSReleaseNumber'].Value

                                                                                                        [String]$OSReleaseVersion = $RegularExpressionGroupList['OSReleaseVersion'].Value

                                                                                                        [String]$OSReleaseVersion = $OSReleaseVersion.Substring($OSReleaseVersion.Length - 2).TrimStart('0')

                                                                                                        Switch (([String]::IsNullOrEmpty($OSReleaseNumber) -eq $False) -and ([String]::IsNullOrWhiteSpace($OSReleaseNumber) -eq $False))
                                                                                                          {
                                                                                                              {($_ -eq $True)}
                                                                                                                {
                                                                                                                    $OSCaptionAlias = "2k$($OSReleaseVersion)$($OSReleaseNumber)"
                                                                                                                }

                                                                                                              Default
                                                                                                                {
                                                                                                                    $OSCaptionAlias = "2k$($OSReleaseVersion)"
                                                                                                                }
                                                                                                          }
                                                                                                    }

                                                                                                  Default
                                                                                                    {
                                                                                                        $OSReleaseVersion = $RegularExpressionGroupList['OSReleaseVersion'].Value

                                                                                                        $OSCaptionAlias = "w$($OSReleaseVersion)"
                                                                                                    }
                                                                                              }

                                                                                            $WriteLogMessage.Invoke(0, @("Attempting to search for relevant driver folder(s) located within `"$($ISOImageVolume.DriveLetter):\`". Please Wait..."))

                                                                                            $WriteLogMessage.Invoke(0, @("Operating System Caption: $($WindowsImageDetails.ProductName)", "Operating System Caption Alias: $($OSCaptionAlias)", "Operating System Processor Architecture: $($WindowsImageDetails.ProcessorArchitecture)"))

                                                                                            $VirtIODriverFolderList = Get-ChildItem -Path "$($ISOImageVolume.DriveLetter):\*" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.DirectoryInfo]) -and ($_.FullName -imatch ".*$($OSCaptionAlias).*") -and ($_.FullName -imatch ".*$($WindowsImageDetails.ProcessorArchitecture).*")}

                                                                                            $VirtIODriverFolderListCount = ($VirtIODriverFolderList | Measure-Object).Count

                                                                                            $WriteLogMessage.Invoke(0, @("Located $($VirtIODriverFolderListCount) relevant driver folder(s) within volume `"$($ISOImageVolume.DriveLetter):\`"."))

                                                                                            Switch ($VirtIODriverFolderListCount -gt 0)
                                                                                              {
                                                                                                  {($_ -eq $True)}
                                                                                                    {
                                                                                                        $DISMLogRootDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($LogDirectory.FullName, 'WindowsPE', 'DISM')

                                                                                                        Switch ($True)
                                                                                                          {
                                                                                                              {($IsWindowsPE -eq $True) -and ([System.IO.Directory]::Exists($DISMLogRootDirectory.FullName) -eq $False)}
                                                                                                                {
                                                                                                                    $Null = [System.IO.Directory]::CreateDirectory($DISMLogRootDirectory.FullName)
                                                                                                                }
                                                                                                          }

                                                                                                        $VirtIODriverFolderListCounter = 1

                                                                                                        For ($VirtIODriverFolderListIndex = 0; $VirtIODriverFolderListIndex -lt $VirtIODriverFolderListCount; $VirtIODriverFolderListIndex++)
                                                                                                          {
                                                                                                              $VirtIODriverFolder = $VirtIODriverFolderList[$VirtIODriverFolderListIndex]

                                                                                                              Switch ($IsWindowsPE)
                                                                                                                {
                                                                                                                    {($_ -eq $True)}
                                                                                                                      {
                                                                                                                          $DISMLogPath = [System.IO.FileInfo][System.IO.Path]::Combine($DISMLogRootDirectory.FullName, "AddDrivers_VirtIO_Folder_$($VirtIODriverFolderListCounter.ToString('00')).log")

                                                                                                                          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                                            $StartProcessWithOutputParameters.FilePath = 'dism.exe'
                                                                                                                            $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add('/Add-Driver')
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add("/Image:$($WindowsImageDetails.InstallLocation.Root.FullName.TrimEnd('\'))")
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add("/Driver:`"$($VirtIODriverFolder.FullName)`"")
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add('/Recurse')
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add('/LogLevel:3')
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add("/LogPath:`"$($DISMLogPath.FullName)`"")
                                                                                                                            $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('2')
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('50')
                                                                                                                            $StartProcessWithOutputParameters.CreateNoWindow = $True
                                                                                                                            $StartProcessWithOutputParameters.ExecutionTimeout = [System.TimeSpan]::FromMinutes(15)
                                                                                                                            $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(5)
                                                                                                                            $StartProcessWithOutputParameters.LogOutput = $True
                                                                                                                            $StartProcessWithOutputParameters.ContinueOnError = $False
                                                                                                                            $StartProcessWithOutputParameters.Verbose = $True
                                                                                                                      }

                                                                                                                    Default
                                                                                                                      {
                                                                                                                          $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                                            $StartProcessWithOutputParameters.FilePath = 'pnputil.exe'
                                                                                                                            $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add('/add-driver')
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add("`"$($VirtIODriverFolder.FullName)\*.inf`"")
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add('/subdirs')
                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add('/install')
                                                                                                                            $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('259')
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('3010')
                                                                                                                              $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('1641')
                                                                                                                            $StartProcessWithOutputParameters.CreateNoWindow = $True
                                                                                                                            $StartProcessWithOutputParameters.ExecutionTimeout = [System.TimeSpan]::FromMinutes(5)
                                                                                                                            $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(2)
                                                                                                                            $StartProcessWithOutputParameters.LogOutput = $True
                                                                                                                            $StartProcessWithOutputParameters.ContinueOnError = $False
                                                                                                                            $StartProcessWithOutputParameters.Verbose = $True
                                                                                                                      }
                                                                                                                }

                                                                                                              $WriteLogMessage.Invoke(0, @("Attempting to install the driver(s) located within driver folder #$($VirtIODriverFolderListCounter.ToString('00')). Please Wait...", "Path: $($VirtIODriverFolder.FullName)"))

                                                                                                              $ProgressPercentage = [System.Math]::Round((($VirtIODriverFolderListCounter / $VirtIODriverFolderListCount) * 100), 2)

                                                                                                              $ProgressActivity = "Installing drivers from folder $($VirtIODriverFolderListCounter) of $($VirtIODriverFolderListCount). Please Wait... [Path: $($VirtIODriverFolder.FullName)]"

                                                                                                              $WriteProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                                $WriteProgressParameters.Activity = $ProgressActivity
                                                                                                                $WriteProgressParameters.Status = "Progress Percentage: $($ProgressPercentage)%"
                                                                                                                $WriteProgressParameters.PercentComplete = $ProgressPercentage
                                                                                                                $WriteProgressParameters.CurrentOperation = $VirtIODriverFolder.FullName

                                                                                                              Switch ($IsRunningTaskSequence)
                                                                                                                {
                                                                                                                    {($_ -eq $True)}
                                                                                                                      {
                                                                                                                          $WriteProgressParameters.Status = $WriteProgressParameters.Activity
                                                                                                                      }

                                                                                                                    Default
                                                                                                                      {
                                                                                                                          $WriteProgressParameters.Status = $WriteProgressParameters.CurrentOperation
                                                                                                                      }
                                                                                                                }

                                                                                                              Write-Progress @WriteProgressParameters

                                                                                                              $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                                                                                              $WriteProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                                $WriteProgressParameters.Activity = $ProgressActivity
                                                                                                                $WriteProgressParameters.Completed = $True

                                                                                                              Write-Progress @WriteProgressParameters

                                                                                                              $VirtIODriverFolderListCounter++
                                                                                                          }
                                                                                                    }
                                                                                              }
                                                                                        }

                                                                                      Default
                                                                                        {
                                                                                            $WriteLogMessage.Invoke(2, @("The operating system caption does not meet the specified regular expression.", "Operating System Caption: $($WindowsImageDetails.ProductName)", "Regular Expression: $($RegularExpression)"))
                                                                                        }
                                                                                  }
                                                                          }

                                                                        Default
                                                                          {
                                                                              $WriteLogMessage.Invoke(0, @("The `"-Install`" parameter was not specified. The VirtIO driver installation will be skipped."))
                                                                          }
                                                                    }
                                                                #endregion

                                                                #region Install the QEMU guest agent (Full operating system only)
                                                                  Switch ($GuestAgentInstallationRequired)
                                                                    {
                                                                        {($_ -eq $True)}
                                                                          {
                                                                              $WriteLogMessage.Invoke(0, @("Attempting to locate the QEMU guest agent installer within the mounted ISO image. Please Wait..."))

                                                                              Switch ($WindowsImageDetails.ProcessorArchitecture)
                                                                                {
                                                                                    {($_ -imatch '(^amd64$)|(^x64$)')}
                                                                                      {
                                                                                          [String]$GuestAgentMSIName = 'qemu-ga-x86_64.msi'
                                                                                      }

                                                                                    Default
                                                                                      {
                                                                                          [String]$GuestAgentMSIName = 'qemu-ga-i386.msi'
                                                                                      }
                                                                                }

                                                                              $GuestAgentMSIPath = [System.IO.FileInfo][System.IO.Path]::Combine("$($ISOImageVolume.DriveLetter):\", 'guest-agent', $GuestAgentMSIName)

                                                                              Switch ([System.IO.File]::Exists($GuestAgentMSIPath.FullName))
                                                                                {
                                                                                    {($_ -eq $True)}
                                                                                      {
                                                                                          $WriteLogMessage.Invoke(0, @("QEMU Guest Agent Installer Path: $($GuestAgentMSIPath.FullName)"))

                                                                                          #Determine the product details of the QEMU guest agent installer
                                                                                            $GetMSIPropertyListParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                              $GetMSIPropertyListParameters.Path = $GuestAgentMSIPath.FullName

                                                                                            $GetMSIPropertyListResult = Get-MSIPropertyList @GetMSIPropertyListParameters

                                                                                            $GuestAgentMSIProductName = $GetMSIPropertyListResult[0].ProductName
                                                                                            $GuestAgentMSIProductVersion = $GetMSIPropertyListResult[0].ProductVersion -As [System.Version]

                                                                                            $WriteLogMessage.Invoke(0, @("QEMU Guest Agent Installer Product Name: $($GuestAgentMSIProductName)", "QEMU Guest Agent Installer Product Version: $($GuestAgentMSIProductVersion)"))

                                                                                          #Determine whether the QEMU guest agent is already installed
                                                                                            $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                              $GetInstalledSoftwareParameters.FilterExpression = {($_.DisplayName -imatch '(^QEMU\s+guest\s+agent.*$)')}
                                                                                              $GetInstalledSoftwareParameters.ContinueOnError = $True
                                                                                              $GetInstalledSoftwareParameters.Verbose = $False

                                                                                            $GetInstalledSoftwareResult = Get-InstalledSoftware @GetInstalledSoftwareParameters

                                                                                            $InstalledGuestAgent = $GetInstalledSoftwareResult | Select-Object -First 1

                                                                                            $InstalledGuestAgentVersion = $InstalledGuestAgent.DisplayVersion -As [System.Version]

                                                                                          #Determine whether the QEMU guest agent installation is necessary
                                                                                            Switch ($True)
                                                                                              {
                                                                                                  {($Null -ieq $InstalledGuestAgent)}
                                                                                                    {
                                                                                                        $WriteLogMessage.Invoke(0, @("The QEMU guest agent is not installed. An installation is necessary."))

                                                                                                        [Boolean]$GuestAgentInstallationNecessary = $True

                                                                                                        Break
                                                                                                    }

                                                                                                  {($Null -ieq $InstalledGuestAgentVersion) -or ($Null -ieq $GuestAgentMSIProductVersion)}
                                                                                                    {
                                                                                                        $WriteLogMessage.Invoke(2, @("Unable to compare the installed QEMU guest agent version against the installer version. An installation will be attempted.", "Installed Version: $($InstalledGuestAgent.DisplayVersion)", "Installer Version: $($GetMSIPropertyListResult[0].ProductVersion)"))

                                                                                                        [Boolean]$GuestAgentInstallationNecessary = $True

                                                                                                        Break
                                                                                                    }

                                                                                                  {($InstalledGuestAgentVersion -lt $GuestAgentMSIProductVersion)}
                                                                                                    {
                                                                                                        $WriteLogMessage.Invoke(0, @("The installed QEMU guest agent version is older than the installer version. An installation is necessary.", "Installed Version: $($InstalledGuestAgentVersion)", "Installer Version: $($GuestAgentMSIProductVersion)"))

                                                                                                        [Boolean]$GuestAgentInstallationNecessary = $True

                                                                                                        Break
                                                                                                    }

                                                                                                  Default
                                                                                                    {
                                                                                                        $WriteLogMessage.Invoke(0, @("The installed QEMU guest agent version is already current. The installation will be skipped.", "Installed Version: $($InstalledGuestAgentVersion)", "Installer Version: $($GuestAgentMSIProductVersion)"))

                                                                                                        [Boolean]$GuestAgentInstallationNecessary = $False
                                                                                                    }
                                                                                              }

                                                                                          #Install the QEMU guest agent (If necessary)
                                                                                            Switch ($GuestAgentInstallationNecessary)
                                                                                              {
                                                                                                  {($_ -eq $True)}
                                                                                                    {
                                                                                                        $GuestAgentLogDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($LogDirectory.FullName, 'QEMUGuestAgent')

                                                                                                        Switch ([System.IO.Directory]::Exists($GuestAgentLogDirectory.FullName))
                                                                                                          {
                                                                                                              {($_ -eq $False)}
                                                                                                                {
                                                                                                                    $Null = [System.IO.Directory]::CreateDirectory($GuestAgentLogDirectory.FullName)
                                                                                                                }
                                                                                                          }

                                                                                                        $GuestAgentInstallLogPath = [System.IO.FileInfo][System.IO.Path]::Combine($GuestAgentLogDirectory.FullName, "Install_QEMUGuestAgent_$($GetCurrentDateTimeFileFormat.Invoke()).log")

                                                                                                        $WriteLogMessage.Invoke(0, @("Attempting to install the QEMU guest agent. Please Wait...", "Installation Log Path: $($GuestAgentInstallLogPath.FullName)"))

                                                                                                        $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                                                          $StartProcessWithOutputParameters.FilePath = 'msiexec.exe'
                                                                                                          $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add('/i')
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add("`"$($GuestAgentMSIPath.FullName)`"")
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add('/qn')
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add('/norestart')
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add('REBOOT=ReallySuppress')
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add('/l*v')
                                                                                                            $StartProcessWithOutputParameters.ArgumentList.Add("`"$($GuestAgentInstallLogPath.FullName)`"")
                                                                                                          $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                                                            $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                                                                            $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('3010')
                                                                                                            $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('1641')
                                                                                                          $StartProcessWithOutputParameters.CreateNoWindow = $True
                                                                                                          $StartProcessWithOutputParameters.ExecutionTimeout = [System.TimeSpan]::FromMinutes(10)
                                                                                                          $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(5)
                                                                                                          $StartProcessWithOutputParameters.LogOutput = $True
                                                                                                          $StartProcessWithOutputParameters.ContinueOnError = $False
                                                                                                          $StartProcessWithOutputParameters.Verbose = $True

                                                                                                        $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                                                                                        #Verify the state of the QEMU guest agent service
                                                                                                          $GuestAgentService = Get-Service | Where-Object {($_.Name -imatch '(^QEMU\-GA$)') -or ($_.DisplayName -imatch '(^QEMU\s+Guest\s+Agent.*$)')} | Select-Object -First 1

                                                                                                          Switch ($Null -ine $GuestAgentService)
                                                                                                            {
                                                                                                                {($_ -eq $True)}
                                                                                                                  {
                                                                                                                      $WriteLogMessage.Invoke(0, @("QEMU Guest Agent Service Name: $($GuestAgentService.Name)", "QEMU Guest Agent Service Display Name: $($GuestAgentService.DisplayName)", "QEMU Guest Agent Service Status: $($GuestAgentService.Status)"))
                                                                                                                  }

                                                                                                                Default
                                                                                                                  {
                                                                                                                      $WriteLogMessage.Invoke(2, @("The QEMU guest agent service could not be found following the installation."))
                                                                                                                  }
                                                                                                            }
                                                                                                    }
                                                                                              }
                                                                                      }

                                                                                    Default
                                                                                      {
                                                                                          $WriteLogMessage.Invoke(2, @("The QEMU guest agent installer could not be located within the mounted ISO image. The installation will be skipped.", "Expected Path: $($GuestAgentMSIPath.FullName)"))
                                                                                      }
                                                                                }
                                                                          }
                                                                    }
                                                                #endregion
                                                            }
                                                          Finally
                                                            {
                                                                #region Dismount the previously mounted ISO image
                                                                  $ISOImageInfo = Get-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO

                                                                  Switch ($ISOImageInfo.Attached)
                                                                    {
                                                                        {($_ -eq $True)}
                                                                          {
                                                                              $WriteLogMessage.Invoke(0, @("Attempting to dismount the previously mounted ISO image. Please Wait...", "ISO Image Path: $($ISO.FullName)"))

                                                                              $Null = Try {Dismount-DiskImage -ImagePath ($ISO.FullName) -StorageType ISO} Catch {}
                                                                          }
                                                                    }
                                                                #endregion
                                                            }
                                                      }

                                                    Default
                                                      {
                                                          $WriteLogMessage.Invoke(2, @("Unable to get the volume information for the mounted ISO image. No further action will be taken."))
                                                      }
                                                }
                                          }
                                    }
                                #endregion
                            }

                          Default
                            {
                                $WriteLogMessage.Invoke(0, @("Neither the `"-Install`" nor the `"-InstallGuestAgent`" parameter was specified. No further action will be taken."))
                            }
                      }
                  #endregion

                  #endregion
              }
            Catch
              {
                  #region Perform error handling actions
                    $ErrorHandlingDefinition.Invoke($Error[0], 2, $ContinueOnError.IsPresent)
                  #endregion
              }
            Finally
              {
                  #region Perform finalization actions
                    $FinalizationActions.Invoke()
                  #endregion
              }
        }

      {($_ -eq $False)}
        {
            [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Definition)"

            $CurrentExecutionPolicy = 'Bypass'

            $ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[String]'
              $ArgumentList.Add("-ExecutionPolicy $($CurrentExecutionPolicy)")
              $ArgumentList.Add('-NonInteractive')
              $ArgumentList.Add('-NoProfile')
              $ArgumentList.Add('-NoLogo')
              $ArgumentList.Add('-NoExit')
              $ArgumentList.Add('-Command')
              $ArgumentList.Add("`"`& {. `"$($ScriptPath.FullName)`"")

            $MyInvocation.UnboundArguments.GetEnumerator() | ForEach-Object {$ArgumentList.Add("-$($_.Key) @($($_.Value | ForEach-Object {`"$($_)`"}))")}

            $PSBoundParameters.GetEnumerator() | ForEach-Object {$ArgumentList.Add("-$($_.Key) @($($_.Value | ForEach-Object {`"$($_)`"}))")}

            $ArgumentListTargetIndex = $ArgumentList.Count - 1

            $ArgumentListIndexItem = $ArgumentList[$ArgumentListTargetIndex]

            $Null = $ArgumentList.RemoveAt($ArgumentListTargetIndex)

            $Null = $ArgumentList.Insert($ArgumentListTargetIndex, ($ArgumentListIndexItem + ';'))

            $ArgumentList.Add("[System.Environment]::Exit((`$LASTEXITCODE -Bor [Int](-Not `$? -And -Not `$LASTEXITCODE)))}`"")

            $ScriptInterpreterList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
              $ScriptInterpreterList.Add('powershell.exe')
              $ScriptInterpreterList.Add('pwsh.exe')

            :ScriptInterpreterListLoop ForEach ($ScriptInterpreter In $ScriptInterpreterList)
              {
                  $ScriptInterpreterObject = Try {Get-Command -Name ($ScriptInterpreter) -ErrorAction SilentlyContinue} Catch {$Null}

                  Switch ($Null -ine $ScriptInterpreterObject)
                    {
                        {($_ -eq $True)}
                          {
                              $Null = Start-Process -FilePath ($ScriptInterpreterObject.Path) -WorkingDirectory "$($Env:Temp.TrimEnd('\'))" -ArgumentList ($ArgumentList.ToArray()) -WindowStyle Normal -Verb RunAs -PassThru

                              Break ScriptInterpreterListLoop
                          }
                    }
              }
        }
  }
