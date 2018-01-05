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

--- Khazix ---
class "Khazix"

local KhazixVersion = "v1.00"

function Khazix:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Khazix:LoadSpells()
	Q = { range = self:Qrange(), delay = 0.25, cost = 20, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6a/Taste_Their_Fear.png" }
	W = { range = 1000, delay = 0.25, cost = self:Wcost(), speed = 1650, width = myHero:GetSpellData(_W).width, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4e/Void_Spike.png" }
    W2 = { icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/7e/Evolved_Spike_Racks.png" }
    E = { range = self:Erange(), delay = 0.25, cost = 50, speed = 1700, width = myHero.boundingRadius, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/af/Leap.png" }
	R = { range = self:Rrange(), delay = 0.25, cost = 100, icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bb/Void_Assault.png" }
end

function Khazix:LoadMenu()
	RomanovKhazix = MenuElement({type = MENU, id = "RomanovKhazix", name = "Romanov's Signature "..Version})
	--- Version ---
	RomanovKhazix:MenuElement({name = "Kha Zix", drop = {KhazixVersion}, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/d0/Kha%27Zix_OriginalCircle.png"})
	--- Combo ---
	RomanovKhazix:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
	RomanovKhazix.Combo:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	RomanovKhazix.Combo:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
	RomanovKhazix.Combo:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
	RomanovKhazix.Combo:MenuElement({id = "R", name = "Smart [R] Combo [?]", value = true, leftIcon = R.icon, tooltip = "When Killable with full Combo"})
    --- Clear ---
	RomanovKhazix:MenuElement({type = MENU, id = "Clear", name = "Clear Settings"})
	RomanovKhazix.Clear:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("A"), toggle = true})
	RomanovKhazix.Clear:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
    RomanovKhazix.Clear:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
    RomanovKhazix.Clear:MenuElement({id = "Whit", name = "[W] Min Hit", value = 5, min = 1, max = 7})
    RomanovKhazix.Clear:MenuElement({id = "E", name = "Use [E] in Jungle", value = true, leftIcon = E.icon})
    RomanovKhazix.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear [%]", value = 0, min = 0, max = 100})
    RomanovKhazix.Clear:MenuElement({id = "Ignore", name = "Ignore Mana if Blue Buff", value = true})
	--- Harass ---
	RomanovKhazix:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
	RomanovKhazix.Harass:MenuElement({id = "Key", name = "Toggle: Key", key = string.byte("S"), toggle = true})
	RomanovKhazix.Harass:MenuElement({id = "Q", name = "Use [Q]", value = true, leftIcon = Q.icon})
	RomanovKhazix.Harass:MenuElement({id = "W", name = "Use [W]", value = true, leftIcon = W.icon})
    RomanovKhazix.Harass:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
    RomanovKhazix.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass [%]", value = 0, min = 0, max = 100})
    RomanovKhazix.Harass:MenuElement({id = "Ignore", name = "Ignore Mana if Blue Buff", value = true})
    --- Flee ---
    RomanovKhazix:MenuElement({type = MENU, id = "Flee", name = "Flee Settings"})
    RomanovKhazix.Flee:MenuElement({id = "W", name = "Evolved [W]", value = true, leftIcon = W2.icon})
    RomanovKhazix.Flee:MenuElement({id = "E", name = "Use [E]", value = true, leftIcon = E.icon})
    RomanovKhazix.Flee:MenuElement({id = "EM", name = "Mode", drop = {"Walljump","Normal"}})
	--- Misc ---
    RomanovKhazix:MenuElement({type = MENU, id = "Misc", name = "Misc Settings"})
    RomanovKhazix.Misc:MenuElement({id = "Wks", name = "Killsecure [W]", value = true, leftIcon = W.icon})
    RomanovKhazix.Misc:MenuElement({id = "Eks", name = "Killsecure [E]", value = true, leftIcon = E.icon})
    --- Misc ---
    RomanovKhazix:MenuElement({type = MENU, id = "Pred", name = "Predict Settings"})
    RomanovKhazix.Pred:MenuElement({id = "Wich", name = "Wich Predict", drop = {"Noddy","Eternal Prediction","TPred","Normal"}})
	--- Draw ---
	RomanovKhazix:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
	RomanovKhazix.Draw:MenuElement({id = "W", name = "Draw [W] Range", value = true, leftIcon = W.icon})
	RomanovKhazix.Draw:MenuElement({id = "E", name = "Draw [E] Range", value = true, leftIcon = E.icon})
	RomanovKhazix.Draw:MenuElement({id = "CT", name = "Clear Toggle", value = true})
	RomanovKhazix.Draw:MenuElement({id = "HT", name = "Harass Toggle", value = true})
	RomanovKhazix.Draw:MenuElement({id = "DMG", name = "Draw Combo Damage", value = true})
end

function Khazix:Tick()
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

function Khazix:CastW(target)
	if target:GetCollision(W.width, W.speed, W.delay) ~= 0 then return end
	RomanovCast(HK_W,W,target,myHero)
end

function Khazix:CastE(target)
	RomanovCast(HK_E,E,target,myHero)
end

function Khazix:Combo()
	local target = GetTarget(R.range)
    if target == nil then return end
    if GetDistance(target.pos) < myHero.range and myHero.attackData.state ~= STATE_WINDDOWN then return end

	if RomanovKhazix.Combo.R:Value() and Ready(_R) and GetDistance(target.pos) < R.range then
		if self:GetComboDamage(target) > target.health and myHero.mana > Q.cost + W.cost + E.cost + R.cost then
			Control.CastSpell(HK_R)
		end
	end
	if RomanovKhazix.Combo.Q:Value() and Ready(_Q) and GetDistance(target.pos) < Q.range then
		Control.CastSpell(HK_Q, target)
	end
	if RomanovKhazix.Combo.W:Value() and Ready(_W) and GetDistance(target.pos) < W.range then
		self:CastW(target)
    end
    if RomanovKhazix.Combo.E:Value() and Ready(_E) and GetDistance(target.pos) < E.range then
        self:CastE(target)
	end
end

function Khazix:Harass()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	local target = GetTarget(W.range)
    if RomanovKhazix.Harass.Key:Value() == false then return end
	if PercentMP(myHero) < RomanovKhazix.Harass.Mana:Value() and not (blue and RomanovKhazix.Harass.Ignore:Value()) then return end
    if target == nil then return end
    if GetDistance(target.pos) < myHero.range and myHero.attackData.state ~= STATE_WINDDOWN then return end

	if RomanovKhazix.Harass.Q:Value() and Ready(_Q) and GetDistance(target.pos) < Q.range then
        Control.CastSpell(HK_Q, target)
	end
	if RomanovKhazix.Harass.W:Value() and Ready(_W) and GetDistance(target.pos) < W.range then
		self:CastW(target)
    end
    if RomanovKhazix.Harass.E:Value() and Ready(_E) and GetDistance(target.pos) < E.range then
        self:CastE(target)
	end
end

function Khazix:Clear()
    local blue = HasBuff(myHero, "crestoftheancientgolem")
	if RomanovKhazix.Clear.Key:Value() == false then return end
    if myHero.mana/myHero.maxMana < RomanovKhazix.Clear.Mana:Value() and not (blue and RomanovKhazix.Clear.Ignore:Value()) then return end
    
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if  minion and minion.team == 300 - myHero.team then
			if RomanovKhazix.Clear.Q:Value() and Ready(_Q) then
                if GetDistance(minion.pos) < Q.range then
                    Control.CastSpell(HK_Q, minion)
                end
			end
			if RomanovKhazix.Clear.W:Value() and Ready(_W) and MinionsAround(275,minion.pos) >= RomanovKhazix.Clear.Whit:Value() then
                local pred = minion:GetPrediction(W.speed, W.delay)
                if GetDistance(pred) < W.range then
                    Control.CastSpell(HK_W, pred)
                end
			end
		elseif minion and minion.team == 300 then
            if RomanovKhazix.Clear.E:Value() and Ready(_E) then
				local pred = minion:GetPrediction(E.speed, E.delay)
                if GetDistance(pred) < E.range then
                    Control.CastSpell(HK_E, pred)
                end
			end
            if RomanovKhazix.Clear.Q:Value() and Ready(_Q) then
                if GetDistance(minion.pos) < Q.range then
                    Control.CastSpell(HK_Q, minion)
                end
			end
			if RomanovKhazix.Clear.W:Value() and Ready(_W) and GetDistance(minion.pos) < W.range then
				local pred = minion:GetPrediction(W.speed, W.delay)
                if GetDistance(pred) < W.range then
                    Control.CastSpell(HK_W, pred)
                end
			end
		end
	end
end

function Khazix:Flee()
	local target = GetTarget(W.range)

    if target and RomanovKhazix.Flee.W:Value() and Ready(_W) and self:IsWevolved() and GetDistance(target.pos) < W.range then
		self:CastW(target)
    end

    if RomanovKhazix.Flee.E:Value() and Ready(_E) then
        local mode = RomanovKhazix.Flee.EM:Value()
        if mode == 2 then
            Control.CastSpell(HK_E, Game.cursorPos())
        elseif mode == 1 then
            local vec = Vector(myHero.pos):Extended(Vector(mousePos), E.range)
            if not MapPosition:inWall(vec) and MapPosition:intersectsWall(LineSegment(myHero,vec)) then
                Control.CastSpell(HK_E, vec)
            end
        end
    end
end

function Khazix:Misc()
	local target = GetTarget(W.range)
    if target == nil then return end
    
	if RomanovKhazix.Misc.Eks:Value() and Ready(_E) then
		local Edmg = CalcPhysicalDamage(myHero, target, (30 + 35 * myHero:GetSpellData(_E).level + 0.2 * myHero.bonusDamage))
		if Edmg > target.health then
			self:CastE(target)
		end
	end
	if RomanovKhazix.Misc.Wks:Value() and Ready(_W) then
		local Wdmg = CalcPhysicalDamage(myHero, target, (55 + 30 * myHero:GetSpellData(_W).level + myHero.bonusDamage))
		if Wdmg > target.health then
			self:CastW(target)
		end
    end
end

function Khazix:GetComboDamage(unit)
	local Total = 0
	local Qdmg = CalcPhysicalDamage(myHero, unit, (15 + 25 * myHero:GetSpellData(_Q).level + 0.35 * myHero.ap))
	local Wdmg = CalcPhysicalDamage(myHero, unit, (55 + 30 * myHero:GetSpellData(_W).level + myHero.bonusDamage))
	local Edmg = CalcPhysicalDamage(myHero, unit, (30 + 35 * myHero:GetSpellData(_E).level + 0.2 * myHero.bonusDamage))
	local Rdmg = CalcMagicalDamage(myHero, unit, (6 + 8 * myHero.levelData.lvl + 0.4 * myHero.bonusDamage)) + CalcPhysicalDamage(myHero, unit, myHero.totalDamage)
	if Ready(_Q) then
		Total = Total + Qdmg
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

function Khazix:Wcost()
    local level = myHero:GetSpellData(_W).level
    return 50 + 5 * level
end

function Khazix:Qrange()
    local name = myHero:GetSpellData(_Q).name
    if name == "KhazixQ" then
        return 325
    elseif name == "KhazixQLong" then
        return 375
    end
end

function Khazix:IsWevolved()
    local name = myHero:GetSpellData(_W).name
    if name == "KhazixW" then
        return false
    elseif name == "KhazixWLong" then
        return true
    end
end

function Khazix:Erange()
    local name = myHero:GetSpellData(_E).name
    if name == "KhazixE" then
        return 700
    elseif name == "KhazixELong" then
        return 900
    end
end

function Khazix:Rrange()
    return E.range + ((1.4 * myHero.ms) * 1.5)
end

function Khazix:Draw()
	if RomanovKhazix.Draw.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, 1000, 3,  Draw.Color(255,000, 075, 180)) end
	if RomanovKhazix.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, 975, 3,  Draw.Color(255,138, 162, 255)) end
	if RomanovKhazix.Draw.CT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovKhazix.Clear.Key:Value() then
			Draw.Text("Clear: On", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPos.x - 33, textPos.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
	end
	if RomanovKhazix.Draw.HT:Value() then
		local textPos = myHero.pos:To2D()
		if RomanovKhazix.Harass.Key:Value() then
			Draw.Text("Harass: On", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPos.x - 40, textPos.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if RomanovKhazix.Draw.DMG:Value() then
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
--- Khazix ---

--- Utility ---
class "Utility"

function Utility:__init()
	self:Menu()
	Callback.Add("Tick", function() self:Tick() end)
end

function Utility:Menu()
	RomanovKhazix:MenuElement({type = MENU, id = "Leveler", name = "Auto Leveler Settings"})
	RomanovKhazix.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
	RomanovKhazix.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
	RomanovKhazix.Leveler:MenuElement({id = "Order", name = "Skill Priority", drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

	RomanovKhazix:MenuElement({type = MENU, id = "Activator", name = "Activator Settings"})
	RomanovKhazix.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RomanovKhazix.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RomanovKhazix.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RomanovKhazix.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RomanovKhazix.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RomanovKhazix.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RomanovKhazix.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RomanovKhazix.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RomanovKhazix.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RomanovKhazix.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RomanovKhazix.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RomanovKhazix.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RomanovKhazix.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RomanovKhazix.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RomanovKhazix.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RomanovKhazix.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RomanovKhazix.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RomanovKhazix.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RomanovKhazix.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RomanovKhazix.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RomanovKhazix.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RomanovKhazix.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RomanovKhazix.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RomanovKhazix.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RomanovKhazix.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RomanovKhazix.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RomanovKhazix.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RomanovKhazix.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RomanovKhazix.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RomanovKhazix.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RomanovKhazix.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RomanovKhazix.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RomanovKhazix.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RomanovKhazix.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RomanovKhazix.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RomanovKhazix.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RomanovKhazix.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RomanovKhazix.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
			RomanovKhazix.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RomanovKhazix.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true})
			RomanovKhazix.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RomanovKhazix.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
			RomanovKhazix.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RomanovKhazix.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RomanovKhazix.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RomanovKhazix.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
		end
end

function Utility:Tick()
	self:AutoLevel()
	self:Activator()
end

function Utility:AutoLevel()
	if RomanovKhazix.Leveler.Enabled:Value() == false then return end
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
	local Check = Sequence[RomanovKhazix.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RomanovKhazix.Leveler.Block:Value() and level == 1 then return end
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
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RomanovKhazix.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RomanovKhazix.Activator.P.Pot:Value() and PercentHP(myHero) < RomanovKhazix.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RomanovKhazix.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RomanovKhazix.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RomanovKhazix.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RomanovKhazix.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RomanovKhazix.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RomanovKhazix.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and PercentHP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RomanovKhazix.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RomanovKhazix.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RomanovKhazix.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RomanovKhazix.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RomanovKhazix.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RomanovKhazix.Activator.S.BarrierHP:Value() then
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
					if ((buff.type == 5 and RomanovKhazix.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RomanovKhazix.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RomanovKhazix.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RomanovKhazix.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RomanovKhazix.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RomanovKhazix.Activator.CS.Root:Value())
					or (buff.type == 21 and  RomanovKhazix.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RomanovKhazix.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RomanovKhazix.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RomanovKhazix.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RomanovKhazix.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RomanovKhazix.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RomanovKhazix.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RomanovKhazix.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RomanovKhazix.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RomanovKhazix.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RomanovKhazix.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RomanovKhazix.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RomanovKhazix.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RomanovKhazix.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RomanovKhazix.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RomanovKhazix.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RomanovKhazix.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RomanovKhazix.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RomanovKhazix.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RomanovKhazix.Activator.S.Smite:Value() then
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RomanovKhazix.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RomanovKhazix.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1)
				and myHero:GetSpellData(SUMMONER_1).ammo >= RomanovKhazix.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2)
				and myHero:GetSpellData(SUMMONER_2).ammo >= RomanovKhazix.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RomanovKhazix.Activator.S.Ignite:Value() then
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
