#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"

#define LENNY_EYE		161
#define LENNY_NOSE		156

public Plugin myinfo = {

	name		= "No Lenny",
	author		= "Phil25",
	description	= "Finally, a cure for cancer.",
	version		= PLUGIN_VERSION,
	url			= "www.google.com"

};

public void OnPluginStart(){

	RegAdminCmd("sm_lenny_access", Command_LennyAccess, ADMFLAG_CUSTOM2|ADMFLAG_SLAY, "Access to using the lenny face in chat.");

}

public Action Command_LennyAccess(int client, int args){

	return Plugin_Handled;

}

public Action OnChatMessage(int &author, Handle hRecipients, char[] sName, char[] sMessage){

	if(CheckCommandAccess(author, "sm_lenny_access", ADMFLAG_SLAY|ADMFLAG_CUSTOM2))
		return Plugin_Continue;
	
	if(!StringContainsCancer(sMessage))
		return Plugin_Continue;
	
	ClearArray(hRecipients);
	PushArrayCell(hRecipients, author);
	
	return Plugin_Changed;

}

stock bool StringContainsCancer(const char[] sString){

	int a = StrContainsFrom(sString, 0, LENNY_EYE);
	if(a == -1)
		return false;
	
	int b = StrContainsFrom(sString, a, LENNY_NOSE);
	if(b == -1)
		return false;
	
	int c = StrContainsFrom(sString, b, LENNY_EYE);
	return (c != -1);

}

stock int StrContainsFrom(const char[] sString, int i, int iChar){
	
	int iTestChar = 0
	while(sString[i] != '\0'){
	
		iTestChar = sString[i];
		if(iTestChar == iChar)
			return i;
	
		i++
	
	}

	return -1;

}