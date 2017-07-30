#pragma semicolon 1


#include <sdkhooks>
#include <sdktools>


#define MODEL_FROK "models/props_2fort/frog.mdl"
#define SOUND_COUNT 4
#define RANDOM_SIZE GetRandomFloat(0.5, 2.0)
//#define RANDOM_SIZE GetRandomFloat(15.0, 20.0)


bool g_bFrok[MAXPLAYERS+1] = {false, ...};
char g_sAction[3][] = {"Toggled", "Disabled", "Enabled"};
char g_sCritters[SOUND_COUNT][] = {

	"ambient/levels/canals/critter1.wav",
	"ambient/levels/canals/critter2.wav",
	"ambient/levels/canals/critter3.wav",
	"ambient/levels/canals/critter5.wav"

};

Handle g_hStickies = INVALID_HANDLE;


public Plugin myinfo = {

	name = "Frok Stickies",
	author = "Phil25",
	description = "Turns stickies into froks."

};


public void OnPluginStart		(){

	LoadTranslations("common.phrases");

	g_hStickies = CreateArray();

	RegAdminCmd("sm_frok", Command_Frok, ADMFLAG_SLAY);

	//HookEvent("post_inventory_application", OnResupply, EventHookMode_Post);

}

public void OnMapStart			(){

	PrecacheModel(MODEL_FROK);
	for(int i = 0; i < SOUND_COUNT; i++)
		PrecacheSound(g_sCritters[i]);

}

public void OnClientDisconnect	(int client){

	g_bFrok[client] = false;

}

public void OnEntityCreated		(int iEnt, const char[] sClassname){

	if(StrEqual(sClassname, "tf_projectile_pipe_remote"))
		SDKHook(iEnt, SDKHook_SpawnPost, OnStickySpawn);

}

public void OnEntityDestroyed	(int iEnt){

	int iId = FindValueInArray(g_hStickies, iEnt);
	if(iId > -1)
		OnStickyDestroy(iEnt, iId);

}


public Action Command_Frok		(int client, int args){

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
		SetFrok(aTrgList[i], iDir);

	ReplyToCommand(client, "[SM] %s Frok on %d player%s", g_sAction[iDir +1], iTrgCount, iTrgCount == 1 ? "" : "s");
	return Plugin_Handled;

}

void SetFrok					(int client, int iDir){

	switch(iDir){
	
		case 0:
			g_bFrok[client] = false;
	
		case 1:
			g_bFrok[client] = true;
	
		default:
			g_bFrok[client] = !g_bFrok[client];
	
	}

}


public void OnStickySpawn		(int iSticky){

	int client = GetEntPropEnt(iSticky, Prop_Send, "m_hOwnerEntity");
	if(!(1 <= client <= MaxClients))
		return;

	if(!g_bFrok[client])
		return;

	SDKHook(iSticky, SDKHook_ThinkPost, OnStickyThink);
	SetEntPropFloat(iSticky, Prop_Data, "m_flModelScale", RANDOM_SIZE);
	SetEntityModel(iSticky, MODEL_FROK);

	PushArrayCell(g_hStickies, iSticky);

}

void OnStickyDestroy			(int iSticky, int iId){

	RemoveFromArray(g_hStickies, iId);

	int iSound = GetRandomInt(0, SOUND_COUNT -1);
	for(int i = 0; i < 4; i++)
		EmitSoundToAll(g_sCritters[iSound], iSticky);

	float fPos[3];
	GetEntPropVector(iSticky, Prop_Send, "m_vecOrigin", fPos);
	CreateParticle(fPos, "tfc_sniper_mist");

}

public void OnStickyThink		(int iSticky){

	if(!GetEntProp(iSticky, Prop_Send, "m_bTouched"))
		return;

	SDKUnhook(iSticky, SDKHook_ThinkPost, OnStickyThink);
	RequestFrame(OnStickyTouch, EntIndexToEntRef(iSticky));

}

public void OnStickyTouch		(int iStickyRef){

	int iSticky = EntRefToEntIndex(iStickyRef);
	if(iSticky <= MaxClients || !IsValidEntity(iSticky))
		return;

	float fAng[3];
	GetEntPropVector(iSticky, Prop_Send, "m_angRotation", fAng);

	for(int i = 0; i < 3; i += 2)
		fAng[i] = 0.0;

	SetEntPropVector(iSticky, Prop_Send, "m_angRotation", fAng);
	CreateTimer(1.0, Timer_FrokSound, iStickyRef);

}

