@set "echo=off"
@echo %echo%
REM Name:           UnifiedCAE.bat
REM Purposes:       Checks for prerequisites such as .Net Framework or signs that the application is already installed and returns an errorcode if they are not met.
REM                 Modifies computer configuration such as Firewall and AV rules.
REM                 Modifies Application Configuration such as activating licenses and stopping services before removal
REM                 Modifies Application Configuration to save unique machine identifiers to be reloaded as needed
REM Usage:          Edit the below variables to detect installation of specified app, change computer configuration, and application configuration.
REM                 The script can automatically detect what trigger is being used so no parameters are required
REM                 If needed, Parameters can be manually specified by using the "/mode" argument followed by the mode
REM                 Running it without parameters outside of a CAE will bring up a menu with diagnostics
REM                 Modes are as follows: REGISTER, ACTIVATE, VIRTUALIZE, LAUNCH, EXIT, DEVIRTUALIZE, DEACTIVATE, KACE, and DEBUG 
REM                 When Defining values, use environment variables when possible
REM Return Codes:   0:      Conditions Met
REM                 1638:   App Already Installed
REM                 15639:  Other Prerequisite not satisfied
REM                 3010:   Reboot Required Error
REM                 5:      Application Launch Denied by Server (Future Use)
REM                 1359:   Internal Error
REM                 574:    Unhandled Error
REM                 87:     Invalid Parameter Error
REM Author:         Trevor Buttrey: tbuttrey@udel.edu
REM Revisions:      August 26th 2020	- 1.0 -	Initial Release 
REM                 August  5th 2021	- 1.1
REM                   Bug Fixes: 
REM                      Updated Message Service to V1.1 which updates MessageBoxSvc.bat, Uninstall.bat, and the uninstall registry keys 
REM                         MessageBoxSvc.bat:   Removed the one message per execution limit to prevent desynchronization of state that could sometimes occur resulting in the user seeing old and irrelevant messages.
REM                         Uninstall.bat:       Added Help Text if there's an error during uninstall.
REM                                              Fixed infinite loop that can occur when user can't elevate
REM                                              Fixed error handling to respect /s switch
REM                         Uninstall Registry:  Fixed Uninstall info to show Version information.
REM                                              Fixed Uninstall GUID to be unique between IT-Groups
REM                         Data Directory:      Granted Full Access to Data Directory so that messages can be deleted after they are shown.
REM                                              Updated Message Initialization error message to indicate error could be either in Install or Update
REM                      Added "/f" to all "Reg Add" calls to prevent script stall if key exists
REM                      Changed the log level and content of various messages and added a few additional messages
REM                      Corrected some example items
REM                      Rearranged some of the main functions to make more sense e.g. bypass is now after log initialize and debug checks
REM                      Fixed a log message in HW_Keys that had a blank value
REM                      Changed Logfile name to have a space instead of underscore
REM                      Removed a errant "Pause" command
REM                      Changed Settings_Override_Code to App_Override_Code to match actual usage
REM                   Features:
REM                      Added Option to Automatically Add/Remove exe location to AppPath
REM                      Added Option to Automatically Add/Remove registry keys for Solidworks EULA
REM                      Added Option to Automatically Add/Remove HASP Drivers for Rocscience
REM                      Added Application specific Debug Override
REM                      Added Web Override to enable remote override for all users
REM                      Added Elevation status to log
REM                      Added License Deactivation Custom Code Section and renamed Licensing to License Activation
REM                      Added Option to Enable/Disable Message Service if desired. If Disabled, all messages are logs but not shown to the user. 
REM                      Added Option to Debug Menu to toggle Message Service which is disabled by default in DEBUG mode
REM                      Added Option to Debug Menu to do a basic scan for potential issues
REM                      Added Functionality to handle shared machines: no removal of license, firewall rules etc.
REM                January  5th 2022	- 1.2
REM                   Bug Fixes:
REM                      Fixed Username Handling for special cases
REM                      Fixed Automatic AV Rules to only add if defined
REM                      Fixed AppPath to only add if defined
REM                   Features: 
REM                      Updated Self Check to make actual issues Clear
REM                      Added LogLevel Override (use /LogLevel N to specify log level)
REM                      Optimized Web Overrides to load during REGISTER only
REM                      Added debug option to test run modes by re-invoking the script (which will cause things like overrides to be processed)
REM                August  28th 2022	- 1.2.1
REM                   Bug Fixes:
REM                      Fixed AppPath Checking to Verify if item actually exists
REM                November 29th 2022	- 1.2.2
REM                   Bug Fixes:
REM                      Fixed how the script handles running in 32-bit CMD on a 64-bit system
REM                      Fixed some Internal Variables missing ending quotes
REM                      Fixed formatting of this revisions section to display consistently
REM                      Fixed how the log command handles mode not being defined
REM                   Features: 
REM                      Added KACE Mode and support for running this script from KACE
REM                      Added additional logging pertaining to Autodesk Licensing

set "Current_Version=1.2.2"

REM ========== Basic Settings ==========

REM [Application information]

REM Matlab examples are for 2019b
REM Solidworks examples are for 2019 SP3.0

REM	Aplication name and version
REM Example: Matlab     "Mathworks", "Matlab", and "2019b"
REM Example: Solidworks "Dassault", "Solidworks", and "2019"
set "UsrVar_Application_Vendor="
set "UsrVar_Application_Name="
set "UsrVar_Application_Version="

REM What is the key name in the primary uninstall section of the registry
REM This is the value in "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\[GUID you want]", using the Registry section of the studio will help limit the number of these you have to look through
REM Value must be the GUID or "False" if there is no GUID
REM Example: Matlab     "Matlab 2019b"
REM Example: Solidworks "{F261BF5C-81C4-4E81-9ED6-D7EBFA2A9A5B}"
set "UsrVar_Uninstall_GUID="

REM Where is the main exe located
REM You can likely just use launch command line value here from the project settings
REM Value must be the exe or "False" if there is no exe
REM Example: Matlab     "%programfiles%\MATLAB\R2019b\bin\win64\MATLAB.exe"
REM Example: Solidworks "%programfiles%\SOLIDWORKS Corp\SOLIDWORKS\SLDWORKS.exe"
set "UsrVar_Exe_Location="

REM Where is the main Program Folder located
REM This is the lowest program folder that has all the files for the program, you want to be as specific as you can to the version of the application
REM Value must be the Folder or "False" if there is no Folder
REM Example: Matlab     "%programfiles%\MATLAB\R2019b"
REM Example: Solidworks "%programfiles%\SOLIDWORKS Corp\"
set "UsrVar_ProgramFolder_Location="


REM Where is the program data folder (usually in %programdata%)
REM Value must be the Folder or "False" if there is no Folder
REM Example: Matlab     "%ProgramData%\MathWorks\R2019b"
REM Example: Solidworks "%ProgramData%\Solidworks"  
set "UsrVar_ProgramData_Location="

REM Where is the registry data (usually in HKLM\Software\)
REM Value must be the Registry Key or "False" if there is no Key
REM Example: Matlab     "HKLM\SOFTWARE\MathWorks\R2019b"
REM Example: Solidworks "HKLM\Software\Solidworks"
set "UsrVar_RegistryData_Location="

REM Where is the license info, can be file, folder, registry name, or registry key, set to "False" if no license
REM If specifying a Folder or Registry Key, you MUST end it with "\" e.g. "%Programfiles%\MATLAB\R2019b\licenses\"
REM Value must be the Folder or "False" if there is no Folder
REM Example: Matlab     "%Programfiles%\MATLAB\R2019b\licenses\network.lic"
REM Example: Solidworks "HKLM\SOFTWARE\SolidWorks\Licenses\Serial Numbers\SolidWorks"
set "UsrVar_License_Location="

REM [Application Functionality]

REM Is this Application allowed live side by side with a different version of itself? 
REM Generally if the install directory is the same each version the answer is no, if it's different, then yes. But testing is always advisable
REM Value must be "Allow", "Deny", or "Warn"
REM Example: Matlab     "Allow"
REM Example: Solidworks "Deny"
set "UsrVar_SideBySide_Allowed="

REM Is Previous Program Data allowed? 
REM Allow is the safest option, Warn and Deny allow for more thorough control over the app state. But as always, testing is advisable
REM Value must be "Allow", "Deny" or "Warn"
REM Example: Matlab     "Allow"
REM Example: Solidworks "Warn"
set "UsrVar_ProgramData_Allowed="

REM Is Previous Program Folder allowed? 
REM Allow is the safest option, Warn and Deny allow for more thorough control over the app state. But as always, testing is advisable
REM Value must be "Allow", "Deny" or "Warn"
REM Example: Matlab     "Warn"
REM Example: Solidworks "Warn"
set "UsrVar_ProgramFolder_Allowed="

REM Is Previous Registry Data allowed? 
REM Allow is the safest option, Warn and Deny allow for more thorough control over the app state. But as always, testing is advisable
REM Value must be "Allow", "Deny" or "Warn"
REM Example: Matlab     "Allow"
REM Example: Solidworks "Warn"
set "UsrVar_RegistryData_Allowed="

REM Is Previous License allowed? 
REM Allow is the safest option, Warn and Deny allow for more thorough control over the app state. But as always, testing is advisable
REM If you specified a Folder or Registry Key for the license, ANY and ALL items in that location will trigger a message if using Deny or Warn
REM Value must be "Allow", "Deny" or "Warn"
REM Example: Matlab     "Deny"
REM Example: Solidworks "Warn"
set "UsrVar_LicenseData_Allowed="


REM ========== Prereq Detection ==========

