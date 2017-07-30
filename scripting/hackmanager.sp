#pragma semicolon 1

#include <sourcemod>
#include <basecomm>
#include <tf2>
#include <sdkhooks>
#include <sdktools_functions>

#undef REQUIRE_PLUGIN
#include <rtd>
#include <rtd2>
#include <friendly>
#include <friendlysimple>
#include <goomba>

#define FIVE_MINS 300
#define RENAME_TO "BeardedBasementDwellingHaxxor"

public Plugin myinfo = {

	name = "Hack Manager",
	author = "Phil25",
	description = "Provides tools for dealing with hackers."

};


bool g_bIsHacker[MAXPLAYERS+1]	= {false, ...};
int g_iNameStamp[MAXPLAYERS+1]	= {0, ...};
int g_iJoinStamp[MAXPLAYERS+1]	= {0, ...};
char g_sOrigName[MAXPLAYERS+1][MAX_NAME_LENGTH];
int g_iMarkedBy[MAXPLAYERS+1] = {0, ...};
float g_fDeathPos[MAXPLAYERS+1][3];
float g_fDeathAng[MAXPLAYERS+1][3];



//***********************//
//  -  G E N E R A L  -  //
//***********************//

public void OnPluginStart(){

	LoadTranslations("common.phrases.txt");

	RegAdminCmd("sm_hacker", Command_Hacker, ADMFLAG_BAN);
	RegAdminCmd("sm_unhacker", Command_Unhacker, ADMFLAG_BAN);
	
	RegAdminCmd("sm_steamid", Command_SteamID, ADMFLAG_SLAY);
	RegAdminCmd("sm_sid", Command_SteamID, ADMFLAG_SLAY);
	
	RegAdminCmd("sm_userid", Command_UserID, ADMFLAG_SLAY);
	RegAdminCmd("sm_uid", Command_UserID, ADMFLAG_SLAY);

	RegAdminCmd("sm_playerip", Command_PlayerIP, ADMFLAG_SLAY);
	RegAdminCmd("sm_ip", Command_PlayerIP, ADMFLAG_SLAY);
	
	AddMultiTargetFilter("@recentname", TargetFilter_RecentName, "Players who had changed their name in last 5 mins.", false);
	AddMultiTargetFilter("@recentnames", TargetFilter_RecentName, "Players who had changed their name in last 5 mins.", false);
	AddMultiTargetFilter("@recentnamechanges", TargetFilter_RecentName, "Players who had changed their name in last 5 mins.", false);
	
	AddMultiTargetFilter("@recentjoin", TargetFilter_RecentJoin, "Players who had joined in last 5 mins.", false);
	AddMultiTargetFilter("@recentjoins", TargetFilter_RecentJoin, "Players who had joined in last 5 mins.", false);
	
	AddMultiTargetFilter("@hackers", TargetFilter_Hackers, "Players who are marked as hackers.", false);
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_changename", Event_OnNameChange);
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			SDKHook(i, SDKHook_OnTakeDamage, Event_OnTakeDamage);

	AddCommandListener(Event_OnCommandBlock, "kill");
	AddCommandListener(Event_OnCommandBlock, "explode");
	AddCommandListener(Event_OnCommandBlock, "jointeam");

}

public void OnPluginEnd(){

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			if(g_bIsHacker[i])
				HackerSet(i, false);

}

public void OnClientPutInServer(int client){

	SDKHook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
	g_iJoinStamp[client] = GetTime();
	g_iNameStamp[client] = 0;

}

public void OnClientDisconnect(int client){

	if(!g_bIsHacker[client])
		return;

	g_bIsHacker[client] = false;

	char sSteamId[32], sIp[16];
	GetClientAuthId(client, AuthId_Steam2, sSteamId, 32);
	GetClientIP(client, sIp, 16);

	int iAdmin = GetClientFromSerial(g_iMarkedBy[client]);
	if(iAdmin == 0)
		PrintToServer("[SM] Player marked as hacker has left the server:\nName: %N\nSteamID32: %s\nIP: %s\nBanned automatically.", client, sSteamId, sIp);

	else
		PrintToChat(iAdmin, "\x04[SM]\x01 Player you've marked as hacker has left the server:\n\x03Name\x01: %s\n\x03SteamID32\x01: %s\n\x03IP\x01: %s\nBanned Automatically.", g_sOrigName[client], sSteamId, sIp);

	ServerCommand("sm_addban 0 \"%s\" Cheating", sSteamId);
	ServerCommand("sm_banip \"%s\" 0 Cheating", sIp);

}



