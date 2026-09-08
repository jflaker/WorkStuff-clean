# Function to copy files from a UNC path to a local folder
function Copy-FilesFromUNC {
    param(
        [string]$uncPath,
        [string]$localPath,
        [string[]]$imageExtensions
    )

    # Create the local directory if it doesn't exist
    if (!(Test-Path -Path $localPath)) {
        New-Item -Path $localPath -ItemType Directory | Out-Null
    }

    # Copy the files - Filter by extension during copy
    foreach ($extension in $imageExtensions) {
        Get-ChildItem -Path $uncPath -Filter "*$extension" -Recurse | Copy-Item -Destination $localPath -Force
        Write-Host "Copied files with extension $extension from '$uncPath' to '$localPath'."
    }
    Write-Host "Files copied from '$uncPath' to '$localPath'."
}

# Function to create a JSON list of image files in a folder and write it to a file
# This file is what powers the web browser based slide show
function Get-ImageFileListJSON {
    param(
        [string]$folderPath,
        [string[]]$imageExtensions
    )

    $jsonFilePath = Join-Path -Path $folderPath -ChildPath "image_list.json"

    try {
        $imageFilesHash = @{}
        foreach ($extension in $imageExtensions) {
            Write-Host "Searching for files with extension $extension in '$folderPath'."
            Get-ChildItem -Path $folderPath -Filter "*$extension" | ForEach-Object {
                if (!$imageFilesHash.ContainsKey($_.Name)) {
                    $imageFilesHash[$_.Name] = [PSCustomObject]@{
                        Name = $_.Name
                    }
                }
            }
        }

        $imageFiles = $imageFilesHash.Values
        if ($imageFiles.Count -gt 0) {
            $jsonOutput = $imageFiles | ConvertTo-Json -Depth 2
            $jsonOutput | Out-File -FilePath $jsonFilePath -Encoding UTF8
            Write-Host "JSON image list written to '$jsonFilePath'."
        } else {
            Write-Host "No image files found in '$folderPath' matching the specified extensions."
            # Create an empty JSON array:
            @{} | ConvertTo-Json | Out-File -FilePath $jsonFilePath -Encoding UTF8
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}
# Function to delete files of image type from rooth folder
# This is for maintenance of the main folder
function Delete-ImageFiles {
    param(
        [string]$folderPath,
        [string[]]$imageExtensions
    )

    # Get all files in the folder with the specified extensions
    $filesToDelete = @()
    foreach ($extension in $imageExtensions) {
        $filesToDelete += Get-ChildItem -Path $folderPath -Filter "*$extension"
    }

    # Delete the files
    if ($filesToDelete.Count -gt 0) {
        $filesToDelete | Remove-Item -Force
        Write-Host "Image files deleted successfully from '$folderPath'."
    } else {
        Write-Host "No image files found in '$folderPath'."
    }
}

Clear-Host
# Clean the main folder
# copy images to the main folder
# refill the image_list.json file for the slide show

# This is where the images are from
# Point this at a purpose-made file share, NOT an admin share (C$).
$uncPath = $env:SLIDESHOW_SOURCE
if (-not $uncPath) { $uncPath = "\\FILESERVER01\Slideshow\images" }
# This is where we are copying the images to for use in the slide show
$localPath = $PSScriptRoot  # resolves to wherever this script lives
# The file types I am looking for
$imageExtensions = @(
    ".jpg", ".jpeg", ".png", ".gif", ".tiff", ".tif", ".bmp", ".webp",
    ".svg", ".ai", ".psd", ".raw", ".heic", ".eps", ".ico", ".cr2", ".nef",
    ".orf", ".sr2", ".dng"
)

# Delete image files from the local folder (uncomment if needed)
Delete-ImageFiles -folderPath $localPath -imageExtensions $imageExtensions

# Copy files from UNC path to local folder
Copy-FilesFromUNC -uncPath $uncPath -localPath $localPath -imageExtensions $imageExtensions

# Create a JSON list of image files in the local folder and write to file
# The JSON file will now be in the local folder
Get-ImageFileListJSON -folderPath $localPath -imageExtensions $imageExtensions

# Example of how to access the JSON file path later:
# $jsonFilePath = Join-Path -Path $localPath -ChildPath "image_list.json"
# Write-Host "JSON File Path: $jsonFilePath"  # Debug: Check the JSON file path

