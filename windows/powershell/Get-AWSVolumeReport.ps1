function Get-AWSVolumeReport
{
Param ([string]$region, [string]$awsProfile)
write-host "Checking" $region

$volsnaps=(Get-EC2Volume -Region $region -ProfileName $awsProfile) 
$images = Get-EC2Image -Region $region -ProfileName $awsProfile -Owner @(get-ec2securitygroup -Region $region -ProfileName $awsProfile -GroupNames "default")[0].OwnerId
$snapshots = Get-EC2Snapshot -Region $region -ProfileName $awsProfile
$snapshotsWithImages = $snapshots  |? {$images.BlockDeviceMappings.Ebs.SnapshotId -contains $_.SnapshotId}
$snapshotsWithoutImages = $snapshots  |? {$images.BlockDeviceMappings.Ebs.SnapshotId -notcontains $_.SnapshotId}
$tag = [Amazon.EC2.Model.Tag]::new("Orphaned","True")

$AllObjects = @()
$count=0
foreach($volume in $volsnaps) {

    $AllObjects += [pscustomobject]@{
        #Count = $count
        ImageId = ( $images | Where-Object {$_.BlockDeviceMappings.Ebs.SnapshotId -eq $volume.SnapshotId} ).ImageId
        InstanceId = $volume.Attachments.InstanceId
        SnapshotId = $volume.SnapshotId
        VolumeId = $volume.VolumeId
        Device = $volume.Attachments.Device
        Size = $volume.Size
        State = $volume.State
        Encrypted = $volume.Encrypted
        Created = $volume.CreateTime

    }
    $count++
}

$AllObjects | Export-Csv -Path "$region-ec2volume-report.csv" -NoTypeInformation
$snapshotsWithImages |Select-Object -Property SnapshotId,Description,StartTime,VolumeId,VolumeSize,Encrypted | export-csv -Path "$region-images.csv" -NoTypeInformation

foreach($orphan in ($snapshotsWithoutImages | ? {$_.Tag.Key -notcontains "Orphaned"})){
write-host "Tagging" $region $orphan.SnapshotId
New-EC2Tag -Resource $orphan.SnapshotId -Tag $tag  -Region $region -ProfileName $awsProfile -ErrorAction SilentlyContinue
}

}

Get-AWSVolumeReport -region "us-east-1" -profile "default"
