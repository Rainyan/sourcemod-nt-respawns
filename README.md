# sourcemod-nt-respawns
Neotokyo plugin that adds respawns to the CTG mode. **Experimental plugin, weirdness may occur!**

If you encounter a bug, please consider [creating a bug report for it](https://github.com/Rainyan/sourcemod-nt-respawns/issues/new/choose)!

Additional plugin for custom respawn locations [is available here](https://github.com/Rainyan/sourcemod-nt-spawn-locations).

### Example
[nt_respawns_example.webm](https://github.com/Rainyan/sourcemod-nt-respawns/assets/6595066/40307a50-5c2d-443d-be5d-94d4dd4d2259)

## Build requirements
* SourceMod 1.8 or newer
* [Neotokyo include](https://github.com/softashell/sourcemod-nt-include), version 1.0 or newer
* [Neotokyo DeadTools](https://github.com/Rainyan/sourcemod-nt-deadtools) plugin, API version 1.0 or compatible.

## Installation
* Compile [the plugin](addons/sourcemod/scripting), and place the .smx binary file to `addons/sourcemod/plugins`

## Usage
### Cvars
* `sm_nt_respawn_time_seconds` — (integer) How many seconds until players will respawn. Must be >=0 and should be less than the round length (currently there is [**no** respawn canceling](https://github.com/Rainyan/sourcemod-nt-respawns/issues/4) at new round start!) If set to 0, players will instantly respawn without the countdown timer.
