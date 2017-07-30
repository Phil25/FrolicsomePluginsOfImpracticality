#pragma semicolon 1


#include <tf2_stocks>
#include <sdktools>


#define TAUNT_ID	30816
#define SPELL_DUR	15.0


enum Spells{

	Spell_None,

	Spell_Invis,
	Spell_Minify,
	Spell_Heal,
	Spell_Speed,
	Spell_Swim,
	Spell_Giant,
	Spell_Crit,
	Spell_Uber,

	Spell_CAST_ON_OTHERS,

	Spell_Fireball,
	Spell_Lightning,
	Spell_Pumpkins,
	Spell_Bats,
	Spell_Meteors,
	Spell_Teleport,
	Spell_Monoculus,
	Spell_Zombies

}


bool g_bIsMagical[MAXPLAYERS+1] = {false, ...};
char g_sActions[3][] = {"Toggled", "Disabled", "Enabled"};

float g_fTimes[10] = {

	1.0,	//Unknown
	2.4,	//Scout
	1.8,	//Sniper
	2.4,	//Soldier
	3.2,	//Demoman
	2.25,	//Medic
	2.1,	//Heavy
	2.25,	//Pyro
	2.2,	//Spy
	2.35,	//Engineer

};

char g_sSpells[][] = {

	"tf_projectile_spellfireball",
	"tf_projectile_lightningorb",
	"tf_projectile_spellmirv",
	//"tf_projectile_spellpumpkin",
	"tf_projectile_spellbats",
	"tf_projectile_spellmeteorshower",
	"tf_projectile_spelltransposeteleport",
	"tf_projectile_spellspawnboss",
	"tf_projectile_spellspawnhorde"//,
	//"tf_projectile_spellspawnzombie"

};

bool g_bSpellCastingOpen[MAXPLAYERS+1] = {false, ...};
Spells g_iNextSpell[MAXPLAYERS+1] = {Spell_None, ...};


public Plugin myinfo = {

	name		= "Second Rate Sorcery Magic",
	author		= "Phil25",
	description	= "Give that shitty staff more buff!"

};


public void OnPluginStart			(){

	LoadTranslations("common.phrases");

	RegAdminCmd("sm_srsmagic", Command_MakeMagical, ADMFLAG_SLAY, "Usage: sm_srsmagic <player>* <-1/0/1>*");

	AddCommandListener(OnVoiceMenu, "voicemenu");

}

public void OnClientDisconnect		(int client){

	g_bIsMagical[client]		= false;
	g_bSpellCastingOpen[client]	= false;

}

public Action Command_MakeMagical	(int client, int args){

	char sTrg[32];
	char sDir[4];

	switch(args){
	
		case 0:{
		
			sTrg = "@me";
			sDir = "-1";
		
		}
	
		case 1:{
		
			GetCmdArg(1, sTrg, 32);
			sDir = "-1";
		
		}
	
		default:{
		
			GetCmdArg(1, sTrg, 32);
			GetCmdArg(2, sDir, 4);
		
		}
	
	}

	int iDir = StringToInt(sDir);

	char sTrgName[MAX_TARGET_LENGTH];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	
	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){
	
		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;
	
	}

	switch(iDir){
	
		case -1:
			for(int i = 0; i < iTrgCount; i++)
				g_bIsMagical[aTrgList[i]] = !g_bIsMagical[aTrgList[i]];
	
		case 0:
			for(int i = 0; i < iTrgCount; i++)
				g_bIsMagical[aTrgList[i]] = false;
	
		case 1:
			for(int i = 0; i < iTrgCount; i++)
				g_bIsMagical[aTrgList[i]] = true;
	
	}

	ReplyToCommand(client, "[SM] %s srs magic on %d players.", g_sActions[iDir+1], iTrgCount);

	return Plugin_Handled;

}


public Action OnVoiceMenu			(int client, const char[] sCmd, int args){

	if(!g_bSpellCastingOpen[client])
		return Plugin_Continue;

	char[][] sArgs = new char[2][4];
	GetCmdArg(1, sArgs[0], 4);
	GetCmdArg(2, sArgs[1], 4);

	int iArgs[2];
	for(int i = 0; i < 2; i++)
		iArgs[i] = StringToInt(sArgs[i]);

	ProcessVoiceMenu(client, iArgs[0], iArgs[1]);

	return Plugin_Continue;

}

