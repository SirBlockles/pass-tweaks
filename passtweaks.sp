/*
	PASS Tweaks
	by muddy, written for PASS Time Federation
	
	Custom adjustments to PASS Time for competitive play.
	All settings default to OFF and should be turned on by a comp cfg.
	
	CURRENT FEATURES:
	Blocks passes between teammates from filling up the bonus bar.
	Prevents damage under a certain threshold from affecting the ball, with adjustable threshold
	Remove trail on ball
	Remove mark-for-death on solo carry when pack enabled
	Add log-formatted events for passtime events for log parsers
	Custom dispenser behavior for ball carrier, fine grained control vs vanilla pack beam
	Stealing from enemies increases bonus goal power meter
	
	CURRENT ISSUES:
	(?) Windows offsets: are they right? i only have linux environments to test on.
	
	IDEAS FOR FUTURE CHANGES:
	custom powerball buffs, for use in combination with disabling bonus goals
	(e.g. instead of bonus goals at full meter, carrier gets a speed boost or something?)
	
	CHANGELOG:
	1.0 - initial release

	1.1 - updated offsets, cleaner DHooks calls
*/

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

// CVARS
Handle cvar_blockInterceptEnable;

Handle cvar_blockHitEnable;
Handle cvar_blockHitThreshold;

Handle cvar_removeTrailEnable;

Handle cvar_blockMinicritEnable;

Handle cvar_customDispenserEnable;
Handle cvar_customDispenserMetal;
Handle cvar_customDispenserHealRate;

Handle cvar_powerballOnSteal;

Handle cvar_customScoreEnable;
Handle cvar_customScoreBase;
Handle cvar_customScoreBonus;

Handle cvar_customRoundTimeEnable;
Handle cvar_customRoundTimeStarttime;
Handle cvar_customRoundTimeMaxtime;
Handle cvar_customRoundTimeHaste;
Handle cvar_customRoundTimeHasteBonus;

// DHOOKS OFFSETS
Handle hRefillThink;
Handle hHealRate;

// LOGIC GLOBALS
int passBall = -1;
int roundTimer = -1;
int firstGrab;
int carrierDispenser;
int carrierDispenserTrigger;
Handle catchDataTimer;

#define VERSION "1.1"

public Plugin myinfo = {
	name = "PASS Tweaks",
	author = "muddy",
	description = "Gameplay tweaks for competitive PASS Time",
	version = VERSION,
	url = ""
}

