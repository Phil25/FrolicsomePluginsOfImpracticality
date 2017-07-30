#pragma semicolon 1


#include <build>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>


#define MAXONE			MAXPLAYERS+1
#define CHAT_PREFIX		"\x03[Build]\x01"
#define CONS_PREFIX		"[Build]"

#define DANGER_COUNT	2000
#define MAX_OBJECTS		300
#define MAX_TYPES		64

#define MAX_DIST_SQR	500000.0
#define MAX_TELE_RANGE	9999999999.0
#define ROTATION_SNAP	30.0

#define SOUND_CLICK		"buttons/button14.wav"

#define ENT_NAME		"prop_plugin_build_object"
#define TELE_SOUND		"misc/halloween/spell_teleport.wav"
#define PAD_SOUND		"weapons/grenade_launcher1.wav"
#define TRAMP_SOUND		"passtime/ball_smack.wav"

#define DISCO_SPRITE	"materials/sprites/laser.vmt"
#define DISCO_INTERVAL	0.75

#define PAD_FORCE		1024.0
#define PAD_RANGE		512.0

#define TRAMP_ADD		64.0
#define TRAMP_MIN_LIMIT	150.0
#define TRAMP_SET_LIMIT	280.0
#define TRAMP_MAX_LIMIT	1536.0

#define ATTRIB_FALLDMG	275


enum Object{

	entity,
	owner,
	account,
	type,
	role,
	pos[3],
	miscData,
	Float:time

}

enum Type{

	String:e_sName[MAX_NAME_LENGTH],
	String:e_sModel[PLATFORM_MAX_PATH],
	bool:e_bRotatable,
	bool:e_bCastsShadow,
	bool:e_bHasPhysics,
	e_iCol[4],
	e_iSolidType,
	e_iSolidTypeAlt,
	e_iZOffset,
	e_iYawRotation,
	Float:e_fGridMult,
	bool:e_bSnapLevel,
	ObjectRole:e_Role

}

int			g_Objects[MAX_OBJECTS][Object],
			g_Types[MAX_TYPES][Type],
			g_iTypeCount = 0,
			g_iObjectCount = 0,
			g_iCategoryCount = 0,
			g_iLargestId = 0,
			g_iDiscoSprite = 0,
			g_iClientObjectCount[MAXONE],
			g_iCurrentType[MAXONE],
			g_iCurrentScale[MAXONE],
			g_iCategory[MAXONE] = {-1, ...},
			g_iGhosts[MAXONE] = {0, ...},
			g_iLastButtons[MAXONE],
			g_iLastSlot[MAXONE],
			g_iFlags[MAXONE],
			g_iInUse[MAXONE],
			g_iNextTeleport[MAXONE],
			g_iLastMenuPos[MAXONE],
			g_iAccount[MAXONE],
			g_iGrids[3]	= {44, 22, 11};

float		g_fScales[3]			= {1.0, 0.5, 0.25},
			g_fTopCorrections[3]	= {1.0, 0.5, 0.25},
			g_fBelCorrections[3]	= {2.0, 1.0, 0.5},
			g_fRotateOffset[MAXONE]	= {0.0, ...},
			g_fLastZVel[MAXONE];

char		g_sPlaceSounds[3][]	= {
	"weapons/baseball_hitworld1.wav", "weapons/baseball_hitworld2.wav", "weapons/baseball_hitworld3.wav"
},
			g_sDestrSounds[3][]	= {
	"weapons/metal_hit_hand1.wav", "weapons/metal_hit_hand2.wav", "weapons/metal_hit_hand3.wav"
},
			g_sClassnames[2][]	= {
	"prop_dynamic", "prop_physics_multiplayer"
			},
			g_sScales[3][]		= {
	"N-m-s", "n-M-s", "n-m-S"
			},
			g_sDeletes[2][]		= {
	"aim-LAST", "AIM-last"
			},
			g_sMusic[][]		= {

	"ui/gamestartup3.mp3", "ui/gamestartup8.mp3", "ui/gamestartup9.mp3", "ui/gamestartup10.mp3", "ui/gamestartup12.mp3", "ui/gamestartup23.mp3", "ui/gamestartup24.mp3",
	"ui/gamestartup25.mp3", "ui/gamestartup26.mp3", "music/hl1_song10.mp3", "music/hl1_song11.mp3", "music/hl1_song15.mp3", "music/hl1_song25_remix3.mp3", "music/hl2_song4.mp3",
	"music/hl2_song14.mp3", "music/hl2_song15.mp3", "music/hl2_song29.mp3", "music/hl2_song31.mp3", "music/radio1.mp3"

},
			g_sAccess[4][]		= {
	"NON-use-build-all", "non-USE-build-all", "non-use-BUILD-all", "non-use-build-ALL"
			},
			g_sAction[3][]		= {
	"Toggled", "Disabled", "Enabled"
			};

bool		g_bCanBuild[MAXONE]		= {false, ...},
			g_bInBuild[MAXONE]		= {false, ...},
			g_bUpdateGhost[MAXONE]	= {false, ...};
			g_bDeleteAim[MAXONE]	= {true, ...},
			g_bBreakFall[MAXONE]	= {false, ...},
			g_bInGod[MAXONE]		= {false, ...};

BuildAccess	g_Access[MAXONE][MAXONE];

BuildMenu	g_BuildMenu[MAXONE]	= {BuildMenu_None, ...};

Handle		g_hCategoryNames	= INVALID_HANDLE,
			g_hCategoryStarts	= INVALID_HANDLE;


public Plugin myinfo = {

	name = "Build",
	author = "Phil25",
	description = "Build stuff in TF2."

};


public void OnPluginStart			(){

	LoadTranslations("common.phrases");

	g_hCategoryNames = CreateArray(MAX_NAME_LENGTH);
	g_hCategoryStarts = CreateArray();
	if(!ParseConfig())
		return;

	RegConsoleCmd("sm_build",	Command_Build, "Open build menu.");
	RegConsoleCmd("sm_b",		Command_Build, "Open build menu.");
	RegAdminCmd("sm_givebuild",	Command_GiveBuild, ADMFLAG_SLAY, "Grant building rights to a player.");
	RegAdminCmd("sm_giveb",		Command_GiveBuild, ADMFLAG_SLAY, "Grant building rights to a player.");

	for(int i = 1; i <= MaxClients; i++){
	
		if(IsClientInGame(i))
			g_iAccount[i] = GetSteamAccountID(i);
	
		g_Access[i][i] = BuildAccess_All;
	
	}

	CleanPotentialLeftovers();

}

public void OnPluginEnd				(){

	for(int i = 0; i <= g_iLargestId; i++)
		KillObject(i);

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientDisconnect(i);

}

