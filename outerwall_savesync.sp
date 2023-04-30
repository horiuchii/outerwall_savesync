#include <sourcemod>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define OUTERWALL_SAVEPATH "scriptdata/pf_outerwall/"
#define OUTERWALL_SAVETYPE ".sav"

bool g_bOuterWallSaveSyncEnabled = false;

enum ePlayerDataTypes
{
	PlayerDataTypes_map_version = 0,
	PlayerDataTypes_best_time,
	PlayerDataTypes_best_checkpoint_time_one,
	PlayerDataTypes_best_checkpoint_time_two,
	PlayerDataTypes_best_lapcount_encore,
	PlayerDataTypes_best_sandpit_time_encore,
	PlayerDataTypes_achievements,
	PlayerDataTypes_misc_stats,
	PlayerDataTypes_settings,
	PlayerDataTypes_MAX
};

Handle g_OuterWallSavePlayerDataTypes[PlayerDataTypes_MAX];

public Plugin myinfo =
{
	name = "Outer Wall Save Sync",
	author = "Horiuchi",
	description = "A companion plugin for pf_outerwall that saves and loads save files from cookies",
	version = "1.0",
};

public void OnPluginStart()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	CheckIfPluginShouldBeActive(mapName);

	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_map_version] = RegClientCookie("ows_map_version", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_best_time] = RegClientCookie("ows_best_time", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_best_checkpoint_time_one] = RegClientCookie("ows_best_checkpoint_time_one", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_best_checkpoint_time_two] = RegClientCookie("ows_best_checkpoint_time_two", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_best_lapcount_encore] = RegClientCookie("ows_best_lapcount_encore", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_best_sandpit_time_encore] = RegClientCookie("ows_best_sandpit_time_encore", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_achievements] = RegClientCookie("ows_achievements", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_misc_stats] = RegClientCookie("ows_misc_stats", "", CookieAccess_Private);
	g_OuterWallSavePlayerDataTypes[PlayerDataTypes_settings] = RegClientCookie("ows_settings", "", CookieAccess_Private);

	PrintToServer("Loaded outerwall_savesync...");
}

public void OnMapInit(const char[] mapName)
{
	CheckIfPluginShouldBeActive(mapName);
}

void CheckIfPluginShouldBeActive(const char[] mapName)
{
	g_bOuterWallSaveSyncEnabled = StrContains(mapName, "pf_outerwall") != -1 ? true : false;
	PrintToServer(g_bOuterWallSaveSyncEnabled ? "Outerwall_savesync is now ENABLED." : "Outerwall_savesync is now DISABLED.");
}

void GetSaveLocation(int iClient, char[] ReturnChar, int ReturnCharLength)
{
	char ClientSteamID[32];
	if(GetClientAuthId(iClient, AuthId_Steam3, ClientSteamID, sizeof(ClientSteamID), true))
	{
		char ClientSteamIDExplosion[3][32];
		ExplodeString(ClientSteamID, ":", ClientSteamIDExplosion, sizeof(ClientSteamIDExplosion), 32);

		int OuterwallAccountID = StringToInt(ClientSteamIDExplosion[1]) + StringToInt(ClientSteamIDExplosion[2]);
		char OuterwallSaveFile[64];
		Format(OuterwallSaveFile, sizeof(OuterwallSaveFile), "%s%i%s", OUTERWALL_SAVEPATH, OuterwallAccountID, OUTERWALL_SAVETYPE);
		strcopy(ReturnChar, ReturnCharLength, OuterwallSaveFile);
	}
}

void SavePlayerProfileToCookies(int iClient)
{
	char SaveLoc[64];
	GetSaveLocation(iClient, SaveLoc, sizeof(SaveLoc));

	if(!FileExists(SaveLoc, false))
		return;

	File SaveFile = OpenFile(SaveLoc, "r", false);
	char SaveFileString[512];

	if(ReadFileString(SaveFile, SaveFileString, sizeof(SaveFileString), -1) == -1)
		return;

	delete SaveFile;

	char SaveFileStringExplosion[PlayerDataTypes_MAX][64];
	ExplodeString(SaveFileString, ";", SaveFileStringExplosion, sizeof(SaveFileStringExplosion), 64);

	for(int i = 0; i < sizeof(SaveFileStringExplosion); i++)
	{
		SetClientCookie(iClient, g_OuterWallSavePlayerDataTypes[i], SaveFileStringExplosion[i]);
	}
}

public void OnClientCookiesCached(int iClient)
{
	if(!g_bOuterWallSaveSyncEnabled)
		return;

	char cookiebuffer[128];
	char ConstructedSaveBuffer[512];
	for(int i = 0; i < sizeof(g_OuterWallSavePlayerDataTypes); i++)
	{
		GetClientCookie(iClient, g_OuterWallSavePlayerDataTypes[i], cookiebuffer, sizeof(cookiebuffer));

		if(cookiebuffer[0] == '\0')
			return;

		Format(ConstructedSaveBuffer, sizeof(ConstructedSaveBuffer), "%s%s;", ConstructedSaveBuffer, cookiebuffer);
	}

	char SaveLoc[64];
	GetSaveLocation(iClient, SaveLoc, sizeof(SaveLoc));

	File SaveFile = OpenFile(SaveLoc, "w", false);
	WriteFileString(SaveFile, ConstructedSaveBuffer, true);
	delete SaveFile;
}

public void OnClientDisconnect(int iClient)
{
	if(!g_bOuterWallSaveSyncEnabled)
		return;

	SavePlayerProfileToCookies(iClient);
}

public void OnMapEnd()
{
	if(!g_bOuterWallSaveSyncEnabled)
		return;

	for(int i = MaxClients; i == 0; i--)
	{
		if(IsClientConnected(i))
			SavePlayerProfileToCookies(i);
	}
}