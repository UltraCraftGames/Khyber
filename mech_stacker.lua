
local mech = {}

lmn_StackerMech = Pawn:new{
	Name = "Stacker Mech",
	Class = "Prime",
	Health = 3,
	MoveSpeed = 3,
	Image = "lmn_MechStacker",
	ImageOffset = FURL_COLORS.lmn_disposal or 1,
	SkillList = { "lmn_LiftAtk" },
	SoundLocation = "/mech/prime/punch_mech/",
	DefaultTeam = TEAM_PLAYER,
	ImpactMaterial = IMPACT_METAL,
	Massive = true,
}

lmn_LiftAtk = Skill:new{
	Name = "Fork Lift",
	Description = "Bash a unit; or throw it, pushing adjacent tiles.",
	Icon = "weapons/lmn_weapon_stacker.png",
	Class = "Prime",
	Damage = 2,
	Range = INT_MAX,
	AllyImmune = false,
	ImpactDamage = false,
	JudoToss = false,
	Crush = false,
	PushBash = false,
	PushAdjacent = true,
	DamageAdjacent = false,
	PowerCost = 1,
	Upgrades = 2,
	UpgradeCost = { 1 , 3 },
	UpgradeList = { "Impact", "Crush" },
	CustomTipImage = "lmn_LiftAtk_Tip",
	TipImage = {
		Unit = Point(2,3),
		Enemy = Point(2,2),
		Friendly = Point(1,1),
		Target = Point(2,2),
		Second_Origin = Point(2,3),
		Second_Target = Point(2,1),
	}
}

local function HasPsionLeech()
	-- only applicable for TEAM_MECH
	pawns = extract_table(Board:GetPawns(TEAM_MECH))
	for _, id in ipairs(pawns) do
		local pawn = Board:GetPawn(id)
		local pawnType = pawn:GetType()
		if _G[pawnType].SkillList then
			for _, skill in ipairs(_G[pawnType].SkillList) do
				if _G[skill].Passive == "Psion_Leech" then
					return true
				end
			end
		end
	end
	return false
end

local function HasArmorPsion()
	-- even if the player has Leader == LEADER_ARMOR, Vek gains armor.
	-- so look through all pawns, not just TEAM_ENEMY
	pawns = extract_table(Board:GetPawns(TEAM_ANY))
	for _, id in ipairs(pawns) do
		local pawn = Board:GetPawn(id)
		local pawnType = pawn:GetType()
		if _G[pawnType].Leader == LEADER_ARMOR
		or _G[pawnType].Leader == LEADER_BOSS	then
			return true
		end
	end
	return false
end

local function IsBot(pawn)
	return Board:IsPawnTeam(pawn:GetSpace(), TEAM_BOTS)
end

local function IsPsion(pawn)
	return _G[pawn:GetType()].Leader
end

local function IsArmor(pawn)
	return	_G[pawn:GetType()].Armor
	
		or	pawn:IsAbility("Armored")
		
		or	(pawn:IsEnemy()			and
			not IsBot(pawn)			and
			not IsPsion(pawn)		and
			HasArmorPsion())
			
		or	(pawn:IsMech()			and
			HasPsionLeech()			and
			HasArmorPsion())
end
	
-- returns whether thrown pawn can crush target pawn.
function lmn_LiftAtk:CanCrush(thrown, target)
	return	target										and
			self.Crush									and		-- must have upgrade
			thrown:GetHealth() > target:GetHealth()		and		-- thrown pawn must have more hp than target
			not list_contains({0,1,2}, target:GetId())	and		-- filter out mechs because they leave a corpse
			not target.corpse							and		-- filter out other pawns that leave a corpse
			_G[target:GetType()].Corporate == false				-- filter out terraformer, and maybe others?
end

function lmn_LiftAtk:IsAvailableTile(tile)
	return	not Board:IsPawnSpace(tile)					and
			not Board:IsBlocked(tile, PATH_PROJECTILE)
end

local function IsThrowable(pawn)
	return _G[pawn:GetType()].Pushable