//*************************************//
//  -  T A R G E T   F I L T E R S  -  //
//*************************************//

public bool TargetFilter_RecentName(const char[] sPattern, Handle hClients){

	int iTimestamp = GetTime() -FIVE_MINS;
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
	
		if(g_iNameStamp[i] > iTimestamp)
			PushArrayCell(hClients, i);
	
	}
	
	return (GetArraySize(hClients) != 0);

}

public bool TargetFilter_RecentJoin(const char[] sPattern, Handle hClients){

	int iTimestamp = GetTime() -FIVE_MINS;
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
	
		if(g_iJoinStamp[i] > iTimestamp)
			PushArrayCell(hClients, i);
	
	}
	
	return (GetArraySize(hClients) != 0);

}

public bool TargetFilter_Hackers(const char[] sPattern, Handle hClients){

	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
	
		if(g_bIsHacker[i])
			PushArrayCell(hClients, i);
	
	}
	
	return (GetArraySize(hClients) != 0);

}



//*************************//
//  -  C O M M A N D S  -  //
//*************************//

public Action Command_PlayerIP(int client, int args){

	if(args < 1){

		ReplyToCommand(client, "[SM] Usage: sm_playerip <player>");
		return Plugin_Handled;

	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}
	
	char sIp[32];
	for(int i = 0; i < iTrgCount; i++){
	
		GetClientIP(aTrgList[i], sIp, 32);
		PrintToConsole(client, "• %N", aTrgList[i]);
		PrintToConsole(client, "%s", sIp);
	
	}
	
	if(client != 0)
		PrintToChat(client, "[SM] Selected player(s) IP printed to your console.");
	
	return Plugin_Handled;

}

public Action Command_SteamID(int client, int args){

	if(args < 1){

		ReplyToCommand(client, "[SM] Usage: sm_steamid <player>");
		return Plugin_Handled;

	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	char sSteamId32[32], sSteamId64[64];
	for(int i = 0; i < iTrgCount; i++){
	
		GetClientAuthId(aTrgList[i], AuthId_Steam2, sSteamId32, 32);
		GetClientAuthId(aTrgList[i], AuthId_SteamID64, sSteamId64, 64);
	
		PrintToConsole(client, "• %N", aTrgList[i]);
		PrintToConsole(client, "%s", sSteamId32);
		PrintToConsole(client, "%s", sSteamId64);
	
	}

	if(client != 0)
		PrintToChat(client, "[SM] Selected player(s) UserIDs printed to your console.");

	return Plugin_Handled;

}

public Action Command_UserID(int client, int args){

	if(args < 1){

		ReplyToCommand(client, "[SM] Usage: sm_userid <player>");
		return Plugin_Handled;

	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}
	
	for(int i = 0; i < iTrgCount; i++){
	
		PrintToConsole(client, "• %N", aTrgList[i]);
		PrintToConsole(client, "%d", GetClientUserId(aTrgList[i]));
	
	}
	
	if(client != 0)
		PrintToChat(client, "[SM] Selected player(s) UserIDs printed to your console.");
	
	return Plugin_Handled;

}

public Action Command_Hacker(int client, int args){

	if(args < 1){

		ReplyToCommand(client, "[SM] Usage: sm_hacker <player>");
		return Plugin_Handled;

	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	int iSerial = client == 0 ? 0 : GetClientSerial(client);
	for(int i = 0; i < iTrgCount; i++){
	
		HackerSet(aTrgList[i]);
		g_iMarkedBy[aTrgList[i]] = iSerial;
		ReplyToCommand(client, "[SM] Player %N has been marked as a hacker.", aTrgList[i]);
	
	}

	return Plugin_Handled;

}

public Action Command_Unhacker(int client, int args){

	if(args < 1){

		ReplyToCommand(client, "[SM] Usage: sm_unhacker <player>");
		return Plugin_Handled;

	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}
	
	for(int i = 0; i < iTrgCount; i++){
	
		HackerSet(aTrgList[i], false);
		ReplyToCommand(client, "[SM] Player %N has been unmarked as a hacker.", aTrgList[i]);
	
	}
	
	return Plugin_Handled;

}



//*********************//
//  -  E V E N T S  -  //
//*********************//

public Action Event_OnTakeDamage(int iVictim, int &iAttacker){

	if(iVictim < 1 || iVictim > MaxClients)
		return Plugin_Continue;

	if(iAttacker < 1 || iAttacker > MaxClients)
		return Plugin_Continue;

	return HackerAction(iAttacker);

}

public Action Event_OnPlayerSpawn(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client != 0 && g_bIsHacker[client])
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);

	return Plugin_Continue;

}

