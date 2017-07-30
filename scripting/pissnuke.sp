#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <nuke>

#define SIZE_NAME 32
#define SIZE_ITEM PLATFORM_MAX_PATH

bool	bHasPissBomb[MAXPLAYERS+1]	= {false, ...};
char	sBombModel[SIZE_ITEM]		= "models/props_td/atom_bomb.mdl";

bool	g_bExplode = true;
bool	g_bDamage = true;

Handle	hBombs		= INVALID_HANDLE;
float	fBombScale	= 1.0;

Handle	hMenu		= INVALID_HANDLE;
Handle	hMenuNames	= INVALID_HANDLE;
Handle	hMenuItems	= INVALID_HANDLE;

public Plugin myinfo = {

	name = "Piss nuke",
	author = "Phil25",
	description = "Creates a nuke out of piss."

}

public void OnPluginStart(){

	RegAdminCmd("sm_pissnuke", Command_Pissbomb, ADMFLAG_ROOT, "Give yourself a piss-nuke");
	RegAdminCmd("sm_pissbomb", Command_Pissbomb, ADMFLAG_ROOT, "Give yourself a piss-nuke");

	RegAdminCmd("sm_pissbombmodel", Command_Pissmodel, ADMFLAG_ROOT, "Set piss-nuke model");
	RegAdminCmd("sm_pissnukemodel", Command_Pissmodel, ADMFLAG_ROOT, "Set piss-nuke model");
	RegAdminCmd("sm_pissbombmenu", Command_Pissmodel, ADMFLAG_ROOT, "Set piss-nuke model");
	RegAdminCmd("sm_pissnukemenu", Command_Pissmodel, ADMFLAG_ROOT, "Set piss-nuke model");

	RegAdminCmd("sm_pissbombscale", Command_Pissscale, ADMFLAG_ROOT, "Set piss-nuke scale");
	RegAdminCmd("sm_pissnukescale", Command_Pissscale, ADMFLAG_ROOT, "Set piss-nuke scale");

	RegAdminCmd("sm_pissbombadd", Command_Pissadd, ADMFLAG_ROOT, "Add piss-nuke model");
	RegAdminCmd("sm_pissnukeadd", Command_Pissadd, ADMFLAG_ROOT, "Add piss-nuke model");

	FillArrays();
	BuildMenu();

}

public void OnClientDisconnect(int client){

	bHasPissBomb[client] = false;

}

void FillArrays(){

	hMenuNames = CreateArray(SIZE_NAME);
	hMenuItems = CreateArray(SIZE_ITEM);

	PushArrayString(hMenuNames, "Bomb");
	PushArrayString(hMenuItems, "models/props_td/atom_bomb.mdl");

	PushArrayString(hMenuNames, "Heavy");
	PushArrayString(hMenuItems, "models/player/heavy.mdl");

	PushArrayString(hMenuNames, "Truck");
	PushArrayString(hMenuItems, "models/props_hydro/dumptruck.mdl");

	PushArrayString(hMenuNames, "Cube");
	PushArrayString(hMenuItems, "models/props_moonbase/moon_cube_crystal03.mdl");

	PushArrayString(hMenuNames, "Vortigaunt");
	PushArrayString(hMenuItems, "models/vortigaunt.mdl");

	PushArrayString(hMenuNames, "Advisor");
	PushArrayString(hMenuItems, "models/advisor.mdl");

	PushArrayString(hMenuNames, "Dog");
	PushArrayString(hMenuItems, "models/dog.mdl");

	PushArrayString(hMenuNames, "Metropolice");
	PushArrayString(hMenuItems, "models/police.mdl");

	PushArrayString(hMenuNames, "G-Man");
	PushArrayString(hMenuItems, "models/gman.mdl");

	PushArrayString(hMenuNames, "Combine Citadel");
	PushArrayString(hMenuItems, "models/props_combine/combine_citadel001.mdl");

}

void PrecacheModels(){

	int iSize = GetArraySize(hMenuItems);
	char sModel[SIZE_ITEM];

	for(int i = 0; i < iSize; i++){
		GetArrayString(hMenuItems, i, sModel, SIZE_ITEM);
		//PrintToChatAll(sModel);
		PrecacheModel(sModel);
	}

}

void BuildMenu(){

	if(hMenu != INVALID_HANDLE)
		delete hMenu;

	hMenu = CreateMenu(Menu_Manager);

	SetMenuTitle(hMenu, "Set pissnuke model:");

	int iSize = GetArraySize(hMenuNames);
	char sName[SIZE_NAME];
	
	AddMenuItem(hMenu, "", g_bExplode ? "[✓] Explode" : "[  ] Explode");
	AddMenuItem(hMenu, "", g_bDamage ? "[✓] Deal Damage" : "[  ] Deal Damage");
	
	for(int i = 0; i < iSize; i++){
		GetArrayString(hMenuNames, i, sName, SIZE_NAME);
		AddMenuItem(hMenu, sName, sName);
	}
	
	SetMenuExitBackButton(hMenu, true);

}