public void OnMapStart				(){

	for(int i = 0; i < 3; i++){
	
		PrecacheSound(g_sPlaceSounds[i]);
		PrecacheSound(g_sDestrSounds[i]);
	
	}

	PrecacheSound(SOUND_CLICK);
	PrecacheSound(TELE_SOUND);
	PrecacheSound(TRAMP_SOUND);
	PrecacheSound(PAD_SOUND);

	g_iDiscoSprite = PrecacheModel(DISCO_SPRITE, true);

	int iMusics = sizeof(g_sMusic);
	for(int i = 0; i < iMusics; i++)
		PrecacheSound(g_sMusic[i]);

	for(int i = 1; i <= MaxClients; i++)
		g_iClientObjectCount[i] = 0;

	for(int i = 0; i <= g_iLargestId; i++)
		g_Objects[i][entity] = 0;

	g_iLargestId = 0;

}

public void OnClientPutInServer		(int client){

	g_iAccount[client] = GetSteamAccountID(client);
	for(int i = 0; i <= g_iLargestId; i++)
		if(g_iAccount[client] == g_Objects[i][account]){
		
			g_Objects[i][owner] = client;
			g_iClientObjectCount[client]++;
		
		}

}

public void OnClientDisconnect		(int client){

	if(g_bInBuild[client])
		SetBuildMode(client, false);

	SafeKillGhost(client);
	g_fRotateOffset[client]	= 0.0;
	g_bCanBuild[client]		= false;
	g_bDeleteAim[client]	= true;
	g_BuildMenu[client]		= BuildMenu_None;
	g_bInGod[client]		= false;

	for(int i = 0; i <= MaxClients; i++){
	
		g_Access[client][i] = BuildAccess_None;
		g_Access[i][client] = BuildAccess_None;
	
	}

	g_Access[client][client]= BuildAccess_All;

	if(g_iClientObjectCount[client] == 0)
		return;

	for(int i = 0; i <= g_iLargestId; i++)
		if(g_Objects[i][owner] == client)
			g_Objects[i][owner] = 0;

	CreateTimer(60.0, Timer_DeleteObjects, g_iAccount[client]);
	g_iClientObjectCount[client] = 0;

}

public Action Timer_DeleteObjects	(Handle hTimer, int iAccountId){

	if(GetClientFromAccountId(iAccountId) == 0)
		for(int i = 0; i <= g_iLargestId; i++)
			if(g_Objects[i][account] == iAccountId)
				KillObject(i);

	return Plugin_Stop;

}

public void OnGameFrame				(){

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientGameFrame(i);

}

void OnClientGameFrame				(int client){

	int iFlags = GetEntityFlags(client);
	if(!(g_iFlags[client] & FL_ONGROUND)){
	
		if(iFlags & FL_ONGROUND)
			OnLand(client);
	
		else
			SetClientZVelocity(client);
	
	}

	g_iFlags[client] = iFlags;
	if(g_iGhosts[client] == 0)
		return;

	if(!g_bInBuild[client]){
	
		SafeKillGhost(client);
		return;
	
	}

	float fPos[3], fAng[3];
	SetEntityRenderMode(g_iGhosts[client], GetLocation(client, fPos, fAng) ? RENDER_TRANSALPHA : RENDER_NONE);
	TeleportEntity(g_iGhosts[client], fPos, fAng, NULL_VECTOR);
	SetEntPropFloat(g_iGhosts[client], Prop_Send, "m_flModelScale", g_fScales[g_iCurrentScale[client]]);

}


bool ParseConfig					(){

	char sPath[255];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/build.cfg");

	if(!FileExists(sPath)){
	
		LogError("%s Failed to find build.cfg in configs/ folder!", CONS_PREFIX);
		SetFailState("Failed to find build.cfg in configs/ folder!");
		return false;
	
	}

	Handle hKv = CreateKeyValues("Build");
	if(FileToKeyValues(hKv, sPath) && KvGotoFirstSubKey(hKv)){
	
		g_iTypeCount = 0;
		char sColor[24], sCategory[MAX_NAME_LENGTH];
		char[][] sColorSplit = new char[4][8];
		do{
		
			KvGetString(hKv, "category", sCategory, MAX_NAME_LENGTH);
			if(strlen(sCategory) > 1){
			
				PushArrayString(g_hCategoryNames, sCategory);
				PushArrayCell(g_hCategoryStarts, g_iTypeCount);
				g_iCategoryCount++;
			
				continue;
			
			}
		
			KvGetString(hKv, "name", g_Types[g_iTypeCount][e_sName], MAX_NAME_LENGTH);
			KvGetString(hKv, "model", g_Types[g_iTypeCount][e_sModel], PLATFORM_MAX_PATH);
		
			if(strlen(g_Types[g_iTypeCount][e_sModel]) > 4 && !IsModelPrecached(g_Types[g_iTypeCount][e_sModel]))
				PrecacheModel(g_Types[g_iTypeCount][e_sModel]);
		
			KvGetString(hKv, "color", sColor, 24);
			ExplodeString(sColor, " ", sColorSplit, 4, 8);
		
			for(int i = 0; i < 4; i++)
				g_Types[g_iTypeCount][e_iCol][i] = StringToInt(sColorSplit[i]);
		
			g_Types[g_iTypeCount][e_iSolidType]		= KvGetNum(hKv, "solid1", 6);
			g_Types[g_iTypeCount][e_iSolidTypeAlt]	= KvGetNum(hKv, "solid2", 3);
			g_Types[g_iTypeCount][e_bCastsShadow]	= KvGetNum(hKv, "shadow") > 0;
			g_Types[g_iTypeCount][e_bRotatable]		= KvGetNum(hKv, "rotate") > 0;
			g_Types[g_iTypeCount][e_iZOffset]		= KvGetNum(hKv, "offset");
			g_Types[g_iTypeCount][e_iYawRotation]	= KvGetNum(hKv, "yaw");
			g_Types[g_iTypeCount][e_fGridMult]		= KvGetFloat(hKv, "grid", 1.0);
			g_Types[g_iTypeCount][e_bSnapLevel]		= KvGetNum(hKv, "snaplevel") > 0;
			g_Types[g_iTypeCount][e_bHasPhysics]	= KvGetNum(hKv, "hasPhys") > 0;
			g_Types[g_iTypeCount][e_Role]			= view_as<ObjectRole>(KvGetNum(hKv, "role"));
		
			g_iTypeCount++;
		
		}while(KvGotoNextKey(hKv));
	
		delete hKv;
		return true;
	
	}

	LogError("%s Parsing build.cfg failed!", CONS_PREFIX);
	SetFailState("Parsing build.cfg failed!");

	delete hKv;
	return false;

}


public Action Command_Build			(int client, int args){

	if(!g_bCanBuild[client] && !IsAdmin(client))
		PrintToChat(client, "%s You do not have access to this command.", CHAT_PREFIX);

	else
		Menu_Display(client);

	return Plugin_Handled;

}

