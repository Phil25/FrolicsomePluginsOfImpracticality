#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <speech>
#include <tf2attributes>
#include <resize>
#include <footsteps>
#include <sdkhooks>
#include <playerdata>
#include <nuke>

public Plugin myinfo = {

	name = "Player Bosses",
	author = "Phil25",
	description = "Turns a player into a boss."

};


//---[ Defines ]---//

#define MAXONE			MAXPLAYERS+1
#define CHAT_PREFIX		"\x04[BOSS]\x01"

#define ATTRIB_SPEED	107
#define ATTRIB_JUMP		326
#define ATTRIB_TAUNT	201

#define COLOR_NORMAL	{255,255,255,255}
#define COLOR_RED		{255,75,75,255}

#define S_FIREBALL		0
#define S_LIGHTNING		1
#define S_BATS			2
#define S_METEORS		3
#define S_TELEPORT		4

#define N_FIREBALL		10
#define N_LIGHTNING		12
#define N_BATS			10
#define N_METEORS		20
#define N_TELEPORT		5

#define SOUND_IMPACT	"misc/halloween/strongman_fast_impact_01.wav"
#define SOUND_EXPLOSION	"weapons/explode3.wav"
#define SOUND_CAST		"misc/halloween/spell_lightning_ball_cast.wav"

#define PART_EXPLOSION	"fireSmokeExplosion_track"

#define RANGE_STONE		48.0
#define RANGE_SKULLCUT	98.0


//---[ Variables ]---//

bool	bIsBoss[MAXONE]	= {false, ...};
bool	bSecond[MAXONE] = {true, ...};
bool	bThird[MAXONE]	= {true, ...};
float	fDefSpd[MAXONE]	= {300.0, ...};
Handle	hAcMenu[MAXONE]	= {INVALID_HANDLE, ...};
bool	bInMenu[MAXONE]	= {false, ...};
int		iNextAc[MAXONE] = {0, ...};

bool	bInCharge[MAXONE] = {false, ...};
float	fBodySize[MAXONE] = {1.8, ...};
float	fSizeAdd[MAXONE] = {-0.05, ...};

Handle	hBossDamagers[MAXONE] = {INVALID_HANDLE, ...};
Handle	hBossDamage[MAXONE] = {INVALID_HANDLE, ...};

char	sLandSound[3][PLATFORM_MAX_PATH] = {

	"weapons/demo_charge_hit_world1.wav",
	"weapons/demo_charge_hit_world2.wav",
	"weapons/demo_charge_hit_world3.wav"

};



//---[ F U N C T I O N S ]---//

public void OnPluginStart(){

	RegAdminCmd("sm_boss", Command_SetBoss, ADMFLAG_SLAY, "Set boss abilities on a player. Usage: sm_boss <player> <0/1>");

	RegAdminCmd("sm_special",	Command_Special,	0, "Opens a menu with special attacks.");
	
	RegAdminCmd("sm_fireball",	Command_Fireball,	0, "Shoots a fireball");
	RegAdminCmd("sm_lightning",	Command_Lightning,	0, "Shoots lightning");
	RegAdminCmd("sm_bats",		Command_Bats,		0, "Shoots bats");
	RegAdminCmd("sm_meteors",	Command_Meteors,	0, "Shoots meteors");
	RegAdminCmd("sm_teleport",	Command_Teleport,	0, "Shoots teleport spell");

	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);

}

