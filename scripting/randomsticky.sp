#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

bool g_bHasRandomStickies[MAXPLAYERS+1] = {false, ...};


public Plugin myinfo = {

	name		= "Sticky Size Randomizer",
	author		= "Phil25",
	description	= "Randomizes size of stickies of particular players."

};

public void OnPluginStart(){

	LoadTranslations("common.phrases.txt");

	RegAdminCmd("sm_randomsticky", Command_RandomizeStickies, ADMFLAG_SLAY, "Randomize sticky sizes for a player");

}

public Action Command_RandomizeStickies(int client, int args){

	if(args < 2){

		ReplyToCommand(client, "[SM] Usage: sm_randomsticky <player> <1/0>");
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
	
	char sEnable[8];
	GetCmdArg(2, sEnable, 8);
	bool bEnable = view_as<bool>(StringToInt(sEnable));
	
	if(bEnable){
	
		PrintToChatAll("Enabling");
		for(int i = 0; i < iTrgCount; i++)
			g_bHasRandomStickies[aTrgList[i]] = true;
	
	}else{
	
		PrintToChatAll("Disabling");
		for(int i = 0; i < iTrgCount; i++)
			g_bHasRandomStickies[aTrgList[i]] = false;
	
	}
	
	return Plugin_Handled;

}

public void OnClientDisconnect(int client){

	g_bHasRandomStickies[client] = false;

}

public void OnEntityCreated(int iEnt, const char[] sClassname){

	if(StrEqual(sClassname, "tf_projectile_pipe_remote"))
		SDKHook(iEnt, SDKHook_SpawnPost, OnStickySpawn);

}

public void OnStickySpawn(int iSticky){
	
	int iOwner = GetEntPropEnt(iSticky, Prop_Send, "m_hThrower");
	
	PrintToChatAll("Owner: %d", iOwner);
	if(iOwner > 0 && iOwner <= MaxClients)
		if(g_bHasRandomStickies[iOwner])
			SetEntPropFloat(iSticky, Prop_Send, "m_flModelScale", GetRandomFloat(0.25, 4.0));

}