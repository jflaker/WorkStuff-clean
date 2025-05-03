# Define the source folder (Home folder) and destination folders
$HomeFolder = [environment]::GetFolderPath('UserProfile')
$PicturesFolder = Join-Path $HomeFolder "Pictures"
$VideosFolder = Join-Path $HomeFolder "Videos"
$DocumentsFolder = Join-Path $HomeFolder "Documents"
$MusicFolder = Join-Path $HomeFolder "Music"
$DesktopFolder = Join-Path $HomeFolder "Desktop"

# Create an extension map to categorize file types
$FileTypeMap = @{
    Pictures = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.webp', '.svg');
    Videos = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm');
    Documents = @('.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.pdf', '.txt', '.rtf', '.odt', '.ods');
    Music = @('.mp3', '.wav', '.flac', '.aac', '.wma', '.ogg');
}

# Function to ensure a folder exists
function Ensure-FolderExists {
    param(
        [string]$FolderPath
    )
    if (-not (Test-Path $FolderPath)) {
        New-Item -ItemType Directory -Path $FolderPath | Out-Null
    }
}

# Ensure all destination folders exist
$DestinationFolders = @($PicturesFolder, $VideosFolder, $DocumentsFolder, $MusicFolder, $DesktopFolder)
foreach ($Folder in $DestinationFolders) {
    Ensure-FolderExists -FolderPath $Folder
}

# Function to move files based on type
function Move-FileByType {
    param(
        [string]$SourceFolder,
        [System.Collections.Hashtable]$FileTypeMap
    )
    Get-ChildItem -Path $SourceFolder -Recurse -File | ForEach-Object {
        $FileExtension = $_.Extension.ToLower()
        foreach ($Category in $FileTypeMap.Keys) {
            if ($FileTypeMap[$Category] -contains $FileExtension) {
                $DestinationFolder = Get-Variable -Name "${Category}Folder" -ValueOnly
                Move-Item -Path $_.FullName -Destination $DestinationFolder -Force -ErrorAction SilentlyContinue
                break
            }
        }
    }
}

# Call the function to sort files in the Home folder
Move-FileByType -SourceFolder $HomeFolder -FileTypeMap $FileTypeMap

Write-Host "Files have been organized into their respective folders."