-- ===========================================================================
-- MapTacks
-- utility functions

include ("ModSettings")

local g_debugLeader = nil;
-- g_debugLeader = GameInfo.Leaders.LEADER_BARBAROSSA
-- g_debugLeader = GameInfo.Leaders.LEADER_CATHERINE_DE_MEDICI
-- g_debugLeader = GameInfo.Leaders.LEADER_CLEOPATRA
-- g_debugLeader = GameInfo.Leaders.LEADER_GANDHI
-- g_debugLeader = GameInfo.Leaders.LEADER_GILGAMESH
-- g_debugLeader = GameInfo.Leaders.LEADER_GORGO
-- g_debugLeader = GameInfo.Leaders.LEADER_HARDRADA
-- g_debugLeader = GameInfo.Leaders.LEADER_HOJO
-- g_debugLeader = GameInfo.Leaders.LEADER_MVEMBA
-- g_debugLeader = GameInfo.Leaders.LEADER_PEDRO
-- g_debugLeader = GameInfo.Leaders.LEADER_PERICLES
-- g_debugLeader = GameInfo.Leaders.LEADER_PETER_GREAT
-- g_debugLeader = GameInfo.Leaders.LEADER_PHILIP_II
-- g_debugLeader = GameInfo.Leaders.LEADER_QIN
-- g_debugLeader = GameInfo.Leaders.LEADER_SALADIN
-- g_debugLeader = GameInfo.Leaders.LEADER_TOMYRIS
-- g_debugLeader = GameInfo.Leaders.LEADER_TRAJAN
-- g_debugLeader = GameInfo.Leaders.LEADER_T_ROOSEVELT
-- g_debugLeader = GameInfo.Leaders.LEADER_VICTORIA
-- g_debugLeader = GameInfo.Leaders.LEADER_JOHN_CURTIN
-- g_debugLeader = GameInfo.Leaders.LEADER_MONTEZUMA
-- g_debugLeader = GameInfo.Leaders.LEADER_ALEXANDER
-- g_debugLeader = GameInfo.Leaders.LEADER_CYRUS
-- g_debugLeader = GameInfo.Leaders.LEADER_AMANITORE
-- g_debugLeader = GameInfo.Leaders.LEADER_JADWIGA

-- ===========================================================================
-- Build the grid of map pin icon options

function GetLocalPlayerTraits()
	local activePlayerID = Game.GetLocalPlayer();
	local pPlayerCfg = PlayerConfigurations[activePlayerID];
  local leader = GameInfo.Leaders[pPlayerCfg:GetLeaderTypeID()];
  if g_debugLeader then leader = g_debugLeader; end
  local civ = leader.CivilizationCollection[1];
  	
  -- Get unique traits for the player civilization
	local traits = {};
  AddTraits(traits, leader.TraitCollection);
  AddTraits(traits, civ.TraitCollection);
  return traits;
end

function AddTraits(traits, collection) 
  for i, item in ipairs(collection) do
    traits[item.TraitType] = true;
  end
end

function GetStockIcons() 
  return {
	  { name="ICON_MAP_PIN_STRENGTH" },
	  { name="ICON_MAP_PIN_RANGED"   },
	  { name="ICON_MAP_PIN_BOMBARD"  },
	  { name="ICON_MAP_PIN_DISTRICT" },
	  { name="ICON_MAP_PIN_CHARGES"  },
	  { name="ICON_MAP_PIN_DEFENSE"  },
	  { name="ICON_MAP_PIN_MOVEMENT" },
	  { name="ICON_MAP_PIN_NO"       },
	  { name="ICON_MAP_PIN_PLUS"     },
	  { name="ICON_MAP_PIN_CIRCLE"   },
	  { name="ICON_MAP_PIN_TRIANGLE" },
	  { name="ICON_MAP_PIN_SUN"      },
	  { name="ICON_MAP_PIN_SQUARE"   },
	  { name="ICON_MAP_PIN_DIAMOND"  },
  };
end

function IconInfoForDistrict(district)
  local tooltip = "";
  if district.CityCenter or district.InternalOnly then
    tooltip = district.Name
  else 
    tooltip = district.DistrictType;
  end
  return { name = "ICON_" .. district.DistrictType, tooltip = tooltip };
end

