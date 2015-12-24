/*
-----------------------------------------------------------------------------
THE MLP HEROES MOD - SOURCEMOD PLUGIN
-----------------------------------------------------------------------------
Code Written By SuperStarPL (c) 2014
-----------------------------------------------------------------------------
This plugin was written with the intent of minibosses style gameplay
 in TF2.

Please visit http://www.marcinbebenek.capriolo.pl/rt/games/source/tf2/sm/mlpheroes/ for any questions, or for a live
server running the latest MLP Heroes Mod visit http://www.marcinbebenek.capriolo.pl/rt/games/source/tf2/sm/mlpheroes/status/.

Thank you and enjoy!
- SuperStarPL
-----------------------------------------------------------------------------
Version History

-- 0.0.3 (10/11/14)
 . Initial release!
 
-- 0.0.4 (19/01/15)
 . More Customizations + Bugfixes
-----------------------------------------------------------------------------
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <tf2items>
#include <sdkhooks>

//
// Global definitions
//
#define MAXENTITIES 2048
#define MAX_ITEMS	256

// Plugin version
#define PLUGIN_VERSION  "0.0.4"

// I'm sure these are defined somewhere else but hey, this is easier than finding out!
#define TEAM_RED        2
#define TEAM_BLU        3

#define TF2_SCOUT       1
#define TF2_SNIPER      2
#define TF2_SOLDIER     3
#define TF2_DEMOMAN     4
#define TF2_MEDIC       5
#define TF2_HEAVY       6
#define TF2_PYRO        7
#define TF2_SPY         8
#define TF2_ENGINEER    9

//Boss' customization init
#define BOSS_COUNT		2

new boss = 1; //change to getrandomint after testing
new HuntedClass = 5;

new String:weaponName[128];
new weapon_Index;
new weaponLevel;
new weaponQuality;
new String:weaponAttributes[256];

new weaponCount = 1;

new String:weaponName2[128];
new weapon_Index2;
new weaponLevel2;
new weaponQuality2;
new String:weaponAttributes2[256];

new String:weaponName3[128];
new weapon_Index3;
new weaponLevel3;
new weaponQuality3;
new String:weaponAttributes3[256];

new String:weaponName4[128];
new weapon_Index4;
new weaponLevel4;
new weaponQuality4;
new String:weaponAttributes4[256];

new String:modelPath[256] = "models/player/engineer.mdl";

//new String:g_strItemModel[MAX_ITEMS][PLATFORM_MAX_PATH];
//new g_iPlayerItem[MAXPLAYERS+1] = { -1, ... };
//new g_iPlayerBGroups[MAXPLAYERS+1];
new iWinningTeam = TEAM_RED;


// Class that is used as the Hunted, default is Engineer.
// To best replicate Hunted gameplay, do not use a class that is
// playable by either the Bodyguards or the Assassians.

//#define HUNTED_CLASS	9
//new HuntedClass  =  9; // TF2_ENGINEER

// Assassin kill score amounts, unused right now as personal scoring is broken
// const AssassinKillHunted = 10;
// const AssassinKillHuntedAssist = 5;

// Other global variable inits
new String:g_szClientCurrentScale[MAXPLAYERS+1][16];
new Float:g_fClientCurrentScale[MAXPLAYERS+1] = {1.0, ... };
new Float:g_fClientLastScale[MAXPLAYERS+1] = {1.0, ... };
new String:g_szClientLastScale[MAXPLAYERS+1][16];
new bool:g_bHitboxAvailable = false;
new Handle:g_hClientResizeTimers[MAXPLAYERS+1] = { INVALID_HANDLE, ... };
new bool:g_bIsTF2 = false;

new CurrentHunted = -1;             // ClientID of the current Hunted
new PreviousHunted = -1;            // ClientID of the previous Hunted, used for anti-grief checks
new bool:IsPluginEnabled = true;
new bool:IsHuntedDead = false;
new bool:IsHuntedOnCap = false;
new bool:NewHuntedOnWarning = false;
new HuntedCapPoint = -1;

// CVars
new Handle:cvarEnabled;
new Handle:cvarPyroMode;
new Handle:cvarMaxPyros;

// Plugin Info
public Plugin:myinfo =
{
    name = "MLP Heroes Mod (Blu only!)",
    author = "SuperStarPL",
//   description = "",
    version = PLUGIN_VERSION,
    url = "http://www.marcinbebenek.capriolo.pl/rt/games/source/tf2/sm/mlpheroes/"
};

// Main plugin init - here we go!
public OnPluginStart()
{
	HookEvent("teamplay_round_start", event_round_start);
	CreateConVar("sm_mlph_version", PLUGIN_VERSION, "MLP Heroes Mod Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvarEnabled = CreateConVar("sm_mlph_enable", "1", "Enable/Disable the MLPH plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
//    cvarPyroMode = CreateConVar("sm_hunted_pyromode", "1", "Cap Pyros by amount (0) or percentage (1)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
//    cvarMaxPyros = CreateConVar("sm_hunted_maxpyros", "3", "Max Pyro count or percentage (3 = 30%)", FCVAR_PLUGIN, true, 0.0, true, 10.0);

	LoadTranslations("common.phrases");
	LoadTranslations("mlph.phrases");
    
	PrecacheSound("misc/your_team_won.mp3", true);
	PrecacheSound("misc/your_team_lost.mp3", true);

	HookEvent("controlpoint_starttouch", event_CPStartTouch);
	HookEvent("controlpoint_endtouch", event_CPEndTouch);
	HookEvent("teamplay_round_start", event_RoundStart);
	HookEvent("player_spawn", event_PlayerRespawn);
	HookEvent("player_changeclass", event_ChangeClass);
	HookEvent("player_death", event_PlayerDeath);
	// HookEvent("player_chargedeployed", event_PlayerDeployUber);
    
	HookConVarChange(cvarEnabled, CheckHuntedEnabled);

	RegConsoleCmd("equip", cmd_Equip);
    // RegConsoleCmd("say", cmd_VoteHunted);

	RegAdminCmd("sm_mlph_reload", cmd_Reload, ADMFLAG_KICK, "Reload Boss Specs (fix)");
	RegAdminCmd("sm_mlph_setboss", cmd_SetBossNext, ADMFLAG_KICK, "Set the next boss");
	RegAdminCmd("sm_mlph_reset", cmd_ResetHunted, ADMFLAG_KICK, "Force all players to respawn");
	RegAdminCmd("sm_mlph_force", cmd_ForceHunted, ADMFLAG_KICK, "Select a random new Hunted, and force all players to respawn");
	RegAdminCmd("sm_mlph_set", cmd_SetPlayerHunted, ADMFLAG_KICK, "Select a new Hunted by name|ClientID");

	CreateTimer(10.0, timer_NoHuntedWarning, INVALID_HANDLE, TIMER_REPEAT);
	CreateTimer(0.1, timer_HuntedItemStrip, INVALID_HANDLE);

	PrecacheModel("models/jugcustom/mlp/applejack/engineer1.mdl");
	PrecacheModel("models/jugcustom/mlp/fluttershy/medic1.mdl");
	
	UpdateBossSpecs();
	
	AutoExecConfig(true, "mlph_b", "sourcemod");
}
public DeD()
{
	new iEnt = -1;
	iEnt = FindEntityByClassname(iEnt, "game_round_win");

	if (iEnt < 1)
	{
		iEnt = CreateEntityByName("game_round_win");
		if (IsValidEntity(iEnt))
		{
			DispatchSpawn(iEnt);
		}
	}
	SetVariantInt(iWinningTeam);
	AcceptEntityInput(iEnt, "SetTeam");
	AcceptEntityInput(iEnt, "RoundWin");
}

// Probably not necessary but better safe than sorry
public OnPluginEnd()
{
    CurrentHunted = -1;
    PreviousHunted = -1;
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{

	UpdateBossSpecs();
	
	for(new entity=MaxClients+1; entity<MAXENTITIES; entity++)
	{
		if(!IsValidEdict(entity))
		{
			continue;
		}

		decl String:classname[64];
		GetEdictClassname(entity, classname, 64);
		if(!strcmp(classname, "func_regenerate"))
		{
			AcceptEntityInput(entity, "Kill");
		}
//		else if(!strcmp(classname, "func_respawnroomvisualizer"))
//		{
//			AcceptEntityInput(entity, "Disable");
//		}
	}
	return Plugin_Continue;
}

public Action:ResizeTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client > 0)
	{
		ResizePlayer(client, (g_fClientCurrentScale[client] == g_fClientLastScale[client] ? "1.0" : "0.0"));
		g_hClientResizeTimers[client] = INVALID_HANDLE;
	}
}

// When a new map is started and ended, the current and previous Hunted
// IDs are cleared out, so that the server does not get put into an
// endless loop or, more likely, disallow any Blue from going Hunted because
// the plugin thinks there already is one.
//
// Note in the MasterCheckPlayer function it allows a player to switch to
// the Hunted class if CurrentHunted = -1 or = 0, this is because for some
// unexplored reason the CurrentHunted gets changed to 0 during map change.
// This is probably due to the GetRandomHunted coming up with no response,
// and this may require further investigation in the future.

public OnMapStart()
{
    CurrentHunted = -1;
    PreviousHunted = -1;

    PrecacheSound("misc/your_team_won.mp3", true);
    PrecacheSound("misc/your_team_lost.mp3", true);
	
	UpdateBossSpecs();
}

public OnMapEnd()
{
    CurrentHunted = -1;
    PreviousHunted = -1;
}

public CheckHuntedEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if (StringToInt(newValue) == 1)
    {
        PrintToChatAll("[MLP Heroes] %T", "MLPHActivated", LANG_SERVER);
        GetRandomHunted();
        RespawnPlayers();
    }
    else
    {
        PrintToChatAll("[MLP Heroes] %T", "MLPHDeactivated", LANG_SERVER);
        CurrentHunted = -1;
        PreviousHunted = -1;
        RespawnPlayers();
    }
}

public UpdateBossSpecs()
{
	if(boss == 1) //Why not, Applejack's first :D
	{
//		#undef HUNTED_CLASS
//		#define HUNTED_CLASS	9
		HuntedClass  =  TF2_ENGINEER; // TF2_ENGINEER 9
		
		weaponCount = 4;

		weaponName = "tf_weapon_wrench";
		weapon_Index = 7;
		weaponQuality = 5;
		weaponAttributes = "275 ; 1 ; 57 ; 20 ; 80 ; 2 ; 107 ; 1.3 ; 113 ; 20 ; 140 ; 9875 ; 150 ; 1 ; 239 ; 1.25 ; 286 ; 1.2 ; 326 ; 1.5 ; 109 ; 0.2 ; 400 ; 1 ; 465 ; 2";
		/*
		275 ; 1			Wearer never takes falling damage
		57 ; 20 		+20 health regenerated per second on wearer
		80 ; 2 			200% max metal on wearer
		107 ; 1.3 		30% faster move speed on wearer
		113 ; 20		20 metal regenerated every 5 seconds on wearer
		140 ; 9850		+9875 max health on wearer
		150 ; 1			Imbued with an ancient power
		239 ; 1.25		+25% ÜberCharge rate for the medic healing you. This effect does not work in the respawn room	
		286 ; 1.2		+20% max building health
		326 ; 1.5		+50% greater jump height when active
		109 ; 0.2		20% health from packs on wearer
		400 ; 1			Wearer cannot carry the intelligence briefcase
		465 ; 2			Increases teleporter build speed by 100%
		*/
		
		weaponName2 = "tf_weapon_pda_engineer_build";
		weapon_Index2 = 25;
		weaponQuality2 = 5;
		weaponAttributes2 = "286 ; 1.2";
		
		weaponName3 = "tf_weapon_pda_engineer_destroy";
		weapon_Index3 = 26;
		weaponQuality3 = 5;
		weaponAttributes3 = "286 ; 1.2";

		weaponName4 = "tf_weapon_builder";
		weapon_Index4 = 28;
		weaponQuality4 = 5;
		weaponAttributes4 = "286 ; 1.2";
		
		modelPath = "models/jugcustom/mlp/applejack/engineer1.mdl";
	}
	
	if(boss == 2) //Fluttershy
	{
//		#undef HUNTED_CLASS
//		#define HUNTED_CLASS	5
		HuntedClass  =  TF2_MEDIC; // TF2_MEDIC 9
		
		weaponCount = 2;

		weaponName = "tf_weapon_bonesaw";
		weapon_Index = 8;
		weaponQuality = 5;
		weaponAttributes = "275 ; 1 ; 200 ; 1 ; 57 ; 20 ; 107 ; 1.3 ; 140 ; 9875 ; 150 ; 1 ; 239 ; 1.25 ; 326 ; 1.5 ; 109 ; 0.2 ; 400 ; 1";
		/*
		275 ; 1			Wearer never takes falling damage
		200 ; 1			On Taunt: Applies a healing effect to all nearby teammates
		57 ; 20 		+20 health regenerated per second on wearer
		107 ; 1.3 		30% faster move speed on wearer
		140 ; 9875		+9875 max health on wearer
		150 ; 1			Imbued with an ancient power
		239 ; 1.25		+25% ÜberCharge rate for the medic healing you. This effect does not work in the respawn room
		326 ; 1.5		+50% greater jump height when active
		109 ; 0.2		20% health from packs on wearer
		400 ; 1			Wearer cannot carry the intelligence briefcase
		*/
		
		weaponName2 = "tf_weapon_medigun";
		weapon_Index2 = 29;
		weaponQuality2 = 5;
		weaponAttributes2 = "200 ; 1";
		/*
		200 ; 1			On Taunt: Applies a healing effect to all nearby teammates
		*/
		
//		weaponName3 = "tf_weapon_pda_engineer_destroy";
//		weapon_Index3 = 26;
//		weaponQuality3 = 5;
//		weaponAttributes3 = "286 ; 1.2";

//		weaponName4 = "tf_weapon_builder";
//		weapon_Index4 = 28;
//		weaponQuality4 = 5;
//		weaponAttributes4 = "286 ; 1.2";
		
		modelPath = "models/jugcustom/mlp/fluttershy/medic1.mdl";
	}
}