REM .NET 3.5: set to "True" if you need it to be installed
REM Value must be "True" or "False"
REM Example: Matlab     "False"
REM Example: Solidworks "False" ("True" if you're using some very specific functionality) 
set "UsrVar_Require_DotNet_35="

REM .NET 4.5+: Choose one of the following values if required: "4.5" "4.5.1" "4.5.2" "4.6" "4.6.1" "4.6.2" "4.7" "4.7.1" "4.7.2" "4.8" Otherwise "False"
REM Example: Matlab     "False"
REM Example: Solidworks "4.5.2"
set "UsrVar_Require_DotNet_4x="

REM ========== Firewall Rules ==========

REM This only functions with Microsoft Windows Defender

REM Add main exe to firewall? (this is just so you don't have to copy it below)
REM Value must be "True" or "False"
REM Example: Matlab     "True"
REM Example: Solidworks "False"
set "UsrVar_Firewall_Allow_Main_exe="

REM Add additional exes to firewall?
REM Add items in increasing order, add additional rules by incrementing the number in [] brackets
REM Example: Matlab     "" (Empty)
REM Example: Solidworks "%programfiles%\Bonjour\mDNSResponder.exe", "%programfiles(x86)%\Bonjour\mDNSResponder.exe", "%programfiles%\solidworks corp\solidworks\swscheduler\dtsmonitor.exe", "%programfiles%\SOLIDWORKS corp\SOLIDWORKS\swScheduler\DTSCoordinatorService", "%programfiles%\solidworks corp\solidworks electrical\bin\solidworkselectrical.exe"
set "UsrVar_Firewall_Rule[0]="
set "UsrVar_Firewall_Rule[1]="
set "UsrVar_Firewall_Rule[2]="
set "UsrVar_Firewall_Rule[3]="
set "UsrVar_Firewall_Rule[4]="
set "UsrVar_Firewall_Rule[5]="

REM ========== AV Rules ==========

REM Add Additional Directories or EXEs to Microsoft Windows Defender, this helps increase performance
REM Main EXE and Program Folder Location are added automatically unless "Automatically_Add_AV_Rules" is false in core settings below
REM Add items in increasing order, add additional rules by incrementing the number in [] brackets
REM Example: Matlab     "" (Empty)
REM Example: Solidworks "%programfiles%\Microsoft SQL Server", "%programfiles(x86)%\Microsoft SQL Server"
set "UsrVar_AV_Rule[0]="
set "UsrVar_AV_Rule[1]="
set "UsrVar_AV_Rule[2]="
set "UsrVar_AV_Rule[3]="
set "UsrVar_AV_Rule[4]="
set "UsrVar_AV_Rule[5]="

REM ========== Services ==========

REM Add All Services related to the application, these will be stopped prior to adding the application if they are running and will also be stopped prior to removal.
REM Add items in increasing order, add additional rules by incrementing the number in [] brackets
REM Example: Matlab     "" (Empty)
REM Example: Solidworks "SQLBrowser", "SQLWriter", "MSSQL$TEW_SQLEXPRESS", "impi_hydra", "FlexNet Licensing Service", "FlexNet Licensing Service 64", "Bonjour Service"
set "UsrVar_Service_AddRemove[0]="
set "UsrVar_Service_AddRemove[1]="
set "UsrVar_Service_AddRemove[2]="
set "UsrVar_Service_AddRemove[3]="
set "UsrVar_Service_AddRemove[4]="
set "UsrVar_Service_AddRemove[5]="

REM Add All Services that need to be running when the software starts, it will be stopped when the application exits
REM This is for for services that don't start automatically and the application errors if they aren't running.
REM Add items in increasing order, add additional rules by incrementing the number in [] brackets
REM This Replaces: https://support.software2.com/hc/en-us/articles/360015570153-Cloudpaging-wrapper-script-to-start-and-stop-services-on-app-launch-and-exit
REM Example: Matlab     "" (Empty)
REM Example: Solidworks "" (Empty)
set "UsrVar_Service_LaunchClose[0]="
set "UsrVar_Service_LaunchClose[1]="
set "UsrVar_Service_LaunchClose[2]="
set "UsrVar_Service_LaunchClose[3]="
set "UsrVar_Service_LaunchClose[4]="
set "UsrVar_Service_LaunchClose[5]="

REM  ========== Licensing ==========

REM Licensing Activation (Custom Code)
REM Please Read the Custom Code Section below for how to handle errors and such
REM You can put code here that will activate the license (for example the content of the AdskLicenseService[Autodesk product].bat files)
REM If you need an external file (not recommended), see the Additional Files Section below for how to add files
REM DO ***NOT*** edit the 3 lines below this
goto :Activate_License_End & REM Don't touch this
:Activate_License & REM Don't touch this
setlocal & REM Don't touch this
REM Put Licensing Activation Code Here:



REM DO ***NOT*** edit the 3 lines below this
endlocal & REM Don't touch this
exit /b & REM Don't touch this
:Activate_License_End & REM Don't touch this
REM End of Licensing Activation

REM DO ***NOT*** edit the 3 lines below this
goto :Deactivate_License_End & REM Don't touch this
:Deactivate_License & REM Don't touch this
setlocal & REM Don't touch this
REM Put Licensing Deactivation Code Here:



REM DO ***NOT*** edit the 3 lines below this
endlocal & REM Don't touch this
exit /b & REM Don't touch this
:Deactivate_License_End & REM Don't touch this
REM End of Licensing Deactivation

REM Files and Registry Keys That should be retained between loadings of the app
REM this is useful for Applications that store hardware identifiers for the license, eula, or other such items.
REM Example: Matlab     "" (Empty)
REM Example: Solidworks "HKCU\Software\Solidworks\Diagnostics\GFX Card Driver Version", "HKCU\Software\Solidworks\Diagnostics\GFX Card Model", "HKCU\Software\Solidworks\Diagnostics\Last Validated SW Version", "HKCU\Software\Solidworks\Diagnostics\OS Version"
set "UsrVar_HWKey_Machine[0]="
set "UsrVar_HWKey_Machine[1]="
set "UsrVar_HWKey_Machine[2]="
set "UsrVar_HWKey_Machine[3]="
set "UsrVar_HWKey_Machine[4]="
set "UsrVar_HWKey_Machine[5]="

REM Files and Registry Keys That should be retained between loadings of the app that are unique per user
REM this is useful for Applications that store hardware identifiers for the license, eula, or other such items, but that are also unique to the user.
REM I don't have any actual examples of this but it is here if needed
REM Example: Matlab     "" (Empty)
REM Example: Solidworks "" (Empty)
set "UsrVar_HWKey_User[0]="
set "UsrVar_HWKey_User[1]="
set "UsrVar_HWKey_User[2]="
set "UsrVar_HWKey_User[3]="
set "UsrVar_HWKey_User[4]="
set "UsrVar_HWKey_User[5]="

REM  ========== Custom Code ==========



REM  ========== Additional Files ==========


REM ========== Application Specific Options ==========

REM [RocScience HASP Driver Install]
set "UsrVar_Rocsci_Drivers_Enabled="

REM [Solidworks EULA]

REM Enable Solidworks EULA bypass
REM Value must be "True" or "False"
set "UsrVar_Solidworks_EULA_Enabled="

REM Solidworks version e.g. "2019"
set "UsrVar_Solidworks_Version="

REM Solidworks Service Pack e.g. "SP3.0"
set "UsrVar_Solidworks_Service_Pack="

REM Solidworks Service Pack in alternate format e.g. "SP03" or "False" if you aren't using eDrawings
set "UsrVar_Solidworks_Service_Pack2="

REM Solidworks Composer Short version e.g. "7.6" or "False" if you aren't using Composer
set "UsrVar_Solidworks_Composer_Short_Version="

REM Solidworks Composer Long version e.g. "7.6.5.1481" or "False" if you aren't using Composer
set "UsrVar_Solidworks_Composer_Long_Version="

REM [Autodesk 2020+ Licensing]

REM Enable Autodesk Licensing activation
REM Value must be "True" or "False"
set "UsrVar_ADSK_License_Enabled="

REM Product version e.g. "2020.0.0.f"
set "UsrVar_ADSK_Product_Version="

REM License server e.g. "autodesklm.university.edu"
set "UsrVar_ADSK_License_Server="

REM Language e.g. "en_us"
set "UsrVar_ADSK_Language="

REM Product Key e.g. "507L1"
set "UsrVar_ADSK_Product_Key="

REM Serial Number e.g. "566-NNNNNNNN"
set "UsrVar_ADSK_Serial_Number="

REM Pit file e.g. "%CommonProgramFiles(x86)%\Autodesk Shared\AdlmReg\2020\NavisworksManageConfig.pit"
set "UsrVar_ADSK_Config_File="

REM ==========Code for Defining the user friendly application name, it is NOT recommended that you change this==========

set User_Friendly_Application_Name=%UsrVar_Application_Vendor% %UsrVar_Application_Name% %UsrVar_Application_Version%

REM ==========Variables below should be edited before use of this script and ideally should not change across apps==========

REM [Institutional Variables]
set "IT_Group_Name=ENGR-IT"
set "IT_Group_Help_Location=https://engr.udel.edu/it"
set "Web_Override_Location=https://appsanywhere.engr.udel.edu/UnifiedCAE/Bypass"
set "Web_Authorization_Location=https://appsanywhere.engr.udel.edu/UnifiedCAE/Authorize"

REM [Core Functionality Variables]
set "MsgSvc_Enabled=True"
set "Show_Alternate_AV_Instructions_Message=False"
set "Show_Alternate_Firewall_Instructions_Message=False"
set "Show_DotNet_4x_Installing_Message=True"
set "Show_DotNet_35_Installing_Message=True"
set "Allow_Firewall_Failure=True"
set "Allow_AV_Failure=True"
set "Automatically_Add_AV_Rules=True"
set "Clear_Log_On_Register=False"
set "Auto_Install_DotNet_35=True"
set "Auto_Install_DotNet_4x=True"
set "Auto_Set_AppPath=True"
set "ADSK_Remove_License=True"
REM Log Levels: 0=Error, 1=Warning, 2=Info, 3=Verbose, 4=Debug
set "LogLevel=3"

REM [Message Text]
set "Internal_Error_Text=There was an error running a required process"
set "App_Installed_Text=A conflicting version of %User_Friendly_Application_Name% or its data was found.\n\nYou will need to uninstall the current version of %User_Friendly_Application_Name% before you can use this one."
set "App_Reminent_Text=Previous Application Data for %User_Friendly_Application_Name% was found.\n\nThis may result in the software not working as expected.\nIf you encounter issues please contact support"
set "DotNet_4x_Installing_Text=%User_Friendly_Application_Name% requires .Net %UsrVar_Require_DotNet_4x%.\n\nPlease wait while it is automatically installed. This can take a few minutes to complete."
set "DotNet_4x_Error_Text=%User_Friendly_Application_Name% requires .Net %UsrVar_Require_DotNet_4x%.\n\nYou will need to install it before you can use this application."
set "DotNet_4x_Install_Error_Text=%User_Friendly_Application_Name% requires .Net %UsrVar_Require_DotNet_4x%.\n\nAutomatic installation Failed\nYou will need to install it manually before you can use this application."
set "DotNet_4x_Install_Reboot_Text=%User_Friendly_Application_Name% requires .Net %UsrVar_Require_DotNet_4x%.\n\nAutomatic installation was Successfull\nYou will first need to reboot your computer and load the application again before you can use it."
set "DotNet_35_Installing_Text=%User_Friendly_Application_Name% requires .Net 3.5.\n\nPlease wait while it is automatically installed. This can take a few minutes to complete."
set "DotNet_35_Error_Text=%User_Friendly_Application_Name% requires .Net 3.5.\n\nYou will need to install it before you can use this application."
set "DotNet_35_Install_Error_Text=%User_Friendly_Application_Name% requires .Net 3.5.\n\nAutomatic installation Failed\nYou will need to install it manually before you can use this application."
set "Alternate_AV_Text=It appears you are using a third party Antivirus product.\n\nWhile not necessary to use the software, in order to improve performance on your system when using this applicaition, it is recommended that you add the following items to your AV's exclusion list:"
set "Alternate_Firewall_Text=It appears you are using a third party Firewall product.\n\nIf you have issues with the software not working as expected, you may need to add the following items to your Firewall's Allowed list:"
set "How_To_Get_Help_Text=If you require assistance with this, please contact %IT_Group_Name% at %IT_Group_Help_Location%"

REM ==========Do not make changes below this line without good reason==========

REM [Internal Variables]
set "Cloudpaging_Profiles=%Programdata%\Endeavors Technologies\StreamingCore\Profiles\"
set "KACE_Kbots=KACE\kbots_cache\packages\kbots\"
set "Log_Location=%ProgramData%\Endeavors Technologies\StreamingCore\Log\"
set "Log_File=UnifiedCAE %User_Friendly_Application_Name%.log"
set "Override_Location=%ProgramData%\%IT_Group_Name%\AppsAnywhere\Overrides"
set "Override_Name=%User_Friendly_Application_Name%"
set "Web_Override_Name=%User_Friendly_Application_Name: =_%"
set "Debug_Override_Name=%User_Friendly_Application_Name% DEBUG"
set "Shared_Machine_Override_Name=SHARED"
set "Override_Mode_List=ALL, REGISTER, ACTIVATE, VIRTUALIZE, LAUNCH, EXIT, DEVIRTUALIZE, DEACTIVATE"
set "Shared_Machine=False"
set "Uninstall_GUID_Allowed=Deny"
set "Primary_Exe_Allowed=Deny"
set "HW_Key_User_Location=%ProgramData%\%IT_Group_Name%\AppsAnywhere\HW_Keys\User"
set "HW_Key_Machine_Location=%ProgramData%\%IT_Group_Name%\AppsAnywhere\HW_Keys\Machine"
set "DOTNET_35_Registry_Location=HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5"
set "DOTNET_4x_Registry_Location=HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
set "Uninstall_Registry_Location=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
set "Uninstall_WOW64_Registry_Location=HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
set "AppPath_Registry_location=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"
set "AppPath_WOW64_Registry_location=HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths"
set "AppPath_Indicator=UnifiedCAE"
set "Running_Directory=%~dp0"
set "MsgSvc_Initalized=False"
set "MsgSvc_ScriptMajorVersion=1"
set "MsgSvc_ScriptMinorVersion=1"
set "MsgSvc_Firendly_Name=AppsAnywhere Message Service (%IT_Group_Name%) V%MsgSvc_ScriptMajorVersion%"
set "MsgSvc_Firendly_Name_Old=AppsAnywhere Message Service V%MsgSvc_ScriptMajorVersion%"
set "MsgSvc_SubDirectory=%IT_Group_Name%\AppsAnywhere\MessageService\V%MsgSvc_ScriptMajorVersion%"
set "MsgSvc_InstallDir=%Programfiles%\%MsgSvc_SubDirectory%"
set "MsgSvc_InstallDirRef=%%Programfiles%%\%MsgSvc_SubDirectory%"
set "MsgSvc_DataDir=%ProgramData%\%MsgSvc_SubDirectory%"
set "MsgSvc_DataDirRef=%%ProgramData%%\%MsgSvc_SubDirectory%"
set "MsgSvc_TempDir=%temp%\%MsgSvc_SubDirectory%"
set "MsgSvc_TempDirRef=%%temp%%\%MsgSvc_SubDirectory%"
set "MsgSvc_DataReg=hklm\Software\%MsgSvc_SubDirectory%"
set "MsgSvc_UninstallReg=%Uninstall_Registry_Location%\%MsgSvc_Firendly_Name%"
set "MsgSvc_UninstallReg_Old=%Uninstall_Registry_Location%\%MsgSvc_Firendly_Name_Old%"
set "MsgSvc_TaskSchdDir=\%MsgSvc_SubDirectory%"
set "MsgSvc_LogDir=%MsgSvc_DataDir%\Logs"
set "MsgSvc_UninstallFile=%MsgSvc_InstallDir%\Uninstall.bat"
set "MsgSvc_UninstallConfigFile=%MsgSvc_InstallDir%\Uninstall.cfg"

REM [Log Level Lookup Table]
REM set "LogLevel[Fatal]=0"
set "LogLevel[Error]=0"
set "LogLevel[Warning]=1"
set "LogLevel[Info]=2"
set "LogLevel[Verbose]=3"
set "LogLevel[Debug]=4"

REM [.NET Release Lookup Table]
set "DotNET_Release[4.5]=378389"
set "DotNET_Release[4.5.1]=378675"
set "DotNET_Release[4.5.2]=379893"
set "DotNET_Release[4.6]=393295"
set "DotNET_Release[4.6.1]=394254"
set "DotNET_Release[4.6.2]=394802"
set "DotNET_Release[4.7]=460798"
set "DotNET_Release[4.7.1]=461308"
set "DotNET_Release[4.7.2]=461808"
set "DotNET_Release[4.8]=528040"

REM [.NET Download Lookup Table]
set "DotNET_Download[4.5]=https://download.microsoft.com/download/B/A/4/BA4A7E71-2906-4B2D-A0E1-80CF16844F5F/dotNetFx45_Full_setup.exe"
set "DotNET_Download[4.5.1]=http://download.microsoft.com/download/7/4/0/74078A56-A3A1-492D-BBA9-865684B83C1B/NDP451-KB2859818-Web.exe"
set "DotNET_Download[4.5.2]=http://download.microsoft.com/download/9/A/7/9A78F13F-FD62-4F6D-AB6B-1803508A9F56/51209.34209.03/web/NDP452-KB2901954-Web.exe"
set "DotNET_Download[4.6]=http://download.microsoft.com/download/1/4/A/14A6C422-0D3C-4811-A31F-5EF91A83C368/NDP46-KB3045560-Web.exe"
set "DotNET_Download[4.6.1]=http://download.microsoft.com/download/3/5/9/35980F81-60F4-4DE3-88FC-8F962B97253B/NDP461-KB3102438-Web.exe"
set "DotNET_Download[4.6.2]=https://download.microsoft.com/download/D/5/C/D5C98AB0-35CC-45D9-9BA5-B18256BA2AE6/NDP462-KB3151802-Web.exe"
set "DotNET_Download[4.7]=http://download.microsoft.com/download/A/E/A/AEAE0F3F-96E9-4711-AADA-5E35EF902306/NDP47-KB3186500-Web.exe"
set "DotNET_Download[4.7.1]=https://download.microsoft.com/download/8/E/2/8E2BDDE7-F06E-44CC-A145-56C6B9BBE5DD/NDP471-KB4033344-Web.exe"
set "DotNET_Download[4.7.2]=https://download.microsoft.com/download/0/5/C/05C1EC0E-D5EE-463B-BFE3-9311376A6809/NDP472-KB4054531-Web.exe"
set "DotNET_Download[4.8]=https://download.visualstudio.microsoft.com/download/pr/014120d7-d689-4305-befd-3cb711108212/1f81f3962f75eff5d83a60abd3a3ec7b/ndp48-web.exe"

REM [RETURN CODES]
set "App_Installed_Code=1638"
set "App_Not_Installed_Code=0"
set "Changes_Made_Code=0"
set "App_Override_Code=0"
set "Internal_Error_Code=1359"
set "Unhandled_Error_Code=574"
set "Invalid_Parameter=87"
set "Prereq_Not_Found_Code=15639"
set "Debug_Complete=0"
set "Reboot_Required_Code=3010"

REM [Architecture Information]
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS_Arc=32-Bit || set OS_Arc=64-Bit
if "%PROCESSOR_ARCHITECTURE%" == "x86" (set CMD_Arc=32-Bit) else (set CMD_Arc=64-Bit)

REM [Main Function]
:Main
setlocal enabledelayedexpansion
call :Log_Initialize
call :Architecture_Check %*
call :Parse_Arguments %*
call :Get_Mode
if defined mode (
   if "%mode%" == "DEBUG" (
      call :Debug_Menu_Initialize
   ) else (
      call :Log_Header
      call :Override_Check
      call :Run_Methods %mode%
   )
) else (
   call :Log Error "mode not defined"
   call :Exit %Internal_Error_Code%
)

REM Hard-coded Exit in case of issues
exit 574

:Run_Methods
call :Log Info "Starting: %~1"
if "%~1" == "REGISTER" (
   call :DotNet_4x_Check
   call :DotNet_35_Check
   call :App_Installed_Check
) else if "%~1" == "ACTIVATE" (
   call :Firewall Add
   call :AV Add
   call :Service_AddRemove Stop
) else if "%~1" == "VIRTUALIZE" (
   call :License Add
   call :HW_Keys Load
   call :AppPath Add
   call :Solidworks_EULA Add
   call :RocScience_HASP Add
) else if "%~1" == "LAUNCH" (
   call :Service_LaunchClose Start
) else if "%~1" == "EXIT" (
   call :Service_LaunchClose Stop
   call :HW_Keys Save
) else if "%~1" == "DEVIRTUALIZE" (
   call :RocScience_HASP Remove
   call :Solidworks_EULA Remove
   call :AppPath Remove
   call :License Remove
   call :Service_AddRemove Stop
) else if "%~1" == "DEACTIVATE" (
   call :Firewall Remove
   call :AV Remove
) else if "%~1" == "KACE" (
   call :DotNet_4x_Check
   call :DotNet_35_Check
   call :App_Installed_Check
) else (
   call :Log Error "Invalid Mode: %~1"
   call :Exit %Internal_Error_Code%
)
call :Log Info "Completed: %~1"
call :exit %Changes_Made_Code%
REM ACTIVATE, DEACTIVATE, DEBUG, DEVIRTUALIZE, EXIT, KACE, LAUNCH, REGISTER, VIRTUALIZE
REM Hard-coded Exit in case of issues
exit 575

:Architecture_Check
setlocal enabledelayedexpansion
call :Log Debug "Checking OS/CMD Architecture"
if "%OS_Arc%" == "64-Bit" (
    if "%CMD_Arc%" == "32-Bit" (
      if exist "%Windir%\SysNative\cmd.exe" (
          call :Log Debug "OS/CMD Architecture Mismatch, Relaunching Script in Native CMD"
          start "" /wait /i /b /d "%Running_Directory%" "%Windir%\SysNative\cmd.exe" /c %~dpnx0 %*
          set "return=!errorlevel!"
          call :Log Debug "Native CMD Returned with Error Code: !return!"
          exit !return!
      ) else (
         call :Log Error "Detected OS/CMD Architecture Mismatch but unable to locate native CMD location"
         call :exit %Internal_Error_Code%
      )
    ) else (
      call :Log Debug "OS/CMD Architecture are both 64-bit"
    )
) else (
    call :Log Debug "OS is 32-bit"
)
endlocal
exit /b


:DotNet_4x_Check
setlocal enabledelayedexpansion
if defined UsrVar_Require_DotNet_4x (
   if /i NOT "%UsrVar_Require_DotNet_4x%" == "False" (
      if defined DotNET_Release[%UsrVar_Require_DotNet_4x%] (
         rem reg query "%DOTNET_4x_Registry_Location%" /v "Release" 2>nul | find "!DotNET_Release[%UsrVar_Require_DotNet_4x%]!" > nul
         for /f "tokens=2*" %%I in ('reg query "%DOTNET_4x_Registry_Location%" /v "Release" ^| find "REG_DWORD"') do (
            set /a Release=%%J
            if !Release! LSS !DotNET_Release[%UsrVar_Require_DotNet_4x%]! (
               call :log Warning "DotNet 4.x: .Net %UsrVar_Require_DotNet_4x% is Not Found"
               call :log Info "DotNet 4.x: Need at least !DotNET_Release[%UsrVar_Require_DotNet_4x%]! but !Release! was found"
               if "[%Auto_Install_DotNet_4x%]" == "[True]" (
                  if defined DotNET_Download[%UsrVar_Require_DotNet_4x%] (
                     if "[%Show_DotNet_4x_Installing_Message%]" == "[True]" (
                        call :1 "%DotNet_4x_Installing_Text%"
                     )
                     call :Log Verbose "DotNet 4.x: Downloading .Net %UsrVar_Require_DotNet_4x% installer from '!DotNET_Download[%UsrVar_Require_DotNet_4x%]!'"
                     bitsadmin /transfer ".NET %UsrVar_Require_DotNet_4x% Download" /priority foreground "!DotNET_Download[%UsrVar_Require_DotNet_4x%]!" "%~dp0\DotNet_%UsrVar_Require_DotNet_4x%.exe" > nul
                     if ERRORLEVEL 1 (
                        call :Log Error "DotNet 4.x: Failed to download .Net %UsrVar_Require_DotNet_4x% installer from '!DotNET_Download[%UsrVar_Require_DotNet_4x%]!'"
                        call :Show_Message "%DotNet_4x_Install_Error_Text%"
                        call :Exit %Prereq_Not_Found_Code%
                     ) else (
                        if NOT exist "%~dp0\DotNet_%UsrVar_Require_DotNet_4x%.exe" (
                           call :Log Error "DotNet 4.x: Download wasn't found in '%~dp0\DotNet_%UsrVar_Require_DotNet_4x%.exe'"
                           call :Show_Message "%DotNet_4x_Install_Error_Text%"
                           call :Exit %Prereq_Not_Found_Code%
                        ) else (
                           call :Log Verbose "DotNet 4.x: Successfully Downloaded Installer"
                           call :Log Verbose "DotNet 4.x: Installing .Net %UsrVar_Require_DotNet_4x% from '%~dp0\DotNet_%UsrVar_Require_DotNet_4x%.exe'"
                           start "" /wait "%~dp0\DotNet_%UsrVar_Require_DotNet_4x%.exe" /passive /norestart
                           if ERRORLEVEL 1 (
                              if ERRORLEVEL 3010 (
                                 if ERRORLEVEL 3011 (
                                    call :Log Error "DotNet 4.x: .NET %UsrVar_Require_DotNet_4x% Failed to Install with error !errorlevel!"
                                    call :Show_Message "%DotNet_4x_Install_Error_Text%"
                                    call :Exit %Prereq_Not_Found_Code%
                                 ) else (
                                    call :Log Info "DotNet 4.x: .NET %UsrVar_Require_DotNet_4x% Successfully Installed, Reboot Required"
                                    call :Show_Message "%DotNet_4x_Install_Reboot_Text%"
                                    call :Exit %Reboot_Required_Code%
                                 )
                              )
                              call :Log Error "DotNet 4.x: .NET %UsrVar_Require_DotNet_4x% Failed to Install with error !errorlevel!"
                              call :Show_Message "%DotNet_4x_Install_Error_Text%"
                              call :Exit %Prereq_Not_Found_Code%
                           ) else (
                              call :Log Info "DotNet 4.x: .NET %UsrVar_Require_DotNet_4x% Successfully Installed"
                           )
                        )
                     )
                  )
               ) else (
                  call :Log Warning "DotNet 4.x: Auto Install Disabled, User must manualy install"
                  call :Show_Message "%DotNet_4x_Error_Text%"
                  call :exit %Prereq_Not_Found_Code%
               )
            ) else (
               call :log Info "DotNet 4.x: .Net %UsrVar_Require_DotNet_4x% is Found"
            )
         )
      ) else (
         call :Log Error ".NET %UsrVar_Require_DotNet_4x% Release number not found"
         call :Exit %Internal_Error_Code%
      )
   )
)
endlocal
exit /b

:DotNet_35_Check
setlocal
if defined UsrVar_Require_DotNet_35 (
   if "[%UsrVar_Require_DotNet_35%]" == "[True]" (
      reg query "%DOTNET_35_Registry_Location%" /v "Install" 2>nul | find "1" > nul
      if ERRORLEVEL 1 (
         call :Log Warning "DotNet 3.5: .Net 3.5 was Not Found"
         if "[%Auto_Install_DotNet_35%]" == "[True]" (
            if "[%Show_DotNet_35_Installing_Message%]" == "[True]" (
               call :Show_Message "%DotNet_35_Installing_Text%"
            )
            call :Log Info "DotNet 3.5: Installing"
            Dism /online /Enable-Feature /FeatureName:"NetFx3"
            if ERRORLEVEL 1 (
               call :Log Error "DotNet 3.5: Failed to Install"
               call :Show_Message "%DotNet_35_Install_Error_Text%"
               call :exit %Prereq_Not_Found_Code%
            ) else (
               call :Log Info "DotNet 3.5: Successfully Installed"
            )
         ) else (
            call :Show_Message "%DotNet_35_Error_Text%"
            call :exit %Prereq_Not_Found_Code%
         )
      ) else (
         call :log Info "DotNet 3.5: .Net 3.5 was Found"
      )
   )
)
endlocal
exit /b

:App_Installed_Check
setlocal
if "%Shared_Machine%" == "True" (
   call :log Warning "Shared Machine, Setting All Detection Methods to Allow"
   set "Uninstall_GUID_Allowed=Allow"
   set "Primary_Exe_Allowed=Allow"
   set "UsrVar_SideBySide_Allowed=Allow"
   set "UsrVar_ProgramFolder_Allowed=Allow"
   set "UsrVar_LicenseData_Allowed=Allow"
   set "UsrVar_ProgramData_Allowed=Allow"
   set "UsrVar_RegistryData_Allowed=Allow"
)

REM Check Uninstall GUID
call :Log Info "Checking GUIDs"
if defined UsrVar_Uninstall_GUID (
   if /i NOT "%UsrVar_Uninstall_GUID%" == "False" (
      call :Check_Registry "%Uninstall_Registry_Location%\%UsrVar_Uninstall_GUID%" "%Uninstall_GUID_Allowed%"
      call :Check_Registry "%Uninstall_WOW64_Registry_Location%\%UsrVar_Uninstall_GUID%" "%Uninstall_GUID_Allowed%"
   ) else (
      call :log Info "Skipping GUID Check"
   )
) else (
   call :log Info "Skipping GUID Check"
   call :log Debug "UsrVar_Uninstall_GUID not defined"
)

REM Check Main EXE
call :Log Info "Checking Main exe"
if defined UsrVar_Exe_Location (
   if /i NOT "%UsrVar_Exe_Location%" == "False" (
      call :Check_Folder "%UsrVar_Exe_Location%" "%Primary_Exe_Allowed%"
   ) else (
      call :log Info "Skipping Main exe Check"
   )
) else (
   call :log Info "Skipping Main exe Check"
   call :log Debug "UsrVar_Exe_Location not defined"
)

REM Check AppPath for EXE
call :Log Info "Checking AppPath"
if defined UsrVar_Exe_Location (
   if /i NOT "%UsrVar_Exe_Location%" == "False" (
      call :Check_AppPath "%UsrVar_Exe_Location%" "%UsrVar_SideBySide_Allowed%"
   ) else (
      call :log Info "Skipping AppPath Check"
   )
) else (
   call :log Info "Skipping AppPath Check"
   call :log Debug "UsrVar_Exe_Location not defined"
)
REM Check Program Folder
call :Log Info "Checking Program Folder"
if defined UsrVar_ProgramFolder_Location (
   if /i NOT "%UsrVar_ProgramFolder_Location%" == "False" (
      call :Check_Folder "%UsrVar_ProgramFolder_Location%" "%UsrVar_ProgramFolder_Allowed%"
   ) else (
      call :log Info "Skipping Program Folder Check"
   )
) else (
   call :log Info "Skipping Program Folder Check"
   call :log Debug "UsrVar_ProgramFolder_Location not defined"
)
REM Check License
call :Log Info "Checking License"
if defined UsrVar_License_Location (
   if /i NOT "%UsrVar_License_Location%" == "False" (
      call :Check_License "%UsrVar_License_Location%" "%UsrVar_LicenseData_Allowed%"
   ) else (
      call :log Info "Skipping License Check"
   )
) else (
   call :log Info "Skipping License Check"
   call :log Debug "UsrVar_License_Location not defined"
)
REM Check Program Data
call :Log Info "Checking Program Data"
if defined UsrVar_ProgramData_Location (
   if /i NOT "%UsrVar_ProgramData_Location%" == "False" (
      call :Check_Folder "%UsrVar_ProgramData_Location%" "%UsrVar_ProgramData_Allowed%"
   ) else (
      call :log Info "Skipping Program Data Check"
   )
) else (
   call :log Info "Skipping Program Data Check"
   call :log Debug "UsrVar_ProgramData_Location not defined"
)
REM Check Registry Data
call :Log Info "Checking Registry Data"
if defined UsrVar_RegistryData_Location (
   if /i NOT "%UsrVar_RegistryData_Location%" == "False" (
      call :Check_Registry "%UsrVar_RegistryData_Location%" "%UsrVar_RegistryData_Allowed%"
   ) else (
      call :log Info "Skipping Registry Data Check"
   )
) else (
   call :log Info "Skipping Registry Data Check"
   call :log Debug "UsrVar_RegistryData_Location not defined"
)
endlocal
exit /b

:Check_AppPath <Exe_Location> <Allowed>
setlocal enabledelayedexpansion
set exe_found=False
call :log Verbose "AppPath: Checking for '%~nx1' Allowed: '%~2'"
reg query "%AppPath_Registry_location%\%~nx1" >nul 2>&1
if NOT ERRORLEVEL 1 (
   call :Log Debug "AppPath: Found entry for: '%~nx1'"
   for /f "tokens=1,2*" %%v in ('reg query "%AppPath_Registry_location%\%~nx1"') do (
      if "[%%v]" == "[Path]" (
         call :Log Debug "AppPath: Path Found: '%%x'"
         if exist "%%x\%~nx1" (
            call :Log Debug "AppPath: EXE Found: '%%x\%~nx1'"
            set exe_found=True
         ) else (
            call :Log Debug "AppPath: EXE Not Found: '%%x\%~nx1'"
            call :Log Verbose "AppPath: Found 'path' entry in AppPath but EXE not found at location specified: '%%x\%~nx1'"
            REM TODO: Check if AppPath was set by this script and cleanup if it was
         )
      )
      if "[%%v]" == "[(Default)]" (
         call :Log Debug "AppPath: EXE Location Found: '%%x'"
         if exist "%%x" (
            call :Log Debug "AppPath: EXE Found: '%%x'"
            set exe_found=True
         ) else (
            call :Log Debug "AppPath: EXE Not Found: '%%x'"
            call :Log Verbose "AppPath: Found 'Default' entry in AppPath but EXE not found at location specified: '%%x'"
            REM TODO: Check if AppPath was set by this script and cleanup if it was
         )
      )
   )
   if "[!exe_found!]" == "[True]" (
      if "%~2" == "Deny" (
         call :Log Warning "AppPath: Found: '%~nx1'"
         call :Show_Message "%App_Installed_Text%"
         call :exit %App_Installed_Code%
      ) else if "%~2" == "Warn" (
         call :Log Warning "AppPath: Found: '%~nx1'"
         call :Show_Message "%App_Reminent_Text%"
      ) else if "%~2" == "Allow" (
         call :log Verbose "AppPath: Found: '%~nx1'"
      ) else (
         call :Log Error "AppPath: Invalid Value: '%~2'"
         call :Show_Message "%Internal_Error_Text%"
         call :exit %Internal_Error_Code%
      )
   ) else (
      call :log Verbose "AppPath: '%~nx1' not Found"
   )
) else (
   call :log Verbose "AppPath: '%~nx1' not found"
)
endlocal
exit /b

:Check_License <item> <allowed>
setlocal enabledelayedexpansion
set "item=%~1"

if /i "!item:~0,2!" == "HK" (
   call :Log Info "License: Checking Registry: '!item!'"
   if /i "!item:~0,4!" == "HKCU" (
      call :Log Debug "License: Converting HKCU to HKU"
      if not defined SID (
         call :Get_Username
      )
      call set item=%%item:HKCU=HKU\!sid!%%
      call :Log Debug "License: '%item%' changed to '!item!'"
   )
   if "!item:~-1!" == "\" (
      call :Log Debug "License: Registry is Key"
      for /f %%v in ('reg query "!item:~0,-1!"') do (
         set value=%%v
         call :ShortenReg value
         call :Log Debug "License: Value: '!value!'"
         call :Log Debug "License: Value minus Item: '!value:%item:~0,-1%=!'"
         if NOT "!value:%item:~0,-1%=!" == "!value!" (
            call :Check_Registry "!item:~0,-1!" %2
         )
      )
      call :Log Debug "License: done comparing"
   ) else (
      call :Log Debug "License: Registry is Key + Value"
      call :ParseFile "!item!"
      call :strLen filename count
      set /a count+=1
      call set filepath=%%item:~0,-!count!%%
      call :Log Debug "License: Registry is '!filepath!' + '!filename!'"
      reg query "!filepath!" /v "!filename!">nul 2>&1
      if NOT ERRORLEVEL 1 (
         call :Check_Registry "!filepath!" %2
      )
   )
) else (
   call :Log Info "License: Checking Filesystem: '!item!'"
   if "!item:~-1!" == "\" (
      call :Log Debug "License: Path is Directory"
      >nul 2>nul dir /a-d "!item!*" && (
         call :Check_Folder "!item!" %2
      )
   ) else (
      call :Log Debug "License: Path is Directory + File"
      call :Check_Folder "!item!" %2
   )
)
endlocal
exit /b

