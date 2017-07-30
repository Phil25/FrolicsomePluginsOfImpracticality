#pragma semicolon 1

#include <sourcemod>

#define CHAT_PREFIX "\x03[SM]\x01"
#define CONS_PREFIX "[SM]"


public Plugin myinfo = {

	name = "Fake Say 2",
	author = "Phil25",
	description = "Properly executes a fakesay."

};

public void OnPluginStart(){

	RegAdminCmd("sm_fakesay2", Command_FakeSay, ADMFLAG_SLAY, "sm_fakesay2 <client> \"<text>\"");

}

public Action Command_FakeSay(int client, int args){

	if(args < 2){
	
		if(client > 0)
			PrintToChat(client, "%s Usage: sm_fakesay2 <player> \"<text>\"", CHAT_PREFIX);
		else
			PrintToServer("%s Usage: sm_fakesay2 <player> \"<text>\"", CONS_PREFIX);
		
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
	
	char sText[255];
	GetCmdArg(2, sText, sizeof(sText));
	
	for(int i = 0; i < iTrgCount; i++)
		FakeClientCommandEx(aTrgList[i], "say %s", sText);
	
	return Plugin_Handled;

}