public Action:cmd_Reload(client, args)
{
	UpdateBossSpecs();
}
//ADMIN FUNCTION - Set next boss
public Action:cmd_SetBossNext(client, args)
{
	new String:liczba[32];
    new arg1 = GetCmdArg(1, liczba, sizeof(liczba));
	
	if(arg1 == 1)
	{
		boss = 1;
	}
	
	if(arg1 == 2)
	{
		boss = 2;
	}
	
	UpdateBossSpecs();
}

// ADMIN FUNCTION - Respawn all players
public Action:cmd_ResetHunted(client, args)
{
    RespawnPlayers();
    return Plugin_Handled;
}

// ADMIN FUNCTION - Force reset of all players, and choose a random Hunted
public Action:cmd_ForceHunted(client, args)
{
    GetRandomHunted();
    RespawnPlayers();

    PrintToChatAll("[MLP Heroes] %T", "NewMLPH", LANG_SERVER);
    PrintToConsole(client, "[MLP Heroes] %t", "NewMLPH");
    return Plugin_Handled;
}

// ADMIN FUNCTION - Force a given player to be the Hunted
public Action:cmd_SetPlayerHunted(client, args)
{
    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));

    new target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    PreviousHunted = CurrentHunted;
    CurrentHunted = target;
    ChangeClientTeam(CurrentHunted, 3);
    SetPlayerClass(CurrentHunted, HuntedClass);
    RespawnPlayers();

    new String:name[MAX_NAME_LENGTH];
    GetClientName(CurrentHunted, name, sizeof(name));

    PrintToChatAll("[MLP Heroes] %T", "PlayerNewMLPH", LANG_SERVER, name);
    PrintToConsole(client, "[MLP Heroes] %t", "PlayerNewMLPH", name);
    return Plugin_Handled;
}