:Check_Folder <Folder> <Allowed>
call :Log Verbose "Checking for folder: '%~1' Allowed: '%~2'"
if "%~1" == "" (
   call :Log Error "Check Folder: Arg[1] not Defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if "%~2" == "" (
   call :Log Error "Check Folder: Arg[2] not Defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if exist %1 (
   if "%~2" == "Deny" (
      call :Log Warning "Folder Found: '%~1'"
      call :Show_Message "%App_Installed_Text%"
      call :exit %App_Installed_Code%
   ) else if "%~2" == "Warn" (
      call :Log Warning "Folder Found: '%~1'"
      call :Show_Message "%App_Reminent_Text%"
   ) else if "%~2" == "Allow" (
      call :Log Verbose "Folder Found: '%~1'"
   ) else (
      call :Log Error "Check Folder: Invalid Value: '%~2'"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
   )
) else (
   call :log Verbose "Folder: '%~1' not Found"
)
exit /b

:Check_Registry <Registry> <Allowed>
call :log Verbose "Checking for Registry: '%~1' Allowed: '%~2'"
reg query "%~1" >nul 2>&1
if NOT ERRORLEVEL 1 (
   if "%~2" == "Deny" (
      call :Log Warning "Registry Found: '%~1'"
      call :Show_Message "%App_Installed_Text%"
      call :exit %App_Installed_Code%
   ) else if "%~2" == "Warn" (
      call :Log Warning "Registry Found: '%~1'"
      call :Show_Message "%App_Reminent_Text%"
   ) else if "%~2" == "Allow" (
      call :log Verbose "Registry Found: '%~1'"
   ) else (
      call :Log Error "Check Registry: Invalid Value: '%~2'"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
   )
) else (
   call :log Verbose "Registry: '%~1' not Found"
)
exit /b