void Display_AttackMenu(int client){

	if(!IsValidClient(client))
		return;
	
	hAcMenu[client] = CreateMenu(Menu_Manager);
	
	bool bCanAttack = (GetTime() >= iNextAc[client]);
	char sNext[12];
	Format(sNext, 12, " [%d]", iNextAc[client] -GetTime());
	
	SetMenuTitle(hAcMenu[client], "Boss's Spells Menu%s", bCanAttack ? "" : sNext);
	
	AddMenuItem(hAcMenu[client], "", "Fireball [10]", bCanAttack ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(hAcMenu[client], "", "Lightning [12]", bCanAttack ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(hAcMenu[client], "", "Bats [10]", bCanAttack ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(hAcMenu[client], "", "Meteors [20]", bCanAttack ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	//AddMenuItem(hAttackMenu, "", "Teleport", bCanAttack ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	bInMenu[client] = true;
	DisplayMenu(hAcMenu[client], client, MENU_TIME_FOREVER);
	CreateTimer(1.0, Timer_RefreshMenu, GetClientSerial(client));

}

public int Menu_Manager(Handle hMenu, MenuAction maState, int client, int iPos){

	if(maState != MenuAction_Select){
	
		if(iPos == MenuCancel_Exit)
			bInMenu[client] = false;
	
		return 0;
	
	}

	if(!bIsBoss[client] && !IsClientAdmin(client)){
	
		bInMenu[client] = false;
		return 0;
	
	}
	
	FireSpell(client, iPos);
	Display_AttackMenu(client);
	
	return 1;

}

public void OnClientDisconnect(int client){

	PlayerData_BoolIsBoss(client, -1);
	bIsBoss[client] = false;
	bInMenu[client] = false;

}

public void OnMapStart(){

	PrecacheSound(SOUND_IMPACT);
	PrecacheSound(SOUND_EXPLOSION);
	PrecacheSound(SOUND_CAST);

	for(int i = 0; i < 3; i++)
		PrecacheSound(sLandSound[i]);

	HookEvent("player_death", Event_PlayerDeath);

}

public void OnMapEnd(){

	UnhookEvent("player_death", Event_PlayerDeath);

}

public void Event_PlayerDeath(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsValidClient(client))
		return;
	
	if(bIsBoss[client])
		DisableBoss(client);

}


//---[ C O M M A N D S ]---//

public Action Command_SetBoss(int client, int args){

	if(args < 1){
	
		ReplyToCommand(client, "[SM] Usage: sm_boss <player> <0/1>");
		return Plugin_Handled;
	
	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));
	
	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_ALIVE|COMMAND_FILTER_NO_MULTI, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){
	
		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;
	
	}
	
	int iSet = 0;
	if(args > 1){
	
		char sDir[4];
		GetCmdArg(2, sDir, sizeof(sDir));
		
		if(StringToInt(sDir) > 0)
			iSet = 1;
		else
			iSet = -1;
	
	}
	
	switch(iSet){
	
		case -1:{
		
			if(!bIsBoss[aTrgList[0]]){
			
				ReplyToCommand(client, "[SM] Player \"%N\" is not a boss.", aTrgList[0]);
				return Plugin_Handled;
			
			}
			
			DisableBoss(aTrgList[0]);
			ReplyToCommand(client, "[SM] Disbling boss on player \"%N\".", aTrgList[0]);
		
		}
		
		case 0:{
		
			if(bIsBoss[aTrgList[0]]){
			
				DisableBoss(aTrgList[0]);
				ReplyToCommand(client, "[SM] Disbling boss on player \"%N\".", aTrgList[0]);
			
			
			}else{
			
				EnableBoss(aTrgList[0]);
				ReplyToCommand(client, "[SM] Enabling boss on player \"%N\".", aTrgList[0]);
			
			}
		
		}
		
		case 1:{
		
			if(bIsBoss[aTrgList[0]]){
			
				ReplyToCommand(client, "[SM] Player \"%N\" is already a boss.", aTrgList[0]);
				return Plugin_Handled;
			
			}
			
			EnableBoss(aTrgList[0]);
			ReplyToCommand(client, "[SM] Enabling boss on player \"%N\".", aTrgList[0]);
		
		}
	
	}
	
	return Plugin_Handled;

}

public Action Command_Special(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;
	
	if(bIsBoss[client] || IsClientAdmin(client))
		Display_AttackMenu(client);

	return Plugin_Handled;

}

public Action Command_Fireball(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;
	
	if(bIsBoss[client] || IsClientAdmin(client))
		FireSpell(client, S_FIREBALL);

	return Plugin_Handled;

}

public Action Command_Lightning(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;
	
	if(bIsBoss[client] || IsClientAdmin(client))
		FireSpell(client, S_LIGHTNING);

	return Plugin_Handled;

}

public Action Command_Bats(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;
	
	if(bIsBoss[client] || IsClientAdmin(client))
		FireSpell(client, S_BATS);

	return Plugin_Handled;

}

public Action Command_Meteors(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;
	
	if(bIsBoss[client] || IsClientAdmin(client))
		FireSpell(client, S_METEORS);

	return Plugin_Handled;

}

public Action Command_Teleport(int client, int args){

	if(!IsValidClient(client))
		return Plugin_Handled;
	
	if(bIsBoss[client] || IsClientAdmin(client))
		FireSpell(client, S_TELEPORT);

	return Plugin_Handled;

}


//---[ M A I N ]---//

void EnableBoss(int client){

	Speech_Change(client, 75);
	Footsteps_Set(client, 10);
	
	SaveClientDefaultSpeed(client);
	TF2Attrib_SetByDefIndex(client, ATTRIB_SPEED, 3.0);
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", fDefSpd[client]*3.0);
	
	TF2Attrib_SetByDefIndex(client, ATTRIB_JUMP, 2.3);
	
	Colorize(client, COLOR_RED);
	
	/*Resize_Change(client, 0, "2.5");
	Resize_Change(client, 1, "3");
	Resize_Change(client, 2, "0.6");
	Resize_Change(client, 3, "2");*/
	
	Resize_Change(client, 0, "1.8");
	Resize_Change(client, 1, "2");
	Resize_Change(client, 2, "0.7");
	Resize_Change(client, 3, "1.5");
	
	SDKHook(client, SDKHook_StartTouch, Event_OnBossTouch);

	SetNotarget(client, false);

	PrintToChat(client, "%s You've been set as a boss", CHAT_PREFIX);
	PlayerData_BoolIsBoss(client, 1);
	bIsBoss[client] = true;

}

void DisableBoss(int client){

	Speech_Change(client, 100);
	Footsteps_Set(client, 0);
	
	TF2Attrib_RemoveByDefIndex(client, ATTRIB_SPEED);
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", fDefSpd[client]);
	
	TF2Attrib_RemoveByDefIndex(client, ATTRIB_JUMP);
	
	Colorize(client, COLOR_NORMAL);
	
	Resize_Reset(client);
	
	SDKUnhook(client, SDKHook_StartTouch, Event_OnBossTouch);
	DisplayDamageDealers(client);
	delete hBossDamagers[client];
	delete hBossDamage[client];

	bSecond[client] = true;
	bThird[client] = true;

	SetNotarget(client, true);

	PrintToChat(client, "%s You've been unset as a boss", CHAT_PREFIX);
	PlayerData_BoolIsBoss(client, -1);
	bIsBoss[client] = false;

}

int FireSpell(int client, int iSpellId){

	float fAng[3], fPos[3];
	
	GetClientEyeAngles(client, fAng);
	GetClientEyePosition(client, fPos);
	
	char sClassname[64];
	switch(iSpellId){
	
		case S_FIREBALL:{
		
			sClassname = "tf_projectile_spellfireball";
			iNextAc[client] = GetTime() +N_FIREBALL;
		
		}
		
		case S_LIGHTNING:{
		
			sClassname = "tf_projectile_lightningorb";
			iNextAc[client] = GetTime() +N_LIGHTNING;
		
		}
		
		case S_BATS:{
		
			sClassname = "tf_projectile_spellbats";
			iNextAc[client] = GetTime() +N_BATS;
		
		}
		
		case S_METEORS:{
		
			sClassname = "tf_projectile_spellmeteorshower";
			iNextAc[client] = GetTime() +N_METEORS;
		
		}
		
		case S_TELEPORT:{
		
			sClassname = "tf_projectile_spelltransposeteleport";
			iNextAc[client] = GetTime() +N_TELEPORT;
		
		}
	
	}

	iNextAc[client] *= IsNotAdmin(client);
	int iTeam	= GetClientTeam(client);
	int iSpell	= CreateEntityByName(sClassname);
	
	if(!IsValidEntity(iSpell))
		return -1;
	
	float fVel[3], fBuf[3];
	
	GetAngleVectors(fAng, fBuf, NULL_VECTOR, NULL_VECTOR);
	
	fVel[0] = fBuf[0]*1100.0; //Speed of a tf2 rocket.
	fVel[1] = fBuf[1]*1100.0;
	fVel[2] = fBuf[2]*1100.0;

	SetEntPropEnt	(iSpell, Prop_Send, "m_hOwnerEntity",	client);
	SetEntProp		(iSpell, Prop_Send, "m_bCritical",		(GetRandomInt(0, 100) <= 5)? 1 : 0, 1);
	SetEntProp		(iSpell, Prop_Send, "m_iTeamNum",		iTeam, 1);
	SetEntProp		(iSpell, Prop_Send, "m_nSkin",			iTeam-2);
	
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0); 
	
	DispatchSpawn(iSpell);
	TeleportEntity(iSpell, fPos, fAng, fVel);
	
	return iSpell;

}


