#pragma semicolon 1


#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>


#define MODEL_FROK "models/props_2fort/frog.mdl"
#define MODEL_TIRE "models/player/gibs/gibs_tire.mdl"

#define WEAPON_COUNT 5
#define SOUND_COUNT 4
#define GIB_COUNT	6

#define SOUND_GORE	"physics/flesh/flesh_bloody_break.wav"
#define BOI_DAMAGE	45.0
#define SOUND_INTV	GetRandomFloat(1.5, 3.0)


bool g_bBoi[MAXPLAYERS+1] = {false, ...};
int	g_iFrog[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...},
	g_iTire[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};

char g_sAction[3][] = {"Toggled", "Disabled", "Enabled"};
char g_sCritters[SOUND_COUNT][] = {

	"ambient/levels/canals/critter1.wav",
	"ambient/levels/canals/critter2.wav",
	"ambient/levels/canals/critter3.wav",
	"ambient/levels/canals/critter5.wav"

};
char g_sGibName[9][] = {

	"scout", "soldier", "pyro",
	"demo", "heavy", "engineer",
	"medic", "sniper", "spy",

};


public Plugin myinfo = {

	name = "Frok Stickies",
	author = "Phil25",
	description = "Turns stickies into froks."

};


public void OnPluginStart		(){

	LoadTranslations("common.phrases");

	RegAdminCmd("sm_datboi", Command_DatBoi, ADMFLAG_SLAY);

	HookEvent("post_inventory_application", OnResupply, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath);

}

public void OnPluginEnd			(){

	for(int i = 1; i <= MaxClients; i++)
		OnClientDisconnect(i);

}

public void OnMapStart			(){

	PrecacheModel(MODEL_FROK);
	PrecacheModel(MODEL_TIRE);
	for(int i = 0; i < SOUND_COUNT; i++)
		PrecacheSound(g_sCritters[i]);

}

public void OnClientDisconnect	(int client){

	if(g_bBoi[client])
		SetBoi(client, 0);

}

public void OnResupply			(Handle hEvent, const char[] sEventName, bool bDontBroadcast){

	int iUserId = GetEventInt(hEvent, "userid"),
		client = GetClientOfUserId(iUserId);
	if(!g_bBoi[client])
		return;
	
	Show_Player(client, false);
	for(int i = 0; i < WEAPON_COUNT; i++)
		TF2_RemoveWeaponSlot(client, i);

}

public Action OnPlayerDeath		(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(client == 0)
		return Plugin_Continue;

	if(g_bBoi[client]){
	
		SetBoi(client, 0);
		return Plugin_Continue;
	
	}

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(attacker == 0)
		return Plugin_Continue;

	if(g_bBoi[attacker])
		RipAndTear(client, attacker);

	return Plugin_Continue;

}


public Action Command_DatBoi	(int client, int args){

	char sTrg[32] = "@me";
	if(args > 0)
		GetCmdArg(1, sTrg, 32);

	char sTrgName[MAX_TARGET_LENGTH];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	int		iDir	= -1;
	float	fTime	= 0.0;
	if(args > 1){
	
		char sDir[4];
		GetCmdArg(2, sDir, 4);
		iDir = StringToInt(sDir);
	
		if(args > 2){
		
			char sTime[8];
			GetCmdArg(3, sTime, 8);
			fTime = StringToFloat(sTime);
		
		}
	
	}

	for(int i = 0; i < iTrgCount; i++)
		SetBoi(aTrgList[i], iDir, fTime);

	ReplyToCommand(client, "[SM] %s Dat Boi on %d player%s", g_sAction[iDir +1], iTrgCount, iTrgCount == 1 ? "" : "s");
	return Plugin_Handled;

}

void SetBoi						(int client, int iDir, float fTime=0.0){

	switch(iDir){
	
		case 0:
			g_bBoi[client] = false;
	
		case 1:
			g_bBoi[client] = true;
	
		default:
			g_bBoi[client] = !g_bBoi[client];
	
	}

	RemoveBois(client);
	Show_Player(client, !g_bBoi[client]);

	if(g_bBoi[client]){
	
		SpawnBois(client);
		SDKHook(client, SDKHook_TouchPost, OnBoiTouch);
		SDKHook(client, SDKHook_OnTakeDamage, OnBoiTakeDamage);
	
		for(int i = 0; i < WEAPON_COUNT; i++)
			TF2_RemoveWeaponSlot(client, i);
	
		int iSerial = GetClientSerial(client);
		CreateTimer(SOUND_INTV, OnBoiSound, iSerial);
	
		if(fTime > 0.0)
			CreateTimer(fTime, OnDisableBoi, iSerial);
	
	}else{
	
		SDKUnhook(client, SDKHook_TouchPost, OnBoiTouch);
		SDKUnhook(client, SDKHook_OnTakeDamage, OnBoiTakeDamage);
	
		TF2_RegeneratePlayer(client);
	
	}

	SetVariantInt(view_as<int>(g_bBoi[client]));
	AcceptEntityInput(client, "SetForcedTauntCam");

}

public Action OnDisableBoi		(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(g_bBoi[client])
		SetBoi(client, 0);

	return Plugin_Stop;

}

void RemoveBois					(int client){

	KillEntRef(g_iFrog[client]);
	KillEntRef(g_iTire[client]);

	g_iFrog[client] = INVALID_ENT_REFERENCE;
	g_iTire[client] = INVALID_ENT_REFERENCE;

}

