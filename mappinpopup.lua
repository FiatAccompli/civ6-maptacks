----------------------------------------------------------------  
-- MapPinPopup
--
-- Popup used for creating and editting map pins.
----------------------------------------------------------------  
include( "PlayerTargetLogic" );
include( "ToolTipHelper" );
include( "MapTacks" );
include( "mod_settings" );

----------------------------------------------------------------  
-- Globals
---------------------------------------------------------------- 
local COLOR_YELLOW				:number = 0xFF2DFFF8;
local COLOR_WHITE				:number = 0xFFFFFFFF;
 
local NO_EDIT_PIN_ID :number = -1;
local g_editPinID :number = NO_EDIT_PIN_ID; 
local g_uniqueIconsPlayer :number = nil;  -- tailor UAs to the player
local g_iconOptionEntries = {};
local g_visibilityTargetEntries = {};

local g_desiredIconName :string = "";

-- Default player target is self only.
local g_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_PLAYER, targetID = Game.GetLocalPlayer() };
local g_cachedChatPanelTarget = nil; -- Cached player target for ingame chat panel

local sendToChatTTStr = Locale.Lookup( "LOC_MAP_PIN_SEND_TO_CHAT_TT" );
local sendToChatNotVisibleTTStr = Locale.Lookup( "LOC_MAP_PIN_SEND_TO_CHAT_NOT_VISIBLE_TT" );

local basicControl;
local districtsControl;
local improvementsControl;
local domesticActionsControl;
local internationalActionsControl;
local militaryActionsControl;
local spyActionsControl;
local greatPeopleControl;
local governorsControl;
local yieldsControl;
local unitsControl;
local wondersControl;

local showBasicIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_BASIC_ICONS_SETTING");
local showDistrictIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_DISTRICT_ICONS_SETTING");
local showImprovementIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY","LOC_MAP_TACKS_SHOW_IMPROVEMENT_ICONS_SETTING");
local showDomesticActionIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_DOMESTIC_ACTION_ICONS_SETTING");
local showInternationalActionIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_INTERNATIONAL_ACTION_ICONS_SETTING");
local showMilitaryActionIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_MILITARY_ACTION_ICONS_SETTING");
local showSpyActionIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_SPY_ACTION_ICONS_SETTING");
local showGreatPeopleIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_GREAT_PEOPLE_ICONS_SETTING");
local showGovernorIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_GOVERNOR_ICONS_SETTING");
local showYieldIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_YIELD_ICONS_SETTING");
local showUnitIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_UNIT_ICONS_SETTING");
local showWonderIcons = ModSettings.Boolean:new(
    true, "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY", "LOC_MAP_TACKS_SHOW_WONDER_ICONS_SETTING");

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
function MapPinVisibilityToPlayerTarget(mapPinVisibility :number, playerTargetData :table)
	if(mapPinVisibility == ChatTargetTypes.CHATTARGET_ALL) then
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_ALL;
		playerTargetData.targetID = GetNoPlayerTargetID();
	elseif(mapPinVisibility == ChatTargetTypes.CHATTARGET_TEAM) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		local localTeam = localPlayer:GetTeam();
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_TEAM;
		playerTargetData.targetID = localTeam;
	elseif(mapPinVisibility >= 0) then
		-- map pin visibility stores individual player targets as a straight positive number
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_PLAYER;
		playerTargetData.targetID = mapPinVisibility;
	else
		-- Unknown map pin visibility state
		playerTargetData.targetType = ChatTargetTypes.NO_CHATTARGET;
		playerTargetData.targetID = GetNoPlayerTargetID();
	end
end

