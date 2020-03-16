
local this = {
	corp = "Archive",
	amphibious = {},
	move = {},
}

--------------------------------------------- Helper functions --------------------------------------------------

-- returns whether a tile is water, acid or lava.
-- GetTerrain() returns TERRAIN_WATER for all.
local function IsSubmerged(point)
	return Board:GetTerrain(point) == TERRAIN_WATER
end

local function IsAcidBath(point)
	return IsSubmerged(point) and Board:IsAcid(point)
end

local function IsLava(point)
	return Board:IsTerrain(point, TERRAIN_LAVA)
end

local function IsAmphibious(pawn)
	local v = _G[pawn:GetType()]
	return	v.lmn_dissolver_amphibious	and
			v.Flying					and
			not pawn:IsAbility("Flying")
end

local function GetFriendlyMassivePath(pawn)
	if pawn:IsAbility("Road_Runner") then return 20 end
	return 18
end

-- returns true if we are in a (non Test Mech) mission
local function IsMission()
    return Game ~= nil and GetCurrentMission() ~= nil
end

-- returns true if we are in Region overview
local function IsRegion()
    return Game ~= nil and GetCurrentMission() == nil
end

-- returns true if all mechs are deployed
local function IsAllMechsDeployed()
	assert(Board ~= nil)
	
	local offBoard = Point(-1, -1)
	return not GAME.lmn_dissolver_amphibious_deployment
		or (Board:GetPawn(0):GetSpace() ~= offBoard		and
			Board:GetPawn(1):GetSpace() ~= offBoard		and
			Board:GetPawn(2):GetSpace() ~= offBoard)
end

-- overlay colors to fade out green highlighted movement tiles.
local colors = {
	Detritus	= GL_Color(90, 65, 81),		-- detritus default
	Archive		= GL_Color(66, 56, 57),		-- archive default
	["R.S.T."]	= GL_Color(192, 129, 90),	-- R.S.T. default
	Pinnacle	= GL_Color(240, 230, 255),	-- Pinnacle default
	Final		= GL_Color(72, 52, 62),		-- Final mission default
	
	water		= GL_Color(117, 139, 164),
	acid		= GL_Color(63, 165, 73),
	lava		= GL_Color(253, 184, 55),
	hole		= GL_Color(10, 0, 10),
	dune		= GL_Color(226, 131, 70),
	ice			= GL_Color(200, 213, 255),
}

------------------------------------------------- Tooltip -------------------------------------------------------

local original_GetStatusTooltip = GetStatusTooltip
function GetStatusTooltip(id)
	if	id == "flying"		and
		IsAmphibious(Pawn)	then
		
		return {"Amphibious", "Amphibious units operates normally when submerged."}
	end
	return original_GetStatusTooltip(id)
end

------------------------------------------------- Move ----------------------------------------------------------

local oldGetTargetArea = Move.GetTargetArea
function Move:GetTargetArea(point)
	assert(type(this.amphibious) == 'table')
	
	if IsAmphibious(Pawn) then
		local ret = Board:GetReachable(point, Pawn:GetMoveSpeed(), GetFriendlyMassivePath(Pawn))
		this.move.tiles = extract_table(ret)
		this.move.id = Pawn:GetId()
		this.move.active = true
		return ret
	end
	
	return oldGetTargetArea(self, point)
end

local oldGetSkillEffect = Move.GetSkillEffect
function Move:GetSkillEffect(p1, p2)
	assert(type(this.amphibious) == 'table')
	
	if IsAmphibious(Pawn) then
		local ret = SkillEffect()
		this.amphibious[Pawn:GetId()].isSubmerged = IsSubmerged(p2)
		ret:AddScript("lmn_dissolver_amphibious_move_in_progress = true")
		ret:AddMove(Board:GetPath(p1, p2, GetFriendlyMassivePath(Pawn)), FULL_DELAY)
		ret:AddScript("lmn_dissolver_amphibious_move_in_progress = false")
		return ret
	end
	
	return oldGetSkillEffect(self, p1, p2)