:Firewall
setlocal enabledelayedexpansion
if "%~1" == "Add" (
   call :Log Info "Firewall: Adding Firewall Rules"
) else if "%~1" == "Remove" (
   if "%Shared_Machine%" == "True" (
      call :Log Warning "Firewall: Shared Machine, Firewall Rules will not be Removed"
      exit /b 0
   ) else (
      call :Log Info "Firewall: Removing Firewall Rules"
   )
) else (
   call :Log Error "Firewall: Invalid Firewall Mode: '%~1'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
call :Count_Items UsrVar_Firewall_Rule
if "[%UsrVar_Firewall_Allow_Main_exe%]" == "[True]" (
   call :Log Verbose "Firewall: Adding Automatic Rule"
   set /a UsrVar_Firewall_Rule+=1
   set "UsrVar_Firewall_Rule[!UsrVar_Firewall_Rule!]=%UsrVar_Exe_Location%"
)
call :Log Debug "Firewall: Found %UsrVar_Firewall_Rule%+1 Rules"
for /l %%i in (0,1,%UsrVar_Firewall_Rule%) do (
   if "%~1" == "Add" (
      call :Log Verbose "Firewall: Adding Firewall Rule: '!UsrVar_Firewall_Rule[%%i]!'"
      netsh advfirewall firewall add rule name="AppsAnywhere - %User_Friendly_Application_Name% - !UsrVar_Firewall_Rule[%%i]!" dir=in action=allow program="!UsrVar_Firewall_Rule[%%i]!
      if ERRORLEVEL 1 (
         if /i "%Allow_Firewall_Failure%" == "False" (
            call :Log Error "Firewall: Failed to Add '!UsrVar_Firewall_Rule[%%i]!'"
            call :Show_Message "%Internal_Error_Text%"
            call :exit %Internal_Error_Code%
         ) else (
            call :Log Warning "Firewall: Failed to Add '!UsrVar_Firewall_Rule[%%i]!'"
         )
      )
   ) else if "%~1" == "Remove" (
      call :log Verbose "Firewall: Removing Firewall Rule: '!UsrVar_Firewall_Rule[%%i]!'"
      netsh advfirewall firewall delete rule name="AppsAnywhere - %User_Friendly_Application_Name% - !UsrVar_Firewall_Rule[%%i]!"
      if ERRORLEVEL 1 (
         if /i "%Allow_Firewall_Failure%" == "False" (
            call :Log Error "Firewall: Failed to remove '!UsrVar_Firewall_Rule[%%i]!'"
            call :Show_Message "%Internal_Error_Text%"
            call :exit %Internal_Error_Code%
         ) else (
            call :Log Warning "Firewall: Failed to remove '!UsrVar_Firewall_Rule[%%i]!'"
         )
      )
   )
)
call :Log Info "Firewall: Done"
exit /b

:AV
setlocal enabledelayedexpansion
if "%~1" == "Add" (
   call :Log Info "AV: Adding AV Rules"
) else if "%~1" == "Remove" (
   if "%Shared_Machine%" == "True" (
      call :Log Warning "AV: Shared Machine, AV Rules will not be Removed"
      exit /b 0
   ) else (
      call :Log Info "AV: Removing AV Rules"
   )
) else (
   call :Log Error "AV: Invalid AV Mode: '%~1'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
set "defender=disabled"
for /f "tokens=1,3" %%A in ('sc query windefend') do (
   if "[%%A]" == "[STATE]" (
      if "[%%B]" == "[4]" (
         set "defender=enabled"
      )
      if "[%%B]" == "[0]" (
         set "defender=enabled"
      )
   )
)
call :Count_Items UsrVar_AV_Rule
if "[%Automatically_Add_AV_Rules%]" == "[True]" (
   call :Log Verbose "AV: Adding Automatic Rules"
   if defined UsrVar_Exe_Location (
      set /a UsrVar_AV_Rule+=1
      set "UsrVar_AV_Rule[!UsrVar_AV_Rule!]=%UsrVar_Exe_Location%"
   )
   if defined UsrVar_ProgramFolder_Location (
      set /a UsrVar_AV_Rule+=1
      set "UsrVar_AV_Rule[!UsrVar_AV_Rule!]=%UsrVar_ProgramFolder_Location%"
   )
)
call :Log Debug "AV: Found %UsrVar_AV_Rule%+1 Rules"
REM set UsrVar_AV_Rule=%errorlevel%
if "[%defender%]" == "[disabled]" (
   call :log Info "AV: Defender is disabled"
   if "%~1" == "Add" (
      if "[%Show_Alternate_AV_Instructions_Message%]" == "[True]" (
         set "AV_Rules="
         for /l %%i in (0,1,%UsrVar_AV_Rule%) do (
            set "AV_Rules=!AV_Rules!\n!UsrVar_AV_Rule[%%i]!"
         )
         if defined AV_Rules (
            call :Show_Message "%Alternate_AV_Text%\n!AV_Rules!"
         )
      )
   )
) else (
   for /l %%i in (0,1,%UsrVar_AV_Rule%) do (
      if "%~1" == "Add" (
         call :log Verbose "AV: Adding AV Rule: '!UsrVar_AV_Rule[%%i]!'"
         powershell -command "Add-MpPreference -ExclusionPath '!UsrVar_AV_Rule[%%i]!'"
         if ERRORLEVEL 1 (
            if /i "%Allow_AV_Failure%" == "False" (
               call :Log Error "AV: Failed to Add '!UsrVar_AV_Rule[%%i]!'"
               call :Show_Message "%Internal_Error_Text%"
               call :exit %Internal_Error_Code%
            ) else (
               call :Log Warning "AV: Failed to Add '!UsrVar_AV_Rule[%%i]!'"
            )
         )
         
      ) else if "%~1" == "Remove" (
         call :log Verbose "AV: Removing AV Rule: '!UsrVar_AV_Rule[%%i]!'"
         powershell -command "Remove-MpPreference -ExclusionPath '!UsrVar_AV_Rule[%%i]!'"
         if ERRORLEVEL 1 (
            if /i "%Allow_AV_Failure%" == "False" (
               call :Log Error "AV: Failed to remove '!UsrVar_AV_Rule[%%i]!'"
               call :Show_Message "%Internal_Error_Text%"
               call :exit %Internal_Error_Code%
            ) else (
               call :Log Warning "AV: Failed to remove '!UsrVar_AV_Rule[%%i]!'"
            )
         )
      )
   )
)
call :Log Info "AV: Done"

endlocal
exit /b



:HW_Keys <Load/Save>
setlocal enabledelayedexpansion
if "%~1" == "Load" (
   call :Log Info "HW_Keys: Loading HW Keys"
) else if "%~1" == "Save" (
   call :Log Info "HW_Keys: Saving HW Keys"
) else (
   call :Log Error "HW_Keys: Invalid Mode: '%~1'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)

call :Count_Items UsrVar_HWKey_Machine
for /l %%I in (0,1,%UsrVar_HWKey_Machine%) do (
   call :log Verbose "HW_Keys: Machine: Processing: '!UsrVar_HWKey_Machine[%%I]!'"
   set "item=!UsrVar_HWKey_Machine[%%I]!"
   call :HW_Key_SaveLoad %1 "!UsrVar_HWKey_Machine[%%I]!" "%HW_Key_Machine_Location%"
)
call :Count_Items UsrVar_HWKey_User
for /l %%I in (0,1,%UsrVar_HWKey_User%) do (
   call :log Verbose "HW_Keys: User: Processing: '!UsrVar_HWKey_User[%%I]!'"
   set "item=!UsrVar_HWKey_User[%%I]!"
   if not defined full_username (
      call :Get_Username
   )
   call :HW_Key_SaveLoad %1 "!UsrVar_HWKey_User[%%I]!" "%HW_Key_User_Location%\%full_username%"
)
rem full_username
endlocal
exit /b

:HW_Key_SaveLoad <Save/Load> <Key> <Save/Load Location> 
if "%~1" == "Load" (
   call :Log Info "HW_Key: Loading HW Key"
) else if "%~1" == "Save" (
   call :Log Info "HW_Key: Saving HW Key"
) else (
   call :Log Error "HW_Key: Invalid Mode: '%~1'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if "%~2" == "" (
   call :Log Error "HW_Key: Key not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)

if "%~3" == "" (
   call :Log Error "HW_Key: Location not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)

if not exist "%~3" (
   mkdir "%~3"
)

set "item=%~2"
if "%~1" == "Save" (
   if "!item:~0,2!" == "HK" (
      call :log Verbose "HW_Key: Saving Registry Key: '!item!'"
      if "!item:~0,4!" == "HKCU" (
         call :Log Debug "HW_Key: Converting HKCU to HKU"
         if not defined SID (
            call :Get_Username
            if ERRORLEVEL 1 (
               call :Log Warning "Unable to get SID cannot save HW Key"
               exit /b %Internal_Error_Code%
            )
         )
         call set item=%%item:HKCU=HKU\!sid!%%
         call :Log Debug "HW_Key: '%item%' changed to '!item!'"
      )
      call :ParseFile "!item!"
      call :strLen filename count
      set /a count+=1
      call set filepath=%%item:~0,-!count!%%
      call :Count_Delims !filename!
      set /a delims+=1
      call :Log Debug "HW_Key: Path: '!filepath!' Name: '!filename!' Delims: '!delims!'"
      call :HW_Key_Get_Reg_Val
      call :Log Verbose "HW_Key: value of '!item!' is '!value!'"
      if not exist "%~3\%User_Friendly_Application_Name%\Reg\" (
         mkdir "%~3\%User_Friendly_Application_Name%\Reg\"
      )
      echo/!value!>"%~3\%User_Friendly_Application_Name%\Reg\!filename!"
      
   ) else (
      call :log Verbose "HW_Key: Saving File: '!item!'"
      rem call :ParseFile "!item!"
      if not exist "%~3\%User_Friendly_Application_Name%\File\" (
         mkdir "%~3\%User_Friendly_Application_Name%\File\"
      )
      copy /B /V /Y "!item!" "%~3\%User_Friendly_Application_Name%\File\"
      if ERRORLEVEL 1 (
         call :Log Warning "HW_Key: Save Failed: Code: !errorlevel!"
      ) else (
         call :log Info "HW_Key: Save Successful"
      )
   )
) else (
   if "!item:~0,2!" == "HK" (
      call :log Verbose "HW_Key: Loading Registry Key: '!item!'"
      if "!item:~0,4!" == "HKCU" (
         call :Log Debug "HW_Key: Converting HKCU to HKU"
         if not defined SID (
            call :Get_Username
         )
         call set item=%%item:HKCU=HKU\!sid!%%
         call :Log Debug "HW_Key: '%item%' changed to '!item!'"
      )
      call :ParseFile "!item!"
      if exist "%~3\%User_Friendly_Application_Name%\Reg\!filename!" (
         call :strLen filename count
         set /a count+=1
         call set filepath=%%item:~0,-!count!%%
         call :Count_Delims !filename!
         set /a delims+=1
         call :Log Debug "HW_Key: Path: '!filepath!' Name: '!filename!' Delims: '!delims!'"
      
         for /F "usebackq tokens=1*" %%L in ("%~3\%User_Friendly_Application_Name%\Reg\!filename!") do (
            set "type=%%L"
            set "value=%%M"
         )
         call :Log Verbose "HW_Key: value of '!item!' is of type '!type!' with value '!value!'"
         REG ADD "!filepath!" /v "!filename!" /t "!type!" /d "!value!" /f /reg:64
         if ERRORLEVEL 1 (
            call :Log Warning "HW_Key: Load Failed: Could not load '!filepath!' '!filename!' '!type!' '!value!' Code: !errorlevel!"
         ) else (
            call :log Info "HW_Key: Load Successful"
         )
      ) else (
         call :Log Warning "HW_Key: No Saved Value in %~3\%User_Friendly_Application_Name%\Reg\!filename!"
      )
      
   ) else (
      call :log Verbose "HW_Key: Loading File: '!item!'"
      rem call :ParseFile "!item!"
      call :ParseFile "!item!"
      if exist "%~3\%User_Friendly_Application_Name%\File\!filename!" (
         if not exist "!FileDrive!!filepath!" (
            mkdir "!FileDrive!!filepath!"
         )
         copy /B /V /Y "%~3\%User_Friendly_Application_Name%\File\!filename!" "!FileDrive!!filepath!"
         if ERRORLEVEL 1 (
            call :Log Warning "HW_Key: Load Failed: Could not copy '%~3\%User_Friendly_Application_Name%\File\!filename!' to '!FileDrive!!filepath!' Code: !errorlevel!"
         ) else (
            call :log Verbose "HW_Key: Load Successful"
         )
      ) else (
         call :Log Warning "HW_Key: No Saved Value in '%~3\%User_Friendly_Application_Name%\File\!filename!'"
      )
   )
)
   
exit /b




REM This is needed because you can't use delayed expansion in a FOR loop's arguments (in this case for delims variable)
:HW_Key_Get_Reg_Val
for /f "tokens=%delims%* skip=2" %%p IN ('REG QUERY "%filepath%" /v "%filename%" /reg:64 2^>nul') do set "value=%%p %%q"
exit /b

:HW_Keys_Machine <Load/Save>
setlocal enabledelayedexpansion
rem full_username
endlocal
exit /b

:HW_Keys_User <Load/Save>
setlocal enabledelayedexpansion
rem full_username
endlocal
exit /b

:RocScience_HASP <Add/Remove>
if "[%UsrVar_Rocsci_Drivers_Enabled%]" == "[True]" (
   call :Log Info "RocScience: Running HASP Configuration
   if "[%~1]" == "[Add]" (
      call :Log Verbose "RocScience: Adding HASP Driver"
      "%ProgramFiles(x86)%\Rocscience\RocActivate\haspdinst.exe" -install -killprocess -fi -nomsg
      if ERRORLEVEL 1 (
         call :Log Warning "RocScience: Failed to add Driver"
      ) else (
         call :Log Verbose "RocScience: Driver added Successfully"
      )
   ) else if "[%~1]" == "[Remove]" (
      if "%Shared_Machine%" == "True" (
         call :Log Warning "RocScience: Shared Computer, HASP Driver will not be Removed"
      ) else (
         call :Log Verbose "RocScience: Removing HASP Driver"
         "%ProgramFiles(x86)%\Rocscience\RocActivate\haspdinst.exe" -fr -killprocess -purge -nomsg
         if ERRORLEVEL 1 (
            call :Log Warning "RocScience: Failed to add Driver"
         ) else (
            call :Log Verbose "RocScience: Driver added Successfully"
         )
      )
   ) else (
      call :Log Error "RocScience: Invalid Mode: '%~1'"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
   )
)
exit /b

:Solidworks_EULA <Add/Remove>
if NOT "[%UsrVar_Solidworks_EULA_Enabled%]" == "[True]" (
   exit /b
)
call :Log Info "Solidworks: Running EULA Configuration"
if not defined UsrVar_Solidworks_Version (
   call :log Error "Solidworks: UsrVar_Solidworks_Version not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_Solidworks_Service_Pack (
   call :log Error "Solidworks: UsrVar_Solidworks_Service_Pack not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_Solidworks_Service_Pack2 (
   call :log Error "Solidworks: UsrVar_Solidworks_Service_Pack2 not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_Solidworks_Composer_Short_Version (
   call :log Error "Solidworks: UsrVar_Solidworks_Composer_Short_Version not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_Solidworks_Composer_Long_Version (
   call :log Error "Solidworks: UsrVar_Solidworks_Composer_Long_Version not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined actual_username (
   call :Get_Username
   if ERRORLEVEL 1 (
      call :Log Warning "Unable to get Username, Solidworks EULA cannot be bypassed"
      exit /b %Internal_Error_Code%
   )
)

if "%~1" == "Add" (
   call :Log Info "Solidworks: Adding EULAS"
   call :Log Verbose "Solidworks: Adding Solidworks EULA"
   reg add "HKU\%sid%\Software\Solidworks\Solidworks %UsrVar_Solidworks_Version%\Security" /v "EULA Accepted %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack% %computername% %actual_username%" /t REG_SZ /d "Yes" /f
   if NOT "%UsrVar_Solidworks_Composer_Short_Version%" == "False" (
      if NOT "%UsrVar_Solidworks_Composer_Long_Version%" == "False" (
         call :Log Verbose "Solidworks: Adding Composer EULA"
         reg add "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "EulaAccepted %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Composer_Long_Version% %computername% %actual_username%" /t REG_DWORD /d "1" /f
         reg add "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "EulaAccepted" /t REG_DWORD /d "1" /f
         reg add "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "Composer.EulaAccepted" /t REG_DWORD /d "1" /f
         reg add "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "Sync.EulaAccepted" /t REG_DWORD /d "1" /f
         reg add "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "RefreshProgressUI" /t REG_DWORD /d "1" /f
      )
   )
   if NOT "%UsrVar_Solidworks_Service_Pack2%" == "False" (
      call :Log Verbose "Solidworks: Adding eDrawings EULA"
      reg add "HKU\%sid%\Software\eDrawings\e%UsrVar_Solidworks_Version%\General" /v "ShowLicense %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack2% %computername% %actual_username%" /t REG_DWORD /d "1" /f
      reg add "HKU\%sid%\Software\eDrawings\e%UsrVar_Solidworks_Version%\General" /v "ShowProLicense %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack2% %computername% %actual_username%" /t REG_DWORD /d "1" /f
   )
   call :Log Verbose "Solidworks: Adding SRAC EULA"
   reg add "HKU\%sid%\Software\srac" /v "EULA Accepted %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack% %computername% %actual_username%" /t REG_SZ /d "1" /f
) else if "%~1" == "Remove" (
   call :Log Info "Solidworks: Removing EULAS"
   call :Log Verbose "Solidworks: Removing Solidworks EULA"
   reg delete "HKU\%sid%\Software\Solidworks\Solidworks %UsrVar_Solidworks_Version%\Security" /v "EULA Accepted %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack% %computername% %actual_username%" /f
   if NOT "%UsrVar_Solidworks_Composer_Short_Version%" == "False" (
      if NOT "%UsrVar_Solidworks_Composer_Long_Version%" == "False" (
         call :Log Verbose "Solidworks: Removing Composer EULA"
         reg delete "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "EulaAccepted %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Composer_Long_Version% %computername% %actual_username%" /f
         if "%Shared_Machine%" == "True" (
            call :Log Warning "Solidworks: Shared Computer, Shared EULA keys will not be Removed"
         ) else (
            reg delete "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "EulaAccepted" /f
            reg delete "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "Composer.EulaAccepted" /f
            reg delete "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "Sync.EulaAccepted" /f
            reg delete "HKU\%sid%\Software\Solidworks\Dassault Systemes\Composer\%UsrVar_Solidworks_Composer_Short_Version%\Preferences" /v "RefreshProgressUI" /f
         )
      )
   )
   if NOT "%UsrVar_Solidworks_Service_Pack2%" == "False" (
      call :Log Verbose "Solidworks: Removing eDrawings EULA"
      reg delete "HKU\%sid%\Software\eDrawings\e%UsrVar_Solidworks_Version%\General" /v "ShowLicense %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack2% %computername% %actual_username%" /f
      reg delete "HKU\%sid%\Software\eDrawings\e%UsrVar_Solidworks_Version%\General" /v "ShowProLicense %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack2% %computername% %actual_username%" /f
   )
   call :Log Verbose "Solidworks: Removing SRAC EULA"
   reg delete "HKU\%sid%\Software\srac" /v "EULA Accepted %UsrVar_Solidworks_Version% %UsrVar_Solidworks_Service_Pack% %computername% %actual_username%" /f
   REM TODO: Cleanup empty Registry Keys left behind
) else (
   call :Log Error "Solidworks: Invalid Mode: '%~1'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
call :Log Info "Solidworks: Done"

exit /b

:AppPath <Add/Remove> <Exe Location>
if "[%~2]" == "[]" (
   if defined UsrVar_Exe_Location (
      call :AppPath %1 "%UsrVar_Exe_Location%"
   )
   exit /b
)
if "[%Auto_Set_AppPath%]" == "[True]" (
   reg query "%AppPath_Registry_location%\%~nx2" >nul 2>&1
   if ERRORLEVEL 1 (
      REM if add, add, if remove, error
      if "[%~1]" == "[Add]" (
         if "%Shared_Machine%" == "True" (
            call :Log Warning "AppPath: Shared Computer, AppPath will not be Added"
         ) else (
            call :Log Info "AppPath: Adding '%AppPath_Registry_location%\%~nx2' '%~dpnx2'"
            reg add "%AppPath_Registry_location%\%~nx2" /ve /t REG_SZ /d "%~dpnx2" /f
            reg add "%AppPath_Registry_location%\%~nx2" /v "%AppPath_Indicator%" /t REG_SZ /d "%User_Friendly_Application_Name%" /f
         )
      ) else if "[%~1]" == "[Remove]" (
         call :log Warning "AppPath:  %AppPath_Registry_location%\%~nx2 Not Found"
      ) else (
         call :log Error "AppPath: Mode is Invalid: %~1"
         call :Show_Message "%Internal_Error_Text%"
         call :exit %Internal_Error_Code%
      )
   ) else (
      REM if add, abort, if remove, remove
      if "[%~1]" == "[Add]" ( 
         call :log Info "AppPath: %AppPath_Registry_location%\%~nx2 already exists"
      ) else if "[%~1]" == "[Remove]" (
         for /f "tokens=2*" %%I in ('reg query "%AppPath_Registry_location%\%~nx2" /v "%AppPath_Indicator%" ^| find "REG_SZ"') do (
            if "%%J" == "%User_Friendly_Application_Name%" (
               if "%Shared_Machine%" == "True" (
                  call :Log Warning "AppPath: Shared Computer, AppPath will not be Removed"
               ) else (
                  call :Log Info "AppPath: Removing '%AppPath_Registry_location%\%~nx2'"
                  reg delete "%AppPath_Registry_location%\%~nx2" /f
               )
            ) else (
               call :log Info "AppPath: %AppPath_Registry_location%\%~nx2 was not added by this script"
            )
         )
      ) else (
         call :log Error "AppPath: Mode is Invalid: %~1"
         call :Show_Message "%Internal_Error_Text%"
         call :exit %Internal_Error_Code%
      )
   )
   rem reg query "%AppPath_WOW64_Registry_location%\%~nx2" >nul 2>&1
)
exit /b

:License <Add/Remove>
setlocal enabledelayedexpansion
if "[%UsrVar_ADSK_License_Enabled%]" == "[True]" (
   call :Log Info "Licensing: Running Autodesk Licensing"
   call :Adsk_License %~1
)
if "[%~1]" == "[Add]" (
   call :Activate_License
) else if "[%~1]" == "[Remove]" (
   call :Deactivate_License
)
endlocal
exit /b

:ADSK_License <Add/Remove>
setlocal enabledelayedexpansion
if "[%~1]" == "[]" (
   call :log Error "ADSK License: Mode is Undefined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined ADSK_Remove_License (
   call :log Error "ADSK License: ADSK_Remove_License not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_ADSK_Product_Version (
   call :log Error "ADSK License: UsrVar_ADSK_Product_Version not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_ADSK_License_Server (
   call :log Error "ADSK License: UsrVar_ADSK_License_Server not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_ADSK_Language (
   call :log Error "ADSK License: UsrVar_ADSK_Language not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_ADSK_Product_Key (
   call :log Error "ADSK License: UsrVar_ADSK_Product_Key not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_ADSK_Serial_Number (
   call :log Error "ADSK License: UsrVar_ADSK_Serial_Number not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if not defined UsrVar_ADSK_Config_File (
   call :log Error "ADSK License: UsrVar_ADSK_Config_File not defined"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if NOT exist "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\Version.ini" (
   call :log Error "ADSK License: Version.ini file not found at '%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\Version.ini'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
for /f "usebackq delims== tokens=1,2*" %%I in ("%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\Version.ini") do (
   if "[%%I]" == "[version]" (
      set "ADSK_Licensing_Version=%%J"
   )
)
call :log Verbose "ADSK License: Got Version '%ADSK_Licensing_Version%' from Version.ini"
if not defined ADSK_Licensing_Version (
   call :log Error "ADSK License: Error getting version from Version.ini"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if NOT exist "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\%ADSK_Licensing_Version%\helper\AdskLicensingInstHelper.exe" (
   call :log Error "ADSK License: AdskLicensingInstHelper.exe not found at '%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\%ADSK_Licensing_Version%\helper\AdskLicensingInstHelper.exe'"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
if "[%~1]" == "[Add]" (
   call :log Info "ADSK License: Mode is '%~1'"
   REM Apply Autodesk Licensing Permissions
   call :log Verbose "ADSK License: Updating Permissions"
   icacls "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing" /grant "LOCAL SERVICE":F
   icacls "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing" /grant "LOCAL SERVICE":^(OI^)^(CI^)F
   icacls "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing" /grant "Everyone":F
   icacls "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing" /grant "Everyone":^(OI^)^(CI^)F
   icacls "%ProgramData%\Autodesk\AdskLicensingService" /grant "LOCAL SERVICE":F
   icacls "%ProgramData%\Autodesk\AdskLicensingService" /grant "LOCAL SERVICE":^(OI^)^(CI^)F
   icacls "%ProgramData%\Autodesk\AdskLicensingService" /grant "Everyone":F
   icacls "%ProgramData%\Autodesk\AdskLicensingService" /grant "Everyone":^(OI^)^(CI^)F
   REM Start the Autodesk Licensing Desktop Service and register the license information
   call :log Verbose "ADSK License: Starting Service"
   call :Manage_Service AdskLicensingService Start
   call :log Verbose "ADSK License: Installing License"
   call :log Debug "ADSK License: Command: '%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\%ADSK_Licensing_Version%\helper\AdskLicensingInstHelper.exe' register --pv %UsrVar_ADSK_Product_Version% --lic_servers %UsrVar_ADSK_License_Server% --lm network --lt single --el %UsrVar_ADSK_Language% --prod_key %UsrVar_ADSK_Product_Key% --serial_number %UsrVar_ADSK_Serial_Number% --config_file '%UsrVar_ADSK_Config_File%'"
   "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\%ADSK_Licensing_Version%\helper\AdskLicensingInstHelper.exe" register --pv %UsrVar_ADSK_Product_Version% --lic_servers %UsrVar_ADSK_License_Server% --lm network --lt single --el %UsrVar_ADSK_Language% --prod_key %UsrVar_ADSK_Product_Key% --serial_number %UsrVar_ADSK_Serial_Number% --config_file "%UsrVar_ADSK_Config_File%"
   if ERRORLEVEL 1 (
      call :log Warning "ADSK License: License Install Failed with Errorcode: !errorcode!"
   ) else (
      call :log Info "ADSK License: License Installed Successfully"
   )
) else if "[%~1]" == "[Remove]" (
   call :log Info "ADSK License: Mode is '%~1'"
   if "%ADSK_Remove_License" == "True" (
      if "%Shared_Machine%" == "True" (
         call :Log Warning "ADSK License: Shared Computer, License will not be Removed"
      ) else (
         call :log Verbose "ADSK License: Starting Service"
         call :Manage_Service AdskLicensingService Start
         call :log Verbose "ADSK License: Uninstalling License"
         call :log Debug "ADSK License: Command: '%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\%ADSK_Licensing_Version%\helper\AdskLicensingInstHelper.exe' deregister --pv %UsrVar_ADSK_Product_Version% --prod_key %UsrVar_ADSK_Product_Key%"
         "%CommonProgramFiles(x86)%\Autodesk Shared\AdskLicensing\%ADSK_Licensing_Version%\helper\AdskLicensingInstHelper.exe" deregister --pv %UsrVar_ADSK_Product_Version% --prod_key %UsrVar_ADSK_Product_Key%
         if ERRORLEVEL 1 (
             call :log Warning "ADSK License: License Uninstall Failed with Errorcode: !errorcode!"
         ) else (
             call :log Info "ADSK License: License Uninstalled Successfully"
         )
      )
   )
) else (
   call :log Error "ADSK License: Mode is Invalid: %~1"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
endlocal
exit /b

:Service_AddRemove <Start/Stop>
setlocal enabledelayedexpansion
if "[%~1]" == "[]" (
      call :log Error "Service Add/Remove: Mode is Undefined"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
)
if "[%~1]" == "[Start]" (
   call :log Info "Service Add/Remove: Mode is '%~1'"
) else if "[%~1]" == "[Stop]" (
   call :log Info "Service Add/Remove: Mode is '%~1'"
) else (
   call :log Error "Service Add/Remove: Mode is Invalid: %~1"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
call :Count_Items UsrVar_Service_AddRemove
for /l %%i in (0,1,%UsrVar_Service_AddRemove%) do (
   call :log Verbose "Service Add/Remove: %~1: '!UsrVar_Service_AddRemove[%%i]!'"
   call :Manage_Service "!UsrVar_Service_AddRemove[%%i]!" %1
)
endlocal
exit /b

:Service_LaunchClose <Start/Stop>
setlocal enabledelayedexpansion
if "[%~1]" == "[]" (
      call :log Error "Service Launch/Close: Mode is Undefined"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
)
if "[%~1]" == "[Start]" (
   call :log Info "Service Launch/Close: Mode is '%~1'"
) else if "[%~1]" == "[Stop]" (
   call :log Info "Service Launch/Close: Mode is '%~1'"
) else (
   call :log Error "Service Launch/Close: Mode is Invalid: %~1"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
call :Count_Items UsrVar_Service_LaunchClose
for /l %%i in (0,1,%UsrVar_Service_LaunchClose%) do (
   call :log Verbose "Service Launch/Close: %~1: '!UsrVar_Service_LaunchClose[%%i]!'"
   call :Manage_Service "!UsrVar_Service_LaunchClose[%%i]!" %1
)
endlocal
exit /b

:Manage_Service <Service> <Start/Stop>
setlocal enabledelayedexpansion
if "[%~1]" == "[]" (
      call :log Error "Service: Service Undefined"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
)
if "[%~2]" == "[]" (
      call :log Error "Service: Mode for Service '%~1' Undefined"
      call :Show_Message "%Internal_Error_Text%"
      call :exit %Internal_Error_Code%
)
if "[%~2]" == "[Start]" (
   call :log Info "Service: Mode for Service '%~1' is '%~2'"
   sc query "%~1" >nul
   if NOT ERRORLEVEL 1 (
      cmd /c exit 0
      sc start "%~1"
      if errorlevel 1 (
         call :log Warning "Service: Service Failed to be Started: '%~1'"
      ) else (
         call :log Info "Service: Service Successfully Started: '%~1'"
      )
   ) else (
      call :log Warning "Service: Service doesn't exist: '%~1'"
   )
) else if "[%~2]" == "[Stop]" (
   call :log Info "Service: Mode for Service '%~1' is '%~2'"
   sc query "%~1" >nul
   if NOT ERRORLEVEL 1 (
      cmd /c exit 0
      sc stop "%~1"
      if errorlevel 1 (
         call :log Warning "Service: Service Failed to be Stopped: '%~1'"
      ) else (
         call :log Info "Service: Service Successfully Stopped: '%~1'"
      )
   ) else (
      call :log Warning "Service: Service doesn't exist: '%~1', Ignoring..."
   )
) else (
   call :log Error "Service: Mode for Service %~1 Invalid: %~2"
   call :Show_Message "%Internal_Error_Text%"
   call :exit %Internal_Error_Code%
)
endlocal
exit /b

:ShortenReg <Reg_Dir>
call set Shorten_Reg_Value=%%%~1%%
set Shorten_Reg_Value=%Shorten_Reg_Value:HKEY_LOCAL_MACHINE\=HKLM\%
set Shorten_Reg_Value=%Shorten_Reg_Value:HKEY_CURRENT_USER\=HKCU\%
set Shorten_Reg_Value=%Shorten_Reg_Value:HKEY_USERS\=HKU\%
set Shorten_Reg_Value=%Shorten_Reg_Value:HKEY_CLASSES_ROOT\=HKCR\%
set %~1=%Shorten_Reg_Value%
exit /b

:strLen
setlocal enabledelayedexpansion
set len=0
:strLen_Loop
   if not "!%~1:~%len%!"=="" set /A len+=1 & goto :strLen_Loop
(endlocal & set "%~2=%len%")
exit /b

:Count_Delims <item>
set delims=0
:Count_Delims_Loop
if NOT "[%~1]" == "[]" (
   set /a delims+=1
   shift
   goto :Count_Delims_Loop
)
exit /b

:ParseFile <Path>
set "FileName=%~nx1"
set "FilePath=%~p1"
set "FileDrive=%~d1"
exit /b

:Count_Items <Var>
setlocal enabledelayedexpansion
set count=0
set item=%~1
:Count_Items_Loop
if defined %item%[%count%] (
   set /a count+=1
   goto :Count_Items_Loop
)
set /a count-=1
endlocal & set "%item%=%count%" & exit /b

:Log_Initialize
if defined Log_Location (
   if not exist "%Log_Location%" (
      mkdir "%Log_Location%"
      if ERRORLEVEL 1 (
         rem call :Display_Message Error "Internal Error\n\nUnable to Initialize log:\nUnable to Create Directory"
         goto :Exit %Invalid_Parameter%
      )
   )
) else (
   rem call :Display_Message Error "Internal Error\n\nUnable to Initialize log:\nLocation not defined"
   goto :Exit %Invalid_Parameter%
)
if NOT defined Log_File (
   rem call :Display_Message Error "Internal Error\n\nUnable to Initialize log:\nFile not defined"
   goto :Exit %Invalid_Parameter%
)
if exist "%Override_Location%\DEBUG" (
   set "LogLevel=%LogLevel[Debug]%"
)
if exist "%Override_Location%\%Debug_Override_Name%" (
   set "LogLevel=%LogLevel[Debug]%"
)
exit /b 0

:Log_Header
if defined Arg_LogLevel (
   set "LogLevel=%Arg_LogLevel%"
   call :Log Warning "Log Level overriden to: %Arg_LogLevel%"
)
if "%mode%" == "REGISTER" (
   if defined Clear_Log_On_Register (
      if /i "%Clear_Log_On_Register%" == "True" (
         if exist "%Log_Location%\%Log_File%" (
            del /q "%Log_Location%\%Log_File%" >nul 2>&1
         )
      )
   )
)
call :Log Info "Log Started"
call :Log Info "Script Version: %Current_Version%"
call :Log Info "Log Level: %LogLevel%"
call :Log Info "Mode: %mode%"
net session >nul 2>&1
if ERRORLEVEL 1 (
   call :Log Warning "Elevated: False"
) else (
   call :Log Info "Elevated: True"
)
call :Log Info "OS Architecture: %OS_Arc%"
call :Log Info "CMD Architecture: %CMD_Arc%"
if NOT "%CMD_Arc%" == "%OS_Arc%" (
   call :Log Error "OS/CMD Architecture Mismatch: %OS_Arc% vs %CMD_Arc%"
   call :Exit %Internal_Error_Code%
)

if "%LogLevel%" == "%LogLevel[Debug]%" (
   call :Log Debug "User Variables:"
   FOR /F "tokens=1,2* Delims==" %%V IN ('set ^| findstr /ibc:UsrVar') DO (
      echo %%V=%%W
      call :Log Debug "%%V = %%W"
   )
)
exit /b 0

:log <Level> <Description>
setlocal enabledelayedexpansion
if "%mode%" == "" (set "mode=UNKNOWN")
if "%mode%" == "DEBUG" echo\%date% %time% %User_Friendly_Application_Name% %Mode% %~1: %~2
if "!LogLevel[%~1]!" leq "%LogLevel%" echo\%date% %time% %User_Friendly_Application_Name% %Mode% %~1: %~2 >>"%Log_Location%\%Log_File%"
endlocal
exit /b

:Get_Mode
REM Determine Variables from Environment
REM If there are multiple sources available to determine mode, they are prioritized with Arguments first, then Built-in, and finally Automatic.

REM Check for Arguments defining mode
if defined arg_mode (
   set mode=%arg_mode%
   call :log Debug "Got mode from Arguments"
) else (
   if defined override_mode (
      set mode=%override_mode%
      call :log Debug "Got mode from Builtin Override"
   ) else (
      REM Determine mode from name
      if NOT "!Running_Directory:%Cloudpaging_Profiles%=!" == "%Running_Directory%" (
         for /f "usebackq tokens=1 delims=_" %%u in ('%~n0') do set mode=%%u
         call :log Debug "Got mode from Script Name"
      ) else (
         REM Determine mode from Directory
         if NOT "!Running_Directory:%KACE_Kbots%=!" == "%Running_Directory%" (
             set mode=KACE
             call :log Debug "Got mode from Directory"
         )
      )
   )
)
if NOT defined mode (
   set mode=DEBUG
   call :Log Warning "Unable to determine mode, DEBUG enabled"
)
exit /b 0

:Get_Username
REM Get User running directory
call :log Info "Getting Username"
rem set "Running_Directory=C:\ProgramData\Endeavors Technologies\StreamingCore\Profiles\ENGRAdmin\Sessions\0\Applications\{1A91397E-F274-42F7-A513-69963108434A}\CAE\"
if NOT "!Running_Directory:%Cloudpaging_Profiles%=!" == "%Running_Directory%" (
   call :log Verbose "Getting username from Run Directory"
   set Running_Directory=!Running_Directory:%Cloudpaging_Profiles%=!
   for /f "usebackq tokens=1 delims=\" %%u in ('!Running_Directory!') do set actual_username=%%u
) else (
   if NOT "%username%" == "%computername%$" (
      call :log Verbose "Getting username from environment variable"
      set actual_username=%username%
   ) else (
      rem Check Active Connections for User
      where query >nul 2>&1
      if NOT ERRORLEVEL 1 (
         SET "potential_username="
         SET "multiple_users="
         for /f "usebackq tokens=2" %%u IN (`query session ^| findstr /C:Active`) do (
            if defined potential_username ( 
               "multiple_users=True"
            ) else ( 
               set "potential_username=%%u"
            )
         )
         if NOT defined multiple_users (
            call :log Verbose "Getting username from active user"
            call set actual_username=%%potential_username%%
         ) else (
            call :Log Warning "Running as system, multiple users active, unable to identify username"
         )
      ) else (
         call :Log Warning "Running as system, query not available, unable to identify username"
         rem call :exit %Internal_Error_Code%
      )
   )
)
call :Log Info "Username=%actual_username%"
for /f "tokens=1* delims=\" %%r in ('reg query HKU') do (
   reg query "hku\%%s\Volatile Environment" /v Username 2>nul | findstr /ic:"%actual_username%" > nul
   if NOT errorlevel 1 (
      for /f "tokens=3" %%d in ('reg query "HKU\%%s\Volatile Environment" /v USERDOMAIN') do (
         set domain=%%d
         set sid=%%s
      )
   )
)
if NOT defined domain (
   call :Log Verbose "Failed to find user by username, checking for matching profile"
   for /f "tokens=1* delims=\" %%r in ('reg query HKU') do (
      reg query "hku\%%s\Volatile Environment" /v USERPROFILE 2>nul | findstr /iec:"%actual_username%" > nul
      if NOT errorlevel 1 (
         for /f "tokens=3" %%d in ('reg query "HKU\%%s\Volatile Environment" /v USERDOMAIN') do (
            set domain=%%d
            set sid=%%s
         )
         for /f "tokens=3" %%n in ('reg query "HKU\%%s\Volatile Environment" /v USERNAME') do (
            set actual_username=%%n
         )
      )
   )
)
if defined sid (
   for /f "tokens=3" %%p in ('reg query "HKU\%sid%\Volatile Environment" /v HOMEPATH') do (
      set "actual_userpath=%%p"
   )
)

if defined domain (
   call :Log Verbose "Domain=%domain%"
   call :Log Verbose "Full Username=%domain%\%actual_username%"
   call :Log Verbose "SID=%sid%
   call :Log Verbose "HomePath=%actual_userpath%
   set "full_username=%domain%\%actual_username%"
   exit /b 0
) else (
   call :Log Warning "Domain not found in registry"
   exit /b %Internal_Error_Code%
)
exit /b 1

:Parse_Arguments
if NOT "%~1" == "" (
   if NOT "%~2" == "" (
      set "arg=%~1"
      set "val=%~2"
      if "!arg:~0,1!" == "/" (
         set "Arg_!arg:~1!=%~2"
         call :Log Debug "Set %~1 to %~2"
      ) else (
         call :Log Error "Argument not formated properly: '%~1' '%~2', '%~1' is not an argument"
         call :Exit %Invalid_Parameter%
      )
   ) else (
      call :Log Error "Argument not formated properly: '%~1' '%~2', '%~1' does not have value defined"
      call :Exit %Invalid_Parameter%
   )
   shift
   shift
   goto :Parse_Arguments
)
exit /b 0

:Override_Check
REM check for override
if exist "%Override_Location%\%Override_Name% All" (
   call :log Warning "Full Override detected - Bypassing checks"
   call :exit %App_Override_Code%
) else (
   call :log Debug "Full Override not detected"
)

if exist "%Override_Location%\%Override_Name% %mode%" (
   call :log Warning "%mode% Override detected - Bypassing checks"
   call :exit %App_Override_Code%
) else (
   call :log Debug "%mode% Override not detected"
)
if defined Web_Override_Location (
   if "[%mode%]" == "[REGISTER]" (
      call :log Debug "Removing Old Web Overrides"
      REM del /q "%Override_Location%\WEB %Override_Name% All"
      for %%m in (%Override_Mode_List%) do (
         del /q "%Override_Location%\WEB %Override_Name% %%m"
      )
      if not exist "%Override_Location%" (
         mkdir "%Override_Location%"
      )
      REM call :log Debug "Checking for Web Override: %Web_Override_Location%/%Web_Override_Name%_All"
      REM bitsadmin /transfer "UnifiedCAE Full Override check" /priority foreground "%Web_Override_Location%/%Web_Override_Name%_All" "%Override_Location%\WEB %Override_Name% All" > nul
      
      for %%m in (%Override_Mode_List%) do (
         call :log Debug "Checking for Web Override: %Web_Override_Location%/%Web_Override_Name%_%%m"
         bitsadmin /transfer "UnifiedCAE %mode% Override check" /priority foreground "%Web_Override_Location%/%Web_Override_Name%_%%m" "%Override_Location%\WEB %Override_Name% %%m" > nul
      )
   )
   if exist "%Override_Location%\WEB %Override_Name% ALL" (
      type "%Override_Location%\WEB %Override_Name% ALL"|findstr /irc:^Enabled$ >nul
      if NOT ERRORLEVEL 1 (
         call :log Warning "Web Full Override detected - Bypassing checks"
         call :exit %App_Override_Code%
      ) else (
         del /q "%Override_Location%\WEB %Override_Name% ALL"
         call :log Debug "Web Full Override detected but file did not contain proper value"
      )
   ) else (
      call :log Debug "Web Full Override not detected"
   )
   if exist "%Override_Location%\WEB %Override_Name% %mode%" (
      type "%Override_Location%\WEB %Override_Name% %mode%"|findstr /irc:^Enabled$ >nul
      if NOT ERRORLEVEL 1 (
         call :log Warning "Web %mode% Override detected - Bypassing checks"
         call :exit %App_Override_Code%
      ) else (
         del /q "%Override_Location%\WEB %Override_Name% %mode%"
         call :log Debug "Web %mode% Override detected but file did not contain proper value"
      )
   ) else (
      call :log Debug "Web %mode% Override not detected"
   )
) else (
   call :log Debug "Web Override not enabled"
)

if exist %Override_Location%\%Shared_Machine_Override_Name% (
   set "Shared_Machine=True"
   call :log Warning "Shared Machine: True"
) else (
   call :log Debug "Shared Machine: False"
)

exit /b 0


:Message_Service_Initialize
REM Initialize Message Service
call :Log Info "Initializing Message Service"
call :Get_Username
if NOT ERRORLEVEL 1 (
   REM Check Version
   call :log Verbose "Message Service Script Version: %MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%
   set "MsgSvc_InstalledMinorVersion="
   reg query "%MsgSvc_DataReg%" /v MinorVersion >nul 2>&1
   if NOT errorlevel 1 (
      for /f "tokens=3" %%v in ('reg query "%MsgSvc_DataReg%" /v MinorVersion') do (
         set "MsgSvc_InstalledMajorVersion=%MsgSvc_ScriptMajorVersion%"
         set "MsgSvc_InstalledMinorVersion=%%v"
      )
      call call :log Verbose "Message Service Installed Minor Version: %%MsgSvc_InstalledMinorVersion%%"
   ) else (
      call :Log Info "Message Service Not Installed"
   )
   
   REM Update Version if Needed
   if defined MsgSvc_InstalledMinorVersion (
      setlocal enabledelayedexpansion
      if "!MsgSvc_InstalledMinorVersion!" lss "%MsgSvc_ScriptMinorVersion%" (
         call :Log Info "Updating Message Service from !MsgSvc_InstalledMajorVersion!.!MsgSvc_InstalledMinorVersion! to %MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%"
         endlocal
         call :Message_Service_Update 
      ) else (
         endlocal
      )
   ) else (
      call :Message_Service_Install
   )
   if ERRORLEVEL 1 (
      call :Log Warning "Unable to install or Update Message Service"
      set "MsgSvc_Initalized=Failed"
   ) else (
      REM TODO: Check For Errors
      REM TODO: Repair if Needed
      set "MsgSvc_Initalized=True"
   )
   schtasks /query /tn "%MsgSvc_TaskSchdDir%\%full_username%\ShowMessage" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Message_Service_Install_User
   ) else (
      call :log Verbose "User task is already installed"
   )
   if not exist "%MsgSvc_DataDir%\%full_username%\Messages" (
      mkdir "%MsgSvc_DataDir%\%full_username%\Messages"
   )
) else (
    call :Log Warning "Unable to get Username, Message Service cannot Initialize"
    set "MsgSvc_Initalized=Failed"
)
exit /b 0

:Message_Service_Update
REM Message Service .1 Update
if "!MsgSvc_InstalledMinorVersion!" lss "1" (
   call :Log Info "Message Service Update: Starting Update to V%MsgSvc_ScriptMajorVersion%.1"
   call :Log Verbose "Message Service Update: Backing up current MessageBoxSvc.bat"
   if exist "%MsgSvc_InstallDir%\MessageBoxSvc.bat.bak" (
      del /q "%MsgSvc_InstallDir%\MessageBoxSvc.bat.bak"
      if ERRORLEVEL 1 (
         call :Log Error "Message Service Update: Unable to remove previous messageBoxSvc.bat backup"
         exit /b 1
      )
   )
   ren "%MsgSvc_InstallDir%\MessageBoxSvc.bat" MessageBoxSvc.bat.bak
   if ERRORLEVEL 1 (
      call :Log Error "Message Service Update: Unable to create backup of messageBoxSvc.bat"
      exit /b 1
   )
   call :Log Verbose "Message Service Update: Updating MessageBoxSvc.bat"
   (
   echo\@echo off
   echo\cd /d %%~dp0
   REM Read message
   echo\for /f "usebackq delims=|" %%%%D in ^(`dir /b "%%~1"^^^|findstr /irc:"Message_.\.txt"`^) do ^(
   echo\		for /f "tokens=*" %%%%L in ^(%%~1\%%%%D^) do ^(
   echo\			start "" /min wscript "%%~dp0MessageBox.vbs" "%%%%L" "AppsAnywhere"
   echo\		^)
   echo\		del /q "%%~1\%%%%D"
   echo\^)
   ) > "%MsgSvc_InstallDir%\MessageBoxSvc.bat"
   if ERRORLEVEL 1 (
      call :Log Error "Message Service Update: Unable to update MessageBoxSvc.bat"
      if exist "%MsgSvc_InstallDir%\MessageBoxSvc.bat" (
         del /q "%MsgSvc_InstallDir%\MessageBoxSvc.bat"
         if ERRORLEVEL 1 (
            call :Log Error "Message Service Update: Unable to remove partial messageBoxSvc.bat"
         )
      )
      ren "%MsgSvc_InstallDir%\MessageBoxSvc.bat.bak" MessageBoxSvc.bat
      if ERRORLEVEL 1 (
         call :Log Error "Message Service Update: Unable to restore backup of messageBoxSvc.bat"
      )
      exit /b 1
   )
   call :Log Verbose "Message Service Update: Backing up current Uninstall.bat"
   if exist "%MsgSvc_InstallDir%\Uninstall.bat.V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%.bak" (
      call :Log Error "Message Service Update: Previous Uninstall.bat backup 'Uninstall.bat.V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%.bak' exists and thus an update cannot take place"
      exit /b 1
   )
   ren "%MsgSvc_InstallDir%\Uninstall.bat" "Uninstall.bat.V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%.bak"
   if ERRORLEVEL 1 (
      call :Log Error "Message Service Update: Unable to create backup of Uninstall.bat"
      del /q "%MsgSvc_InstallDir%\Uninstall.bat"
      ren "%MsgSvc_InstallDir%\Uninstall.bat.V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%.bak" "Uninstall.bat"
      exit /b 1
   )
   call :Log Verbose "Message Service Update: Updating MessageBoxSvc.bat"
   call :Message_Service_Uninstall_Header
   call :Log Verbose "Message Service Update: Porting Uninstall info from backup file"
   rem Port additional uninstall info from backup file
   for /f "usebackq delims== tokens=2" %%L in (`type "%MsgSvc_InstallDir%\Uninstall.bat.V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%.bak" ^| findstr /ibc:"setlocal & set command="`) do (
      setlocal disabledelayedexpansion
      (
         echo\setlocal ^& set command=%%L
      ) >> "%MsgSvc_UninstallFile%"
      endlocal
   )
   call :Log Verbose "Message Service Update: Changing Permissions on Data directory"
   icacls "%MsgSvc_DataDir%" /grant Users:^(OI^)^(CI^)F
   if ERRORLEVEL 1 (
      call :Log Error "Message Service Update: Failed Changing Permissions on Data directory '%MsgSvc_DataDir%'"
   )
   call :Log Verbose "Message Service Update: Removing update backup files"
   del /q "%MsgSvc_InstallDir%\MessageBoxSvc.bat.bak"
   if ERRORLEVEL 1 (
      call :Log Warning "Message Service Update: Unable to remove messageBoxSvc.bat.bak this may cause issues on future updates"
   )
   call :Log Verbose "Message Service Update: Updating Registry"
   reg add "%MsgSvc_DataReg%" /v MinorVersion /d "1" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update MinorVersion Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v DisplayName /d "%MsgSvc_Firendly_Name%" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall DisplayName Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v DisplayVersion /d "%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall DisplayVersion Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v Publisher /d "%IT_Group_Name%" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall Publisher Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v UninstallString /d "\"%MsgSvc_UninstallFile%\"" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall UninstallString Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v QuietUninstallString /d "\"%MsgSvc_UninstallFile%\" /s" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall QuietUninstallString Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v NoModify /d "1" /t REG_DWORD /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall NoModify Reg Key"
      exit /b 1
   )
   reg add "%MsgSvc_UninstallReg%" /v NoRepair /d "1"  /t REG_DWORD /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to update Uninstall NoRepair Reg Key"
      exit /b 1
   )
   reg delete "%MsgSvc_UninstallReg_Old%" /f
   if ERRORLEVEL 1 (
      echo :Log Error "Message Service Update: Unable to remove old Uninstall Reg Key"
      exit /b 1
   )
   call :Log Info "Message Service Update: Done Update to V%MsgSvc_ScriptMajorVersion%.1"
)
exit /b 0

:Message_Service_Install
call :Log Info "Message Service Install: Installing Message Service V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%"
REM Install Message Service
call :log Verbose "Message Service Install: Adding Directories"
if NOT exist "%MsgSvc_InstallDir%" (
   mkdir "%MsgSvc_InstallDir%" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create directory: '%MsgSvc_InstallDir%'"
      exit /b %Internal_Error_Code%
   )
)
call :Message_Service_Uninstall_Header
rem call :Message_Service_Uninstall_Command rmdir /S /Q "%MsgSvc_InstallDirRef%"

if NOT exist "%MsgSvc_DataDir%" (
   mkdir "%MsgSvc_DataDir%" >nul 2>&1 
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create directory: '%MsgSvc_DataDir%'"
      exit /b %Internal_Error_Code%
   )
)
icacls "%MsgSvc_DataDir%" /grant Users:^(OI^)^(CI^)F
rem call :Message_Service_Uninstall_Command rmdir /S /Q "%MsgSvc_DataDirRef%"

if NOT exist "%MsgSvc_TempDir%" (
   mkdir "%MsgSvc_TempDir%" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create directory: '%MsgSvc_TempDir%'"
      exit /b %Internal_Error_Code%
   )
)
rem call :Message_Service_Uninstall_Command rmdir /S /Q "%MsgSvc_TempDirRef%"

reg query "%MsgSvc_DataReg%" >nul 2>&1
if ERRORLEVEL 1 (
   reg add "%MsgSvc_DataReg%" /f
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create registry: '%MsgSvc_DataReg%'"
      exit /b %Internal_Error_Code%
   )
)
rem call :Message_Service_Uninstall_Command reg delete /f "%MsgSvc_DataReg%"

call :log Verbose "Message Service Install: Adding Program Files"
(
echo\Set objArgs = WScript.Arguments
echo\messageText = Replace^(objArgs^(0^), "\n", vbCrLf^)
echo\ObjectText = objArgs^(1^)
echo\MsgBox messageText, vbSystemModal + vbExclamation, objectText
) > "%MsgSvc_InstallDir%\MessageBox.vbs"
rem call :Message_Service_Uninstall_Command del /Q "%MsgSvc_InstallDirRef%\MessageBox.vbs"

(
echo\@echo off
echo\cd /d %%~dp0
REM Read message
echo\for /f "usebackq delims=|" %%%%D in ^(`dir /b "%%~1"^^^|findstr /irc:"Message_.\.txt"`^) do ^(
echo\		for /f "tokens=*" %%%%L in ^(%%~1\%%%%D^) do ^(
echo\			start "" /min wscript "%%~dp0MessageBox.vbs" "%%%%L" "AppsAnywhere"
echo\		^)
echo\		del /q "%%~1\%%%%D"
echo\^)
) > "%MsgSvc_InstallDir%\MessageBoxSvc.bat"
rem call :Message_Service_Uninstall_Command del /Q "%MsgSvc_InstallDirRef%\MessageBoxSvc.bat"

(
echo\@echo off
echo\cd /d %%~dp0
REM Read message
echo\for /f %%%%F in ^('dir /b /s "%MsgSvc_DataDirRef%"^^^|findstr /irc:"Message_.\.txt"'^) do ^(
echo\	del /q "%%%%~dpnxF"
echo\^)
) > "%MsgSvc_InstallDir%\MessageClear.bat"

call :log Verbose "Message Service Install: Loading Message Clear Scheduled Task"
if NOT exist "%MsgSvc_TempDir%" (
   mkdir "%MsgSvc_TempDir%" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create directory: '%MsgSvc_TempDir%'"
      exit /b %Internal_Error_Code%
   )
)
(
echo\^<?xml version="1.0" encoding="UTF-16"?^>
echo\^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo\  ^<RegistrationInfo^>
echo\    ^<Date^>2020-02-27T10:32:46.0125855^</Date^>
echo\    ^<Author^>%full_username%^</Author^>
echo\    ^<Description^>Clear Queued Messages^</Description^>
echo\    ^<URI^>%MsgSvc_TaskSchdDir%\ClearMessages^</URI^>
echo\  ^</RegistrationInfo^>
echo\    ^<Triggers^>
echo\      ^<BootTrigger^>
echo\        ^<ExecutionTimeLimit^>PT30M^</ExecutionTimeLimit^>
echo\        ^<Enabled^>true^</Enabled^>
echo\      ^</BootTrigger^>
echo\    ^</Triggers^>
echo\  ^<Principals^>
echo\    ^<Principal id="Author"^>
echo\      ^<UserId^>S-1-5-18^</UserId^>
echo\      ^<RunLevel^>HighestAvailable^</RunLevel^>
echo\    ^</Principal^>
echo\  ^</Principals^>
echo\  ^<Settings^>
echo\    ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo\    ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo\    ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo\    ^<AllowHardTerminate^>true^</AllowHardTerminate^>
echo\    ^<StartWhenAvailable^>false^</StartWhenAvailable^>
echo\    ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
echo\    ^<IdleSettings^>
echo\      ^<StopOnIdleEnd^>false^</StopOnIdleEnd^>
echo\      ^<RestartOnIdle^>false^</RestartOnIdle^>
echo\    ^</IdleSettings^>
echo\    ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
echo\    ^<Enabled^>true^</Enabled^>
echo\    ^<Hidden^>false^</Hidden^>
echo\    ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
echo\    ^<DisallowStartOnRemoteAppSession^>false^</DisallowStartOnRemoteAppSession^>
echo\    ^<UseUnifiedSchedulingEngine^>true^</UseUnifiedSchedulingEngine^>
echo\    ^<WakeToRun^>false^</WakeToRun^>
echo\    ^<ExecutionTimeLimit^>PT1H^</ExecutionTimeLimit^>
echo\    ^<Priority^>7^</Priority^>
echo\  ^</Settings^>
echo\  ^<Actions Context="Author"^>
echo\    ^<Exec^>
echo\      ^<Command^>%%comspec%%^</Command^>
echo\      ^<Arguments^>/c ""%MsgSvc_InstallDirRef%\MessageClear.bat""^</Arguments^>
echo\    ^</Exec^>
echo\  ^</Actions^>
echo\^</Task^>
) > "%MsgSvc_TempDir%\ScheduledTask.xml"
schtasks /query /tn "%MsgSvc_TaskSchdDir%\Clear Messages" >nul 2>&1
if NOT ERRORLEVEL 1 (
   schtasks /delete /f /tn "%MsgSvc_TaskSchdDir%\Clear Messages" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Log Error "Unable to Remove old ScheduledTask: '%MsgSvc_TaskSchdDir%\Clear Messages'"
      exit /b %Internal_Error_Code%
   )
)
schtasks /create /xml "%MsgSvc_TempDir%\ScheduledTask.xml" /tn "%MsgSvc_TaskSchdDir%\Clear Messages" >nul 2>&1
if ERRORLEVEL 1 (
   call :Log Error "Unable to Import ScheduledTask: %MsgSvc_TempDir%\ScheduledTask.xml"
   exit /b %Internal_Error_Code%
)
reg add "%MsgSvc_UninstallReg%" /v DisplayName /d "%MsgSvc_Firendly_Name%" /f
reg add "%MsgSvc_UninstallReg%" /v DisplayVersion /d "%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%" /f
reg add "%MsgSvc_UninstallReg%" /v Publisher /d "%IT_Group_Name%" /f
reg add "%MsgSvc_UninstallReg%" /v UninstallString /d "\"%MsgSvc_UninstallFile%\"" /f
reg add "%MsgSvc_UninstallReg%" /v QuietUninstallString /d "\"%MsgSvc_UninstallFile%\" /s" /f
reg add "%MsgSvc_UninstallReg%" /v NoModify /d "1" /t REG_DWORD /f
reg add "%MsgSvc_UninstallReg%" /v NoRepair /d "1"  /t REG_DWORD /f
reg add "%MsgSvc_DataReg%" /v MinorVersion /d "%MsgSvc_ScriptMinorVersion%" /f
call :Log Info "Message Service Install: Installed Message Service V%MsgSvc_ScriptMajorVersion%.%MsgSvc_ScriptMinorVersion%"