function PlayerTargetToMapPinVisibility(playerTargetData :table)
	if(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_ALL) then
		return ChatTargetTypes.CHATTARGET_ALL;
	elseif(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_TEAM) then
		return ChatTargetTypes.CHATTARGET_TEAM;
	elseif(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		-- map pin visibility stores individual player targets as a straight positive number
		return playerTargetData.targetID;
	end

	return ChatTargetTypes.NO_CHATTARGET;
end

function MapPinIsVisibleToChatTarget(mapPinVisibility :number, chatPlayerTarget :table)
	if(chatPlayerTarget == nil or mapPinVisibility == nil) then
		return false;
	end

	if(mapPinVisibility == ChatTargetTypes.CHATTARGET_ALL) then
		-- All pins are visible to all
		return true;
	elseif(mapPinVisibility == ChatTargetTypes.CHATTARGET_TEAM) then
		-- Team pins are visible in that team's chat and whispers to anyone on that team.
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		local localTeam = localPlayer:GetTeam();
		if(chatPlayerTarget.targetType == ChatTargetTypes.CHATTARGET_TEAM) then
			if(localTeam == chatPlayerTarget.targetID) then
				return true;
			end
		elseif(chatPlayerTarget.targetType == ChatTargetTypes.CHATTARGET_PLAYER and chatPlayerTarget.targetID ~= NO_PLAYERTARGET_ID) then
			local chatPlayerID = chatPlayerTarget.targetID;
			local chatPlayer = PlayerConfigurations[chatPlayerID];
			local chatTeam = chatPlayer:GetTeam();	
			if(localTeam == chatTeam) then
				return true;
			end	
		end
	elseif(mapPinVisibility >= 0) then
		-- Individual map pin is only visible to that player.
		if(chatPlayerTarget.targetType == ChatTargetTypes.CHATTARGET_PLAYER and mapPinVisibility == chatPlayerTarget.targetID) then
			return true;
		end
	end

	return false;
end


-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
function SetMapPinIcon(imageControl :table, mapPinIconName :string)
	if(imageControl ~= nil and mapPinIconName ~= nil) then
		imageControl:SetIcon(mapPinIconName);
	end
end

-- ===========================================================================
function PopulateIconOptions()
	-- unique icons are specific to the current player
	g_uniqueIconsPlayer = Game.GetLocalPlayer();
	
  PopulateIconOptionsForCategory(basicsControl.IconOptionStack, GetStockIcons(), true);
  PopulateIconOptionsForCategory(districtsControl.IconOptionStack, GetDistrictIcons());
  PopulateIconOptionsForCategory(improvementsControl.IconOptionStack, GetImprovementIcons());
  PopulateIconOptionsForCategory(domesticActionsControl.IconOptionStack, GetDomesticActionIcons());
  PopulateIconOptionsForCategory(internationalActionsControl.IconOptionStack, GetInternationalActionIcons());
  PopulateIconOptionsForCategory(militaryActionsControl.IconOptionStack, GetMilitaryActionIcons());
  PopulateIconOptionsForCategory(spyActionsControl.IconOptionStack, GetSpyActionIcons());
  PopulateIconOptionsForCategory(greatPeopleControl.IconOptionStack, GetGreatPeopleIcons());
  if (GameInfo.Governors) then 
    PopulateIconOptionsForCategory(governorsControl.IconOptionStack, GetGovernorIcons());
  end
  PopulateIconOptionsForCategory(yieldsControl.IconOptionStack, GetYieldIcons());
  PopulateIconOptionsForCategory(unitsControl.IconOptionStack, GetUnitIcons());
  PopulateIconOptionsForCategory(wondersControl.IconOptionStack, GetWonderIcons());

	--Controls.WindowContentsStack:CalculateSize();
	--Controls.WindowContentsStack:ReprocessAnchoring();
	--Controls.WindowStack:CalculateSize();
	--Controls.WindowStack:ReprocessAnchoring();
	--Controls.WindowContainer:ReprocessAnchoring();
end

function PopulateIconOptionsForCategory(control, iconData, smallIcons) 
  control:DestroyAllChildren();
  for _, iconData in ipairs(iconData) do
    local controlTable = {};
    local iconName = iconData.name;
    ContextPtr:BuildInstanceForControl(smallIcons and "IconOptionInstanceSmall" or "IconOptionInstance", controlTable, control);
    SetMapPinIcon(controlTable.Icon, iconName);
    controlTable.IconOptionButton:RegisterCallback(Mouse.eLClick, function() OnIconOption(iconName) end);

    if iconData.tooltip then
			local tooltip = ToolTipHelper.GetToolTip(iconData.tooltip, Game.GetLocalPlayer()) or Locale.Lookup(iconData.tooltip);
			controlTable.IconOptionButton:SetToolTipString(tooltip);
		end

    g_iconOptionEntries[iconName] = controlTable;
  end

  control:CalculateSize();
	control:ReprocessAnchoring();
end

-- ===========================================================================
function UpdateIconSelection(iconName, selected)
  local controlTable = g_iconOptionEntries[iconName];
  if controlTable ~= nil then
    controlTable.IconOptionButton:SetSelected(selected);
  end
end

-- ===========================================================================
function RequestMapPin(hexX :number, hexY :number)
	local activePlayerID = Game.GetLocalPlayer();
	-- update UA icons if the active player has changed
	if g_uniqueIconsPlayer ~= activePlayerID then PopulateIconOptions(); end
	local pPlayerCfg = PlayerConfigurations[activePlayerID];
	local pMapPin = pPlayerCfg:GetMapPin(hexX, hexY);
	if(pMapPin ~= nil) then
		g_editPinID = pMapPin:GetID();

    UpdateIconSelection(g_desiredIconName, false);
		g_desiredIconName = pMapPin:GetIconName();
    UpdateIconSelection(g_desiredIconName, true);
		if GameConfiguration.IsAnyMultiplayer() then
			MapPinVisibilityToPlayerTarget(pMapPin:GetVisibility(), g_playerTarget);
			UpdatePlayerTargetPulldown(Controls.VisibilityPull, g_playerTarget);
			Controls.VisibilityContainer:SetHide(false);
		else
			Controls.VisibilityContainer:SetHide(true);
		end

		Controls.PinName:SetText(pMapPin:GetName());
		Controls.PinName:TakeFocus();
		
		ShowHideSendToChatButton();

		Controls.OptionsStack:CalculateSize();
		Controls.OptionsStack:ReprocessAnchoring();
		Controls.WindowContentsStack:CalculateSize();
		Controls.WindowContentsStack:ReprocessAnchoring();
		Controls.WindowStack:CalculateSize();
		Controls.WindowStack:ReprocessAnchoring();
		Controls.WindowContainer:ReprocessAnchoring();

		UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
	end
end

-- ===========================================================================
-- Returns the map pin configuration for the pin we are currently editing.
-- Do not cache the map pin configuration because it will get destroyed by other processes.  Use it and get out!
function GetEditPinConfig()
	if(g_editPinID ~= NO_EDIT_PIN_ID) then
		local activePlayerID = Game.GetLocalPlayer();
		local pPlayerCfg = PlayerConfigurations[activePlayerID];
		local pMapPin = pPlayerCfg:GetMapPinID(g_editPinID);
		return pMapPin;
	end

	return nil;
end

-- Deletes the map pin with the given id
function RequestDeleteMapPin(mapPinID :number)
  if(mapPinID ~= nil) then
    local activePlayerID = Game.GetLocalPlayer();
    local pPlayerCfg = PlayerConfigurations[activePlayerID];
    pPlayerCfg:DeleteMapPin(mapPinID);
    Network.BroadcastPlayerInfo();
    UI.PlaySound("Map_Pin_Remove");
  end
end

-- ===========================================================================
function OnChatPanel_PlayerTargetChanged(playerTargetTable)
	g_cachedChatPanelTarget = playerTargetTable;
	if( not ContextPtr:IsHidden() ) then
		ShowHideSendToChatButton();
	end
end

-- ===========================================================================
function ShowHideSendToChatButton()
	local editPin = GetEditPinConfig();
	if(editPin == nil) then
		return;
	end

	local privatePin = editPin:IsPrivate();
	local showSendButton = GameConfiguration.IsNetworkMultiplayer() and not privatePin;

	Controls.SendToChatButton:SetHide(not showSendButton);

	-- Send To Chat disables itself if the current chat panel target is not visible to the map pin.
	if(showSendButton) then
		local chatVisible = MapPinIsVisibleToChatTarget(editPin:GetVisibility(), g_cachedChatPanelTarget);
		Controls.SendToChatButton:SetDisabled(not chatVisible);
		if(chatVisible) then
			Controls.SendToChatButton:SetToolTipString(sendToChatTTStr);
		else
			Controls.SendToChatButton:SetToolTipString(sendToChatNotVisibleTTStr);
		end
	end
end

-- ===========================================================================
function OnIconOption(iconName :string)
  UpdateIconSelection(g_desiredIconName, false);
	g_desiredIconName = iconName;
	UpdateIconSelection(g_desiredIconName, true);
end

-- ===========================================================================
function OnOk()
	if( not ContextPtr:IsHidden() ) then
		local editPin = GetEditPinConfig();
		if(editPin ~= nil) then
			editPin:SetName(Controls.PinName:GetText());
			editPin:SetIconName(g_desiredIconName);

			local newMapPinVisibility = PlayerTargetToMapPinVisibility(g_playerTarget);
			editPin:SetVisibility(newMapPinVisibility);

			Network.BroadcastPlayerInfo();
			UI.PlaySound("Map_Pin_Add");
		end

		UIManager:DequeuePopup( ContextPtr );
	end
end


-- ===========================================================================
function OnSendToChatButton()
	local editPinCfg = GetEditPinConfig();
	if(editPinCfg ~= nil) then
		editPinCfg:SetName(Controls.PinName:GetText());
		LuaEvents.MapPinPopup_SendPinToChat(editPinCfg:GetPlayerID(), editPinCfg:GetID());
	end
end

-- ===========================================================================
function OnDelete()
	local editPinCfg = GetEditPinConfig();
	if(editPinCfg ~= nil) then
		local activePlayerID = Game.GetLocalPlayer();
		local pPlayerCfg = PlayerConfigurations[activePlayerID];
		local deletePinID = editPinCfg:GetID();

		g_editPinID = NO_EDIT_PIN_ID;
		pPlayerCfg:DeleteMapPin(deletePinID);
		Network.BroadcastPlayerInfo();
		UI.PlaySound("Map_Pin_Remove");
	end
	UIManager:DequeuePopup( ContextPtr );
end

function OnCancel()
  Controls.PinName:GetText()
	UIManager:DequeuePopup( ContextPtr );
end
----------------------------------------------------------------  
-- Event Handlers
---------------------------------------------------------------- 
function OnMapPinPlayerInfoChanged( playerID :number )
	PlayerTarget_OnPlayerInfoChanged( playerID, Controls.VisibilityPull, nil, nil, g_visibilityTargetEntries, g_playerTarget, true);
end

function OnLocalPlayerChanged()
	g_playerTarget.targetID = Game.GetLocalPlayer();
	PopulateTargetPull(Controls.VisibilityPull, nil, nil, g_visibilityTargetEntries, g_playerTarget, true, OnVisibilityPull);

	if( not ContextPtr:IsHidden() ) then
		UIManager:DequeuePopup( ContextPtr );
	end
end

function OnDiplomacyMeet(player1ID:number, player2ID:number)
	local localPlayerID:number = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= -1) then
		-- Was the local player involved?
		if (player1ID == localPlayerID or player2ID == localPlayerID) then
			UpdateAvailableIcons();
		end
	end
