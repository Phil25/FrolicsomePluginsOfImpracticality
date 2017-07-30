#pragma semicolon 1

#include <sourcemod>

bool	g_bIsFuckedUp[MAXPLAYERS+1] = {false, ...};
float	g_fSpeed[MAXPLAYERS+1] = {0.25, ...};
float	g_fScale[MAXPLAYERS+1] = {1.0, ...};
float	g_fBoundsLow[MAXPLAYERS+1] = {0.0, ...};
float	g_fBoundsTop[MAXPLAYERS+1] = {3.0, ...};
float	g_fAdd[MAXPLAYERS+1] = {0.25, ...};

public void OnPluginStart(){

	RegAdminCmd("sm_wtf", Command_Wtf, ADMFLAG_SLAY, "Fuck up a player");
	RegAdminCmd("sm_unwtf", Command_UnWtf, ADMFLAG_SLAY, "Unfuck up a player");

}

public void OnClientDisconnect(int client){

	g_bIsFuckedUp[client] = false;

}

public Action Command_Wtf(int client, int args){

	if(args == 0){
	
		ReplyToCommand(client, "[SM] Usage: sm_wtf <player> <lower limit>* <upper limit>* <speed>*");
		return Plugin_Handled;
	
	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	float fLowerLimit = -1000.0;
	float fUpperLimit = -1000.0;
	float fSpeed = 0.0;
	if(args > 1){
	
		char sLowerLimit[8];
		GetCmdArg(2, sLowerLimit, 8);
		fLowerLimit = StringToFloat(sLowerLimit);
	
		if(args > 2){
		
			char sUpperLimit[8];
			GetCmdArg(3, sUpperLimit, 8);
			fUpperLimit = StringToFloat(sUpperLimit);
		
			if(args > 3){
			
				char sSpeed[8];
				GetCmdArg(4, sSpeed, 8);
				fSpeed = StringToFloat(sSpeed);
				if(fSpeed < 0.0)
					fSpeed = 0.0;
			
			}
		
		}
	
	}

	for(int i = 0; i < iTrgCount; i++){
	
		if(fLowerLimit != -1000.0)
			g_fBoundsLow[aTrgList[i]] = fLowerLimit;
	
		if(fUpperLimit != -1000.0)
			g_fBoundsTop[aTrgList[i]] = fUpperLimit;
	
		if(fSpeed != 0.0)
			g_fSpeed[aTrgList[i]] = fSpeed;
	
		g_bIsFuckedUp[aTrgList[i]] = true;

	}

	ReplyToCommand(client, "[SM] Fucked up %d player%s", iTrgCount, iTrgCount == 1 ? "" : "s");

	return Plugin_Handled;

}

public Action Command_UnWtf(int client, int args){

	if(args == 0){
	
		ReplyToCommand(client, "[SM] Usage: sm_unwtf <player>");
		return Plugin_Handled;
	
	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	int iCount = 0;
	for(int i = 0; i < iTrgCount; i++){
	
		iCount += view_as<int>(g_bIsFuckedUp[aTrgList[i]]);
		g_bIsFuckedUp[aTrgList[i]] = false;
	
	}

	ReplyToCommand(client, "[SM] Unfucked up %d player%s", iCount, iCount == 1 ? "" : "s");

	return Plugin_Handled;

}

public void OnGameFrame(){

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && g_bIsFuckedUp[i])
			FuckItUp(i);

}

void FuckItUp(int client){

	if(g_fScale[client] > g_fBoundsTop[client])
		g_fAdd[client] = -g_fSpeed[client];
	else if(g_fScale[client] < g_fBoundsLow[client])
		g_fAdd[client] = g_fSpeed[client];

	g_fScale[client] += g_fAdd[client];
	SetEntPropFloat(client, Prop_Send, "m_flTorsoScale", g_fScale[client]);

}