function GetDistrictIcons() 
  local icons = {};
  local traits = GetLocalPlayerTraits();

	-- Get unique district replacement info
	local districts = {};
	for item in GameInfo.Districts() do
		if traits[item.TraitType] then
			for i, swap in ipairs(item.ReplacesCollection) do
				local base = swap.ReplacesDistrictType;
				districts[base] = item;
			end
		end
	end
  table.insert(icons, IconInfoForDistrict(GameInfo.Districts.DISTRICT_WONDER));
	for item in GameInfo.Districts() do
		local itype = item.DistrictType;
		if districts[itype] then
			-- unique district replacements for this civ
			table.insert(icons, IconInfoForDistrict(districts[itype]));
		elseif item.TraitType then
			-- skip other unique districts
		elseif itype ~= "DISTRICT_WONDER" then
			table.insert(icons, IconInfoForDistrict(item));
		end
	end
  return icons;
end

local uniqueImprovementsSettingValues = {"LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_SELF_ONLY",
                                         "LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_MET_MINOR_CIVS_IN_GAME",
                                         "LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_MINOR_CIVS_IN_GAME",
                                         "LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_ALL_MINOR_CIVS",
                                         "LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_MET_CIVS_IN_GAME",
                                         "LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_ALL_CIVS_IN_GAME",
                                         "LOC_MAP_TACKS_UNIQUE_IMPROVEMENTS_OPTION_ALL"};
local uniqueImprovementSetting = ModSettings.Select:new(uniqueImprovementsSettingValues, 2, 
  "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY",
  "LOC_MOD_TACKS_UNIQUE_IMPROVEMENTS_SETTING", "LOC_MOD_TACKS_UNIQUE_IMPROVEMENTS_SETTING_TOOLTIP");
uniqueImprovementSetting:AddChangedHandler(
  function()
    LuaEvents.MapTacks_UpdateAvailableIcons();
  end);

function GetImprovementTraitsFunc()
  if uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[7] then
    -- All
    return function() return true end;
  elseif uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[4] then
    -- All minor civs
    local traits = GetLocalPlayerTraits();
    return function(trait) return trait:sub(1,10) == "MINOR_CIV_" or traits[trait] end;
  else 
    local traits = GetLocalPlayerTraits();
    traits["TRAIT_CIVILIZATION_NO_PLAYER"] = true; -- Governor improvements always available
    local players = PlayerManager.GetWasEverAlive(); 
    local localPlayerID = Game.GetLocalPlayer();

    if localPlayerId ~= -1 then
      local diplomacy = Players[localPlayerID]:GetDiplomacy();
      for _, player in ipairs(players) do
        if not player:IsBarbarian() then
          local hasMet = diplomacy:HasMet(player:GetID());
          local playerCfg = PlayerConfigurations[player:GetID()];
          local leader = GameInfo.Leaders[playerCfg:GetLeaderTypeID()];
          local civ = leader.CivilizationCollection[1];

          if player:IsMajor() then
            if (hasMet and uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[5]) or
               (uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[6]) then
              AddTraits(traits, leader.TraitCollection);
              AddTraits(traits, civ.TraitCollection);
            end
          else
            if (hasMet and (uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[5]
                            or uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[2])) or
               (uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[3]) or 
               (uniqueImprovementSetting.Value == uniqueImprovementsSettingValues[6]) then
              AddTraits(traits, leader.TraitCollection);
              AddTraits(traits, civ.TraitCollection);
            end
          end
        end
      end
    end

    return function(trait) return traits[trait] end;
  end
end

function MakeUnitOperationIcon(item) 
  return { name = item.Icon, tooltip = item.Description };
end