end

function lmn_LiftAtk:GetTargetArea(point)
	local ret = PointList()
	
	for dir = DIR_START, DIR_END do
		local curr = point + DIR_VECTORS[dir]
		
		if Board:IsValid(curr) then
			ret:push_back(curr)
			local thrownPawn = Board:GetPawn(curr)
			if	thrownPawn				and
				IsThrowable(thrownPawn)	then
				
				for k = 2, self.Range do
					local curr = point + DIR_VECTORS[dir] * k
					
					if not Board:IsValid(curr) then
						break
					end
					
					local targetPawn = Board:GetPawn(curr)
					
					if	not Board:IsBlocked(curr, PATH_PROJECTILE)
					or	(targetPawn									 and
						self:CanCrush(thrownPawn, targetPawn))		then
						
						ret:push_back(curr)
					end
				end
			end
		end
	end
	
	return ret
end

function lmn_LiftAtk:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local distance = p1:Manhattan(p2)
	local dir = GetDirection(p2 - p1)
	local dir_back = (dir + 2)%4
	local pawnFront = Board:GetPawn(p1 + DIR_VECTORS[dir])
	local pawnBack = Board:GetPawn(p1 + DIR_VECTORS[dir_back])
	local bash = true
	local thrownPawn
	local pawnSpace
	
	if distance > 1 then
		if pawnFront then
			thrownPawn = pawnFront
			bash = false
		end
	elseif distance == 1 then
		if self.JudoToss and pawnBack then
			if self:IsAvailableTile(p1 + DIR_VECTORS[dir]) or self:CanCrush(pawnBack, pawnFront) then
				thrownPawn = pawnBack
				bash = false
			end
		end
	end
	
	if bash then
		
		local fx = SpaceDamage(p2)
		fx.sSound = "/weapons/titan_fist"
		if self.PushBash then
			fx.sAnimation = "explopush1_".. dir
			fx.iPush = dir
		else
			fx.sAnimation = "explosmash_".. dir
		end
		ret:AddDamage(fx)
		ret:AddDelay(0.05)
		
		ret:AddMelee(p1, SpaceDamage(p2), 0.20)
		
		local dmg = SpaceDamage(p2, self.Damage)
		ret:AddDamage(dmg)
	elseif thrownPawn then
		
		local throwFrom = thrownPawn:GetSpace()
		local crushedPawn = Board:GetPawn(p2)
		
		local damage = 0
		if self.ImpactDamage then
			local isEnemy =	isEnemy(Pawn:GetTeam(), thrownPawn:GetTeam())
			if isEnemy or not self.AllyImmune then
				damage = self.Damage
			end
		end
		
		local fx = SpaceDamage(throwFrom)
		fx.sSound = "/weapons/titan_fist"
		fx.sAnimation = "lmn_exploforklift_".. GetDirection(throwFrom - p1)
		ret:AddDamage(fx)
		
		ret:AddMelee(p1, SpaceDamage(throwFrom), NO_DELAY)
		
		local id = thrownPawn:GetId()
		-- hide pawn we are about to throw.
		ret:AddScript([[
			Board:GetPawn(]].. id ..[[):SetSpace(Point(-1, -1));
		]])
		-- preview damage to thrown pawn on it's original tile.
		local spaceDamage = SpaceDamage(throwFrom, damage)
		ret:AddDamage(spaceDamage)
		
		-- return pawn we are about to throw.
		ret:AddScript([[
			Board:GetPawn(]].. id ..[[):SetSpace(Point(]].. throwFrom.x ..", ".. throwFrom.y ..[[));
		]])
		ret:AddDelay(0.1)
		
		local leap = PointList()
		leap:push_back(throwFrom)
		leap:push_back(p2)
		
		ret:AddLeap(leap, NO_DELAY)
		
		if thrownPawn:IsMech() then
			ret:AddDelay(0.48)
			ret:AddSound("mech/land")
			ret:AddDelay(0.32)
		else
			ret:AddDelay(0.8)
		end
		
		-- hide thrown pawn.
		ret:AddScript([[
			Board:GetPawn(]].. id ..[[):SetSpace(Point(-1, -1));
		]])
		-- kill pawn being crushed.
		if crushedPawn then
			local death = SpaceDamage(p2, 499)	-- custom hidden DAMAGE_DEATH
			ret:AddDamage(death)				-- hides skull, but shows hp blinking.
			if crushedPawn:IsFrozen()
			or crushedPawn:IsShield()
			or crushedPawn:IsAcid()
			or thrownPawn:IsAcid()
			or Board:IsAcid(p2)
			or IsArmor(crushedPawn)
			or IsArmor(thrownPawn)		then
				local death = SpaceDamage(p2, DAMAGE_DEATH)	-- show the skull to hide unwanted
				ret:AddDamage(death)						-- acid/frozen/shield/armor icons
			end
		end
		-- return thrown pawn.
		ret:AddScript([[
			Board:GetPawn(]].. id ..[[):SetSpace(Point(]].. p2.x ..", ".. p2.y ..[[));
		]])
		
		-- deal damage we previewed to thrown pawn at it's destination.
		ret:AddScript([[
			local spaceDamage = SpaceDamage(Point(]].. p2.x ..", ".. p2.y ..[[), ]].. damage ..[[);
			lmn_stacker_modApiExt.pawn:safeDamage(Board:GetPawn(]].. id ..[[), spaceDamage);
		]])
		
		if self.PushAdjacent then
			local dirs = {0, 1, 2, 3}
			--local dirs = {(dir+1)%4, (dir+3)%4}
			for _, i in ipairs(dirs) do
				local curr = p2 + DIR_VECTORS[i]
				if Board:IsValid(curr) then
					local dmg = self.DamageAdjacent and self.Damage or 0
					local spaceDamage = SpaceDamage(curr, dmg)
					spaceDamage.sAnimation = "exploout0_".. i
					
					if	not Board:IsValid(curr + DIR_VECTORS[i])
					or	curr == p1 + DIR_VECTORS[dir]				then
						
						spaceDamage.sImageMark = "combat/lmn_stacker_push_box.png"
					else
						spaceDamage.iPush = i
					end
					
					ret:AddDamage(spaceDamage)
				end
			end
		end
	end
	
	return ret
