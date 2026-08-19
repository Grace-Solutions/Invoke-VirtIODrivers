# PowerShell Script Compilation Guidelines

## Overview
This document outlines the standardized guidelines for creating enterprise-grade PowerShell scripts. These guidelines ensure consistency, reliability, and maintainability across all PowerShell automation projects.

## Core Principles

### 1. No Nested Functions Policy
- **NEVER** use nested functions within scripts
- Keep all code in the main scope with minimal function definitions
- Use scriptblocks with `.Invoke()` pattern instead of nested functions
- This prevents performance issues and maintains code clarity

### 2. File System Object Usage
Always use proper .NET file system objects instead of string paths:

```powershell
# \u2705 CORRECT - Use accelerators with Path.Combine
$LogFile = [System.IO.FileInfo][System.IO.Path]::Combine("$($BaseDir)", 'Logs', 'Script.log')
$WorkingDir = [System.IO.DirectoryInfo][System.IO.Path]::Combine("$($RootPath)", 'Data')

# \u274c INCORRECT - Don't use string concatenation
$LogFile = "$BaseDir\Logs\Script.log"
```

### 3. Variable Interpolation in Strings
Use explicit variable syntax within quotes:

```powershell
# \u2705 CORRECT
Write-Output "Processing file: $($File.FullName)"
$Path = [System.IO.Path]::Combine("$($BaseDirectory)", 'SubFolder')

# \u274c INCORRECT
Write-Output "Processing file: $File.FullName"
$Path = [System.IO.Path]::Combine($BaseDirectory, 'SubFolder')
```

### 4. Code Formatting Standards
Use extensive indentation and line breaks for easier code reading:

```powershell
# \u2705 CORRECT - Extensive formatting
Switch ($True)
{
    {($Null -ieq $SourceDirectoryList) -or ($SourceDirectoryList.Count -eq 0)}
    {
        [System.IO.DirectoryInfo[]]$SourceDirectoryList = @("$($ContentDirectory.FullName)")
    }

    {([String]::IsNullOrEmpty($DestinationDirectory) -eq $True) -or ([String]::IsNullOrWhiteSpace($DestinationDirectory) -eq $True)}
    {
        [System.IO.DirectoryInfo]$DestinationDirectory = "$($Env:SystemDrive)\Recovery\Customizations"
    }
}

# \u274c INCORRECT - Compressed formatting
Switch ($True) { {($Null -ieq $SourceDirectoryList) -or ($SourceDirectoryList.Count -eq 0)} { [System.IO.DirectoryInfo[]]$SourceDirectoryList = @("$($ContentDirectory.FullName)") } }
```

## Logging Standards

### 1. Transcript Management
```powershell
# Script basename extraction
$ScriptFileInfo = [System.IO.FileInfo]$MyInvocation.MyCommand.Path
$ScriptBaseName = $ScriptFileInfo.BaseName

# Default log path with environment variables
$LogPath = [System.IO.DirectoryInfo][System.IO.Path]::Combine("$($env:SystemRoot)", 'Logs', 'Software', "$($ScriptBaseName)")

# Transcript with rotation (keep last 3)
$TranscriptFiles = $LogPath.GetFiles("$($ScriptBaseName)*.log") | Sort-Object CreationTime -Descending
if ($TranscriptFiles.Count -gt 3) {
    for ($i = 3; $i -lt $TranscriptFiles.Count; $i++) {
        $Null = $TranscriptFiles[$i].Delete()
    }
}

$TranscriptPath = [System.IO.FileInfo][System.IO.Path]::Combine($LogPath.FullName, "$($ScriptBaseName)_$(Get-Date -Format 'yyyyMMdd').log")
$Null = Start-Transcript -Path $TranscriptPath.FullName -Force
```

### 2. Logging Scriptblock Pattern
```powershell
# Logging scriptblock using PowerShell built-in cmdlets
$LogMessage = {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $Timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss.fff')
    $LogEntry = "[$($Timestamp)] - [$($Level)] - $($Message)"

    Switch ($Level)
    {
        'INFO'
        {
            Write-Verbose $LogEntry -Verbose
        }
        'WARN'
        {
            Write-Verbose $LogEntry
        }
        'ERROR'
        {
            Write-Warning $LogEntry
        }
        'DEBUG'
        {
            Write-Verbose $LogEntry
        }
    }
}

# Usage
$LogMessage.Invoke('Script started successfully', 'INFO')
```

### 3. Default Log Directory Structure
```
C:\Windows\Logs\Software\ScriptBaseName\
\u251c\u2500\u2500 ScriptBaseName_20250924.log
\u251c\u2500\u2500 ScriptBaseName_20250923.log
\u2514\u2500\u2500 ScriptBaseName_20250922.log
```