// Hooks resupply and ammo pickup, so that the Hunted can be stripped.
public Action:cmd_Equip(client, args)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

    if (client == CurrentHunted)
        CreateTimer(0.5, timer_HuntedChangeWeapons);
}

// Remove all weapons and metal from the Hunted
public Action:timer_HuntedItemStrip(Handle:timer)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

    if (!IsPlayerHunted(CurrentHunted) || GetClientCount() == 0)
        return;

    for (new i = 0; i <= 5; i++)
    {
        if (i == 2)
            continue;

        TF2_RemoveWeaponSlot(CurrentHunted, i);
    }
//		SetEntityModel(CurrentHunted, modelPath);

//   SetEntData(CurrentHunted, FindSendPropInfo("CTFPlayer", "m_iAmmo") + ((3)*4), 0);
}
/*
//New version of striping
public Action:timer_HuntedItemStrip(Handle:timer)
{
	TF2_RemoveAllWeapons(CurrentHunted);
}*/

// Forces the Hunted to change weapons, so they do not go into Civilian mode
public Action:timer_HuntedChangeWeapons(Handle:timer)
{
	if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
		return;

	if (!IsPlayerHunted(CurrentHunted))
		return;

	for (new i = 0; i <= 5; i++)
	{
		if(boss == 1)
		{
			if (i == 2 || i == 4 || i == 5)
				continue;
		}
		else
		if (i == 2)
			continue;

		TF2_RemoveWeaponSlot(CurrentHunted, i);
	}

	SpawnWeapon(CurrentHunted, weaponName, weapon_Index, weaponLevel, weaponQuality, weaponAttributes);

	switch(weaponCount)
{
	case 2:
	{
		SpawnWeapon(CurrentHunted, weaponName2, weapon_Index2, weaponLevel2, weaponQuality2, weaponAttributes2);
	}

	case 3:
	{
		SpawnWeapon(CurrentHunted, weaponName2, weapon_Index2, weaponLevel2, weaponQuality2, weaponAttributes2);
		SpawnWeapon(CurrentHunted, weaponName3, weapon_Index3, weaponLevel3, weaponQuality3, weaponAttributes3);
	}
	
	case 4:
	{
		SpawnWeapon(CurrentHunted, weaponName2, weapon_Index2, weaponLevel2, weaponQuality2, weaponAttributes2);
		SpawnWeapon(CurrentHunted, weaponName3, weapon_Index3, weaponLevel3, weaponQuality3, weaponAttributes3);
		SpawnWeapon(CurrentHunted, weaponName4, weapon_Index4, weaponLevel4, weaponQuality4, weaponAttributes4);
	}
}
	
	ResizePlayer(CurrentHunted, "0.75");
	
	ClientCommand(CurrentHunted, "slot2");
	ClientCommand(CurrentHunted, "slot3");

	SetVariantString(modelPath);
	AcceptEntityInput(CurrentHunted, "SetCustomModel");
	SetEntProp(CurrentHunted, Prop_Send, "m_bUseClassAnimations", 1);
}

