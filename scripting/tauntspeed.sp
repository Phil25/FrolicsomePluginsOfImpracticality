#pragma semicolon 1

#include <sourcemod>
#include <tf2attributes>
#include <tf2>
#include <tauntspeed>

#define ATTRIB_TAUNT 201

bool g_bHasTauntSpeedSet[MAXPLAYERS+1] = {false, ...};


public APLRes AskPluginLoad2	(Handle hMyself, bool bLate, char[] sError, int iErrorSize){

	CreateNative("TauntSpeed_Set", Native_SetTauntSpeed);

	return APLRes_Success;

}

public void OnPluginStart(){

	RegAdminCmd("sm_tauntspeed", Command_TauntSpeedSet, ADMFLAG_SLAY);

}

public void OnPluginEnd(){

	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			if(g_bHasTauntSpeedSet[i])
				TF2Attrib_RemoveByDefIndex(i, ATTRIB_TAUNT);

}

public void OnClientDisconnect(client){
	
	g_bHasTauntSpeedSet[client] = false;

}

public Action Command_TauntSpeedSet(client, args){

	if(args < 2){

		ReplyToCommand(client, "[SM] Usage: sm_tauntspeed <player> <value>");
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

	char sValue[8];
	GetCmdArg(2, sValue, sizeof(sValue));
	float fValue = StringToFloat(sValue);
	
	switch(fValue){
	
		case 0.0, 1.0:{
	
			int iCount = 0;
			for(int i = 0; i < iTrgCount; i++){
	
				if(!g_bHasTauntSpeedSet[aTrgList[i]])
					continue;
				
				TF2Attrib_RemoveByDefIndex(aTrgList[i], ATTRIB_TAUNT);
				g_bHasTauntSpeedSet[aTrgList[i]] = false;
				
				PrintToChat(aTrgList[i], "\x01[SM] Your taunt speed was \x03reset\x01.");
				iCount++;
			
			}
			
			if(client == 0)
				PrintToServer("[SM] Taunt speed reset for %d players.", iCount);
			else
				PrintToChat(client, "\x01[SM] Taunt speed reset for \x03%d\x01 players.", iCount);
		
		}
		
		default:{
	
			int iCount = 0;
			for(int i = 0; i < iTrgCount; i++){
		
				TF2Attrib_SetByDefIndex(aTrgList[i], ATTRIB_TAUNT, fValue);
				g_bHasTauntSpeedSet[aTrgList[i]] = true;
				
				PrintToChat(aTrgList[i], "\x01[SM] Your taunt speed has been set to \x03%.2f\x01!", fValue);
				iCount++;
			
			}
			
			if(client == 0)
				PrintToServer("[SM] Taunt speed set to %.02f for %d players.", fValue, iCount);
			else
				PrintToChat(client, "\x01[SM] Taunt speed set to \x03%.02f\x01 for \x03%d\x01 players.", fValue, iCount);
		
		}
	
	}
	
	return Plugin_Handled;

}

int SetTauntSpeed(int client, float fValue){

	if(fValue == 0.0 || fValue == 1.0){
	
		if(!g_bHasTauntSpeedSet[client])
			return 0;
		
		TF2Attrib_RemoveByDefIndex(client, ATTRIB_TAUNT);
		g_bHasTauntSpeedSet[client] = false;
		
		return -1;
	
	}
	
	TF2Attrib_SetByDefIndex(client, ATTRIB_TAUNT, fValue);
	g_bHasTauntSpeedSet[client] = true;
	
	return 1;

}

public int Native_SetTauntSpeed(Handle hPlugin, int iParams){

	return SetTauntSpeed(GetNativeCell(1), GetNativeCell(2));

}