------------------------------------------------------------------
-- MapTacks
-- utility functions

------------------------------------------------------------------
-- Calculate icon tint color
-- Icons generally have light=224, shadow=112 (out of 255).
-- So, to match icons to civ colors, ideally brighten the original color:
-- by 255/224 to match light areas, or by 255/112 to match shadows.
--
-- In practice:
-- Light colors look best as bright as possible without distortion.
-- The darkest colors need shadow=64, light=128, max=144 for legibility.
-- Other colors look good around 1.5-1.8x brightness, matching midtones.
local g_tintCache = {};
function IconTint( abgr : number, midtone : number )
	if g_tintCache[abgr] ~= nil then return g_tintCache[abgr]; end
	local r = abgr % 256;
	local g = math.floor(abgr / 256) % 256;
	local b = math.floor(abgr / 65536) % 256;
	local max = math.max(r, g, b, 1);  -- avoid division by zero
	local light = 255/max;  -- maximum brightness without distortion
	local dark = 144/max;  -- minimum brightness
	local x = midtone or 1.6;  -- match midtones
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

------------------------------------------------------------------
-- XXX debug

local g_civInfo :table = nil;
function CivInfo( civ : string )
	if g_civInfo == nil then
		g_civInfo = {};
		for item in GameInfo.PlayerColors() do
			local leader = item.Type:match("LEADER_(.+)");
			if leader then
				local civ = item.PrimaryColor:match("^COLOR_PLAYER_(.*)_[^_]+");
				-- print(item.Type, civ, item.PrimaryColor, item.SecondaryColor);
				g_civInfo[civ] = {
					leader = leader,
					primary = UI.GetColorValue(item.PrimaryColor),
					secondary = UI.GetColorValue(item.SecondaryColor)
				}
			end
		end
	end
	return g_civInfo[civ];
end

function CivColors( civ : string, primaryColor, secondaryColor )
	local info = CivInfo(civ);
	if info then
		primaryColor = info.primary;
		secondaryColor = info.secondary;
	end
	return primaryColor, secondaryColor;
end

-- ===========================================================================
-- XXX debug

