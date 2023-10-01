#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <colors>
#include <nativevotes_rework>


public Plugin myinfo = {
    name        = "KickSpec",
    author      = "TouchMe",
    description = "Vote to kick all spectators from the server",
    version     = "build0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_kickspec"
}


#define VOTE_TIME               15

#define TRANSLATIONS            "kickspec.phrases"

#define MAX_SHORT_NAME_LENGTH   18

/*
 * Team.
 */
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3


int g_iTarget = -1;


public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    RegConsoleCmd("sm_ks", Cmd_KickSpec, "Vote to kick all spectators from the server");
    RegConsoleCmd("sm_kickspec", Cmd_KickSpec, "Vote to kick all spectators from the server");
    RegConsoleCmd("sm_sk", Cmd_KickSpec, "Vote to kick all spectators from the server");
    RegConsoleCmd("sm_speckick", Cmd_KickSpec, "Vote to kick all spectators from the server");
}

Action Cmd_KickSpec(int iClient, int args)
{
    if (iClient == 0) {
        return Plugin_Continue;
    }

    if (GetClientTeam(iClient) == TEAM_SPECTATOR && !IsClientAdmin(iClient)){
        return Plugin_Handled;
    }

    ShowKickMenu(iClient);

    return Plugin_Handled;
}

void ShowKickMenu(int iClient)
{
    int iTotalPlayers = 0;
    int[] iPlayers = new int[MaxClients];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        if (GetClientTeam(iPlayer) != TEAM_SPECTATOR) {
            continue;
        }

        iPlayers[iTotalPlayers++] = iPlayer;
    }

    Menu menu = CreateMenu(HandlerKickMenu, MenuAction_Select|MenuAction_End);

    SetMenuTitle(menu, "%T", "MENU_KICK_TITLE", iClient);

    char szBuffer[64];
    FormatEx(szBuffer, sizeof szBuffer, "%T", "MENU_KICK_ALL_SPEC_ITEM", iClient);
    AddMenuItem(menu, "-1", szBuffer);

    char szTarget[4], szPlayerName[MAX_NAME_LENGTH];

    for (int iPlayerIndex = 0; iPlayerIndex < iTotalPlayers; iPlayerIndex ++)
    {
        int iPlayer = iPlayers[iPlayerIndex];

        IntToString(iPlayer, szTarget, sizeof szTarget);
        GetClientNameFixed(iPlayer, szPlayerName, sizeof szPlayerName, MAX_SHORT_NAME_LENGTH);

        AddMenuItem(menu, szTarget, szPlayerName, IsClientAdmin(iPlayer) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    DisplayMenu(menu, iClient, MENU_TIME_FOREVER);
}

/**
 *
 */
int HandlerKickMenu(Menu menu, MenuAction action, int iClient, int iItem)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char szTarget[4]; GetMenuItem(menu, iItem, szTarget, sizeof(szTarget));

            int iTarget = StringToInt(szTarget);

            if (iTarget != -1 && !IsClientInGame(iTarget)) {
                ShowKickMenu(iClient);
                return 0;
            }

            if (!RunVoteKick(iClient, iTarget))
            {
                ShowKickMenu(iClient);
                return 0;
            }
        }

        case MenuAction_End: delete menu;
    }

    return 0;
}

bool RunVoteKick(int iClient, int iTarget)
{
    if (!NativeVotes_IsNewVoteAllowed())
    {
        CReplyToCommand(iClient, "%T%T", "TAG", iClient, "VOTE_COULDOWN", iClient, NativeVotes_CheckVoteDelay());
        return false;
    }

    int iTotalPlayers = 0;
    int[] iPlayers = new int[MaxClients];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        int iTeam = GetClientTeam(iPlayer);

        if (iTeam == TEAM_INFECTED || iTeam == TEAM_SURVIVOR) {
            iPlayers[iTotalPlayers++] = iPlayer;
        }
    }

    g_iTarget = iTarget;

    NativeVote nv = new NativeVote(HandlerVoteKick, NativeVotesType_Custom_YesNo);
    nv.Initiator = iClient;
    nv.DisplayVote(iPlayers, iTotalPlayers, VOTE_TIME);

    return true;
}

/**
 * Called when a vote action is completed.
 *
 * @param nv             The vote being acted upon.
 * @param action           The action of the vote.
 * @param iParam1           First action parameter.
 * @param iParam2           Second action parameter.
 */
Action HandlerVoteKick(NativeVote nv, VoteAction action, int iParam1, int iParam2)
{
    switch (action)
    {
        case VoteAction_Display:
        {
            char szVoteDisplay[128];

            if (g_iTarget == -1) {
                FormatEx(szVoteDisplay, sizeof szVoteDisplay, "%T", "VOTE_KICK_ALL_SPEC_TITLE", iParam1);
            } else {
                char szPlayerName[MAX_NAME_LENGTH];
                GetClientNameFixed(iParam1, szPlayerName, sizeof szPlayerName, MAX_SHORT_NAME_LENGTH);
                FormatEx(szVoteDisplay, sizeof szVoteDisplay, "%T", "VOTE_TARGET_SPEC_TITLE", iParam1);
            }

            nv.SetDetails(szVoteDisplay);

            return Plugin_Changed;
        }

        case VoteAction_Cancel: nv.DisplayFail();

        case VoteAction_Finish:
        {
            if (iParam1 == NATIVEVOTES_VOTE_NO)
            {
                nv.DisplayFail();

                return Plugin_Continue;
            }

            nv.DisplayPass();

            if (g_iTarget == -1)
            {
                for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
                {
                    if (!IsClientInGame(iPlayer)
                    || IsFakeClient(iPlayer)
                    || !IsClientSpectator(iPlayer)
                    || IsClientAdmin(iPlayer)) {
                        continue;
                    }

                    KickClient(iPlayer, "%T", "KICK_REASON", iPlayer);
                }
            }

            else if (IsClientConnected(g_iTarget))
            {
                KickClient(g_iTarget, "%T", "KICK_REASON", g_iTarget);
            }
        }

        case VoteAction_End: nv.Close();
    }

    return Plugin_Continue;
}

bool IsClientSpectator(int iClient) {
    return GetClientTeam(iClient) == TEAM_SPECTATOR;
}

bool IsClientAdmin(int iClient) {
    return GetUserAdmin(iClient) != INVALID_ADMIN_ID;
}

/**
 *
 */
void GetClientNameFixed(int iClient, char[] name, int length, int iMaxSize)
{
    GetClientName(iClient, name, length);

    if (strlen(name) > iMaxSize)
    {
        name[iMaxSize - 3] = name[iMaxSize - 2] = name[iMaxSize - 1] = '.';
        name[iMaxSize] = '\0';
    }
}
