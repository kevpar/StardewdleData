Set-StrictMode -Version Latest

enum Season {
	Spring
	Summer
	Fall
	Winter
}

enum CropType {
	Vegetable
	Fruit
	Forage
	Flower
}

class Crop {
	[string]$Name
	[CropType]$Type
	[uint]$Price
	[uint]$Growth
	[bool]$Regrow
	[Season[]]$Season
}

function FormatCrop($crop) {
	"{0}(Type={1}, Price={2}, Growth={3}, Regrow={4}, Season={5})" -f
		$crop.Name, $crop.Type, $crop.Price, $crop.Growth, $crop.Regrow, $crop.Season
}

class Rel {
	[string]$Name
	[scriptblock]$Script
}

function CompareCrop($guess, $crop, $rels) {
	Write-Debug "Comparing $(FormatCrop $crop)"

	if (!(& $rels.Type.Script $guess.Type $crop.Type)) {
		Write-Debug "Type comparison failed"
		return $false
	}
	if (!(& $rels.Price.Script $guess.Price $crop.Price)) {
		Write-Debug "Price comparison failed"
		return $false
	}
	if (!(& $rels.Growth.Script $guess.Growth $crop.Growth)) {
		Write-Debug "Growth comparison failed"
		return $false
	}
	if (!(& $rels.Regrow.Script $guess.Regrow $crop.Regrow)) {
		Write-Debug "Regrow comparison failed"
		return $false
	}
	if (!(& $rels.Season.Script $guess.Season $crop.Season)) {
		Write-Debug "Type comparison failed"
		return $false
	}
	Write-Debug "Comparison succeeded!"
	return $true
}

$relEq = [Rel]@{Name = 'Eq'; Script = {$args[0] -eq $args[1]}}
$relNe = [Rel]@{Name = 'Ne'; Script = {$args[0] -ne $args[1]}}
$relLt = [Rel]@{Name = 'Lt'; Script = {$args[0] -lt $args[1]}}
$relGt = [Rel]@{Name = 'Gt'; Script = {$args[0] -gt $args[1]}}
$relOv = [Rel]@{Name = 'Ov'; Script = {Overlap $args[0] $args[1]}}

function CompEquality($guess, $answer) {
	if ($guess -eq $answer) {
		$relEq
	} else {
		$relNe
	}
}

function CompNum($guess, $answer) {
	if ($guess -lt $answer) {
		Write-Verbose "$guess -lt $answer"
		$relLt
	} elseif ($guess -gt $answer) {
		$relGt
	} else {
		$relEq
	}
}

function Overlap($guess, $answer) {
	[system.linq.enumerable]::Intersect($guess, $answer)
}

function CompSeason($guess, $answer) {
	if ($guess -eq $answer) {
		$relEq
	} elseif (Overlap -guess $guess -answer $answer) {
		return $relOv
	} else {
		return $relNe
	}
}

function GetRelations($guess, $answer) {
	[pscustomobject]@{
		Type = CompEquality $guess.Type $answer.Type
		Price = CompNum $guess.Price $answer.Price
		Growth = CompNum $guess.Growth $answer.Growth
		Regrow = CompEquality $guess.Regrow $answer.Regrow
		Season = CompSeason $guess.Season $answer.Season
	}
}

function GetRemaining($guess, $answer, $pool) {
	Write-Verbose "Guess: $(FormatCrop $guess)"
	Write-Verbose "Answer: $(FormatCrop $answer)"
	$rels = GetRelations -guess $guess -answer $answer
	Write-Verbose "Relations: Type=$($rels.Type.Name), Price=$($rels.Price.Name), Growth=$($rels.Growth.Name), Regrow=$($rels.Regrow.Name), Season=$($rels.Season.Name)"
	foreach ($crop in $pool) {
		if (CompareCrop -guess $guess -crop $crop -rels $rels) {
			$crop
		}
	}
}

function Limit-Crop {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline)][Crop[]]$CropPool,
		[Parameter(Mandatory, Position = 0)][Crop]$Answer,
		[Parameter(Mandatory, Position = 1)][Crop]$Guess
	)

	begin {
		$relations = GetRelations -answer $Answer -guess $Guess
	}

	process {
		if (CompareCrop -guess $Guess -crop $CropPool -rels $relations) {
			$CropPool
		}
	}
}

function Get-Crop {
	[CmdletBinding()]
	param(
		[Parameter(ParameterSetName = 'ByName', Mandatory, Position = 0)][string]$Name,
		[Parameter(ParameterSetName = 'All')][switch]$All
	)

	switch ($PSCmdlet.ParameterSetName) {
		'All' { $AllCrops.Values }
		'ByName' { $AllCrops[$Name] }
	}
}

$AllCrops = @{}
Import-Csv "$PSScriptRoot/Stardewdle.csv" | Foreach-Object {
	$crop = [Crop]@{
		Name = $_.Crop
		Type = $_.Type
		Price = $_.Price
		Growth = $_.Growth
		Regrow = $_.Regrow -eq 'Yes'
		Season = $_.Season
	}
	$AllCrops[$crop.Name] = $crop
}

function GuessStats {
	[CmdletBinding()]
	param()

	$guessStats = @{}
	foreach ($guess in $AllCrops) {
		foreach ($answer in $AllCrops) {
			$options = GetRemaining -guess $guess -answer $answer -pool $AllCrops
			for ($i = 0; $i -lt $options.Count; $i++) {
				Write-Verbose "Option #${i}: $(FormatCrop $options[$i])"
			}
			if (!$guessStats.ContainsKey($guess.Name)) {
				$guessStats[$guess.Name] = @()
			}
			$guessStats[$guess.Name] += $options.Count
		}
	}

	foreach ($kvp in $guessStats.GetEnumerator()) {
		[pscustomobject]@{
			Crop = $kvp.Name
			Average = ($kvp.Value | Measure-Object -Average).Average
			Median = ($kvp.Value | Sort-Object)[$kvp.Value.Length / 2]
			StdDev = ($kvp.Value | Measure-Object -StandardDeviation).StandardDeviation
			Maximum = ($kvp.Value | Measure-Object -Maximum).Maximum
		}
	}
}