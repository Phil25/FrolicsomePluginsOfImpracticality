#pragma semicolon 1


/****** I N C L U D E S *****/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <updater>
#include <friendly>
#include <friendlysimple>


/******* D E F I N E S ******/

#define PLUGIN_VERSION	"1.0.0"
#define FLAGS_CVARS		FCVAR_PLUGIN|FCVAR_NOTIFY

#define DESC_PLUGIN_ENABLED		"Enable Sawblade plugin"
#define DESC_SAWBLADE_MODE		"Set sawblade mode:\n0 - Still,\n1 - Moving (default)"
#define DESC_SAWBLADE_DAMAGE	"Set sawblade damage."
#define DESC_SAWBLADE_SPEED		"Set sawblade speed, when mode is 1."
#define DESC_SAWBLADE_LIFE		"Set sawblade lifetime, in seconds."
#define DESC_SAWBLADE_SIZE		"Set sawblade size. 1.0 = normal."

#define MODEL_SAW				"models/props_forest/sawblade_moving.mdl"
#define SOUND_SAW				"ambient/sawblade.wav"

#define SAW_LIMIT				144


/***** V A R I A B L E S ****/

bool	g_bPluginUpdater		= false;
bool	g_bPluginFriendly		= false;
bool	g_bPluginFriendlySimple	= false;

Handle	g_hSpawnedSaws = INVALID_HANDLE;
Handle	g_hSpawnedSaws[MAXPLAYERS+1]	= {null, ...};
int		g_iSawCount = 0;

char	g_sSawSpawn[3][PLATFORM_MAX_PATH] = {

	"physics/metal/sawblade_stick1.wav",
	"physics/metal/sawblade_stick2.wav",
	"physics/metal/sawblade_stick3.wav"

};
char	g_sSawHit[2][PLATFORM_MAX_PATH] = {

	"ambient/sawblade_impact1.wav",
	"ambient/sawblade_impact2.wav"

};


/***** C O N V A R S ****/

ConVar g_hCvarPluginEnabled;	bool	g_bCvarPluginEnabled	= true;
ConVar g_hCvarSawbladeMode;		int		g_iCvarSawbladeMode		= 1;
ConVar g_hCvarSawbladeDamage;	float	g_fCvarSawbladeDamage	= 640.0;
ConVar g_hCvarSawbladeSpeed;	int		g_iCvarSawbladeSpeed	= 256;
ConVar g_hCvarSawbladeLife;		float	g_fCvarSawbladeLife		= 8.0;
ConVar g_hCvarSawbladeSize;		float	g_fCvarSawbladeSize		= 1.0;



/********** I N F O *********/

public Plugin myinfo = {

	name		= "[TF2] Sawblade",
	author		= "Phil25",
	description	= "Spawns Sawmill-style sawblades.",
	version		= PLUGIN_VERSION

};



			//*************************//
			//----  G E N E R A L  ----//
			//*************************//

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrorSize){

	char sGame[32]; sGame[0] = '\0';
	GetGameFolderName(sGame, sizeof(sGame));
	if(!StrEqual(sGame, "tf")){

		Format(sError, iErrorSize, "This plugin only works for Team Fortress 2.");
		return APLRes_Failure;

	}

	RegPluginLibrary("Sawblade");

	return APLRes_Success;

}

