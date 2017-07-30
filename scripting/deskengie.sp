#pragma semicolon 1


#include <sdkhooks>
#include <sdktools>


#define PLUGIN_VERSION	"1.0"
#define ENGIE_LIMIT	100

#define SOUND_BILL	"mvm/mvm_money_pickup.wav"
#define MODEL_ENGIE	"models/player/engineer.mdl"

char g_sCmds[][] = {

	"tde", "deskengie", "deskengineer", "tinydeskengie", "tinydeskengineer"

};

int g_iEngies = 0;
Handle g_hEngies[MAXPLAYERS+1] = INVALID_HANDLE;


ConVar	g_hCvarSizeMin,
		g_hCvarSizeMax;

float	g_fSizeMin = 0.1,
		g_fSizeMax = 0.3;


public Plugin myinfo = {

	name		= "Tiny Desk Engineer",
	author		= "Phil25",
	description	= "Tiny Desk Engineers.",
	version		= PLUGIN_VERSION

};


public void OnPluginStart				(){

	LoadTranslations("common.phrases");

	for(int i = 1; i <= MaxClients; i++)
		g_hEngies[i] = CreateArray();

	int iCmdSize = sizeof(g_sCmds);
	char sCmd[64];
	for(int i = 0; i < iCmdSize; i++){
	
		Format(sCmd, 64, "sm_%s", g_sCmds[i]);
		RegAdminCmd(sCmd, Command_DeskEngie, ADMFLAG_SLAY, "Spawn Tiny Desk Engieer");
	
		Format(sCmd, 64, "sm_clear%s", g_sCmds[i]);
		RegAdminCmd(sCmd, Command_ClearDeskEngie, ADMFLAG_SLAY, "Clear Tiny Desk Engieers");
	
		Format(sCmd, 64, "sm_clearmy%s", g_sCmds[i]);
		RegAdminCmd(sCmd, Command_ClearClientDesk, ADMFLAG_SLAY, "Clear your Tiny Desk Engieers");
	
	}

	
	g_hCvarSizeMin = CreateConVar("sm_tde_min", "0.1", "Minimal Tiny Desk Engineer size", FCVAR_NOTIFY, true, 0.01);
	g_hCvarSizeMax = CreateConVar("sm_tde_max", "0.3", "Maximal Tiny Desk Engineer size", FCVAR_NOTIFY, true, 0.02);

	g_hCvarSizeMin.AddChangeHook(ConVarChange_SizeMin);
	g_hCvarSizeMax.AddChangeHook(ConVarChange_SizeMax);

	g_fSizeMin = g_hCvarSizeMin.FloatValue;
	g_fSizeMax = g_hCvarSizeMax.FloatValue;

}

public void OnMapStart					(){

	PrecacheSound(SOUND_BILL);
	PrecacheModel(MODEL_ENGIE);

}

public void OnClientDisconnect			(int client){

	RemoveClientEngies(client);

}

public void OnPluginEnd					(){

	RemoveAllEngies();

}


public int ConVarChange_SizeMin			(Handle hCvar, const char[] sOld, const char[] sNew){

	g_fSizeMin = StringToFloat(sNew);

}

public int ConVarChange_SizeMax			(Handle hCvar, const char[] sOld, const char[] sNew){

	g_fSizeMax = StringToFloat(sNew);

}


public Action Command_DeskEngie			(int client, int args){

	if(client == 0)
		ReplyToCommand(client, "[SM] This command can be used only in-game!");

	else
		SpawnEngie(client);

	return Plugin_Handled;

}

public Action Command_ClearDeskEngie	(int client, int args){

	RemoveAllEngies();
	ReplyToCommand(client, "[SM] Tiny Desk Engineers cleared!");

	return Plugin_Stop;

}

public Action Command_ClearClientDesk	(int client, int args){

	if(client == 0){
	
		ReplyToCommand(client, "[SM] This command can be used only in-game!");
		return Plugin_Handled;
	
	}

	RemoveClientEngies(client);
	ReplyToCommand(client, "[SM] Your Tiny Desk Engineers cleared!");

	return Plugin_Handled;

}


