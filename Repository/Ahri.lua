require 'DamageLib'
require '2DGeometry'
require 'MapPositionGOS'

if FileExist(COMMON_PATH .. "RomanovPred.lua") then
	require 'RomanovPred'
end

local Version = "v2.0"
--- Engine ---
local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

local function PercentMP(target)
    return 100 * target.mana / target.maxMana
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function MinionsAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or 300 - myHero.team
    local Count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local function HeroesAround(range, pos, team)
    local pos = pos or myHero.pos
    local team = team or 300 - myHero.team
    local Count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team == team and not hero.dead and hero.pos:DistanceTo(pos, hero.pos) < range then
			Count = Count + 1
		end
	end
	return Count
end

local function GetDistance(p1,p2)
    local p2 = p2 or myHero.pos
    return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2) + math.pow((p2.z - p1.z),2))
end

local function GetDistance2D(p1,p2)
    local p2 = p2 or myHero
    return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2))
end

local function GetTarget(range)
	local target = nil
	if _G.EOWLoaded then
		target = EOW:GetTarget(range)
	elseif _G.SDK and _G.SDK.Orbwalker then
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = GOS:GetTarget(range)
	end
	return target
end

local function GetMode()
	if _G.EOWLoaded then
		if EOW.CurrentMode == 1 then
			return "Combo"
		elseif EOW.CurrentMode == 2 then
			return "Harass"
		elseif EOW.CurrentMode == 3 then
			return "Lasthit"
		elseif EOW.CurrentMode == 4 then
			return "Clear"
		end
	elseif _G.SDK and _G.SDK.Orbwalker then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"	
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
			return "Clear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "Lasthit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_NONE] then
			return "None"
		end
	else
		return GOS.GetMode()
	end
end