public Action Command_GiveBuild		(int client, int args){

	if(args < 1){
	
		ReplyToCommand(client, "%s Usage: sm_giveb <player> <-1/0/1>*", CONS_PREFIX);
		return Plugin_Handled;
	
	}

	char sTrgName[MAX_TARGET_LENGTH], sTrg[32];
	int	 aTrgList[MAXPLAYERS], iTrgCount;
	bool bNameMultiLang;

	GetCmdArg(1, sTrg, 32);
	if((iTrgCount = ProcessTargetString(sTrg, client, aTrgList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTrgName, MAX_TARGET_LENGTH, bNameMultiLang)) <= 0){

		ReplyToTargetError(client, iTrgCount);
		return Plugin_Handled;

	}

	int iDir = -1;
	if(args > 1){
	
		char sDir[4];
		GetCmdArg(2, sDir, 4);
		iDir = StringToInt(sDir);
	
	}

	switch(iDir){
	
		case -1: for(int i = 0; i < iTrgCount; i++)
			g_bCanBuild[aTrgList[i]] = !g_bCanBuild[aTrgList[i]];
	
		case 0: for(int i = 0; i < iTrgCount; i++)
			g_bCanBuild[aTrgList[i]] = false;
	
		case 1: for(int i = 0; i < iTrgCount; i++)
			g_bCanBuild[aTrgList[i]] = true;
	
	}

	for(int i = 0; i < iTrgCount; i++)
		PrintToChat(aTrgList[i], "%s You can %s use \x03!build\x01.", CHAT_PREFIX, g_bCanBuild[aTrgList[i]] ? "now" : "no longer");

	if(iTrgCount == 1)
		ReplyToCommand(client, "%s Build %s on %N", CONS_PREFIX, g_bCanBuild[aTrgList[0]] ? "enabled" : "disabled", aTrgList[0]);

	else
		ReplyToCommand(client, "%s %s Build on %d players.", CONS_PREFIX, g_sAction[iDir+1], iTrgCount);

	return Plugin_Handled;

}


void Menu_Display					(int client, BuildMenu buildMenu=BuildMenu_Main, int iPos=0){

	Handle hMenu = Menu_Create(client, buildMenu);

	if(iPos > 0)
		DisplayMenuAtItem(hMenu, client, iPos, MENU_TIME_FOREVER);

	else
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	SetBuildMode(client, true);
	g_BuildMenu[client] = buildMenu;
	if(buildMenu == BuildMenu_Main)
		g_iCategory[client] = -1;

}

void Menu_Refresh					(int client, bool bUseLastPos=false){

	Menu_Display(client, g_BuildMenu[client], bUseLastPos ? g_iLastMenuPos[client] : 0);

}

Handle Menu_Create					(int client, BuildMenu buildMenu=BuildMenu_Main){

	Handle hMenu = CreateMenu(Menu_Manager);

	Menu_SetTitle	(hMenu, client, buildMenu);
	Menu_SetItems	(hMenu, client, buildMenu);
	Menu_SetBack	(hMenu, buildMenu);

	return hMenu;

}

void Menu_SetTitle					(Handle &hMenu, int client, BuildMenu buildMenu=BuildMenu_Main){

	switch(buildMenu){
	
		case BuildMenu_Main:
			SetMenuTitle(hMenu, "Build Menu [%d/%d] (%d)", g_iObjectCount, MAX_OBJECTS, g_iClientObjectCount[client]);
	
		case BuildMenu_Objects:
			SetMenuTitle(hMenu, "Select Object [%d/%d] (%d)", g_iObjectCount, MAX_OBJECTS, g_iClientObjectCount[client]);
	
		case BuildMenu_Access:
			SetMenuTitle(hMenu, "Set Access [%d/%d] (%d)", g_iObjectCount, MAX_OBJECTS, g_iClientObjectCount[client]);
	
		case BuildMenu_ClearAll:
			SetMenuTitle(hMenu, "Clear owned objects? [%d/%d] (%d)", g_iObjectCount, MAX_OBJECTS, g_iClientObjectCount[client]);
	
	}

}

void Menu_SetItems					(Handle &hMenu, int client, BuildMenu buildMenu=BuildMenu_Main){

	switch(buildMenu){
	
		case BuildMenu_Main:{
		
			AddMenuItemF(hMenu, "0", "Selected: [%s]", g_Types[g_iCurrentType[client]][e_sName]);
			AddMenuItemF(hMenu, "1", "Scale: [%s]", g_sScales[g_iCurrentScale[client]]);
			AddMenuItemF(hMenu, "2", "Delete: [%s]", g_sDeletes[view_as<int>(g_bDeleteAim[client])]);
			AddMenuItemF(hMenu, "3", "Set Access");
			AddMenuItemF(hMenu, "4", "Clear All");
		
		}
	
		case BuildMenu_Objects:{
		
			if(g_iCategory[client] == -1){
			
				char sCategoryName[MAX_NAME_LENGTH];
				for(int i = 0; i < g_iCategoryCount; i++){
				
					GetArrayString(g_hCategoryNames, i, sCategoryName, MAX_NAME_LENGTH);
					AddMenuItemIF(hMenu, i, "%s", sCategoryName);
				
				}
			
			}else{
			
				int	i		= GetArrayCell(g_hCategoryStarts, g_iCategory[client]),
					iEnd	= g_iCategory[client] == g_iCategoryCount -1 ? g_iTypeCount : GetArrayCell(g_hCategoryStarts, g_iCategory[client] +1);
			
				for(; i < iEnd; i++)
					AddMenuItemIF(hMenu, i, "[%s] %s", i == g_iCurrentType[client] ? "•" : " ", g_Types[i][e_sName]);
			
			}
		
		}
	
		case BuildMenu_Access:{
		
			AddMenuItemIF(hMenu, 0, "> Anyone..........[%s]", g_sAccess[view_as<int>(g_Access[client][0])]);
			AddMenuItemIF(hMenu, client, "> You..........[%s]", g_sAccess[view_as<int>(g_Access[client][client])]);
			AddMenuItem(hMenu, "", "- - - - - - - - -", ITEMDRAW_DISABLED);
			for(int i = 1; i <= MaxClients; i++)
				if(i != client)
					if(IsClientInGame(i))
						AddMenuItemIF(hMenu, i, "%N..........[%s]", i, g_sAccess[view_as<int>(g_Access[client][i])]);
		
		}
	
		case BuildMenu_ClearAll:{
		
			AddMenuItem(hMenu, "1", "Yes");
			AddMenuItem(hMenu, "0", "No");
			AddMenuItem(hMenu, "0", "Maybe");
		
		}
	
	}

}

void Menu_SetBack					(Handle &hMenu, BuildMenu buildMenu=BuildMenu_Main){

	if(buildMenu == BuildMenu_Main){

		SetMenuPagination(hMenu, MENU_NO_PAGINATION);
		SetMenuExitButton(hMenu, true);

	}else
		SetMenuExitBackButton(hMenu, true);

}

