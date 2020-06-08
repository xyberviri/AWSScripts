
function Get-AWSVolumeReport
{
Param ([string]$region, [string]$profile)

$volsnaps=(Get-EC2Volume -Region $region -ProfileName $profile) 

#$serverList = import-csv "datafile.csv"
$AllObjects = @()

$volsnaps | ForEach-Object {
    $AllObjects += [pscustomobject]@{
        InstanceId = $_.Attachments.InstanceId
        SnapshotId = $_.SnapshotId
        VolumeId = $_.Attachments.VolumeId
        Device = $_.Attachments.Device
        Size = $_.Size
        State = $_.State
        Encrypted = $_.Encrypted
        Created = $_.CreateTime

    }
}

$AllObjects | Export-Csv -Path "$region.csv" -NoTypeInformation
}

Get-AWSVolumeReport -region "us-east-1" -profile "default"
