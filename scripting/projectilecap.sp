#pragma semicolon 1


#include <sdktools>


#define PROJECTILE_CAP 150


public Plugin myinfo = {

	name = "Projectile Cap",
	author = "Phil25",
	description = "Removes a projectile if there are too many."

};


Handle g_hStuff = INVALID_HANDLE;
int g_iStuffCount = 0;


public void OnPluginStart(){

	g_hStuff = CreateArray();

}

public void OnEntityCreated(int iEnt, const char[] sClassname){

	if(!IsProjectile(sClassname))
		return;

	PushArrayCell(g_hStuff, iEnt);
	g_iStuffCount++;

	if(g_iStuffCount > PROJECTILE_CAP)
		AcceptEntityInput(GetArrayCell(g_hStuff, 0), "Kill");

}

public void OnEntityDestroyed(int iEnt){

	int iId = FindValueInArray(g_hStuff, iEnt);
	if(iId == -1)
		return;

	RemoveFromArray(g_hStuff, iId);
	g_iStuffCount--;

}

bool IsProjectile(const char[] sClassname){

	return
		sClassname[3] == 'p' &&
		sClassname[4] == 'r' &&
		sClassname[5] == 'o' &&
		sClassname[6] == 'j'
	;

}