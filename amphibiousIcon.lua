
local icon = sdlext.surface("img/combat/icons/icon_flying.png")

local this = {
	icon = icon,
	title = Global_Texts.TipTitle_HangarFlying,
	desc = Global_Texts.TipText_HangarFlying,
	hangarMechs = {},
	oldGetNames = {},
}

-- TODO:	connect mech with pilot on region screen
--			to detect Prospero in amphibious mech.
local function IsAmphibious(pawnType, flyingPilot)
	local v = _G[pawnType]
	return	v.lmn_dissolver_amphibious	and
			v.Flying					and
			not flyingPilot
end

local function SetIcon(icon)
	this.icon = sdlext.surface(icon)
end

local function SetTooltip(title, desc)
	this.title = title
	this.desc = desc
end

local function list_clear(list)
	for i, _ in ipairs(list) do
		list[i] = nil
	end
end

local function list_subrange(list, first, last)
	local ret = {}
	for i = 1, 3 do ret[i] = list[i] end
	return ret
end

-- returns true if we're in Region view
local function IsRegion()
    return Game ~= nil and GetCurrentMission() == nil
end

local function GetHangarMechs()
	return list_subrange(this.hangarMechs, 1, 3)
end

local function GetHoveredMech()
	if #this.hangarMechs == 1 then
		return this.hangarMechs[1]
	elseif #this.hangarMechs == 4 then
		return this.hangarMechs[4]
	end
	
	return nil
end

local function OverrideGetNames()
	this.pawns = {}
	for pawnType, v in pairs(_G) do
		if type(v) == "table" and v.Health and v.Image then
			table.insert(this.pawns, pawnType)
			if v.GetName then
				this.oldGetNames[pawnType] = v.GetName
			end
			v.GetName = function(self, _, parent)
				if not parent then
					if
						not IsHangarWindowlessState() or
						IsRegion()
					then
						table.insert(this.hangarMechs, pawnType)
					end
				end
				
				local fn = this.oldGetNames[pawnType]
				return fn
					and fn(self, _, parent)
					or  self.Name
			end
		end
	end
end

local function RestoreGetNames()
	for _, id in ipairs(this.pawns) do
		_G[id].GetName = oldGetNames[id]
	end
end

-- returns the pawnId of pawn
-- currentlty having it's UI drawn.
local function GetUIEnabledPawn()
	if Board then
		if IsTestMechScenario() then
			for id = 0, 2 do
				local pawn = Board:GetPawn(id)
				if pawn then return pawn end
			end
			return nil
			
		elseif this.selected  then
			return this.selected
			
		elseif this.highlighted and Board:IsPawnSpace(this.highlighted) then
			return Board:GetPawn(this.highlighted)
		else
			local hovered = GetHoveredMech()	-- this can fetch the wrong mech.
			if hovered then						-- not sure how to make sure we get the right one.
				for id = 0, 2 do
					local pawn = Board:GetPawn(id)
					if pawn and pawn:GetType() == hovered.pawnType then
						return pawn
					end
				end
			end
		
		end
	end
	
    return nil
end

local hangarWidgets = {}
local selectMechWidget
local missionSmallWidget
local missionLargeWidget
local decoColorHangarBlack = sdl.rgb(9, 7 ,8)
local decoColorMissionBlack = sdl.rgb(22, 23, 25)