function GetImprovementIcons()
  local traitFunc = GetImprovementTraitsFunc();

  local builderIcons = {};
	local uniqueIcons = {};
	local governorIcons = {};
	local minorCivIcons = {};
	local engineerIcons = {};

	for item in GameInfo.Improvements() do
		-- does this improvement have a valid build unit?
		local units = item.ValidBuildUnits;
		if #units ~= 0 then
			local entry = { name = item.Icon, tooltip = item.ImprovementType };
			local unit = GameInfo.Units[units[1].UnitType];
			local trait = item.TraitType or unit.TraitType;
			if trait then
        if traitFunc(trait) then
				  if trait == "TRAIT_CIVILIZATION_NO_PLAYER" then
					  -- governor improvements
					  table.insert(governorIcons, entry);
				  elseif trait:sub(1, 10) == "MINOR_CIV_" then
					  table.insert(minorCivIcons, entry);
          else 
            table.insert(uniqueIcons, entry);
				  end
        end
			elseif unit.UnitType == "UNIT_BUILDER" then
				table.insert(builderIcons, entry);
			else
				table.insert(engineerIcons, entry);
			end
		end
	end

  local icons = {};
  for _, v in ipairs(uniqueIcons) do table.insert(icons, v); end
  for _, v in ipairs(builderIcons) do table.insert(icons, v); end
  for _, v in ipairs(governorIcons) do table.insert(icons, v); end
  for _, v in ipairs(minorCivIcons) do table.insert(icons, v); end
  for _, v in ipairs(engineerIcons) do table.insert(icons, v); end
  table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_PLANT_FOREST));
  table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_REMOVE_FEATURE));
  table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_HARVEST_RESOURCE));
  table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_BUILD_IMPROVEMENT));
  return icons;
end

function GetDomesticActionIcons()
  return {
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_FOUND_CITY),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_FOUND_RELIGION),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_BUILD_ROUTE),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_CLEAR_CONTAMINATION),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_REPAIR),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_DESIGNATE_PARK),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_EXCAVATE),
    {
      name="ICON_UNITOPERATION_SPY_COUNTERSPY_ACTION",
      -- Description="LOC_UNIT_SPY_NAME",
      tooltip="LOC_UNITOPERATION_SPY_COUNTERSPY_DESCRIPTION",
    },
    -- GameInfo.Notifications.NOTIFICATION_CITY_RANGE_ATTACK,
    -- GameInfo.Notifications.NOTIFICATION_BARBARIANS_SIGHTED,
    -- GameInfo.Notifications.NOTIFICATION_DISCOVER_GOODY_HUT,
    MakeUnitOperationIcon(GameInfo.UnitCommands.UNITCOMMAND_ACTIVATE_GREAT_PERSON),
  };
end

function MakeDiplomaticActionIcon(item)
  return { name = "ICON_" .. item.DiplomaticActionType, tooltip = item.Name or item.Description };
end

function MakeNotificationIcon(item, tooltip)
  return { name = "ICON_" .. item.NotificationType, tooltip = tooltip or item.Message};
end


function GetInternationalActionIcons() 
  return {
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_MAKE_TRADE_ROUTE),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPREAD_RELIGION),
    {
      name="ICON_NOTIFICATION_DISCOVER_GOODY_HUT",
      tooltip="LOC_IMPROVEMENT_GOODY_HUT_NAME",
    },
    MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_ALLIANCE),
    MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_DECLARE_FRIENDSHIP),
    { 
      name="ICON_NOTIFICATION_DIPLO_DENUNCIATION_EXPIRED",
      tooltip="LOC_DIPLOACTION_DENOUNCE_NAME"
    },
    --MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_GIFT_UNIT),
    {
      name="ICON_NOTIFICATION_DIPLOMACY_SESSION",
      tooltip="LOC_DIPLOACTION_DIPLOMATIC_DELEGATION_NAME"
    },
    MakeNotificationIcon(GameInfo.Notifications.NOTIFICATION_GIVE_INFLUENCE_TOKEN),
    MakeNotificationIcon(GameInfo.Notifications.NOTIFICATION_DECLARE_WAR, "LOC_DECLARE_WAR_BUTTON"),
    --MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_JOINT_WAR),
    MakeNotificationIcon(GameInfo.Notifications.NOTIFICATION_MAKE_PEACE, "LOC_MAKE_PEACE_BUTTON"),
    --MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_MILITARY_REQUEST),
    --{
    --  name="ICON_NOTIFICATION_BORDERS_NOW_ENFORCED",
    --  tooltip="LOC_DIPLOACTION_OPEN_BORDERS"
    --},
    MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_OPEN_BORDERS),
    --MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_REQUEST_ASSISTANCE),
    --MakeDiplomaticActionIcon(GameInfo.DiplomaticActions.DIPLOACTION_THIRD_PARTY_WAR),
    MakeNotificationIcon(GameInfo.Notifications.NOTIFICATION_DISCOVER_RESOURCE, "LOC_RESOURCE_NAME"),
    --MakeUnitOperationIcon(GameInfo.UnitCommands.UNITCOMMAND_GIFT),
  };
end

