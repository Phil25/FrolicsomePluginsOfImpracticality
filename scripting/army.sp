#pragma semicolon 1

#include <speech>
#include <resize>

#define CHAT_PREFIX "[ARMY]"

#define ARMY_DUMPLINGS 0
#define ARMY_SMALLDUMPLINGS 1
#define ARMY_PENCILS 2

bool	g_bInArmy[MAXPLAYERS+1] = {false, ...};
int		g_iArmyPreset = 0;

public Plugin myinfo = {

	name = "Army",
	author = "Phil25",
	description = "Sets armies and shit.",

};

public void OnPluginStart(){

	LoadTranslations("common.phrases.txt");

	RegAdminCmd("sm_army_set", Command_ArmySet, ADMFLAG_SLAY, "Sets army preset.");
	RegAdminCmd("sm_army_add", Command_ArmyAdd, ADMFLAG_SLAY, "Adds a player to the army.");
	RegAdminCmd("sm_army_remove", Command_ArmyRemove, ADMFLAG_SLAY, "Removes a player from the army.");
	
	AddMultiTargetFilter("@army", TargetFilter_Army, "Players in the army", false);
	AddMultiTargetFilter("@!army", TargetFilter_NotArmy, "Players in the army", false);

}

public void OnPluginEnd(){

	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
		
		if(g_bInArmy[i])
			RemoveFromArmy(i);

	}

}

public void OnClientDisconnect(int client){

	g_bInArmy[client] = false;

}

public Action Command_ArmySet(int client, int args){

	if(args < 1){
	
		ReplyToCommand(client, "%s Usage: sm_army_set <dumplings/smalldumplings/pencils>", CHAT_PREFIX);
		return Plugin_Handled;
	
	}
	
	char sSet[16];
	GetCmdArg(1, sSet, 16);
	int iSetTo = 0;
	
	if(StrEqual(sSet, "dumplings", false))
		iSetTo = 0;
	
	else if(StrEqual(sSet, "smalldumplings", false))
		iSetTo = 1;
	
	else if(StrEqual(sSet, "pencils", false))
		iSetTo = 2;
	
	if(g_iArmyPreset == iSetTo)
		return Plugin_Handled;
	
	UpdateArmyPreset(iSetTo);
	ReplyToCommand(client, "%s Army preset set to: %s", CHAT_PREFIX, sSet);
	
	return Plugin_Handled;

}

public Action Command_ArmyAdd(int client, int args){

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}
	
	for(int i = 0; i < iTrgCount; i++)
		AddToArmy(aTrgList[i]);
	
	return Plugin_Handled;

}

public Action Command_ArmyRemove(int client, int args){

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}
	
	for(int i = 0; i < iTrgCount; i++)
		RemoveFromArmy(aTrgList[i]);
	
	return Plugin_Handled;

}

void AddToArmy(int client){

	if(g_bInArmy[client])
		return;

	switch(g_iArmyPreset){
	
		case ARMY_DUMPLINGS:{
		
			Speech_Change(client, 75);
			Resize_Change(client, 0, "0.85");
			Resize_Change(client, 1, "3");
			Resize_Change(client, 2, "-0.4");
			Resize_Change(client, 3, "1.5");
		
		}
	
		case ARMY_SMALLDUMPLINGS:{
		
			Speech_Change(client, 180);
			Resize_Change(client, 0, "0.5");
			Resize_Change(client, 1, "3");
			Resize_Change(client, 2, "-0.4");
			Resize_Change(client, 3, "1.5");
		
		}
	
		case ARMY_PENCILS:{
		
			Speech_Change(client, 230);
			Resize_Change(client, 0, "0.2");
			Resize_Change(client, 1, "2");
			Resize_Change(client, 2, "12");
			Resize_Change(client, 3, "2");
		
		}
	
	}
	
	PrintToChat(client, "%s You've joined the army!", CHAT_PREFIX);
	g_bInArmy[client] = true;

}

void RemoveFromArmy(int client){

	if(!g_bInArmy[client])
		return;

	Speech_Change(client, 100);
	Resize_Reset(client);

	g_bInArmy[client] = false;

}

void UpdateArmyPreset(int iSetTo){

	g_iArmyPreset = iSetTo;
	
	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
		
		if(!g_bInArmy[i])
			continue;
		
		RemoveFromArmy(i);
		AddToArmy(i);
	
	}

}

public bool TargetFilter_Army(const char[] sPattern, Handle hClients){

	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
	
		if(g_bInArmy[i])
			PushArrayCell(hClients, i);
	
	}
	
	return true;

}

public bool TargetFilter_NotArmy(const char[] sPattern, Handle hClients){

	for(int i = 1; i <= MaxClients; i++){
	
		if(!IsClientInGame(i))
			continue;
	
		if(!g_bInArmy[i])
			PushArrayCell(hClients, i);
	
	}
	
	return true;

}