//---[ E V E N T S ]---//

public void TF2_OnConditionAdded(int client, TFCond Condition){

	if(!IsClientInGame(client))
		return;

	if(!bIsBoss[client])
		return;

	switch(Condition){
	
		case TFCond_Taunting:{
		
			int iTauntId = GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex");
			if(iTauntId == -1){
			
				int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if(iWeapon > MaxClients && IsValidEntity(iWeapon))
					iTauntId = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			
			}
		
			OnClientTaunt(client, iTauntId);
		
		}
	
		case TFCond_Charging: OnClientCharge(client);
	
	}

}

public void TF2_OnConditionRemoved(int client, TFCond Condition){

	if(!IsClientInGame(client))
		return;

	if(!bIsBoss[client])
		return;

	if(Condition == TFCond_Charging)
		bInCharge[client] = false;

}

void OnClientCharge(int client){

	bInCharge[client] = true;
	CreateTimer(0.1, Timer_OnChargeTick, GetClientSerial(client), TIMER_REPEAT);

}

void OnClientTaunt(int client, int iTauntId){

	switch(iTauntId){
	
		case 30673:	CreateTimer(0.85, Timer_SoldierRequiem1, GetClientSerial(client));
		case 1114:	CreateTimer(6.6, Timer_SpentWellSpirits, GetClientSerial(client));
		case 1120:	CreateTimer(0.1, Timer_Oblooterated1, GetClientSerial(client));
		case 172:	CreateTimer(0.45, Timer_SkullcutterTaunt1, GetClientSerial(client));
	
	}

}

public Action OnPlayerRunCmd(int client, int &iButtons){

	if(!bIsBoss[client])
		return Plugin_Continue;

	if(iButtons & IN_ATTACK && iButtons & IN_RELOAD && bSecond[client])
		OnClientSecond(client);

	if(iButtons & IN_ATTACK2 && iButtons & IN_RELOAD && bThird[client])
		OnClientThird(client);

	if(iButtons & IN_ATTACK2)
		SetEntityGravity(client, 8.0);

	else
		SetEntityGravity(client, 1.0);

	return Plugin_Continue;

}

void OnClientSecond(int client){

	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iWeapon <= MaxClients || !IsValidEntity(iWeapon))
		return;

	if(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") != 172)
		return;

	bSecond[client] = false;
	CreateTimer(0.2, Timer_Skullcutter1, GetClientSerial(client));

}