## Error Handling Standards

### 1. Central Error Handling Scriptblock
```powershell
$HandleError = {
    param(
        [System.Exception]$Exception,
        [string]$Context = 'Unknown'
    )
    
    $ErrorMessage = "Error in $($Context): $($Exception.Message)"
    if ($Exception.InnerException) {
        $ErrorMessage += " Inner: $($Exception.InnerException.Message)"
    }
    $LogMessage.Invoke($ErrorMessage, 'ERROR')
    $LogMessage.Invoke("Stack Trace: $($Exception.StackTrace)", 'DEBUG')
}

# Usage
try {
    # Risky operation
}
catch {
    $HandleError.Invoke($_.Exception, 'Operation Name')
    throw
}
```

### 2. Main Script Structure
```powershell
try {
    # Main script logic here
    $LogMessage.Invoke('Script execution started', 'INFO')
    
    # Script operations...
    
    $LogMessage.Invoke('Script execution completed successfully', 'INFO')
}
catch {
    $HandleError.Invoke($_.Exception, 'Main Script Execution')
    throw
}
finally {
    # Cleanup operations
    if ($SomeResource) {
        $SomeResource.Dispose()
        $LogMessage.Invoke('Resources cleaned up', 'DEBUG')
    }
    
    $LogMessage.Invoke('Script execution finished', 'INFO')
    $Null = Stop-Transcript
}
```

## Performance Optimization Guidelines

### 1. Collection Performance
Use Generic Lists instead of arrays for better performance:

```powershell
# \u2705 CORRECT - High performance collections
$DeviceList = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'
$StringList = New-Object -TypeName 'System.Collections.Generic.List[String]'
$FileList = New-Object -TypeName 'System.Collections.Generic.List[System.IO.FileInfo]'

# \u274c INCORRECT - Slower array operations
$DeviceList = @()
$StringList = @()
$FileList = @()
```

### 2. API Call Optimization
- Pre-load large datasets once and use in-memory lookups
- Use `Where-Object -ieq` for subsequent filtering instead of repeated API calls
- Measure and log initial load times for performance tracking

### 2. Microsoft Graph API Best Practices
- Use page size of 250 for optimal performance
- Implement OR filters: `'(id eq 'groupId') or (displayName eq 'groupName')'`
- Use `Get-MgGroupTransitiveMember` to get all member properties in `AdditionalProperties`
- Reduce API calls from thousands to just a few strategic calls

### 3. MECM Integration Patterns
- Implement thread safety with reduced concurrent jobs (5 max)
- Add 1-second delays between operations to prevent overwhelming MECM
- Include device removal functionality for direct membership rules
- Provide percentage progress for long-running operations

## Code Style Standards

### 1. Parameter Declarations
```powershell
[CmdletBinding()]
param(
    [System.IO.DirectoryInfo]$WorkingDirectory = [System.IO.Path]::Combine($env:TEMP, 'ScriptData'),
    [System.IO.DirectoryInfo]$LogPath = $null
)
```

### 2. PSObject Creation Pattern
Use OrderedDictionary for consistent property ordering:

```powershell
# \u2705 CORRECT - Structured PSObject creation
$PSObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary'
    $PSObjectProperties.DeviceName = $Device.Name
    $PSObjectProperties.SerialNumber = $Device.SerialNumber
    $PSObjectProperties.Status = $Device.Status
    $PSObjectProperties.LastSeen = $Device.LastSeen

$DeviceObject = New-Object -TypeName 'System.Management.Automation.PSObject' -Property ($PSObjectProperties)

# Add to Generic List for performance
$DeviceList.Add($DeviceObject)

# \u274c INCORRECT - Direct PSObject creation
$DeviceObject = [PSCustomObject]@{
    DeviceName = $Device.Name
    SerialNumber = $Device.SerialNumber
}
```

### 3. Switch Statement Usage
Use Switch statements exclusively instead of if statements:

```powershell
# \u2705 CORRECT - Single condition Switch
Switch (Test-Path -Path $OperatingSystemInfoPath.FullName)
{
    {($_ -eq $False)}
    {
        [Int]$Script:ErrorCode = $ErrorCodeRange.GetValue(2)
        break
    }
}

# \u2705 CORRECT - Multiple conditions Switch
Switch ($True)
    {
        {($Null -ieq $SourceDirectoryList) -or ($SourceDirectoryList.Count -eq 0)}
            {
                [System.IO.DirectoryInfo[]]$SourceDirectoryList = @("$($ContentDirectory.FullName)")
            }

        {([String]::IsNullOrEmpty($DestinationDirectory) -eq $True) -or ([String]::IsNullOrWhiteSpace($DestinationDirectory) -eq $True)}
            {
                [System.IO.DirectoryInfo]$DestinationDirectory = "$($Env:SystemDrive)\Recovery\Customizations"
            }
    }

# \u274c INCORRECT - if/elseif statements
if ($Condition1) {
    # Action 1
} elseif ($Condition2) {
    # Action 2
}
```

