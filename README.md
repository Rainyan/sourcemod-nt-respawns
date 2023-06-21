# sourcemod-nt-respawns
Neotokyo plugin that adds respawns to the CTG mode. **Experimental plugin, weirdness may occur!**

## Build requirements
* SourceMod 1.10 or newer
  * **If using SourceMod older than 1.11**: you also need [the DHooks extension](https://forums.alliedmods.net/showpost.php?p=2588686). Download links are at the bottom of the opening post of the AlliedMods thread. Be sure to choose the correct one for your SM version! You don't need this if you're using SourceMod 1.11 or newer.
* [Neotokyo include](https://github.com/softashell/sourcemod-nt-include), version 1.0 or newer

## Installation
* Place [the gamedata file](addons/sourcemod/gamedata/neotokyo/) to the `addons/sourcemod/gamedata/neotokyo` folder (create the "neotokyo" folder if it doesn't exist).
* Compile the plugin, and place the .smx binary file to `addons/sourcemod/plugins`

## Usage
### Cvars
* `sm_nt_respawn_time_seconds` — (integer) How many seconds until players will respawn. Must be >0 and should be less than the round length (currently there is not respawn canceling at new round start)