void OnClientThird(int client){

	if(TF2_GetPlayerClass(client) != TFClass_DemoMan)
		return;

	bThird[client] = false;

}

public Action Event_OnBossTouch(int client, int iOther){

	float fVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVel);
	
	if(fVel[2] > -860.0)
		return Plugin_Continue;
	
	SmashFeet(client);
	
	return Plugin_Continue;

}

public void OnGameFrame(){

	for(int i = 1; i <= MaxClients; i++)
		if(bIsBoss[i])
			OnBossGameFrame(i);

}

void OnBossGameFrame(int client){

	if(bThird[client])
		return;

	fBodySize[client] += fSizeAdd[client];
	if(fBodySize[client] < 0.25)
		fSizeAdd[client] = -fSizeAdd[client];

	else if(fBodySize[client] > 1.8){
	
		fBodySize[client] = 1.8;
		fSizeAdd[client] = -fSizeAdd[client];
		Resize_Change(client, 0, "1.8");
		bThird[client] = true;
		return;
	
	}

	char sSize[4];
	Format(sSize, 4, "%.1f", fBodySize[client]);
	Resize_Change(client, 0, sSize);

}

public Action OnPlayerHurt(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!bIsBoss[client])
		return Plugin_Continue;

	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(client == iAttacker)
		return Plugin_Continue;

	if(iAttacker < 1 || iAttacker > MaxClients)
		return Plugin_Continue;

	if(hBossDamage[client] == INVALID_HANDLE || hBossDamagers[client] == INVALID_HANDLE){
	
		hBossDamage[client] = CreateArray();
		hBossDamagers[client] = CreateArray();

	}

	int iDamage = GetEventInt(hEvent, "damageamount");
	int iSerial = GetClientSerial(iAttacker);
	int iId = FindValueInArray(hBossDamagers[client], iSerial);

	if(iId == -1){
	
		PushArrayCell(hBossDamagers[client], iSerial);
		PushArrayCell(hBossDamage[client], iDamage);
		return Plugin_Continue;
	
	}

	int iCurrentDamage = GetArrayCell(hBossDamage[client], iId);
	SetArrayCell(hBossDamage[client], iId, iCurrentDamage +iDamage);

	return Plugin_Continue;

}


//---[ T I M E R S ]---//

public Action Timer_RefreshMenu(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bInMenu[client])
		return Plugin_Stop;

	Display_AttackMenu(client);

	return Plugin_Stop;

}

public Action Timer_SoldierRequiem1(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return Plugin_Stop;

	SmashSurroundings(client);
	CreateTimer(2.3, Timer_SoldierRequiem2, iSerial);

	return Plugin_Stop;

}

public Action Timer_SoldierRequiem2(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return Plugin_Stop;

	SmashSurroundings(client);

	return Plugin_Stop;

}

public Action Timer_SpentWellSpirits(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return Plugin_Stop;

	float fPos[3];
	GetClientAbsOrigin(client, fPos);
	Nuke_Spawn(fPos[0], fPos[1], fPos[2]);

	return Plugin_Stop;

}

public Action Timer_Skullcutter1(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	TF2Attrib_SetByDefIndex(client, ATTRIB_TAUNT, 0.1);

	EmitSoundToAll(SOUND_CAST, client);
	int iParticle = CreateAndAttachParticle(client, GetClientTeam(client) == 2 ? "eyeboss_vortex_red" : "eyeboss_vortex_blue", _, "head");
	SetVariantString("OnUser1 !self:Kill::1:-1");
	AcceptEntityInput(iParticle, "AddOutput");
	AcceptEntityInput(iParticle, "FireUser1");

	CreateTimer(1.0, Timer_Skullcutter2, iSerial);

	return Plugin_Stop;

}

public Action Timer_Skullcutter2(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	TF2Attrib_RemoveByDefIndex(client, ATTRIB_TAUNT);
	CreateTimer(0.1, Timer_Skullcutter3, iSerial);

	return Plugin_Stop;

}

public Action Timer_Skullcutter3(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	bSecond[client] = true;
	float fPos[3], fAng[3], fFwd[3];
	GetClientAbsOrigin(client, fPos);
	GetClientAbsAngles(client, fAng);
	fAng[0] = 0.0;
	GetAngleVectors(fAng, fFwd, NULL_VECTOR, NULL_VECTOR);
	
	float fSize = Resize_GetBody(client);
	fPos[0] += fSize*RANGE_SKULLCUT*fFwd[0];
	fPos[1] += fSize*RANGE_SKULLCUT*fFwd[1];
	CreateExplosion(fPos, client);

	Handle hInfoArray = CreateArray();
	PushArrayCell(hInfoArray, iSerial);
	PushArrayCell(hInfoArray, 2);
	PushArrayCell(hInfoArray, fPos[0]);
	PushArrayCell(hInfoArray, fPos[1]);
	PushArrayCell(hInfoArray, fPos[2]);
	PushArrayCell(hInfoArray, fFwd[0]);
	PushArrayCell(hInfoArray, fFwd[1]);

	CreateTimer(0.15, Timer_Skullcutter4, hInfoArray);

	return Plugin_Stop;

}

