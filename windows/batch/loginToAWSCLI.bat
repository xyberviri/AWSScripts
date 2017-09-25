@ECHO OFF
REM Requires JQ, Sed, Grep

:awsPromptForCredentials
IF [%1] == [] (
ECHO Enter a profile to authenticate against.
ECHO The following profiles are setup to work with this utility.
grep "\-auth]$" %userprofile%/.aws/config|sed "s/\[profile\s//g;s/-auth]//g"
	SET /p var_loginProfile=:
) ELSE (
	SET var_loginProfile=%1
)
IF [%var_loginProfile%] == [] ( GOTO awsPromptForCredentials )

:awsPromptForMFASerial
ECHO Enter the serial number for your MFA device.
	SET /p var_PromptForMFASerial=:
IF [%var_PromptForMFASerial%] == [] ( GOTO awsPromptForMFASerial )

:awsPromptForMFAOTP
ECHO Enter the one time pass from your MFA device.
	SET /p var_PromptForMFAOTP=:
IF [%var_PromptForMFAOTP%] == [] ( GOTO awsPromptForMFAOTP )

:awsAttemptAuthentication
aws sts get-session-token --profile="%var_loginProfile%-auth" --serial-number "%var_PromptForMFASerial%" --token-code %var_PromptForMFAOTP% >%temp%\%var_loginProfile%.session
IF %ERRORLEVEL% NEQ 0 (
	ECHO ERROR %ERRORLEVEL%
	ECHO Try again [Y/N]?
	set /p var_PromptTryAgain=:
	if /i ["%var_PromptTryAgain%"] == ["y"] ( GOTO awsPromptForCredentials )
	GOTO EoF
)
	PUSHD %temp%
	TYPE %var_loginProfile%.session
		FOR /F "tokens=* USEBACKQ" %%F IN (`jq -r ".Credentials.AccessKeyId" %var_loginProfile%.session`) DO (
			aws configure --profile %var_loginProfile% set aws_access_key_id %%F
		)
		FOR /F "tokens=* USEBACKQ" %%F IN (`jq -r ".Credentials.SecretAccessKey" %var_loginProfile%.session`) DO (
			aws configure --profile %var_loginProfile% set aws_secret_access_key %%F
		)
		FOR /F "tokens=* USEBACKQ" %%F IN (`jq -r ".Credentials.SessionToken" %var_loginProfile%.session`) DO (
			aws configure --profile %var_loginProfile% set aws_session_token %%F
		)
		DEL /Q /F %var_loginProfile%.session
	POPD
ECHO. Success, you are now authenticated until your session token expires.

:Eof
PAUSE
EXIT /B %ERRORLEVEL%
EXIT /B %ERRORLEVEL%
