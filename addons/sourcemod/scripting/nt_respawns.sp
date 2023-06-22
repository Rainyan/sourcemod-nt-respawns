#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.3.0"

#define LIFE_ALIVE 0
#define OBS_MODE_NONE 0
#define DAMAGE_YES 2
#define TRAIN_NEW 0xc0
#define SOLID_BBOX 2

#define EF_NODRAW 0x020

// Remember to update all format calls if you change this
#define RESPAWN_PHRASE "— RESPAWNING IN %d —"

#if SOURCEMOD_V_MAJOR > 1
#define SUPPORTS_DROP_BYPASSHOOKS
#endif
#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR > 12
#define SUPPORTS_DROP_BYPASSHOOKS
#endif
#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR == 12 && SOURCEMOD_V_REV >= 6961
#define SUPPORTS_DROP_BYPASSHOOKS
#endif

#if !defined(SUPPORTS_DROP_BYPASSHOOKS)
static Handle g_hForwardDrop = INVALID_HANDLE;
#endif

ConVar g_cRespawnTimeSecs = null;

public Plugin myinfo = {
	name = "NT Respawns",
	description = "Respawning for Neotokyo CTG mode",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/sourcemod-nt-respawns"
};

void InitGameData()
{
	Handle gd = LoadGameConfigFile("neotokyo/respawns");
	if (!gd)
	{
		SetFailState("Failed to load GameData");
	}
	DynamicDetour dd = DynamicDetour.FromConf(gd, "Fn_CNEOPlayer__OnPlayerDeath");
	if (!dd)
	{
		SetFailState("Failed to create detour");
	}
	if (!dd.Enable(Hook_Pre, PlayerKilled))
	{
		SetFailState("Failed to detour");
	}
	CloseHandle(gd);
}

#if defined(SUPPORTS_DROP_BYPASSHOOKS)
public void OnPluginStart()
#else
public void OnAllPluginsLoaded()
#endif
{
	InitGameData();

	g_cRespawnTimeSecs = CreateConVar("sm_nt_respawn_time_seconds", "5",
		"How many seconds until players will respawn", _, true, 1.0);

#if !defined(SUPPORTS_DROP_BYPASSHOOKS)
	g_hForwardDrop = CreateGlobalForward("OnGhostDrop", ET_Event, Param_Cell);
#endif
}

public MRESReturn PlayerKilled(int client, DHookReturn hReturn, DHookParam hParams)
{
	/* The first & only parameter is a CTakeDamageInfo, with the layout:
	Vector	m_vecDamageForce; <-- offset 16 (4*sizeof(BYTE)); rest are contiguous
	Vector	m_vecDamagePosition;
	Vector	m_vecReportedPosition; // pos players are told damage is coming from
	EHANDLE	m_hInflictor;
	EHANDLE	m_hAttacker;
	float	m_flDamage;
	float	m_flMaxDamage;
	float	m_flBaseDamage; // dmg before skill level adjustments; for uniform dmg forces
	int		m_bitsDamageType;
	int		m_iDamageCustom;
	int		m_iDamageStats;
	int		m_iAmmoType;
	*/

	// prevent "dying" multiple times while pretend dead
	SetEntityFlags(client, GetEntityFlags(client) | FL_GODMODE);

	SetInvisible(client, true);

	// Need to strip guns because the player's attachments will remain visible,
	// (or alternatively need to drop them in the world).
	int weps_size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	char classname[32];
	for (int i = 0; i < weps_size; ++i)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (weapon == -1)
		{
			continue;
		}
		if (!GetEntityClassname(weapon, classname, sizeof(classname)))
		{
			continue;
		}

		// Don't destroy the ghost; instead drop it to the world
		if (StrEqual(classname, "weapon_ghost"))
		{
			PrintToServer("Found ghost as wep %d", weapon);

			// For versions of SM that don't support reporting the weapon drop
			// via the call, we need to manually call the nt_ghostdrop forward.
			// This is kind of nasty but necessary for other plugins that rely
			// on this info.

#if defined(SUPPORTS_DROP_BYPASSHOOKS)
			SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR,
				false);
#else
			SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);

			Call_StartForward(g_hForwardDrop);
			Call_PushCell(client);
			Call_Finish();
