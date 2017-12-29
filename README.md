# Dependencies

`pronto2broadlink.py` from:  
  
    https://gist.githubusercontent.com/appden/42d5272bf128125b019c45bc2ed3311f/raw/bdede927b231933df0c1d6d47dcd140d466d9484/pronto2broadlink.py


# Usage

Find your remote under  

    https://github.com/probonopd/irdb/tree/master/codes  
Note the path of the .csv file under the codes/ directory, e.g.
`Sky/Unknown_DVB-S/0,12.csv`

Then run this script with two parameters:  
- The path to the .csv from the codes directory
- Prefix to use for the switch id and friendly name in the HA config

e.g.:  

    ./irdb2broadlinkha.bash 'Sky/Unknown_DVB-S/0,12.csv' Sky_


This will output the YAML ready to be pasted into your HomeAssistant config.

To save it to a file use unix redirection `>`:

    ./irdb2broadlinkha.bash 'Sky/Unknown_DVB-S/0,12.csv' Sky_ >sky.yaml


As this can generate many lines it clutters up `configuration.yaml` so it is neater to have each IR device in its own file and include it from `configuration.yaml`.
One way to do that is make a directory for the remotes - e.g. `broadlink` - then use HA's `!include_dir_merge_named` to merge all files contained in that directory into
the broadlink switches configuration.


e.g., `configuration.yaml`:

    - platform: broadlink
        mac: 'xx:xx:xx:xx:xx:xx'
        host: 192.168.1.xx
        timeout: 15
        friendly_name: "Broadlink"
        switches:
          !include_dir_merge_named broadlink


then run `irdb2broadlinkha.bash` for each remote:  

    ./irdb2broadlinkha.bash 'Sky/Unknown_DVB-S/0,12.csv' Sky_ >~/.homeassistant/broadlink/sky.yaml  

    ./irdb2broadlinkha.bash 'Yamaha/Receiver/120%2C-1.csv' amp_ >~/.homeassistant/broadlink/yamaha_receiver.yaml

