<#  
    Generate
        -ec2volume-report.csv - Volumes with attachment status
        -images.csv           - AMI information    
    Tag 
        -orphaned snapshots with "Orphaned:True"
    Usage
        Get-AWSVolumeReport -region $awsRegion -awsprofile $awsProfile
        
       List aws regions with Get-AWSRegion
       List aws local profile names with Get-AWSCredential -ListProfileDetail
       
   Permissions 
   
       You need to at least be able to describe images, volumes,snapshots
       
            ec2:DescribeInstances
            ec2:DescribeImages
            ec2:DescribeVolumes
            
            OR
            
            ec2:Describe*
            
       For tagging you need
              ec2:CreateTag    
              
   Tips are appreciated paypal.me/xyberviri
    #>
function Get-AWSVolumeReport
{
    Param ([string]$region, [string]$awsProfile)
    write-host "Checking" $region "Using profile:" $awsProfile

    $volsnaps=(Get-EC2Volume -Region $region -ProfileName $awsProfile) 
    $images = Get-EC2Image -Region $region -ProfileName $awsProfile -Owner (Get-STSCallerIdentity -Region $region -ProfileName $awsProfile).account
    $snapshots = Get-EC2Snapshot -Region $region -ProfileName $awsProfile
    $snapshotsWithImages = $snapshots  |? {$images.BlockDeviceMappings.Ebs.SnapshotId -contains $_.SnapshotId}# -or $volsnaps.VolumeId -contains $_.VolumeId}
    $snapshotsWithoutImages = $snapshots  |? {$images.BlockDeviceMappings.Ebs.SnapshotId -notcontains $_.SnapshotId -and $volsnaps.VolumeId -notcontains $_.VolumeId}
    $tag = [Amazon.EC2.Model.Tag]::new("Orphaned","True")

    $AllObjects = @()
    foreach($volume in $volsnaps) {

        $AllObjects += [pscustomobject]@{
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
    }

    $AllObjects | Export-Csv -Path "$region-ec2volume-report.csv" -NoTypeInformation
    $snapshotsWithImages |Select-Object -Property SnapshotId,Description,StartTime,VolumeId,VolumeSize,Encrypted | export-csv -Path "$region-ec2snapshot-report.csv" -NoTypeInformation

    $AllObjects = @()
    foreach ($image in $images)
    {
         $totalsize=0
         foreach($volumesize in $image.BlockDeviceMappings.Ebs.VolumeSize)
            {
                $totalsize+=$volumesize
            }
         $AllObjects += [pscustomobject]@{
         AmiId = $image.ImageId
         CreationDate = $image.CreationDate
         Platform = $image.Platform
         PlatformDetails = $image.PlatformDetails
         Public = $image.Public
         State = $image.State
         EbsVolumes = $image.BlockDeviceMappings.Ebs.VolumeSize.count
         EbsVolumesSize = $totalsize
         Name = $image.Name
         Description = $image.Description
         }

    }
    $AllObjects | Export-Csv -Path "$region-ec2Image-report.csv" -NoTypeInformation

    foreach($orphan in ($snapshotsWithoutImages | ? {$_.Tag.Key -notcontains "Orphaned" -or ($_.Tag.Key -contains "Orphaned" -and $_.Tag.Value -ne "True")})){
        write-host "Tagging" $region $orphan.SnapshotId
        New-EC2Tag -Resource $orphan.SnapshotId -Tag $tag  -Region $region -ProfileName $awsProfile -ErrorAction SilentlyContinue
    }

    write-host $volsnaps.count "volumes"
    write-host $snapshotsWithImages.count "snapshots backing amis or from existing volumes"
    write-host ($snapshotsWithoutImages | ? {$_.Tag.Key -notcontains "Orphaned" -or ($_.Tag.Key -contains "Orphaned" -and $_.Tag.Value -ne "True")}).count "orphaned snapshots"
    write-host "done with" $region "`r`n"
}