public Action Timer_FrokSound	(Handle hTimer, int iFrokRef){

	int iFrok = EntRefToEntIndex(iFrokRef);
	if(iFrok <= MaxClients || !IsValidEntity(iFrok))
		return Plugin_Stop;

	if(!GetEntProp(iFrok, Prop_Send, "m_bTouched")){
	
		CreateTimer(GetRandomFloat(0.6, 1.4), Timer_FrokSound, iFrokRef);
		return Plugin_Stop;
	
	}

	FrokThink(iFrok);

	CreateTimer(GetRandomFloat(0.6, 1.4), Timer_FrokSound, iFrokRef);
	return Plugin_Stop;

}

void FrokThink					(int iFrok){

	int iSound = GetRandomInt(0, SOUND_COUNT -1),
		iVol = RoundFloat(2.0 *GetEntPropFloat(iFrok, Prop_Data, "m_flModelScale")),
		iPitch = 150/iVol;

	for(int i = 0; i < iVol; i++)
		EmitSoundToAll(g_sCritters[iSound], iFrok, _, _, _, _, iPitch);

	/*int client = GetEntPropEnt(iFrok, Prop_Send, "m_hThrower");
	if(!(1 <= client <= MaxClients))
		return;

	float fPos[3], fAng[3], fClientPos[3];
	GetEntPropVector(iFrok, Prop_Data, "m_vecOrigin", fPos);
	GetEntPropVector(iFrok, Prop_Data, "m_angRotation", fAng);
	GetClientAbsOrigin(client, fClientPos);

	float fDist[3];
	fDist[0] = GetVector2Distance(fClientPos, fPos);
	for(int i = 0; i < 2; i++)
		fDist[i+1] = fClientPos[i] -fPos[i];

	float fSpeed = (fDist[0] -64.0) /16.0;
	Math_Clamp(fSpeed, -4.0, 4.0);
	if(FloatAbs(fSpeed) < 0.3)
		fSpeed *= 0.1;

	if(fPos[0] < fClientPos[0]) fPos[0] += fSpeed;
	if(fPos[0] > fClientPos[0]) fPos[0] -= fSpeed;
	if(fPos[1] < fClientPos[1]) fPos[1] += fSpeed;
	if(fPos[1] > fClientPos[1]) fPos[1] -= fSpeed;

	fAng[1] = (ArcTangent2(fDist[2], fDist[1]) *180) /3.14;
	fPos[2] = GetPetZPosition(fPos, fClientPos);
	TeleportEntity(iFrok, fPos, fAng, NULL_VECTOR);*/

	float fAng[3], fPos[3];
	fAng[1] = GetRandomFloat(-180.0, 180.0);
	SetEntPropVector(iFrok, Prop_Send, "m_angRotation", fAng);

	GetEntPropVector(iFrok, Prop_Send, "m_vecOrigin", fPos);
	float fThreshold = 8.0 *iVol;
	fPos[0] += GetRandomFloat(-fThreshold, fThreshold);
	fPos[1] += GetRandomFloat(-fThreshold, fThreshold);
	TeleportEntity(iFrok, fPos, NULL_VECTOR, NULL_VECTOR);

}


stock void CreateParticle		(float fPos[3], const char[] strParticle, float fZOffset=0.0){

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

stock float GetVector2Distance	(const float fVec1[3], const float fVec2[3]){

	float fVec3[3], fVec4[3];

	for(int i = 0; i < 2; i++){
	
		fVec3[i] = fVec1[i];
		fVec4[i] = fVec2[i];
	
	}

	return GetVectorDistance(fVec3, fVec4);

}

stock float GetPetZPosition		(float fPos[3], float fPosOwner[3], bool bJumping=false){

	fPos[2] = fPosOwner[2] +128.0;
	float fGroundZ = GetGroundZ(fPos);

	if(!(-256.0 < fGroundZ -fPosOwner[2] < 256.0))
		fGroundZ = fPosOwner[2];

	if(bJumping)
		fGroundZ += fPosOwner[2] -GetGroundZ(fPosOwner);

	return fGroundZ;

}

stock any Math_Clamp			(any aVal, any aMin, any aMax){

	aVal = Math_Min(aVal, aMin);
	aVal = Math_Max(aVal, aMax);

	return aVal;

}

stock any Math_Min				(any aVal, any aMin){

	return aVal < aMin ? aMin : aVal;

}

stock any Math_Max				(any aVal, any aMax){

	return aVal > aMax ? aMax : aVal;

}

stock float GetGroundZ			(const float fStart[3]){

	Handle hTrace = TR_TraceRayEx(fStart, view_as<float>({90.0, 0.0, 0.0}), MASK_SHOT, RayType_Infinite);
	if(hTrace == INVALID_HANDLE)
		return 0.0;

	if(!TR_DidHit(hTrace)){
	
		delete hTrace;
		return 0.0;
	
	}

	float fGroundPos[3];
	TR_GetEndPosition(fGroundPos, hTrace);
	delete hTrace;

	return fGroundPos[2];

}