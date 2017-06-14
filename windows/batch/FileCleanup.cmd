REM FTP clean up

SET PURGEPATH=C:\Users\%username%\Downloads
SET PURGEDEST=C:\Users\%username%\olddownloads
SET PURGE_AGE=35
SET DELET_AGE=70

SET PURGESTOR=storage
SET PURGELOG=purgejob.log
SET DELFEMPT=Y

REM Robocopy files/folders older than PURGE_AGE
robocopy "%PURGEPATH%" "%PURGEDEST%\%PURGESTOR%" *.* /move /copyall /s /MAXAGE:%PURGE_AGE% /LOG:"%PURGEDEST%\%PURGELOG%"

REM Delete files older than X
forfiles -p "%PURGEDEST%\%PURGESTOR%" -s -m *.* /D -%DELET_AGE% /C "cmd /c del @path"

REM Delete empty folders, RD does not delete empty folders when used with out flags. 
for /f "usebackq delims=" %%d in (`"dir "%PURGEDEST%\%PURGESTOR%" /ad/b/s | sort /R"`) do rd "%%d"