exit /b 0

:Message_Service_Install_User
call :log Info "Message Service Install: Loading Scheduled Task for %full_username%"
if NOT exist "%MsgSvc_TempDir%\%full_username%" (
   mkdir "%MsgSvc_TempDir%\%full_username%" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create directory: '%MsgSvc_TempDir%\%full_username%'"
      exit /b %Internal_Error_Code%
   )
)

if NOT exist "%MsgSvc_DataDir%\%full_username%" (
   mkdir "%MsgSvc_DataDir%\%full_username%" >nul 2>&1
   if ERRORLEVEL 1 (
      call :Log Error "Unable to create directory: '%MsgSvc_DataDir%\%full_username%'"
      exit /b %Internal_Error_Code%
   )
)
(
echo\^<?xml version="1.0" encoding="UTF-16"?^>
echo\^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo\  ^<RegistrationInfo^>
echo\    ^<Date^>2020-02-27T10:32:46.0125855^</Date^>
echo\    ^<Author^>%full_username%^</Author^>
echo\    ^<Description^>Shows Message from Message Queue^</Description^>
echo\    ^<URI^>%MsgSvc_TaskSchdDir%\%full_username%\ShowMessage^</URI^>
echo\  ^</RegistrationInfo^>
echo\  ^<Triggers /^>
echo\  ^<Principals^>
echo\    ^<Principal id="Author"^>
echo\      ^<UserId^>%sid%^</UserId^>
echo\      ^<LogonType^>InteractiveToken^</LogonType^>
echo\      ^<RunLevel^>LeastPrivilege^</RunLevel^>
echo\    ^</Principal^>
echo\  ^</Principals^>
echo\  ^<Settings^>
echo\    ^<MultipleInstancesPolicy^>Queue^</MultipleInstancesPolicy^>
echo\    ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo\    ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo\    ^<AllowHardTerminate^>true^</AllowHardTerminate^>
echo\    ^<StartWhenAvailable^>false^</StartWhenAvailable^>
echo\    ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
echo\    ^<IdleSettings^>
echo\      ^<StopOnIdleEnd^>false^</StopOnIdleEnd^>
echo\      ^<RestartOnIdle^>false^</RestartOnIdle^>
echo\    ^</IdleSettings^>
echo\    ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
echo\    ^<Enabled^>true^</Enabled^>
echo\    ^<Hidden^>false^</Hidden^>
echo\    ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
echo\    ^<DisallowStartOnRemoteAppSession^>false^</DisallowStartOnRemoteAppSession^>
echo\    ^<UseUnifiedSchedulingEngine^>true^</UseUnifiedSchedulingEngine^>
echo\    ^<WakeToRun^>false^</WakeToRun^>
echo\    ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
echo\    ^<Priority^>7^</Priority^>
echo\  ^</Settings^>
echo\  ^<Actions Context="Author"^>
echo\    ^<Exec^>
echo\      ^<Command^>%%comspec%%^</Command^>
echo\      ^<Arguments^>/c ""%MsgSvc_InstallDirRef%\MessageBoxSvc.bat" "%MsgSvc_DataDirRef%\%full_username%\Messages""^</Arguments^>
echo\    ^</Exec^>
echo\  ^</Actions^>
echo\^</Task^>
) > "%MsgSvc_TempDir%\%full_username%\ScheduledTask.xml"
call :Message_Service_Uninstall_Command del /Q "%MsgSvc_TempDirRef%\%full_username%\ScheduledTask.xml"

