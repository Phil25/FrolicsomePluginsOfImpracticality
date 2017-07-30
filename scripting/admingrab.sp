

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <playerdata>

#define SOUND_GRAB	"ui/item_default_pickup.wav"
#define SOUND_TOSS	"ui/item_default_drop.wav"

#define THROW_FORCE		1000.0
#define GRAB_DISTANCE	150.0

#define LASERBEAM		"sprites/laserbeam.vmt"


public Plugin myinfo = {

	name = "Admin Grab",
	author = "Phil25",
	description = "Allows admins to grab players/entities."

};

int g_iGrabbed[MAXPLAYERS+1]	= {INVALID_ENT_REFERENCE, ...};
float g_fDistance[MAXPLAYERS+1]	= {150.0, ...};
int g_iBeam[MAXPLAYERS+1]		= {0, ...};
bool g_bInAttack[MAXPLAYERS+1]	= {false, ...};

int g_iGrabPoolSize = 0;
int g_iGrabPool[] = {
	48874109, //Phil
	156524502, //Uber
	90108395, //Fames
	185592723, //Rew
	198657264, //Bee
	158846632, //Gala
	67362746, //Rox
	167278159, //Fish
	134289050, //Fluffy
	197612672, //Sana
	//119366244, //Retro
	146803570, //Cubit
	136616071, //Mario
	//33626329, //Festive
	260286743, //Phanton
	381308940 //Psycho
};

char sSwoosh[4][64]				= {

	"passtime/projectile_swoosh2.wav",
	"passtime/projectile_swoosh3.wav",
	"passtime/projectile_swoosh4.wav",
	"passtime/projectile_swoosh5.wav"

};


//***********************//
//  -  G E N E R A L  -  //
//***********************//

public void OnPluginStart		(){

	LoadTranslations("common.phrases.txt");

	RegAdminCmd("sm_grab", Command_Grab, 0, "Grab an object.");
	RegAdminCmd("sm_brab", Command_Grab, 0, "Grab an object.");
	RegAdminCmd("sm_throw", Command_Throw, ADMFLAG_SLAY, "Throw an object.");

	HookEvent("player_death", Event_OnCancelGrab);
	HookEvent("player_spawn", Event_OnCancelGrab);
	HookEvent("player_team", Event_OnCancelGrab);

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPutInServer(i);

	g_iGrabPoolSize = sizeof(g_iGrabPool);

}

public void OnMapStart			(){

	for(int i = 1; i <= MaxClients; i++)
		g_iGrabbed[i] = INVALID_ENT_REFERENCE;

	for(int i = 0; i < 4; i++)
		PrecacheSound(sSwoosh[i]);

	PrecacheSound(SOUND_GRAB);
	PrecacheSound(SOUND_TOSS);
	PrecacheModel(LASERBEAM);

}

public void OnClientPutInServer	(int client){

	SDKHook(client, SDKHook_PreThink, Event_PreThink);

}

public void OnClientDisconnect	(int client){

	UnconnectBeam(client);
	g_iGrabbed[client] = INVALID_ENT_REFERENCE;

}



//*************************//
//  -  C O M M A N D S  -  //
//*************************//

public Action Command_Grab	(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;

	if(!HasGrabAccess(client))
		return Plugin_Handled;

	if(!IsClientGrabbing(client)){
	
		int iTarget = 0;
		if(args > 0){
		
			char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
			int	 aTrgList[MAXPLAYERS], iTrgCount;
			bool bNameMultiLang;
			GetCmdArg(1, sTrg, sizeof(sTrg));
		
			if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_ALIVE|COMMAND_FILTER_NO_MULTI, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0)
				ReplyToTargetError(client, iTrgCount);
			else
				iTarget = aTrgList[0];
		
		}
	
		GrabObject(client, iTarget);
	
	}else
		DropObject(client, view_as<bool>(GetClientButtons(client) & IN_ATTACK2));

	return Plugin_Handled;

}

public Action Command_Throw	(int client, int args){

	if(client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	if(IsClientGrabbing(client))
		DropObject(client, true);

	return Plugin_Handled;

}



//*********************//
//  -  E V E N T S  -  //
//*********************//

public void Event_OnCancelGrab	(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsValidClient(client))
		return;

	for(int i = 1; i <= MaxClients; i++)
		if(EntRefToEntIndex(g_iGrabbed[i] == client))
			g_iGrabbed[i] = INVALID_ENT_REFERENCE;

	if(!IsClientGrabbing(client))
		return;

	UnconnectBeam(client);
	g_iGrabbed[client] = INVALID_ENT_REFERENCE;

	int iGrabbed = EntRefToEntIndex(g_iGrabbed[client]);
	if(iGrabbed != INVALID_ENT_REFERENCE && iGrabbed > MaxClients){
	
		char sClassname[13];
		GetEntityClassname(iGrabbed, sClassname, 13);
		if(StrEqual(sClassname, "prop_physics"))
			SetEntPropEnt(iGrabbed, Prop_Data, "m_hPhysicsAttacker", 0);
	
	}

}