sdlext.addUiRootCreatedHook(function(screen, uiRoot)
	
	local decoDrawFn = function(self, screen, widget)
		local oldX = widget.rect.x
		local oldY = widget.rect.y
		
		widget.rect.x = widget.rect.x - 2
		widget.rect.y = widget.rect.y + 2
		
		DecoSurfaceOutlined.draw(self, screen, widget)
		
		widget.rect.x = oldX
		widget.rect.y = oldY
	end
	
	-- 3 widgets to cover up flying icons
	-- for mechs selected in the hangar.
	for i = 1, 3 do
		hangarWidgets[i] = Ui()
			:widthpx(25):heightpx(21)
			:decorate({ DecoSolid(deco.colors.button) })
			:addTo(uiRoot)
		local mask = Ui()
			:widthpx(25):heightpx(21)
			:decorate({ DecoSolid(deco.colors.transparent) })
			:addTo(hangarWidgets[i])
		local child = Ui()
			:widthpx(20):heightpx(15)
			:decorate({ DecoSurfaceOutlined(this.icon, 1, deco.colors.buttonborder, deco.colors.focus, 1) })
			:addTo(hangarWidgets[i])
		hangarWidgets[i].translucent = true
		hangarWidgets[i].visible = false
		hangarWidgets[i].clipRect = sdl.rect(0, 0, 25, 21)
		hangarWidgets[i].animations.fadeIn = UiAnim(hangarWidgets[i], 600, function(anim, widget, percent)
			widget.decorations[1].color = InterpolateColor(
				deco.colors.button,
				deco.colors.buttonhl,
				percent
			)
		end)
		child.onMouseEnter = function(self)
			Global_Texts.TipTitle_HangarFlying = this.title
			Global_Texts.TipText_HangarFlying = this.desc
		end
		child.onMouseExit = function(self)
			Global_Texts.TipTitle_HangarFlying = "Flying"
			Global_Texts.TipText_HangarFlying = "Flying units can move over any terrain tile."
		end
		child.decorations[1].draw = decoDrawFn
		child.x = 2
		child.y = 2
		child.translucent = true
		mask.translucent = true
		mask.animations.fadeIn = UiAnim(mask, 650, function(anim, widget, percent)
			widget.decorations[1].color = InterpolateColor(
				deco.colors.transparent,
				decoColorHangarBlack,
				percent
			)
		end)
	end
	
	-- 1 widget to cover up flying icon
	-- when selecting a custom mech.
	selectMechWidget = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSolid(deco.colors.framebg) })
		:addTo(uiRoot)
	local child = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSurfaceOutlined(this.icon, 1, deco.colors.buttonborder, deco.colors.focus, 1) })
		:addTo(selectMechWidget)
	child.translucent = true
	selectMechWidget.translucent = true
	selectMechWidget.visible = false
	selectMechWidget.clipRect = sdl.rect(0, 0, 25, 21)
	
	-- 1 widget to cover up flying icon
	-- when hovering/selecting mech in mission
	missionSmallWidget = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSolid(decoColorMissionBlack) })
		:addTo(uiRoot)
	local mask = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSolid(deco.colors.transparent) })
		:addTo(missionSmallWidget)
	local child = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSurfaceOutlined(this.icon, 1, deco.colors.buttonborder, deco.colors.focus, 1) })
		:addTo(missionSmallWidget)
	missionSmallWidget.translucent = true
	missionSmallWidget.visible = false
	missionSmallWidget.clipRect1 = sdl.rect(0, 0, 25, 21)
	missionSmallWidget.clipRect2 = sdl.rect(0, 0, 25, 21)
	child.translucent = true
	child.decorations[1].draw = function(self, screen, widget)
		self.surface = self.surface or self.surfacenormal
		DecoSurface.draw(self, screen, widget)
	end
	mask.translucent = true
	mask.animations.fadeIn = UiAnim(mask, 1400, function(anim, widget, percent)
		widget.decorations[1].color = InterpolateColor(
			deco.colors.transparent,
			decoColorMissionBlack,
			percent
		)
		if percent == 1 then
			missionSmallWidget.isMasked = true
		end
	end)
	
	-- 1 widget to cover up flying icon
	-- when hovering a mech's buffs.
	missionLargeWidget = Ui()
		:widthpx(50):heightpx(42)
		:decorate({ DecoSolid(deco.colors.framebg) })
		:addTo(uiRoot)
	local child = Ui()
		:widthpx(50):heightpx(42)
		:decorate({ DecoSurfaceOutlined(this.icon, 1, deco.colors.buttonborder, deco.colors.buttonborder, 2) })
		:addTo(missionLargeWidget)
	child.translucent = true
	missionLargeWidget.translucent = true
	missionLargeWidget.visible = false
	missionLargeWidget.clipRect = sdl.rect(0, 0, 50, 42)
	
	-- 1 widget to cover up flying icon
	-- when hovering mech in region view
	regionWidget = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSolid(deco.colors.framebg) })
		:addTo(uiRoot)
	local child = Ui()
		:widthpx(25):heightpx(21)
		:decorate({ DecoSurfaceOutlined(this.icon, 1, deco.colors.buttonborder, deco.colors.buttonborder, 1) })
		:addTo(regionWidget)
	child.translucent = true
	regionWidget.translucent = true
	regionWidget.visible = false
	regionWidget.clipRect = sdl.rect(0, 0, 25, 21)
	
	-- flying icons
	-- CUSTOM/RANDOM + FULLSCREEN
	-- 1: y=403
	-- 2: y=508
	-- 3: y=613
	
	-- CUSTOM/RANDOM + WINDOWED/STRETCHED
	-- 1: y=330
	-- 2: y=435
	-- 3: y=540
	
	-- PREMADE + FULLSCREEN
	-- 1: y=439
	-- 2: y=544
	-- 3: y=649
	
	-- PREMADE + WINDOWED/STRETCHED
	-- 1: y=366
	-- 2: y=471
	-- 3: y=576
	
	-- SKILLS (fullscreen)
	-- 0: x=1117
	-- 1: x=1117
	-- 2: x=1184
	
	for i = 1, 3 do
		hangarWidgets[i].draw = function(self, screen)
			self.visible = false
			if icon:wasDrawn() then
				if	sdlext.isHangar()				and
					IsHangarWindowlessState()		then
					
					local mechs = HangarGetSelectedMechs()
					if mechs[i] and IsAmphibious(mechs[i]) then
						
						self.x = icon.x
						self.y = icon.y
						
						-- offset icon to correct y position
						local offsetIndex = 1
						if icon.y == 540 or icon.y == 613 or icon.y == 649 or icon.y == 576 then
							offsetIndex = 3
							
						elseif icon.y == 435 or icon.y == 508 or icon.y == 544 or icon.y == 471 then
							offsetIndex = 2
						end
						
						-- offset icon by width of pawn's weapons
						if mechs[offsetIndex] then
							self.x = self.x - 67 * (#_G[mechs[offsetIndex]].SkillList - #_G[mechs[i]].SkillList)
						end
						self.y = self.y - 105 * (offsetIndex - i)
						self.clipRect.x = self.x
						self.clipRect.y = self.y
						
						if	(sdlext.CurrentWindowRect.w ~= 420
						or	(sdlext.CurrentWindowRect.h ~= 480			and
							sdlext.CurrentWindowRect.h ~= 493))			and
							rect_intersects(self.clipRect,
											sdlext.CurrentWindowRect)	then
							
							self.clipRect.w = math.max(0, math.min(25, sdlext.CurrentWindowRect.x - self.x))
						else
							self.clipRect.w = 25
						end
						
						self.visible = true
					end
				end
			end
			
			screen:clip(self.clipRect)
			Ui.draw(self, screen)
			screen:unclip()
		end
	end
	
	selectMechWidget.draw = function(self, screen)
		self.visible = false
		if	icon:wasDrawn()					and
			sdlext.isHangar()				and
			not IsHangarWindowlessState()	then
			
			local mech = GetHoveredMech()
			if mech and IsAmphibious(mech) then
			
				self.x = icon.x
				self.y = icon.y
				
				self.clipRect.x = self.x
				self.clipRect.y = self.y
				
				self.visible = true
			end
		end
		
		screen:clip(self.clipRect)
		Ui.draw(self, screen)
		screen:unclip()
	end
	
	local function IsMenu()
		return	sdlext.CurrentWindowRect.w == 275 and
				sdlext.CurrentWindowRect.h == 500
	end
	
	-- TODO: find the correct threshold of the pawn tooltip.
	-- smallest seen 260
	-- largest seen 278
	--
	-- potential issue if the gap is too large and we start
	-- mistaking it for other Ui elements within the same widths.
	-- already having to distinguish between Menu object.
	local function IsLargeTooltip()
		return	sdlext.CurrentWindowRect.w >= 260 and
				sdlext.CurrentWindowRect.w <= 278
	end
	
	-- sets x and w of rect a to not clip with rect b.
	-- assumes b is wider than a
	local function ClipWidth(a, b)
		local x, w = a.x, a.w
		if x < b.x then
			a.w = math.max(0, math.min(w, b.x - x))
		else
			a.x = math.max(x, b.x + b.w)
			a.w = math.max(0, math.min(w, x + w - (b.x + b.w)))
		end
	end
	
	-- sets y and h of rect a to not clip with rect b.
	-- assumes b is taller than a
	local function ClipHeight(a, b)
		local y, h = a.y, a.h
		if y < b.y then
			a.h = math.max(0, math.min(h, b.y - y))
		else
			a.y = math.max(y, b.y + b.h)
			a.h = math.max(0, math.min(h, y + h - (b.y + b.h)))
		end
	end
	
	missionSmallWidget.draw = function(self, screen)
		self.visible = false
		if	icon:wasDrawn()					and
			GetCurrentMission()				and
			not missionSmallWidget.isMasked	then
			
			local pawn = GetUIEnabledPawn()
			if pawn and IsAmphibious(pawn:GetType(), pawn:IsAbility("Flying")) then
				if not IsLargeTooltip() then
					self.x = icon.x
					self.y = icon.y
					
					self.clipRect1.x = self.x
					self.clipRect1.y = self.y
					self.clipRect1.w = 25
					self.clipRect1.h = 21
					
					if rect_intersects(self.clipRect1, sdlext.CurrentWindowRect) then
						ClipWidth(self.clipRect1, sdlext.CurrentWindowRect)
						
						if self.clipRect1.x < sdlext.CurrentWindowRect.x then
							self.clipRect2.x = self.x + self.clipRect1.w
						else
							self.clipRect2.x = self.x
						end
						self.clipRect2.y = self.y
						self.clipRect2.w = 25 - self.clipRect1.w
						self.clipRect2.h = 21
						
						ClipHeight(self.clipRect2, sdlext.CurrentWindowRect)
					end
					
					self.children[2].decorations[1].surface = self.children[2].decorations[1].surfacenormal
				elseif not IsMenu() then
					self.children[2].decorations[1].surface = self.children[2].decorations[1].surfacehl
				end
				self.visible = true
			end
		end
		
		screen:clip(self.clipRect1)
		Ui.draw(self, screen)
		screen:unclip()
		screen:clip(self.clipRect2)
		Ui.draw(self, screen)
		screen:unclip()
	end
	
	missionLargeWidget.draw = function(self, screen)
		self.visible = false
		if	icon:wasDrawn()			and
			GetCurrentMission()		then
			
			local pawn = GetUIEnabledPawn()
			if pawn and IsAmphibious(pawn:GetType(), pawn:IsAbility("Flying")) then
				if	IsLargeTooltip()	and
					not IsMenu()		then
					
					self.x = icon.x
					self.y = icon.y
					
					self.clipRect.x = self.x
					self.clipRect.y = self.y
					
					self.visible = true
				end
			end
		end
		
		screen:clip(self.clipRect)
		Ui.draw(self, screen)
		screen:unclip()
	end
	
	regionWidget.draw = function(self, screen)
		self.visible = false
		if	icon:wasDrawn()							and
			IsRegion()								then
			
			local mech = GetHoveredMech()
			if mech and IsAmphibious(mech) then
				
				self.x = icon.x
				self.y = icon.y
				
				self.clipRect.x = self.x
				self.clipRect.y = self.y
				
				if rect_intersects(self.clipRect, sdlext.CurrentWindowRect) then
					self.clipRect.w = math.max(0, math.min(25, sdlext.CurrentWindowRect.x - self.x))
				else
					self.clipRect.w = 25
				end
				
				self.visible = true
			end
		end
		
		screen:clip(self.clipRect)
		Ui.draw(self, screen)
		screen:unclip()
	end
end)

