#!/bin/bash

# prune master script
# don't call this directly in sonarr, see readme

# ------------------------------------
# config
# sonarr instance details (copy/paste from Settings > General in sonarr)
proto=http
host=localhost
ip=8989
urlbase=
api=your_api_key
# unmonitor episode after deleting episode file
# true = enable
# false = don't change monitored status
unmonitor=true
# select where to save logs from the script for future reference. /dev/null discards logs
log="/dev/null"
debuglog="/dev/null"

# end config
# ------------------------------------

echo "Log from $date)" >> $log

if [[ "${sonarr_eventtype}" == "Test" ]];
then

	echo "test event fired succesfully." | tee -a $log
	exit 0
	
fi

if [[ "${sonarr_eventtype}" != "Download" && "${sonarr_isupgrade}" != "False" ]];
then

	echo "this script only works for the 'On Import' event in Sonarr by design." | tee -a $log
	echo "disable all notifications other than 'On Import' in Sonarr." | tee -a $log
	exit 1
	
fi

if [[ "$#" -ne 1 ]];
then

	echo "invalid number of parameters. Do NOT call this script directly, use a wrapper script." | tee -a $log
	echo "see help file for more info."
	exit 1
	
fi

if [[ "$1" -lt 1 ]];
then

	echo "this script needs a single parameter, which is a positive number of episodes to keep." | tee -a $log
	echo "example: prune.sh 10"
	exit 1
	
fi

echo "pruning ${sonarr_series_title}" | tee -a $log
echo "files to keep : $1" | tee -a $log

filecount=$(curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/series/${sonarr_series_id} | jq '.episodeFileCount')
echo "files on disk : $filecount" | tee -a $log

prune=$((filecount-$1))

if [[ $prune -gt 0 ]];
then

	echo "pruning $prune file(s)..." | tee -a $log

	count=1
	
	curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/episode?seriesId=${sonarr_series_id} | jq -r '.[] | select( .hasFile ) | "\(.id);\(.episodeFileId);\(.seasonNumber);\(.episodeNumber)"' | while read line ; do
		
		if [[ $count -le $prune ]];
		then
			{ 
				echo "Count @ $count"; 
				echo "\$line =";
				echo "$line" 
			} >> $debuglog

			episodeid=$(echo $line | cut -d';' -f1)
			fileid=$(echo $line | cut -d';' -f2)
			season=$(echo $line | cut -d';' -f3)
			episode=$(echo $line | cut -d';' -f4)
			
			echo "season $season, episode $episode:" | tee -a $log
			
			curl -s -H "X-Api-Key: $api" -X DELETE $proto://$host:$ip$urlbase/api/episodefile/$fileid 1>>$debuglog 2>&1
			echo "-> file deleted" | tee -a $log
			
			if [[ $unmonitor == true ]];
			then
			
				json=$(curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/episode/$episodeid | jq '.monitored = false')
				echo "JSON" | tee -a $debuglog
				echo "$json" | tee -a $debuglog
				curl -s -H "X-Api-Key: $api" -H "Content-Type: application/json" -X PUT -d "$json" $proto://$host:$ip$urlbase/api/episode 1>>$debuglog 2>&1
				echo "-> episode unmonitored" | tee -a $log
				
			fi
						
			((count+=1))
			
		else
		
			echo "$prune file(s) pruned." | tee -a $log
			break
		
		fi
	
	done

else

	echo "pruning not required, exiting..." | tee -a $log

fi