public void Event_PreThink		(int client){

	if(!HasGrabAccess(client))
		return;

	int iGrabbed = EntRefToEntIndex(g_iGrabbed[client]);
	if(iGrabbed == INVALID_ENT_REFERENCE)
		return;

	float fView[3], fFwd[3], fPos[3], fVel[3];

	GetClientEyeAngles(client, fView);
	GetAngleVectors(fView, fFwd, NULL_VECTOR, NULL_VECTOR);
	GetClientEyePosition(client, fPos);

	fPos[0] += fFwd[0] *g_fDistance[client];
	fPos[1] += fFwd[1] *g_fDistance[client];
	fPos[2] += fFwd[2] *g_fDistance[client];

	GetEntPropVector(iGrabbed, Prop_Send, "m_vecOrigin", fFwd);

	SubtractVectors(fPos, fFwd, fVel);
	ScaleVector(fVel, 10.0);

	TeleportEntity(iGrabbed, NULL_VECTOR, NULL_VECTOR, fVel);

}

public Action OnPlayerRunCmd	(int client, int &iButtons){

	if(!HasGrabAccess(client))
		return Plugin_Continue;

	if(!IsClientGrabbing(client))
		return Plugin_Continue;

	if((iButtons & IN_ATTACK2) && !g_bInAttack[client])
		SetBeamColor(client, true);

	else if(!(iButtons & IN_ATTACK2) && g_bInAttack[client])
		SetBeamColor(client, false);

	return Plugin_Continue;

}



//*****************//
//  -  M A I N  -  //
//*****************//

void GrabObject		(int client, int iTarget=0){

	int iGrabbed = iTarget == 0 ? FindObjectByTrace(client) : iTarget;
	if(iGrabbed == 0)
		return;

	if(IsValidClient(iGrabbed)){
	
		if(!IsClientAdmin(client)){
		
			//if(!IsNonAdminGrab(client, iGrabbed))
			if(!IsNonAdminGrab(client, iGrabbed) || iTarget != 0)
				return;
		
		}
	
		if(PlayerData_BoolInBonus(iGrabbed)){
		
			PrintToChat(client, "[SM] Player is in Bonus.");
			return;
		
		}
	
	}

	if(iGrabbed > MaxClients){
	
		char sClassname[13];
		GetEntityClassname(iGrabbed, sClassname, 13);
		
		if(StrEqual(sClassname, "prop_physics")){
		
			int iGrabber = GetEntPropEnt(iGrabbed, Prop_Data, "m_hPhysicsAttacker");
			if(IsValidClient(iGrabber))
				return;
			
			SetEntPropEnt(iGrabbed, Prop_Data, "m_hPhysicsAttacker", client);
			AcceptEntityInput(iGrabbed, "EnableMotion");
		
		}
		
		SetEntityMoveType(iGrabbed, MOVETYPE_VPHYSICS);
	
	}else{
	
		SetEntityMoveType(iGrabbed, MOVETYPE_WALK);
		
		PrintHintText(client, "Grabbing %N.", iGrabbed);
		PrintHintText(iGrabbed, "%N is grabbing you!", client);
	
	}

	bool bInAttack = view_as<bool>(GetClientButtons(client) & IN_ATTACK2);
	if(bInAttack){
	
		float fPosGrabbed[3], fPosGrabbing[3];
		
		GetEntPropVector(iGrabbed, Prop_Send, "m_vecOrigin", fPosGrabbed);
		GetClientEyePosition(client, fPosGrabbing);
		
		g_fDistance[client] = GetVectorDistance(fPosGrabbed, fPosGrabbing);
	
	}else g_fDistance[client] = GRAB_DISTANCE;

	TeleportEntity(iGrabbed, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));

	g_iGrabbed[client] = EntIndexToEntRef(iGrabbed);

	EmitSoundToAll(SOUND_GRAB, client);

	if(g_iBeam[client] == 0)
		g_iBeam[client] = ConnectWithBeam(client, iGrabbed, bInAttack ? 255 : 64, bInAttack ? 64 : 255, 64);

}

