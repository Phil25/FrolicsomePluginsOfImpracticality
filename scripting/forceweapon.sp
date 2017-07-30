#pragma semicolon 1


public Plugin myinfo = {

	name = "Force Weapon",
	author = "Phil25"

};


int g_iWeap = -1;


public void OnPluginStart(){

	RegAdminCmd("sm_forcew", Command_Force, ADMFLAG_RCON);
	HookEvent("post_inventory_application", Event_Resupply);

}

public Action Command_Force(int client, int args){

	if(args < 1)
		return Plugin_Handled;

	char sArg[8];
	GetCmdArg(1, sArg, 8);
	g_iWeap = StringToInt(sArg);
	ServerCommand("sm_givew @all %d", g_iWeap);

	return Plugin_Handled;

}

public Action Event_Resupply(Handle hEvent, const char[] sName, bool bDontBroadcast){

	if(g_iWeap == -1)
		return Plugin_Continue;

	int uid = GetEventInt(hEvent, "userid");
	ServerCommand("sm_givew #%i %d", uid, g_iWeap);

	return Plugin_Continue;

}