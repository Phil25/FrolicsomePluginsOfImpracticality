#pragma semicolon 1


#include <tf2>


#define HP_FULL -1

#define DIR_ADD	1
#define DIR_SET	0
#define DIR_SUB	-1

#define CHAT_PREFIX	"\x01[SM]"
#define HP_COLOR	"\x03"


public Plugin myinfo = {

	name		= "Health Manager",
	author		= "Phil25",
	description	= "Manage players' health."

};


public void OnPluginStart(){

	LoadTranslations("common.phrases");

	RegAdminCmd("sm_hp", Command_Health, ADMFLAG_SLAY);
	RegAdminCmd("sm_p", Command_PlusHealth, ADMFLAG_SLAY);

}

public Action Command_Health(int client, int args){

	char sTarget[32], sValue[16];
	switch(args){
	
		case 0:{
		
			strcopy(sTarget, 32, "@me");
			strcopy(sValue, 32, "full");
		
		}
	
		case 1:{
		
			strcopy(sTarget, 32, "@me");
			GetCmdArg(1, sValue, 16);
		
		}
	
		default:{
		
			GetCmdArg(1, sTarget, 32);
			GetCmdArg(2, sValue, 16);
		
		}
	
	}

	char sTrgName[MAX_TARGET_LENGTH];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;

	if((iTrgCount = ProcessTargetString(sTarget, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	int iDir = GetValueDirection(sValue);
	int iVal = GetHealthValue(sValue, iDir);
	for(int i = 0; i < iTrgCount; i++)
		ApplyHealthChange(aTrgList[i], iVal, iDir);

	if(args < 2)
		return Plugin_Handled;

	if(iTrgCount == 1)
		ReplyToCommand(client, "[SM] Health of %N set.", aTrgList[0]);
	else ReplyToCommand(client, "[SM] Health of %d players set.", iTrgCount);

	return Plugin_Handled;

}

public Action Command_PlusHealth(int client, int args){

	if(client != 0)
		SetHealth(client, 999999999);

	return Plugin_Handled;

}


void ApplyHealthChange(int client, int iValue, int iDir){

	int iHealth = CalculateHealth(client, iValue);
	switch(iDir){
	 
	 	case DIR_ADD: AddHealth(client, iHealth);
	 	case DIR_SET: SetHealth(client, iHealth);
	 	case DIR_SUB: SubHealth(client, iHealth);
	 
	 }

}

void AddHealth(int client, int iVal){

	SetEntityHealth(client, GetHealth(client) +iVal);
	PrintToChat(client, "%s Gained %s%d\x01 health.", CHAT_PREFIX, HP_COLOR, iVal);

}

void SetHealth(int client, int iVal){

	SetEntityHealth(client, iVal);
	PrintToChat(client, "%s Health set to %s%d\x01.", CHAT_PREFIX, HP_COLOR, iVal);

}

void SubHealth(int client, int iVal){

	SetEntityHealth(client, GetHealth(client) -iVal);
	PrintToChat(client, "%s Taken %s%d\x01 health.", CHAT_PREFIX, HP_COLOR, iVal);

}

int GetHealth(int client){

	return GetEntProp(client, Prop_Data, "m_iHealth");

}


stock int GetValueDirection(const char[] sValue){

	switch(sValue[0]){
	
		case '+': return DIR_ADD;
		case '-': return DIR_SUB;
	
	}

	return DIR_SET;

}

stock int GetHealthValue(const char[] sValue, int iDir){

	if(iDir == DIR_SET)
		return HealthStringToInt(sValue);

	char sHealth[16];
	strcopy(sHealth, 16, sValue[1]);
	return HealthStringToInt(sHealth);

}

stock int HealthStringToInt(const char[] sHealth){

	if(StrEqual(sHealth, "full", false))
		return HP_FULL;

	return StringToInt(sHealth);

}

stock int CalculateHealth(int client, int iValue){

	if(iValue == HP_FULL)
		return GetEntProp(client, Prop_Data, "m_iMaxHealth");

	return iValue;

}