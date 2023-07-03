#include <sourcemod>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define OUTERWALL_SAVEPATH "scriptdata/pf_outerwall/"
#define OUTERWALL_SAVETYPE ".sav"

#define MAX_SAVECOOKIES 128
#define MAX_COOKIESIZE 100
#define MAX_SAVESIZE 16384

bool g_bOuterWallSaveSyncEnabled = false;

Handle g_OuterWallSaveCookie[MAX_SAVECOOKIES];

public Plugin myinfo =
{
	name = "Outer Wall Save Sync",
	author = "Horiuchi",
	description = "A companion plugin for pf_outerwall that saves and loads save files from cookies",
	version = "1.2",
};

public void OnPluginStart()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	CheckIfPluginShouldBeActive(mapName);

	for(int i = 0; i < MAX_SAVECOOKIES; i++)
	{
		char cookie_name[32];
		Format(cookie_name, sizeof(cookie_name), "outerwall_save_%i", i);
		g_OuterWallSaveCookie[i] = RegClientCookie(cookie_name, "", CookieAccess_Protected);
	}
	
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
	char SaveFileString[MAX_SAVESIZE];

	if(ReadFileString(SaveFile, SaveFileString, sizeof(SaveFileString), -1) == -1)
		return;

	delete SaveFile;

	char SaveFileStringExplosion[MAX_SAVECOOKIES][MAX_COOKIESIZE];
	ExplodeString(SaveFileString, ";", SaveFileStringExplosion, sizeof(SaveFileStringExplosion), MAX_COOKIESIZE);

	for(int i = 0; i < sizeof(SaveFileStringExplosion); i++)
	{
		SetClientCookie(iClient, g_OuterWallSaveCookie[i], SaveFileStringExplosion[i]);
	}
}

public void OnClientCookiesCached(int iClient)
{
	if(!g_bOuterWallSaveSyncEnabled)
		return;

	char cookiebuffer[MAX_COOKIESIZE];
	char ConstructedSaveBuffer[MAX_SAVESIZE];
	for(int i = 0; i < sizeof(g_OuterWallSaveCookie); i++)
	{
		GetClientCookie(iClient, g_OuterWallSaveCookie[i], cookiebuffer, sizeof(cookiebuffer));

		if(cookiebuffer[0] == '\0')
			continue;

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