#endif
			continue;
		}
		// Because most servers run plugins for weapons that never de-spawn,
		// explicitly destroy our guns to avoid overflowing the entity limit
		// for extended gameplay. A more elegant approach would be enforcing
		// the original NT's weapon de-spawning for when we are loaded, so
		// players can restock ammo by looting.
		RemovePlayerItem(client, weapon);
		RemoveEdict(weapon);
	}

	CreateRagdoll(client);

	int inflictor = hParams.GetObjectVar(1, 13 * 4, ObjectValueType_Ehandle);
	int attacker = hParams.GetObjectVar(1, 14 * 4, ObjectValueType_Ehandle);

	char weapon[32] = "world";
	if (client != attacker && attacker != 0 && IsValidEntity(inflictor))
	{
		if (!GetEntityClassname(inflictor, weapon, sizeof(weapon)))
		{
			LogError("Failed to get classname of attacker");
			return MRES_Ignored;
		}
	}

#if(0) // just for completeness sake; these aren't needed for this
	float dmg_force[3];
	hParams.GetObjectVarVector(1, 4 * 4, ObjectValueType_Vector, dmg_force);
	PrintToServer("dmg force: %f %f %f", dmg_force[0], dmg_force[1], dmg_force[2]);

	float dmg_pos[3];
	hParams.GetObjectVarVector(1, 7 * 4, ObjectValueType_Vector, dmg_pos);
	PrintToServer("damage pos: %f %f %f", dmg_pos[0], dmg_pos[1], dmg_pos[2]);

	float damage_reported_pos[3];
	hParams.GetObjectVarVector(1, 10 * 4, ObjectValueType_Vector,
		damage_reported_pos);
	PrintToServer("damage reported pos: %f %f %f",
		damage_reported_pos[0], damage_reported_pos[1], damage_reported_pos[2]);

	float damage = hParams.GetObjectVar(1, 15 * 4, ObjectValueType_Float);
	PrintToServer("damage: %f", damage);

	float max_damage = hParams.GetObjectVar(1, 16 * 4, ObjectValueType_Float);
	PrintToServer("max damage: %f", max_damage);

	// seems to return bogus values for us(?); unused by the mod?
	float base_damage = hParams.GetObjectVar(1, 17 * 4, ObjectValueType_Float);
	PrintToServer("base damage: %f", base_damage);

	int dmg_type = hParams.GetObjectVar(1, 18 * 4, ObjectValueType_Int);
	PrintToServer("bits damage type: %d", dmg_type);

	int dmg_custom = hParams.GetObjectVar(1, 19 * 4, ObjectValueType_Int);
	PrintToServer("damage custom: %d", dmg_custom);

	int dmg_stats = hParams.GetObjectVar(1, 20 * 4, ObjectValueType_Int);
	PrintToServer("damage stats: %d", dmg_stats);

	int ammo_type = hParams.GetObjectVar(1, 21 * 4, ObjectValueType_Int);
	PrintToServer("ammo type: %d", ammo_type);
#endif

	DataPack data;
	CreateDataTimer(1.0, Timer_DeferFakeDeath, data,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	// -1 because we've already waited once here until the first callback
	data.WriteCell(g_cRespawnTimeSecs.IntValue - 1);
	data.WriteCell(GetClientUserId(client));
	data.WriteString(weapon);
	// Print the initial message instantly for a more responsive feel
	PrintCenterText(client, RESPAWN_PHRASE, g_cRespawnTimeSecs.IntValue);

	CreateFakeDeathEvent(
		GetClientUserId(client),
		GetClientUserId(attacker),
		weapon
	);

	int score = 1;
	if (GetClientTeam(client) == GetClientTeam(attacker))
	{
		score = -1;
	}
	SetPlayerXP(client, GetPlayerXP(client) + score);
	SetPlayerDeaths(client, GetPlayerDeaths(client) + 1);

	hReturn.Value = 0;

	return MRES_Supercede;
}

void SetInvisible(int client, bool is_invisible)
{
	if (is_invisible)
	{
		SetEntProp(client, Prop_Send, "m_fEffects",
			GetEntProp(client, Prop_Send, "m_fEffects") | EF_NODRAW);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_fEffects",
			GetEntProp(client, Prop_Send, "m_fEffects") & ~EF_NODRAW);
	}
}

