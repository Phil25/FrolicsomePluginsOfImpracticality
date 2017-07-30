#pragma semicolon 1


#include <sdkhooks>
#include <tf2_stocks>


bool g_bGod[MAXPLAYERS+1] = {false, ...};
char g_sAction[3][] = {"Toggled", "Disabled", "Enabled"};
TFCond g_CondRem[] = {TFCond_Dazed, TFCond_OnFire, TFCond_Jarated, TFCond_Bleeding, TFCond_Milked, TFCond_MarkedForDeath, TFCond_MarkedForDeathSilent};


public Plugin myinfo = {

	name = "Godmode",
	author = "Phil25",
	description = "This is THE PERFECT Godmode plugin in existance."

};


public void OnPluginStart				(){

	LoadTranslations("common.phrases");

	RegAdminCmd("sm_god", Command_God, ADMFLAG_SLAY);
	RegAdminCmd("sm_godmode", Command_God, ADMFLAG_SLAY);
	RegAdminCmd("sm_godmod", Command_God, ADMFLAG_SLAY);
	RegAdminCmd("sm_g", Command_God, ADMFLAG_SLAY);

	HookEvent("post_inventory_application", OnInventoryApplication);

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPutInServer(i);

}

public void OnClientPutInServer			(int client){

	SDKHook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);

}

public void OnClientDisconnect			(int client){

	g_bGod[client] = false;

}


public Action Command_God				(int client, int args){

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

	int iDir = -1;
	if(args > 1){
	
		char sDir[4];
		GetCmdArg(2, sDir, 4);
		iDir = StringToInt(sDir);
	
	}

	for(int i = 0; i < iTrgCount; i++)
		SetGod(aTrgList[i], iDir);

	if(iTrgCount == 1)
		ReplyToCommand(client, "[SM] Godmode %s on %N", g_bGod[aTrgList[0]] ? "enabled" : "disabled", aTrgList[0]);

	else
		ReplyToCommand(client, "[SM] %s godmode on %d players.", g_sAction[iDir+1], iTrgCount);

	return Plugin_Handled;

}

void SetGod								(int client, int iDir){

	switch(iDir){
	
		case 0:
			g_bGod[client] = false;
	
		case 1:
			g_bGod[client] = true;
	
		default:
			g_bGod[client] = !g_bGod[client];
	
	}

	SetNoTarget(client, g_bGod[client]);

}


public Action OnClientTakeDamage		(int client, int &iAtk){

	if(!g_bGod[client])
		return Plugin_Continue;

	if(client != iAtk)
		return Plugin_Handled;

	TF2_AddCondition(client, TFCond_Bonked, 0.01, client);
	return Plugin_Continue;

}

public void TF2_OnConditionAdded		(int client, TFCond Cond){

	if(!g_bGod[client])
		return;

	if(IsRemCond(Cond))
		TF2_RemoveCondition(client, Cond);

}

public Action OnInventoryApplication	(Handle hEvent, const char[] sName, bool bDontBroadcast){

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(g_bGod[client])
		SetNoTarget(client, true);

	return Plugin_Continue;

}

public void OnEntityCreated				(int iEnt, const char[] sClassname){

	if(strcmp(sClassname, "tf_projectile_flare") == 0)
		SDKHook(iEnt, SDKHook_Touch, OnFlareTouch);

}

public Action OnFlareTouch				(int iFlare, int client){

	if(!(1 <= client <= MaxClients))
		return Plugin_Continue;

	if(g_bGod[client])
		AcceptEntityInput(iFlare, "Kill");

	return Plugin_Continue;

}


stock bool IsRemCond					(TFCond Cond){

	int iSize = sizeof(g_CondRem);
	for(int i = 0; i < iSize; i++)
		if(g_CondRem[i] == Cond)
			return true;

	return false;

}

stock void SetNoTarget					(int iEnt, bool bSet){

	SetEntityFlags(iEnt, bSet ? GetEntityFlags(iEnt)|FL_NOTARGET : GetEntityFlags(iEnt)&~FL_NOTARGET);

}