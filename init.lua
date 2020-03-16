
local mod = {
	mod_loader_version = "2.3.0",
	id = "lmn_disposal_mechs",
	name = "Disposal Mechs",
	version = "1.0.4",
	requirements = {"kf_ModUtils"},
}

local oldOrderMods = mod_loader.orderMods
function mod_loader.orderMods(self, options, savedOrder)
	local ret = oldOrderMods(self, options, savedOrder)
	
	local mod = mod_loader.mods[mod.id]
	mod.icon = mod.resourcePath .."img/icons/mod_icon.png"
	
	return ret
end

local FURL_object = {
	{	Type = "color",
		Name = "lmn_disposal",
		
		PlateHighlight =	{ 46, 229, 229},	--lights
		
		PlateLight =		{172, 140, 108},	--main highlight
		PlateMid =			{105,  68,  72},	--main light
		PlateDark =			{ 67,  45,  50},	--main mid
		PlateOutline =		{ 23,  17,  19},	--main dark
		BodyHighlight =		{169, 183, 147},	--metal light
		BodyColor =			{ 82,  88,  70},	--metal mid
		PlateShadow =		{ 36,  37,  29},	--metal dark 
	},
	{
		Type = "mech",
		Name = "lmn_MechDozer",
		Filename = "lmn_mech_dozer",
		Path = "img/units/player",
		ResourcePath = "units/player",
		
		Default =           { PosX = -19, PosY = 2 },
		Animated =          { PosX = -19, PosY = 2, NumFrames = 3 },
		Broken =            { PosX = -19, PosY = 2 },
		Submerged =  	    { PosX = -20, PosY = 11 },
		SubmergedBroken =   { PosX = -20, PosY = 11 },
		Icon =              {},
	},
	{
		Type = "mech",
		Name = "lmn_MechChem",
		Filename = "lmn_mech_chem",
		Path = "img/units/player",
		ResourcePath = "units/player",
		
		Default =           { PosX = -19, PosY = 0 },
		Animated =          { PosX = -19, PosY = 0, NumFrames = 4 },
		Broken =            { PosX = -19, PosY = 0 },
		Submerged =  	    { PosX = -19, PosY = 8 },
		SubmergedBroken =   { PosX = -19, PosY = 8 },
		Icon =              {},
	},
	{
		Type = "mech",
		Name = "lmn_MechStacker",
		Filename = "lmn_mech_stacker",
		Path = "img/units/player",
		ResourcePath = "units/player",
		
		Default =           { PosX = -17, PosY = 2 },
		Animated =          { PosX = -17, PosY = 2, NumFrames = 4 },
		Broken =            { PosX = -17, PosY = 2 },
		Submerged =  	    { PosX = -17, PosY = 10 },
		SubmergedBroken =   { PosX = -17, PosY = 10 },
		Icon =              {},
	},
}
	
function mod:init()
	
	if not modApi:isVersion(self.mod_loader_version) then
		error(string.format(
			"Unable to load %s, because the mod loader is out of date (need at least version %s)",
			self.name, self.mod_loader_version
		))
	end
	
	self.modApiExt = require(self.scriptPath .."modApiExt/modApiExt")
	self.modApiExt:init()
	
	modApi:addGenerationOption("option_dozer", "Dozer Test Changes", "Alternate Dozer attacks being tested.", {values = {1,2,3}, value = 0, strings = {"Original", "Gradual Upgrades", "Redesign"}})
	
	require(self.scriptPath.."FURL")(self, FURL_object)
	
	self.mech_chemical = require(self.scriptPath .."mech_chemical")
	self.mech_dozer = require(self.scriptPath .."mech_dozer")
	self.mech_stacker = require(self.scriptPath .."mech_stacker")
	
	self.mech_chemical:init(self)
	self.mech_dozer:init(self)
	self.mech_stacker:init(self)
end

function mod:load(options, version)
	self.modApiExt:load(self, options, version)
	
	self.mech_chemical:load(self.modApiExt)
	self.mech_dozer:load(options, self.modApiExt)
	self.mech_stacker:load(self.modApiExt)
	
	modApi:addSquadTrue(
		{
			"Disposal Mechs",
			"lmn_StackerMech", "lmn_DozerMech", "lmn_ChemMech"
		},
		"Disposal Mechs",
		"Originally made by Detritus as waste disposal mechs. Now repurposed to fight the Vek.",
		self.resourcePath .. "img/icons/squad_icon.png"
	)
end

return mod