public Action Timer_DeferFakeDeath(Handle timer, DataPack data)
{
	data.Reset();
	int respawn_secs = data.ReadCell();
	int client = GetClientOfUserId(data.ReadCell());
	char weapon[32];
	data.ReadString(weapon, sizeof(weapon));

	if (client == 0)
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

	// Places the NT player in the world
	// TODO: figure out what this is
	Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(SDKLibrary_Server,
			"\x56\x8B\xF1\x8B\x06\x8B\x90\xBC\x04\x00\x00\x57\xFF\xD2\x8B\x06",
			16
		);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			ThrowError("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client);

	SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_NONE);
	SetEntProp(client, Prop_Send, "m_iHealth", 100);
	SetEntProp(client, Prop_Send, "m_lifeState", LIFE_ALIVE);
	SetEntProp(client, Prop_Send, "deadflag", 0);
	SetEntPropFloat(client, Prop_Send, "m_flDeathTime", 0.0);
	SetEntProp(client, Prop_Send, "m_bDucked", false);
	SetEntProp(client, Prop_Send, "m_bDucking", false);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", true);
	SetEntProp(client, Prop_Send, "m_nRenderFX", 0);
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_flFallVelocity", 0.0);
	SetEntProp(client, Prop_Send, "m_nSolidType", SOLID_BBOX);
	SetEntProp(client, Prop_Data, "m_fInitHUD", 1);
	SetEntPropFloat(client, Prop_Data, "m_DmgTake", 0.0);
	SetEntPropFloat(client, Prop_Data, "m_DmgSave", 0.0);
	SetEntProp(client, Prop_Data, "m_afPhysicsFlags", 0);
	SetEntProp(client, Prop_Data, "m_bitsDamageType", 0);
	SetEntProp(client, Prop_Data, "m_bitsHUDDamage", -1);
	SetEntProp(client, Prop_Data, "m_takedamage", DAMAGE_YES);
	SetEntityMoveType(client, MOVETYPE_WALK);
	// declaring as variables for older sm compat
	float campvsorigin[3];
	float hackedgunpos[3] = { 0.0, 32.0, 0.0 };
	SetEntPropVector(client, Prop_Data, "m_vecCameraPVSOrigin", campvsorigin);
	SetEntPropVector(client, Prop_Data, "m_HackedGunPos", hackedgunpos);
	SetEntProp(client, Prop_Data, "m_bPlayerUnderwater", false);
	SetEntProp(client, Prop_Data, "m_iTrain", TRAIN_NEW);

	SetInvisible(client, false);
	SetEntityFlags(client, GetEntityFlags(client) & ~FL_GODMODE);
	ChangeEdictState(client, 0);

	GivePlayerEquipment(client);

	return Plugin_Stop;
}

void GivePlayerEquipment(int client)
{
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(SDKLibrary_Server,
			"\x83\xEC\x1C\x56\x8B\xF1\x8B\x86\xC0\x09\x00\x00", 12
		);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			ThrowError("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client);
}

void CreateFakeDeathEvent(int victim_userid, int attacker_userid=0,
	const char[] weapon="world", int icon=0)
{
	Event event = CreateEvent("player_death", true);
	if (event == null)
	{
		ThrowError("Failed to create event");
	}

	event.SetInt("userid", victim_userid);
	event.SetInt("attacker", attacker_userid);
	event.SetString("weapon", weapon);
	event.SetInt("icon", icon);

	event.Fire();
}

// TODO: support gibbing
void CreateRagdoll(int client)
{
	if (client < 0 || client >= MaxClients)
	{
		ThrowError("Invalid client index: %d", client);
	}
	if (!IsClientInGame(client))
	{
		ThrowError("Client is not in game: %d", client);
	}

	int team = GetClientTeam(client);
	if (team != TEAM_JINRAI && team != TEAM_NSF)
	{
		ThrowError("Unexpected team %d", team);
	}

	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(SDKLibrary_Server,
			"\x53\x56\x57\x8B\xF9\x8B\x87\x1C\x0E\x00\x00", 11);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			ThrowError("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client);
}
