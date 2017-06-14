REM 14 lines in VBS what we can do in 1 line using good ol dos
forfiles -p "C:\inetpub\logs\LogFiles" -s -m *.* /D -35 /C "cmd /c del /Q /F @path"