schtasks /create /xml "%MsgSvc_TempDir%\%full_username%\ScheduledTask.xml" /tn "%MsgSvc_TaskSchdDir%\%full_username%\ShowMessage" >nul 2>&1
if ERRORLEVEL 1 (
   call :Log Error "Unable to Import ScheduledTask: %MsgSvc_TempDir%\%full_username%\ScheduledTask.xml"
   exit /b %Internal_Error_Code%
)
call :Message_Service_Uninstall_Command schtasks /delete /F /tn "%MsgSvc_TaskSchdDir%\%full_username%\ShowMessage"
call :log Info "Message Service Install: Loaded Scheduled Task for %full_username%"
exit /b 0

:Message_Service_Uninstall_Header
REM TODO: Add code to cleanup scheduled tasks folders
(
echo\@echo off
echo\set "command="
echo\REM Check for Admin Permissions
echo\echo Administrative permissions required. Detecting permissions...
echo\net session ^>nul 2^>^&1
echo\if ERRORLEVEL 1 ^(
echo\	echo Failure: Current permission inadequate
echo\	if "%%~1" == "Elevated" ^(
echo\		echo Error Getting Admin, please launch manually
echo\		pause
echo\		exit 1
echo\	^)
echo\	if "%%~2" == "Elevated" ^(
echo\		exit 1
echo\	^)
echo\	REM Create elevate.vbs to get us admin
echo\	echo Set UAC = CreateObject^^^("Shell.Application"^^^) ^> %%temp%%\elevate.vbs
echo\	echo UAC.ShellExecute "%%~s0", WScript.Arguments^^^(0^^^), "", "runas", 1 ^>^> %%temp%%\elevate.vbs
echo\	start "" /wait %%SystemRoot%%\System32\wscript.exe %%temp%%\elevate.vbs "%%~1 Elevated"
echo\	if ERRORLEVEL 1 ^(
echo\		echo Error Getting Admin, please launch manually
echo\		if NOT "%%~1" == "/s" ^(
echo\			pause
echo\		^)
echo\		exit 1
echo\	^) else ^(
echo\		exit 0
echo\	^)
echo\	
echo\^) else ^(
echo\	echo Success: Administrative Permissions Confirmed
echo\	echo.
echo\^)
echo\if NOT "%%~1" == "/s" ^(
echo\	echo This Will Uninstall the AppsAnywhere Message Service
echo\	choice /m "Would you like to continue with the uninstall "
echo\	if ERRORLEVEL 2 ^(exit 0^) else if ERRORLEVEL 1 ^(call :Load_Commands^) else ^(exit %Internal_Error_Code%^)
echo\^) else ^(
echo\	call :Load_Commands
echo\^)
echo\:Command_Loop
echo\for /f "usebackq delims== tokens=2" %%%%L in ^(`type "%%~dpnx0" ^^^| findstr /ibc:"setlocal & set command="`^) do ^(
echo\	call %%%%L ^>nul 2^>^&1
echo\	if ERRORLEVEL 1 ^(
echo\		echo Error Durring Uninstall
echo\		echo %How_To_Get_Help_Text:\n= %
echo\		if NOT "%%~1" == "/s" ^(
echo\			pause
echo\		^)
echo\		exit %Internal_Error_Code%
echo\	^)
echo\^)
echo\schtasks /delete /F /tn "%MsgSvc_TaskSchdDir%\Clear Messages" ^>nul 2^>^&1
echo\del /Q "%MsgSvc_TempDirRef%\ScheduledTask.xml" ^>nul 2^>^&1
echo\del /Q "%MsgSvc_InstallDirRef%\MessageBoxSvc.bat" ^>nul 2^>^&1
echo\del /Q "%MsgSvc_InstallDirRef%\MessageBox.vbs" ^>nul 2^>^&1
echo\del /Q "%MsgSvc_InstallDirRef%\MessageClear.bat" ^>nul 2^>^&1
echo\reg delete "%MsgSvc_DataReg%" /f ^>nul 2^>^&1 
echo\rmdir /S /Q "%MsgSvc_TempDirRef%" ^>nul 2^>^&1
echo\rmdir /S /Q "%MsgSvc_DataDirRef%" ^>nul 2^>^&1
echo\^(
echo\	reg delete "%MsgSvc_UninstallReg%" /f ^>nul 2^>^&1
echo\	del /Q "%MsgSvc_InstallDirRef%\Uninstall.bat" ^>nul 2^>^&1
echo\	cd /d %%temp%%
echo\	rmdir /S /Q "%MsgSvc_InstallDirRef%" ^>nul 2^>^&1
echo\	echo Uninstall Complete
echo\	if NOT "%%~1" == "/s" ^(
echo\		pause
echo\	^)
echo\	exit 0
echo\^)
echo\:Load_Commands
echo\
) > "%MsgSvc_UninstallFile%"
exit /b 0

