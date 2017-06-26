#!/bin/bash

if [ -z $1 ]; then
 echo "no file given"
exit 0
fi

if [ -z $2 ]; then
    outFilePrefix="$(echo $1 | sed 's=.*/==;s/.iso//I')"
else
    outFilePrefix=$2
fi

if [ -z $3 ]; then
    outTitleOffset=1
else
    outTitleOffset=$3
fi

rawout=$(HandBrakeCLI --min-duration 0 -i $1 -t 0 2>&1 >/dev/null)
count=$(echo $rawout | grep -Eao "\\+ title [0-9]+:" | wc -l)

echo $rawout | grep -Eao "\\+ duration: [0-9]+:[0-9]+:[0-9]+"
echo $count

for i in $(seq $count)
do
    title=$(printf "%02d" $outTitleOffset)
    ((outTitleOffset++))
    echo -e "\n\n\nExtracting title $i as '${outFilePrefix}${title}.mkv'\n\n\n"
    HandBrakeCLI -i $1 -t $i --preset Normal --output ${outFilePrefix}${title}.mkv
done

echo -e "\n\n\niso2mkv complete!"
