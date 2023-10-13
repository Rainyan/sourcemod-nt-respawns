#include <sourcemod>

#include <neotokyo>


//#define FLATTEN_INCLUDE_PATHS
#if defined(FLATTEN_INCLUDE_PATHS)
#include "nt_deadtools_natives"
#else
// If you're compiling using Spider orother in-browser compiler,
// and these include paths are failing, un-comment the FLATTEN_INCLUDE_PATHS
// compile flag above.
#include "nt_deadtools/nt_deadtools_natives"
#endif


#pragma semicolon 1
#pragma newdecls required

ConVar g_cRespawnTimeSecs;

static bool g_bLateLoad;
static int g_iOldClientDeadToolsBits[NEO_MAXPLAYERS + 1];

#define PLUGIN_VERSION "1.0.1"

// Remember to update all format calls if you change this
#define RESPAWN_PHRASE "— RESPAWNING IN %d —"

public Plugin myinfo = {
	name = "NT Respawns",
	description = "Respawning for Neotokyo CTG mode",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/sourcemod-nt-respawns"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error,
	int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cRespawnTimeSecs = CreateConVar("sm_nt_respawn_time_seconds", "5",
		"How many seconds until players will respawn", _, true, 0.0);

	if (!HookEventEx("player_death", OnPlayerDeath, EventHookMode_Pre))
	{
		SetFailState("Failed to hook event");
	}
}

public void OnAllPluginsLoaded()
{
	DeadTools_VerifyApiVersion();

	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client))
		{
			continue;
		}
		g_iOldClientDeadToolsBits[client] = DeadTools_GetClientFlags(client);
		if (g_bLateLoad)
		{
			DeadTools_SetIsDownable(client, true);
		}
	}
}

public void OnPluginEnd()
{
	// TODO: This is kind of awkward and really we should rework the base
	// DeadTools plugin design to take care of all of this automagically.
	// But for now, this boilerplate is kind of required.
	for (int client = 1; client <= MaxClients; ++client)
	{
		// This is required for now, because if we unload early after having
		// declared this client "downable", they might end up with no plugin
		// to handle that custom state, leaving the player in limbo.
		//
		// If the client was already declared as having the "downable" bits
		// before we loaded, don't step on the toes of other plugins using it.
		if (!(g_iOldClientDeadToolsBits[client] & DEADTOOLS_FLAG_DOWNABLE))
		{
			if (IsClientInGame(client))
			{
				DeadTools_SetIsDownable(client, false);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	// Note that you should *not* pair this with OnClientDisconnect;
	// the DeadTools base plugin will remove the client index downable bitflag
	// automatically for us.
	DeadTools_SetIsDownable(client, true);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == 0 ||
		!(DeadTools_GetClientFlags(client) & DEADTOOLS_FLAG_DOWN))
	{
		return;
	}

	// So we can skip the "Respawning..." screen print stuff on <1 sec respawns
	bool instant_revive = (g_cRespawnTimeSecs.FloatValue < 1);

	// TODO: do we have to defer the revive here?? if not, could just call directly
	DataPack data;
	CreateDataTimer(instant_revive ? 0.1 : 1.0, Timer_Revive, data,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	// -1 because we've already waited once here until the first print callback
	data.WriteCell(instant_revive ? 0 : g_cRespawnTimeSecs.IntValue - 1);
	data.WriteCell(GetClientUserId(client));
	if (!instant_revive)
	{
		// Print the initial message instantly for a more responsive feel
		PrintCenterText(client, RESPAWN_PHRASE, g_cRespawnTimeSecs.IntValue);
	}
}

public Action Timer_Revive(Handle timer, DataPack data)
{
	data.Reset();
	int respawn_secs = data.ReadCell();
	int client = GetClientOfUserId(data.ReadCell());

	if (client == 0 ||
		!(DeadTools_GetClientFlags(client) & DEADTOOLS_FLAG_DOWN))
	{
		return Plugin_Stop;
	}

	if (respawn_secs > 0)
	{
		PrintCenterText(client, RESPAWN_PHRASE, respawn_secs);
		data.Reset();
		data.WriteCell(respawn_secs - 1);
		return Plugin_Continue;
	}
	PrintCenterText(client, ""); // clear any lingering "RESPAWNING..." text

	DeadTools_Revive(client);

	return Plugin_Stop;
}