public void OnPluginStart(){


		//-----[ Setup ]-----//
	LoadTranslations("common.phrases.txt");

		//-----[ ConVars ]-----//
	CreateConVar("sm_sawblade_version", PLUGIN_VERSION, "Current Sawblade Version", FLAGS_CVARS|FCVAR_DONTRECORD|FCVAR_SPONLY);

	g_hCvarPluginEnabled	= CreateConVar("sm_sawblade_enabled",	"1",	DESC_PLUGIN_ENABLED,	FLAGS_CVARS, true, 0.0, true, 1.0);
	g_hCvarSawbladeMode		= CreateConVar("sm_sawblade_mode",		"1",	DESC_SAWBLADE_MODE,		FLAGS_CVARS, true, 0.0, true, 1.0);
	g_hCvarSawbladeDamage	= CreateConVar("sm_sawblade_damage",	"640",	DESC_SAWBLADE_DAMAGE,	FLAGS_CVARS);
	g_hCvarSawbladeSpeed	= CreateConVar("sm_sawblade_speed",		"256",	DESC_SAWBLADE_SPEED,	FLAGS_CVARS);
	g_hCvarSawbladeLife		= CreateConVar("sm_sawblade_life",		"0.0",	DESC_SAWBLADE_LIFE,		FLAGS_CVARS, true, 0.0);
	g_hCvarSawbladeSize		= CreateConVar("sm_sawblade_size",		"1.0",	DESC_SAWBLADE_SIZE,		FLAGS_CVARS, true, 0.1);
	

		//-----[ ConVars Hooking & Setting ]-----//
	g_hCvarPluginEnabled.AddChangeHook	(ConVarChange_Enabled	);	g_bCvarPluginEnabled	= g_hCvarPluginEnabled.BoolValue;
	g_hCvarSawbladeMode.AddChangeHook	(ConVarChange_Mode		);	g_iCvarSawbladeMode		= g_hCvarSawbladeMode.IntValue;
	g_hCvarSawbladeDamage.AddChangeHook	(ConVarChange_Damage	);	g_fCvarSawbladeDamage	= g_hCvarSawbladeDamage.FloatValue;
	g_hCvarSawbladeSpeed.AddChangeHook	(ConVarChange_Speed		);	g_iCvarSawbladeSpeed	= g_hCvarSawbladeSpeed.IntValue;
	g_hCvarSawbladeLife.AddChangeHook	(ConVarChange_Life		);	g_fCvarSawbladeLife		= g_hCvarSawbladeLife.FloatValue;
	g_hCvarSawbladeSize.AddChangeHook	(ConVarChange_Size		);	g_fCvarSawbladeSize		= g_hCvarSawbladeSize.FloatValue;


		//-----[ Commands ]-----//
	RegAdminCmd("sm_sawblade", Command_Sawblade, ADMFLAG_SLAY, "Spawn a sawblade. First argument overrides the mode.");
	RegAdminCmd("sm_sawtower", Command_Sawtower, ADMFLAG_SLAY, "Spawn a tower of saws. First argument overrides the mode.");
	RegAdminCmd("sm_sawball", Command_Sawball, ADMFLAG_SLAY, "Spawn a ball of saws. First argument overrides the mode.");
	RegAdminCmd("sm_sawcircle", Command_Sawcircle, ADMFLAG_SLAY, "Spawn a circle of saws. First argument overrides the mode.");
	
	RegAdminCmd("sm_clearsaw", Command_ClearSaws, ADMFLAG_SLAY, "Clear all the saws.");
	RegAdminCmd("sm_clearsaws", Command_ClearSaws, ADMFLAG_SLAY, "Clear all the saws.");
	
	RegAdminCmd("sm_clearmysaw", Command_ClearMySaws, ADMFLAG_SLAY, "Clear your saws.");
	RegAdminCmd("sm_clearmysaws", Command_ClearMySaws, ADMFLAG_SLAY, "Clear your saws.");
	
	
		//-----[ Misc ]-----//
	for(int i = 1; i <= MaxClients; i++)
		g_hSpawnedSaws[i] = CreateArray();

}

public void OnMapStart(){

	PrecacheModel(MODEL_SAW);
	PrecacheSound(SOUND_SAW);
	
	for(int i = 0; i < 3; i++)
		PrecacheSound(g_sSawSpawn[i]);
	
	for(int i = 0; i < 2; i++)
		PrecacheSound(g_sSawHit[i]);

	for(int i = 1; i <= MaxClients; i++)
		ClearArray(g_hSpawnedSaws[i]);
	
	g_iSawCount = 0;

}

public void OnClientDisconnect(int client){

	int iSize = GetArraySize(g_hSpawnedSaws[client]);
	if(iSize == 0)
		return;
	
	int iEnt = 0;
	for(int i = 0; i < iSize; i++){
	
		iEnt = EntRefToEntIndex(GetArrayCell(g_hSpawnedSaws[client], i));
		if(IsValidEntity(iEnt))
			AcceptEntityInput(iEnt, "Kill");
	
	}

	ClearArray(g_hSpawnedSaws[client]);

}

public void OnPluginEnd(){

	int iSize = 0, iEnt = 0;
	for(int i = 1; i <= MaxClients; i++){
	
		iSize = GetArraySize(g_hSpawnedSaws[i]);
		if(iSize == 0)
			continue;
		
		for(int j = 0; j < iSize; j++){
		
			iEnt = EntRefToEntIndex(GetArrayCell(g_hSpawnedSaws[i], j));
			if(!IsValidEntity(iEnt))
				continue;
			
			AcceptEntityInput(iEnt, "Kill");
			g_iSawCount--;
		
		}

		ClearArray(g_hSpawnedSaws[i]);
	
	}

}



			//*************************//
			//----  P L U G I N S  ----//
			//*************************//