void SpawnEngie							(int client){

	if(g_iEngies >= ENGIE_LIMIT){
	
		PrintToChat(client, "[SM] Budget for Tiny Desk Engieers depleted.");
		return;
	
	}

	float fPos[3];
	if(!GetClientLookPosition(client, fPos)){
	
		PrintToChat(client, "[SM] Cannot place you Tiny Desk Engineer here.");
		return;
	
	}

	int iEngie = CreateEntityByName("prop_dynamic_override");
	if(iEngie <= MaxClients || !IsValidEntity(iEngie))
		return;

	SetEntPropEnt(iEngie, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropFloat(iEngie, Prop_Data, "m_flModelScale", g_fSizeMin > g_fSizeMax ? GetRandomFloat(g_fSizeMax, g_fSizeMin) : GetRandomFloat(g_fSizeMin, g_fSizeMax));
	SetEntityModel(iEngie, MODEL_ENGIE);

	SetVariantString("taunt_russian"); 
	AcceptEntityInput(iEngie, "SetAnimation");
	SetVariantString("taunt_russian"); 
	AcceptEntityInput(iEngie, "SetDefaultAnimation");

	PushArrayCell(g_hEngies[client], EntIndexToEntRef(iEngie));

	float fAng[3];
	GetClientAbsAngles(client, fAng);
	fAng[1] += 180.0;

	EmitSoundToAll(SOUND_BILL, client);
	PrintToChat(client, "\x07dd0000-$69.99\x01 for 1 \x03Tiny Desk Engineer\x01. [%d/%d]", ++g_iEngies, ENGIE_LIMIT);
	TeleportEntity(iEngie, fPos, fAng, NULL_VECTOR);

}

void RemoveAllEngies					(){

	for(int i = 1; i <= MaxClients; i++)
		RemoveClientEngies(i);

}

void RemoveClientEngies					(int client){

	int iEngies = GetArraySize(g_hEngies[client]);
	if(iEngies == 0)
		return;

	for(int i = 0; i < iEngies; i++)
		KillEnt(EntRefToEntIndex(GetArrayCell(g_hEngies[client], i)));

	g_iEngies -= iEngies;
	ResizeArray(g_hEngies[client], 0);

	EmitSoundToAll(SOUND_BILL, client);
	PrintToChat(client, "\x0700dd00+$%.2f\x01 for selling %d \x03Tiny Desk Engineer%s\x01.", iEngies *69.99, iEngies, iEngies == 1 ? "" : "s");

}

void KillEnt							(int iEnt){

	if(iEnt > MaxClients && IsValidEntity(iEnt))
		AcceptEntityInput(iEnt, "Kill");

}


stock void CreateParticle				(float fPos[3], const char[] strParticle, float fZOffset=0.0){

	int iParticle = CreateEntityByName("info_particle_system");
	if(!IsValidEdict(iParticle))
		return;

	fPos[2] += fZOffset;
	TeleportEntity(iParticle, fPos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(iParticle, "effect_name", strParticle);

	DispatchSpawn(iParticle);
	ActivateEntity(iParticle);
	AcceptEntityInput(iParticle, "Start");

	SetVariantString("OnUser1 !self:kill::4.0:1");
	AcceptEntityInput(iParticle, "AddOutput");
	AcceptEntityInput(iParticle, "FireUser1");

}

stock bool GetClientLookPosition		(int client, float fPosition[3]){

	float fPos[3], fAng[3];
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAng);

	Handle hTrace = TR_TraceRayFilterEx(fPos, fAng, MASK_SHOT, RayType_Infinite, TraceFilterIgnorePlayers, client);
	if(hTrace != INVALID_HANDLE && TR_DidHit(hTrace)){

		TR_GetEndPosition(fPosition, hTrace);
		delete hTrace;
		return true;

	}

	delete hTrace;
	return false;

}

public bool TraceFilterIgnorePlayers	(int iEntity, int iContentsMask, any data){

	if(iEntity >= 1 && iEntity <= MaxClients)
		return false;

	return true;

}