public int Menu_Manager				(Handle hMenu, MenuAction maState, int client, int iPos){

	if(client < 1)
		return 0;

	switch(maState){
	
		case MenuAction_Select:{
		
			g_iLastMenuPos[client] = GetMenuSelectionPosition();
		
			char sItem[32];
			GetMenuItem(hMenu, iPos, sItem, 32);
			if(Menu_Selection(client, StringToInt(sItem)))
				Menu_Refresh(client, true);
		
			else
				Menu_GoBack(client);
		
		}
	
		case MenuAction_Cancel: switch(iPos){
		
			case MenuCancel_ExitBack:
				Menu_GoBack(client);
		
			case MenuCancel_Exit:{
			
				SetBuildMode(client, false);
				g_BuildMenu[client] = BuildMenu_None;
			
			}
		
		}
	
		case MenuAction_End:{
		
			delete hMenu;
			g_BuildMenu[client] = BuildMenu_None;
		
		}
	
	}

	return 1;

}

bool Menu_Selection					(int client, int iItem){

	switch(g_BuildMenu[client]){
	
		case BuildMenu_Main: switch(iItem){
		
			case 0:
				Menu_Display(client, BuildMenu_Objects);
		
			case 1:{
			
				g_iCurrentScale[client]++;
				if(g_iCurrentScale[client] >= 3)
					g_iCurrentScale[client] = 0;
			
				g_bUpdateGhost[client]	= true;
			
			}
		
			case 2:
				g_bDeleteAim[client] = !g_bDeleteAim[client];
		
			case 3:
				Menu_Display(client, BuildMenu_Access);
		
			case 4:
				Menu_Display(client, BuildMenu_ClearAll);
		
		}
	
		case BuildMenu_Objects:{
		
			if(g_iCategory[client] == -1){
			
				g_iCategory[client] = iItem;
			
			}else{
			
				g_iCurrentType[client]	= iItem;
				g_bUpdateGhost[client]	= true;
			
			}
		
		}
	
		case BuildMenu_Access:{
		
			g_Access[client][iItem]++;
			if(g_Access[client][iItem] >= BuildAccess_Count)
				g_Access[client][iItem] = BuildAccess_None;
		
		}
	
		case BuildMenu_ClearAll:{
		
			if(iItem == 1)
				for(int i = 0; i <= g_iLargestId; i++)
					if(g_Objects[i][owner] == client)
						KillObject(i);
		
			return false;
		
		}
	
	}

	return true;

}

void Menu_GoBack					(int client){

	switch(g_BuildMenu[client]){
	
		case BuildMenu_Objects:{
		
			if(g_iCategory[client] == -1)
				Menu_Display(client);
		
			else{
			
				g_iCategory[client] = -1;
				Menu_Refresh(client);
			
			}
		
		}
	
		case BuildMenu_Access, BuildMenu_ClearAll:
			Menu_Display(client);
	
	}

}


public Action OnPlayerRunCmd		(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iNewWeap){

	CheckGodballProximity(client);

	if(!g_bInBuild[client])
		return Plugin_Continue;

	int iButton;
	for(int i = 0; i < 25; i++){
	
		iButton = (1 << i);
		if(iButtons & iButton && !(g_iLastButtons[client] & iButton))
			OnButtonPress(client, iButton);
	
	}

	int iNewSlot = g_iLastSlot[client];
	if(iNewWeap != 0){
	
		iNewSlot = GetWeaponSlot(client, iNewWeap);
		if(iNewSlot == 0 && g_iLastSlot[client] > 1)
			OnWheelDown(client);
	
		else if(g_iLastSlot[client] == 0 && iNewSlot > 1)
			OnWheelUp(client);
	
		else if(g_iLastSlot[client] > iNewSlot)
			OnWheelUp(client);
	
		else
			OnWheelDown(client);
	
	}

	g_iLastButtons[client]	= iButtons;
	g_iLastSlot[client]		= iNewSlot;
	return Plugin_Continue;

}

void OnButtonPress					(int client, int iButton){

	switch(iButton){
	
		case IN_ATTACK:		Build(client, g_iCurrentType[client]);
		case IN_ATTACK2:	Delete(client);
		case IN_RELOAD:		if(!OnSetAimBlock(client)) PrintToChat(client, "%s Not looking at any block.", CHAT_PREFIX);
	
	}

}

void OnWheelUp						(int client){

	g_fRotateOffset[client] += ROTATION_SNAP;
	if(g_fRotateOffset[client] >= 360.0)
		g_fRotateOffset[client] = 0.0;

}

void OnWheelDown					(int client){

	g_fRotateOffset[client] -= ROTATION_SNAP;
	if(g_fRotateOffset[client] < 0.0)
		g_fRotateOffset[client] = 360.0 -ROTATION_SNAP;

}

bool OnSetAimBlock					(int client){

	int iEnt = GetClientAimTarget(client, false);
	if(iEnt <= MaxClients || !IsValidEntity(iEnt))
		return false;

	int iId = GetEntId(iEnt);
	if(iId == -1)
		return false;

	g_iCurrentType[client] = g_Objects[iId][type];
	g_bUpdateGhost[client] = true;
	Menu_Refresh(client, true);
	PrintToChat(client, "%s Selected \x03%s\x01.", CHAT_PREFIX, g_Types[g_iCurrentType[client]][e_sName]);
	EmitSoundToClient(client, SOUND_CLICK);
	return true;

}

void BreakNextFall					(int client){

	g_bBreakFall[client] = true;
	TF2Attrib_SetByDefIndex(client, ATTRIB_FALLDMG, 1.0);

}

void OnLand							(int client){

	SetClientZVelocity(client);

	if(!g_bBreakFall[client])
		return;

	float fShake[3];
	fShake[0] = 20.0;
	SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", fShake);

	TF2Attrib_RemoveByDefIndex(client, ATTRIB_FALLDMG);
	g_bBreakFall[client] = false;

}


void SetBuildMode					(int client, bool bSet){

	if(g_bInBuild[client] == bSet)
		return;

	g_bInBuild[client] = bSet;
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", !view_as<int>(bSet));
	SetNextAttack(client, bSet);
	g_iLastSlot[client] = GetWeaponSlot(client, GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));

	if(!bSet)
		return;

	SafeKillGhost(client);
	g_iGhosts[client] = SpawnGhost(client);

}