public void OnAllPluginsLoaded(){
	
	g_bPluginUpdater		= LibraryExists("updater");
	g_bPluginFriendly		= LibraryExists("[TF2] Friendly Mode");
	g_bPluginFriendlySimple	= LibraryExists("Friendly Simple");

	//if(g_bPluginUpdater)
	//	Updater_AddPlugin(UPDATE_URL);

}

public void OnLibraryAdded(const char[] sLibName){

	if(StrEqual(sLibName, "updater"))
		g_bPluginUpdater = true;

	if(StrEqual(sLibName, "[TF2] Friendly Mode"))
		g_bPluginFriendly = true;

	if(StrEqual(sLibName, "Friendly Simple"))
		g_bPluginFriendlySimple = true;

	//if(g_bPluginUpdater)
	//	Updater_AddPlugin(UPDATE_URL);

}

public void OnLibraryRemoved(const char[] sLibName){

	if(StrEqual(sLibName, "updater"))
		g_bPluginUpdater = false;

	if(StrEqual(sLibName, "[TF2] Friendly Mode"))
		g_bPluginFriendly = false;

	if(StrEqual(sLibName, "Friendly Simple"))
		g_bPluginFriendlySimple = false;

}



			//***********************//
			//----  C O N V A R  ----//
			//***********************//

public int ConVarChange_Enabled(Handle hCvar, const char[] sOld, const char[] sNew){

	g_bCvarPluginEnabled = view_as<bool>(StringToInt(sNew));

}

public int ConVarChange_Mode(Handle hCvar, const char[] sOld, const char[] sNew){

	g_iCvarSawbladeMode = StringToInt(sNew);

}

public int ConVarChange_Damage(Handle hCvar, const char[] sOld, const char[] sNew){

	g_fCvarSawbladeDamage = StringToFloat(sNew);

}

public int ConVarChange_Speed(Handle hCvar, const char[] sOld, const char[] sNew){

	g_iCvarSawbladeSpeed = StringToInt(sNew);

}

public int ConVarChange_Life(Handle hCvar, const char[] sOld, const char[] sNew){

	g_fCvarSawbladeLife = StringToFloat(sNew);

}

public int ConVarChange_Size(Handle hCvar, const char[] sOld, const char[] sNew){

	g_fCvarSawbladeSize = StringToFloat(sNew);

}



			//***************************//
			//----  C O M M A N D S  ----//
			//***************************//

public Action Command_Sawblade(int client, int args){

	if(!g_bCvarPluginEnabled){
	
		ReplyToCommand(client, "[SM] Sawblade is disabled at this moment.");
		return Plugin_Handled;
	
	}

	if(client == 0){
	
		ReplyToCommand(client, "[SM] This command works only in game.");
		return Plugin_Handled;
	
	}
	
	if(g_iSawCount +1 > SAW_LIMIT){
	
		PrintToChat(client, "\x01[SM] The amount of saws has reached a limit. Please use \x03sm_clearsaws\x01.");
		return Plugin_Handled;
	
	}

	int iMode = g_iCvarSawbladeMode;
	if(args > 0){
	
		char sMode[8];
		GetCmdArg(1, sMode, 8);
		iMode = StringToInt(sMode);
	
	}
	
	float fPos[3];
	if(GetClientLookPosition(client, fPos)){
	
		float fAng[3];
		GetClientEyeAngles(client, fAng);
	
		fPos[2] += 32.0;
		SpawnSaw(client, fPos, fAng[1], iMode);
	
	}else
		ReplyToCommand(client, "[SM] Unable to find proper look-position.");
	
	return Plugin_Handled;

}

public Action Command_Sawtower(int client, int args){

	if(!g_bCvarPluginEnabled){
	
		ReplyToCommand(client, "[SM] Sawblade is disabled at this moment.");
		return Plugin_Handled;
	
	}

	if(client == 0){
	
		ReplyToCommand(client, "[SM] This command works only in game.");
		return Plugin_Handled;
	
	}
	
	if(g_iSawCount +36 > SAW_LIMIT){
	
		PrintToChat(client, "\x01[SM] The amount of saws has reached a limit. Please use \x03sm_clearsaws\x01.");
		return Plugin_Handled;
	
	}

	int iMode = g_iCvarSawbladeMode;
	if(args > 0){
	
		char sMode[8];
		GetCmdArg(1, sMode, 8);
		iMode = StringToInt(sMode);
	
	}
	
	float fPos[3];
	if(GetClientLookPosition(client, fPos)){
	
		float fAng[3];
		GetClientEyeAngles(client, fAng);
	
		for(int i = 0; i < 36; i++){
		
			fPos[2] += 32.0;
			SpawnSaw(client, fPos, float(10*i), iMode);
		
		}
	
	}else
		ReplyToCommand(client, "[SM] Unable to find proper look-position.");
	
	return Plugin_Handled;

}