end

----------------------------------------------- Mission ---------------------------------------------------------

local oldMissionStartDeployment = Mission.StartDeployment
function Mission.StartDeployment(...)
	GAME.lmn_dissolver_amphibious_deployment = true
	return oldMissionStartDeployment(...)
end

local oldMissionIsEnvironmentEffect = Mission.IsEnvironmentEffect
function Mission.IsEnvironmentEffect(...)
	GAME.lmn_dissolver_amphibious_deployment = nil
	for id, v in pairs(this.amphibious) do
		local pawn = Board:GetPawn(id)
		v.submerged = IsSubmerged(pawn:GetSpace())
	end
	return oldMissionIsEnvironmentEffect(...)
end

local function UpdateFireAcid(id)
	local v = this.amphibious[id]
	local pawn = Board:GetPawn(id)
	v.isAcid = pawn:IsAcid()
	v.isFire = pawn:IsFire() or _G[pawn:GetType()].IgnoreFire
	
	if not pawn:IsBusy() then
		
		if	not v.isAcid		and
			IsAcidBath(v.loc)	then
			
			local acid = SpaceDamage(v.loc)
			acid.iAcid = 1
			Board:DamageSpace(acid)
		end
		
		if	not v.isFire	and
			IsLava(v.loc)	then
			
			local fire = SpaceDamage(v.loc)
			fire.iFire = 1
			Board:DamageSpace(fire)
		end
	end
end

-- this function can be called in the region screen
-- no use of v.loc or any functions that are
-- mission or board dependent in here.
local function UpdateAnimation(id)
	local v = this.amphibious[id]
	
	local pawn = Game:GetPawn(id)
	if pawn then	-- just for peace of mind.
		
		if not IsAmphibious(pawn) then
			return
		end
		
		local suffix = ""
		if	v.isSubmerged			and
			pawn:GetHealth() > 0	then
			
			suffix = "w"
		end
		if v.currAnim ~= v.anim .. suffix then
			v.currAnim = v.anim .. suffix
			pawn:SetCustomAnim(v.anim .. suffix)
		end
	end
end