public int Menu_Manager(Handle hThisMenu, MenuAction maState, int client, int iPos){

	if(maState != MenuAction_Select)
		return 0;

	if(iPos < 2){
	
		if(iPos == 0)
			g_bExplode = !g_bExplode;
		else
			g_bDamage = !g_bDamage;
	
		BuildMenu();
	
	}else{
	
		iPos -= 2;
	
		if(iPos >= GetArraySize(hMenuItems))
			return 0;
	
		char sName[SIZE_NAME];
		GetArrayString(hMenuNames, iPos, sName, SIZE_NAME);
		GetArrayString(hMenuItems, iPos, sBombModel, SIZE_ITEM);
		PrintToChat(client, "\x01[SM] Pissnuke model is \x03%s\x01.", sName);
	
	}

	DisplayMenuAtItem(hMenu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);

	return 1;

}

public Action Command_Pissbomb(int client, int args){

	if(client == 0)
		return Plugin_Handled;

	if(args < 1){
		SetPissNuke(client);
		return Plugin_Handled;
	}

	int iDir = -1;
	if(args > 1){
		char sDir[8];
		GetCmdArg(2, sDir, 8);
		iDir = StringToInt(sDir);
	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;
	GetCmdArg(1, sTrg, 32);

	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_MULTI, sTrgName, sizeof(sTrgName), bNameMultiLang)) <= 0){
		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;
	}

	SetPissNuke(aTrgList[0], iDir);
	PrintToChat(client, "\x01[SM] Pissnuke \x03%s\x01 on \x04%N\x01.", bHasPissBomb[aTrgList[0]] ? "enabled" : "disabled", aTrgList[0]);

	return Plugin_Handled;

}

void SetPissNuke(int client, int iDir=-1){
	bHasPissBomb[client] = iDir == -1 ? !bHasPissBomb[client] : iDir == 1 ? true : false;
	PrintToChat(client, "\x01[SM] Your pissnuke is \x03%s\x01.", bHasPissBomb[client] ? "enabled" : "disabled");
}

public Action Command_Pissmodel(int client, int args){

	if(client > 0)
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;

}

public Action Command_Pissscale(int client, int args){

	if(args < 1)
		return Plugin_Handled;

	char sArg[4];
	GetCmdArg(1, sArg, 4);
	fBombScale = StringToFloat(sArg);
	if(fBombScale < 0.05)
		fBombScale = 0.05;
	
	ReplyToCommand(client, "[SM] Pissnuke scale set to %.2f", fBombScale);

	return Plugin_Handled;

}

public Action Command_Pissadd(int client, int args){

	if(args < 2){
	
		ReplyToCommand(client, "[SM] Usage: sm_pissnukeadd \"<model name>\" \"<model path>\"");
		return Plugin_Handled;
	
	}

	if(args > 2){
	
		ReplyToCommand(client, "[SM] Usage: sm_pissnukeadd \"<model name>\" \"<model path>\"");
		return Plugin_Handled;
	
	}

	char sName[SIZE_NAME];
	GetCmdArg(1, sName, SIZE_NAME);
	
	if(FindCharInString(sName, '/') != -1 || FindCharInString(sName, '\\') != -1){
	
		ReplyToCommand(client, "[SM] Forbidden character in the name \\ or /. Did you mistake the order?");
		return Plugin_Handled;
	
	}
	
	char sPath[SIZE_ITEM];
	GetCmdArg(2, sPath, SIZE_ITEM);
	
	if(FindCharInString(sPath, '/') == -1){
	
		ReplyToCommand(client, "[SM] No / found in the model path. Did you mistake the order or put a backslash?");
		return Plugin_Handled;
	
	}
	
	PushArrayString(hMenuNames, sName);
	PushArrayString(hMenuItems, sPath);
	
	PrecacheModels();
	BuildMenu();
	
	ReplyToCommand(client, "[SM] Added pissnuke model \"%s\" at \"%s\".", sName, sPath);

	return Plugin_Handled;

}

public void OnMapStart(){

	if(hBombs != INVALID_HANDLE)
		delete hBombs;

	hBombs = CreateArray();
	PrecacheModels();

}

public void OnEntityCreated(int iEnt, const char[] sClassname){

	if(StrEqual(sClassname, "tf_projectile_jar") || StrEqual(sClassname, "tf_projectile_healing_bolt"))
		SDKHook(iEnt, SDKHook_SpawnPost, OnProjectileSpawned);

}

public void OnProjectileSpawned(int iEnt){

	int client = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
	if(client < 1 || !IsClientInGame(client))
		return;

	if(!bHasPissBomb[client])
		return;

	//SetEntPropFloat(iEnt, Prop_Data, "m_flDetonateTime", 999.0);
	SetEntPropFloat(iEnt, Prop_Data, "m_flModelScale", fBombScale);
	PushArrayCell(hBombs, EntIndexToEntRef(iEnt));
	SetEntityModel(iEnt, sBombModel);

}

public void OnEntityDestroyed(int iEnt){

	if(hBombs == INVALID_HANDLE)
		return;

	if(iEnt <= MaxClients)
		return;

	int iIndex = FindValueInArray(hBombs, EntIndexToEntRef(iEnt));
	if(iIndex == -1)
		return;
	
	RemoveFromArray(hBombs, iIndex);

	if(!g_bExplode)
		return;

	float fPos[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fPos);
	
	Nuke_Spawn(fPos[0], fPos[1], fPos[2], g_bDamage);

}