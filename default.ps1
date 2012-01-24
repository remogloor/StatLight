properties {
	# NOTE: the $build_configuration property must be set prior to calling anything in here... default.ps1 for example
	$build_configuration =  ?? $build_configuration 'Debug'

	$not_build_configuration = Get-Not-Build-Configuration
	$build_dir = ".\src\build\bin\$build_configuration"
	$program_files_dir = Get-x86-ProgramFiles-Location

	$silverlight_core_assemblies_location = "$program_files_dir\Reference Assemblies\Microsoft\Framework\Silverlight\v5.0"
	$silverlight_libraries_client_assemblies = "$program_files_dir\Microsoft SDKs\Silverlight\v5.0\Libraries\Client"

	$statlight_xap_for_prefix = "StatLight.Client.For" 
	$release_dir = 'Release'
	
	$clientHarnessBuildOutputDir = ".\src\StatLight.Client.Harness\bin\$build_configuration"
	
	$solutionFile = ?? $solutionFile ".\src\StatLight.sln"
	$solutionFilePhone = ?? $solutionFilePhone ".\src\StatLight.Phone.sln"
	
	$nunit_console_path = 'Tools\NUnit\nunit-console-x86.exe'

	$statLightSourcesFilePrefix = 'StatLight.Sources.'
	$core_assembly_path = "$build_dir\StatLight.Core.dll"
	$test_assembly_path = "src\StatLight.Core.Tests\bin\x86\$build_configuration\StatLight.Core.Tests.dll"
	$integration_test_assembly_path = "$build_dir\StatLight.IntegrationTests.dll"
	
	$isPhoneBuild = ?? $isPhoneBuild $false
	
	$chmDocPath  = '.\docs\_build\htmlhelp\StatLightdoc.chm'
	
	# All of the versions that this script will create compatible 
	# builds of the statlight silverlight client for...
	#
	# How to add a new version
	#  - 1. Create the new version in the libs path .\libs\Silverlight\Microsoft\<version>\*.dll
	#  - 2. Add the version below 
	#  - 3. Add the version to the MicrosoftTestingFrameworkVersion enum in the project
	$microsoft_silverlight_testing_versions = @(
			'MSTest2011December'
			'MSTest2011October'
			'MSTest2011June'
			'MSTest2011Feb'
			'MSTest2010March'
			'MSTest2010April'
			'MSTest2010May'

#			'MSTest2008December'
#			'MSTest2009March'
			'MSTest2009July'
			'MSTest2009October'
			'MSTest2009November'
		)
}

function ?? {
    $result = $null
	$i = 0;
	while($args[$i] -eq $null)
	{
		$i = $i + 1;
	}
	
	return $args[$i]
}

Task default -depends build-debug

if(!($Global:hasLoadedNUnitSpecificationExtensions))
{
	echo 'loading NUnitSpecificationExtensions...'
	Update-TypeData -prependPath .\tools\PowerShell\NUnitSpecificationExtensions.ps1xml
	[System.Reflection.Assembly]::LoadFrom((Get-Item .\tools\NUnit\nunit.framework.dll).FullName) | Out-Null
	$Global:hasLoadedNUnitSpecificationExtensions = $true;
}


# Is this a Win64 machine regardless of whether or not we are currently 
# running in a 64 bit mode 
function Test-Win64Machine() {
    return test-path (join-path $env:WinDir "SysWow64")
}

function rename-file-extensions {
	param([string]$itemsPath, [string]$fromExtension, [string]$toExtension)
	Get-Item "$itemsPath" | foreach{ Move-Item $_.FullName $_.FullName.Replace($fromExtension, $toExtension) }
}

function get-assembly-version() {
	param([string] $file)
	
	$fileStream = ([System.IO.FileInfo] (Get-Item $file)).OpenRead()
	$assemblyBytes = new-object byte[] $fileStream.Length
	$fileStream.Read($assemblyBytes, 0, $fileStream.Length) | Out-Null #out null this because this function should only return the version & this call was outputting some garbage number
	$fileStream.Close()
	$version = [System.Reflection.Assembly]::Load($assemblyBytes).GetName().Version;
	
	#format the version and output it...
	$version
}

function get-formatted-assembly-version() {
	param([string] $file)
	
	$version = get-assembly-version $file
	"v$($version.Major).$($version.Minor).$($version.Build).$($version.Revision)"
}