:Message_Service_Uninstall_Command
setlocal disabledelayedexpansion
(
echo\setlocal ^& set command=%*
) >> "%MsgSvc_UninstallFile%"
endlocal
exit /b 0

:Message_Service_Uninstall_Footer
(

) >> "%MsgSvc_UninstallFile%"
exit /b 0

:Message_Service_Repair
rem TODO: Repair Message Service
exit /b 0
:Show_Message <Message_Text>
:Message_Service_Display_Message <Message_Text>
REM Display Message
call :Log Info "Preparing to display message: %~1"
REM Initialize if not Initialized
if /i "%MsgSvc_Enabled%" == "False" (
   call :Log Warning "Message Service Disabled, Message will not be shown to User"
   exit /b 0
) else if "%MsgSvc_Enabled%" == "True" (
   echo.>nul
) else (
   call :log Error "MsgSvc_Enabled is not True or False"
   call :exit %Internal_Error_Code%
)
if /i "%MsgSvc_Initalized%" == "False" (
   call :Message_Service_Initialize
)
if "%MsgSvc_Initalized%" == "True" (
   REM add Message to Queue
   if NOT exist "%MsgSvc_DataDir%\%full_username%\Messages" (
      mkdir "%MsgSvc_DataDir%\%full_username%\Messages" >nul 2>&1
      if ERRORLEVEL 1 (
         call :Log Error "Unable to create directory: '%MsgSvc_DataDir%\%full_username%\Messages'"
      )
   )
   set "DisplayedMessage="
   for /l %%I in (1,1,9) do (
      if not Defined DisplayedMessage (
         if not exist "%MsgSvc_DataDir%\%full_username%\Messages\Message_%%I.txt" (
            rem echo\%~1\n\n%How_To_Get_Help_Text%> "%MsgSvc_DataDir%\%full_username%\Messages\Message_%%I.txt"
            call :Message_Service_Save_Message "%~1\n\n%How_To_Get_Help_Text%" "%MsgSvc_DataDir%\%full_username%\Messages\Message_%%I.txt"
            set "DisplayedMessage=True"
         )
      )
   )
   schtasks /run /tn "%MsgSvc_TaskSchdDir%\%full_username%\ShowMessage"
   call :Log Info "Displayed message: %~1"
) else (
   call :Log Warning "Message Service Unavailable, Message not Displayed to user"
)