public void OnPluginStart() {
	HookEvent("pass_pass_caught", catchBallEvent, EventHookMode_Pre);
	HookEvent("pass_get", passGrabEvent);
	HookEvent("pass_free", passDropEvent);
	HookEvent("pass_ball_stolen", passStealEvent);
	HookEvent("pass_score", passScoreEvent, EventHookMode_Pre);
	HookEvent("teamplay_setup_finished", setupFinishEvent);
	HookEntityOutput("info_passtime_ball_spawn", "OnSpawnBall", ballSpawnEvent);
	
	passBall = FindEntityByClassname(-1, "passtime_ball");
	if(passBall > 0) { SDKHook(passBall, SDKHook_OnTakeDamage, ballTakeDamage); }
	
	cvar_blockInterceptEnable = CreateConVar("sm_passtweaks_blockpassbonus", "0", "If enabled, passes between teammates will not fill the bonus meter", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_blockHitEnable = CreateConVar("sm_passtweaks_blockhit", "0", "If enabled, prevent damage below a certain threshold from affecting the ball", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_blockHitThreshold = CreateConVar("sm_passtweaks_blockhit_threshold", "25", "Minimum damage required for a hit to affect the ball when blockhit is enabled", FCVAR_ARCHIVE, true, 0.0, true, 999.0);
	cvar_removeTrailEnable = CreateConVar("sm_passtweaks_removetrail", "0", "Should trail be removed from the ball?\n0 - no\n1 - yes, on spawn\n2 - yes, on first pickup (trail active on spawn)", FCVAR_ARCHIVE, true, 0.0, true, 2.0);
	cvar_blockMinicritEnable = CreateConVar("sm_passtweaks_blockminicrit", "0", "If enabled, solo ball carrier will not take mini-crits with the pack enabled", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_customDispenserEnable = CreateConVar("sm_passtweaks_balldispenser", "0", "If enabled, ball carrier has dispenser attached. USE WITH tf_passtime_pack_speed 0 !!!", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_customDispenserMetal = CreateConVar("sm_passtweaks_balldispenser_metal", "0", "If enabled, ball dispenser will generate metal like a normal dispenser.", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_customDispenserHealRate = CreateConVar("sm_passtweaks_balldispenser_healrate", "5.0", "Heal rate, in HP/sec, of the carried ball dispenser.", FCVAR_ARCHIVE, true, 0.0, false);
	cvar_powerballOnSteal = CreateConVar("sm_passtweaks_powerball_steal", "0.0", "Powerball points awarded when stealing from an enemy ball carrier", FCVAR_ARCHIVE, true, 0.0, true, 100.0);
	cvar_customScoreEnable = CreateConVar("sm_passtweaks_custom_scoring", "0.0", "If enabled, you can adjust the amount of points for normal and bonus goals", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_customScoreBase = CreateConVar("sm_passtweaks_custom_scoring_base", "1.0", "Points awarded for a normal goal if custom scoring is on", FCVAR_ARCHIVE, true, 0.0, true, 100.0);
	cvar_customScoreBonus = CreateConVar("sm_passtweaks_custom_scoring_bonus", "2.0", "Points awarded for a bonus goal if custom scoring is on", FCVAR_ARCHIVE, true, 0.0, true, 100.0);
	cvar_customRoundTimeEnable = CreateConVar("sm_passtweaks_custom_timer", "0.0", "If enabled, enables custom round timer behavior. DOES NOT CHECK IF ROUND TIMER EXISTS!", FCVAR_ARCHIVE, true, 0.0, true, 1.0);
	cvar_customRoundTimeStarttime = CreateConVar("sm_passtweaks_custom_timer_starttime", "480.0", "Time, in seconds, the round starts with", FCVAR_ARCHIVE, true, 0.0, true, 3600.0);
	cvar_customRoundTimeMaxtime = CreateConVar("sm_passtweaks_custom_timer_maxtime", "600.0", "Max time, in seconds, the round time caps at with goal time", FCVAR_ARCHIVE, true, 0.0, true, 3600.0);
	cvar_customRoundTimeHaste = CreateConVar("sm_passtweaks_custom_timer_goal", "60.0", "Seconds added to the round time when scoring a normal goal", FCVAR_ARCHIVE, true, 0.0, true, 3600.0);
	cvar_customRoundTimeHasteBonus = CreateConVar("sm_passtweaks_custom_timer_goal_bonus", "120.0", "Seconds added to the round time when scoring a bonus goal", FCVAR_ARCHIVE, true, 0.0, true, 3600.0);
	
	Handle hGameConf = LoadGameConfigFile("tf2.passtweaks");
	if(hGameConf == INVALID_HANDLE) SetFailState("tf2.passtweaks.txt not found! is it in your gamedata folder?");
	
	hRefillThink = DHookCreate(0, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, RefillThink);
	DHookSetFromConf(hRefillThink, hGameConf, SDKConf_Virtual, "CObjectDispenser::RefillThink");
	
	hHealRate = DHookCreate(0, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, GetHealRate);
	DHookSetFromConf(hHealRate, hGameConf, SDKConf_Virtual, "CObjectDispenser::GetHealRate");
	DHookAddParam(hHealRate, HookParamType_CBaseEntity, _, DHookPass_ByRef); //is this param call... necessary...?
	
	delete hGameConf;
}

public void OnMapEnd() {
	passBall = -1;
	roundTimer = -1;
}

public void OnMapStart() {
	passBall = -1;
	//attempt to find passtime ball on map load (likely before entity creation though)
	passBall = FindEntityByClassname(-1, "passtime_ball");
	roundTimer = FindEntityByClassname(-1, "team_round_timer");
	if(passBall > 0) { SDKHook(passBall, SDKHook_OnTakeDamage, ballTakeDamage); }
}

public int SpawnBallDispenser(int ply) {
	if(!GetConVarBool(cvar_customDispenserEnable)) { return 0; }
	float plyPos[3];
	GetClientAbsOrigin(ply, plyPos);

	if(carrierDispenser > 0) { RemoveEntity(carrierDispenser); }
	carrierDispenser = CreateEntityByName("pd_dispenser");
	SetEntProp(carrierDispenser, Prop_Send, "m_iUpgradeLevel", 1);
	SetEntProp(carrierDispenser, Prop_Send, "m_iTeamNum", GetClientTeam(ply));
	SetEntProp(carrierDispenser, Prop_Send, "m_iState", 3);
	SetEntProp(carrierDispenser, Prop_Send, "m_fObjectFlags", 12); //default spawn flags are 4 but PD gives flags of 12, not sure what it changes
	SetEntPropVector(carrierDispenser, Prop_Send, "m_vecOrigin", plyPos);
	SetVariantString("!activator"); 
	AcceptEntityInput(carrierDispenser, "SetParent", ply, ply);
	
	DHookEntity(hRefillThink, false, carrierDispenser);
	DHookEntity(hHealRate, false, carrierDispenser);
	
	DispatchSpawn(carrierDispenser);
	ActivateEntity(carrierDispenser);
	
	SetEntPropEnt(carrierDispenser, Prop_Send, "m_hBuilder", ply); //setting the builder on a PD dispenser gives heal credit without being destructible
	
	SetEntProp(carrierDispenser, Prop_Send, "m_iAmmoMetal", 0);
	
	carrierDispenserTrigger = -1;
	while((carrierDispenserTrigger = FindEntityByClassname(carrierDispenserTrigger, "dispenser_touch_trigger")) != INVALID_ENT_REFERENCE) {
		if(GetEntPropEnt(carrierDispenserTrigger, Prop_Send, "m_hOwnerEntity") != carrierDispenser) { continue; }
		SetVariantString("!activator");
		AcceptEntityInput(carrierDispenserTrigger, "SetParent", carrierDispenser, carrierDispenser);
		break;
	}
	
	return carrierDispenser;
}

public Action passGrabEvent(Handle event, const char[] name, bool dontBreadcast) {
	if(GetConVarInt(cvar_removeTrailEnable) == 2) {
		CreateTimer(0.01, removeTrailTimer);
	}
	
	int ply = GetEventInt(event, "owner");
	SpawnBallDispenser(ply);
	
	//log formatting
	char steamid[16];
	char team[12];
	
	GetClientAuthId(ply, AuthId_Steam3, steamid, sizeof(steamid));
	
	if(GetClientTeam(ply) == 2) {
		team = "Red";
	} else if(GetClientTeam(ply) == 3) {
		team = "Blue";
	} else { //players shouldn't ever be able to grab the ball in spec but if they get manually spawned, maybe...
		team = "Spectator";
	}
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_get\" (firstcontact \"%i\")", ply, GetClientUserId(ply), steamid, team, firstGrab);
	firstGrab = 0;
	
	return Plugin_Continue;
}

public Action passDropEvent(Handle event, const char[] name, bool dontBreadcast) {
	if(carrierDispenser > 0 && IsValidEntity(carrierDispenser)) {
		RemoveEntity(carrierDispenser);
		carrierDispenser = 0;
	}
	if(carrierDispenserTrigger > 0 && IsValidEntity(carrierDispenserTrigger)) {
		RemoveEntity(carrierDispenserTrigger);
		carrierDispenserTrigger = 0;
	}
	
	return Plugin_Continue;
}

public void ballSpawnEvent(const char[] output, int caller, int activator, float delay) {
	if(GetConVarInt(cvar_removeTrailEnable) == 1) {
		CreateTimer(0.01, removeTrailTimer); //delay by a frame to call this after the sprite exists
	}
	firstGrab = 1;
}

public Action passStealEvent(Handle event, const char[] name, bool dontBreadcast) {
	int stealer = GetEventInt(event, "attacker");
	int carrier = GetEventInt(event, "victim");
	int powerBonus = GetConVarInt(cvar_powerballOnSteal);
	
	SpawnBallDispenser(stealer);
	
	if(powerBonus > 0 && GetClientTeam(stealer) != GetClientTeam(carrier)) { //increase the power meter on steal based on our cvar amount.
		int passLogicEnt = FindEntityByClassname(-1, "passtime_logic");
		SetEntProp(passLogicEnt, Prop_Send, "m_iBallPower", GetEntProp(passLogicEnt, Prop_Send, "m_iBallPower")+powerBonus);
	}
	
	//log formatting
	char steamid_stealer[16];
	char steamid_carrier[16];
	char team_stealer[12];
	char team_carrier[12];
	
	GetClientAuthId(stealer, AuthId_Steam3, steamid_stealer, sizeof(steamid_stealer));
	GetClientAuthId(carrier, AuthId_Steam3, steamid_carrier, sizeof(steamid_carrier));
	
	if(GetClientTeam(stealer) == 2) {
		team_stealer = "Red";
	} else if(GetClientTeam(stealer) == 3) {
		team_stealer = "Blue";
	} else {
		team_stealer = "Spectator";
	}
	
	if(GetClientTeam(carrier) == 2) {
		team_carrier = "Red";
	} else if(GetClientTeam(carrier) == 3) {
		team_carrier = "Blue";
	} else {
		team_carrier = "Spectator";
	}
	
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_ball_stolen\" against \"%N<%i><%s><%s>\"", stealer, GetClientUserId(stealer), steamid_stealer, team_stealer, carrier, GetClientUserId(carrier), steamid_carrier, team_carrier);
	
	return Plugin_Continue;
}


public Action passScoreEvent(Event event, const char[] name, bool dontBroadcast) {
	int scorer = GetEventInt(event, "scorer");
	int points = GetEventInt(event, "points");
	int assistor = GetEventInt(event, "assister");
	int bonusGoal = 0;
	bool eventChanged = false;
	
	//custom scoring, if enabled. all we do here is change the points on the killfeed event, scoring is done in posthook
	if(points == 1) { //assume 1 pt is a normal goal
		if(GetConVarBool(cvar_customScoreEnable)) {
			points = GetConVarInt(cvar_customScoreBase);
			int oldScore;
			int teamNum;
			if(GetClientTeam(scorer) == 3) { teamNum = 3; oldScore = GetEntProp(32, Prop_Send, "m_nFlagCaptures"); }
			else { teamNum = 2; oldScore = GetEntProp(31, Prop_Send, "m_nFlagCaptures"); }
			
			DataPack pack;
			CreateDataTimer(0.0, resetScoreTimer, pack);
			pack.WriteCell(teamNum);
			pack.WriteCell(oldScore+points);
			
			event.SetInt("points", points);
		}
	} else { //any other score (3) will be considered a bonus goal
		if(GetConVarBool(cvar_customScoreEnable)) {
			points = GetConVarInt(cvar_customScoreBonus);
			int oldScore;
			int teamNum;
			if(GetClientTeam(scorer) == 3) { teamNum = 3; oldScore = GetEntProp(32, Prop_Send, "m_nFlagCaptures"); }
			else { teamNum = 2; oldScore = GetEntProp(31, Prop_Send, "m_nFlagCaptures"); }
			
			DataPack pack;
			CreateDataTimer(0.0, resetScoreTimer, pack);
			pack.WriteCell(teamNum);
			pack.WriteCell(oldScore+points);
			
			event.SetInt("points", points);
		}
		bonusGoal = 1;
	}
	
	//round time, if haste mode is enabled
	if(GetConVarBool(cvar_customRoundTimeEnable)) {
		int timeToAdd;
		if(bonusGoal) {
			timeToAdd = GetConVarInt(cvar_customRoundTimeHasteBonus);
		} else {
			timeToAdd = GetConVarInt(cvar_customRoundTimeHaste);
		}
		
		if(timeToAdd > 0) {
			SetVariantInt(timeToAdd);
			AcceptEntityInput(roundTimer, "AddTime", -1, -1);
		}
	}
	
	//log formatting
	char steamid_scorer[16];
	char team_scorer[12];
	
	GetClientAuthId(scorer, AuthId_Steam3, steamid_scorer, sizeof(steamid_scorer));
	
	if(GetClientTeam(scorer) == 2) {
		team_scorer = "Red";
	} else if(GetClientTeam(scorer) == 3) {
		team_scorer = "Blue";
	} else {
		team_scorer = "Spectator";
	}
	
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_score\" (points \"%i\") (bonus \"%i\")", scorer, GetClientUserId(scorer), steamid_scorer, team_scorer, points, bonusGoal);
	
	if(assistor > 0) {
		char steamid_assistor[16];
		char team_assistor[12];
		
		GetClientAuthId(assistor, AuthId_Steam3, steamid_assistor, sizeof(steamid_assistor));
		
		if(GetClientTeam(assistor) == 2) {
			team_assistor = "Red";
		} else if(GetClientTeam(assistor) == 3) {
			team_assistor = "Blue";
		} else {
			team_assistor = "Spectator";
		}
		
		LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_score_assist\"", assistor, GetClientUserId(assistor), steamid_assistor, team_assistor);
	}
	return Plugin_Changed;
}

public Action resetScoreTimer(Handle timer, DataPack pack) {
	pack.Reset();
	int teamNum = pack.ReadCell();
	int scoreToSet = pack.ReadCell();
	
	if(teamNum == 3) {
		SetEntProp(32, Prop_Send, "m_nFlagCaptures", scoreToSet);
	}
	else {
		SetEntProp(31, Prop_Send, "m_nFlagCaptures", scoreToSet);
	}

	//if we're manually setting a lower score that would've won the game without editing, we have to spawn the ball manually
	//because passtime_logic thinks the game should be over.
	int passLogic = FindEntityByClassname(-1, "passtime_logic");
	SetVariantInt(0);
	if(passLogic > 0) { AcceptEntityInput(passLogic, "SpawnBall", -1, -1); }
	
	return Plugin_Handled;
}

public Action removeTrailTimer(Handle timer) {
	int spriteloop = -1;
	while((spriteloop = FindEntityByClassname(spriteloop, "env_spritetrail")) != INVALID_ENT_REFERENCE) {
		if(GetEntPropEnt(spriteloop, Prop_Send, "moveparent") == passBall) {
			SetEntPropFloat(spriteloop, Prop_Send, "m_flLifeTime", 0.0);
		}
	}
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if(StrEqual(classname, "passtime_ball")) {
		passBall = entity;
		SDKHook(entity, SDKHook_OnTakeDamage, ballTakeDamage);
	}
}

public Action catchBallEvent(Handle event, const char[] name, bool dontBroadcast) {
	int thrower = GetEventInt(event, "passer");
	int catcher = GetEventInt(event, "catcher");
	float dist = GetEventFloat(event, "dist");
	float duration = GetEventFloat(event, "duration");
	int passLogicEnt = FindEntityByClassname(-1, "passtime_logic");
	int powerPercentage = GetEntProp(passLogicEnt, Prop_Send, "m_iBallPower");
	
	int intercept = true;
	
	if(GetClientTeam(thrower) == GetClientTeam(catcher)) {
		intercept = false;
		if(GetConVarBool(cvar_blockInterceptEnable)) {
			DataPack pack;
			catchDataTimer = CreateDataTimer(0.01, resetBar, pack);
			pack.WriteCell(passLogicEnt);
			pack.WriteCell(powerPercentage);
		}
	}
	
	SpawnBallDispenser(catcher);
	
	//log formatting
	char steamid_thrower[16];
	char steamid_catcher[16];
	char team_thrower[12];
	char team_catcher[12];
	
	GetClientAuthId(thrower, AuthId_Steam3, steamid_thrower, sizeof(steamid_thrower));
	GetClientAuthId(catcher, AuthId_Steam3, steamid_catcher, sizeof(steamid_catcher));
	
	if(GetClientTeam(thrower) == 2) {
		team_thrower = "Red";
	} else if(GetClientTeam(thrower) == 3) {
		team_thrower = "Blue";
	} else {
		team_thrower = "Spectator";
	}
	
	if(GetClientTeam(catcher) == 2) {
		team_catcher = "Red";
	} else if(GetClientTeam(catcher) == 3) {
		team_catcher = "Blue";
	} else { //if a player throws the ball then goes spec they can trigger this event as a spectator
		team_catcher = "Spectator";
	}
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_pass_caught\" against \"%N<%i><%s><%s>\" (interception \"%i\") (dist \"%.3f\") (duration \"%.3f\")", catcher, GetClientUserId(catcher), steamid_catcher, team_catcher, thrower, GetClientUserId(thrower), steamid_thrower, team_thrower, intercept, dist, duration);
	
	return Plugin_Continue;
}

public Action setupFinishEvent(Handle event, const char[] name, bool dontBroadcast) {
	if(!GetConVarBool(cvar_customRoundTimeEnable)) { return Plugin_Continue; }
	if(roundTimer == -1) { return Plugin_Continue; }
	
	CreateTimer(0.01, roundTimerTimer);
	
	return Plugin_Continue;
}

public Action roundTimerTimer(Handle timer) {
	SetVariantInt(GetConVarInt(cvar_customRoundTimeMaxtime));
	AcceptEntityInput(roundTimer, "SetMaxTime", -1, -1);
	
	SetVariantInt(GetConVarInt(cvar_customRoundTimeStarttime));
	AcceptEntityInput(roundTimer, "SetTime", -1, -1);
	
	return Plugin_Handled;
}

/* have to use a data timer here to delay the reset by a single frame.
** since events are hooked before, even when hooking post-event, setting it
** then effectively does nothing. annoying, but it works this way. \*/
public Action resetBar(Handle timer, DataPack pack) {
	pack.Reset();
	int passLogicEnt = pack.ReadCell();
	int powerPercentage = pack.ReadCell();
	
	SetEntProp(passLogicEnt, Prop_Send, "m_iBallPower", powerPercentage);
	
	delete catchDataTimer;
	
	return Plugin_Handled;
}
/* block vanilla RefillThink() to prevent metal generation if set via cvar
*/
public MRESReturn RefillThink(int dispenser, Handle hReturn, Handle hParams) {
	if(!GetConVarBool(cvar_customDispenserMetal)) {
		return MRES_Supercede; //do nothing, but stop original function from generating metal
	}
	return MRES_Handled;
}

/* hijack GetHealRate() to supplant our own custom heal rate onto the dispenser
*/
public MRESReturn GetHealRate(int dispenser, Handle hReturn, Handle hParams) {
	if(hReturn != INVALID_HANDLE) {
		DHookSetReturn(hReturn, GetConVarFloat(cvar_customDispenserHealRate));
		return MRES_Override;
	}
	return MRES_Handled;
}


/*
 block the ball from taking damage if below a certain threshold (defined by cvar)
 this prevents scouts and engies from pistol spamming and neutralizing the ball before it goes in
*/
Action ballTakeDamage(int ball, int& shooter, int& inflictor, float& damage, int& damagetype) {	
	if(!GetConVarBool(cvar_blockHitEnable)) { return Plugin_Continue; }
	if(damage >= GetConVarFloat(cvar_blockHitThreshold)) { return Plugin_Continue; }
	else { return Plugin_Stop; }
}

public void OnGameFrame() { //block mini-crits in pack mode if enabled
	if(passBall > 0 && GetConVarBool(cvar_blockMinicritEnable)) {
		int carrier = GetEntPropEnt(passBall, Prop_Send, "m_hCarrier");
		if(carrier > 0) { TF2_RemoveCondition(carrier, TFCond_PasstimePenaltyDebuff); }
	}
}