public Action Timer_Skullcutter4(Handle hTimer, Handle hThisInfoArray){

	int iRepeats = GetArrayCell(hThisInfoArray, 1);
	if(iRepeats > 5){
	
		delete hThisInfoArray;
		return Plugin_Stop;
	
	}

	int iSerial = GetArrayCell(hThisInfoArray, 0);

	float fPos[3], fFwd[3];
	fPos[0] = GetArrayCell(hThisInfoArray, 2);
	fPos[1] = GetArrayCell(hThisInfoArray, 3);
	fPos[2] = GetArrayCell(hThisInfoArray, 4);
	fFwd[0] = GetArrayCell(hThisInfoArray, 5);
	fFwd[1] = GetArrayCell(hThisInfoArray, 6);

	fPos[0] += RANGE_SKULLCUT*fFwd[0]*iRepeats;
	fPos[1] += RANGE_SKULLCUT*fFwd[1]*iRepeats;
	CreateExplosion(fPos, GetClientFromSerial(iSerial));
	delete hThisInfoArray;

	Handle hInfoArray = CreateArray();
	PushArrayCell(hInfoArray, iSerial);
	PushArrayCell(hInfoArray, ++iRepeats);
	PushArrayCell(hInfoArray, fPos[0]);
	PushArrayCell(hInfoArray, fPos[1]);
	PushArrayCell(hInfoArray, fPos[2]);
	PushArrayCell(hInfoArray, fFwd[0]);
	PushArrayCell(hInfoArray, fFwd[1]);

	CreateTimer(0.15, Timer_Skullcutter4, hInfoArray);

	return Plugin_Stop;

}

public Action Timer_Oblooterated1(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return Plugin_Stop;

	int iTeam = GetClientTeam(client);

	float fPos[3], fAng[3];
	GetClientAbsOrigin(client, fPos);

	fPos[2] += 128.0;
	RandomizeAng(fAng);

	FireTeamRocket(fPos, fAng, client, iTeam, _, _, true);

	Handle hInfoArray = CreateArray();
	PushArrayCell(hInfoArray, iSerial);
	PushArrayCell(hInfoArray, iTeam);
	PushArrayCell(hInfoArray, 1);

	CreateTimer(0.1, Timer_Oblooterated2, hInfoArray);

	return Plugin_Stop;

}

public Action Timer_Oblooterated2(Handle hTimer, Handle hThisInfoArray){

	int iSerial = GetArrayCell(hThisInfoArray, 0);
	int client = GetClientFromSerial(iSerial);
	int iTeam = GetArrayCell(hThisInfoArray, 1);

	float fPos[3], fAng[3];
	GetClientAbsOrigin(client, fPos);

	fPos[2] += 128.0;
	RandomizeAng(fAng);

	FireTeamRocket(fPos, fAng, client, iTeam, _, _, true);

	int iRepeats = GetArrayCell(hThisInfoArray, 2);
	delete hThisInfoArray;

	if(iRepeats > 56)
		return Plugin_Stop;

	Handle hInfoArray = CreateArray();
	PushArrayCell(hInfoArray, iSerial);
	PushArrayCell(hInfoArray, iTeam);
	PushArrayCell(hInfoArray, ++iRepeats);

	CreateTimer(0.01, Timer_Oblooterated2, hInfoArray);

	return Plugin_Stop;

}

public Action Timer_OnChargeTick(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!bInCharge[client])
		return Plugin_Stop;

	float fPos[3], fVel[3];
	GetClientAbsOrigin(client, fPos);

	fPos[2] += 48.0;
	RandomizeAng(fVel, 0.7);

	SpawnPipe(fPos, client, GetClientTeam(client), fVel);

	return Plugin_Continue;

}

public Action Timer_SkullcutterTaunt1(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return Plugin_Stop;

	float fPos[3], fAng[3];
	GetClientAbsOrigin(client, fPos);
	GetClientEyeAngles(client, fAng);
	fPos[2] += 56.0;

	fAng[0] += GetRandomFloat(-5.0, 5.0);
	fAng[1] += GetRandomFloat(-5.0, 5.0);

	float fVel[3];
	GetAngleVectors(fAng, fVel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVel, GetRandomFloat(1848.0, 2248.0));

	SpawnPipe(fPos, client, GetClientTeam(client), fVel);

	CreateTimer(0.1, Timer_SkullcutterTaunt2, iSerial, TIMER_REPEAT);

	return Plugin_Stop;

}

public Action Timer_SkullcutterTaunt2(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	if(!bIsBoss[client])
		return Plugin_Stop;

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		return Plugin_Stop;

	float fPos[3], fAng[3];
	GetClientAbsOrigin(client, fPos);
	GetClientEyeAngles(client, fAng);
	fPos[2] += 56.0;

	fAng[0] += GetRandomFloat(-5.0, 5.0);
	fAng[1] += GetRandomFloat(-5.0, 5.0);

	float fVel[3];
	GetAngleVectors(fAng, fVel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVel, 2048.0);

	SpawnPipe(fPos, client, GetClientTeam(client), fVel);

	return Plugin_Continue;

}


