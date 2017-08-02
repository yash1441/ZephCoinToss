#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.5"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <store>

#define MIN_CREDITS 10
#define MAX_CREDITS 5000

#define CHAT_PREFIX "[Coin-Toss]"

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

EngineVersion g_Game;

bool PleaseDo = true;
bool g_Wait = false;
bool g_bUsed[MAXPLAYERS + 1] = {false, ...};
bool g_Doit[MAXPLAYERS + 1] = {false, ...};
int g_Creds[MAXPLAYERS + 1] = {0, ...};
int g_Enemy[MAXPLAYERS + 1] = {0, ...};

public Plugin myinfo = 
{
	name = "Zephyrus-Store: Coin-Toss",
	author = PLUGIN_AUTHOR,
	description = "Coin Toss plugin for gambling credits.",
	version = PLUGIN_VERSION,
	url = "yash1441@yahoo.com"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	RegConsoleCmd("sm_coin", Cmd_Toss);
	RegConsoleCmd("sm_cointoss", Cmd_Toss);
	
	HookEvent("round_end", Event_OnRoundEnd);
}

public Action Cmd_Toss(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "%s This command is only for players", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	if(g_bUsed[client])
	{
		PrintToChat(client, "%s You are already in an ongoing Coin-Toss.", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	if(g_Wait)
	{
		PrintToChat(client, "%s There is an ongoing Coin-Toss. Please wait.", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		PrintToChat(client, "%s Usage: sm_coin <credits> <name or #userid>", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	char Target[64];
	char cHP[32];
	int target_final;
	GetCmdArg(1, cHP, sizeof(cHP));
	GetCmdArg(2, Target, sizeof(Target));
	
	
	
	int creds;
	creds = StringToInt(cHP);

	target_final = FindTarget(client, Target, true, false);


	if (target_final == -1)
		return Plugin_Handled;

	if (creds < MIN_CREDITS || creds > MAX_CREDITS)
	{
		PrintToChat(client, "%s Use a legit value of credits (%i - %i).", CHAT_PREFIX, MIN_CREDITS, MAX_CREDITS);
		return Plugin_Handled;
	}
	
	if(g_bUsed[target_final])
	{
		PrintToChat(client, "%s Opponent is already in an ongoing Coin-Toss.", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	int creds1 = Store_GetClientCredits(client);
	int creds2 = Store_GetClientCredits(target_final);
	if(creds > creds1)
	{
		PrintToChat(client, "%s You don't have enough credits.", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	if(creds > creds2)
	{
		PrintToChat(client, "%s Opponent doesn't have enough credits.", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	Store_SetClientCredits(client, Store_GetClientCredits(client) - creds);
	Store_SetClientCredits(target_final, Store_GetClientCredits(target_final) - creds);
	g_Creds[target_final] = creds;
	g_Creds[client] = creds;
	g_Enemy[client] = target_final;
	g_Enemy[target_final] = client;
	AcceptReject(client, target_final);
	
	PrintToChat(client, "<-------------Coin-Toss by Simon------------->");
	PrintToChat(target_final, "<-------------Coin-Toss by Simon------------->");

	return Plugin_Handled;
}

public void AcceptReject(int client, int other)
{
	Handle menu = CreateMenu(MyMenuHandler);
	
	// FormatEx Here
	char s_version[30];
	FormatEx(s_version, sizeof(s_version), "Coin-Toss: (%N) [%i Credits]", client, g_Creds[client]);
	SetMenuTitle(menu, s_version);
	AddMenuItem(menu, "accept", "Accept");
	AddMenuItem(menu, "reject", "Reject");
	SetMenuExitButton(menu, false);
	PleaseDo = true;
	CreateTimer(20.0, RejectIt, other);
	DisplayMenu(menu, other, MENU_TIME_FOREVER);
}

public Action RejectIt(Handle timer, int other)
{
	if (PleaseDo)
	{
		g_Doit[other] = false;
		checkreject(other);
		PleaseDo = false;
		CloseClientMenu(other);
	}
	
}

public int MyMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		decl String:info[11];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		if (strcmp(info,"accept") == 0) 
		{
			g_Doit[client] = true;
			g_Wait = true;
			PleaseDo = false;
		}
		
		else if (strcmp(info,"reject") == 0) 
		{
			g_Doit[client] = false;
			PleaseDo = false;
		}
	}
	checkreject(client);
	return 0;
}

public void checkreject(client)
{
	if(g_Doit[client])
		StartCoinToss(client, g_Enemy[client], g_Creds[client]);
	else
	{
		PrintToChat(client, "%s %N rejected your challenge.", CHAT_PREFIX, client);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_Creds[client]);
		Store_SetClientCredits(g_Enemy[client], Store_GetClientCredits(g_Enemy[client]) + g_Creds[g_Enemy[client]]);
	}
		
	g_Creds[client] = 0;
	g_Creds[g_Enemy[client]] = 0;
	g_Enemy[g_Enemy[client]] = 0;
	g_Enemy[client] = 0;
}

public void StartCoinToss(int you, int enemy, int prize)
{
	g_bUsed[you] = true;
	g_bUsed[enemy] = true;
	g_Doit[enemy] = false;
	PrintToChatAll("%s %N vs %N for %i credits.", CHAT_PREFIX, you, enemy, prize);
	//Store_SetClientCredits(you, Store_GetClientCredits(you) - prize);
	//Store_SetClientCredits(enemy, Store_GetClientCredits(enemy) - prize);
	
	int Total = (prize * 2);
	
	int random_number = GetRandomInt(1, 2);
	
	if(random_number == 1)
	{
		PrintToChatAll("%s %N won %i credits! %N lost!", CHAT_PREFIX, you, Total, enemy);
		Store_SetClientCredits(you, Store_GetClientCredits(you) + Total);
	}
	
	else
	{
		PrintToChatAll("%s %N won %i credits! %N lost!", CHAT_PREFIX, enemy, Total, you);
		Store_SetClientCredits(enemy, Store_GetClientCredits(enemy) + Total);
	}
	g_Wait = false;
}

public Action Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	LoopClients(i)
	{
		g_bUsed[i] = false;
	}
	return Plugin_Continue;
}

public void CloseClientMenu(client)
{
	Handle m_hMenu = CreateMenu(MenuHandler_CloseClientMenu);
	SetMenuTitle(m_hMenu, "Empty menu");
	DisplayMenu(m_hMenu, client, 1);
}

public int MenuHandler_CloseClientMenu(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
}