public Action Command_Sawball(int client, int args){

	if(!g_bCvarPluginEnabled){
	
		ReplyToCommand(client, "[SM] Sawblade is disabled at this moment.");
		return Plugin_Handled;
	
	}

	if(client == 0){
	
		ReplyToCommand(client, "[SM] This command works only in game.");
		return Plugin_Handled;
	
	}
	
	if(g_iSawCount +36 > SAW_LIMIT){
	
		PrintToChat(client, "\x01[SM] The amount of saws has reached a limit. Please use \x03sm_clearsaws\x01.");
		return Plugin_Handled;
	
	}

	int iMode = g_iCvarSawbladeMode;
	if(args > 0){
	
		char sMode[8];
		GetCmdArg(1, sMode, 8);
		iMode = StringToInt(sMode);
	
	}
	
	float fPos[3];
	if(GetClientLookPosition(client, fPos)){
	
		float fAng[3];
		GetClientEyeAngles(client, fAng);
	
		fPos[2] += 32.0;
		for(int i = 0; i < 36; i++)
			SpawnSaw(client, fPos, float(10*i), iMode);
	
	}else
		ReplyToCommand(client, "[SM] Unable to find proper look-position.");
	
	return Plugin_Handled;

}

public Action Command_Sawcircle(int client, int args){

	if(!g_bCvarPluginEnabled){
	
		ReplyToCommand(client, "[SM] Sawblade is disabled at this moment.");
		return Plugin_Handled;
	
	}

	if(client == 0){
	
		ReplyToCommand(client, "[SM] This command works only in game.");
		return Plugin_Handled;
	
	}
	
	if(g_iSawCount +72 > SAW_LIMIT){
	
		PrintToChat(client, "\x01[SM] Limit reached; please use \x03sm_clearsaws\x01 or \x03sm_clearmysaws\x01.");
		return Plugin_Handled;
	
	}

	int iMode = g_iCvarSawbladeMode;
	if(args > 0){
	
		char sMode[8];
		GetCmdArg(1, sMode, 8);
		iMode = StringToInt(sMode);
	
	}
	
	float fPos[3];
	if(GetClientLookPosition(client, fPos)){
	
		float fAng[3];
		GetClientEyeAngles(client, fAng);
		
		fPos[0] -= 256.0;
		fPos[2] += 32.0;
		float fValue;
		for(int i = 0; i < 72; i++){
		
			fValue = float(10*i);
			fPos[0] += 512*Cosine(fValue);
			fPos[1] += 512*Sine(fValue);
			
			SpawnSaw(client, fPos, fValue, iMode);
		
		}
	
	}else
		ReplyToCommand(client, "[SM] Unable to find proper look-position.");
	
	return Plugin_Handled;

}

public Action Command_ClearSaws(int client, int args){

	if(!g_bCvarPluginEnabled){
	
		ReplyToCommand(client, "[SM] Sawblade is disabled at this moment.");
		return Plugin_Handled;
	
	}
	
	OnPluginEnd();
	g_iSawCount = 0;
	
	return Plugin_Handled;

}

public Action Command_ClearMySaws(int client, int args){

	if(!g_bCvarPluginEnabled){
	
		ReplyToCommand(client, "[SM] Sawblade is disabled at this moment.");
		return Plugin_Handled;
	
	}
	
	OnClientDisconnect(client);
	
	return Plugin_Handled;

}



			//*************************************//
			//----  F U N C T I O N A L I T Y  ----//
			//*************************************//

int SpawnSaw(int iOwner, float fPos[3], float fAng, int iMode=1){

	int iSaw = CreateEntityByName("prop_dynamic");
	if(!IsValidEntity(iSaw))
		return 0;
	
	//Set model and solidity of the saw
	SetEntityModel(iSaw, MODEL_SAW);
	DispatchKeyValue(iSaw, "Solid", "6");
	
	//Set saw's angles relative to client view
	float fSawAngles[3];
	fSawAngles[1] = fAng;
	DispatchKeyValueVector(iSaw, "angles", fSawAngles);
	
	//Spawn the dreadful thing
	DispatchSpawn(iSaw);
	
	//Edit the scale, if set
	if(g_fCvarSawbladeSize != 1.0)
		SetEntPropFloat(iSaw, Prop_Send, "m_flModelScale", g_fCvarSawbladeSize);
	
	//Set default animation
	SetVariantString("idle");
	AcceptEntityInput(iSaw, "SetAnimation");
	
	//Set the starting position
	TeleportEntity(iSaw, fPos, NULL_VECTOR, NULL_VECTOR);
	
	//Hook touch
	SDKHook(iSaw, SDKHook_StartTouchPost, OnSawTouch);
	
	//Add saw's reference to the array of the specific client
	int iSawRef = EntIndexToEntRef(iSaw);
	PushArrayCell(g_hSpawnedSaws[iOwner], iSawRef);
	
	if(g_fCvarSawbladeLife != 0.0)
		CreateTimer(g_fCvarSawbladeLife, Timer_DestroySawBlade, iSawRef);
	
	EmitSoundToAll(g_sSawSpawn[GetRandomInt(0, 2)], iSaw);
	
	g_iSawCount++;
	return iSaw;

}