exit /b 0

:Message_Service_Save_Message <Message> <File>
echo\%~1> %2
exit /b
:Debug_Menu_Initialize
set "LogLevel=%LogLevel[Debug]%"
set "MsgSvc_Enabled=False"
set "Debug_Run_Mode=Internal"
:Debug_Menu
title DEBUG

CLS
echo/Debug Menu
echo/1. Run Mode
echo/2. Call Function
echo/3. Run Command
echo/4. Self Check
echo/5. Toggle Echo (currently %echo%)
echo/6. Toggle Message Service (currently %MsgSvc_Enabled%)
choice /C 123456 /M "What do you want to do " 
if "%errorlevel%"=="1" (
   call :Debug_Run
)
if "%errorlevel%"=="2" (
   call :Debug_goto
)
if "%errorlevel%"=="3" (
   call :Debug_cmd
)
if "%errorlevel%"=="4" (
   call :Debug_SelfCheck
)
if "%errorlevel%"=="5" (
   call :Debug_Echo
)
if "%errorlevel%"=="6" (
   call :Debug_Message_Service
)
goto :Debug_Menu
call :Exit %Debug_Complete%

:Debug_SelfCheck
CLS
setlocal enabledelayedexpansion
echo Starting Self Check
FOR /F "tokens=1,2* Delims==" %%V IN ('set ^| findstr /ibc:UsrVar') DO (
   set Variable=%%V
   set Value=%%W
   set !Variable!|find """" >nul 2>&1
   if NOT ERRORLEVEL 1 (
      REM echo !Variable! contains a " this may cause issues
   )
)
for /f "usebackq delims== tokens=1*" %%V in (`type "%~dpnx0" ^| findstr /ibc:"set ""UsrVar_"`) do (
   set Variable=%%V
   set Variable=!Variable:~5!
   set !Variable! 2>nul|find """" >nul 2>&1
   if NOT ERRORLEVEL 1 (
      echo !Variable! is malformed ^(Quote in Value^)
   ) else (
      echo %%V=%%W| findstr /irc:"^set \"Usrvar_.*\"..*$" >nul 2>&1
      if NOT ERRORLEVEL 1 (
         echo !Variable! is malformed ^(Text After Quote^)
      ) else (
         echo %%V=%%W| findstr /irc:"^set \"Usrvar_.*\"$" >nul 2>&1
         if ERRORLEVEL 1 (
            echo !Variable! is malformed ^(No Ending Quote^)
         )
      )
   )
)
for /f "usebackq delims== tokens=1" %%V in (`type "%~dpnx0" ^| findstr /ibc:"set ""UsrVar_"`) do (
   set Variable=%%V
   set Variable=!Variable:~5!
   if not defined !Variable! (
      echo !Variable!| findstr /irc:".*\[[0-9][0-9]*\]$" >nul 2>&1
      if ERRORLEVEL 1 (
         if NOT "!Variable!" == "!Variable:SolidWorks=!" (
            if /i "[%UsrVar_Solidworks_EULA_Enabled%]" == "[True]" (
               echo !Variable! is not Defined
            )
         ) else (
            if NOT "!Variable!" == "!Variable:ADSK=!" (
               if /i "[%UsrVar_ADSK_License_Enabled%]" == "[True]" (
                  echo !Variable! is not Defined
               )
            ) else (
               if NOT "!Variable!" == "!Variable:Rocsci=!" (
                  if /i "[%UsrVar_Rocsci_Drivers_Enabled%]" == "[True]" (
                     echo !Variable! is not Defined
                  )
               ) else (
                  echo !Variable! is not Defined
               )
            )
         )
      )
   )
)
echo Self Check Completed
pause
endlocal
exit /b 0

:Debug_goto
CLS
echo/Enter nothing to return to menu
set /p "Function=Function [Paramaters]: "
if defined Function (
   echo === Function Start ===
   call :%Function%
   echo === Function Complete ===
   pause
)
exit /b 0

:Debug_run
CLS
echo Run Mode
echo 1. REGISTER
echo 2. ACTIVATE
echo 3. VIRTUALIZE
echo 4. LAUNCH
echo 5. EXIT
echo 6. DEVIRTUALIZE
echo 7. DEACTIVATE
echo 8. Toggle Internal/External (Currently %Debug_Run_Mode%)
choice /C 12345678 /M "What do you want to run " 
if "%errorlevel%"=="1" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods REGISTER
   ) else (
      call "%~dpnx0" /mode REGISTER /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="2" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods ACTIVATE
   ) else (
      call "%~dpnx0" /mode ACTIVATE /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="3" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods VIRTUALIZE
   ) else (
      call "%~dpnx0" /mode VIRTUALIZE /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="4" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods LAUNCH
   ) else (
      call "%~dpnx0" /mode LAUNCH /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="5" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods EXIT
   ) else (
      call "%~dpnx0" /mode EXIT /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="6" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods DEVIRTUALIZE
   ) else (
      call "%~dpnx0" /mode DEVIRTUALIZE /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="7" (
   if "%Debug_Run_Mode%" == "Internal" (
      call :Run_Methods DEACTIVATE
   ) else (
      call "%~dpnx0" /mode DEACTIVATE /LogLevel %LogLevel[Debug]%
   )
) else if "%errorlevel%"=="8" (
   call :Debug_Mode
   goto :Debug_run
)
exit /b 0

:Debug_cmd
CLS
echo/Enter nothing to return to menu
set /p "Command=Command: "
if NOT "%Command%" == "" (
   echo === Command Start ===
   %Command%
   echo === Command Complete ===
   pause
)
exit /b 0
:Debug_Mode
if "%Debug_Run_Mode%" == "Internal" (
   set "Debug_Run_Mode=External"
) else (
   set "Debug_Run_Mode=Internal"
)
exit /b 0

:Debug_Echo
if "%echo%" == "off" (
   set "echo=on"
) else (
   set "echo=off"
)
echo %echo%
exit /b 0

:Debug_Message_Service
if "%MsgSvc_Enabled%" == "False" (
   set "MsgSvc_Enabled=True"
) else (
   set "MsgSvc_Enabled=False"
)
exit /b 0

:exit <errorcode>
call :log Info "Exiting with errorcode: %~1"
if "%Mode%" == "DEBUG" (
   if %1 gtr 0 (
      echo Script would exit with error
      choice /m "do you want to continue anyway "
      if ERRORLEVEL 3 (
         echo Invalid
         pause
      ) else if ERRORLEVEL 2 (
         echo.>nul
      ) else if ERRORLEVEL 1 (
         call :log Debug "Exit Aborted, Resuming"
         exit /b 0
      ) else (
         echo.>nul
      )
   ) else (
      pause
   )
)
exit %1