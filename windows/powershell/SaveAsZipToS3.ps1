param(
   [string] $region = $(throw "-region is required."),
   [string] $path = $(throw "-path is required."),
   [string] $destination = $(throw "-destination is required."),
   [string] $bucket = $(throw "-bucket is required."),
   [string] $filename = $(throw "-filename is required.")
)

write-host $path $destination $filename $bucket
If(Test-path $destination) {Remove-item $destination}
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($path, $destination) 
Write-S3Object -Region $region -BucketName $bucket -Key $filename -File $destination