// Checks to see if the Hunted left the server, and if so it prompts
// for a new Hunted.

public OnClientDisconnect(client)
{
    if (CurrentHunted == client)
    {
        CurrentHunted = -1;
        NewHuntedOnWarning = false;
    }
}

// Randomly selects a new Hunted from the Blue team.
public GetRandomHunted()
{
    new maxplayers = GetMaxClients();

    decl Bodyguards[maxplayers];
    new team;
    new index = 0;
    
    if (GetClientCount() == 0 || GetTeamClientCount(3) < 2)
    {
        NewHuntedOnWarning = false;
        return;
    }

    for (new i = 1; i <= maxplayers; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i))
        {
            team = GetClientTeam(i);
            if (team == 3 && i != CurrentHunted)
            {
                Bodyguards[index] = i;
                index++;
            }
        }
    }

    new rand = GetRandomInt(0, index - 1);
    if (Bodyguards[rand] < 1 || !IsClientConnected(Bodyguards[rand]) || !IsClientInGame(Bodyguards[rand]))
    {
        NewHuntedOnWarning = false;
        return;
    }
    else
    {
        PreviousHunted = CurrentHunted;
        CurrentHunted = Bodyguards[rand];
        ChangeClientTeam(CurrentHunted, 3);
        SetPlayerClass(CurrentHunted, HuntedClass);
    }
}

// Timer that checks to see if there is currently no Hunted, and
// displays pop-up messages to the Blue team that someone needs
// to switch to the Hunted. After 20 seconds it picks one randomly.

public Action:timer_NoHuntedWarning(Handle:timer)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
		return;

    if (IsPlayerHunted(CurrentHunted))
        return;

    if (GetClientCount() == 0 || GetTeamClientCount(3) < 2)
        return;

    new String:Message[256];

    if (!NewHuntedOnWarning)
    {
        Format(Message, sizeof(Message), "%T", "NoMLPHWarning", LANG_SERVER);
        DisplayText(Message, "3");
        HuntedHintText(Message, 3);
        NewHuntedOnWarning = true;
    }
    else
    {
        GetRandomHunted();
        Format(Message, sizeof(Message), "%T", "NewMLPH", LANG_SERVER);
        DisplayText(Message, "3");
        HuntedHintText(Message, 3);
        NewHuntedOnWarning = false;
    }
}