void DropObject		(int client, bool bThrow){

	int iGrabbed = EntRefToEntIndex(g_iGrabbed[client]);
	if(bThrow && iGrabbed > 0){
	
		float fView[3], fFwd[3], fPos[3], fVel[3];
	
		GetClientEyeAngles(client, fView);
		GetAngleVectors(fView, fFwd, NULL_VECTOR, NULL_VECTOR);
		GetClientEyePosition(client, fPos);
	
		fPos[0]+=fFwd[0]*THROW_FORCE;
		fPos[1]+=fFwd[1]*THROW_FORCE;
		fPos[2]+=fFwd[2]*THROW_FORCE;
	
		GetEntPropVector(iGrabbed, Prop_Send, "m_vecOrigin", fFwd);
	
		SubtractVectors(fPos, fFwd, fVel);
		ScaleVector(fVel, 10.0);
	
		TeleportEntity(iGrabbed, NULL_VECTOR, NULL_VECTOR, fVel);
	
	}

	EmitSoundToAll(bThrow ? sSwoosh[GetRandomInt(0, 3)] : SOUND_TOSS, client);

	UnconnectBeam(client);
	g_iGrabbed[client] = INVALID_ENT_REFERENCE;

	if(iGrabbed <= MaxClients)
		return;

	char sClassname[13];
	GetEntityClassname(iGrabbed, sClassname, 13);
	if(StrEqual(sClassname, "prop_physics"))
		SetEntPropEnt(iGrabbed, Prop_Data, "m_hPhysicsAttacker", 0);

}

void SetBeamColor	(int client, bool bThrow){

	SetVariantString(bThrow ? "255" : "64");
	AcceptEntityInput(g_iBeam[client], "ColorRedValue");

	SetVariantString(bThrow ? "64" : "255");
	AcceptEntityInput(g_iBeam[client], "ColorGreenValue");

	g_bInAttack[client] = bThrow;

}



//*******************//
//  -  T R A C E  -  //
//*******************//

int FindObjectByTrace		(int client){

	float fPos[3], fAng[3];
	
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAng);
	
	TR_TraceRayFilter(fPos, fAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayFilter, client);

	return TR_GetEntityIndex(INVALID_HANDLE);

}

public bool TraceRayFilter	(int iEnt, int iMask, int iSelf){

	if(iEnt > 0 && iEnt <= MaxClients)
		return (IsPlayerAlive(iEnt) && iEnt != iSelf);
	
	else{
	
		char sClassname[13];
		return (GetEntityClassname(iEnt, sClassname, 13) && (StrEqual(sClassname, "prop_physics") || StrEqual(sClassname, "tf_dropped_weapon") || StrEqual(sClassname, "tf_ammo_pack") || !StrContains(sClassname, "tf_projectil")));
	
	}

}



//*********************//
//  -  S T O C K S  -  //
//*********************//

stock bool IsNonAdminGrab		(int iGrabber, int iGrabbed){

	return (IsIdInNonAdminPool(GetSteamAccountID(iGrabber)) && IsIdInNonAdminPool(GetSteamAccountID(iGrabbed)));

}

stock bool IsIdInNonAdminPool	(int iAccountId){

	for(int i = 0; i < g_iGrabPoolSize; i++)
		if(iAccountId == g_iGrabPool[i])
			return true;

	return false;

}

stock bool IsClientAdmin		(int client){

	return CheckCommandAccess(client, "", ADMFLAG_SLAY, true);

}

stock bool HasGrabAccess		(int client){

	return (CheckCommandAccess(client, "", ADMFLAG_SLAY, true) || IsIdInNonAdminPool(GetSteamAccountID(client)));

}

stock bool IsClientGrabbing		(int client){

	return (g_iGrabbed[client] != INVALID_ENT_REFERENCE);

}

stock int ConnectWithBeam		(int iEnt, int iEnt2, int iRed=255, int iGreen=255, int iBlue=255, float fStartWidth=1.0, float fEndWidth=1.0, float fAmp=1.35){

	int iBeam = CreateEntityByName("env_beam");
	
	if(iBeam <= MaxClients)
		return -1;
	
	if(!IsValidEntity(iBeam))
		return -1;
	
	SetEntityModel(iBeam, LASERBEAM);
	
	char sColor[16];
	Format(sColor, sizeof(sColor), "%d %d %d", iRed, iGreen, iBlue);
	
	DispatchKeyValue(iBeam, "rendercolor", sColor);
	DispatchKeyValue(iBeam, "life", "0");
	
	DispatchSpawn(iBeam);
	
	SetEntPropEnt(iBeam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(iEnt));
	SetEntPropEnt(iBeam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(iEnt2), 1);
	
	SetEntProp(iBeam, Prop_Send, "m_nNumBeamEnts", 2);
	SetEntProp(iBeam, Prop_Send, "m_nBeamType", 2);
	
	SetEntPropFloat(iBeam, Prop_Data, "m_fWidth", 1.0);
	SetEntPropFloat(iBeam, Prop_Data, "m_fEndWidth", 1.0);
	
	SetEntPropFloat(iBeam, Prop_Data, "m_fAmplitude", 1.35);
	
	SetVariantFloat(32.0);
	AcceptEntityInput(iBeam, "Amplitude");
	AcceptEntityInput(iBeam, "TurnOn");
	
	return iBeam;

}

stock void UnconnectBeam		(int client){

	if(g_iBeam[client] == 0)
		return;

	AcceptEntityInput(g_iBeam[client], "Kill");
	g_iBeam[client] = 0;

}

stock bool IsValidClient		(int client){

	return (client > 0 && client <= MaxClients && IsClientInGame(client));

}