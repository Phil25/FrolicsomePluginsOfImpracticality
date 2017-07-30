#pragma semicolon 1

#include <sdktools>
#include <sdkhooks>

#define SOUND_THUNDER	"npc/strider/fire.wav"
#define LASERBEAM		"sprites/laserbeam.vmt"


public Plugin myinfo = {

	name		= "Smite",
	author		= "Phil25",
	description	= "Rain down havok on player peasants."

};


public void OnPluginStart(){

	LoadTranslations("common.phrases");

	RegAdminCmd("sm_smite", Command_Smite, ADMFLAG_SLAY);

}

public void OnMapStart(){

	PrecacheSound(SOUND_THUNDER);
	PrecacheModel(LASERBEAM);

}

public Action Command_Smite(int client, int args){

	if(args < 1){

		ReplyToCommand(client, "[SM] Usage: sm_smite <player>");
		return Plugin_Handled;

	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, 32);

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	/*if(iTrgCount > 8){
	
		ReplyToCommand(client, "[SM] Cannot smite more than 8 players at once.");
		return Plugin_Handled;
	
	}*/

	for(int i = 0; i < iTrgCount; i++)
		SmitePlayer(aTrgList[i]);

	return Plugin_Handled;

}


void SmitePlayer(int client){

	EmitSoundToAll(SOUND_THUNDER, client);
	SDKHooks_TakeDamage(client, client, client, 999.0, DMG_GENERIC);

	RequestFrame(SmitePlayerPost, GetClientUserId(client));

	int[] iStrike = new int[2];

	iStrike[0] = CreateEntityByName("info_target");
	if(iStrike[0] <= MaxClients)
		return;

	SetVariantString("OnUser1 !self:kill::0.25:1");
	AcceptEntityInput(iStrike[0], "AddOutput");
	AcceptEntityInput(iStrike[0], "FireUser1");

	iStrike[1] = CreateEntityByName("info_target");
	if(iStrike[1] <= MaxClients)
		return;

	SetVariantString("OnUser1 !self:kill::0.25:1");
	AcceptEntityInput(iStrike[1], "AddOutput");
	AcceptEntityInput(iStrike[1], "FireUser1");

	float fPos[3];
	GetClientAbsOrigin(client, fPos);
	fPos[2] += 32.0;
	TeleportEntity(iStrike[0], fPos, NULL_VECTOR, NULL_VECTOR);
	fPos[2] += 1024.0;
	TeleportEntity(iStrike[1], fPos, NULL_VECTOR, NULL_VECTOR);

	SpawnBeam(EntIndexToEntRef(iStrike[1]), EntIndexToEntRef(iStrike[0]));

}

public void SmitePlayerPost(int iUid){

	int client = GetClientOfUserId(iUid);
	if(client == 0)
		return;

	int iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if(iRagdoll <= MaxClients)
		return;

	int iDissolver = CreateEntityByName("env_entity_dissolver");
	if(iDissolver <= MaxClients)
		return;

	DispatchKeyValue(iDissolver, "dissolvetype", "0");
	DispatchKeyValue(iDissolver, "magnitude", "1");
	DispatchKeyValue(iDissolver, "target", "!activator");
	AcceptEntityInput(iDissolver, "Dissolve", iRagdoll);
	AcceptEntityInput(iDissolver, "Kill");

}


stock int SpawnTesla(float fPos[3]){

	int iTesla = CreateEntityByName("point_tesla");
	if(iTesla <= MaxClients || !IsValidEntity(iTesla))
		return 0;

	TeleportEntity(iTesla, fPos, NULL_VECTOR, NULL_VECTOR);

	DispatchKeyValue(iTesla, "m_flRadius", "150.0");
	DispatchKeyValue(iTesla, "m_SoundName", "DoSpark");
	DispatchKeyValue(iTesla, "beamcount_min", "2");
	DispatchKeyValue(iTesla, "beamcount_max", "4");
	DispatchKeyValue(iTesla, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(iTesla, "m_Color", "255 255 255");
	DispatchKeyValue(iTesla, "thick_min", "5.0");
	DispatchKeyValue(iTesla, "thick_max", "11.0");
	DispatchKeyValue(iTesla, "lifetime_min", "0.3");
	DispatchKeyValue(iTesla, "lifetime_max", "2");
	DispatchKeyValue(iTesla, "interval_min", "0.1");
	DispatchKeyValue(iTesla, "interval_max", "0.2");

	ActivateEntity(iTesla);
	DispatchSpawn(iTesla);
	AcceptEntityInput(iTesla, "TurnOn");

	return iTesla;

}

stock void SpawnBeam(int iEntRef, int iEntRef2){

	int iBeam = CreateEntityByName("env_beam");

	if(iBeam <= MaxClients)
		return;

	if(!IsValidEntity(iBeam))
		return;

	SetEntityModel(iBeam, LASERBEAM);

	DispatchKeyValue(iBeam, "rendercolor", "128 128 255");
	DispatchKeyValue(iBeam, "life", "0");

	DispatchSpawn(iBeam);

	SetEntPropEnt(iBeam, Prop_Send, "m_hAttachEntity", iEntRef);
	SetEntPropEnt(iBeam, Prop_Send, "m_hAttachEntity", iEntRef2, 1);

	SetEntProp(iBeam, Prop_Send, "m_nNumBeamEnts", 2);
	SetEntProp(iBeam, Prop_Send, "m_nBeamType", 2);

	SetEntPropFloat(iBeam, Prop_Data, "m_fWidth", 10.0);
	SetEntPropFloat(iBeam, Prop_Data, "m_fEndWidth", 2.5);

	SetEntPropFloat(iBeam, Prop_Data, "m_fAmplitude", 4.0);

	SetVariantFloat(32.0);
	AcceptEntityInput(iBeam, "Amplitude");
	AcceptEntityInput(iBeam, "TurnOn");

	SetVariantString("OnUser1 !self:kill::0.5:1");
	AcceptEntityInput(iBeam, "AddOutput");
	AcceptEntityInput(iBeam, "FireUser1");

}