public Action:event_ChangeClass(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
		return;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new class = GetEventInt(event, "class");

    if (client == CurrentHunted && class != HuntedClass)
    {
        PreviousHunted = CurrentHunted;
        CurrentHunted = -1;
        NewHuntedOnWarning = false;
    }

    if (client == CurrentHunted)
        CreateTimer(0.5, timer_HuntedChangeWeapons);
}

public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
		return;

    if (GetClientCount() == 0)
        return;

    GetRandomHunted();
    RespawnPlayers();

    new String:Message[256];
    Format(Message, sizeof(Message), "%T", "NewMLPH", LANG_SERVER);
    DisplayText(Message, "3");
    HuntedHintText(Message, 3);
//	CreateTimer(1.0, timer_HuntedChangeWeapons);
}

// Checks to see if the Hunted has died, and if so it announces the killer,
// sets everyone to respawn when the Hunted does, and gives the Assassins
// a team point. I am considering adding a psuedo-Humiliation mode here,
// but right now I don't want to have it.
//
// Removed player respawning if the killer is the Hunted or Worldspawn,
// IE suicide, falling from a ledge, etc. This prevents people from spamming
// "Hunted Change" to grief, and to fix the exploit of changing Hunteds right
// before setup ends, allowing Blue easier capping of the first point on multi
// stage maps like Dustbowl.

public Action:event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
		return;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new Killer = GetClientOfUserId(GetEventInt(event, "attacker"));
    new Assister = GetClientOfUserId(GetEventInt(event, "assister"));

    new String:Message[256];
    
    if (CurrentHunted == client)
    {
	
		//DeD();
		
        if (Killer == 0 || Killer == CurrentHunted)
        {
            Format(Message, sizeof(Message), "%T", "MLPHDied", LANG_SERVER);
            DisplayText(Message, "3");
            HuntedHintText(Message, 3);

            if (!IsPlayerHunted(CurrentHunted))
            {
                PreviousHunted = CurrentHunted;
                CurrentHunted = -1;
            }
        }
        else
        {
            new String:KillerName[256];
            GetClientName(Killer, KillerName, sizeof(KillerName));

            IsHuntedDead = true;
            NewHuntedOnWarning = false;

            // Update the Assassins's score.
            // Thanks to berni for making this update properly!

            new Score = GetTeamScore(2);
            Score += 1;
            SetTeamScore(2, Score);
            // ChangeEdictState(CTeam); // Maybe not berni. :(

            if (Assister == 0)
                Format(Message, sizeof(Message), "%T", "KilledMLPH", LANG_SERVER, KillerName);
            else
            {
                new String:AssisterName[256];
                GetClientName(Assister, AssisterName, sizeof(AssisterName));

                Format(Message, sizeof(Message), "%T", "KilledMLPHAssist", LANG_SERVER, KillerName, AssisterName);
            }

            DisplayText(Message, "0");
            PrintHintTextToAll(Message);

/*          new maxplayers = GetMaxClients();
            new team;

            for (new i = 1; i <= maxplayers; i++)
            {
                if (IsClientConnected(i) && IsClientInGame(i))
                {
                    team = GetClientTeam(i);
                    if (team == 2)
                        EmitSoundToClient(i, "misc/your_team_won.mp3");
                    if (team == 3)
                        EmitSoundToClient(i, "misc/your_team_lost.mp3");
                }
            }
*/
        }

        NewHuntedOnWarning = false;
    }
}

// Checks to see if 1.) the Hunted has died, and 2.) if the Hunted respawns
// it forces all players to respawn. It also does another MasterPlayerCheck
// to make sure nobody has tried to pull any shenanigans for changing class.

public Action:event_PlayerRespawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
		return;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (!IsClientConnected(client) && !IsClientInGame(client))
        return;

    if (CurrentHunted == client && IsHuntedDead)
    {
        RespawnPlayers();
        IsHuntedDead = false;
		CreateTimer(0.5, timer_HuntedItemStrip);
//        CreateTimer(1.0, timer_HuntedChangeWeapons);
    }

    if (client == CurrentHunted && !IsPlayerHunted(CurrentHunted))
    {
        PreviousHunted = CurrentHunted;
        CurrentHunted = -1;
        NewHuntedOnWarning = false;
    }
//	CreateTimer(0.5, timer_HuntedItemStrip);
//	CreateTimer(1.0, timer_HuntedChangeWeapons);
    
//    MasterCheckPlayer(client);
}

// Respawns all players, except the Hunted. The Hunted is not respawned because
// it throws the plugin into an endless loop. This is used when the Hunted
// respawns normally, so there is no real need to respawn him again.

public RespawnPlayers()
{
    if (GetClientCount() < 1)
        return;

    new maxplayers = GetMaxClients();
    
    for (new i = 1; i <= maxplayers; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && IsClientOnTeam(i))
        {
            if (i == CurrentHunted)
            {
                CreateTimer(0.5, timer_HuntedItemStrip);
//				CreateTimer(1.0, timer_HuntedChangeWeapons);
                continue;
            }

            TF2_RespawnPlayer(i);
			CreateTimer(0.5, timer_HuntedItemStrip);
        }
    }

    new RedCount = GetTeamClientCount(2);
    new BlueCount = GetTeamClientCount(3);

    if (BlueCount < 2)
        return;

    if (RedCount > BlueCount)
    {
        decl Assassins[maxplayers];
        new index = 0;
        new team;

        for (new i = 1; i <= maxplayers; i++)
        {
            if (IsClientConnected(i) && IsClientInGame(i))
            {
                team = GetClientTeam(i);
                if (team == 2)
                {
                    Assassins[index] = i;
                    index += 1;
                }
            }
        }

        new rand;
        while (GetTeamClientCount(2) > GetTeamClientCount(3))
        {
            rand = GetRandomInt(0, index - 1);

            team = GetClientTeam(Assassins[rand]);
            if (team == 2 && IsClientConnected(Assassins[rand]) && IsClientInGame(Assassins[rand]) && IsClientOnTeam(Assassins[rand]))
            {
                ChangeClientTeam(Assassins[rand], 3);
                TF2_RespawnPlayer(Assassins[rand]);
                PrintToChat(Assassins[rand], "[MLP Heroes] %t", "TeamBalanced");
            }
        }
    }
}