### 4. Flow Control with Switch
- Use `break` to stop on specific conditions
- Omit `break` to allow all conditions to evaluate
- Use switch/loop labels for complex flow control

### 5. Null Assignment Pattern
Use `$Null =` for commands that don't need output stored:
```powershell
$Null = Start-Transcript -Path $TranscriptPath.FullName -Force
$Null = $Directory.Create()
$Null = Add-AppxPackage -Path $PackagePath
```

### 6. Progress Tracking for Long Operations
```powershell
$ProgressHandler = {
    param($WebSender, $ProgressEventArgs)
    $PercentComplete = [math]::Round(($ProgressEventArgs.BytesReceived / $ProgressEventArgs.TotalBytesToReceive) * 100, 2)
    $ReceivedMB = [math]::Round($ProgressEventArgs.BytesReceived / 1MB, 2)
    $TotalMB = [math]::Round($ProgressEventArgs.TotalBytesToReceive / 1MB, 2)

    Write-Progress -Activity 'Operation in Progress' `
                  -Status "Processed $($ReceivedMB) MB of $($TotalMB) MB" `
                  -PercentComplete $PercentComplete `
                  -CurrentOperation "Progress: $($PercentComplete)%"
}
```

### 7. Exit Code Management
Always use `[System.Environment]::ExitCode` for proper exit code handling:

```powershell
# Set default success code
[System.Environment]::ExitCode = 0

# Set specific error codes for different scenarios
Switch ($ErrorCondition)
{
    'DownloadFailed'
    {
        [System.Environment]::ExitCode = 2
    }
    'InstallationFailed'
    {
        [System.Environment]::ExitCode = 3
    }
    'VerificationFailed'
    {
        [System.Environment]::ExitCode = 5
    }
}

# Log exit code at end
$LogMessage.Invoke("Script execution finished with exit code: $([System.Environment]::ExitCode)", 'INFO')
```

## Script Requirements Template

### 1. Header Requirements
```powershell
#Requires -Version 5.1
#Requires -RunAsAdministrator  # If needed

<#
.SYNOPSIS
    Brief description of script purpose
.DESCRIPTION
    Detailed description of script functionality
.PARAMETER ParameterName
    Description of parameter
.EXAMPLE
    .\Script.ps1 -Parameter Value
.NOTES
    Author: [Author Name]
    Version: [Version Number]
    Created: [Date]
#>
```

### 2. Package Management
- Always use appropriate package managers instead of manual file editing
- Use `npm install`, `pip install`, `cargo add`, etc.
- Only edit package files directly for complex configuration changes

### 3. Testing Recommendations
- Write unit tests for all major functions
- Test error handling paths
- Validate with different input scenarios
- Run tests before deployment

## Directory Structure Best Practices

```
ProjectRoot/
\u251c\u2500\u2500 ScriptName/
\u2502   \u251c\u2500\u2500 ScriptName.ps1
\u2502   \u251c\u2500\u2500 README.md
\u2502   \u251c\u2500\u2500 Tests/
\u2502   \u2502   \u2514\u2500\u2500 ScriptName.Tests.ps1
\u2502   \u2514\u2500\u2500 Logs/
\u2502       \u2514\u2500\u2500 (auto-generated log files)
\u251c\u2500\u2500 Common/
\u2502   \u251c\u2500\u2500 CommonFunctions.ps1
\u2502   \u2514\u2500\u2500 CommonVariables.ps1
\u2514\u2500\u2500 Documentation/
    \u251c\u2500\u2500 PowerShell-Script-Compilation-Guidelines.md
    \u2514\u2500\u2500 ProjectSpecificDocs.md