function GetSpyActionIcons() 
  local icons = {
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_TRAVEL_NEW_CITY),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_DISRUPT_ROCKETRY),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_GAIN_SOURCES),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_GREAT_WORK_HEIST),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_LISTENING_POST),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_RECRUIT_PARTISANS),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_SABOTAGE_PRODUCTION),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_SIPHON_FUNDS),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_STEAL_TECH_BOOST),
  };
  -- New operations in Rise and Fall.
  if (GameInfo.UnitOperations.UNITOPERATION_SPY_FABRICATE_SCANDAL) then 
    table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_FABRICATE_SCANDAL));
  end
  if (GameInfo.UnitOperations.UNITOPERATION_SPY_FOMENT_UNREST) then 
    table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_FOMENT_UNREST));
  end
  if (GameInfo.UnitOperations.UNITOPERATION_SPY_NEUTRALIZE_GOVERNOR) then 
    table.insert(icons, MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_SPY_NEUTRALIZE_GOVERNOR));
  end
  return icons;
end 

function GetMilitaryActionIcons() 
  return {
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_FORTIFY),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_HEAL),
    MakeUnitOperationIcon(GameInfo.UnitCommands.UNITCOMMAND_AIRLIFT),
  	MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_PILLAGE),
    MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_AIR_ATTACK),
	  MakeUnitOperationIcon(GameInfo.UnitOperations.UNITOPERATION_WMD_STRIKE),
	  MakeUnitOperationIcon(GameInfo.UnitCommands.UNITCOMMAND_PLUNDER_TRADE_ROUTE),
    MakeUnitOperationIcon(GameInfo.UnitCommands.UNITCOMMAND_FORM_CORPS),
	  MakeUnitOperationIcon(GameInfo.UnitCommands.UNITCOMMAND_FORM_ARMY),
    {
		  name="ICON_UNITCOMMAND_DELETE",
		  tooltip="LOC_DELETE_BUTTON",
	  },
    {
		  name="ICON_NOTIFICATION_BARBARIANS_SIGHTED",
		  tooltip="LOC_IMPROVEMENT_BARBARIAN_CAMP_NAME",
	  },
    MakeNotificationIcon(GameInfo.Notifications.NOTIFICATION_CONSIDER_RAZE_CITY, "LOC_RAZE_CITY_RAZE_BUTTON_LABEL"),
  };
end

function GetGreatPeopleIcons() 
  local icons = {};
	for item in GameInfo.GreatPersonClasses() do
		table.insert(icons, { name = item.ActionIcon, tooltip = item.Name });
	end
  return icons;
end

