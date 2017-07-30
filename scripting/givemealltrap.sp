#pragma semicolon 1

#include <sdktools>

#define TRIGGER_COUNT	16
#define COOLDOWN		4
#define SOUND_TRUMPET	"music/trombonetauntv2.mp3"

int g_iNextTrumpet = 0;
int g_iCount = 0;
char g_sTriggers[TRIGGER_COUNT][] = {

	"givemeall", "giveall", "givemeitem", "givemeitems", "giveitem", "giveitems", "giveme", "australium", "hats", "unusuals", "taunt", "taunts", "givekey", "givekeys", "bhop", "bunnyhop"

};

public Plugin myinfo = {

	name = "Givemeall trap.",
	author = "Phil25",
	description = "That's gotta get rid of those pesky !givemeall folks."

};

public void OnMapStart(){

	PrecacheSound(SOUND_TRUMPET);

}

public Action OnClientSayCommand(int client, const char[] sCommand, const char[] sArgs){

	if(client == 0)
		return Plugin_Continue;

	if(!IsPlayerAlive(client))
		return Plugin_Continue;

	char sMessage[16];
	strcopy(sMessage, 16, sArgs);

	ReplaceString(sMessage, 2, "!", "");
	ReplaceString(sMessage, 2, "/", "");

	if(!IsTrigger(sMessage))
		return Plugin_Continue;

	FakeClientCommandEx(client, "explode");
	g_iCount++;
	PrintToChatAll("\x03[SM]\x01 Players who humiliated themselves: %d", g_iCount);

	int iTime = GetTime();
	if(g_iNextTrumpet >= iTime)
		return Plugin_Continue;

	EmitSoundToAll(SOUND_TRUMPET, client);
	g_iNextTrumpet = iTime +COOLDOWN;

	return Plugin_Continue;

}

bool IsTrigger(const char[] sString){

	for(int i = 0; i < TRIGGER_COUNT; i++)
		if(StrEqual(sString, g_sTriggers[i], false))
			return true;

	return false;

}