//---[ M O V E S ]---//

void SmashSurroundings(int client){

	float fPos[3], fAng[3], fFwd[3];
	GetClientAbsOrigin(client, fPos);
	GetClientAbsAngles(client, fAng);
	fAng[0] = 0.0;
	GetAngleVectors(fAng, fFwd, NULL_VECTOR, NULL_VECTOR);
	
	float fSize = Resize_GetBody(client);
	fPos[0] += fSize*RANGE_STONE*fFwd[0];
	fPos[1] += fSize*RANGE_STONE*fFwd[1];

	int iShaker = CreateEntityByName("env_shake");
	if(iShaker != -1){
	
		DispatchKeyValue(iShaker, "amplitude", "10");
		DispatchKeyValue(iShaker, "radius", "1500");
		DispatchKeyValue(iShaker, "duration", "1");
		DispatchKeyValue(iShaker, "frequency", "2.5");
		DispatchKeyValue(iShaker, "spawnflags", "4");
		DispatchKeyValueVector(iShaker, "origin", fPos);
		
		DispatchSpawn(iShaker);
		AcceptEntityInput(iShaker, "StartShake");
		
		SetVariantString("OnUser1 !self:Kill::1.0:1");
		AcceptEntityInput(iShaker, "AddOutput");
		AcceptEntityInput(iShaker, "FireUser1");
	
	}
	
	float fTrgPos[3], fVec[3], fAngBuff[3];
	float fTrgDist = 0.0;
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(i == client)
			continue;
		
		GetClientAbsOrigin(i, fTrgPos);
		fTrgDist = GetVectorDistance(fPos, fTrgPos);
		
		if(fTrgDist <= 512.0){
		
			MakeVectorFromPoints(fPos, fTrgPos, fVec);
			GetVectorAngles(fVec, fAngBuff);
			fAngBuff[0] -= 30.0;
			GetAngleVectors(fAngBuff, fVec, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(fVec, fVec);
			ScaleVector(fVec, 500.0);
			fVec[2] += 250.0;
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, fVec);
		
		}
		
		if(fTrgDist <= 230.0)
			SDKHooks_TakeDamage(i, 0, client, 3*fTrgDist, DMG_CLUB|DMG_ALWAYSGIB|DMG_BLAST);
	
	}
	
	EmitSoundToAll(SOUND_IMPACT, client);
	CreateParticle("hammer_impact_button", fPos);

}

void SmashFeet(int client){

	float fPos[3];
	GetClientAbsOrigin(client, fPos);
	
	int iShaker = CreateEntityByName("env_shake");
	if(iShaker != -1){
	
		DispatchKeyValue(iShaker, "amplitude", "10");
		DispatchKeyValue(iShaker, "radius", "1500");
		DispatchKeyValue(iShaker, "duration", "1");
		DispatchKeyValue(iShaker, "frequency", "2.5");
		DispatchKeyValue(iShaker, "spawnflags", "4");
		DispatchKeyValueVector(iShaker, "origin", fPos);
		
		DispatchSpawn(iShaker);
		AcceptEntityInput(iShaker, "StartShake");
		
		SetVariantString("OnUser1 !self:Kill::1.0:1");
		AcceptEntityInput(iShaker, "AddOutput");
		AcceptEntityInput(iShaker, "FireUser1");
	
	}
	
	float fTrgPos[3], fVec[3], fAngBuff[3];
	float fTrgDist = 0.0;
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(i == client)
			continue;
		
		GetClientAbsOrigin(i, fTrgPos);
		fTrgDist = GetVectorDistance(fPos, fTrgPos);
		
		if(fTrgDist <= 512.0){
		
			MakeVectorFromPoints(fPos, fTrgPos, fVec);
			GetVectorAngles(fVec, fAngBuff);
			fAngBuff[0] -= 30.0;
			GetAngleVectors(fAngBuff, fVec, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(fVec, fVec);
			ScaleVector(fVec, 500.0);
			fVec[2] += 250.0;
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, fVec);
		
		}
		
		if(fTrgDist <= 230.0)
			SDKHooks_TakeDamage(i, 0, client, 3*fTrgDist, DMG_CLUB|DMG_ALWAYSGIB|DMG_BLAST);
	
	}
	
	CreateParticle("hammer_impact_button", fPos);
	EmitSoundToAll(sLandSound[GetRandomInt(0, 2)], client);

}