end

lmn_LiftAtk_A = lmn_LiftAtk:new{
	UpgradeDescription = "Enemies take damage when thrown.",
	ImpactDamage = true,
	AllyImmune = true,
	CustomTipImage = "lmn_LiftAtk_Tip_A",
	TipImage = {
		Unit = Point(2,3),
		Enemy = Point(2,2),
		Forest = Point(2,2),
		Friendly = Point(1,1),
		Target = Point(2,1),
	},
}

lmn_LiftAtk_B = lmn_LiftAtk:new{
	UpgradeDescription = "Allows thrown unit to target and crush units with less health.",
	Crush = true,
	Crush_Target = Point(2,1),
	Crush_Type = "Scarab1",
	Crush_Anim = "scarab",
	CustomTipImage = "lmn_LiftAtk_Tip_B",
	TipImage = {
		Unit = Point(2,3),
		Enemy = Point(2,2),
		Friendly = Point(1,1),
		Target = Point(2,1),
	},
}

lmn_LiftAtk_AB = lmn_LiftAtk:new{
	ImpactDamage = true,
	AllyImmune = true,
	Crush = true,
	Crush_Target = lmn_LiftAtk_B.Crush_Target,
	Crush_Type = lmn_LiftAtk_B.Crush_Type,
	Crush_Anim = lmn_LiftAtk_B.Crush_Anim,
	CustomTipImage = "lmn_LiftAtk_Tip_AB",
	TipImage = lmn_LiftAtk_A.TipImage,
}

lmn_LiftAtk_Tip = lmn_LiftAtk:new{}
lmn_LiftAtk_Tip_A = lmn_LiftAtk_A:new{}
lmn_LiftAtk_Tip_B = lmn_LiftAtk_B:new{}
lmn_LiftAtk_Tip_AB = lmn_LiftAtk_AB:new{}