int SpawnGhost						(int client){

	float fPos[3], fAng[3];
	GetLocation(client, fPos, fAng);

	int iGhost = CreateEntityByName(g_sClassnames[view_as<int>(g_Types[g_iCurrentType[client]][e_bHasPhysics])]);
	if(iGhost <= MaxClients || !IsValidEntity(iGhost))
		return -1;

	DispatchKeyValue(iGhost, "targetname", ENT_NAME);
	DispatchKeyValue(iGhost, "model", g_Types[g_iCurrentType[client]][e_sModel]);

	DispatchSpawn(iGhost);
	TeleportEntity(iGhost, fPos, fAng, NULL_VECTOR);

	AcceptEntityInput(iGhost, "DisableShadow");
	SetEntityRenderFx(iGhost, RENDERFX_PULSE_FAST_WIDE);
	SetEntityRenderColor(iGhost,
		g_Types[g_iCurrentType[client]][e_iCol][0],
		g_Types[g_iCurrentType[client]][e_iCol][1],
		g_Types[g_iCurrentType[client]][e_iCol][2],
		g_Types[g_iCurrentType[client]][e_iCol][3]/2
	);

	SDKHook(iGhost, SDKHook_SetTransmit, GhostTransmit);
	return iGhost;

}

void Build							(int client, int iType){

	int iId = GetNextId();
	if(iId == -1){
	
		PrintToChat(client, "%s Object limit has been reached!", CHAT_PREFIX);
		return;
	
	}

	if(GetEntityCount() > DANGER_COUNT){
	
		PrintToChat(client, "%s Map entity count reaching dangerous limit!", CHAT_PREFIX);
		return;
	
	}

	float fEndPos[3], fEndAng[3];
	if(!GetLocation(client, fEndPos, fEndAng))
		return;

	int iOb = CreateEntityByName(g_sClassnames[view_as<int>(g_Types[iType][e_bHasPhysics])]);
	if(iOb <= MaxClients || !IsValidEntity(iOb))
		return;

	DispatchKeyValue(iOb, "targetname", ENT_NAME);
	DispatchKeyValue(iOb, "model", g_Types[iType][e_sModel]);

	AcceptEntityInput(iOb, "EnableCollision");

	if(g_iCurrentScale[client] != 0){
	
		SetEntProp(iOb, Prop_Send, "m_nSolidType", g_Types[iType][e_iSolidTypeAlt]);
		float fScale[3];
		fScale[0] = g_fScales[g_iCurrentScale[client]];
		SetVariantVector3D(fScale);
		AcceptEntityInput(iOb, "SetModelScale");
	
	}else
		SetEntProp(iOb, Prop_Send, "m_nSolidType", g_Types[iType][e_iSolidType]);

	if(iId > g_iLargestId)
		g_iLargestId = iId;

	g_Objects[iId][entity]	= iOb;
	g_Objects[iId][owner]	= client;
	g_Objects[iId][account]	= g_iAccount[client];
	g_Objects[iId][type]	= iType;
	g_Objects[iId][time]	= GetEngineTime();
	for(int i = 0; i < 3; i++)
		g_Objects[iId][pos][i] = RoundFloat(fEndPos[i]);

	DispatchSpawn(iOb);
	SetRoleProps(iId, EntIndexToEntRef(iOb), g_Types[iType][e_Role]);

	if(g_Types[iType][e_bHasPhysics])
		AcceptEntityInput(iOb, "DisableMotion");

	if(!g_Types[iType][e_bCastsShadow])
		AcceptEntityInput(iOb, "DisableShadow");

	SetEntityRenderMode(iOb, RENDER_GLOW);
	SetEntityRenderColor(iOb, g_Types[iType][e_iCol][0], g_Types[iType][e_iCol][1], g_Types[iType][e_iCol][2], g_Types[iType][e_iCol][3]);

	TeleportEntity(iOb, fEndPos, fEndAng, NULL_VECTOR);
	EmitSoundToAll(g_sPlaceSounds[GetRandomInt(0, 2)], iOb);
	g_iObjectCount++;
	g_iClientObjectCount[client]++;

	Menu_Refresh(client, true);

}

void SetRoleProps					(int iId, int iEntRef, ObjectRole objectRole){

	switch(objectRole){
	
		case ObjectRole_Door:
			SetEntPropEnt(g_Objects[iId][entity], Prop_Send, "m_hOwnerEntity", g_Objects[iId][owner]);
	
		case ObjectRole_Disco:
			CreateTimer(DISCO_INTERVAL, OnDiscoTick, iEntRef, TIMER_REPEAT);
	
		case ObjectRole_DiscoBall:
			CreateTimer(DISCO_INTERVAL, OnDiscoBallTick, iEntRef, TIMER_REPEAT);
	
		case ObjectRole_Teleporter:{
		
			SetEntProp(g_Objects[iId][entity], Prop_Send, "m_nSolidType", 6);
			SDKHook(g_Objects[iId][entity], SDKHook_StartTouchPost, OnTeleTouch);
		
		}
	
		case ObjectRole_Launchpad:{
		
			SetEntProp(g_Objects[iId][entity], Prop_Send, "m_nSolidType", 7);
			DispatchKeyValue(g_Objects[iId][entity], "solid", "2");
			SDKHook(g_Objects[iId][entity], SDKHook_StartTouchPost, OnPadTouch);
		
		}
	
		case ObjectRole_Trampoline:{
		
			SetEntProp(g_Objects[iId][entity], Prop_Send, "m_nSolidType", 7);
			DispatchKeyValue(g_Objects[iId][entity], "solid", "2");
			SDKHook(g_Objects[iId][entity], SDKHook_StartTouch, OnTrampolineTouch);
		
		}
	
		case ObjectRole_Jukebox:{
		
			SDKHook(g_Objects[iId][entity], SDKHook_OnTakeDamagePost, OnJukeboxHit);
			g_Objects[iId][miscData] = -1;
		
		}
	
	}

}

void Delete							(int client){

	int iId = GetLastClientId(client);
	if(g_bDeleteAim[client]){
	
		int iEnt = GetClientAimTarget(client, false);
		if(iEnt <= MaxClients || !IsValidEntity(iEnt))
			return;
	
		iId = GetEntId(iEnt);
		if(iId == -1)
			return;
	
	}

	if(KillObject(iId, client))
		Menu_Refresh(client, true);

}

bool KillObject						(int iId, int client=0){

	if(!IsUsed(iId))
		return false;

	if(client > 0){
	
		bool bRemovingTheirs = client == g_Objects[iId][owner];
		if(!HasBuildAccess(client, iId)){
	
			PrintToChat(client, "%s No access to this object.", CHAT_PREFIX);
			return false;
	
		}else
			EmitSoundToAll(g_sDestrSounds[GetRandomInt(0, 2)], g_Objects[iId][entity]);
	
		if(bRemovingTheirs)
			g_iClientObjectCount[client]--;
	
	}

	AcceptEntityInput(g_Objects[iId][entity], "Kill", client == 0 ? -1 : client);
	g_Objects[iId][entity] = 0;
	g_Objects[iId][type] = 0;
	g_iObjectCount--;
	return true;

}

public Action GhostTransmit			(int iEnt, int client){

	if(g_bUpdateGhost[client])
		UpdateGhost(client);

	return g_iGhosts[client] == iEnt ? Plugin_Continue : Plugin_Handled;

}