public void OnSawTouch(int iSaw, client){

	if(client < 1 || client > MaxClients)
		return;
	
	if(IsPlayerFriendly(client))
		return;

	float fSawPos[3], fClientPos[3];
	GetClientAbsOrigin(client, fClientPos);
	GetEntPropVector(iSaw, Prop_Send, "m_vecOrigin", fSawPos);
	
	if(GetVectorDistance(fClientPos, fSawPos, true) < 7600.0)
		return;
	
	//SDKHooks_TakeDamage(client, iSaw, GetSawOwner(iSaw), g_fCvarSawbladeDamage, DMG_NERVEGAS);
	SDKHooks_TakeDamage(client, iSaw, iSaw, g_fCvarSawbladeDamage, DMG_NERVEGAS);
	EmitSoundToAll(g_sSawHit[GetRandomInt(0, 1)], iSaw);
	SetEntProp(iSaw, Prop_Send, "m_nSkin", 1);
	
	CreateTimer(1.0, Timer_ClearBlood, EntIndexToEntRef(CreateBlood(fClientPos)));

}



			//***********************//
			//----  T I M E R S  ----//
			//***********************//

public Action Timer_DestroySawBlade(Handle hTimer, int iSawRef){

	int iIndex = -1;
	for(int i = 1; i <= MaxClients; i++){
	
		if(GetArraySize(g_hSpawnedSaws[i]) == 0)
			continue;
		
		iIndex = FindValueInArray(g_hSpawnedSaws[i], iSawRef);
		if(iIndex > -1)
			RemoveFromArray(g_hSpawnedSaws[i], iIndex);
	
	}

	int iSaw = EntRefToEntIndex(iSawRef);
	
	if(IsValidEntity(iSaw)){
	
		AcceptEntityInput(iSaw, "Kill");
		g_iSawCount--;
	
	}
	
	return Plugin_Stop;

}

public Action Timer_ClearBlood(Handle hTimer, int iBloodRef){
	
	int iBlood = EntRefToEntIndex(iBloodRef);
	
	if(IsValidEntity(iBlood))
		AcceptEntityInput(iBlood, "Kill");

}



			//***********************//
			//----  S T O C K S  ----//
			//***********************//

stock bool GetClientLookPosition(int client, float fPosition[3]){

	float fPos[3], fAng[3];
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAng);

	Handle hTrace = TR_TraceRayFilterEx(fPos, fAng, MASK_SHOT, RayType_Infinite, TraceFilterIgnorePlayers, client);
	if(hTrace != INVALID_HANDLE && TR_DidHit(hTrace)){

		TR_GetEndPosition(fPosition, hTrace);
		return true;

	}

	return false;

}

public bool TraceFilterIgnorePlayers(int iEntity, int iContentsMask, any aData){

	if(iEntity >= 1 && iEntity <= MaxClients)
		return false;

	return true;

}

stock int GetSawOwner(int iSaw){

	int iSawRef = EntIndexToEntRef(iSaw);
	for(int i = 1; i <= MaxClients; i++){
	
		if(GetArraySize(g_hSpawnedSaws[i]) == 0)
			continue;
		
		if(FindValueInArray(g_hSpawnedSaws[i], iSawRef) > -1)
			return i;
	
	}

	return iSaw;

}

stock int CreateBlood(float fPos[3]){

	int iParticle = CreateEntityByName("info_particle_system");
	if(!IsValidEdict(iParticle))
		return 0;
	
	TeleportEntity(iParticle, fPos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(iParticle, "effect_name", "env_sawblood");
	
	DispatchSpawn(iParticle);
	ActivateEntity(iParticle);
	AcceptEntityInput(iParticle, "Start");

	return iParticle;

}

stock bool IsPlayerFriendly(int client){

	if(g_bPluginFriendly)
		if(TF2Friendly_IsFriendly(client))
			return true;

	if(g_bPluginFriendlySimple)
		if(FriendlySimple_IsFriendly(client))
			return true;

	return false;

}