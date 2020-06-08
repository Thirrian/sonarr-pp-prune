#!/bin/bash

# ------------------------------------
# config
# ------------------------------------

# sonarr instance details (copy/paste from Settings > General in sonarr)
proto=http
host=localhost
ip=8989
urlbase=/sonarr
api=your_api_key

# script config
# select where to save logs from the script for future reference. /dev/null discards logs
log="/dev/null" 
debuglog="/dev/null"

# ------------------------------------
# end config
# ------------------------------------


if [[ "${sonarr_eventtype}" == "Test" ]];
then
	
	echo "test event fired succesfully." | tee -a $log
	exit 0
	
fi

if [[ "${sonarr_eventtype}" != "Download" && "${sonarr_isupgrade}" != "False" ]];
then
	
	echo "this script only works for the 'On Import' event in Sonarr by design" | tee -a $log
	exit 0
	
fi

main


main() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	echo "running prune for ${sonarr_series_title}" | tee -a $log
	
	# get all tags from sonarr instance
	json_sonarr_tags=$(curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/tag | jq -r '.[] | @base64')
	
	# get series info
	json_series=$(curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/series/${sonarr_series_id})
	
	# fill prune_tags array
	get_prune_tags
	
	# get id of prune-unmonitor tag in sonarr
	get_unmonitor_tag_id
	
	# if no prune tags exist in sonarr, exit here
	if [[ ${#prune_tags[@]} -eq 0 ]]; then
		echo "no prune tags found, exiting" | tee -a $log
		exit 0
	fi
	
	# get number of files to keep, -1 in case of multiple prune tags assigned to series
	get_files_to_keep
	
	# if none or more than one prune tag was associated with the series, exit here	
	if [[ $files_to_keep -eq -1 ]]; then
		echo "either none, or more than one prune tag is associated with this series" | tee -a $log
		exit 0
	fi
	
	# get monitored flag
	get_monitored
	
	# get number of files on disk for series
	files_available=$(echo $json_series | jq '.episodeFileCount')
	
	echo "files on disk : $files_available" | tee -a $log
	echo "files to keep : $files_to_keep" | tee -a $log
	
	# get number of files to prune
	files_to_prune=$((files_available-files_to_keep))
	
	# if no files need to be deleted, exit here
	if [[ $files_to_prune -lt 1 ]]; then
		echo "prune not required" | tee -a $log
		exit 0
	fi
	
	# get episodes with a file for this series
	json_episodes=$(curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/episode?seriesId=${sonarr_series_id})
	
	echo "pruning $files_to_prune files..." | tee -a $log
	
	# delete files
	delete_files
	
	# unmonitor episodes if required
	if [[ $monitored == false ]]; then
		unmonitor_episodes
	fi
	
	echo "prune complete" | tee -a $log
	
	echo "$FUNCNAME end" >>$debuglog

}


delete_files() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	# list of file ids
	file_ids=$(echo $json_episodes | jq -r '.[] | select( .hasFile ) | .episodeFileId')
	
	# loop over all file_ids
	for file_id in $(echo $file_ids);
	do
	
		((files_deleted+=1))
		
		if [[ $files_deleted -le $files_to_prune ]]; then
			
			delete_file
		
		else
		
			break
			
		fi
		
	done
	
	echo "$FUNCNAME end" >>$debuglog
	
}


unmonitor_episodes() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	# list of episode ids
	episode_ids=$(echo $json_episodes | jq -r '.[] | select( .hasFile ) | .id')
	
	# loop over all episode_ids
	for episode_id in $(echo $episode_ids);
	do
	
		((episodes_unmonitored+=1))
		
		if [[ $episodes_unmonitored -le $files_to_prune ]]; then
		
			unmonitor_episode
		
		else
		
			break
		
		fi
	
	done
	
	echo "$FUNCNAME end" >>$debuglog
	
}


delete_file() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	# api call to delete episode file
	curl -s -H "X-Api-Key: $api" -X DELETE $proto://$host:$ip$urlbase/api/episodefile/$file_id 1>>$debuglog 2>&1
	
	echo "$FUNCNAME end" >>$debuglog
	
}


unmonitor_episode() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	# get episode json
	episode=$(curl -s -H "X-Api-Key: $api" $proto://$host:$ip$urlbase/api/episode/$episode_id)
	
	# set monitored to false
	episode=$(echo $episode | jq '.monitored = false')
	
	# api call to submit modified episode to disable monitoring
	curl -s -H "X-Api-Key: $api" -H "Content-Type: application/json" -X PUT -d "$episode" $proto://$host:$ip$urlbase/api/episode 1>>$debuglog 2>&1
	
	echo "$FUNCNAME end" >>$debuglog
	
}


get_prune_tags() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	# get all sonarr tags, filter out prune-* tags and fill array
	for tag in $(echo $json_sonarr_tags);
	do	
		_t() {
			echo ${tag} | base64 --decode | jq -r ${1}
		}
		case "$(_t '.label')" in
			prune-unmonitor)
				# ignore prune-unmonitor
				;;
			prune-*)
				id=$(_t '.id')
				number=$(_t '.label')
				prune_tags+=( [$id]=${number:6} )		
				;;
		esac
	done
	
	echo "$FUNCNAME end" >>$debuglog
	
}


get_unmonitor_tag_id() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	prune_unmonitor_tagid=-1
	for tag in $(echo $json_sonarr_tags);
	do	
		_t() {
			echo ${tag} | base64 --decode | jq -r ${1}
		}
				
		if [[ "$(_t '.label')" == "prune-unmonitor" ]]; then
		
			unmonitor_tag_id=$(_t '.id')
		
		fi
	done
	
	echo "$FUNCNAME end" >>$debuglog
	
}


get_files_to_keep() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	# loop over all tags for the series
	for series_tag_id in $(echo $json_series | jq -r '.tags | .[]');
	do
	
		# loop over all prune tags and match with series tags
		for prune_tag_id in "${!prune_tags[@]}";
		do
		
			# if a match for a prune-* tag is found, remember the number of files to prune and increment the counter for found prune tags
			if [[ $series_tag_id -eq $prune_tag_id ]]; then
								
				((prune_tag_count+=1))
				files_to_keep=${prune_tags[$prune_tag_id]}
			
			fi
		
		done

	done
	
	# more than one prune tag is assigned to the series, can't find number of files to keep
	if [[ $prune_tag_count != 1 ]]; then
	
		files_to_keep=-1
	
	fi
	
	echo "$FUNCNAME end" >>$debuglog
	
}


get_monitored() {
	
	echo "$FUNCNAME start" >>$debuglog
	
	monitored=true
	
	# get unmonitor tag id, -1 when not found
	get_unmonitor_tag_id
	
	# check if prune-unmonitor tag exists in sonarr
	if [[ $unmonitor_tag_id != -1 ]]; then
	
		# loop over all tags for the series
		for series_tag_id in $(echo $json_series | jq -r '.tags | .[]');
		do
		
			# if prune-unmonitor tag is applied to series, set unmonitor flag to true
			if [[ $series_tag_id == $unmonitor_tag_id ]]; then
			
				monitored=false
				
			fi
			
		done
	
	fi
	
	echo "$FUNCNAME end" >>$debuglog
	
}
