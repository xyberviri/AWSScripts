cmd /c dir /s /b c:\folder |? {$_.length -gt 215}|Out-File c:\longnames.txt