sdlext.addFrameDrawnHook(function(screen)
	if	not IsHangarWindowlessState()
	or	IsRegion()						then
		
		list_clear(this.hangarMechs)
	end
end)

sdlext.addGameExitedHook(function(screen)
	this.selected = nil
	this.highlighted = nil
end)

sdlext.addHangarLeavingHook(function(startGame)

	if startGame then
		for _, widget in ipairs(hangarWidgets) do
			local mask = widget.children[1]
			widget.animations.fadeIn:start()
			mask.animations.fadeIn:start()
		end
	end
end)

sdlext.addHangarExitedHook(function(screen)
	
	for _, widget in ipairs(hangarWidgets) do
		local mask = widget.children[1]
		widget.animations.fadeIn:stop()
		widget.decorations[1].color = deco.colors.button
		mask.animations.fadeIn:stop()
		mask.decorations[1].color = deco.colors.transparent
	end
end)

function this:init(mod)
	SetIcon(mod.resourcePath .."img/combat/icons/icon_amphibious.png")
	SetTooltip("Amphibious", "Amphibious units operates unhindered when submerged in water.")
end

function this:load(modApiExt)
	modApiExt:addPawnSelectedHook(function(mission, pawn)
		this.selected = pawn
	end)
	modApiExt:addPawnDeselectedHook(function()
		this.selected = nil
	end)
	modApiExt:addTileHighlightedHook(function(mission, tile)
		this.highlighted = tile
	end)
	modApiExt:addTileUnhighlightedHook(function()
		this.highlighted = nil
	end)
	if not self.hooksOverriden then
		self.hooksOverriden = true
		modApi:scheduleHook(40, function()
			OverrideGetNames()
		end)
	end
	
	modApi:addMissionEndHook(function(mission)
		local mask = missionSmallWidget.children[1]
		mask.animations.fadeIn:start()
		modApi:conditionalHook(
			function()
				return IsRegion() or GetCurrentMission() ~= mission
			end,
			function()
				missionSmallWidget.isMasked = nil
				mask.animations.fadeIn:stop()
				mask.decorations[1].color = deco.colors.transparent
			end
		)
	end)
end

return this