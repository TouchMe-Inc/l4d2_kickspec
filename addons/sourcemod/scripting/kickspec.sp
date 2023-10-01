#pragma semicolon               1
#pragma newdecls                required

#include <colors>
#include <nativevotes_rework>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN


public Plugin myinfo = {
	name = "KickSpec",
	author = "TouchMe",
	description = "Vote to kick all spectators from the server",
	version = "build0001",
	url = "https://github.com/TouchMe-Inc/l4d2_kickspec"
}


// Libs
#define LIB_READY               "readyup"

#define VOTE_TIME               15

#define TRANSLATIONS            "kickspec.phrases"

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3


bool g_bReadyUpAvailable = false;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded() {
	g_bReadyUpAvailable = LibraryExists(LIB_READY);
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, LIB_READY)) {
		g_bReadyUpAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_READY)) {
		g_bReadyUpAvailable = true;
	}
}

public void OnPluginStart()
{
	LoadTranslations(TRANSLATIONS);

	RegConsoleCmd("sm_kickspec", Cmd_KickSpec, "Vote to kick all spectators from the server");
	RegConsoleCmd("sm_speckick", Cmd_KickSpec, "Vote to kick all spectators from the server");
}

Action Cmd_KickSpec(int iClient, int args)
{
	if (GetClientTeam(iClient) == TEAM_SPECTATOR && !IsClientAdmin(iClient)){
		return Plugin_Handled;
	}

	if (!NativeVotes_IsNewVoteAllowed())
	{
		CReplyToCommand(iClient, "%T%T", "TAG", iClient, "VOTE_COULDOWN", iClient, NativeVotes_CheckVoteDelay());
		return Plugin_Handled;
	}

	int iTotalPlayers;
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

	NativeVote hVote = new NativeVote(HandlerVote, NativeVotesType_Custom_YesNo);
	hVote.Initiator = iClient;
	hVote.DisplayVote(iPlayers, iTotalPlayers, VOTE_TIME);

	return Plugin_Handled;
}

/**
 * Called when a vote action is completed.
 *
 * @param hVote             The vote being acted upon.
 * @param tAction           The action of the vote.
 * @param iParam1           First action parameter.
 * @param iParam2           Second action parameter.
 */
Action HandlerVote(NativeVote hVote, VoteAction tAction, int iParam1, int iParam2)
{
	switch (tAction)
	{
		case VoteAction_Start:
		{
			if (g_bReadyUpAvailable) {
				ToggleReadyPanel(false);
			}
		}

		case VoteAction_Display:
		{
			char sVoteDisplayMessage[128];

			FormatEx(sVoteDisplayMessage, sizeof(sVoteDisplayMessage), "%T", "VOTE_TITLE", iParam1);

			hVote.SetDetails(sVoteDisplayMessage);

			return Plugin_Changed;
		}

		case VoteAction_Cancel: {
			hVote.DisplayFail();
		}

		case VoteAction_Finish:
		{
			if (iParam1 == NATIVEVOTES_VOTE_NO)
			{
				hVote.DisplayFail();

				return Plugin_Continue;
			}

			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
			{
				if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)
				|| GetClientTeam(iPlayer) != TEAM_SPECTATOR  || IsClientAdmin(iPlayer)) {
					continue;
				}

				KickClient(iPlayer, "%T", "KICK_REASON", iPlayer);
			}

			hVote.DisplayPass();
		}

		case VoteAction_End:
		{
			if (g_bReadyUpAvailable) {
				ToggleReadyPanel(true);
			}

			hVote.Close();
		}
	}

	return Plugin_Continue;
}

bool IsClientAdmin(int iClient) {
	return GetUserAdmin(iClient) != INVALID_ADMIN_ID;
}