void SpawnBois					(int client){

	int iFrog = SpawnBoi(MODEL_FROK);
	int iTire = SpawnBoi(MODEL_TIRE);

	g_iFrog[client] = EntIndexToEntRef(iFrog);
	g_iTire[client] = EntIndexToEntRef(iTire);

}

void Show_Player				(int client, bool bShow){

	if(GetEntityRenderMode(client) == RENDER_NORMAL)
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);

	SetEntityAlpha(client, view_as<int>(bShow) *255);

	char sClass[24];
	for(int i = MaxClients+1; i < GetMaxEntities(); i++){
	
		if(!IsCorrectWearable(client, i, sClass, 24))
			continue;
	
		if(GetEntityRenderMode(i) == RENDER_NORMAL)
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
	
		SetEntityAlpha(i, view_as<int>(bShow) *255);
	
	}

}

int SpawnBoi					(const char[] sModel){

	int iBoi = CreateEntityByName("prop_dynamic");
	if(!IsValidEntity2(iBoi))
		return 0;

	SetEntityModel(iBoi, sModel);

	return iBoi;

}


public void OnGameFrame			(){

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientGameFrame(i);

}

void OnClientGameFrame			(int client){

	if(!g_bBoi[client])
		return;

	float fPos[3], fAng[3];
	GetClientAbsOrigin(client, fPos);
	GetClientAbsAngles(client, fAng);

	UpdateTirePos(client, fPos, fAng);
	UpdateFrogPos(client, fPos, fAng);

}

void UpdateFrogPos				(int client, float fClientPos[3], float fClientAng[3]){

	if(g_iFrog[client] == INVALID_ENT_REFERENCE)
		return;

	int iFrog = EntRefToEntIndex(g_iFrog[client]);

	float fPos[3];
	CopyArray(fPos, fClientPos);
	fPos[2] += 26.0;

	TeleportEntity(iFrog, fPos, fClientAng, NULL_VECTOR);

}

void UpdateTirePos				(int client, float fClientPos[3], float fClientAng[3]){

	if(g_iTire[client] == INVALID_ENT_REFERENCE)
		return;

	int iTire = EntRefToEntIndex(g_iTire[client]);

	float fPos[3], fAng[3];
	CopyArray(fPos, fClientPos);
	//GetEntPropVector(iTire, Prop_Send, "m_angRotation", fAng);

	fAng[1] = fClientAng[1];
	//IncrementAngle(fAng[0], SPEED);

	//fPos[2] += Sine(fAng[0] /SPEED /10.0) *20.0;
	//PrintToChatAll("Pos: %.3f", Sine(fAngle) *16.0);
	TeleportEntity(iTire, fPos, fAng, NULL_VECTOR);

}

public void OnBoiTouch			(int iBoi, int client){

	if(!(1 <= client <= MaxClients))
		return;

	SDKHooks_TakeDamage(client, iBoi, iBoi, BOI_DAMAGE);
	SDKHooks_TakeDamage(iBoi, iBoi, iBoi, -5.0);

}

public Action OnBoiTakeDamage	(int client, int &iAtk, int &iInflictor, float &fDmg, int &iDmgType){

	fDmg /= 10.0;
	return Plugin_Changed;

}

public Action OnBoiSound		(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(!g_bBoi[client])
		return Plugin_Stop;

	int iSound = GetRandomInt(0, SOUND_COUNT -1);
	EmitSoundToAll(g_sCritters[iSound], client);

	CreateTimer(SOUND_INTV, OnBoiSound, iSerial);
	return Plugin_Stop;

}


void RipAndTear					(int client, int atk){

	RequestFrame(RipAndTear_Frame, GetClientSerial(client));

	int iSound = GetRandomInt(0, SOUND_COUNT -1);
	for(int i = 0; i < 5; i++){
	
		EmitSoundToAll(g_sCritters[iSound], atk);
		EmitSoundToAll(SOUND_GORE, client);
	
	}

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

public void RipAndTear_Frame	(int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return;

	int iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if(iRagdoll > MaxClients && IsValidEntity(iRagdoll))
		AcceptEntityInput(iRagdoll, "Kill");

}

void SpawnGib					(float fPos[3], float fAng[3], float fVel[3], TFClassType Class, int iGibCount){

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

int ClassToIndex				(TFClassType Class){

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


stock void CreateParticle		(float fPos[3], const char[] strParticle, float fZOffset){

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

stock float IncrementAngle		(float &fAng, float fVal){

	fAng += fVal;
	fAng = fAng >= 380.0 ? 0.0 : fAng;

}

stock void CopyArray			(float fArr1[3], float fArr2[3]){

	for(int i = 0; i < 3; i++)
		fArr1[i] = fArr2[i];

}

stock void KillEntRef			(int iEntRef){

	int iEnt = EntRefToEntIndex(iEntRef);
	if(IsValidEntity2(iEnt))
		AcceptEntityInput(iEnt, "Kill");

}

stock bool IsValidEntity2		(int iEnt){

	return iEnt > MaxClients && IsValidEntity(iEnt);

}

stock bool IsCorrectWearable	(int client, int i, char[] sClass, iBufferSize){

	if(!IsValidEntity(i))
		return false;

	GetEntityClassname(i, sClass, iBufferSize);
	if(StrContains(sClass, "tf_wearable", false) < 0 && StrContains(sClass, "tf_powerup", false) < 0)
		return false;

	if(GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") != client)
		return false;

	return true;

}

stock void SetEntityAlpha		(int iEntity, int iValue){

	SetEntData(iEntity, GetEntSendPropOffs(iEntity, "m_clrRender") + 3, iValue, 1, true);

}