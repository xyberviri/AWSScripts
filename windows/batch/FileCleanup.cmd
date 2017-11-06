REM The purpose of this script is to move files older then %PURGE_AGE% from %PURGEPATH% to %PURGEDEST%\%PURGESTOR%
REM and then delete files older then %DELET_AGE% from %PURGEDEST%\%PURGESTOR%
REM a record of what was moved is kept in %PURGEDEST%\%PURGELOG%-%datetime%.log

SET PURGEPATH=C:\Users\%username%\Downloads
SET PURGEDEST=C:\Users\%username%\olddownloads
SET PURGE_AGE=35
SET DELET_AGE=70

SET PURGESTOR=storage
SET PURGELOG=purgejob
SET DELFEMPT=Y

FOR /f "tokens=1-8 delims=:./ " %%G IN ("%date%_%time%") DO (
SET datetime=%%G%%H%%I_%%J_%%K
)

set PURGELOG=%PURGELOG%-%datetime%.log

REM Robocopy files/folders older than PURGE_AGE
robocopy "%PURGEPATH%" "%PURGEDEST%\%PURGESTOR%" *.* /move /copyall /s /MAXAGE:%PURGE_AGE% /LOG:"%PURGEDEST%\%PURGELOG%"

REM Delete files older than X
forfiles -p "%PURGEDEST%\%PURGESTOR%" -s -m *.* /D -%DELET_AGE% /C "cmd /c del @path"

REM Delete empty folders, RD does not delete empty folders when used with out flags. 
for /f "usebackq delims=" %%d in (`"dir "%PURGEDEST%\%PURGESTOR%" /ad/b/s | sort /R"`) do rd "%%d"
