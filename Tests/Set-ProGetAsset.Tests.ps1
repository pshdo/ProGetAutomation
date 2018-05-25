
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)


function Init
{
    $script:fileName = $null
    $script:progetAssetName = $null
    $script:baseDirectory = (Split-Path -Path $TestDrive.FullName -Leaf)
    $script:directory = $null
    $script:filePath = $null
    $script:valueContent = $null
}

function GivenSession 
{
    $script:session = New-ProGetTestSession
    $feed = Test-ProGetFeed -Session $session -FeedName $baseDirectory -FeedType 'Asset'
    if( !$feed )
    {
        New-ProGetFeed -Session $session -FeedName $baseDirectory -FeedType 'Asset'
    }
}

function GivenAssetName
{
    param(
        [string]
        $Name
    )

    $script:proGetAssetName = $Name
}

function GivenAssetDirectory
{
    param(
        [string]
        $RootDirectory        
    )

    $script:baseDirectory = $RootDirectory
}

function GivenSourceFilePath
{
    param(
        [string]
        $Path,
        [switch]
        $WhereFileDoesNotExist
    )

    $script:filePath = Join-Path -Path $TestDrive.FullName -ChildPath $Path

    if( !$WhereFileDoesNotExist )
    {
        New-Item -Path $filePath -ItemType 'File' -Force
    }
}

function GivenSourceValue
{
    param(
        [string]
        $Value
    )

    $script:valueContent = $Value
}

function WhenAssetIsPublished
{
    $Global:Error.Clear()

    $params = @{ }
    if( $filePath )
    {
        $params['FilePath'] = $filePath
    }
    else
    {
        $params['Value'] = $valueContent
    }

    Set-ProGetAsset -Session $session -Path $proGetAssetName -DirectoryName $baseDirectory @params -ErrorAction SilentlyContinue
}

function ThenAssetShouldExist
{
    param(
        [string]
        $Name,
        [string]
        $Directory
    )
    it ('should contain the asset ''{0}''' -f $Name) {
        Get-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $Directory | Where-Object { $_.name -match $name } | Should -Not -BeNullOrEmpty
    }
}

function ThenAssetShouldNotExist
{
    param(
        [string]
        $Name,
        [string]
        $Directory
    )
    it ('should not contain the asset ''{0}''' -f $Name) {
        Get-ProGetAsset -Session $session -DirectoryName $baseDirectory -Path $Directory | Where-Object { $_.name -match $name } | Should -BeNullOrEmpty
    }
}

function ThenAssetContentsShouldMatch
{
    param(
        $Value
    )

    $assetContents = Invoke-ProGetRestMethod -Session $session -Path ('/endpoints/{0}/content/{1}' -f $baseDirectory, $progetAssetName) -Method Get

    It 'should post the correct content to the ProGet asset' {
        $assetContents.Test | Should Be $Value.Test
        $assetContents.Test2 | Should Be $Value.Test2
    }
}

function ThenErrorShouldBeThrown
{
    param(
        [string]
        $ExpectedError
    )
    It ('should write an error that matches ''{0}''' -f $ExpectedError) {
        $Global:Error | Where-Object { $_ -match $ExpectedError } | Should -Not -BeNullOrEmpty
    }
}

function ThenNoErrorShouldBeThrown
{
    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Set-ProGetAsset.when file asset is uploaded' {
    Init
    GivenSession
    GivenAssetName 'foo.txt'
    GivenSourceFilePath 'foo.txt'
    WhenAssetIsPublished
    ThenAssetShouldExist -Name 'foo.txt' -Directory ''
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when file asset is uploaded in subfolder' {
    Init
    GivenSession
    GivenAssetName 'subdir/foo.txt' 
    GivenSourceFilePath 'foo.txt'
    WhenAssetIsPublished
    ThenAssetShouldExist -Name 'foo.txt' -Directory 'subdir'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when file asset is uploaded in subfolder with backslashes' {
    Init
    GivenSession
    GivenAssetName '\subdir\foo.txt' 
    GivenSourceFilePath 'foo.txt'
    WhenAssetIsPublished
    ThenAssetShouldExist -Name 'foo.txt' -Directory 'subdir'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when target asset directory does not exist' {
    Init
    GivenSession
    GivenAssetName 'foo.txt' 
    GivenAssetDirectory 'badDir'
    GivenSourceFilePath 'foo.txt'
    WhenAssetIsPublished
    ThenAssetShouldNotExist -Name 'foo.txt' -Directory 'badDir'
    ThenErrorShouldBeThrown -ExpectedError 'The remote server returned an error: \(404\) Not Found\.'
}

Describe 'Set-ProGetAsset.when source file exists in a subdirectory of local working directory' {
    Init
    GivenSession
    GivenAssetName 'foo.txt'
    GivenSourceFilePath 'dir/foo.txt'
    WhenAssetIsPublished
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when source file does not exist' {
    Init
    GivenSession
    GivenAssetName 'fubu.txt'
    GivenSourceFilePath 'fubu.txt' -WhereFileDoesNotExist
    WhenAssetIsPublished
    ThenAssetShouldNotExist -Name 'fubu.txt' -Directory ''
    ThenErrorShouldBeThrown -ExpectedError 'Could not find file named'
}

Describe 'Set-ProGetAsset.when file asset already exists' {
    Init
    GivenSession
    GivenAssetName 'foo.txt'
    GivenSourceFilePath 'foo.txt'
    WhenAssetIsPublished
    WhenAssetIsPublished
    ThenAssetShouldExist -Name 'foo.txt'
    ThenNoErrorShouldBeThrown
}

Describe 'Set-ProGetAsset.when body content is provided instead of a file' {
    Init
    GivenSession
    GivenAssetName 'foo.txt'
    GivenSourceValue (@{ Test = 'Test'; Test2 = 'Test2' } | ConvertTo-Json | Out-String)
    WhenAssetIsPublished
    ThenAssetShouldExist -Name 'foo.txt' -Directory ''
    ThenAssetContentsShouldMatch @{ Test = 'Test'; Test2 = 'Test2' }
    ThenNoErrorShouldBeThrown
}