void CreateExplosion(float fPos[3], int client=0){

	int iEnt = CreateEntityByName("info_particle_system");
	if(!IsValidEntity(iEnt))
		return;

	TeleportEntity(iEnt, fPos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(iEnt, "effect_name", PART_EXPLOSION);
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	AcceptEntityInput(iEnt, "start");
	SetVariantString("OnUser1 !self:Kill::8:-1");
	AcceptEntityInput(iEnt, "AddOutput");
	AcceptEntityInput(iEnt, "FireUser1");
	EmitAmbientSound(SOUND_EXPLOSION, fPos, _, SNDLEVEL_SCREAMING);

	float fTrgPos[3], fVec[3], fAngBuff[3];
	float fTrgDist = 0.0;
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(i == client)
			continue;
		
		GetClientAbsOrigin(i, fTrgPos);
		fTrgDist = GetVectorDistance(fPos, fTrgPos);
		
		if(fTrgDist <= 512.0){
		
			MakeVectorFromPoints(fPos, fTrgPos, fVec);
			GetVectorAngles(fVec, fAngBuff);
			fAngBuff[0] -= 30.0;
			GetAngleVectors(fAngBuff, fVec, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(fVec, fVec);
			ScaleVector(fVec, 500.0);
			fVec[2] += 250.0;
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, fVec);
		
			if(fTrgDist <= 230.0)
				SDKHooks_TakeDamage(i, 0, client, 3*fTrgDist, DMG_CLUB|DMG_ALWAYSGIB|DMG_BLAST);
		
		}
	
	}

}


//---[ S T O C K S ]---//

stock int IsNotAdmin(int client){

	return view_as<int>(!CheckCommandAccess(client, "", ADMFLAG_SLAY, true));

}

stock void SetNotarget(int iEnt, bool bApply){

	SetEntityFlags(iEnt, bApply ? GetEntityFlags(iEnt)|FL_NOTARGET : GetEntityFlags(iEnt)&~FL_NOTARGET);

}

stock void CreateParticle(char[] particle, float pos[3]){

	int tblidx	= FindStringTable("ParticleEffectNames");
	char tmp[256];
	int count	= GetStringTableNumStrings(tblidx);
	int stridx	= INVALID_STRING_INDEX;
	
	for(int i = 0; i < count; i++){
	
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if(StrEqual(tmp, particle, false)){
		
			stridx = i;
			break;
		
		}
	
	}
	
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsValidEntity(i))
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		TE_Start("TFParticleEffect");
		TE_WriteFloat("m_vecOrigin[0]", pos[0]);
		TE_WriteFloat("m_vecOrigin[1]", pos[1]);
		TE_WriteFloat("m_vecOrigin[2]", pos[2]);
		TE_WriteNum("m_iParticleSystemIndex", stridx);
		TE_WriteNum("entindex", -1);
		TE_WriteNum("m_iAttachType", 2);
		TE_SendToClient(i, 0.0);
	
	}

}

stock void SaveClientDefaultSpeed(int client){

	switch(TF2_GetPlayerClass(client)){
	
		case TFClass_Scout:		{fDefSpd[client] = 400.0;}
		case TFClass_Soldier:	{fDefSpd[client] = 240.0;}
		case TFClass_DemoMan:	{fDefSpd[client] = 280.0;}
		case TFClass_Heavy:		{fDefSpd[client] = 230.0;}
		case TFClass_Medic:		{fDefSpd[client] = 320.0;}
	
	}

}

stock void Colorize(int client, int iColor[4]){

	SetEntityColor(client, iColor);
	
	for(int i = 0; i < 3; i++){
	
		int iWeapon = GetPlayerWeaponSlot(client, i);
		
		if(iWeapon > MaxClients && IsValidEntity(iWeapon))
			SetEntityColor(iWeapon, iColor);
		
	}
	
	char sClass[20];
	int iMaxEnt = GetMaxEntities();
	for(int i = MaxClients+1; i < iMaxEnt; i++){
	
		if(!IsValidEntity(i))
			continue;
		
		GetEdictClassname(i, sClass, sizeof(sClass));
		
		if((strncmp(sClass, "tf_wearable", 11) == 0
		|| strncmp(sClass, "tf_powerup", 10) == 0)
		&& GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client)
			SetEntityColor(i, iColor);
	
	}

	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
	if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		SetEntityColor(iWeapon, iColor);

}

stock void SetEntityColor(int iEnt, int iColor[4]){

	SetEntityRenderMode(iEnt, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEnt, iColor[0], iColor[1], iColor[2], iColor[3]);

}

stock bool IsClientAdmin(int client){

	return CheckCommandAccess(client, "", ADMFLAG_SLAY, true);

}

