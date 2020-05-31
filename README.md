# sonarr-pp-prune
Sonarr postprocessing script to automatically prune series (keep only a specified number of files on disk).
Highly untested, use at your own risk.

## Usage

1. Save pp-prune.sh to a directory you can access from sonarr

2. Edit pp-prune-main.sh to configure it.

The first section are your sonarr details and should be straightforward:
```bash
proto=http
host=localhost
ip=8989
urlbase=/sonarr # blank for typical installations
api=your_api_key
```
Secondly, set the unmonitor option to true or false. This will make an extra api call to sonarr to unmonitor an episode after deleting the corresponding file. Default: true.
```bash
unmonitor=true
```

3. Create a pp-prune-x.sh script which points to `./pp-prune-main.sh <x>` where x is the number of files you want to keep. Example:
```bash
#!/bin/bash
/bin/bash /path/to/prune.sh 10
```
4. Tag series you want to auto-prune with e.g. “prune10”
5. Create a new Custom Script connection in sonarr:  
  - Name: whatever you like, e.g. “Prune 10”
  - On Import: enable
  - DISABLE all other events
  - Tags: enter the same tag you used for your series, e.g. “prune10”
  - Browse to the script you created in step 2, e.g. pp-prune-10.sh. Do NOT select the pp-prune-main.sh script.
  
Repeat steps 3-5 for every group of series that require a different number of files to keep.

## Todo

Not necessarily by me. Just things I'd like to be better.
- Turn the unmonitor option into a parameter, so it can be enabled/disabled for each prune group as required.
- Clean up fugly code.