local g_icons = {};
local g_standardIcons =
{
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

function MapTacksTestPattern()
	print("MapTacksTestPattern: start");
	local activePlayerID = Game.GetLocalPlayer();
	local pPlayerCfg = PlayerConfigurations[activePlayerID];
	local pMapPin = pPlayerCfg:GetMapPin(hexX, hexY);
	for i, item in ipairs(MapTacksIconOptions()) do
		local row = math.floor((i-1) / 14);
		local col = (i-1) % 14;
		print(row, col, item.name);
		local pMapPin = pPlayerCfg:GetMapPin(col, 4-row);
		pMapPin:SetName(nil);
		pMapPin:SetIconName(item.name);
	end
	Network.BroadcastPlayerInfo();
	UI.PlaySound("Map_Pin_Add");
end

local g_buildOps = {
	GameInfo.UnitOperations.UNITOPERATION_PLANT_FOREST,
	GameInfo.UnitOperations.UNITOPERATION_REMOVE_FEATURE,
	GameInfo.UnitOperations.UNITOPERATION_HARVEST_RESOURCE,
};
local g_repairOps = {
	GameInfo.UnitOperations.UNITOPERATION_CLEAR_CONTAMINATION,
	GameInfo.UnitOperations.UNITOPERATION_REPAIR,
};
local g_miscOps = {
	GameInfo.UnitOperations.UNITOPERATION_BUILD_ROUTE,
	GameInfo.UnitOperations.UNITOPERATION_DESIGNATE_PARK,
	GameInfo.UnitOperations.UNITOPERATION_EXCAVATE,
	GameInfo.UnitOperations.UNITOPERATION_MAKE_TRADE_ROUTE,
	GameInfo.Units.UNIT_SPY,
	GameInfo.UnitCommands.UNITCOMMAND_ACTIVATE_GREAT_PERSON,
};
local g_attackOps = {
	GameInfo.UnitCommands.UNITCOMMAND_FORM_ARMY,
	GameInfo.UnitCommands.UNITCOMMAND_PLUNDER_TRADE_ROUTE,
--	GameInfo.UnitOperations.UNITOPERATION_AIR_ATTACK,
	GameInfo.UnitOperations.UNITOPERATION_PILLAGE,
	GameInfo.UnitOperations.UNITOPERATION_WMD_STRIKE,
};

function MapTacksIconOptions(standardIcons : table)
	local icons = {};
	local activePlayerID = Game.GetLocalPlayer();
	g_uniqueIconsPlayer = activePlayerID;
	local pPlayerCfg = PlayerConfigurations[activePlayerID];
	local civ = GameInfo.Civilizations[pPlayerCfg:GetCivilizationTypeID()];
	-- civ = GameInfo.Civilizations.CIVILIZATION_GREECE;
	-- civ = GameInfo.Civilizations.CIVILIZATION_ROME;
	-- civ = GameInfo.Civilizations.CIVILIZATION_GERMANY;
	-- civ = GameInfo.Civilizations.CIVILIZATION_RUSSIA;
	-- civ = GameInfo.Civilizations.CIVILIZATION_KONGO;
	-- civ = GameInfo.Civilizations.CIVILIZATION_BRAZIL;
	-- civ = GameInfo.Civilizations.CIVILIZATION_ENGLAND;
	-- civ = GameInfo.Civilizations.CIVILIZATION_CHINA;
	-- print(civ.CivilizationType);

	-- Get unique traits for the player civilization
	local traits = {};
	for i, item in ipairs(civ.TraitCollection) do
		traits[item.TraitType] = true;
		-- print(item.TraitType);
	end
	-- Get unique district replacement info
	local districts = {};
	for item in GameInfo.Districts() do
		if traits[item.TraitType] then
			for i, swap in ipairs(item.ReplacesCollection) do
				local base = swap.ReplacesDistrictType;
				districts[base] = item;
				-- print(item.DistrictType, "replaces", base);
			end
		end
	end

	-- Standard map pins
	for i, item in ipairs(standardIcons or g_standardIcons) do
		table.insert(icons, item);
	end

	-- Districts
	for item in GameInfo.Districts() do
		local itype = item.DistrictType;
		if districts[itype] then
			-- unique district replacements for this civ
			table.insert(icons, MapTacksIcon(districts[itype], "DistrictType"));
		elseif item.TraitType then
			-- skip other unique districts
		else
			table.insert(icons, MapTacksIcon(item, "DistrictType"));
		end
	end

	-- Improvements
	local builderIcons = {};
	local uniqueIcons = {};
	local minorCivIcons = {};
	local miscIcons = {};
	for item in GameInfo.Improvements() do
		-- does this improvement have a valid build unit?
		local valid = item.ValidBuildUnits[1];
		if valid then
			local entry = MapTacksIcon(item, "ImprovementType");
			local unit = GameInfo.Units[valid.UnitType];
			local trait = item.TraitType or unit.TraitType;
			-- print(valid.UnitType, trait);
			if trait then
				-- print(trait);
				if traits[trait] then
					-- separate unique improvements
					table.insert(uniqueIcons, entry);
				elseif trait:sub(1, 10) == "MINOR_CIV_" then
					table.insert(minorCivIcons, entry);
				end
			elseif unit.UnitType == "UNIT_BUILDER" then
				table.insert(builderIcons, entry);
			else
				table.insert(miscIcons, entry);
			end
		end
	end

	for i,v in ipairs(builderIcons) do table.insert(icons, v); end
	for i,v in ipairs(g_buildOps) do table.insert(icons, MapTacksIcon(v)); end
	if #uniqueIcons==0 then
		table.insert(icons, MapTacksIcon(
			GameInfo.UnitOperations.UNITOPERATION_BUILD_IMPROVEMENT))
	end
	for i,v in ipairs(uniqueIcons) do table.insert(icons, v); end
	for i,v in ipairs(minorCivIcons) do table.insert(icons, v); end
	for i,v in ipairs(g_repairOps) do table.insert(icons, MapTacksIcon(v)); end
	for i,v in ipairs(miscIcons) do table.insert(icons, v); end
	for i,v in ipairs(g_miscOps) do table.insert(icons, MapTacksIcon(v)); end

	-- Great people
	for item in GameInfo.GreatPersonClasses() do
		table.insert(icons, MapTacksIcon(item));
	end

	-- Unit actions
	for i,v in ipairs(g_attackOps) do table.insert(icons, MapTacksIcon(v)); end

	return icons;
end

function MapTacksIcon(item)
	local name :string = nil;
	local tooltip :string = nil;
	if item.GreatPersonClassType then
		name = item.ActionIcon;
		tooltip = item.Name;
	elseif item.DistrictType then
		name = "ICON_"..item.DistrictType;
		tooltip = item.DistrictType;
		if tooltip=="DISTRICT_WONDER" then
			tooltip = "LOC_CIVICS_KEY_WONDER";
		end
	elseif item.ImprovementType then
		name = item.Icon;
		tooltip = item.ImprovementType;
	elseif item.UnitType == "UNIT_SPY" then
		name="ICON_UNITOPERATION_SPY_COUNTERSPY_ACTION";
		tooltip=item.Name;
	else
		name = item.Icon;
		tooltip = item.Description;
	end
	return { name=name, tooltip=tooltip };
end

function MapTacksType(pin : table)
	if not pin then return nil; end
	local iconName = pin:GetIconName();
	if iconName:sub(1,5) ~= "ICON_" then return nil; end
	-- M = map pin
	-- D = district
	-- I = improvement
	-- U = unit action
	-- A = unit action
	local iconType = iconName:sub(6, 6);
	-- print(iconName, iconType);
	return iconType;
end

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
