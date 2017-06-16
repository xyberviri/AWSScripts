@ECHO OFF
SET var_PromptForProfile=%1
IF [%1] == [] SET var_PromptForProfile=default
aws ec2 describe-vpcs --profile "%var_PromptForProfile%" --output text --query "Vpcs[*].{VpcId:VpcId}
