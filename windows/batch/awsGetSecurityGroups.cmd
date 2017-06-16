@ECHO OFF
aws ec2 describe-instances --profile "%1" --filters "Name=vpc-id,Values=%2" --output text --query "Reservations[*].Instances[*].SecurityGroups[*].{GroupId:GroupId}" ^|sort -n ^|uniq ^|sed ":a;N;$!ba;s/\n/,/g"