public Action Event_OnPlayerDeath(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int iUserId = GetEventInt(hEvent, "userid");
	int client = GetClientOfUserId(iUserId);
	if(client == 0)
		return Plugin_Continue;

	if(!g_bIsHacker[client])
		return Plugin_Continue;

	GetClientAbsOrigin(client, g_fDeathPos[client]);
	GetClientAbsAngles(client, g_fDeathAng[client]);
	CreateTimer(0.0, Timer_OnPlayerDeathPost, iUserId);

	return Plugin_Continue;

}

public Action Timer_OnPlayerDeathPost(Handle hTimer, int iUserId){

	int client = GetClientOfUserId(iUserId);
	if(client == 0)
		return Plugin_Stop;

	if(!g_bIsHacker[client])
		return Plugin_Stop;

	TF2_RespawnPlayer(client);
	TeleportEntity(client, g_fDeathPos[client], g_fDeathAng[client], NULL_VECTOR);

	return Plugin_Stop;

}

public Action Event_OnNameChange(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client != 0 && IsClientInGame(client) && !IsFakeClient(client))
		g_iNameStamp[client] = GetTime();

	return Plugin_Continue;

}

public Action Event_OnCommandBlock(int client, const char[] sCmd, int args){

	return HackerAction(client);

}



//*****************//
//  -  M A I N  -  //
//*****************//

void HackerSet(int client, bool bSet=true){

	g_bIsHacker[client] = bSet;

	BaseComm_SetClientMute(client, bSet);
	BaseComm_SetClientGag(client, bSet);
	
	SetEntProp(client, Prop_Send, "m_bGlowEnabled", view_as<int>(bSet));
	int iUserId = GetClientUserId(client);
	
	if(bSet){
	
		GetClientName(client, g_sOrigName[client], MAX_NAME_LENGTH);
		ServerCommand("sm_rename #%d %s", iUserId, RENAME_TO);
	
	}else
		ServerCommand("sm_rename #%d %s", iUserId, g_sOrigName[client]);
	
	ServerCommand("namelockid %d %d", iUserId, view_as<int>(bSet));

}

Action HackerAction(int client){

	return g_bIsHacker[client] ? Plugin_Handled : Plugin_Continue;

}



//*******************//
//  -  O T H E R  -  //
//*******************//

public int FriendlySimple_OnEnableFriendly(int client){

	if(g_bIsHacker[client])
		RequestFrame(RequestFrame_DisableFriendly, GetClientSerial(client));

}

public void RequestFrame_DisableFriendly(int iSerial){

	int client = GetClientFromSerial(iSerial);

	if(client != 0)
		FriendlySimple_SetFriendly(client, 0);

}

public Action RTD2_CanRollDice(int client){

	return HackerAction(client);

}

public Action RTD_CanRollDice(int client){

	return HackerAction(client);

}

public Action TF2Friendly_CanToggleFriendly(int client){

	return HackerAction(client);

}

public Action OnStomp(int iAttacker, int iVictim, float &fDmgMultiplier, float &fDmgBonus, float &fJumpPower){

	return HackerAction(iAttacker);

}