```

## Quality Checklist

Before finalizing any PowerShell script, ensure:

- [ ] No nested functions used
- [ ] All paths use `System.IO.Path::Combine`
- [ ] File system objects use proper accelerators
- [ ] Variables in strings use `"$($Variable)"` syntax
- [ ] Extensive indentation and line breaks for readability
- [ ] Generic Lists used instead of arrays for performance
- [ ] PSObjects created with OrderedDictionary pattern
- [ ] Switch statements used exclusively (no if statements)
- [ ] Proper flow control with break/labels as needed
- [ ] Logging uses PowerShell built-in cmdlets
- [ ] Central error handling implemented
- [ ] Transcript management with rotation
- [ ] Try-catch-finally structure used
- [ ] Exit code management with [System.Environment]::ExitCode
- [ ] Resources properly disposed in finally block
- [ ] Progress tracking for long operations
- [ ] Comprehensive parameter validation
- [ ] Proper comment-based help
- [ ] Performance considerations addressed

## Version Control Integration

### Commit Message Format
```
feat: Add Teams installation detection logic
fix: Resolve file locking issue in logging
docs: Update README with usage examples
refactor: Implement central error handling pattern
```

### Branch Naming
- `feature/script-name-enhancement`
- `bugfix/logging-file-lock-issue`
- `docs/update-compilation-guidelines`

This document serves as the authoritative guide for PowerShell script development and should be referenced for all new script creation and existing script refactoring efforts.

Always use WebClient for downloads and not Invoke-WebRequest because it is way slower. This is applied only to downloading files.

For API calls using System.Net.WebRequest or Httprequest with status code translation and rate limit retry and paging until everything is collected.

Use Get-CIMInstance always and never Get-WMIObject

When doing powershell scripts
No Write-Host
No AI icons in log messages and strings
Only Write-Verbose, Warning, Error, and Output as needed
Logging function should be centralized and [TimestampUTC] - [Level] - Message
Use $Var = New-Object -TypeName 'Type' and not [Type]::New() as much as possible
Use $Var = System.Collections.Generic.List[T] for arrays and add with 2 indents then $Var.Add(Item)
Use Splatting by doing $VarObjectProperties = New-Object -TypeName 'System.Collections.Specialized.OrderedDictionary' then two indents and $Var.Property = $Value and after when running the command
Set conditional properties when splatting by using a switch statement like Switch ($Property) or in multi case Switch ($True) {}
Prefer switch statements over if statements
Dont put { on the same line so that the code is more readable so we line break { and indent it one level then indent code one more level after that and then close with } at the same indent as the opening {. This applies to all blocks including Try/Catch/Finally, Switch, For, Function, etc. For example Try at column 0, { indented to column 4, code inside indented to column 8, } back at column 4. Nested blocks continue the pattern — each { is one level in from its parent statement, and the code inside is one more level past the {.
Powershell scripts should be written in a PS7 compatible way so that Linux and Mac can be accomodated relatively easily although its not the main goal of each script
[System.IO.FileInfo][System.IO.Path]::Combine(Path1, Path2, Leaf) and [System.IO.DirectoryInfo][System.IO.Path]::Combine(Path1, Path2) should be used for all paths so that directory separator logic is already accounted for.
Use [System.IO.File]::Exists() for file existence checks and [System.IO.Directory]::Exists() for directory existence checks instead of Test-Path.
Switch ($True) should only be used for unrelated conditions. For a single boolean variable use Switch ($VarName) with {($_ -eq $True)} and {($_ -eq $False)} as the cases.
Parameter types should use [System.IO.FileInfo] for file paths and [System.IO.DirectoryInfo] for directory paths instead of [String]
Use environment variable paths like $Env:ProgramFiles instead of hardcoded paths such as 'C:\Program Files'
URLs should be System.URI with full scheme (e.g. https://)
Use System.Net.WebClient with default credentials for downloads instead of Invoke-WebRequest
Use WriteAllText or WriteAllLines with non BOM encoding for writing file content
Environment variables should only be used for paths and non-sensitive configuration, never for secrets or API keys
Here-strings should use PowerShell variable expansion with $($Var) syntax to bake in values at generation time rather than creating system environment variables and referencing them
Splatting dictionary properties should be indented one additional level from the variable assignment
Loops should generally be Long Loop Type For ($Counter Index etc) {} and have Counter of Count generally so that we can easily use Write-Progress when appropriate
Main script should always have Try Catch Finally
ScriptPath should be dynamically determined and used for the logpath and name using Start-Transcript (no -Append, no custom log appending functions). Transcript log name should be based on the BaseName of the script.
Service names and display names should be generic to the product being installed, not specific to a single use case, since configurations can always be extended
When doing Powershell modules, apply the following
*no async/await
*No updating progress bars from background threads because it does not work
*No workarounds and simpler approaches without asking first
*Code according to best practices
*Code quality is that goal, not quick delivery
*Think about what is needed before implementation so we can have reusable code across the code base, so BaseCmdlets, inherits, Classes, Models, Methods
*Add write progress to cmdlets where approriate
*The Module folder should not be gitignored
*Build artifcacts should go into the Artifacts folder
*All docs except the Readme should go into the docs folder
*Any scripts should go into the scripts folder
*A changelog should be kept
*Constant printing of excessive information to the threads should not occur to keep the project concise
*New threads speed up performance but should not forget the progress of the previous thread so we can pick up where we left off
*Release format is yyyy.mm.dd.hhmm in all cases