local function onMissionUpdate()
	if not this.loaded then return end
	assert(type(this.amphibious) == 'table')
	
	for id, v in pairs(this.amphibious) do
		local pawn = Board:GetPawn(id)
		
		if pawn and IsAmphibious(pawn) then
			
			if not GAME.lmn_dissolver_amphibious_deployment then
				if not this.move.active then
					v.isSubmerged = IsSubmerged(v.loc)
					UpdateFireAcid(id)
				end
				
				if lmn_dissolver_amphibious_move_in_progress
				or not pawn:IsBusy() then
					UpdateAnimation(id)
					
				end
			end
			
			-- trim highlighted tiles we cannot reach
			if	not IsTestMechScenario()	and
				Board:GetBusyState() == 0	and
				this.highlighted == v.loc	and
				not this.selected			and
				pawn:IsActive()				and
				not pawn:IsUndoPossible()	and		-- Unreliable. Clicking on a pawn twice incorrectly sets this to true.
				IsAllMechsDeployed()		then
				
				local hiddenTiles = {}
				local flyerTiles = extract_table(Board:GetReachable(v.loc, pawn:GetMoveSpeed(), PATH_FLYER))
				local amphibiousTiles = extract_table(Board:GetReachable(v.loc, pawn:GetMoveSpeed(), GetFriendlyMassivePath(pawn)))
				for _, p in ipairs(flyerTiles) do
					if not list_contains(amphibiousTiles, p) then
						table.insert(hiddenTiles, p)
					end
				end
				
				local corp = Game:GetCorp().bark_name
				if corp ~= "" then
					this.corp = corp
				else
					local region = GetCurrentRegion()
					if region == RegionData["final_region"] then
						this.corp = "Final"
					end
				end
				
				local borders = {}
				
				for _, p in ipairs(hiddenTiles) do
					local color = colors[this.corp] or GL_Color()
					
					if IsLava(p) then
						color = colors.lava
						
					elseif IsAcidBath(p) then
						color = colors.acid
						
					elseif Board:IsTerrain(p, TERRAIN_WATER) then
						color = colors.water
						
					elseif Board:IsTerrain(p, TERRAIN_HOLE) then
						color = colors.hole
						
					elseif Board:IsTerrain(p, TERRAIN_ICE) then
						color = colors.ice
						
					elseif Board:IsTerrain(p, TERRAIN_SAND) then
						color = colors.dune
						
					elseif Board:IsTerrain(p, TERRAIN_FOREST) then
						
					end
					
					color = CCC or color
					
					local suffix = ""
					for i = 0, 3, 3 do
						local curr = p + DIR_VECTORS[i]
						
						if	Board:IsValid(curr)					and
							not list_contains(flyerTiles, curr)	then
							
							suffix = suffix .. i
						end
					end
					
					-- hide green lines of hidden tiles
					for i = 1, 2 do
						local curr = p + DIR_VECTORS[i]
						
						if	Board:IsValid(curr)							and
							not Board:IsTerrain(curr, TERRAIN_MOUNTAIN)	and -- line is already hidden
							not Board:IsPawnSpace(curr)					and	-- avoid danger markers
							not Board:IsEnvironmentDanger(curr)			and	-- avoid overwriting markers
							not list_contains(flyerTiles, curr)			then
							
							borders[p2idx(curr)] = borders[p2idx(curr)] and borders[p2idx(curr)].. i or i
						end
					end
					
					Board:MarkSpaceImage(p, "combat/lmn_amphibious_square".. suffix ..".png", color)
				end
				
				for i, suffix in pairs(borders) do
					local p = idx2p(i)
					Board:MarkSpaceImage(p, "combat/lmn_amphibious_line".. suffix ..".png", GL_Color())
				end
			end
			
		elseif not IsTestMechScenario() then	-- don't erase pawns in Test Mech
			this.rem = this.rem or {}			-- because they won't get tracked
			table.insert(this.rem, id)			-- again if you leave and reenter.
		end
	end
	
	if this.rem then
		for _, id in ipairs(this.rem) do
			this.amphibious[id] = nil
		end
		this.rem = nil
	end
end

local function TrackPawn(pawn)
	this.amphibious[pawn:GetId()] = {
		id = pawn:GetId(),
		loc = pawn:GetSpace(),
		anim = _G[pawn:GetType()].Image,
		isSubmerged = IsSubmerged(pawn:GetSpace()),
	}
end

local function initVars()
	this.loaded = true
	this.amphibious = {}
	this.move = {}
end

-- this should only fire if we have a BaseMissionUpdate
-- since we start it via modApi:RunLater.
-- thus no board test is needed
local function onLoad()
	if loaded then return end
	
	initVars()
	
	local mechs = extract_table(Board:GetPawns(TEAM_MECH))
	for _, id in ipairs(mechs) do
		local pawn = Board:GetPawn(id)
		if IsAmphibious(pawn) then
			TrackPawn(pawn)
		end
	end
	
	onMissionUpdate()	-- in case onMissionUpdate was exited early.
end

local function onStateChanged(_, pawn)
	assert(type(this.amphibious) == 'table')
	
	local v = this.amphibious[pawn:GetId()]
	if not v then return end
	
	this.move.active = nil
	v.loc = pawn:GetSpace()
	v.isSubmerged = IsSubmerged(v.loc)
end

------------------------------------------------ Region ---------------------------------------------------------

sdlext.addGameEnteredHook(function(screen)
	this.inGame = true
	this.loaded = nil
	modApi:runLater(onLoad)	-- to ensure loading for Test Mech
end)