end

function UpdateAvailableIcons() 
  PopulateIconOptions();
  UpdateIconSelection(g_desiredIconName, true);
end

function MakeCategoryUI(name:string, control:table, showSetting:table)
  local controlTable = {};
  ContextPtr:BuildInstanceForControl("IconCategoryInstance", controlTable, control);
  controlTable.CategoryName:LocalizeAndSetText(name);

  showSetting:AddChangedHandler(
    function(value)
      controlTable.Category:SetHide(not value);
    end);
  controlTable.Category:SetHide(not showSetting.Value);

  controlTable.CategoryName:RegisterCallback(Mouse.eLClick, 
    function()
      local value = controlTable.Icons:IsHidden();
      controlTable.Icons:SetHide(not value);
      controlTable.ExpanderIcon:SetTextureOffsetVal(0, value and controlTable.ExpanderIcon:GetSizeY() or 0);
    end);
  
  return controlTable;
end

-- ===========================================================================
--	Keyboard INPUT Handler
-- ===========================================================================
function KeyHandler( key:number )
	if (key == Keys.VK_ESCAPE) then 
    OnCancel(); 
    return true; 
  end
  if (key == Keys.VK_RETURN) then 
    OnOk(); 
    return true; 
  end
	return false;
end
-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end
-- ===========================================================================
--	INITIALIZE
-- ===========================================================================
function Initialize()
	ContextPtr:SetInputHandler( OnInputHandler, true );

  basicsControl = MakeCategoryUI("LOC_MAP_TACKS_BASICS_CATEGORY", Controls.IconCategoriesFirstColumn, showBasicIcons);
  districtsControl = MakeCategoryUI("LOC_HUD_DISTRICTS", Controls.IconCategoriesFirstColumn, showDistrictIcons);
  improvementsControl = MakeCategoryUI("LOC_TECH_FILTER_IMPROVEMENTS", Controls.IconCategoriesSecondColumn, showImprovementIcons);
  domesticActionsControl = MakeCategoryUI("LOC_MAP_TACKS_DOMESTIC_ACTIONS_CATEGORY", Controls.IconCategoriesSecondColumn, showDomesticActionIcons);
  internationalActionsControl = MakeCategoryUI("LOC_MAP_TACKS_INTERNATIONAL_ACTIONS_CATEGORY", Controls.IconCategoriesSecondColumn, showInternationalActionIcons);
  militaryActionsControl = MakeCategoryUI("LOC_MAP_TACKS_MILITARY_ACTIONS_CATEGORY", Controls.IconCategoriesSecondColumn, showMilitaryActionIcons);
  spyActionsControl = MakeCategoryUI("LOC_MAP_TACKS_SPY_ACTIONS_CATEGORY", Controls.IconCategoriesSecondColumn, showSpyActionIcons);
  greatPeopleControl = MakeCategoryUI("LOC_PEDIA_GREATPEOPLE_TITLE", Controls.IconCategoriesFirstColumn, showGreatPeopleIcons);
  if GameInfo.Governors then
    governorsControl = MakeCategoryUI("LOC_MAP_TACKS_GOVERNORS_CATEGORY", Controls.IconCategoriesFirstColumn, showGovernorIcons);
  end
  yieldsControl = MakeCategoryUI("LOC_HUD_REPORTS_TAB_YIELDS", Controls.IconCategoriesFirstColumn, showYieldIcons);
  wondersControl = MakeCategoryUI("LOC_CATEGORY_WONDER_NAME", Controls.IconCategoriesThirdColumn, showWonderIcons);
  unitsControl = MakeCategoryUI("LOC_TECH_FILTER_UNITS", Controls.IconCategoriesThirdColumn, showUnitIcons);
 
	PopulateIconOptions();

	PopulateTargetPull(Controls.VisibilityPull, nil, nil, g_visibilityTargetEntries, g_playerTarget, true, OnVisibilityPull);
	Controls.DeleteButton:RegisterCallback(Mouse.eLClick, OnDelete);
	Controls.DeleteButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.SendToChatButton:RegisterCallback(Mouse.eLClick, OnSendToChatButton);
	Controls.SendToChatButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk);
	Controls.OkButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.PinName:RegisterCommitCallback( OnOk );
	
  LuaEvents.MapTacks_UpdateAvailableIcons.Add(UpdateAvailableIcons);
	LuaEvents.MapPinPopup_RequestMapPin.Add(RequestMapPin);
	LuaEvents.ChatPanel_PlayerTargetChanged.Add(OnChatPanel_PlayerTargetChanged);
  LuaEvents.MapPinPopup_RequestDeleteMapPin.Add(RequestDeleteMapPin);

	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	Events.PlayerInfoChanged.Add(OnMapPinPlayerInfoChanged);
	Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
  Events.DiplomacyMeet.Add(OnDiplomacyMeet);

	-- Request the chat panel's player target so we have an initial value. 
	-- We have to do this because the map pin's context is loaded after the chat panel's 
	-- and the chat panel's show/hide handler is not triggered as expected.
	LuaEvents.MapPinPopup_RequestChatPlayerTarget();

	local canChangeName = GameCapabilities.HasCapability("CAPABILITY_RENAME");
	if(not canChangeName) then
		Controls.PinFrame:SetHide(true);
	end

end
Initialize();

-- vim: sw=4 ts=4
