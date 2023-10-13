#include <sourcemod>

#include <neotokyo>

#include "nt_deadtools/nt_deadtools_natives"

#pragma semicolon 1
#pragma newdecls required

ConVar g_cRespawnTimeSecs;

#define PLUGIN_VERSION "1.0.0"

// Remember to update all format calls if you change this
#define RESPAWN_PHRASE "— RESPAWNING IN %d —"

public Plugin myinfo = {
	name = "NT Respawns",
	description = "Respawning for Neotokyo CTG mode",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/sourcemod-nt-deadtools"
};

public void OnPluginStart()
{
	g_cRespawnTimeSecs = CreateConVar("sm_nt_respawn_time_seconds", "5",
		"How many seconds until players will respawn", _, true, 0.0);

	if (!HookEventEx("player_death", OnPlayerDeath, EventHookMode_PostNoCopy))
	{
		SetFailState("Failed to hook event");
	}
}

public void OnAllPluginsLoaded()
{
	DeadTools_VerifyApiVersion();
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == 0 ||
		!(DeadTools_GetClientFlags(client) & DEADTOOLS_FLAG_DOWN))
	{
		return;
	}

	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon), "world");

	// So we can skip the "Respawning..." screen print stuff on <1 sec respawns
	bool instant_revive = (g_cRespawnTimeSecs.FloatValue < 1);

	// TODO: do we have to defer the revive here?? if not, could just call directly
	DataPack data;
	CreateDataTimer(instant_revive ? 0.1 : 1.0, Timer_Revive, data,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	// -1 because we've already waited once here until the first print callback
	data.WriteCell(instant_revive ? 0 : g_cRespawnTimeSecs.IntValue - 1);
	data.WriteCell(GetClientUserId(client));
	data.WriteString(weapon);
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