// Used to check if the client is on a team, and not a Spectator
public bool:IsClientOnTeam(client)
{
    if (client == -1 || client == 0)
        return false;

    if (IsClientConnected(client) && IsClientInGame(client))
    {
        new team = GetClientTeam(client);
        switch (team)
        {
            case 2:
                return true;
            case 3:
                return true;
            default:
                return false;
        }
    }

    return false;
}

// Check if the Red team can support more Pyros, used when a Red player spawns.
// Returns true if Pyro is not maxed out, false otherwise.

public bool:CheckMaxPyros()
{
    new MaxPyros = GetConVarInt(cvarMaxPyros);
    new PyroMode = GetConVarInt(cvarPyroMode);
    new PyroCount = 0;
    new team;
    
    new maxplayers = GetMaxClients();
    for (new i = 1; i <= maxplayers; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i))
        {
            team = GetClientTeam(i);
			if (team == 2 && TF2_GetPlayerClass(i) == TF2_PYRO)
                PyroCount += 1;
        }
    }

    if (PyroMode == 0)
    {
        if (PyroCount > MaxPyros)
            return false;
        else
            return true;
    }
    else if (PyroMode == 1)
    {
        MaxPyros = ((GetTeamClientCount(2) * MaxPyros) / 10);
        if (MaxPyros < 1)
            MaxPyros = 0;

        if (PyroCount > MaxPyros)
            return false;
        else
            return true;
    }

    return false;
}

// This is the primary function that controls player class control and whether or
// not someone is allowed to be the Hunted. Right now the allowable classes are hard
// set here, so for future releases where customizable Bodyguard, Assassin, and
// Hunted classes are desired this section will more or less need to be rewritten.


public MasterCheckPlayer(client)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

	new class;
	new team;
//	new rand;
    
    if (!IsPlayerHunted(CurrentHunted))
    {
        PreviousHunted = CurrentHunted;
        CurrentHunted = -1;
    }

	class = TF2_GetPlayerClass(client);
	team = GetClientTeam(client);

    switch (team)
    {
        // Assassin class assignments
        case 2:
        {
            /*
			switch (class)
            {
                case TF2_PYRO:
                {
                    if (CheckMaxPyros())
                        PrintToChat(client, "[MLP Heroes] %t", "AssassinSpawn");
                    else
                    {
                        ShowVGUIPanel(client, GetClientTeam(client) == 3 ? "class_blue" : "class_red");

                        rand = GetRandomInt(1, 2);
                        if (rand == 1)
                            SetPlayerClass(client, TF2_SNIPER);
                        if (rand == 2)
                            SetPlayerClass(client, TF2_SPY);
                    }
                }
                case TF2_SNIPER:
                    PrintToChat(client, "[MLP Heroes] %t", "AssassinSpawn");
                case TF2_SPY:
                    PrintToChat(client, "[MLP Heroes] %t", "AssassinSpawn");
                default:
                {
                    ShowVGUIPanel(client, GetClientTeam(client) == 3 ? "class_blue" : "class_red");

                    rand = GetRandomInt(1, 3);
                    if (rand == 1)
                        SetPlayerClass(client, TF2_SNIPER);
                    if (rand == 2)
                        SetPlayerClass(client, TF2_SPY);
                    if (rand == 3)
                        SetPlayerClass(client, TF2_PYRO);
                }
            }
			*/
        }
        // Bodyguard / Hunted class assignements
        case 3:
        {
                if(class == HuntedClass)
                {
                    // Disallow the PreviousHunted to become the Hunted again for anti-grief
                    if (PreviousHunted == client)
                    {
                    /*	ShowVGUIPanel(client, GetClientTeam(client) == 3 ? "class_blue" : "class_red");
                        
						rand = GetRandomInt(1, 3);
                        if (rand == 1)
                            SetPlayerClass(client, TF2_SOLDIER);
                        if (rand == 2)
                            SetPlayerClass(client, TF2_HEAVY);
                        if (rand == 3)
                            SetPlayerClass(client, TF2_MEDIC);
                    
					*/
					}
                    else if (CurrentHunted == -1 || CurrentHunted == 0 || CurrentHunted == client)
                    {
                        CurrentHunted = client;
                        CreateTimer(0.5, timer_HuntedChangeWeapons);
                        NewHuntedOnWarning = false;
                        PrintToChat(client, "[MLP Heroes] %t", "MLPHSpawn");
                    }
 //                   else
 //                   {
                    /*	ShowVGUIPanel(client, GetClientTeam(client) == 3 ? "class_blue" : "class_red");

                        rand = GetRandomInt(1, 3);
                        if (rand == 1)
                            SetPlayerClass(client, TF2_SOLDIER);
                        if (rand == 2)
                            SetPlayerClass(client, TF2_HEAVY);
                        if (rand == 3)
                            SetPlayerClass(client, TF2_MEDIC);
                    */
//					}
                
				
				}
				
                if(class == TF2_SOLDIER)
				{
					PrintToChat(client, "[MLP Heroes] %t", "BodyguardSpawn");
                }
				if(class == TF2_MEDIC)
				{
					PrintToChat(client, "[MLP Heroes] %t", "BodyguardSpawn");
                }
				if(class == TF2_HEAVY)
				{
                    PrintToChat(client, "[HUNTED] %t", "BodyguardSpawn");
				}
                /*    ShowVGUIPanel(client, GetClientTeam(client) == 3 ? "class_blue" : "class_red");

                    rand = GetRandomInt(1, 3);
                    if (rand == 1)
                        SetPlayerClass(client, TF2_SOLDIER);
                    if (rand == 2)
                        SetPlayerClass(client, TF2_HEAVY);
                    if (rand == 3)
                        SetPlayerClass(client, TF2_MEDIC);
				*/
        }
        default:
            return;
    
	
	}
}

