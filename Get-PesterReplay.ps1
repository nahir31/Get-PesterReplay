function Get-PesterReplay
{
    <#
    .SYNOPSIS
       	Replay Pester tests results from XML

    .DESCRIPTION
       	Read Pester tests results result file, given it is in NUnitXml format, and replay the original colorful text result.
       	The result file might be with or without Pester 'Context'. 
		In addition to the standrd Pester output, the summary will include the date & time when the original test was performed.

    .EXAMPLE
       	Get-PesterReplay 'C:\PesterResults\result.xml'       

    .EXAMPLE
       	Get-PesterReplay -FullName 'C:\PesterResults\result.xml'

    .EXAMPLE
       	Get-PesterReplay -Path 'C:\PesterResults\result.xml'

    .EXAMPLE
       	'C:\PesterResults\result.xml' | Get-PesterReplay

    .EXAMPLE
       	Get-Item -Path 'C:\PesterResults\result.xml' | Get-PesterReplay

    .INPUTS
       	Pester result file in NUnitXml format

    .OUTPUTS
       	The only output is text to host, aka. Standard Output or StdOut

    .NOTES
   ===========================================
    Created on:    22 Apr 2020 22:00
    Created by:    Tsvika Nahir, ISRAEL
    Version:       1.0.0 Initial version  
   ===========================================
    #>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true)]
		[Alias('Path')]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$FullName
	)
	
	function Get-TimeDisplay
	{
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory = $true)]
			[double]$Seconds,
			[Parameter()]
			[switch]$FullSecondsDisplay
		)
		
		$secondsText = 's'
		$secRound = [Math]::Round($Seconds, 2)
		
		if ($FullSecondsDisplay.IsPresent)
		{
			$secondsText = ' second'
			
			if ($secRound -gt 1)
			{
				$secondsText = ' seconds'
			} # end if
		} # end if
		
		switch ($Seconds)
		{
			{ $_ -lt 1 } { $timeInfo = "$((1000 * $Seconds) -as [int])ms" }
			default { $timeInfo = "$secRound$secondsText" }
		} # end switch
		
		$timeInfo
	} # endfunction Get-TimeDisplay
	
	function Show-TestCase
	{
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
			[System.Xml.XmlLinkedNode[]]$Case
		)
		
		begin { }
		
		process
		{
			foreach ($c in $Case)
			{
				$myErr = ''
				
				switch ($c.result)
				{
					'Success'
					{
						$totalPassed++
						$mark = '[+]'
						$resColor = 'Green'
						break
					}
					
					'Failure'
					{
						$totalFailed++
						$mark = '[-]'
						$resColor = 'Red'
						$myErr = $c.failure.message
						break
					}
					
					'Ignored'
					{
						$totalSkipped++
						$mark = '[!]'
						$resColor = 'Yellow'
						break
					}
					
					default
					{
						$totalInconclusive++
						$mark = '[?]'
						$resColor = 'Cyan'
						break
					}
				} # end switch
				
				$duration = Get-TimeDisplay -Seconds $c.time
				Write-Host "    $mark $($c.description) " -NoNewline -ForegroundColor $resColor
				Write-Host $duration -ForegroundColor Gray
				
				if ($myErr -ne '')
				{
					$myErrors = @()
					$myErrors += $myErr -split "`n"
					
					$myErrors | ForEach-Object {
						Write-Host "    $_" -ForegroundColor $resColor
					} # end ForEach-Object
				} # end if
			} # end foreach ($c in $Case)
		} # end process
		
		end { Write-Host '' }
	}
	
	function Show-SuiteResult
	{
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
			[System.Xml.XmlLinkedNode[]]$Suite,
			[Parameter()]
			[switch]$IsContext
		)
		
		begin { }
		
		process
		{
			foreach ($s in $Suite)
			{
				$header = 'Context'
				
				if ($IsContext.IsPresent)
				{
					$header = '  Describing'
				} # end if
				
				Write-Host "$header $($s.name)" -ForegroundColor Green
				
				$hasInnerSuite = $s.results | Get-Member | Where-Object { $_.Name -eq 'test-suite' }
				
				if ($hasInnerSuite)
				{
					Write-Host ''
					$contextSuites = $s.results.'test-suite'
					Show-SuiteResult -Suite $contextSuites -IsContext
				} # end if
				else
				{
					$s.results.'test-case' | Show-TestCase
				} # end else
			} # end foreach ($s in $Suite)
		} # end process
		
		end { Write-Host '' }
	} # end function Show-SuiteResult
	
	$formatErr = "$FullName is not a valid Pester result file (expected format: NUnitXML)"
	
	[xml]$xml = Get-Content -Path $FullName
	
	$hasTestResults = $xml | Get-Member | Where-Object { $_.Name -eq 'test-results' }
	
	if ($hasTestResults -eq $null)
	{
		throw $formatErr
	} # end if
	
	$root = $xml.'test-results'
	
	$hasTestsuite = $root | Get-Member | Where-Object { $_.Name -eq 'test-suite' }
	
	if ($hasTestsuite -eq $null)
	{
		throw $formatErr
	} # end if
	
	$top = $root.'test-suite'.results.'test-suite'
	
	if ($top -eq $null)
	{
		throw $formatErr
	} # end if
	
	[int]$totalPassed = 0
	[int]$totalFailed = 0
	[int]$totalSkipped = 0
	[int]$totalPending = 0
	[int]$totalInconclusive = 0
	
	$title = "Executing script $($top.name) (REPLAY)`n"
	
	Write-Host $title -ForegroundColor Cyan
	
	$suites = $top.results.'test-suite'
	
	Show-SuiteResult -Suite $suites
	
	$totalTimeSec = $top.time
	
	$testDateInfo = "Test Original Time: $($root.date) $($root.time)"
	
	$timeSummary = "`nTests completed in $(Get-TimeDisplay -Seconds $top.time -FullSecondsDisplay)"
	
	$testSumHeader = "`nTests Summary: "
	$passSum = "Passed: $totalPassed, "
	$failSum = "Failed: $totalFailed, "
	$skipSum = "Skipped: $totalSkipped, "
	$miscSum = "Pending: $totalPending, Inconclusive: $totalInconclusive"
	$divider = '-' * 80
	
	Write-Host $testDateInfo -ForegroundColor Cyan
	Write-Host $testSumHeader -NoNewline -ForegroundColor Cyan
	Write-Host $passSum -NoNewline -ForegroundColor Green
	Write-Host $failSum -NoNewline -ForegroundColor Red
	Write-Host $skipSum -NoNewline -ForegroundColor Yellow
	Write-Host $miscSum -ForegroundColor Gray
	Write-Host $timeSummary -ForegroundColor Cyan
	Write-Host $divider
} # end function