function GetGovernorIcons() 
  local icons = {};
  for item in GameInfo.Governors() do
    -- There are three icons for each governor.  
    -- <no suffix> has a dark grey background
    -- "_FILL" has a white background
    -- "_SLOT" has a transparent background (would be best to use this, but it is also darkened to a 
    -- point where it's very hard to see the actual governor).
    table.insert(icons, { name = "ICON_" .. item.GovernorType .. "_FILL", tooltip = item.Description });
  end
  return icons;
end

function GetYieldIcons()
  return {
    { name = "ICON_YIELD_FOOD_5", description = "LOC_YIELD_FOOD_NAME" },
    { name = "ICON_YIELD_PRODUCTION_5", description = "LOC_YIELD_PRODUCTION_NAME" },
    { name = "ICON_YIELD_GOLD_5", description = "LOC_YIELD_GOLD_NAME" },
    { name = "ICON_YIELD_SCIENCE_5", description = "LOC_YIELD_SCIENCE_NAME" },
    { name = "ICON_YIELD_CULTURE_5", description = "LOC_YIELD_CULTURE_NAME" },
    { name = "ICON_YIELD_FAITH_5", description = "LOC_YIELD_FAITH_NAME" },
  };
end

local uniqueUnitsSettingValues = {"LOC_MAP_TACKS_UNIQUE_UNITS_OPTION_SELF_ONLY",
                                  "LOC_MAP_TACKS_UNIQUE_UNITS_OPTION_MET_CIVS_IN_GAME",
                                  "LOC_MAP_TACKS_UNIQUE_UNITS_OPTION_ALL_CIVS_IN_GAME",
                                  "LOC_MAP_TACKS_UNIQUE_UNITS_OPTION_ALL"};
local uniqueUnitsSetting = ModSettings.Select:new(uniqueUnitsSettingValues, 1,
  "LOC_MAP_TACKS_MOD_SETTINGS_CATEGORY",
  "LOC_MOD_TACKS_UNIQUE_UNITS_SETTING", "LOC_MOD_TACKS_UNIQUE_UNITS_SETTING_TOOLTIP");
uniqueUnitsSetting:AddChangedHandler(
  function()
    LuaEvents.MapTacks_UpdateAvailableIcons();
  end);

function GetUnitTraitsFunc()
  if uniqueUnitsSetting.Value == uniqueUnitsSettingValues[4] then
    -- All
    return function() return true end;
  else 
    local traits = GetLocalPlayerTraits();
    local players = PlayerManager.GetWasEverAlive(); 
    local localPlayerID = Game.GetLocalPlayer();

    if localPlayerId ~= -1 then
      local diplomacy = Players[localPlayerID]:GetDiplomacy();
      for _, player in ipairs(players) do
        if not player:IsBarbarian() then
          local hasMet = diplomacy:HasMet(player:GetID());
          local playerCfg = PlayerConfigurations[player:GetID()];
          local leader = GameInfo.Leaders[playerCfg:GetLeaderTypeID()];
          local civ = leader.CivilizationCollection[1];
          if (hasMet and uniqueUnitsSetting.Value == uniqueUnitsSettingValues[2]) or
              (uniqueUnitsSetting.Value == uniqueUnitsSettingValues[3]) then
            AddTraits(traits, leader.TraitCollection);
            AddTraits(traits, civ.TraitCollection);
          end
        end
      end
    end

    return function(trait) return traits[trait] end;
  end
end

function GetUnitIcons()
  local icons = {};
  local traitFunc = GetUnitTraitsFunc();

  for item in GameInfo.Units() do
    -- Skip great people since they're in their own container.
    if item.CanTrain then
      local trait = item.TraitType;
      if not trait or traitFunc(trait) then
        table.insert(icons, { name = "ICON_"..item.UnitType, tooltip = item.Name });
      end
    end
  end

  return icons;
end

function GetWonderIcons() 
  local icons = {};

  for item in GameInfo.Buildings() do
    if item.IsWonder then
      table.insert(icons, { name = "ICON_" .. item.BuildingType, tooltip = item.BuildingType });
    end
  end
  return icons;
end

-- ===========================================================================
-- Given an icon name, determine its color and size profile
MAPTACKS_STOCK = 0;  -- stock icons
MAPTACKS_WHITE = 1;  -- white icons (units, spy ops)
MAPTACKS_GRAY = 2;   -- gray shaded icons (improvements, commands)
MAPTACKS_COLOR = 3;  -- full color icons (districts, wonders)
function MapTacksType(pin : table)
	if not pin then return nil; end
	local iconName = pin:GetIconName();
	if iconName:sub(1,5) ~= "ICON_" then return nil; end
	local iconType = iconName:sub(6, 10);
	if iconType == "MAP_P" then
		return MAPTACKS_STOCK;
	elseif iconType == "UNIT_" then
		return MAPTACKS_WHITE;
  elseif iconType == "UNITO" then
		if iconName:sub(20,22) == "SPY" and iconName:sub(24,29) ~= "TRAVEL" then
      return MAPTACKS_WHITE;
    else 
      return MAPTACKS_GRAY;
    end
	elseif iconType == "DISTR" then
		return MAPTACKS_COLOR;
	elseif iconType == "BUILD" then  -- wonders
		return MAPTACKS_COLOR;
  elseif iconType == "GOVER" then -- governors
    return MAPTACKS_COLOR;
	elseif iconType == "YIELD" then 
    return MAPTACKS_COLOR;
  else
		return MAPTACKS_GRAY;
	end
end

-- ===========================================================================
-- Get player colors (with debug override)
function MapTacksColors(playerID : number)
	local primaryColor, secondaryColor = UI.GetPlayerColors(playerID);
	if g_debugLeader then
		local colors = GameInfo.PlayerColors[g_debugLeader.Hash];
		primaryColor = UI.GetColorValue(colors.PrimaryColor);
		secondaryColor = UI.GetColorValue(colors.SecondaryColor);
	end
	return primaryColor, secondaryColor;
end

-- ===========================================================================
-- Calculate icon tint color
-- Icons generally have light=224, shadow=112 (out of 255).
-- So, to match icons to civ colors, ideally brighten the original color:
-- by 255/224 to match light areas, or by 255/112 to match shadows.
--
-- In practice:
-- Light colors look best as bright as possible without distortion.
-- The darkest colors need shadow=56, light=112, max=128 for legibility.
-- Other colors look good around 1.5-1.8x brightness, matching midtones.
local g_tintCache = {};
function MapTacksIconTint( abgr : number, debug : number )
	if g_tintCache[abgr] ~= nil then return g_tintCache[abgr]; end
	local r = abgr % 256;
	local g = math.floor(abgr / 256) % 256;
	local b = math.floor(abgr / 65536) % 256;
	local max = math.max(r, g, b, 1);  -- avoid division by zero
	local light = 255/max;  -- maximum brightness without distortion
	local dark = 128/max;  -- minimum brightness
	local x = 1.6;  -- match midtones
	if light < x then x = light; elseif x < dark then x = dark; end

	-- sRGB luma
	-- local v = 0.2126 * r + 0.7152 * g + 0.0722 * b;
	-- print(string.format("m%d r%d g%d b%d", max, r, g, b));
	-- print(string.format("%0.3f %0.3f", x, 255/max));
	r = math.min(255, math.floor(x * r + 0.5));
	g = math.min(255, math.floor(x * g + 0.5));
	b = math.min(255, math.floor(x * b + 0.5));
	local tint = ((-256 + b) * 256 + g) * 256 + r;
	g_tintCache[abgr] = tint;
	-- print(string.format("saved %d = tint %d", abgr, tint));
	return tint;
end

-- ===========================================================================
-- Simpler version of DarkenLightenColor
function MapTacksTint( abgr : number, tint : number )
	local r = abgr % 256;
	local g = math.floor(abgr / 256) % 256;
	local b = math.floor(abgr / 65536) % 256;
	r = math.min(math.max(0, r + tint), 255);
	g = math.min(math.max(0, g + tint), 255);
	b = math.min(math.max(0, b + tint), 255);
	return ((-256 + b) * 256 + g) * 256 + r;
end

-- ===========================================================================
-- XXX: Create a test pattern of icons on the map
function MapTacksTestPattern()
	print("MapTacksTestPattern: start");
	local iW, iH = Map.GetGridSize();
	items = MapTacksIconOptions();
	for i, item in ipairs(items) do
		local x = ((i-1) % 15 - 7) % iW;
		local y = 4 - math.floor((i-1) / 15);
		MapTacksTestPin(x, y, item);
	end
	Network.BroadcastPlayerInfo();
	UI.PlaySound("Map_Pin_Add");
	print("MapTacksTestPattern: end");
end

function MapTacksTestPin(x, y, item)
	local name = item and item.name;
	print(string.format("%d %d %s", x, y, tostring(name)));
	local activePlayerID = Game.GetLocalPlayer();
	local pPlayerCfg = PlayerConfigurations[activePlayerID];
	local pMapPin = pPlayerCfg:GetMapPin(x, y);
	pMapPin:SetName("");
	pMapPin:SetIconName(name);
	pMapPin:SetVisibility(ChatTargetTypes.CHATTARGET_ALL);
	pPlayerCfg:GetMapPins();
end

-- ===========================================================================
-- Reference info

-- ===========================================================================
-- Civilization color values
--         maxrgb luma
-- RUSSIA      20   20
-- GERMANY     63   61
-- NUBIA      108   74
-- ARABIA     118   99
-- PERSIA     164   69
-- JAPAN      166   64
-- AZTEC      181   98
-- SCYTHIA    184   67
-- KONGO      207   74
-- INDIA      239  216
-- SPARTA     239  232
-- SPAIN      241  214
-- BRAZIL     245  221
-- SUMERIA    246  171
-- NORWAY     254  104
-- ROME       255  212
-- MACEDON    255  238
-- EGYPT      255  244
-- FRANCE     255  248
-- POLAND     255  251
-- AMERICA    255  255
-- AUSTRALIA  255  255
-- CHINA      255  255
-- ENGLAND    255  255
-- GREECE     255  255

-- ===========================================================================
-- Unit commands
-- INPLACE:
--   UNITCOMMAND_WAKE
--   UNITCOMMAND_CANCEL
--   UNITCOMMAND_STOP_AUTOMATION
--   UNITCOMMAND_GIFT
-- MOVE:
--   UNITCOMMAND_AIRLIFT
-- SECONDARY:
--   UNITCOMMAND_DELETE
-- SPECIFIC:
--   UNITCOMMAND_PROMOTE
--   UNITCOMMAND_UPGRADE
--   UNITCOMMAND_AUTOMATE  -- not VisibleInUI
--   UNITCOMMAND_ENTER_FORMATION
--   UNITCOMMAND_EXIT_FORMATION
--   UNITCOMMAND_ACTIVATE_GREAT_PERSON
--   UNITCOMMAND_DISTRICT_PRODUCTION
--   UNITCOMMAND_FORM_CORPS
--   UNITCOMMAND_FORM_ARMY
--   UNITCOMMAND_PLUNDER_TRADE_ROUTE
--   UNITCOMMAND_NAME_UNIT
--   UNITCOMMAND_WONDER_PRODUCTION
--   UNITCOMMAND_HARVEST_WONDER

-- ===========================================================================
-- Unit operations
-- ATTACK:
--   UNITOPERATION_AIR_ATTACK
--   UNITOPERATION_WMD_STRIKE
--   UNITOPERATION_COASTAL_RAID
--   UNITOPERATION_PILLAGE
--   UNITOPERATION_PILLAGE_ROUTE
--   UNITOPERATION_RANGE_ATTACK
-- BUILD:
--   UNITOPERATION_BUILD_IMPROVEMENT
--   UNITOPERATION_BUILD_ROUTE
--   UNITOPERATION_DESIGNATE_PARK
--   UNITOPERATION_PLANT_FOREST
--   UNITOPERATION_REMOVE_FEATURE
--   UNITOPERATION_REMOVE_IMPROVEMENT
-- INPLACE:
--   UNITOPERATION_FORTIFY
--   UNITOPERATION_HEAL
--   UNITOPERATION_REST_REPAIR
--   UNITOPERATION_SKIP_TURN
--   UNITOPERATION_SLEEP
--   UNITOPERATION_ALERT
-- MOVE:
--   UNITOPERATION_DEPLOY
--   UNITOPERATION_DISEMBARK  -- not VisibleInUI
--   UNITOPERATION_EMBARK  -- not VisibleInUI
--   UNITOPERATION_MOVE_TO
--   UNITOPERATION_MOVE_TO_UNIT  -- not VisibleInUI
--   UNITOPERATION_REBASE
--   UNITOPERATION_ROUTE_TO  -- not VisibleInUI
--   UNITOPERATION_SPY_COUNTERSPY  -- special handling in unit panel
--   UNITOPERATION_SPY_TRAVEL_NEW_CITY
--   UNITOPERATION_TELEPORT_TO_CITY
-- OFFENSIVESPY:  -- these do not appear in unit panel
--   UNITOPERATION_SPY_DISRUPT_ROCKETRY
--   UNITOPERATION_SPY_GAIN_SOURCES
--   UNITOPERATION_SPY_GREAT_WORK_HEIST
--   UNITOPERATION_SPY_LISTENING_POST
--   UNITOPERATION_SPY_RECRUIT_PARTISANS
--   UNITOPERATION_SPY_SABOTAGE_PRODUCTION
--   UNITOPERATION_SPY_SIPHON_FUNDS
--   UNITOPERATION_SPY_STEAL_TECH_BOOST
-- SECONDARY:
--   UNITOPERATION_AUTOMATE_EXPLORE
-- SPECIFIC:
--   UNITOPERATION_CLEAR_CONTAMINATION
--   UNITOPERATION_CONVERT_BARBARIANS
--   UNITOPERATION_EVANGELIZE_BELIEF
--   UNITOPERATION_EXCAVATE
--   UNITOPERATION_FOUND_CITY
--   UNITOPERATION_FOUND_RELIGION
--   UNITOPERATION_HARVEST_RESOURCE
--   UNITOPERATION_LAUNCH_INQUISITION
--   UNITOPERATION_MAKE_TRADE_ROUTE
--   UNITOPERATION_REMOVE_HERESY
--   UNITOPERATION_REPAIR
--   UNITOPERATION_REPAIR_ROUTE
--   UNITOPERATION_RETRAIN
--   UNITOPERATION_SPREAD_RELIGION
--   UNITOPERATION_SWAP_UNITS  -- not VisibleInUI
--   UNITOPERATION_UPGRADE
--   UNITOPERATION_WAIT_FOR  -- not VisibleInUI

-- vim: sw=4 ts=4
