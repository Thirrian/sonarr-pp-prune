# sonarr-pp-prune
Sonarr postprocessing script to automatically prune series (keep only a specified number of files on disk).

**Highly untested, use at your own risk.**

## Setup

### Script

1. Save pp-prune.sh to a directory you can access from sonarr

2. Edit pp-prune.sh to configure it.

The first section are your sonarr details and should be straightforward:
```bash
proto=http
host=localhost
ip=8989
urlbase=/sonarr # blank for typical installations
api=your_api_key
```

The second section is optional, you can specify a (debug) log file.
```bash
log="/dev/null" 
debuglog="/dev/null"
```

### Sonarr

1. Create prune tags in sonarr

Create any number of tags starting with `prune-` followed by a whole number. E.g. `prune-10`.

These tags are read by the script to determine how many files to keep for a particular series. If you put anything other than a whole number here (with the exception of `unmonitor`), who knows what happens.

2. Optional: create `prune-unmonitor` tag in sonarr

This tag is used by the script to determine if an episode should be unmonitored after a file is deleted.

3. Create script connection

- Go to Settings - Connect in sonarr
- Add a new Custom Connection notification
  - Name: anything you like
  - On Import: enable
  - All other events (grab/upgrade/rename/health): disable
  - Tags: not required. (_If you want, you can tag the connection with all `prune-<x>` tags you created earlier, so it only runs for those series you really want. If the script detects that no prune tag is configured for the episode sonarr just imported, it will not do anything.)_
  - Path: browse to pp-prune.sh

## Usage

Tag series with **one** of the `prune-<x>` tags you created.

Optionally tag series with `prune-unmonitor`.

## Todo

Testing, testing, testing...
