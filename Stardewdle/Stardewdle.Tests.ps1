BeforeAll {
    Import-Module -Force $PSScriptRoot/Stardewdle.psm1
}

Describe 'Get-Crop' {
    It 'Returns the right number of crops' {
        (Get-Crop).Count | Should-Be 72
    }

    It 'Can find a certain crop' {
        Get-Crop -Name 'Wheat'
    }
}

Describe 'Limit-Crop' {
    It 'Basic cases' -ForEach @(
        @{ Answer = 'Parsnip'; Guess = 'Spice Berry'; Results = @('Parsnip', 'Tulip', 'Garlic', 'Carrot') }
        @{ Answer = 'Wheat'; Guess = 'Parsnip'; Results = @('Wheat') }
    ) {
        $params = @{
            Answer = Get-Crop -Name $Answer
            Guess = Get-Crop -Name $Guess
        }
        Get-Crop |
            Limit-Crop @params |
            ForEach-Object Name |
            Should-BeCollection $Results
    }
}