// Used to check if the client actually is the Hunted by checking Class and Team.
public bool:IsPlayerHunted(client)
{
    if (client < 1)
        return false;

    if (IsClientConnected(client) && IsClientInGame(client))
    {
		new class = TF2_GetPlayerClass(client);
		new team = GetClientTeam(client);

		if (class == HuntedClass && team == 3 && client == CurrentHunted)
			return true;

		return false;
	}
	else
		return false;
}

// Set's a client's class and forces them to respawn
public SetPlayerClass(client, class)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

	TF2_SetPlayerClass(client, class, false, true);
    TF2_RespawnPlayer(client);
}

// DisplayText function modified from the SM_Showtext plugin by Mammal Master.
// Used to display information about the Hunted's status or death. Since this
// is not shown if a player has Minimal HUD enabled, the HintText has also been
// used at the same time.

public Action:DisplayText(String:string[256], String:team[2])
{
    new Text = CreateEntityByName("game_text_tf");
    DispatchKeyValue(Text, "message", string);
    DispatchKeyValue(Text, "display_to_team", team);
    DispatchKeyValue(Text, "icon", "leaderboard_dominated");
    DispatchKeyValue(Text, "targetname", "game_text1");
    DispatchKeyValue(Text, "background", team);
    DispatchSpawn(Text);

    AcceptEntityInput(Text, "Display", Text, Text);

    CreateTimer(5.0, KillText, Text);
}

public Action:KillText(Handle:timer, any:ent)
{
    if (IsValidEntity(ent))
        AcceptEntityInput(ent, "kill");

    return;
}

// Send Hint text to only a certain team
public HuntedHintText(String:string[256], SendToTeam)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

    new maxplayers = GetMaxClients();
    new team;

    for (new i = 1; i <= maxplayers; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i))
        {
            team = GetClientTeam(i);
            if (team == SendToTeam)
                PrintHintText(i, string);
        }
    }
}

// Event for when a player leaves a Control Point area. This is used to Disable
// the Control Points when the Hunted leaves the zone.

public Action:event_CPEndTouch(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

    new client = GetEventInt(event, "player");
    
    if (!IsClientConnected(client) || !IsClientInGame(client))
        return;
    
    new team = GetClientTeam(client);

    if (team == 3)
    {
        new class = TF2_GetPlayerClass(client);
        if (class == HuntedClass)
        {
            IsHuntedOnCap = false;
            HuntedCapPoint = -1;

            CreateTimer(3.0, timer_EnableCP);
            ControlCP("Disable");
        }
    }
}

// Event for when a player enters a Control Point area. This is used to Enable or
// Disable all of the control points when the Hunted is or is not in the area.
// This is a super hack but hey, it works.

public Action:event_CPStartTouch(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

    new client = GetEventInt(event, "player");

    if (!IsClientConnected(client) || !IsClientInGame(client))
        return;

    new area = GetEventInt(event, "area");
    new team = GetClientTeam(client);

    if (team == 3)
    {
        new class = TF2_GetPlayerClass(client);

        if (class == HuntedClass)
        {
            IsHuntedOnCap = true;
            HuntedCapPoint = area;
            CreateTimer(0.0, timer_EnableCP);
        }
        else
        {
            if (area == HuntedCapPoint)
            {
                if (!IsHuntedOnCap)
                {
                    CreateTimer(1.0, timer_EnableCP);
                    CreateTimer(0.0, timer_DisableCP);
                }
            }
            else
            {
                IsHuntedOnCap = false;
                CreateTimer(1.0, timer_EnableCP);
                CreateTimer(0.0, timer_DisableCP);
            }
        }
    }
}

// Enable all Control Points after a given time.
public Action:timer_EnableCP(Handle:timer)
{
    ControlCP("Enable");
}

// Disable all Control Points after a given time, if the Hunted is not
// within a Capture zone. The reason for the Timer on this is because
// there was a bug that arose that would not properly allow the capture
// point to be triggered if there were too many Blue members on it at once.

public Action:timer_DisableCP(Handle:timer)
{
    if (!IsHuntedOnCap)
        ControlCP("Disable");
}

// Loop through all possible trigger_capture_area entities in the map and
// Enable or Disable them. This assumes there are no more than 16 possible
// capture zones in a map - it WILL error in some unknown way if this plugin
// is played on a map with more!

