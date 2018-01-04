# Summary

Creates HomeAssistant's .yaml containing Broadlink IR codes for entire remotes found in the irdb (`https://github.com/probonopd/irdb/tree/master/codes`) or lirc (`https://sourceforge.net/p/lirc-remotes/code/ci/master/tree/remotes/`) databases.

** It is currently suggested to try irdb first as converting lirc devices is much slower right now **


# Dependencies

Will be automatically downloaded and stored in the work dir 'irdb2broadlinkha-work'.


`pronto2broadlink.py` from:  
  
    https://gist.githubusercontent.com/appden/42d5272bf128125b019c45bc2ed3311f/raw/bdede927b231933df0c1d6d47dcd140d466d9484/pronto2broadlink.py  


IrpTransmogrifier from:  

    https://github.com/bengtmartensson/IrpTransmogrifier



# Usage

Find your remote in irdb under 

    https://github.com/probonopd/irdb/tree/master/codes  
Note the path of the .csv file under the codes/ directory, e.g. `Sky/Unknown_DVB-S/0,12.csv`

or the lirc config under
    https://sourceforge.net/p/lirc-remotes/code/ci/master/tree/remotes/
Note the path of the .lircd.conf file under the remotes/ directory, e.g. `apple/A1294.lircd.conf`


Then run this script with parameters:  
- The path to the .csv/.conf as determined above, or an irdb directory path to process all the remotes in that directory
- Prefix to use for the switch id and friendly name in the HA config
- (optional) search pattern to match the function name against - e.g. POWER. Useful for very large remotes or when pulling a directory full of remotes.


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



# Discovery mode

When you don't know which remote you need from irdb this tool can download all the remotes in a directory and process them all.
Pass a search pattern (third parameter) of "POWER" to just get the power buttons, then go through them manually until you find the ones that work for your device.
e.g.:

    ./irdb2broadlinkha.bash 'Yamaha/Receiver' amptest_ POWER >~/.homeassistant/broadlink/yamaha_all_test.yaml