void UpdateGhost					(int client){

	g_bUpdateGhost[client] = false;
	SafeKillGhost(client);
	g_iGhosts[client] = SpawnGhost(client);

}

void SafeKillGhost					(int client){

	if(g_iGhosts[client] > MaxClients && IsValidEntity(g_iGhosts[client]))
		AcceptEntityInput(g_iGhosts[client], "Kill");

	g_iGhosts[client] = 0;

}


bool GetLocation					(int client, float fEndPos[3], float fEndAng[3]){

	float fPos[3], fAng[3];
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAng);

	Handle hTrace = TR_TraceRayFilterEx(fPos, fAng, MASK_SHOT, RayType_Infinite, Trace_Filter);
	if(hTrace == INVALID_HANDLE)
		return false;

	TR_GetEndPosition(fEndPos, hTrace);
	if(GetVectorDistance(fPos, fEndPos, true) > MAX_DIST_SQR){
	
		delete hTrace;
		return false;
	
	}

	SnapToNeighbour(fEndPos, TR_GetEntityIndex(hTrace), g_iCurrentScale[client]);
	SnapToGrid(fEndPos, g_iCurrentScale[client], g_Types[g_iCurrentType[client]][e_fGridMult]);
	delete hTrace;

	fEndPos[2] += g_Types[g_iCurrentType[client]][e_iZOffset];
	fEndAng[0] += g_Types[g_iCurrentType[client]][e_iYawRotation];

	if(g_Types[g_iCurrentType[client]][e_bRotatable])
		fEndAng[1] = RoundToFloor((ModFloatInt(fAng[1], 360) +ROTATION_SNAP /2) /ROTATION_SNAP) *ROTATION_SNAP +g_fRotateOffset[client];

	return !IsPositionTaken(fEndPos);

}

public bool Trace_Filter			(int iEnt, int iContentMask, any data){

	return !(1 <= iEnt <= MaxClients);

}

void SnapToGrid						(float fPos[3], int iScale, float fGridMult){

	float fDiff, fGrid = g_iGrids[iScale] *fGridMult;
	for(int i = 0; i < 2; i++){
	
		fDiff = ModFloat(fPos[i], fGrid);
		fPos[i] = fDiff < fGrid/2 ? fPos[i] -fDiff : fPos[i] +(fGrid -fDiff);
	
	}

	fPos[2] = float(RoundToFloor(fPos[2]));

}

void SnapToNeighbour				(float fPos[3], int iEnt, int iScale){

	if(iEnt <= MaxClients || !IsValidEntity(iEnt))
		return;

	int iOtherId = GetEntId(iEnt);
	if(iOtherId < 0)
		return;

	float fOtherPos[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOtherPos);

	if(g_Types[g_Objects[iOtherId][type]][e_bSnapLevel]){
	
		fPos[2] = fOtherPos[2];
		return;
	
	}

	switch(GetRelativePos(fPos[2], fOtherPos[2], iScale)){
	
		case 2: fPos[2] -= g_fTopCorrections[iScale];
		case 1: fPos[2] = fOtherPos[2];
		case 0: fPos[2] = fOtherPos[2] -g_iGrids[iScale] +g_fBelCorrections[iScale];
	
	}

}

int GetRelativePos					(float fThis, float fOther, int iSelScale){

	if(fThis >= fOther +g_iGrids[iSelScale] -2.0)
		return 2;

	else if(fThis > fOther)
		return 1;

	return 0;

}

bool IsPositionTaken				(float fPos[3]){

	for(int i = 0; i < MAX_OBJECTS; i++)
		if(IsUsed(i))
			if(MatchPos(i, fPos))
				return true;

	return false;

}


public Action OnDiscoTick			(Handle hTimer, int iEntRef){

	int iEnt = EntRefToEntIndex(iEntRef);
	if(iEnt < MaxClients)
		return Plugin_Stop;

	SetEntityRenderColor(iEnt, GetRandomInt(128, 255), GetRandomInt(128, 255), GetRandomInt(128, 255));
	return Plugin_Continue;

}

public Action OnDiscoBallTick		(Handle hTimer, int iDiscoRef){

	int iDisco = EntRefToEntIndex(iDiscoRef);
	if(iDisco <= MaxClients || !IsValidEntity(iDisco))
		return Plugin_Stop;

	char sColor[12];
	Format(sColor, 12, "%d %d %d", GetRandomInt(128, 255), GetRandomInt(128, 255), GetRandomInt(128, 255));
	SetVariantString(sColor);
	AcceptEntityInput(iDisco, "Color");

	Handle hTrace = INVALID_HANDLE;
	float fPos[3], fEndPos[3], fAng[3];
	int iColors[4];
	iColors[3] = 255;
	GetEntPropVector(iDisco, Prop_Send, "m_vecOrigin", fPos);
	for(int i = 0; i < 10; i++){
	
		fAng[0] = GetRandomFloat(0.0, 90.0);
		fAng[1] = GetRandomFloat(-180.0, 180.0);
		hTrace = TR_TraceRayFilterEx(fPos, fAng, MASK_SHOT, RayType_Infinite, TraceFilterPlayers, iDisco);
		if(TR_DidHit(hTrace)){
		
			TR_GetEndPosition(fEndPos, hTrace);
			for(int j = 0; j < 3; j++)
				iColors[j] = GetRandomInt(128, 255);
		
			Lazor(fPos, fEndPos, iColors);
		
		}
	
		delete hTrace;
	
	}

	return Plugin_Continue;

}

public void OnTeleTouch				(int iTele, int client){

	if(!(1 <= client <= MaxClients))
		return;

	if(!IsClientInGame(client))
		return;

	int iCurTime = GetTime();
	if(iCurTime < g_iNextTeleport[client])
		return;

	if(!HasUseAccess(client, GetEntId(iTele)))
		return;

	g_iNextTeleport[client] = iCurTime +2;

	int iNextTele = FindNearestObject(GetEntId(iTele), ObjectRole_Teleporter);
	if(iNextTele <= MaxClients || !IsValidEntity(iNextTele))
		return;

	float fOtherPos[3];
	GetEntPropVector(iNextTele, Prop_Send, "m_vecOrigin", fOtherPos);
	fOtherPos[2] += 10.0;
	TeleportEntity(client, fOtherPos, NULL_VECTOR, NULL_VECTOR);
	EmitSoundToAll(TELE_SOUND, client);

	TeleportEffect(client);

}

public void OnPadTouch				(int iPad, int client){

	if(!(1 <= client <= MaxClients))
		return;

	if(!IsClientInGame(client))
		return;

	if(!HasUseAccess(client, GetEntId(iPad)))
		return;

	g_iInUse[client] = EntIndexToEntRef(iPad);
	CreateTimer(0.1, OnPadTouchPost, GetClientSerial(client));

}