function Build-Csc-Command {
	param([array]$options, [array]$sourceFiles, [array]$references, [array]$resources)
	
	$csc = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'

	# can't say I'm doing delimeters correctly, but seems to work ???
	$delim = [string]""""
	
	$opts = $options

	if($references.Count -gt 0)
	{
		$opts += '/reference:' + $delim + [string]::Join($delim + ' /reference:' + $delim, $references) + $delim
	}

	if($resources.Count -gt 0)
	{
		$opts += '/resource:' + $delim + [string]::Join($delim + ' /resource:' + $delim, $resources) + $delim
	}
	
	if($sourceFiles.Count -gt 0)
	{
		$opts += [string]::Join(' ', $sourceFiles)
	}
	
	$cmd = [string]::Join(" ", $options)
	$cmd = $csc + " " + $opts
	$cmd;
}

function Execute-Command-String {
	param([string]$cmd)
	
	# this drove me crazy... all I wanted to do was execute
	# something like this (excluding the [])
	#
	# [& $csc $opts] OR [& $cmd]
	#
	# however couldn't figure out the correct powershell syntax...
	# But I was able to execute it if I wrote the string out to a 
	# file and executed it from there... would be nice to not 
	# have to do that.

	$tempFileGuid = ([System.Guid]::NewGuid())
	$scriptFile = ".\temp_build_csc_command-$tempFileGuid.ps1"
	Remove-If-Exists $scriptFile

	Write-Host ''
	Write-Host '*********** Executing Command ***********'
	Write-Host $cmd
	Write-Host '*****************************************'
	Write-Host ''
	Write-Host ''

	$cmd >> $scriptFile
	exec { . $scriptFile } 'Doh - Compile failed...'
	Remove-If-Exists $scriptFile
}

function StatLightReferences {
	param([string]$microsoft_silverlight_testing_version_name)
	
	$references = @(
		"$silverlight_core_assemblies_location\mscorlib.dll",
		"$silverlight_core_assemblies_location\System.dll",
		"$silverlight_core_assemblies_location\System.Core.dll",
		"$silverlight_core_assemblies_location\System.Net.dll",
		"$silverlight_core_assemblies_location\System.Runtime.Serialization.dll",
		"$silverlight_core_assemblies_location\System.ServiceModel.dll",
		"$silverlight_core_assemblies_location\System.Windows.dll",
		"$silverlight_core_assemblies_location\System.Windows.Browser.dll",
		"$silverlight_core_assemblies_location\System.Xml.dll",
		"$silverlight_libraries_client_assemblies\System.Windows.Controls.dll",
		"$silverlight_libraries_client_assemblies\System.Xml.Linq.dll",
		"$silverlight_libraries_client_assemblies\System.Xml.Serialization.dll",
		".\lib\Silverlight\Microsoft\$microsoft_silverlight_testing_version_name\Microsoft.Silverlight.Testing.dll"
		".\lib\Silverlight\Microsoft\$microsoft_silverlight_testing_version_name\Microsoft.VisualStudio.QualityTools.UnitTesting.Silverlight.dll"
		"$clientHarnessBuildOutputDir\StatLight.Client.Harness.dll"
	)
	$references;
}

function StatLightIntegrationTestsReferences {
	param([string]$microsoft_silverlight_testing_version_name)
	
	$references = @(
		"$silverlight_core_assemblies_location\mscorlib.dll",
		"$silverlight_core_assemblies_location\System.dll",
		"$silverlight_core_assemblies_location\System.Core.dll",
		"$silverlight_core_assemblies_location\System.Net.dll",
		"$silverlight_core_assemblies_location\System.Runtime.Serialization.dll",
		"$silverlight_core_assemblies_location\System.ServiceModel.dll",
		"$silverlight_core_assemblies_location\System.Windows.dll",
		"$silverlight_core_assemblies_location\System.Windows.Browser.dll",
		"$silverlight_core_assemblies_location\System.Xml.dll",
		"$silverlight_libraries_client_assemblies\System.Windows.Controls.dll",
		"$silverlight_libraries_client_assemblies\System.Xml.Linq.dll",
		"$silverlight_libraries_client_assemblies\System.Xml.Serialization.dll",
		".\lib\Silverlight\Microsoft\$microsoft_silverlight_testing_version_name\Microsoft.Silverlight.Testing.dll"
		".\lib\Silverlight\Microsoft\$microsoft_silverlight_testing_version_name\Microsoft.VisualStudio.QualityTools.UnitTesting.Silverlight.dll"
		"$clientHarnessBuildOutputDir\StatLight.Client.Harness.dll"
	)

	$references;
}

function compile-StatLight-MSTestHost {
	param([string]$microsoft_Silverlight_Testing_Version_Name, [string]$outAssemblyName, $references)

	$sourceFiles = @(
		"src\AssemblyInfo.cs"
		".\src\StatLight.Client.Harness.MSTest\App.g.cs"
	)

	$sourceFiles += Get-ChildItem 'src\StatLight.Client.Harness.MSTest\' -recurse `
		| where{$_.Extension -like "*.cs"} `
		| foreach {$_.FullName} `
		| where{!$_.Contains($not_build_configuration)} `
		| where{!$_.Contains('App.g.cs')} `
		| where{!$_.Contains('App.g.i.cs')}
echo $sourceFiles

	$extraCompilerFlags = "$microsoft_Silverlight_Testing_Version_Name"

	$buildConfigToUpper = $build_configuration.ToUpper();
	echo $buildConfigToUpper
	$options = @(
		'/noconfig',
		'/nowarn:1701`,1702',
		'/nostdlib+',
		'/errorreport:prompt',
		'/platform:anycpu',
		'/warn:4'
		"/define:$buildConfigToUpper``;TRACE``;SILVERLIGHT``;$extraCompilerFlags``;$microsoft_Silverlight_Testing_Version_Name",
		'/debug-',
		'/optimize+',
		'/keyfile:src\StatLight.snk',
		"/out:$outAssemblyName",
		'/target:library'
	)

	$cmd = Build-Csc-Command -options $options -sourceFiles $sourceFiles -references $references -resources $resources
	
	Execute-Command-String $cmd
}

function compile-StatLight-MSTestHostIntegrationTests {
	param([string]$microsoft_Silverlight_Testing_Version_Name, [string]$outAssemblyName, [string]$additionalDefines, $references)

	$sourceFiles = @(
		".\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\App.g.cs"
	)

	$sourceFiles += Get-ChildItem 'src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\' -recurse `
		| where{$_.Extension -like "*.cs"} `
		| foreach {$_.FullName} `
		| where{!$_.Contains($not_build_configuration)} `
		| where{!$_.Contains('App.g.cs')} `
		| where{!$_.Contains('App.g.i.cs')}
echo $sourceFiles

	$buildConfigToUpper = $build_configuration.ToUpper();
	echo $buildConfigToUpper
	$options = @(
		'/noconfig',
		'/nowarn:1701`,1702',
		'/nostdlib+',
		'/errorreport:prompt',
		'/platform:anycpu',
		'/warn:4'
		"/define:$buildConfigToUpper``;TRACE``;SILVERLIGHT``;$additionalDefines$microsoft_Silverlight_Testing_Version_Name",
		'/debug-',
		'/optimize+',
		'/keyfile:src\StatLight.snk',
		"/out:$outAssemblyName",
		'/target:library'
	)

	$cmd = Build-Csc-Command -options $options -sourceFiles $sourceFiles -references $references -resources $resources
	
	Execute-Command-String $cmd
}

function Remove-If-Exists {
	param($file)
	if(Test-Path $file)
	{
		echo "Deleting file $file"
		Remove-Item $file -Force -Recurse
	}
}

function Build-And-Package-StatLight-MSTest {
	param([string]$microsoft_Silverlight_Testing_Version_Name)
	
	$statlightBuildFilePath = "$build_dir\StatLight.Client.Harness.MSTest.dll"
	
	$references = StatLightReferences $microsoft_Silverlight_Testing_Version_Name
	
	compile-StatLight-MSTestHost $microsoft_Silverlight_Testing_Version_Name $statlightBuildFilePath $references
	
	Assert ( test-path $statlightBuildFilePath) "File should exist $statlightBuildFilePath"
	
	$zippedName = "$build_dir\$statlight_xap_for_prefix.$microsoft_Silverlight_Testing_Version_Name.zip"

	$newAppManifestFile = "$(($pwd).Path)\src\build\AppManifest.xaml"
	Remove-If-Exists $newAppManifestFile

	# the below chunk will add the StatLight.Client.Harness.MSTest to the AppManifest
	$appManifestContent = [xml](get-content "$clientHarnessBuildOutputDir\AppManifest.xaml")
	$extraStuff = '
    <AssemblyPart x:Name="StatLight.Client.Harness.MSTest" Source="StatLight.Client.Harness.MSTest.dll" />
    <AssemblyPart x:Name="Microsoft.Silverlight.Testing" Source="Microsoft.Silverlight.Testing.dll" />
    <AssemblyPart x:Name="Microsoft.VisualStudio.QualityTools.UnitTesting.Silverlight" Source="Microsoft.VisualStudio.QualityTools.UnitTesting.Silverlight.dll" />
'
	$appManifestContent.Deployment."Deployment.Parts".InnerXml = $appManifestContent.Deployment."Deployment.Parts".InnerXml + $extraStuff
	$appManifestContent.Save($newAppManifestFile);

	$zipFiles = StatLightReferences $microsoft_Silverlight_Testing_Version_Name `
				| Where-Object { -not $_.Contains($silverlight_core_assemblies_location) } `
				| foreach{ Get-Item $_}
	$zipFiles += @(
					Get-Item $newAppManifestFile
					Get-Item $statlightBuildFilePath
				)
	Create-Xap $zippedName $zipFiles
}

function Build-And-Package-All-StatLight-MSTest-IntegrationTests {
	param([string]$microsoft_Silverlight_Testing_Version_Name)
	Build-And-Package-StatLight-MSTest-IntegrationTests $microsoft_Silverlight_Testing_Version_Name "SILVERLIGHT3``;" "SL3" "-SL3"
	Build-And-Package-StatLight-MSTest-IntegrationTests $microsoft_Silverlight_Testing_Version_Name "SILVERLIGHT4``;" "SL4" "-SL4"
	Build-And-Package-StatLight-MSTest-IntegrationTests $microsoft_Silverlight_Testing_Version_Name "SILVERLIGHT5``;" "SL5" "-SL5"
}

function Build-And-Package-StatLight-MSTest-IntegrationTests {
	param([string]$microsoft_Silverlight_Testing_Version_Name, [string]$additionalDefines, [string]$silverlightVersion, [string]$dllPostfix)

	$dllName = "StatLight.IntegrationTests.Silverlight.MSTest" + $dllPostfix + ".dll"
	$dllPath = "$build_dir\$dllName"

	Remove-If-Exists $dllPath

	$references = StatLightIntegrationTestsReferences $microsoft_Silverlight_Testing_Version_Name

	compile-StatLight-MSTestHostIntegrationTests $microsoft_Silverlight_Testing_Version_Name $dllPath $additionalDefines $references
	
	$zippedName = "$build_dir\StatLight.Client.For.$microsoft_Silverlight_Testing_Version_Name.Integration-" + $silverlightVersion + ".zip"
	$sourceAppManifest = "src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\Bin\$build_configuration\AppManifest-" + $silverlightVersion + ".xaml"
	Copy-Item $sourceAppManifest "src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\Bin\$build_configuration\AppManifest.xaml"
	$zipFiles = StatLightIntegrationTestsReferences $microsoft_Silverlight_Testing_Version_Name `
				| Where-Object { -not $_.Contains($silverlight_core_assemblies_location) } `
				| foreach{ Get-Item $_}
				$zipFiles += @(
					Get-Item "src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\Bin\$build_configuration\AppManifest.xaml"
					Get-Item $dllPath
				)

	Create-Xap $zippedName $zipFiles
}

function Create-Xap {
	param($newZipFileName, $filesToInclude)
	Remove-If-Exists $newZipFileName
	$filesToInclude | Zip-Files-From-Pipeline $newZipFileName
	Move-Item $newZipFileName $newZipFileName.Replace(".zip", ".xap")
}

function Get-x86-ProgramFiles-Location {
	$program_files_dir = 'C:\Program Files'	
	if(Test-Win64Machine)
	{
		$program_files_dir = 'C:\Program Files (x86)'
	}
	$program_files_dir;
}

function Is-Release-Build {
	if($build_configuration.Equals('Release'))
	{
		$return = $true
	}
	else
	{
		$return = $false
	}
	$return;
}

function Get-Not-Build-Configuration {
	if(Is-Release-Build)
	{
		$not_build_configuration = 'Debug'
	}
	else
	{
		$not_build_configuration = 'Release'
	}
	$not_build_configuration;
}

function GetTemporaryXmlFile()
{
	$tempFileGuid = ([System.Guid]::NewGuid())
	$scriptFile = ("$($pwd.Path)\temp_statlight-integration-output-$tempFileGuid.xml")
	Remove-If-Exists $scriptFile
	$scriptFile
}

function execStatLight()
{
	# Run the integration tests with the FireFox browser.
	#& "$build_dir\StatLight.exe" "--WebBrowserType:Firefox" $args
	& "$build_dir\StatLight.exe" $args
}


function Execute-MSTest-Version-Acceptance-Tests-AllSL {
	param([string]$microsoft_Silverlight_Testing_Version_Name)
	Execute-MSTest-Version-Acceptance-Tests $microsoft_Silverlight_Testing_Version_Name "SL3"
	Execute-MSTest-Version-Acceptance-Tests $microsoft_Silverlight_Testing_Version_Name "SL4"
	Execute-MSTest-Version-Acceptance-Tests $microsoft_Silverlight_Testing_Version_Name "SL5"
}

function Execute-MSTest-Version-Acceptance-Tests {
	param([string]$microsoft_Silverlight_Testing_Version_Name, [string]$slVersion)
	
	$scriptFile = GetTemporaryXmlFile;
	$xapDefinition = "-x=$build_dir\StatLight.Client.For.$microsoft_Silverlight_Testing_Version_Name.Integration-" + $slVersion + ".xap"
	execStatLight $xapDefinition "-v=$microsoft_Silverlight_Testing_Version_Name" "-r=$scriptFile" --debug
	
	if($build_configuration -eq 'Debug')
	{
		Assert-statlight-xml-report-results -message "Execute-MSTest-Version-Acceptance-Tests" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 9 -expectedFailedCount 4 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 1
	}
	else
	{
		Assert-statlight-xml-report-results -message "Execute-MSTest-Version-Acceptance-Tests" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 9 -expectedFailedCount 3 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 1
	}
	
	#added sleep to wait for file system to loose the lock on the file so we can delete it
	[System.Threading.Thread]::Sleep(500);
	Remove-If-Exists $scriptFile
	Remove-If-Exists ".\temp_statlight-integration-output-*"
}

function AssertXmlReportIsValid([string]$scriptFile)
{
	if([System.Environment]::Version.Major -ge 4) {
		$statLightCoreFilePath = (Get-Item "$build_dir\StatLight.Core.dll").FullName
		$fileStream = ([System.IO.FileInfo] (Get-Item $statLightCoreFilePath)).OpenRead()
		$assemblyBytes = new-object byte[] $fileStream.Length
		$fileStream.Read($assemblyBytes, 0, $fileStream.Length) | Out-Null #out null this because this function should only return the version & this call was outputting some garbage number
		$fileStream.Close()
		[System.Reflection.Assembly]::Load($assemblyBytes) | Out-Null;
		
		$errs = $null
		$passed = [StatLight.Core.Reporting.Providers.Xml.XmlReport]::ValidateSchema($scriptFile, [ref] $errs)
		if($passed -eq $false)
		{
			foreach($msg in $errs)
			{
				Write-Host $msg -ForegroundColor Red
			}
			throw "Failed the xmlreport schema validation."
		}
	}
	else {
		Write-Warning "Not running xml schema validation - must run powershell under .net 4.0 or higher"
	}
}

function Get-Git-Commit
{
	try {
		$gitLog = git log --oneline -1
		if($gitLog){
			$gitLog.Split(' ')[0]
		}
		else {
			#Pull the TeamCity environment variable (hash)
			(ls env:BUILD_VCS_NUMBER).Value.SubString(0, 7)
		}
	}
	catch {
		"0000000"
	}
	$Error.Clear();
}


function LoadZipAssembly {
	if(!(Test-Path ('variable:hasLoadedIonicZipDll')))
	{
		$scriptDir = ".\lib\Desktop\DotNetZip"
		$zippingAssembly = (Get-Item "$scriptDir\Ionic.Zip.Reduced.dll").FullName

		echo "loading Zipping assembly [$zippingAssembly]..."
		[System.Reflection.Assembly]::LoadFrom($zippingAssembly) | Out-Null
		$hasLoadedIonicZipDll = $true;
	}
}

function Zip-Files-From-Pipeline
{
    param([string]$zipfilename, [bool] $addAllZipsToRoot = $true)
	
	BEGIN {
		
		LoadZipAssembly;
	
		$pwdPath = $PWD.Path;
	
		$zipfile =  new-object Ionic.Zip.ZipFile
	}
	PROCESS {
		[string] $fileFullName;
		$isDirectory = $false
		$file = $_

		if($file.GetType() -eq [string])
		{
			$fileFullName = $file
		}
		elseif($file.GetType() -eq [System.IO.FileInfo])
		{
			$fileInfo = [System.IO.FileInfo]$file
			$fileFullName = $fileInfo.FullName
		}
		elseif($file.GetType() -eq [System.IO.DirectoryInfo])
		{
			$directoryToZip = "$($file.FullName)".Replace("\", "\\")
			echo "Zipping Directory $directoryToZip"
			$zipfile.AddDirectory($directoryToZip, "")
			echo "Directory added..."
			$isDirectory = $true
		}
		else
		{
			echo "DEBUG: PSIsContainer = $($file.PSIsContainer)"
			echo "DEBUG: PSPath = $($file.PSPath)"
			echo "DEBUG: FullName = $($file.FullName)"
			
			$unknownTypeName = $file.GetType();
			throw "Zip-Files-From-Pipeline - Can only work with [string] and [System.IO.FileInfo] items. Cannot use unknown type - [$unknownTypeName]"
		}
		
		if(!$isDirectory)
		{
			if($addAllZipsToRoot -eq $true)
			{
				$zipfile.AddFile($fileFullName, "") | Out-Null
			}
			else
			{
				if($fileFullName.Substring(0, $pwdPath.Length) -eq $pwdPath)
				{
					$hackedFileName = $fileFullName.Substring($pwdPath.Length);
				}
				else
				{
					$hackedFileName = $fileFullName
				}
		
				$hackedFileName = Split-Path $hackedFileName -Parent
	
				$zipfile.AddFile($fileFullName, $hackedFileName) | Out-Null
			}
		}
	}	
	END {
		echo "Saving zip to $pwdPath\$zipfilename"
		$zipfile.Save("$pwdPath\$zipfilename")
		$zipfile.Dispose()
	}
}

#########################################
#
# build script misc pre-build tasks
#
#########################################

Task initialize { 

	#
	#Value	Meaning
	#0	Turn script tracing off.
	#1	Trace script lines as they are executed.
	#2	Trace script lines, variable assignments, function calls, and scripts.
	#Set-PSDebug -Trace 0
	
	$ErrorActionPreference = "Stop"
	
	echo "running build with configuration of $build_configuration"
	echo "running build with configuration of $build_dir"
	
	# warning in-case you place statlight source root too far down in the directory structure
	if(((pwd).path.length + 180) -gt 255){
		throw "It looks like you've placed the StatLight src in a directory that is too deep. You will run into problems building - look to move the StatLight up a few folders before trying the build."
	}
}

#########################################
#
# Building/Compilation tasks
#
#########################################

Task create-AssemblyInfo {

	$versionInfoFile = 'src/VersionInfo.cs'
	Remove-If-Exists $versionInfoFile
	New-Item -ItemType file $versionInfoFile -Force | out-null
	
	$commit = Get-Git-Commit

	$asmInfo = "
[assembly: System.Reflection.AssemblyInformationalVersion(""$commit"")]
"
	Write-Output $asmInfo > $versionInfoFile
}

Task clean-build {
	#-ErrorAction SilentlyContinue --- because of the *.vshost which is locked and we can't delete.
	Remove-If-Exists $build_dir\*
	Remove-If-Exists $release_dir
	Remove-If-Exists temp*
	
	mkdir $build_dir -Force
}

Task compile-StatLight-MSTestHostVersions {

	rename-file-extensions -itemsPath "$build_dir\*.xap" -fromExtension ".xap" -toExtension ".zip"

	$microsoft_silverlight_testing_versions | foreach { Build-And-Package-StatLight-MSTest $_ }

	rename-file-extensions -itemsPath "$build_dir\*.zip" -fromExtension ".zip" -toExtension ".xap"
}

Task compile-StatLight-MSTestHostVersionIntegrationTests {
	
	rename-file-extensions -itemsPath "$build_dir\*.xap" -fromExtension ".xap" -toExtension ".zip"

	$microsoft_silverlight_testing_versions | foreach { Build-And-Package-All-StatLight-MSTest-IntegrationTests $_ }

	rename-file-extensions -itemsPath "$build_dir\*.zip" -fromExtension ".zip" -toExtension ".xap"
}

Task compile-Solution {
	$msbuild = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
	$verbosity = "/verbosity:normal"
	$solutionFolder = (split-path (get-item $solutionFile))
	
	exec { . $msbuild $solutionFile /t:Rebuild /p:Configuration=$build_configuration /p:Platform=x86 $verbosity /nologo /p:CompileTimeSolutionDir="$solutionFolder" } 'msbuild failed on $solutionFile'
}

Task compile-Solution-Phone {
	$script:isPhoneBuild = $true
	$msbuild = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
	$verbosity = "/verbosity:normal"
	$solutionFolder = (split-path (get-item $solutionFilePhone))
	
	exec { . $msbuild $solutionFilePhone /t:Rebuild /p:Configuration=$build_configuration /p:Platform=x86 $verbosity /nologo /p:CompileTimeSolutionDir="$solutionFolder" } 'msbuild failed $solutionFilePhone'
}

Task compile-StatLight-UnitDrivenHost {
	$unitDrivenXapFile = ".\src\StatLight.Client.Harness.UnitDriven\Bin\$build_configuration\StatLight.Client.Harness.dll"
	$references = (ls .\src\StatLight.Client.Harness.UnitDriven\Bin\$build_configuration\*.dll)
	$referencedNames = ($references | foreach { $_.Name.TrimEnd(".dll") })
	
	
	$zippedName = "$build_dir\$statlight_xap_for_prefix.UnitDriven2009December.zip"

	$appManifestContent = [string] '<Deployment xmlns="http://schemas.microsoft.com/client/2007/deployment" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" EntryPointAssembly="StatLight.Client.Harness" EntryPointType="StatLight.Client.Harness.App" RuntimeVersion="4.0.50401.00">
		<Deployment.Parts>'
	
	$referencedNames | foreach { 
		$ass = $_
		$extraStuff = "
			<AssemblyPart x:Name=""$ass"" Source=""$ass.dll"" />"
		$appManifestContent += $extraStuff	
	}

	$appManifestContent += '	</Deployment.Parts>
	</Deployment>'

	$newAppManifestFile = "$(($pwd).Path)\src\build\AppManifest.xaml"
	Remove-If-Exists $newAppManifestFile
	([xml]$appManifestContent).Save($newAppManifestFile);

	$zipFiles = $references
	$zipFiles += @(
					Get-Item $newAppManifestFile
				)

	Remove-If-Exists $zippedName
	#throw 'a'
	$zipFiles | Zip-Files-From-Pipeline $zippedName | Out-Null
	#Create-Xap $zippedName $zipFiles
}

Task compile-StatLight-XUnitContribHost {
	$xunitContribXapFile = ".\src\StatLight.Client.Harness.XUnit\Bin\$build_configuration\StatLight.Client.Harness.dll"
	$references = (ls .\src\StatLight.Client.Harness.XUnit\Bin\$build_configuration\*.dll)
	$referencedNames = ($references | foreach { $_.Name.TrimEnd(".dll") })
	
	
	$zippedName = "$build_dir\$statlight_xap_for_prefix.XUnitContrib2011April.zip"

	$appManifestContent = [string] '<Deployment xmlns="http://schemas.microsoft.com/client/2007/deployment" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" EntryPointAssembly="StatLight.Client.Harness" EntryPointType="StatLight.Client.Harness.App" RuntimeVersion="4.0.50401.00">
		<Deployment.Parts>'
	
	$referencedNames | foreach { 
		$ass = $_
		$extraStuff = "
			<AssemblyPart x:Name=""$ass"" Source=""$ass.dll"" />"
		$appManifestContent += $extraStuff	
	}

	$appManifestContent += '	</Deployment.Parts>
	</Deployment>'

	$newAppManifestFile = "$(($pwd).Path)\src\build\AppManifest.xaml"
	Remove-If-Exists $newAppManifestFile
	([xml]$appManifestContent).Save($newAppManifestFile);

	$zipFiles = $references
	$zipFiles += @(
					Get-Item $newAppManifestFile
				)

	Remove-If-Exists $zippedName
	#throw 'a'
	$zipFiles | Zip-Files-From-Pipeline $zippedName | Out-Null
	#Create-Xap $zippedName $zipFiles
}

Task compile-StatLight-XUnitContribHost-Phone {
	$references = (ls .\src\StatLight.Client.Harness.XUnitPhone\Bin\$build_configuration\*.dll)
	$png = (ls .\src\StatLight.Client.Harness.Phone\*.png)
	$jpg = (ls .\src\StatLight.Client.Harness.Phone\*.jpg)
	$manifest = (ls .\src\StatLight.Client.Harness.Phone\WMAppManifest.xml)
	$referencedNames = ($references | foreach { $_.Name.TrimEnd(".dll") })
	
	$zippedName = "$build_dir\$statlight_xap_for_prefix.XUnitContrib2011AprilPhone.zip"

	$appManifestContent = [string] '<Deployment xmlns="http://schemas.microsoft.com/client/2007/deployment" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" EntryPointAssembly="StatLight.Client.Harness.Phone" EntryPointType="StatLight.Client.Harness.Phone.App" RuntimeVersion="3.0.40624.0">
		<Deployment.Parts>'
	
	$referencedNames | foreach { 
		$ass = $_
		$extraStuff = "
			<AssemblyPart x:Name=""$ass"" Source=""$ass.dll"" />"
		$appManifestContent += $extraStuff	
	}

	$appManifestContent += '	</Deployment.Parts>
	</Deployment>'

	$newAppManifestFile = "$(($pwd).Path)\src\build\AppManifest.xaml"
	Remove-If-Exists $newAppManifestFile
	([xml]$appManifestContent).Save($newAppManifestFile);

	$zipFiles = $references
	$zipFiles += $png
	$zipFiles += $jpg
	$zipFiles += $manifest
	$zipFiles += @(
					Get-Item $newAppManifestFile
				)

	Remove-If-Exists $zippedName
	#throw 'a'
	$zipFiles | Zip-Files-From-Pipeline $zippedName | Out-Null
	#Create-Xap $zippedName $zipFiles
}

Task compile-StatLight-MSTest-Phone {
	$references = (ls .\src\StatLight.Client.Harness.MSTestPhone\Bin\$build_configuration\*.dll)
	$png = (ls .\src\StatLight.Client.Harness.Phone\*.png)
	$jpg = (ls .\src\StatLight.Client.Harness.Phone\*.jpg)
	$manifest = (ls .\src\StatLight.Client.Harness.Phone\WMAppManifest.xml)
	$referencedNames = ($references | foreach { $_.Name.TrimEnd(".dll") })
	
	$zippedName = "$build_dir\$statlight_xap_for_prefix.MSTest2010MayPhone.zip"

	$appManifestContent = [string] '<Deployment xmlns="http://schemas.microsoft.com/client/2007/deployment" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" EntryPointAssembly="StatLight.Client.Harness.Phone" EntryPointType="StatLight.Client.Harness.Phone.App" RuntimeVersion="3.0.40624.0">
		<Deployment.Parts>'
	
	$referencedNames | foreach { 
		$ass = $_
		$extraStuff = "
			<AssemblyPart x:Name=""$ass"" Source=""$ass.dll"" />"
		$appManifestContent += $extraStuff	
	}

	$appManifestContent += '	</Deployment.Parts>
	</Deployment>'

	$newAppManifestFile = "$(($pwd).Path)\src\build\AppManifest.xaml"
	Remove-If-Exists $newAppManifestFile
	([xml]$appManifestContent).Save($newAppManifestFile);

	$zipFiles = $references
	$zipFiles += $png
	$zipFiles += $jpg
	$zipFiles += $manifest
	$zipFiles += @(
					Get-Item $newAppManifestFile
				)

	Remove-If-Exists $zippedName
	#throw 'a'
	$zipFiles | Zip-Files-From-Pipeline $zippedName | Out-Null
	#Create-Xap $zippedName $zipFiles
}
#########################################
#
# Unit/Integration tests
#
#########################################


Task test-core {
	exec { & $nunit_console_path $test_assembly_path } 'Unit Tests Failed'
}

Task test-integrationTests {
	exec { & $nunit_console_path $integration_test_assembly_path /noshadow } 'test-integrationTests Failed'
}


Task test-tests-in-other-assembly {
	
	$scriptFile = GetTemporaryXmlFile;
	
	execStatLight "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.xap" "-t=OtherAssemblyTests" "-r=$scriptFile"
	
	Assert-statlight-xml-report-results -message "test-tests-in-other-assembly" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 2 -expectedFailedCount 1 -expectedIgnoredCount 1
}

Task test-client-harness-tests {
	exec { execStatLight "-x=.\src\StatLight.Client.Tests\Bin\$build_configuration\StatLight.Client.Tests.xap" -o=MSTest } 'test-client-harness-tests Failed'
}


Task test-specific-method-filter {
	$scriptFile = GetTemporaryXmlFile;
	
	execStatLight "-x=src\IntegrationTests\StatLight.IntegrationTests.Silverlight\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.xap" '--MethodsToTest="StatLight.IntegrationTests.Silverlight.TeamCityTests.this_should_be_a_passing_test;StatLight.IntegrationTests.Silverlight.TeamCityTests.this_should_be_a_Failing_test;"' "-o=MSTest" "-r=$scriptFile"

	Assert-statlight-xml-report-results -message "test-specific-method-filter" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 1 -expectedFailedCount 1
}

Task test-auto-detects-xunit-contrib {
	$scriptFile = GetTemporaryXmlFile;

	execStatLight "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.xUnitContrib\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.xUnitContrib.xap" "-r=$scriptFile"

	Assert-statlight-xml-report-results -message "test-auto-detects-xunit-contrib" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 3 -expectedFailedCount 1 -expectedIgnoredCount 1
}

Task test-multiple-xaps {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.MSTest-SL5.xap" "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest.UITests\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.MSTest.UITests.xap" "-r=$scriptFile" -b
	if(Is-Release-Build){
		Assert-statlight-xml-report-results -message "test-multiple-xaps" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 12 -expectedFailedCount 3 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 1
	}
	else {
		Assert-statlight-xml-report-results -message "test-multiple-xaps" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 12 -expectedFailedCount 4 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 1
	}
}

Task test-multiple-one-xap-one-dll {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.MSTest-SL5.xap" "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.OtherTestAssembly\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.OtherTestAssembly.dll" "-o=MSTest" "-r=$scriptFile" 

	if(Is-Release-Build){
		Assert-statlight-xml-report-results -message "test-multiple-one-xap-one-dll" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 12 -expectedFailedCount 4 -expectedIgnoredCount 2 -expectedSystemGeneratedfailedCount 1
	}
	else {
		Assert-statlight-xml-report-results -message "test-multiple-one-xap-one-dll" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 12 -expectedFailedCount 5 -expectedIgnoredCount 2 -expectedSystemGeneratedfailedCount 1
	}
}

Task test-multiple-two-dlls {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.MSTest-SL5.dll" "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.OtherTestAssembly\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.OtherTestAssembly.dll" "-o=MSTest" "-v=MSTest2011October" "-r=$scriptFile" 

	if(Is-Release-Build){
		Assert-statlight-xml-report-results -message "test-multiple-two-dlls" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 12 -expectedFailedCount 4 -expectedIgnoredCount 2 -expectedSystemGeneratedfailedCount 1
	}
	else {
		Assert-statlight-xml-report-results -message "test-multiple-two-dlls" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 12 -expectedFailedCount 5 -expectedIgnoredCount 2 -expectedSystemGeneratedfailedCount 1
	}
}

Task test-statlight-no-communication-from-browser-forced-timeout {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.dll" "-r=$scriptFile" '--MethodsToTest="StatLight.IntegrationTests.Silverlight.LongRunningAsyncTests.Should_take_a_really_long_time_and_probably_timeout;"' '--OverrideSetting:MaxWaitTimeAllowedBeforeCommunicationErrorSent=00:00:10'

	Assert-statlight-xml-report-results -message "test-statlight-no-communication-from-browser-forced-timeout" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 0 -expectedFailedCount 1 -expectedIgnoredCount 0 -expectedSystemGeneratedfailedCount 0
}

Task test-one-dll-not-referencing-MicrosoftSilverlightTesting-dll {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.NoRefToMicrosoftSLTesting\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.NoRefToMicrosoftSLTesting.dll" "-r=$scriptFile" 
	
	if(Is-Release-Build){
		Assert-statlight-xml-report-results -message "test-one-dll-not-referencing-MicrosoftSilverlightTesting-dll" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 1 -expectedFailedCount 0 -expectedIgnoredCount 0 -expectedSystemGeneratedfailedCount 0
	}
	else {
		Assert-statlight-xml-report-results -message "test-one-dll-not-referencing-MicrosoftSilverlightTesting-dll" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 1 -expectedFailedCount 0 -expectedIgnoredCount 0 -expectedSystemGeneratedfailedCount 0
	}
}

Task test-remote-access-querystring {
	$hostServieWebsitePath = (Get-Item .\src\IntegrationTests\StatLight.RemoteIntegration\StatLight.RemoteIntegration.Web);

	$cassiniPort = 8085
	$cassiniDevProcessExe = (Get-Item ".\Tools\CassiniDev\CassiniDev4-console.exe")
	$cassiniDevProcessArgs = "/path:$hostServieWebsitePath /pm:Specific /p:8085"
	echo "$cassiniDevProcessExe $cassiniDevProcessArgs"
	$cassiniProcess = [System.Diagnostics.Process]::Start($cassiniDevProcessExe, $cassiniDevProcessArgs)
	
	$scriptFile = GetTemporaryXmlFile;
	
	execStatLight "-x=.\src\IntegrationTests\StatLight.RemoteIntegration\StatLight.ExternalWebTest\Bin\$build_configuration\StatLight.ExternalWebTest.xap" "-r=$scriptFile" "-QueryString=RemoteCallbackServiceUrl=http://localhost:$cassiniPort/Service1.svc" 
	
	Stop-Process $cassiniProcess.Id -ErrorAction SilentlyContinue

	Assert-statlight-xml-report-results -message "test-remote-access-test" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 3
}

Task test-specific-multiple-browser-runner {

	#$browsers = @( 'SelfHosted', 'Firefox', 'chrome' )
	$browsers = @( 'SelfHosted' )
	
	foreach( $browser in $browsers )
	{
		MultipleBrowserRunner $browser
	}
}

function MultipleBrowserRunner($browser)
{
	echo "Executing StatLight tests for WebBrowser type $browser"
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "--WebBrowserType:$browser" "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.LotsOfTests\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.LotsOfTests.xap" "-r=$scriptFile" "-NumberOfBrowserHosts=5"
	Assert-statlight-xml-report-results -message "test-specific-mutiple-browser-runner" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 1000
}

function Assert-statlight-xml-report-results
{
	param ( $message,
			$resultsXmlTextFilePath,
			$expectedPassedCount = 0,
			$expectedIgnoredCount = 0,
			$expectedFailedCount = 0,
			$expectedSystemGeneratedfailedCount = 0 )	
			
	Echo "Asserting xml report results for $message. File=$resultsXmlTextFilePath"
	AssertXmlReportIsValid $scriptFile

	$testReportXml = [xml](Get-Content $scriptFile)
	function assertResultTypeCount($resultTypeToLookFor, $count)
	{
		$allTestNodes = $testReportXml.StatLightTestResults.Tests | %{ $_.Test }
		$filteredTestNodes = ($allTestNodes | where-object { $_.ResultType -eq $resultTypeToLookFor })
		$foundCount = ($filteredTestNodes| Measure-Object).Count
		echo "*********************************"
		echo "ERROR result type: $resultTypeToLookFor"
		$foundCount.ShouldEqual($count)
		echo "*********************************"
	}
	
	assertResultTypeCount 'Passed' $expectedPassedCount
	assertResultTypeCount 'Ignored' $expectedIgnoredCount
	assertResultTypeCount 'Failed' $expectedFailedCount
	assertResultTypeCount 'SystemGeneratedFailure' $expectedSystemGeneratedfailedCount
}

Task test-all-mstest-version-acceptance-tests {
##	@( 'MSTest2011October' ) | foreach { Execute-MSTest-Version-Acceptance-Tests-AllSL $_ }
#	@( 'MSTest2011October' ) | foreach { Execute-MSTest-Version-Acceptance-Tests-AllSL $_ }
	$microsoft_silverlight_testing_versions | foreach { Execute-MSTest-Version-Acceptance-Tests-AllSL $_ }
}

Task test-custom-test-provider {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-x=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.CustomTestProvider\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.CustomTestProvider.xap"  "-r=$scriptFile" "--OverrideTestProvider=MSTestWithCustomProvider"
	
	Assert-statlight-xml-report-results -message "test-custom-test-provider" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 2 -expectedFailedCount 0 -expectedIgnoredCount 0 -expectedSystemGeneratedfailedCount 0
}

Task test-single-assembly-run {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-d=src\IntegrationTests\StatLight.IntegrationTests.Silverlight.OtherTestAssembly\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.OtherTestAssembly.dll"  "-r=$scriptFile"
	
	Assert-statlight-xml-report-results -message "test-single-assembly-run" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 3 -expectedFailedCount 1 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 0
}

Task test-sample-extension {
	mkdir -Force ".\src\build\bin\$build_configuration\Extensions\" | Out-Null
	cp ".\src\Samples\SampleExtension\bin\$build_configuration\SampleExtension.dll" ".\src\build\bin\$build_configuration\Extensions\" -Force

	execStatLight "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.OtherTestAssembly\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.OtherTestAssembly.dll" | Tee-Object -variable output 

	if(($output | select-string "Hello From Class1" | Measure).Count -eq 0){
		$output
		throw "Extension did not print expected output"
	}
	rm -Force ".\src\build\bin\$build_configuration\Extensions\SampleExtension.dll"
}


Task test-UI-show-browser {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest.UITests\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.MSTest.UITests.dll" "-r=$scriptFile" -b

	Assert-statlight-xml-report-results -message "test-single-assembly-run" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 3 -expectedFailedCount 0 -expectedIgnoredCount 0 -expectedSystemGeneratedfailedCount 0
}

Task test-UI-NoBrowser-displays-warning {

# TODO: make this run against all supported MSTest versions?
	execStatLight "-d=.\src\IntegrationTests\StatLight.IntegrationTests.Silverlight.MSTest.UITests\Bin\$build_configuration\StatLight.IntegrationTests.Silverlight.MSTest.UITests.dll" | Tee-Object -variable output 

	if(($output | select-string "Looks like your trying to use the Silverlight Test Framework's TestPanel." | Measure).Count -eq 0){
		$output
		throw "Did not detect usage of TestPanel and report to the user."
	}
}

Task test-phone-xap {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-x=src\StatLight.IntegrationTests.Phone.MSTest\Bin\$build_configuration\StatLight.IntegrationTests.Phone.MSTest.xap"  "-r=$scriptFile" "--UsePhoneEmulator"
	

	if( Is-Release-Build ) {
		Assert-statlight-xml-report-results -message "test-single-assembly-run" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 4 -expectedFailedCount 2 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 0
	}
	else {
		Assert-statlight-xml-report-results -message "test-single-assembly-run" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 5 -expectedFailedCount 2 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 0
	}
}

Task test-phone-dll {
	$scriptFile = GetTemporaryXmlFile;
	execStatLight "-d=src\StatLight.IntegrationTests.Phone.MSTest\Bin\$build_configuration\StatLight.IntegrationTests.Phone.MSTest.dll"  "-r=$scriptFile" "--UsePhoneEmulator"
	

	if( Is-Release-Build ) {
		Assert-statlight-xml-report-results -message "test-phone-dll" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 4 -expectedFailedCount 2 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 0
	}
	else {
		Assert-statlight-xml-report-results -message "test-phone-dll" -resultsXmlTextFilePath $scriptFile -expectedPassedCount 5 -expectedFailedCount 2 -expectedIgnoredCount 1 -expectedSystemGeneratedfailedCount 0
	}
}

#########################################
#
# Release packaging
#
#########################################

Task clean-release {
	if(-not (Test-Path $release_dir))
	{
		New-Item $release_dir -type directory -force | Out-Null
	}
	Remove-If-Exists "$release_dir\*" | Out-Null
}

Task package-zip-project-sources-snapshot {
	# files to zip ... (Get all files & run all the files thought this exclusion logic)...
	$files = (Get-ChildItem -Path .\ -Recurse | `
		where { !($_.PSIsContainer) } | `
		where { !($_.GetType() -eq [System.IO.DirectoryInfo])} | `
		where { ($_.FullName -notlike "*\obj\*") } | `
		where { ($_.FullName -notlike "*\bin\*") } | `
		where { ($_.FullName -notlike "*\src\build\*") } | `
		where { ($_.FullName -notlike "*\_Resharper*") } | `
		where { ($_.FullName -notlike "*\.git*") } | `
		where { ($_.FullName -notlike "*TestResult.xml") } | `
		where { ($_.FullName -notlike "*.sln.cache") } | `
		where { ($_.FullName -notlike "*.user") } | `
		where { ($_.FullName -notlike "*\Release\*") })

	$versionString = get-formatted-assembly-version $core_assembly_path
	$sourceZipFile = "$statLightSourcesFilePrefix$versionString.zip"
	
	echo "Remove-If-Exists $sourceZipFile"
	Remove-If-Exists $sourceZipFile | Out-Null

	#DEBUG: $files | foreach{ echo "$($_.GetType()) - $_" }

	echo "Zipping up the source files"
	$files | Zip-Files-From-Pipeline $sourceZipFile $false | Out-Null
	
	echo "Moving the zipped source into the $release_dir folder."
	mv $sourceZipFile $release_dir\$sourceZipFile -Force | Out-Null
}

Task package-release -depends clean-release {
	$versionNumber = get-formatted-assembly-version $core_assembly_path
	$commit = Get-Git-Commit
	$versionNumber = $versionNumber + "-" + $commit

	$versionBuildPath = "$release_dir\$versionNumber"

	$expectedFilesToInclude = @(
			'StatLight.Client.For.MSTest2011December.xap'
			'StatLight.Client.For.MSTest2011October.xap'
			'StatLight.Client.For.MSTest2011June.xap'
			'StatLight.Client.For.MSTest2011Feb.xap'
			'StatLight.Client.For.MSTest2010March.xap'
			'StatLight.Client.For.MSTest2010April.xap'
			'StatLight.Client.For.MSTest2010May.xap'
			'StatLight.Client.For.MSTest2009July.xap'
			'StatLight.Client.For.MSTest2009October.xap'
			'StatLight.Client.For.MSTest2009November.xap'
			'Ionic.Zip.Reduced.dll'
			'Microsoft.Silverlight.Testing.License.txt'
			'StatLight.Client.For.UnitDriven2009December.xap'
			'StatLight.Client.For.XUnitContrib2011April.xap'
			'StatLight.Core.dll'
			'StatLight.EULA.txt'
			'StatLight.exe'
			'StatLight.exe.config'
		)
			#TODO 'StatLight.chm'
		
	if($script:isPhoneBuild -eq $true){
		$expectedFilesToInclude += @(
			'StatLight.Client.For.MSTest2010MayPhone.xap'
			'StatLight.WindowsPhoneEmulator.dll'
			'StatLight.Client.For.XUnitContrib2011AprilPhone.xap'
		)
	}
"****"
	$expectedFilesToInclude
"****"

	$knownFilesToExclude = @(
		'Microsoft.Silverlight.Testing.dll'
		'Microsoft.VisualStudio.QualityTools.UnitTesting.Silverlight.dll'
		'nunit.framework.dll'
		'StatLight.IntegrationTests.dll'
		'StatLight.Client.Harness.MSTest.dll'
		'StatLight.IntegrationTests.Silverlight.MSTest-SL3.dll'
		'StatLight.IntegrationTests.Silverlight.MSTest-SL4.dll'
		'StatLight.IntegrationTests.Silverlight.MSTest-SL5.dll'
		'StatLight.Core.Phone.dll'
	)

	$filesToCopyFromBuild = @(
		Get-ChildItem "$build_dir\*.xap" | where{ -not $_.FullName.Contains("Integration") }
		Get-ChildItem $build_dir\* -Include *.dll, *.txt, StatLight.exe, StatLight.exe.config
		Get-ChildItem ".\StatLight.EULA.txt"
	)

	New-Item -Path $versionBuildPath -Force -ItemType directory | Out-Null

	#Move-Item (Get-ChildItem $release_dir\$statLightSourcesFilePrefix*) "$versionBuildPath\$($_.Name)"
	$filesToCopyFromBuild | foreach{ Copy-Item $_ "$versionBuildPath\$($_.Name)"  }
	#TODO cp $chmDocPath "$versionBuildPath\StatLight.chm" 


	$knownFilesToExclude | where { Test-Path "$versionBuildPath\$_" } | foreach{ Remove-Item "$versionBuildPath\$_"; "Cleaning - $versionBuildPath\$_" }
	
	$unexpectedFilesInReleaseDir = (Get-ChildItem $versionBuildPath -Exclude $expectedFilesToInclude)
	if($unexpectedFilesInReleaseDir.Count)
	{
		$unexpectedFilesInReleaseDir
		throw "Unexpected files in release directory"
	}
	
	foreach($expectedFile in $expectedFilesToInclude)
	{
		Assert (Test-Path "$versionBuildPath\$expectedFile") "Could not find expected file $expectedFile in release directory $versionBuildPath"
	}
	
	Assert ($assertAllFilesWereFound.Count -eq $assertAllFilesWereFound.Count) "Not all the necessary files were found in the release directory - $expectedFilesToInclude"
	
	$release_zip_path = "$release_dir\StatLight.$versionNumber.zip"
	
	Get-Item $versionBuildPath | Zip-Files-From-Pipeline $release_zip_path
	Write-Host -ForegroundColor Green "*************************************************"
	Write-Host -ForegroundColor Green "Release build $versionNumber - Created in the following folder."
	Write-Host -ForegroundColor Green "     $(get-item $release_dir)"
	Write-Host -ForegroundColor Green "*************************************************"
	
	<#
	Write-Host "Creating NuPack package"
	mkdir "Release\NuPack\tools" -Force
	cp "$versionBuildPath\*" "Release\NuPack\tools"
	cp "StatLight.nuspec" "Release\NuPack\"
	$nuSpecFile = get-item "Release\NuPack\StatLight.nuspec"
	$nuPackDate = [System.String]::Format("{0:s}", (get-date))
	$nuSpec = [xml] (cat $nuSpecFile)
	$nuSpec.Package.Metadata.version = "$version"
	$nuSpec.Package.Metadata.created = $nuPackDate
	$nuSpec.Package.Metadata.modified = $nuPackDate
	$nuSpec.Save($nuSpecFile);
	#>
}


Task help -Description "Prints out the different tasks within the StatLIght build engine." {
	Write-Documentation
}

Task ? -Description "Prints out the different tasks within the StatLIght build engine." {
	Write-Documentation
}

Task compile-docs {
	pushd .\docs
		Remove-If-Exists .\_build\*
		.\make.bat htmlhelp
		& 'C:\Program Files (x86)\HTML Help Workshop\hhc.exe' .\_build\htmlhelp\StatLightdoc.hhp
	popd
}

Task doc -depends compile-docs {
	& $chmDocPath
}

Task test-UI -depends 	test-UI-NoBrowser-displays-warning, test-UI-show-browser {
}

Task test-multiple -depends test-multiple-xaps, test-multiple-one-xap-one-dll, test-multiple-two-dlls {
}

Task test-single-assemblies -depends test-single-assembly-run, test-one-dll-not-referencing-MicrosoftSilverlightTesting-dll {
}

Task test-phone -depends test-phone-xap, test-phone-dll {
}

Task build-Debug -depends build-all, test-all {
}

Task build-Debug-Phone -depends build-all, compile-Solution-Phone, test-all, test-phone {
}

Task build-full-Release -depends build-all, `
	test-all, `
	compile-docs, `
	package-release {
}

Task build-full-Release-Phone -depends `
	build-all-phone, `
	test-all, `
	test-phone, `
	compile-docs, `
	package-release {
}

Task test-all -depends `
	test-core, `
	test-client-harness-tests, `
	test-integrationTests, `
	test-all-mstest-version-acceptance-tests, `
	test-tests-in-other-assembly, `
	test-specific-method-filter, `
	test-remote-access-querystring, `
	test-specific-multiple-browser-runner, `
	test-custom-test-provider, `
	test-auto-detects-xunit-contrib, `
	test-sample-extension, `
	test-UI, `
	test-statlight-no-communication-from-browser-forced-timeout, `
	test-multiple, `
	test-single-assemblies {
}


Task build-all -depends `
	clean-build, `
	initialize, `
	create-AssemblyInfo, `
	compile-Solution, `
	compile-StatLight-MSTestHostVersions, `
	compile-StatLight-UnitDrivenHost, `
	compile-StatLight-XUnitContribHost, `
	compile-StatLight-MSTestHostVersionIntegrationTests {
}

Task build-all-phone -depends `
	clean-build, `
	initialize, `
	create-AssemblyInfo, `
	compile-Solution-Phone, `
    compile-StatLight-MSTest-Phone, `
    compile-StatLight-XUnitContribHost-Phone, `
	compile-StatLight-MSTestHostVersions, `
	compile-StatLight-UnitDrivenHost, `
	compile-StatLight-XUnitContribHost, `
	compile-StatLight-MSTestHostVersionIntegrationTests {
}
