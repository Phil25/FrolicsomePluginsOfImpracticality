#pragma semicolon 1


#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>


#define GIB_COUNT	6
#define SOUND_GORE	"physics/flesh/flesh_bloody_break.wav"


bool g_bBerserk[MAXPLAYERS+1] = {false, ...};
char g_sAction[3][] = {"Toggled", "Disabled", "Enabled"};
char g_sGibName[9][] = {

	"scout", "soldier", "pyro",
	"demo", "heavy", "engineer",
	"medic", "sniper", "spy",

};


public Plugin myinfo = {

	name = "Berserk",
	author = "Phil25",
	description = "Rip & Tear"

};


public void OnPluginStart				(){

	LoadTranslations("common.phrases");

	HookEvent("player_death", Event_PlayerDeath);

	RegAdminCmd("sm_berserk", Command_Berserk, ADMFLAG_SLAY);

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPutInServer(i);

}

public void OnMapStart					(){

	PrecacheSound(SOUND_GORE);

}

public void OnClientPutInServer			(int client){

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

}

public Action Command_Berserk			(int client, int args){

	char sTrg[32], sArg[32];
	switch(args){
	
		case 0:{
		
			sTrg = "@me";
			sArg = "-1";
		
		}
	
		case 1:{
		
			GetCmdArg(1, sTrg, 32);
			sArg = "-1";
		
		}
	
		default:{
		
			GetCmdArg(1, sTrg, 32);
			GetCmdArg(2, sArg, 32);
		
		}
	
	}

	char sTrgName[MAX_TARGET_LENGTH];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	int iDir = StringToInt(sArg);
	for(int i = 0; i < iTrgCount; i++)
		SetBerserk(aTrgList[i], iDir);

	ReplyToCommand(client, "[SM] %s Berserk on %d player%s", g_sAction[iDir +1], iTrgCount, iTrgCount == 1 ? "" : "s");
	return Plugin_Handled;

}

void SetBerserk							(int client, int iDir){

	switch(iDir){
	
		case 0:
			g_bBerserk[client] = false;
	
		case 1:
			g_bBerserk[client] = true;
	
		default:
			g_bBerserk[client] = !g_bBerserk[client];
	
	}

	if(g_bBerserk[client])
		OnBerserkEnabled(client);

	else
		OnBerserkDisabled(client);

}

void OnBerserkEnabled					(int client){

	PrintToChat(client, "\x01[SM] You've gone \x07dd2222BERSERK\x01!");

	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);

	int iWeapon = GetPlayerWeaponSlot(client, 2);
	if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);

	TF2_RemoveWeaponSlot(client, 3);
	TF2_RemoveWeaponSlot(client, 4);

}

void OnBerserkDisabled					(int client){

	PrintToChat(client, "\x01[SM] You're no longer berserk.");
	TF2_RegeneratePlayer(client);

}

public void OnClientDisconnect			(int client){

	g_bBerserk[client] = false;

}


public Action TF2_CalcIsAttackCritical	(int client, int iWeap, char[] sWeaponName, bool &bResult){

	if(!g_bBerserk[client])
		return Plugin_Continue;

	bResult = false;
	return Plugin_Changed;

}

public Action OnTakeDamage				(int client, int &iAtk, int &iInflictor, float &fDmg, int &iDmgType){

	if(!(1 <= iAtk <= MaxClients))
		return Plugin_Continue;

	if(g_bBerserk[iAtk]){

		fDmg = 666.0;
		return Plugin_Changed;
	
	}

	if(g_bBerserk[client]){
	
		fDmg /= 3.0;
		return Plugin_Changed;
	
	}

	return Plugin_Continue;

}

public Action Event_PlayerDeath			(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(client == 0)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(attacker == 0)
		return Plugin_Continue;

	if(g_bBerserk[attacker])
		RipAndTear(client, attacker);

	return Plugin_Continue;

}

void RipAndTear							(int client, int atk){

	RequestFrame(RipAndTear_NextFrame, GetClientSerial(client));

	for(int i = 0; i < 5; i++)
		EmitSoundToAll(SOUND_GORE, client);

	int iRagdoll = CreateEntityByName("tf_ragdoll");
	if(iRagdoll <= MaxClients || !IsValidEntity(iRagdoll))
		return;

	float fPos[3], fPos2[3], fAng[3], fVel[3];
	GetClientAbsOrigin(client, fPos);
	GetClientAbsOrigin(atk, fPos2);
	GetClientAbsAngles(client, fAng);
	TFClassType Class = TF2_GetPlayerClass(client);

	MakeVectorFromPoints(fPos2, fPos, fVel);
	NormalizeVector(fVel, fVel);
	ScaleVector(fVel, 256.0);

	for(int i = 1; i <= GIB_COUNT; i++)
		SpawnGib(fPos, fAng, fVel, Class, i);

	for(int i = 1; i <= 4; i++)
		SpawnGib(fPos, fAng, fVel, Class, i);

	for(int i = 0; i < 2; i++)
		CreateParticle(fPos, "tfc_sniper_mist", 16.0);

	//blood_impact_backscatter_ring
	//blood_impact_backscatter
	//blood_impact_red_01
	//env_sawblood
	//tfc_sniper_mist

}

public void RipAndTear_NextFrame		(int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return;

	int iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if(iRagdoll > MaxClients && IsValidEntity(iRagdoll))
		AcceptEntityInput(iRagdoll, "Kill");

}

void SpawnGib							(float fPos[3], float fAng[3], float fVel[3], TFClassType Class, int iGibCount){

	int iGib = CreateEntityByName("prop_physics");

	char sGibPath[PLATFORM_MAX_PATH];
	Format(sGibPath, PLATFORM_MAX_PATH, "models/player/gibs/%sgib00%d.mdl", g_sGibName[ClassToIndex(Class)], iGibCount);

	if(!IsModelPrecached(sGibPath))
		PrecacheModel(sGibPath);

	SetEntityModel(iGib, sGibPath);

	DispatchKeyValue(iGib, "modelscale", "1.2");
	SetEntProp(iGib, Prop_Send, "m_CollisionGroup", 1);
	SetEntProp(iGib, Prop_Data, "m_CollisionGroup", 1);

	DispatchSpawn(iGib);
	TeleportEntity(iGib, fPos, fAng, fVel);

	SetVariantString("OnUser1 !self:kill::5.0:1");
	AcceptEntityInput(iGib, "AddOutput");
	AcceptEntityInput(iGib, "FireUser1");

}

int ClassToIndex						(TFClassType Class){

	switch(Class){
	
		case TFClass_Scout:
			return 0;
	
		case TFClass_Soldier:
			return 1;
	
		case TFClass_Pyro:
			return 2;
	
		case TFClass_DemoMan:
			return 3;
	
		case TFClass_Heavy:
			return 4;
	
		case TFClass_Engineer:
			return 5;
	
		case TFClass_Medic:
			return 6;
	
		case TFClass_Sniper:
			return 7;
	
		case TFClass_Spy:
			return 8;
	
	}

	return 0;

}

stock void CreateParticle				(float fPos[3], const char[] strParticle, float fZOffset){

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