public Action OnPadTouchPost		(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	int iPad = EntRefToEntIndex(g_iInUse[client]);
	if(iPad <= MaxClients || !IsValidEntity(iPad))
		return Plugin_Stop;

	float fPos[3], fOtherPos[3], fAng[3], fFwd[3], fPush[3];
	GetEntPropVector(iPad, Prop_Send, "m_vecOrigin", fPos);

	for(int i = 0; i < 3; i++)
		fOtherPos[i] = fPos[i];

	GetEntPropVector(iPad, Prop_Data, "m_angRotation", fAng);
	fAng[0] = 0.0;
	GetAngleVectors(fAng, fFwd, NULL_VECTOR, NULL_VECTOR);
	for(int i = 0; i < 2; i++)
		fOtherPos[i] += PAD_RANGE *fFwd[i];

	MakeVectorFromPoints(fPos, fOtherPos, fPush);
	fPush[2] = PAD_FORCE;
	fPos[2] += 10.0;

	TeleportEntity(client, fPos, NULL_VECTOR, fPush);
	EmitSoundToAll(PAD_SOUND, client);
	BreakNextFall(client);
	ShakeEffect(client);

	return Plugin_Stop;

}

public void OnTrampolineTouch		(int iTrampoline, int client){

	if(!(1 <= client <= MaxClients))
		return;

	if(!IsClientInGame(client))
		return;

	if(!HasUseAccess(client, GetEntId(iTrampoline)))
		return;

	if(GetEntityFlags(client) & FL_DUCKING)
		return;

	CreateTimer(0.1, OnTrampolineTouchPost, GetClientSerial(client));

}

public Action OnTrampolineTouchPost	(Handle hTimer, int iSerial){

	int client = GetClientFromSerial(iSerial);
	if(client == 0)
		return Plugin_Stop;

	float fVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);
	fVel[2] = FloatAbs(g_fLastZVel[client]);
	fVel[2] += TRAMP_ADD;

	if(fVel[2] < TRAMP_MIN_LIMIT)
		return Plugin_Stop;
	
	else if(fVel[2] < TRAMP_SET_LIMIT)
		fVel[2] = TRAMP_SET_LIMIT;

	BreakNextFall(client);

	//if(fVel[2] > TRAMP_MAX_LIMIT)
	//	fVel[2] = TRAMP_MAX_LIMIT;

	EmitSoundToAll(TRAMP_SOUND, client);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);

	return Plugin_Stop;

}