local function EnableOrb(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif _G.SDK.Orbwalker then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
end

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 11 or buff.type == 29 or buff.type == 24 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
end

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

local function NoPotion()
	for i = 0, myHero.buffCount do 
	local buff = myHero:GetBuff(i)
		if buff.type == 13 and Game.Timer() < buff.expireTime then 
			return false
		end
	end
	return true
end
--- Engine ---

--- Predictions ---
-- Romanov --
function RomanovCast(hotkey,slot,target,from)
	local pred = RomanovPredPos(from,target,slot.speed,slot.delay,slot.width)
	if RomanovHitchance(from,target,slot.speed,slot.delay,slot.range,slot.width) >= 2 then
		EnableOrb(false)
		Control.CastSpell(hotkey, pred)
		DelayAction(function() EnableOrb(true) end, 0.25)
	end
end
-- Romanov --
--- Predictions

--- Ahri ---
class "Ahri"

local AhriVersion = "v1.01"

function Ahri:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Ahri:LoadSpells()
	Q = { range = 880, delay = 0.25, cost = self:Qcost(), speed = 1700, width = myHero:GetSpellData(_Q).width, icon = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/1/19/Orb_of_Deception.png" }
	W = { range = 700, delay = 0.25, cost = 50, speed = math.huge, icon = "https://vignette3.wikia.nocookie.net/leagueoflegends/images/a/a8/Fox-Fire.png" }
	E = { range = 975, delay = 0.25, cost = 85, speed = 1600, width = myHero:GetSpellData(_E).width, icon = "https://vignette4.wikia.nocookie.net/leagueoflegends/images/0/04/Charm.png" }
	R = { range = 450, delay = 0.25, cost = 100, icon = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/8/86/Spirit_Rush.png" }
end

function Ahri:LoadMenu()
	RomanovAhri = MenuElement({type = MENU, id = "RomanovAhri", name = "Romanov's Signature "..Version})
	--- Version ---
	RomanovAhri:MenuElement({name = "Ahri", drop = {AhriVersion}, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2c/Ahri_OriginalCircle.png"})
	--- Combo ---
	RomanovAhri:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
	RomanovAhri.Combo:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	RomanovAhri.Combo:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
	RomanovAhri.Combo:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
	RomanovAhri.Combo:MenuElement({id = "R", name = "Smart [R] Combo [?]", value = true, leftIcon = R.icon, tooltip = "When Killable with full Combo"})
    RomanovAhri.Combo:MenuElement({id = "RD", name = "[R] Secure Min Dist", value = 500, min = 0, max = 600})
    --- Clear ---
	RomanovAhri:MenuElement({type = MENU, id = "Clear", name = "Clear Settings"})
	RomanovAhri.Clear:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("A"), toggle = true})
	RomanovAhri.Clear:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	RomanovAhri.Clear:MenuElement({id = "Qhit", name = "[Q] Min Hit", value = 5, min = 1, max = 7})
    RomanovAhri.Clear:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
    RomanovAhri.Clear:MenuElement({id = "Whit", name = "[W] Min Hit", value = 3, min = 1, max = 3})
    RomanovAhri.Clear:MenuElement({id = "Passive", name = "Passive Priority", drop = {"[Q]","[W]"}})
    RomanovAhri.Clear:MenuElement({id = "E", name = "Use [E] in Jungle", value = true, leftIcon = E.icon})
    RomanovAhri.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear [%]", value = 0, min = 0, max = 100})
    RomanovAhri.Clear:MenuElement({id = "Ignore", name = "Ignore Mana if Blue Buff", value = true})
	--- Harass ---
	RomanovAhri:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
	RomanovAhri.Harass:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("S"), toggle = true})
	RomanovAhri.Harass:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	RomanovAhri.Harass:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
    RomanovAhri.Harass:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
    RomanovAhri.Harass:MenuElement({id = "Priority", name = "Mana Priority", drop = {"[Q]","[E]"}})
    RomanovAhri.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass [%]", value = 0, min = 0, max = 100})
    RomanovAhri.Harass:MenuElement({id = "Ignore", name = "Ignore Mana if Blue Buff", value = true})
    --- Flee ---
    RomanovAhri:MenuElement({type = MENU, id = "Flee", name = "Flee Settings"})
    RomanovAhri.Flee:MenuElement({id = "Q", name = "[Q] Backward", value = true, leftIcon = Q.icon})
    RomanovAhri.Flee:MenuElement({id = "W", name = "[W] if Rylai", value = true, leftIcon = W.icon})
    RomanovAhri.Flee:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
    RomanovAhri.Flee:MenuElement({id = "R", name = "Use [R]", value = true, leftIcon = R.icon})
    RomanovAhri.Flee:MenuElement({id = "RM", name = "Mode", drop = {"Walljump","Normal"}})
    RomanovAhri.Flee:MenuElement({id = "RA", name = "Only if already active", value = true})
	--- Misc ---
    RomanovAhri:MenuElement({type = MENU, id = "Misc", name = "Misc Settings"})
    RomanovAhri.Misc:MenuElement({id = "Qcc", name = "Auto [Q] Immobile", value = true, leftIcon = Q.icon})
	RomanovAhri.Misc:MenuElement({id = "Ecc", name = "Auto [E] Immobile", value = true, leftIcon = E.icon})
	RomanovAhri.Misc:MenuElement({id = "Qks", name = "Killsecure [Q]", value = true, leftIcon = Q.icon})
    RomanovAhri.Misc:MenuElement({id = "Eks", name = "Killsecure [E]", value = true, leftIcon = E.icon})
    --- Draw ---
	RomanovAhri:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
	RomanovAhri.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", value = true, leftIcon = Q.icon})
	RomanovAhri.Draw:MenuElement({id = "E", name = "Draw [E] Range", value = true, leftIcon = E.icon})
	RomanovAhri.Draw:MenuElement({id = "CT", name = "Clear Toggle", value = true})
	RomanovAhri.Draw:MenuElement({id = "HT", name = "Harass Toggle", value = true})
	RomanovAhri.Draw:MenuElement({id = "DMG", name = "Draw Combo Damage", value = true})
end

function Ahri:Tick()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Clear" then
		self:Clear()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
	end
		self:Misc()
end

function Ahri:CastQ(target)
	RomanovCast(HK_Q,Q,target,myHero)
end

function Ahri:CastE(target)
	if target:GetCollision(E.width, E.speed, E.delay) ~= 0 then return end
	RomanovCast(HK_E,E,target,myHero)
end

function Ahri:Combo()
	local target = GetTarget(1050)
    if target == nil then return end
    local tumble = HasBuff(myHero, "AhriTumble")
	if RomanovAhri.Combo.R:Value() and Ready(_R) and GetDistance(target.pos) < 1050 then
		if (self:GetComboDamage(target) > target.health and myHero.mana > Q.cost + W.cost + E.cost + R.cost) or tumble then
			local vec = Vector(myHero.pos):Extended(Vector(mousePos), R.range)
            if GetDistance(vec,target.pos) <= 600 and GetDistance(vec,target.pos) >= RomanovAhri.Combo.RD:Value() then
                Control.CastSpell(HK_R, vec)
            end
		end
	end
    if RomanovAhri.Combo.E:Value() and Ready(_E) then
        self:CastE(target)
	end
	if RomanovAhri.Combo.Q:Value() and Ready(_Q) and GetDistance(target.pos) < Q.range then
		self:CastQ(target)
	end
	if RomanovAhri.Combo.W:Value() and Ready(_W) and GetDistance(target.pos) < W.range and myHero.mana > Q.cost + W.cost + E.cost then
		Control.CastSpell(HK_W)
	end
end

function Ahri:Harass()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	local target = GetTarget(975)
	if RomanovAhri.Harass.Key:Value() == false then return end
	if PercentMP(myHero) < RomanovAhri.Harass.Mana:Value() and not (blue and RomanovAhri.Harass.Ignore:Value()) then return end
    if target == nil then return end
    local priority = RomanovAhri.Harass.Priority:Value()

	if RomanovAhri.Harass.E:Value() and Ready(_E) and ((priority == 1 and myHero.mana > Q.cost + E.cost) or (priority == 2 and myHero.mana > E.cost)) then
        self:CastE(target)
	end
	if RomanovAhri.Harass.Q:Value() and Ready(_Q) and ((priority == 1 and myHero.mana > Q.cost) or (priority == 2 and myHero.mana > Q.cost + E.cost)) then
        self:CastQ(target)
	end
	if RomanovAhri.Harass.W:Value() and Ready(_W) and GetDistance(target.pos) < W.range and myHero.mana > Q.cost + W.cost + E.cost then
		Control.CastSpell(HK_W)
	end
end

function Ahri:Clear()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	if RomanovAhri.Clear.Key:Value() == false then return end
    if myHero.mana/myHero.maxMana < RomanovAhri.Clear.Mana:Value() and not (blue and RomanovAhri.Clear.Ignore:Value()) then return end
    local heal = HasBuff(myHero, "ahrisoulcrusher")
    local priority = RomanovAhri.Clear.Passive:Value()

	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion and minion.team == 300 - myHero.team then
			if RomanovAhri.Clear.Q:Value() and Ready(_Q) and minion:GetCollision(Q.width,Q.speed,Q.delay) + 1 >= RomanovAhri.Clear.Qhit:Value() then
				local pred = minion:GetPrediction(Q.speed, Q.delay)
                if GetDistance(pred) < Q.range and (priority == 1 or (priority == 2 and not heal)) then
                    Control.CastSpell(HK_Q, pred)
                end
			end
			if RomanovAhri.Clear.W:Value() and Ready(_W) and MinionsAround(W.range) >= RomanovAhri.Clear.Whit:Value() and myHero.mana > Q.cost + W.cost and (priority == 2 or (priority == 1 and not heal)) then
				Control.CastSpell(HK_W)
			end
		elseif minion and minion.team == 300 then
            if RomanovAhri.Clear.E:Value() and Ready(_E) and not heal then
				local pred = minion:GetPrediction(E.speed, E.delay)
                if GetDistance(pred) < E.range then
                    Control.CastSpell(HK_E, pred)
                end
			end
            if RomanovAhri.Clear.Q:Value() and Ready(_Q) then
				local pred = minion:GetPrediction(Q.speed, Q.delay)
                if GetDistance(pred) < Q.range and (priority == 1 or (priority == 2 and not heal)) then
                    Control.CastSpell(HK_Q, pred)
                end
			end
			if RomanovAhri.Clear.W:Value() and Ready(_W) and GetDistance(minion.pos) < W.range and myHero.mana > Q.cost + W.cost + E.cost and (priority == 2 or (priority == 1 and not heal)) then
				Control.CastSpell(HK_W)
			end
		end
	end
end

function Ahri:Flee()
    local tumble = HasBuff(myHero, "AhriTumble")
	local target = GetTarget(975)

    if RomanovAhri.Flee.Q:Value() and Ready(_Q) then
        local vec = Vector(myHero.pos):Extended(Vector(mousePos), - Q.range)
        Control.CastSpell(HK_Q, vec)
    end
    if target and RomanovAhri.Flee.E:Value() and Ready(_E) then
		self:CastE(target)
    end

    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Rylai = items[3116]
    if target and Rylai and RomanovAhri.Flee.W:Value() and Ready(_W) then
        if GetDistance(target.pos) < W.range then
            Control.CastSpell(HK_W)
        end
    end

    if RomanovAhri.Flee.R:Value() and Ready(_R) then
        if tumble or (not RomanovAhri.Flee.RA:Value()) then
            local mode = RomanovAhri.Flee.RM:Value()
            if mode == 2 then
                Control.CastSpell(HK_R, Game.cursorPos())
            elseif mode == 1 then
                local vec = Vector(myHero.pos):Extended(Vector(mousePos), R.range)
                if not MapPosition:inWall(vec) and MapPosition:intersectsWall(LineSegment(myHero,vec)) then
                    Control.CastSpell(HK_R, vec)
                end
            end
        end
    end
end

function Ahri:Misc()
	local target = GetTarget(975)
    if target == nil then return end
    
	if RomanovAhri.Misc.Eks:Value() and Ready(_E) then
		local Edmg = CalcMagicalDamage(myHero, target, (25 + 35 * myHero:GetSpellData(_E).level + 0.6 * myHero.ap))
		if Edmg > target.health then
			self:CastE(target)
		end
	end
	if RomanovAhri.Misc.Qks:Value() and Ready(_Q) then
		local Qdmg = CalcMagicalDamage(myHero, target, (15 + 25 * myHero:GetSpellData(_Q).level + 0.35 * myHero.ap)) + (15 + 25 * myHero:GetSpellData(_Q).level + 0.35 * myHero.ap)
		if Qdmg > target.health then
			self:CastQ(target)
		end
    end
    
    if RomanovAhri.Misc.Ecc:Value() and Ready(_E) then
		if IsImmobileTarget(target) then
			self:CastE(target)
		end
    end
    if RomanovAhri.Misc.Qcc:Value() and Ready(_Q) then
		if IsImmobileTarget(target) then
			self:CastQ(target)
		end
    end
end

function Ahri:GetComboDamage(unit)
	local Total = 0
	local Qdmg = CalcMagicalDamage(myHero, unit, (15 + 25 * myHero:GetSpellData(_Q).level + 0.35 * myHero.ap))
	local Q2dmg = (15 + 25 * myHero:GetSpellData(_Q).level + 0.35 * myHero.ap)
	local Wdmg = CalcMagicalDamage(myHero, unit, (15 + 25 * myHero:GetSpellData(_Q).level + 0.3 * myHero.ap))
	local Edmg = CalcMagicalDamage(myHero, unit, (25 + 35 * myHero:GetSpellData(_E).level + 0.6 * myHero.ap))
	local Rdmg = CalcMagicalDamage(myHero, unit, (30 + 40 * myHero:GetSpellData(_R).level + 0.25 * myHero.ap))
	if Ready(_Q) then
		Total = Total + Qdmg + Q2dmg
	end
	if Ready(_W) then
		Total = Total + Wdmg
	end
	if Ready(_E) then
		Total = Total + Edmg
	end
	if Ready(_R) then
		Total = Total + Rdmg
	end
	return Total
end

function Ahri:Qcost()
    local level = myHero:GetSpellData(_Q).level
    return 60 + 5 * level
end

function Ahri:Draw()
	if RomanovAhri.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, 880, 3,  Draw.Color(255,000, 075, 180)) end
	if RomanovAhri.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, 975, 3,  Draw.Color(255,138, 162, 255)) end
	if RomanovAhri.Draw.CT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovAhri.Clear.Key:Value() then
			Draw.Text("Clear: On", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
	end
	if RomanovAhri.Draw.HT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovAhri.Harass.Key:Value() then
			Draw.Text("Harass: On", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if RomanovAhri.Draw.DMG:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead then
				if OnScreen(enemy) then
				local rectPos = enemy.hpBar
					if self:GetComboDamage(enemy) < enemy.health then
						Draw.Rect(rectPos.x + 20 , rectPos.y - 13 ,(tostring(math.floor(self:GetComboDamage(enemy)/enemy.health*100)))*((enemy.health/enemy.maxHealth)),11, Draw.Color(150, 000, 000, 255)) 
					else
						Draw.Rect(rectPos.x + 20 , rectPos.y - 13 ,((enemy.health/enemy.maxHealth)*100),10, Draw.Color(150, 255, 255, 000)) 
					end
				end
			end
		end
	end
end
--- Ahri ---

--- Utility ---
class "Utility"

function Utility:__init()
	self:Menu()
	Callback.Add("Tick", function() self:Tick() end)
end

function Utility:Menu()
	RomanovAhri:MenuElement({type = MENU, id = "Leveler", name = "Auto Leveler Settings"})
	RomanovAhri.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
	RomanovAhri.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
	RomanovAhri.Leveler:MenuElement({id = "Order", name = "Skill Priority", drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

	RomanovAhri:MenuElement({type = MENU, id = "Activator", name = "Activator Settings"})
	RomanovAhri.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RomanovAhri.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RomanovAhri.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RomanovAhri.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RomanovAhri.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RomanovAhri.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RomanovAhri.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RomanovAhri.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RomanovAhri.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RomanovAhri.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RomanovAhri.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RomanovAhri.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RomanovAhri.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RomanovAhri.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RomanovAhri.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RomanovAhri.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RomanovAhri.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RomanovAhri.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RomanovAhri.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RomanovAhri.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RomanovAhri.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RomanovAhri.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RomanovAhri.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RomanovAhri.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RomanovAhri.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RomanovAhri.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RomanovAhri.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RomanovAhri.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RomanovAhri.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RomanovAhri.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RomanovAhri.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RomanovAhri.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RomanovAhri.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RomanovAhri.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RomanovAhri.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RomanovAhri.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RomanovAhri.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RomanovAhri.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
			RomanovAhri.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RomanovAhri.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true})
			RomanovAhri.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RomanovAhri.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
			RomanovAhri.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RomanovAhri.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RomanovAhri.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RomanovAhri.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
		end
end

function Utility:Tick()
	self:AutoLevel()
	self:Activator()
end

function Utility:AutoLevel()
	if RomanovAhri.Leveler.Enabled:Value() == false then return end
	local Sequence = {
	[1] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_W, HK_Q, HK_W, HK_R, HK_W, HK_W, HK_E, HK_E, HK_R, HK_E, HK_E },
	[2] = { HK_Q, HK_E, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_E, HK_Q, HK_E, HK_R, HK_E, HK_E, HK_W, HK_W, HK_R, HK_W, HK_W },
	[3] = { HK_W, HK_Q, HK_E, HK_W, HK_W, HK_R, HK_W, HK_Q, HK_W, HK_Q, HK_R, HK_Q, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_E },
	[4] = { HK_W, HK_E, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_E, HK_W, HK_E, HK_R, HK_E, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
	[5] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_Q, HK_E, HK_Q, HK_R, HK_Q, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_W },
	[6] = { HK_E, HK_W, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_W, HK_E, HK_W, HK_R, HK_W, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
	}
	local Slot = nil
	local Tick = 0
	local SkillPoints = myHero.levelData.lvlPts
	local level = myHero.levelData.lvl
	local Check = Sequence[RomanovAhri.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RomanovAhri.Leveler.Block:Value() and level == 1 then return end
		if GetTickCount() - Tick > 800 and Check ~= nil then
			Control.KeyDown(HK_LUS)
			Control.KeyDown(Check)
			Slot = Check
			Tick = GetTickCount()
		end
	end
	if Control.IsKeyDown(HK_LUS) then
		Control.KeyUp(HK_LUS)
	end
	if Slot and Control.IsKeyDown(Slot) then
		Control.KeyUp(Slot)
	end
end

function Utility:Activator()
	local target = GetTarget(1575)
	if target == nil then return end
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Banner = items[3060]
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RomanovAhri.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RomanovAhri.Activator.P.Pot:Value() and PercentHP(myHero) < RomanovAhri.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RomanovAhri.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RomanovAhri.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RomanovAhri.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RomanovAhri.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RomanovAhri.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RomanovAhri.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and PercentHP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RomanovAhri.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RomanovAhri.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RomanovAhri.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RomanovAhri.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RomanovAhri.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RomanovAhri.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		if target then
			for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i);
				if buff.count > 0 then
					if ((buff.type == 5 and RomanovAhri.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RomanovAhri.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RomanovAhri.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RomanovAhri.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RomanovAhri.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RomanovAhri.Activator.CS.Root:Value())
					or (buff.type == 21 and  RomanovAhri.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RomanovAhri.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RomanovAhri.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RomanovAhri.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RomanovAhri.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RomanovAhri.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RomanovAhri.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RomanovAhri.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RomanovAhri.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RomanovAhri.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RomanovAhri.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RomanovAhri.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RomanovAhri.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RomanovAhri.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RomanovAhri.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RomanovAhri.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RomanovAhri.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RomanovAhri.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RomanovAhri.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RomanovAhri.Activator.S.Smite:Value() then
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RomanovAhri.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RomanovAhri.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RomanovAhri.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RomanovAhri.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RomanovAhri.Activator.S.Ignite:Value() then
				local IgDamage = 70 + 20 * myHero.levelData.lvl
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
	end
end
--- Utility ---

Callback.Add("Load", function()
	if _G[myHero.charName] then
		_G[myHero.charName]()
		Utility()
		print("Romanov Repository "..Version..": "..myHero.charName.." Loaded")
		print("PM me for suggestions/fix problems")
		print("Discord: Romanov#6333")
	else print ("Romanov Repository doens't support "..myHero.charName.." shutting down...") return
	end
end)