public ControlCP(String:input[])
{
    if (!GetConVarInt(cvarEnabled) || !IsPluginEnabled)
        return;

    new i = -1;
    new CP = 0;

    for (new n = 0; n <= 16; n++)
    {
        CP = FindEntityByClassname(i, "trigger_capture_area");
        if (IsValidEntity(CP))
        {
            AcceptEntityInput(CP, input);
            i = CP;
        }
        else
            break;
    }
}

stock SpawnWeapon(client, String:name[], index, level, qual, String:att[]) //giving weapon for boss
{
	new Handle:hWeapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(hWeapon==INVALID_HANDLE)
	{
		return -1;
	}

	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count=ExplodeString(att, ";", atts, 32, 32);

	if(count % 2)
	{
		--count;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2;
		for(new i; i<count; i+=2)
		{
			new attrib=StringToInt(atts[i]);
			if(!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", atts[i], atts[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}

			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	new entity=TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

//Resize boss
stock bool:ResizePlayer(const client, const String:szScale[] = "0.0", const bool:bLog = false, const iOrigin = -1, const String:szTime[] = "0.0", const bool:bCheckStuck = false)
{
	new Float:fScale = StringToFloat(szScale), Float:fTime = StringToFloat(szTime);
	decl String:szOriginalScale[16];
	strcopy(szOriginalScale, sizeof(szOriginalScale), g_szClientCurrentScale[client]);
	
	if (fScale == 0.0)
	{
		if (g_fClientCurrentScale[client] != g_fClientLastScale[client])
		{
			SetEntPropFloat(client, Prop_Send, "m_flModelScale", g_fClientLastScale[client]);
			//SetEntPropFloat(client, Prop_Send, "m_flStepSize", 18.0 * g_fClientLastScale[client]);
			g_fClientCurrentScale[client] = g_fClientLastScale[client];
			strcopy(g_szClientCurrentScale[client], sizeof(g_szClientCurrentScale[]), g_szClientLastScale[client]);
		}
		else
		{
			SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.0);
			//SetEntPropFloat(client, Prop_Send, "m_flStepSize", 18.0);
			g_fClientCurrentScale[client] = 1.0;
			strcopy(g_szClientCurrentScale[client], sizeof(g_szClientCurrentScale[]), "1.0");
		}
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", fScale);
		//SetEntPropFloat(client, Prop_Send, "m_flStepSize", 18.0 * fScale);
		g_fClientCurrentScale[client] = fScale;
		strcopy(g_szClientCurrentScale[client], sizeof(g_szClientCurrentScale[]), szScale);
	}
	
	if (g_bHitboxAvailable)
	{
		UpdatePlayerHitbox(client);
	}
	
	if (bCheckStuck && IsPlayerAlive(client) && IsPlayerStuck(client))
	{
		ResizePlayer(client, szOriginalScale);
		return false;
	}
	
	if (fScale != 1.0 && fScale != 0.0)
	{
		g_fClientLastScale[client] = fScale;
		strcopy(g_szClientLastScale[client], sizeof(g_szClientLastScale[]), szScale);
	}
	
	if (fTime > 0.0)
	{
		g_hClientResizeTimers[client] = CreateTimer(fTime, ResizeTimer, GetClientUserId(client));
	}
	
	if (bLog)
	{
		if (iOrigin > -1)
		{
			if (fTime > 0.0)
			{
//				LogAction(iOrigin, client, "\"%L\" resized \"%L\" to %s for %s seconds.", iOrigin, client, g_szClientCurrentScale[client], szTime);				
			}
			else
			{
//				LogAction(iOrigin, client, "\"%L\" resized \"%L\" to %s.", iOrigin, client, g_szClientCurrentScale[client]);
			}
		}
		else
		{
//			LogAction(0, client, "\"%L\" was resized to %s.", client, g_szClientCurrentScale[client]);
		}
	}
	return true;
}

stock UpdatePlayerHitbox(const client)
{
	static const Float:vecTF2PlayerMin[3] = { -24.5, -24.5, 0.0 }, Float:vecTF2PlayerMax[3] = { 24.5,  24.5, 83.0 };
	static const Float:vecGenericPlayerMin[3] = { -16.5, -16.5, 0.0 }, Float:vecGenericPlayerMax[3] = { 16.5,  16.5, 73.0 };
	decl Float:vecScaledPlayerMin[3], Float:vecScaledPlayerMax[3];
	if (g_bIsTF2)
	{
		vecScaledPlayerMin = vecTF2PlayerMin;
		vecScaledPlayerMax = vecTF2PlayerMax;
	}
	else
	{
		vecScaledPlayerMin = vecGenericPlayerMin;
		vecScaledPlayerMax = vecGenericPlayerMax;
	}
	ScaleVector(vecScaledPlayerMin, g_fClientCurrentScale[client]);
	ScaleVector(vecScaledPlayerMax, g_fClientCurrentScale[client]);
	SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
	SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
}

stock bool:IsPlayerStuck(const client)
{
	decl Float:vecMins[3], Float:vecMaxs[3], Float:vecOrigin[3];
	GetClientMins(client, vecMins);
	GetClientMaxs(client, vecMaxs);
	GetClientAbsOrigin(client, vecOrigin);
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer, client);
	return TR_DidHit();
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return (entity < 1 || entity > MaxClients);
}