function lmn_LiftAtk_Tip:GetTargetArea(point, bool)
	return lmn_LiftAtk.GetTargetArea(self, point, bool)
end

function lmn_LiftAtk_Tip:GetSkillEffect(p1, p2, bool)
	if	self.Crush_Target	and
		self.Crush_Type		and
		self.Crush_Anim		then
		
		Board:ClearSpace(self.Crush_Target)
		local unit = SpaceDamage(self.Crush_Target)
		unit.sPawn = self.Crush_Type
		Board:DamageSpace(unit)
		Board:GetPawn(self.Crush_Target):SetCustomAnim(self.Crush_Anim)
	end
	
	local ret = lmn_LiftAtk.GetSkillEffect(self, p1, p2, bool)
	ret:AddDelay(1.5)
	return ret
end

lmn_LiftAtk_Tip_A.GetTargetArea = lmn_LiftAtk_Tip.GetTargetArea
lmn_LiftAtk_Tip_B.GetTargetArea = lmn_LiftAtk_Tip.GetTargetArea
lmn_LiftAtk_Tip_AB.GetTargetArea = lmn_LiftAtk_Tip.GetTargetArea
lmn_LiftAtk_Tip_A.GetSkillEffect = lmn_LiftAtk_Tip.GetSkillEffect
lmn_LiftAtk_Tip_B.GetSkillEffect = lmn_LiftAtk_Tip.GetSkillEffect
lmn_LiftAtk_Tip_AB.GetSkillEffect = lmn_LiftAtk_Tip.GetSkillEffect

Location["combat/lmn_stacker_push_box.png"] = Point(-28,1)

function mech:init(mod)
	self.mod = mod
	-- custom blank damage icons to cause blinking to happen without showing the skull when damaging.
	-- we want to stay below 1000 damage so we don't overwrite DAMAGE_DEATH events.
	modApi:appendAsset("img/combat/icons/damage_498.png", mod.resourcePath .."img/combat/icons/DAMAGE_DEATH_HIDDEN.png") -- damage reduced by armor
	modApi:appendAsset("img/combat/icons/damage_499.png", mod.resourcePath .."img/combat/icons/DAMAGE_DEATH_HIDDEN.png") -- normal damage
	modApi:appendAsset("img/combat/icons/damage_996.png", mod.resourcePath .."img/combat/icons/DAMAGE_DEATH_HIDDEN.png") -- acid on thrown pawn, armor on crushed pawn (or visa versa?)
	modApi:appendAsset("img/combat/icons/damage_998.png", mod.resourcePath .."img/combat/icons/DAMAGE_DEATH_HIDDEN.png") -- damage doubled by acid
	modApi:appendAsset("img/weapons/lmn_weapon_stacker.png", mod.resourcePath .."img/weapons/stacker.png")
	modApi:appendAsset("img/combat/lmn_stacker_push_box.png", mod.resourcePath .."img/combat/push_box.png")
	
	for _, dir in ipairs{"U", "R", "L", "D"} do
		modApi:appendAsset("img/effects/lmn_forklift_".. dir ..".png", mod.resourcePath .."img/effects/forklift_".. dir ..".png")
	end
	setfenv(1, ANIMS)
	lmn_exploforklift_0 = Animation:new{
		Image = "effects/lmn_forklift_U.png",
		NumFrames = 8,
		Layer = LAYER_BACK,
		Time = 0.06,
		PosX = -22,
		PosY = -9
	}
	lmn_exploforklift_1 = lmn_exploforklift_0:new{Image = "effects/lmn_forklift_R.png"}
	lmn_exploforklift_2 = lmn_exploforklift_0:new{Image = "effects/lmn_forklift_D.png"}
	lmn_exploforklift_3 = lmn_exploforklift_0:new{Image = "effects/lmn_forklift_L.png"}
end

function mech:load(modApiExt)
	lmn_stacker_modApiExt = modApiExt
	self.modApiExt = modApiExt
end

return mech