sdlext.addGameExitedHook(function(screen)
	this.inGame = false
	this.selected = nil
	this.highlighted = nil
end)

------------------------------------------------ Setup ----------------------------------------------------------

Location["combat/lmn_amphibious_square.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_square0.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_square3.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_square03.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_line1.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_line2.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_line12.png"] = Point(-28, 1)
Location["combat/lmn_amphibious_line21.png"] = Point(-28, 1)

function this:init(mod)
	modApi:appendAsset("img/combat/lmn_amphibious_square.png", mod.resourcePath .."img/combat/square.png")
	modApi:appendAsset("img/combat/lmn_amphibious_square0.png", mod.resourcePath .."img/combat/square0.png")
	modApi:appendAsset("img/combat/lmn_amphibious_square3.png", mod.resourcePath .."img/combat/square3.png")
	modApi:appendAsset("img/combat/lmn_amphibious_square03.png", mod.resourcePath .."img/combat/square03.png")
	modApi:appendAsset("img/combat/lmn_amphibious_line1.png", mod.resourcePath .."img/combat/line1.png")
	modApi:appendAsset("img/combat/lmn_amphibious_line2.png", mod.resourcePath .."img/combat/line2.png")
	modApi:appendAsset("img/combat/lmn_amphibious_line12.png", mod.resourcePath .."img/combat/line12.png")
	modApi:appendAsset("img/combat/lmn_amphibious_line21.png", mod.resourcePath .."img/combat/line12.png")
	
	self.amphibiousIcon = require(mod.scriptPath .."amphibiousIcon")
	self.amphibiousIcon:init(mod)
end

local function onExitMission()
	if Game then	-- Test Mech -> Main Menu has no Game
		assert(type(this.amphibious) == 'table')
		
		for id, v in pairs(this.amphibious) do
			v.isSubmerged = false
			v.pawn = Game:GetPawn(id)
			UpdateAnimation(id)
		end
	end
end

function this:load(modApiExt)
	self.modApiExt = modApiExt
	self.amphibiousIcon:load(modApiExt)
	
	modApi:addMissionStartHook(initVars)
	modApi:addMissionNextPhaseCreatedHook(initVars)
	modApi:addMissionUpdateHook(onMissionUpdate)
	
	modApiExt:addPawnPositionChangedHook(onStateChanged)
	modApiExt:addPawnDamagedHook(onStateChanged)
	modApiExt:addPawnHealedHook(onStateChanged)
	modApiExt:addPawnDeselectedHook(function(_, pawn) this.selected = nil; onStateChanged(_, pawn) end)
	modApiExt:addPawnSelectedHook(function(_, pawn) this.selected = pawn; end)
	
	modApiExt:addTileHighlightedHook(function(mission, tile)
		this.highlighted = tile
	end)
	
	modApiExt:addTileUnhighlightedHook(function(mission, tile)
		this.highlighted = nil
		if this.move.active then
			
			if IsTestMechScenario()
			or list_contains(this.move.tiles, tile) then
				
				local id = this.move.id
				local v = this.amphibious[id]
				local pawn = Board:GetPawn(id)
				this.amphibious[id].isSubmerged = IsSubmerged(pawn:GetSpace())
			end
		end
	end)
	
	modApiExt:addPawnTrackedHook(function(mission, pawn)
		if IsAmphibious(pawn) then
			TrackPawn(pawn)
		end
	end)
	
	modApiExt:addResetTurnHook(function() this.loaded = nil; modApi:runLater(onLoad) end)		-- submerged animation won't trigger unless we delay by one frame.
	modApiExt:addGameLoadedHook(function() this.loaded = nil; modApi:runLater(onLoad) end)
	modApi:addMissionEndHook(function()
		modApi:scheduleHook(5700, function()
			onExitMission()
		end)
	end)
	modApi:addTestMechExitedHook(onExitMission)
end

return this