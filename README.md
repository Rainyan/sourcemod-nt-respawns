# sourcemod-nt-respawns
Neotokyo plugin that adds respawns to the CTG mode. **Experimental plugin, weirdness may occur!**

If you encounter a bug, please consider [creating a bug report for it](https://github.com/Rainyan/sourcemod-nt-respawns/issues/new/choose)!

### Example
[nt_respawns_example.webm](https://github.com/Rainyan/sourcemod-nt-respawns/assets/6595066/40307a50-5c2d-443d-be5d-94d4dd4d2259)

## Build requirements
* SourceMod 1.8 or newer
  * **If using SourceMod older than 1.11**: you also need [the DHooks extension](https://forums.alliedmods.net/showpost.php?p=2588686). Download links are at the bottom of the opening post of the AlliedMods thread. Be sure to choose the correct one for your SM version! You don't need this if you're using SourceMod 1.11 or newer.
* [Neotokyo include](https://github.com/softashell/sourcemod-nt-include), version 1.0 or newer

## Installation
* Place [the gamedata file](addons/sourcemod/gamedata/neotokyo/) to the `addons/sourcemod/gamedata/neotokyo` folder (create the "neotokyo" folder if it doesn't exist).
* Compile [the plugin](addons/sourcemod/scripting), and place the .smx binary file to `addons/sourcemod/plugins`

## Usage
### Cvars
* `sm_nt_respawn_time_seconds` — (integer) How many seconds until players will respawn. Must be >0 and should be less than the round length (currently there is [**no** respawn canceling](https://github.com/Rainyan/sourcemod-nt-respawns/issues/4) at new round start!)

### Ability to loot weapons/ammo
You'll need the [nt_drop plugin](https://github.com/softashell/nt-sourcemod-plugins/blob/master/scripting/nt_drop.sp), version 0.8.0 or newer. Set its cvar `sm_ntdrop_nodespawn` to value `0` (it defaults to `1`). This will allow weapons dropped in the world to de-spawn after 30 seconds, which is necessary in respawn mode to avoid spawning too many objects in the world for the engine to handle.