void ProcessVoiceMenu(int client, int iMenu, int iVoice){

	switch(iMenu){
	
		case 0: switch(iVoice){
		
			case 0: //MEDIC!
				g_iNextSpell[client] = Spell_Heal;
		
			case 1: //Thanks!
				g_iNextSpell[client] = Spell_Monoculus;
		
			case 2: //Go! Go! Go!
				g_iNextSpell[client] = Spell_Speed;
		
			case 3: //Move Up!
				g_iNextSpell[client] = Spell_Swim;
		
			case 6: //Yes
				g_iNextSpell[client] = Spell_Giant;
		
			case 7: //No
				g_iNextSpell[client] = Spell_Zombies;
		
		}
	
		case 1: switch(iVoice){
		
			case 0: //Incoming!
				g_iNextSpell[client] = Spell_Meteors;
		
			case 1: //Spy!
				g_iNextSpell[client] = Spell_Invis;
		
			case 3: //Teleporter Here
				g_iNextSpell[client] = Spell_Teleport;
		
			case 4: //Dispenser Here
				g_iNextSpell[client] = Spell_Pumpkins;
		
			case 6: //Activate Charge!
				g_iNextSpell[client] = Spell_Uber;
		
		}
	
		case 2: switch(iVoice){
		
			case 1: //Battle Cry
				g_iNextSpell[client] = Spell_Lightning;
		
			case 2: //Cheers
				g_iNextSpell[client] = Spell_Minify;
		
			case 3: //Jeers
				g_iNextSpell[client] = Spell_Bats;
		
			case 4: //Positive
				g_iNextSpell[client] = Spell_Crit;
		
			case 6: //Nice Shot!
				g_iNextSpell[client] = Spell_Fireball;
		
		}
	
	}

}

public void TF2_OnConditionAdded	(int client, TFCond Condition){

	if(!IsClientInGame(client))
		return;

	if(!g_bIsMagical[client])
		return;

	if(Condition != TFCond_Taunting)
		return;

	if(GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex") != TAUNT_ID)
		return;

	g_bSpellCastingOpen[client] = true;
	CreateTimer(g_fTimes[view_as<int>(TF2_GetPlayerClass(client))], Timer_OnMagic, GetClientSerial(client));

}

public Action Timer_OnMagic			(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	g_bSpellCastingOpen[client] = false;
	if(g_iNextSpell[client] == Spell_None)
		return Plugin_Stop;

	if(g_iNextSpell[client] < Spell_CAST_ON_OTHERS)
		CastSpellOnSelf(client);
	else CastSpellOnOthers(client);

	g_iNextSpell[client] = Spell_None;
	CreateTimer(0.6, Timer_StopTaunting, iSerial);

	return Plugin_Stop;

}

void CastSpellOnSelf				(int client){

	switch(g_iNextSpell[client]){
	
		case Spell_Invis:
			TF2_AddCondition(client, TFCond_Stealthed, SPELL_DUR, client);
	
		case Spell_Minify:
			TF2_AddCondition(client, TFCond_HalloweenTiny, SPELL_DUR, client);
	
		case Spell_Heal:
			TF2_AddCondition(client, TFCond_HalloweenQuickHeal, SPELL_DUR, client);
	
		case Spell_Speed:
			TF2_AddCondition(client, TFCond_HalloweenSpeedBoost, SPELL_DUR, client);
	
		case Spell_Swim:
			TF2_AddCondition(client, TFCond_SwimmingCurse, SPELL_DUR, client);
	
		case Spell_Giant:
			TF2_AddCondition(client, TFCond_HalloweenGiant, SPELL_DUR, client);
	
		case Spell_Crit:
			TF2_AddCondition(client, TFCond_HalloweenCritCandy, SPELL_DUR, client);
	
		case Spell_Uber:
			TF2_AddCondition(client, TFCond_UberchargedCanteen, SPELL_DUR, client);
	
	}

}

void CastSpellOnOthers				(int client){

	int iSpellNum = view_as<int>(g_iNextSpell[client] -Spell_CAST_ON_OTHERS) -1,
		iSpell = CreateEntityByName(g_sSpells[iSpellNum]);

	if(!IsValidEntity(iSpell))
		return;

	/*
		Pretty much everything below is [strike]stolen[/strike] borrowed from Powerlord's "Spell casting!"
		https://forums.alliedmods.net/showthread.php?p=2054678
	*/

	float fPos[3], fAng[3], fVel[3], fBuf[3];
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAng);
	GetAngleVectors(fAng, fBuf, NULL_VECTOR, NULL_VECTOR);
	int iTeam = GetClientTeam(client);

	for(int i = 0; i < 3; i++)
		fVel[i] = fBuf[i] *1100.0;

	SetEntPropEnt(iSpell,	Prop_Send, "m_hOwnerEntity",	client);
	SetEntProp(iSpell,		Prop_Send, "m_bCritical",		GetRandomInt(0, 100) <= 5 ? 1 : 0, 1);
	SetEntProp(iSpell,		Prop_Send, "m_iTeamNum",		iTeam, 1);
	SetEntProp(iSpell,		Prop_Send, "m_nSkin",			iTeam -2);

	TeleportEntity(iSpell, fPos, fAng, NULL_VECTOR);

	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "TeamNum");
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "SetTeam");

	DispatchSpawn(iSpell);
	TeleportEntity(iSpell, NULL_VECTOR, NULL_VECTOR, fVel);

}

public Action Timer_StopTaunting	(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client != 0)
		TF2_RemoveCondition(client, TFCond_Taunting);

	return Plugin_Stop;

}