public void OnJukeboxHit			(int iJukebox, int client, int iInflictor, float fDmg, int iType){

	if(!(1 <= client <= MaxClients))
		return;

	if(!IsClientInGame(client))
		return;

	if(!HasUseAccess(client, GetEntId(iJukebox)))
		return;

	if(!(iType & DMG_CLUB))
		return;

	int iId = GetEntId(iJukebox);
	if(iId == -1){
	
		AcceptEntityInput(iJukebox, "Kill");
		return;
	
	}

	StopJukeboxMusic(iJukebox, g_Objects[iId][miscData]);
	int iMusics = sizeof(g_sMusic);
	if(++g_Objects[iId][miscData] >= iMusics)
		g_Objects[iId][miscData] = 0;

	char sColor[12];
	Format(sColor, 12, "%d %d %d", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
	SetVariantString(sColor);
	AcceptEntityInput(iJukebox, "Color");

	PrintToChat(client, "%s Playing song \x03%d\x01 of \x03%d\x01.", CHAT_PREFIX, g_Objects[iId][miscData]+1, iMusics);
	PlayJukeboxMusic(iJukebox, g_Objects[iId][miscData]);

}

void PlayJukeboxMusic				(int iJukebox, int iSong){

	if(iSong < 0)
		return;

	EmitSoundToAll(g_sMusic[iSong], iJukebox, SNDCHAN_AUTO);
	EmitSoundToAll(g_sMusic[iSong], iJukebox, SNDCHAN_BODY);
	EmitSoundToAll(g_sMusic[iSong], iJukebox, SNDCHAN_ITEM);
	EmitSoundToAll(g_sMusic[iSong], iJukebox, SNDCHAN_REPLACE);

}

void StopJukeboxMusic				(int iJukebox, int iSong){

	if(iSong < 0)
		return;

	StopSound(iJukebox, SNDCHAN_AUTO, g_sMusic[iSong]);
	StopSound(iJukebox, SNDCHAN_BODY, g_sMusic[iSong]);
	StopSound(iJukebox, SNDCHAN_ITEM, g_sMusic[iSong]);
	StopSound(iJukebox, SNDCHAN_REPLACE, g_sMusic[iSong]);

}

void CheckGodballProximity			(int client){

	float fPos[3];
	GetClientAbsOrigin(client, fPos);

	bool bInRange = false;
	for(int i = 0; i <= g_iLargestId; i++)
		if(g_Types[g_Objects[i][type]][e_Role] == ObjectRole_Godmode)
			if(HasUseAccess(client, i) && IsPosInRange(fPos, i, 262144.0)){
			
				bInRange = true;
				break;
			
			}

	if(view_as<bool>(g_bInGod[client]) == bInRange)
		return;

	if(g_bInGod[client] && !bInRange)
		SetEntityHealth(client, GetEntProp(client, Prop_Data, "m_iMaxHealth"));

	else
		SetEntityHealth(client, 999999);

	g_bInGod[client] = bInRange;

}


stock int GetLastClientId			(int client){

	int iBiggestId = -1;
	float fBiggestTime = 0.0;

	for(int i = 0; i <= g_iLargestId; i++)
		if(IsUsed(i) && g_Objects[i][owner] == client)
			if(g_Objects[i][time] > fBiggestTime){
			
				iBiggestId = i;
				fBiggestTime = g_Objects[i][time];
			
			}

	return iBiggestId;

}

stock int GetNextId					(){

	for(int i = 0; i < MAX_OBJECTS; i++)
		if(!IsUsed(i))
			return i;

	return -1;

}

stock int GetEntId					(int iEnt){

	for(int i = 0; i <= g_iLargestId; i++)
		if(g_Objects[i][entity] == iEnt)
			return i;

	return -1;

}

stock bool IsPosInRange				(float fPos[3], int iId, float fRange){

	if(fPos[2] < g_Objects[iId][pos][2] -32
	|| fPos[2] > g_Objects[iId][pos][2] +256)
		return false;

	float fObjectPos[3];
	GetObjectFloatPosition(iId, fObjectPos);
	return GetVectorDistance(fObjectPos, fPos, true) <= fRange;

}


stock float ModFloatInt				(float fVal, int iSub){

	return fVal -iSub *RoundToFloor(fVal /iSub);

}

stock float ModFloat				(float fVal, float fSub){

	return fVal -fSub *RoundToFloor(fVal /fSub);

}

stock bool IsUsed					(int iId){

	return iId == -1 ? false : g_Objects[iId][entity] != 0;

}

stock bool MatchPos					(int iObject, float fPos[3]){

	for(int i = 0; i < 3; i++)
		if(RoundFloat(fPos[i]) != g_Objects[iObject][pos][i])
			return false;

	return true;

}

stock void AddMenuItemF				(Handle &hMenu, const char[] sItem, const char[] sPreDesc, any ...){

	char sDesc[128];
	VFormat(sDesc, 128, sPreDesc, 4);

	AddMenuItem(hMenu, sItem, sDesc);

}

stock void AddMenuItemIF			(Handle &hMenu, int iItem, const char[] sPreDesc, any ...){

	char sDesc[128];
	VFormat(sDesc, 128, sPreDesc, 4);

	char[] sItem = new char[8];
	IntToString(iItem, sItem, 8);

	AddMenuItem(hMenu, sItem, sDesc);

}

stock void SetNextAttack			(int client, bool bSet){

	for(int i = 0; i < 3; i++)
		SetWeapon(GetPlayerWeaponSlot(client, i), bSet);

}

stock void SetWeapon				(int iEnt, bool bSet){

	if(iEnt <= MaxClients || !IsValidEntity(iEnt))
		return;

	SetEntPropFloat(iEnt, Prop_Data, "m_flNextPrimaryAttack", bSet ? GetGameTime() + 86400.0 : 0.1);
	SetEntPropFloat(iEnt, Prop_Data, "m_flNextSecondaryAttack", bSet ? GetGameTime() + 86400.0 : 0.1);

}

stock int GetWeaponSlot				(int client, int iWeap){

	for(int i = 0; i < 5; i++)
		if(GetPlayerWeaponSlot(client, i) == iWeap)
			return i;

	return 0;

}

stock bool RemoveValueFromArray		(Handle &hArray, int iValue){

	int iId = FindValueInArray(hArray, iValue);
	if(iId == -1)
		return false;

	RemoveFromArray(hArray, iId);
	return true;

}

stock int FindNearestObject			(int iId, ObjectRole objectRole, float fMaxRange=MAX_TELE_RANGE){

	if(iId == -1)
		return -1;

	if(g_iClientObjectCount[g_Objects[iId][owner]] <= 1)
		return -1;

	int iClosest = -1;
	float fClosestDist = fMaxRange, fCurrentDist = 0.0;
	for(int i = 0; i <= g_iLargestId; i++){
	
		if(i == iId)
			continue;
	
		if(!IsUsed(i))
			continue;
	
		if(g_Objects[iId][owner] != g_Objects[i][owner])
			continue;
	
		if(objectRole != g_Types[g_Objects[i][type]][e_Role])
			continue;
	
		fCurrentDist = GetObjectDistance(i, iId);
		if(fCurrentDist > fClosestDist)
			continue;
	
		fClosestDist = fCurrentDist;
		iClosest = g_Objects[i][entity];
	
	}

	return iClosest;

}

stock float GetObjectDistance		(int iId1, int iId2){

	float fPreDist = 0.0;
	for(int i = 0; i < 3; i++)
		fPreDist += IntPow(g_Objects[iId2][pos][i] -g_Objects[iId1][pos][i], 2);

	return SquareRoot(fPreDist);

}

stock float IntPow					(int iVal, int iExpo){

	return Pow(float(iVal), float(iExpo));

}

stock void GetObjectFloatPosition	(int iId, float fPos[3]){

	for(int i = 0; i < 3; i++)
		fPos[i] = float(g_Objects[iId][pos][i]);

}


stock bool HasUseAccess				(int client, int iId){

	if(iId == -1)
		return false;

	int iOwner = g_Objects[iId][owner];
	if(iOwner == 0)
		return true;

	return
		g_Access[iOwner][0] == BuildAccess_Use ||
		g_Access[iOwner][0] == BuildAccess_All ||
		g_Access[iOwner][client] == BuildAccess_Use ||
		g_Access[iOwner][client] == BuildAccess_All;

}

stock bool HasBuildAccess			(int client, int iId){

	if(iId == -1)
		return false;

	int iOwner = g_Objects[iId][owner];
	if(iOwner == 0)
		return true;

	return
		g_Access[iOwner][0] == BuildAccess_Build ||
		g_Access[iOwner][0] == BuildAccess_All ||
		g_Access[iOwner][client] == BuildAccess_Build ||
		g_Access[iOwner][client] == BuildAccess_All;

}

stock bool IsAdmin					(int client){

	return CheckCommandAccess(client, "", ADMFLAG_SLAY, true);

}

stock int GetClientFromAccountId	(int iAccountId){

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			if(g_iAccount[i] == iAccountId)
				return i;

	return 0;

}

stock void SetClientZVelocity		(int client, bool bGrab=true){

	if(!bGrab){
	
		g_fLastZVel[client] = 0.0;
		return;
	
	}

	float fVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);

	if(!(-0.1 < fVel[2] < 0.1))
		g_fLastZVel[client] = fVel[2];

}


stock void CleanPotentialLeftovers	(){

	char sName[32];
	int iEnt = -1;
	for(int i = 0; i < 2; i++)
		while((iEnt = FindEntityByClassname(iEnt, g_sClassnames[i])) != INVALID_ENT_REFERENCE){
		
			GetEntPropString(iEnt, Prop_Data, "m_iName", sName, 32);
			if(StrEqual(sName, ENT_NAME))
				AcceptEntityInput(iEnt, "Kill");
		
		}

}

stock void ShakeEffect				(int client){

	Handle hShake = StartMessageOne("Shake", client);
	if(hShake == INVALID_HANDLE)
		return;

	BfWriteByte(hShake, 0);
	BfWriteFloat(hShake, 25.0);
	BfWriteFloat(hShake, 25.0);
	BfWriteFloat(hShake, 0.5);
	EndMessage();

}

stock void TeleportEffect			(int client){

	Handle hFx = StartMessageOne("Fade", client);
	if(hFx == INVALID_HANDLE)
		return;

	BfWriteShort(hFx, 100);
	BfWriteShort(hFx, 0);
	BfWriteShort(hFx, 0x0011);
	BfWriteByte(hFx, 128);
	BfWriteByte(hFx, 128);
	BfWriteByte(hFx, 255);
	BfWriteByte(hFx, 64);
	EndMessage();

}

public bool TraceFilterPlayers		(int iEnt, int iMask, int iSelf){

	return !(1 <= iEnt <= MaxClients) && iEnt != iSelf;

}

stock void Lazor					(const float fStart[3], const float fEnd[3], const int iColor[4]){

	TE_SetupBeamPoints(fStart, fEnd, g_iDiscoSprite, 0, 0, 0, DISCO_INTERVAL, 3.0, 3.0, 7, 0.0, iColor, 0);
	TE_SendToAll();

}