stock bool IsValidClient(int client){

	if(client > 4096)
		client = EntRefToEntIndex(client);

	if(client < 1 || client > MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(IsFakeClient(client))
		return false;
	
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;
	
	return true;

}

stock int CreateAndAttachParticle(int iClient, char[] strParticle, bool bAttach=true, char[] strAttachmentPoint="", float fOffset[3]={0.0, 0.0, 36.0}){

	//Thanks J-Factor for CreateParticle()

	int iParticle = CreateEntityByName("info_particle_system");
	if(!IsValidEdict(iParticle)) return 0;

	float fPosition[3], fAngles[3], fForward[3], fRight[3], fUp[3];

	GetClientAbsOrigin(iClient, fPosition);
	GetClientAbsAngles(iClient, fAngles);

	GetAngleVectors(fAngles, fForward, fRight, fUp);
	fPosition[0] += fRight[0]*fOffset[0] + fForward[0]*fOffset[1] + fUp[0]*fOffset[2];
	fPosition[1] += fRight[1]*fOffset[0] + fForward[1]*fOffset[1] + fUp[1]*fOffset[2];
	fPosition[2] += fRight[2]*fOffset[0] + fForward[2]*fOffset[1] + fUp[2]*fOffset[2];

	TeleportEntity(iParticle, fPosition, fAngles, NULL_VECTOR);
	DispatchKeyValue(iParticle, "effect_name", strParticle);

	if(bAttach){

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", iClient, iParticle, 0);

		if(!StrEqual(strAttachmentPoint, "")){

			SetVariantString(strAttachmentPoint);
			AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset", iParticle, iParticle, 0);

		}

	}

	DispatchSpawn(iParticle);
	ActivateEntity(iParticle);
	AcceptEntityInput(iParticle, "Start");

	return iParticle;

}

stock void RandomizeAng(float fAng[3], float fIntensity=1.0){

	int i = 0;
	while(i < 3)
		fAng[i++] = GetURandomFloat()*360.0*fIntensity;

}

stock void DisplayDamageDealers(int client){

	int iSize = GetArraySize(hBossDamagers[client]) -1;
	bool bSwapped = true;
	while(bSwapped){
	
		bSwapped = false;
		for(int i = 0; i < iSize; i++)
			if(GetArrayCell(hBossDamage[client], i) < GetArrayCell(hBossDamage[client], i+1)){
			
				SwapArrayItems(hBossDamage[client], i, i+1);
				SwapArrayItems(hBossDamagers[client], i, i+1);
				bSwapped = true;
			
			}
	
	}

	if(iSize > 4)
		iSize = 5;
	else iSize++;

	PrintToChatAll("%s Top 5 Damage Dealers to \x03%N\x01:", CHAT_PREFIX, client);
	int iPlayer = 0;
	for(int i = 0; i < iSize; i++){
	
		iPlayer = GetClientFromSerial(GetArrayCell(hBossDamagers[client], i));
		if(iPlayer < 1)
			PrintToChatAll("\x01    %d. \x03<unknown>\x01: %d", i+1, GetArrayCell(hBossDamage[client], i));
		else
			PrintToChatAll("\x01    %d. \x03%N\x01: %d", i+1, iPlayer, GetArrayCell(hBossDamage[client], i));

	}

}

//---[ R O C K E T ]---//

stock int FireTeamRocket(float fPos[3], float fAng[3], int iOwner=0, int iTeam=2, float fSpeed=1100.0, float fDamage=90.0, bool bCrit=false, int iWeapon=-1){

	int iRocket = CreateEntityByName("tf_projectile_rocket");
	if(!IsValidEntity(iRocket))
		return -1;

	float fVel[3]; // Determine velocity based on given speed/angle
	GetAngleVectors(fAng, fVel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVel, fSpeed);

	SetEntProp(iRocket, Prop_Send, "m_bCritical", bCrit);

	SetRocketDamage(iRocket, fDamage);

	SetEntProp(iRocket, Prop_Send, "m_nSkin", iTeam -2); // 0 = RED 1 = BLU
	SetEntProp(iRocket, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetVariantInt(iTeam);
	AcceptEntityInput(iRocket, "TeamNum");
	SetVariantInt(iTeam);
	AcceptEntityInput(iRocket, "SetTeam");

	if(iOwner != -1)
		SetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity", iOwner);

	TeleportEntity(iRocket, fPos, fAng, fVel);
	DispatchSpawn(iRocket);

	if(iWeapon != -1){
	
		SetEntPropEnt(iRocket, Prop_Send, "m_hOriginalLauncher", iWeapon);
		SetEntPropEnt(iRocket, Prop_Send, "m_hLauncher", iWeapon);
	
	}

	return iRocket;

}

static int s_iRocketDmgOffset = -1;

stock void SetRocketDamage(int iRocket, float fDamage){

	if(s_iRocketDmgOffset == -1)
		s_iRocketDmgOffset = FindSendPropOffs("CTFProjectile_Rocket", "m_iDeflected") +4; // Credit to voogru

	SetEntDataFloat(iRocket, s_iRocketDmgOffset, fDamage, true);

}

stock float GetRocketDamage(iRocket){

	if(s_iRocketDmgOffset == -1)
		s_iRocketDmgOffset = FindSendPropOffs("CTFProjectile_Rocket", "m_iDeflected") +4; // Credit to voogru

	return GetEntDataFloat(iRocket, s_iRocketDmgOffset);

}

//---[ P I L L ]---//

stock int SpawnPipe(float fPos[3], int iOwner=0, int iTeam=2, float fVel[3]={0.0, 0.0, 0.0}){

	int iPipe = CreateEntityByName("tf_projectile_pipe");
	if(!IsValidEntity(iPipe))
		return -1;

	SetEntProp(iPipe, Prop_Send, "m_bCritical", 1);

	SetEntProp(iPipe, Prop_Send, "m_iTeamNum", iTeam);
	SetEntPropFloat(iPipe, Prop_Send, "m_flDamage", 90.0);

	if(iOwner != -1)
		SetEntPropEnt(iPipe, Prop_Send, "m_hThrower", iOwner);

	DispatchSpawn(iPipe);
	TeleportEntity(iPipe, fPos, NULL_VECTOR, fVel);

	return iPipe;

}