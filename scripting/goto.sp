#pragma semicolon 1

#include <sdktools>

public Plugin myinfo = {

	name = "Go To",
	author = "Phil25",
	description = "Allows admins to teleport to a target.",

};

public void OnPluginStart(){

	RegAdminCmd("sm_goto", Command_TeleToTarget, ADMFLAG_SLAY, "Teleport to selected player");
	RegAdminCmd("sm_tpto", Command_TeleToTarget, ADMFLAG_SLAY, "Teleport to selected player");

}

public Action Command_TeleToTarget(int client, int args){

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, sizeof(sTrg));

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}
	
	if(iTrgCount > 1){
	
		ReplyToCommand(client, "[SM] You can choose only one player.");
		return Plugin_Handled;
	
	}
	
	int iTrg = aTrgList[0];
	
	if(!IsPlayerAlive(iTrg)){
	
		ReplyToCommand(client, "[SM] Target is dead.");
		return Plugin_Handled;
	
	}
	
	float fPos[3];
	GetClientAbsOrigin(iTrg, fPos);
	
	TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);

	return Plugin_Handled;

}