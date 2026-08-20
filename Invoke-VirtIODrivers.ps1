#Requires -Version 5

<#
    .SYNOPSIS
    Downloads the latest VirtIO driver ISO and installs the relevant VirtIO drivers for the deployed operating system. Optionally installs the QEMU guest agent within the full operating system.

    .DESCRIPTION
    This script detects the deployed operating system details, downloads the VirtIO driver ISO (only when required), mounts the ISO, and installs the drivers that are relevant to the detected operating system version and processor architecture.

    Within Windows PE, the deployed operating system details are determined by reading the registry hive of the offline operating system volume, and the drivers are injected into the offline operating system using DISM.

    Within the full operating system, the drivers are installed using pnputil, and the QEMU guest agent can optionally be installed directly from the mounted ISO. The SPICE guest tools can also optionally be downloaded and installed.

    .PARAMETER Install
    Download the VirtIO driver ISO (if required) and install the relevant VirtIO drivers for the deployed operating system.

    .PARAMETER InstallGuestAgent
    Install the QEMU guest agent from the mounted VirtIO driver ISO. This operation is only supported within the full operating system and will be skipped within Windows PE. The installation is also skipped when the installed version is already current, so this switch is safe to specify on every run.

    .PARAMETER InstallSpiceGuestTools
    Install the SPICE guest tools. The installer is downloaded separately because it is not included within the VirtIO driver ISO.
    Before the silent installation is performed, the driver signing certificate(s) found within the VirtIO driver ISO catalog files are imported into the local machine trusted publishers store, so that the bundled driver installations do not produce prompts.
    This operation is only supported within the full operating system and will be skipped within Windows PE. The installation is also skipped when the SPICE guest tools are already installed, so this switch is safe to specify on every run.

    .PARAMETER SpiceGuestToolsDownloadURL
    The URL where the SPICE guest tools installer is located. If this parameter is not specified, the latest SPICE guest tools installer will be downloaded.
    The download is skipped entirely whenever an installer already exists within the destination directory.

    .PARAMETER SpiceGuestToolsDestinationDirectory
    The directory path where the SPICE guest tools installer will be downloaded to. If this parameter is not specified, the "Installers" directory located within the local download directory ("%WinDir%\Temp\<ScriptBaseName>") will be used.

    .PARAMETER ArchiveUtilityDownloadURL
    The URL where the archive utility is located. The archive utility is required in order to read the driver catalogs contained within the SPICE guest tools installer.
    An existing copy is always preferred, and is located by searching the "Toolkit\Tools\<ProcessorArchitecture>" directories, the "Toolkit\Tools\All" directory, and then the "Tools\<ProcessorArchitecture>" directories located within the local download directory ("%WinDir%\Temp\<ScriptBaseName>"). The download only occurs when an existing copy could not be located, and the downloaded package is expanded using an administrative installation so that the product itself is never installed.

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

    The SPICE guest tools installation is likewise only performed within the full operating system.

    The SPICE guest tools installer is not digitally signed and exposes no version resource, therefore the driver signing certificate(s) are read from the driver catalog files contained within the installer itself. The installer is expanded using an archive utility, every distinct signing certificate is imported into the local machine trusted publishers store, and the expanded content is then removed. This suppresses the driver installation prompts that would otherwise require user interaction.

    The archive utility is located within the "Toolkit\Tools\<ProcessorArchitecture>" directories (for example "X64" followed by "AMD64"), the "Toolkit\Tools\All" directory, and then within the local download directory. An existing copy is always preferred so that a download is avoided, and the download only occurs when no existing copy is present.

    Anything that is downloaded at runtime is written beneath "%WinDir%\Temp\<ScriptBaseName>".

    The SPICE guest tools installer is executed using its own normal installation method so that its standard behavior is preserved.

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
        [Alias('ISGT', 'Spice')]
        [Switch]$InstallSpiceGuestTools,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('SGTURL')]
        [System.URI]$SpiceGuestToolsDownloadURL,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('SGTDD')]
        [System.IO.DirectoryInfo]$SpiceGuestToolsDestinationDirectory,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [Alias('AUURL')]
        [System.URI]$ArchiveUtilityDownloadURL,

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
                    $LocalDownloadDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($Env:Windir, 'Temp', "$($CallingScriptPath.BaseName)")

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

                          {([System.String]::IsNullOrEmpty($SpiceGuestToolsDownloadURL) -eq $True) -or ([System.String]::IsNullOrWhiteSpace($SpiceGuestToolsDownloadURL) -eq $True)}
                            {
                                [System.URI]$SpiceGuestToolsDownloadURL = 'https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe'
                            }

                          {([System.String]::IsNullOrEmpty($SpiceGuestToolsDestinationDirectory) -eq $True) -or ([System.String]::IsNullOrWhiteSpace($SpiceGuestToolsDestinationDirectory) -eq $True)}
                            {
                                $SpiceGuestToolsDestinationDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($LocalDownloadDirectory.FullName, 'Installers')
                            }

                          {([System.String]::IsNullOrEmpty($ArchiveUtilityDownloadURL) -eq $True) -or ([System.String]::IsNullOrWhiteSpace($ArchiveUtilityDownloadURL) -eq $True)}
                            {
                                [System.URI]$ArchiveUtilityDownloadURL = 'https://www.7-zip.org/a/7z2409-x64.msi'
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

                    $SpiceGuestToolsInstallationRequired = ($InstallSpiceGuestTools.IsPresent -eq $True) -and ($IsWindowsPE -eq $False)

                    Switch ($True)
                      {
                          {($InstallGuestAgent.IsPresent -eq $True) -and ($IsWindowsPE -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("The QEMU guest agent installation will be skipped because it is not supported within Windows PE."))
                            }

                          {($InstallSpiceGuestTools.IsPresent -eq $True) -and ($IsWindowsPE -eq $True)}
                            {
                                $WriteLogMessage.Invoke(0, @("The SPICE guest tools installation will be skipped because it is not supported within Windows PE."))
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

                                              #The disk image cmdlets are projected directly from the storage CIM provider so that the Storage module is not required (It is not present within every Windows PE boot image)
                                                [System.IO.FileInfo]$DiskImageDefinitionPath = [System.IO.Path]::Combine($ToolkitScriptDirectory.FullName, 'Libraries', 'Storage', 'DiskImage.cdxml')

                                                $Null = Import-Module -Name ($DiskImageDefinitionPath.FullName) -Force -DisableNameChecking -Verbose:$False

                                              #The storage type value of 1 represents an ISO image and the access value of 3 represents read only access
                                                $ISOImageInfo = Get-ToolkitDiskImage -ImagePath ($ISO.FullName) -StorageType 1

                                              Switch ($ISOImageInfo.Attached)
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("The specified ISO image has already been mounted. Skipping operation."))
                                                      }

                                                    {($_ -eq $False)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("The specified ISO image requires mounting. Please Wait..."))

                                                          $ISOImageInfo = Mount-ToolkitDiskImage -ImagePath ($ISO.FullName) -StorageType 1 -Access 3 -PassThru
                                                      }
                                                }

                                              $WriteLogMessage.Invoke(0, @("Attempting to get the volume information for the mounted ISO image. Please Wait..."))

                                              $ISOImageVolume = Get-CimAssociatedInstance -InputObject ($ISOImageInfo) -Association 'MSFT_DiskImageToVolume' -ResultClassName 'MSFT_Volume' -ErrorAction SilentlyContinue | Select-Object -First 1

                                              #The drive letter is exposed as a character and is normalized so that an unassigned drive letter is evaluated as an empty value
                                                [String]$ISOImageDriveLetter = "$($ISOImageVolume.DriveLetter)".Trim([System.Char]0).Trim()

                                              Switch (([String]::IsNullOrEmpty($ISOImageDriveLetter) -eq $False) -and ([String]::IsNullOrWhiteSpace($ISOImageDriveLetter) -eq $False))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $WriteLogMessage.Invoke(0, @("Mounted ISO Image Volume Letter: $($ISOImageDriveLetter)"))

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

                                                                                            $WriteLogMessage.Invoke(0, @("Attempting to search for relevant driver folder(s) located within `"$($ISOImageDriveLetter):\`". Please Wait..."))

                                                                                            $WriteLogMessage.Invoke(0, @("Operating System Caption: $($WindowsImageDetails.ProductName)", "Operating System Caption Alias: $($OSCaptionAlias)", "Operating System Processor Architecture: $($WindowsImageDetails.ProcessorArchitecture)"))

                                                                                            $VirtIODriverFolderList = Get-ChildItem -Path "$($ISOImageDriveLetter):\*" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.DirectoryInfo]) -and ($_.FullName -imatch ".*$($OSCaptionAlias).*") -and ($_.FullName -imatch ".*$($WindowsImageDetails.ProcessorArchitecture).*")}

                                                                                            $VirtIODriverFolderListCount = ($VirtIODriverFolderList | Measure-Object).Count

                                                                                            $WriteLogMessage.Invoke(0, @("Located $($VirtIODriverFolderListCount) relevant driver folder(s) within volume `"$($ISOImageDriveLetter):\`"."))

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
                                                                                                                              #Any trailing directory separator(s) are removed and exactly one is appended, so that the value is always the root of the volume regardless of how the path was originally produced. A path such as "S:" is drive relative and resolves to the current directory of that drive rather than to its root, which causes DISM to fail with exit code 2. The value is intentionally not quoted because a trailing directory separator would escape the closing quote.
                                                                                                                                [String]$OfflineImageRootPath = "$($WindowsImageDetails.InstallLocation.Root.FullName.TrimEnd('\', '/'))\"

                                                                                                                              $StartProcessWithOutputParameters.ArgumentList.Add("/Image:$($OfflineImageRootPath)")
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

                                                                              $GuestAgentMSIPath = [System.IO.FileInfo][System.IO.Path]::Combine("$($ISOImageDriveLetter):\", 'guest-agent', $GuestAgentMSIName)

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
                                                                  $ISOImageInfo = Get-ToolkitDiskImage -ImagePath ($ISO.FullName) -StorageType 1

                                                                  Switch ($ISOImageInfo.Attached)
                                                                    {
                                                                        {($_ -eq $True)}
                                                                          {
                                                                              $WriteLogMessage.Invoke(0, @("Attempting to dismount the previously mounted ISO image. Please Wait...", "ISO Image Path: $($ISO.FullName)"))

                                                                              $Null = Try {Dismount-ToolkitDiskImage -ImagePath ($ISO.FullName) -StorageType 1} Catch {}
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

                  #region Download and install the SPICE guest tools
                    Switch ($SpiceGuestToolsInstallationRequired)
                      {
                          {($_ -eq $True)}
                            {
                                #region Stage the SPICE guest tools installer (Any existing installer within the destination directory is used as-is, otherwise the installer is downloaded)
                                  Switch ([System.IO.Directory]::Exists($SpiceGuestToolsDestinationDirectory.FullName))
                                    {
                                        {($_ -eq $False)}
                                          {
                                              $Null = [System.IO.Directory]::CreateDirectory($SpiceGuestToolsDestinationDirectory.FullName)
                                          }
                                    }

                                  $ExistingSpiceGuestToolsList = Get-ChildItem -Path ($SpiceGuestToolsDestinationDirectory.FullName) -Filter 'spice-guest-tools*.exe' -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])}

                                  $ExistingSpiceGuestToolsListCount = ($ExistingSpiceGuestToolsList | Measure-Object).Count

                                  Switch ($ExistingSpiceGuestToolsListCount -gt 0)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $SpiceGuestToolsPath = $ExistingSpiceGuestToolsList | Sort-Object -Property @('LastWriteTime') -Descending | Select-Object -First 1

                                              $WriteLogMessage.Invoke(0, @("Found $($ExistingSpiceGuestToolsListCount) existing SPICE guest tools installer(s) within `"$($SpiceGuestToolsDestinationDirectory.FullName)`". The download will be skipped.", "Latest Existing Installer: $($SpiceGuestToolsPath.FullName)"))
                                          }

                                        Default
                                          {
                                              $InvokeFileDownloadWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                $InvokeFileDownloadWithProgressParameters.URL = $SpiceGuestToolsDownloadURL
                                                $InvokeFileDownloadWithProgressParameters.Destination = $SpiceGuestToolsDestinationDirectory.FullName
                                                $InvokeFileDownloadWithProgressParameters.FileName = [System.IO.Path]::GetFileName($SpiceGuestToolsDownloadURL.OriginalString)
                                                $InvokeFileDownloadWithProgressParameters.ContinueOnError = $False
                                                $InvokeFileDownloadWithProgressParameters.Verbose = $True

                                              $InvokeFileDownloadWithProgressResult = Invoke-FileDownloadWithProgress @InvokeFileDownloadWithProgressParameters

                                              $SpiceGuestToolsPath = $InvokeFileDownloadWithProgressResult.DownloadPath
                                          }
                                    }

                                  $SpiceGuestToolsPath = Get-Item -Path ($SpiceGuestToolsPath.FullName) -Force
                                #endregion

                                #region Determine whether the SPICE guest tools installation is necessary
                                  $WriteLogMessage.Invoke(0, @("SPICE Guest Tools Installer Path: $($SpiceGuestToolsPath.FullName)"))

                                  $GetInstalledSoftwareParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                    $GetInstalledSoftwareParameters.FilterExpression = {($_.DisplayName -imatch '(^SPICE\s+Guest\s+Tools.*$)')}
                                    $GetInstalledSoftwareParameters.ContinueOnError = $True
                                    $GetInstalledSoftwareParameters.Verbose = $False

                                  $GetInstalledSoftwareResult = Get-InstalledSoftware @GetInstalledSoftwareParameters

                                  $InstalledSpiceGuestTools = $GetInstalledSoftwareResult | Select-Object -First 1

                                  Switch ($Null -ieq $InstalledSpiceGuestTools)
                                    {
                                        {($_ -eq $True)}
                                          {
                                              $WriteLogMessage.Invoke(0, @("The SPICE guest tools are not installed. An installation is necessary."))

                                              [Boolean]$SpiceGuestToolsInstallationNecessary = $True
                                          }

                                        Default
                                          {
                                              $WriteLogMessage.Invoke(0, @("The SPICE guest tools are already installed. The installation will be skipped.", "Installed Version: $($InstalledSpiceGuestTools.DisplayVersion)"))

                                              [Boolean]$SpiceGuestToolsInstallationNecessary = $False
                                          }
                                    }
                                #endregion

                                Switch ($SpiceGuestToolsInstallationNecessary)
                                  {
                                      {($_ -eq $True)}
                                        {
                                            #region Locate the archive utility that is used to read the driver catalogs contained within the installer (A local copy is preferred so that a download is avoided)
                                              $ArchiveUtilityPath = $Null

                                              #The architecture specific directories are searched first, followed by the architecture neutral directory. The first alias is also used as the download destination.
                                                $ArchiveUtilityArchitectureAliasList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'

                                                Switch ("$($Env:PROCESSOR_ARCHITECTURE)")
                                                  {
                                                      {($_ -ieq 'AMD64') -or ($_ -ieq 'X64')}
                                                        {
                                                            $ArchiveUtilityArchitectureAliasList.Add('X64')
                                                            $ArchiveUtilityArchitectureAliasList.Add('AMD64')
                                                        }

                                                      {($_ -ieq 'X86') -or ($_ -ieq 'I386')}
                                                        {
                                                            $ArchiveUtilityArchitectureAliasList.Add('X86')
                                                            $ArchiveUtilityArchitectureAliasList.Add('I386')
                                                        }

                                                      Default
                                                        {
                                                            $ArchiveUtilityArchitectureAliasList.Add("$($Env:PROCESSOR_ARCHITECTURE)")
                                                        }
                                                  }

                                              $ArchiveUtilitySearchDirectoryList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.DirectoryInfo]'

                                              ForEach ($ArchiveUtilityArchitectureAlias In $ArchiveUtilityArchitectureAliasList)
                                                {
                                                    $ArchiveUtilitySearchDirectoryList.Add([System.IO.Path]::Combine($ToolsDirectory.FullName, $ArchiveUtilityArchitectureAlias))
                                                }

                                              $ArchiveUtilitySearchDirectoryList.Add([System.IO.Path]::Combine($ToolsDirectory.FullName, 'All'))

                                              ForEach ($ArchiveUtilityArchitectureAlias In $ArchiveUtilityArchitectureAliasList)
                                                {
                                                    $ArchiveUtilitySearchDirectoryList.Add([System.IO.Path]::Combine($LocalDownloadDirectory.FullName, 'Tools', $ArchiveUtilityArchitectureAlias))
                                                }

                                              ForEach ($ArchiveUtilitySearchDirectory In $ArchiveUtilitySearchDirectoryList)
                                                {
                                                    $CandidatePath = [System.IO.FileInfo][System.IO.Path]::Combine($ArchiveUtilitySearchDirectory.FullName, '7z.exe')

                                                    Switch (([System.IO.File]::Exists($CandidatePath.FullName) -eq $True) -and ($Null -ieq $ArchiveUtilityPath))
                                                      {
                                                          {($_ -eq $True)}
                                                            {
                                                                $ArchiveUtilityPath = $CandidatePath

                                                                $WriteLogMessage.Invoke(0, @("Using the local archive utility. [Path: $($ArchiveUtilityPath.FullName)]"))
                                                            }
                                                      }
                                                }

                                              #Download the archive utility only when a local copy could not be located
                                                Switch ($Null -ieq $ArchiveUtilityPath)
                                                  {
                                                      {($_ -eq $True)}
                                                        {
                                                            $WriteLogMessage.Invoke(0, @("A local archive utility could not be located and will be downloaded. Please Wait...", "Search Directories: $(($ArchiveUtilitySearchDirectoryList | ForEach-Object {$_.FullName}) -Join ', ')"))

                                                            $ArchiveUtilityDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($LocalDownloadDirectory.FullName, 'Tools', $ArchiveUtilityArchitectureAliasList[0])

                                                            $Null = [System.IO.Directory]::CreateDirectory($ArchiveUtilityDirectory.FullName)

                                                            $InvokeFileDownloadWithProgressParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                              $InvokeFileDownloadWithProgressParameters.URL = $ArchiveUtilityDownloadURL
                                                              $InvokeFileDownloadWithProgressParameters.Destination = $ArchiveUtilityDirectory.FullName
                                                              $InvokeFileDownloadWithProgressParameters.FileName = [System.IO.Path]::GetFileName($ArchiveUtilityDownloadURL.OriginalString)
                                                              $InvokeFileDownloadWithProgressParameters.ContinueOnError = $False
                                                              $InvokeFileDownloadWithProgressParameters.Verbose = $True

                                                            $InvokeFileDownloadWithProgressResult = Invoke-FileDownloadWithProgress @InvokeFileDownloadWithProgressParameters

                                                            #An administrative installation extracts the archive utility binaries without installing the product
                                                              $ArchiveUtilityExtractionDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($ArchiveUtilityDirectory.FullName, 'Extracted')

                                                              $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                                $StartProcessWithOutputParameters.FilePath = 'msiexec.exe'
                                                                $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                  $StartProcessWithOutputParameters.ArgumentList.Add('/a')
                                                                  $StartProcessWithOutputParameters.ArgumentList.Add("`"$($InvokeFileDownloadWithProgressResult.DownloadPath.FullName)`"")
                                                                  $StartProcessWithOutputParameters.ArgumentList.Add('/qn')
                                                                  $StartProcessWithOutputParameters.ArgumentList.Add("TARGETDIR=`"$($ArchiveUtilityExtractionDirectory.FullName)`"")
                                                                $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                                $StartProcessWithOutputParameters.CreateNoWindow = $True
                                                                $StartProcessWithOutputParameters.ExecutionTimeout = [System.TimeSpan]::FromMinutes(5)
                                                                $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(5)
                                                                $StartProcessWithOutputParameters.LogOutput = $True
                                                                $StartProcessWithOutputParameters.ContinueOnError = $False
                                                                $StartProcessWithOutputParameters.Verbose = $True

                                                              $Null = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                                              $ArchiveUtilityPath = Get-ChildItem -Path ($ArchiveUtilityExtractionDirectory.FullName) -Filter '7z.exe' -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_ -is [System.IO.FileInfo])} | Select-Object -First 1

                                                              Switch ($Null -ieq $ArchiveUtilityPath)
                                                                {
                                                                    {($_ -eq $True)}
                                                                      {
                                                                          Throw "The archive utility could not be located following its extraction. [Path: $($ArchiveUtilityExtractionDirectory.FullName)]"
                                                                      }
                                                                }

                                                              $WriteLogMessage.Invoke(0, @("Using the downloaded archive utility. [Path: $($ArchiveUtilityPath.FullName)]"))
                                                        }
                                                  }
                                            #endregion

                                            #region Extract the installer so that the driver signing certificate(s) can be read from the driver catalogs contained within it
                                              $SpiceGuestToolsExtractionDirectory = [System.IO.DirectoryInfo][System.IO.Path]::Combine($SpiceGuestToolsDestinationDirectory.FullName, "$($SpiceGuestToolsPath.BaseName)_Extracted")

                                              Switch ([System.IO.Directory]::Exists($SpiceGuestToolsExtractionDirectory.FullName))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $Null = Remove-Item -Path ($SpiceGuestToolsExtractionDirectory.FullName) -Recurse -Force -Confirm:$False
                                                      }
                                                }

                                              $Null = [System.IO.Directory]::CreateDirectory($SpiceGuestToolsExtractionDirectory.FullName)

                                              $WriteLogMessage.Invoke(0, @("Attempting to extract the SPICE guest tools installer. Please Wait...", "Extraction Path: $($SpiceGuestToolsExtractionDirectory.FullName)"))

                                              $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                $StartProcessWithOutputParameters.FilePath = $ArchiveUtilityPath.FullName
                                                $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                  $StartProcessWithOutputParameters.ArgumentList.Add('x')
                                                  $StartProcessWithOutputParameters.ArgumentList.Add("`"$($SpiceGuestToolsPath.FullName)`"")
                                                  $StartProcessWithOutputParameters.ArgumentList.Add("`"-o$($SpiceGuestToolsExtractionDirectory.FullName)`"")
                                                  $StartProcessWithOutputParameters.ArgumentList.Add('-y')
                                                $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('1')
                                                $StartProcessWithOutputParameters.CreateNoWindow = $True
                                                $StartProcessWithOutputParameters.ExecutionTimeout = [System.TimeSpan]::FromMinutes(10)
                                                $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(5)
                                                $StartProcessWithOutputParameters.LogOutput = $False
                                                $StartProcessWithOutputParameters.ContinueOnError = $False
                                                $StartProcessWithOutputParameters.Verbose = $True

                                              $Null = Start-ProcessWithOutput @StartProcessWithOutputParameters
                                            #endregion

                                            #region Import the driver signing certificate(s) into the trusted publishers store so that the driver installation prompts are suppressed
                                              $WriteLogMessage.Invoke(0, @("Attempting to import the driver signing certificate(s) contained within the SPICE guest tools installer into the trusted publishers store. Please Wait..."))

                                              $ImportTrustedPublisherCertificateParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                $ImportTrustedPublisherCertificateParameters.SearchDirectory = $SpiceGuestToolsExtractionDirectory.FullName
                                                $ImportTrustedPublisherCertificateParameters.SearchFilter = '*.cat'
                                                $ImportTrustedPublisherCertificateParameters.ContinueOnError = $True
                                                $ImportTrustedPublisherCertificateParameters.Verbose = $True

                                              $ImportTrustedPublisherCertificateResult = Import-TrustedPublisherCertificate @ImportTrustedPublisherCertificateParameters

                                              ForEach ($ImportedCertificate In $ImportTrustedPublisherCertificateResult)
                                                {
                                                    $WriteLogMessage.Invoke(0, @("Driver Signing Certificate: $($ImportedCertificate.Subject)", "Thumbprint: $($ImportedCertificate.Thumbprint)", "Already Present: $($ImportedCertificate.AlreadyPresent)"))
                                                }
                                            #endregion

                                            #region Install the SPICE guest tools silently by using the normal installation method of the installer
                                              $WriteLogMessage.Invoke(0, @("Attempting to install the SPICE guest tools. Please Wait..."))

                                              $StartProcessWithOutputParameters = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
                                                $StartProcessWithOutputParameters.FilePath = $SpiceGuestToolsPath.FullName
                                                $StartProcessWithOutputParameters.ArgumentList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                  $StartProcessWithOutputParameters.ArgumentList.Add('/S')
                                                $StartProcessWithOutputParameters.AcceptableExitCodeList = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
                                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('0')
                                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('3010')
                                                  $StartProcessWithOutputParameters.AcceptableExitCodeList.Add('1641')
                                                $StartProcessWithOutputParameters.CreateNoWindow = $True
                                                $StartProcessWithOutputParameters.ExecutionTimeout = [System.TimeSpan]::FromMinutes(15)
                                                $StartProcessWithOutputParameters.ExecutionTimeoutInterval = [System.TimeSpan]::FromSeconds(5)
                                                $StartProcessWithOutputParameters.LogOutput = $True
                                                $StartProcessWithOutputParameters.ContinueOnError = $False
                                                $StartProcessWithOutputParameters.Verbose = $True

                                              $StartProcessWithOutputResult = Start-ProcessWithOutput @StartProcessWithOutputParameters

                                              #Verify the state of the SPICE guest tools service
                                                $SpiceGuestToolsService = Get-Service | Where-Object {($_.Name -imatch '(^(vdservice|spice\-agent|vdagent).*$)') -or ($_.DisplayName -imatch '(^.*SPICE.*(agent|service).*$)')} | Select-Object -First 1

                                                Switch ($Null -ine $SpiceGuestToolsService)
                                                  {
                                                      {($_ -eq $True)}
                                                        {
                                                            $WriteLogMessage.Invoke(0, @("SPICE Guest Tools Service Name: $($SpiceGuestToolsService.Name)", "SPICE Guest Tools Service Display Name: $($SpiceGuestToolsService.DisplayName)", "SPICE Guest Tools Service Status: $($SpiceGuestToolsService.Status)"))
                                                        }

                                                      Default
                                                        {
                                                            $WriteLogMessage.Invoke(2, @("The SPICE guest tools service could not be found following the installation."))
                                                        }
                                                  }
                                            #endregion

                                            #region Remove the extracted installer contents because they are only required in order to read the driver signing certificate(s)
                                              Switch ([System.IO.Directory]::Exists($SpiceGuestToolsExtractionDirectory.FullName))
                                                {
                                                    {($_ -eq $True)}
                                                      {
                                                          $Null = Try {Remove-Item -Path ($SpiceGuestToolsExtractionDirectory.FullName) -Recurse -Force -Confirm:$False} Catch {}
                                                      }
                                                }
                                            #endregion
                                        }
                                  }
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
