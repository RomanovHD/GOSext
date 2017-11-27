if myHero.charName ~= "Karthus" then return end

require "DamageLib"
require 'Eternal Prediction'

local Q = { Name = "Lay Waste", Range = 875, Delay = 0.5, Speed = 2000, Width = 100}
local W = { Name = "Wall of Pain", Range = 1000, Delay = myHero:GetSpellData(_W).delay, Speed = myHero:GetSpellData(_W).speed, Width = myHero:GetSpellData(_W).width}
local E = { Name = "Defile", Range = 425}
local R = { Name = "Requiem", Range = 20000}

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function ValidTarget(target, range)
	range = range and range or math.huge
	return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range
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

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

local function PercentMP(target)
    return 100 * target.mana / target.maxMana
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
end

local function GetTarget(range)
	local target = nil
	if _G.SDK and _G.SDK.Orbwalker then
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = GOS:GetTarget(range)
	end
	return target
end

local function GetMode()
	if _G.SDK and _G.SDK.Orbwalker then
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
		end
	else
		return GOS.GetMode()
	end
end

local function HeroesAround(pos, range, team)
	local Count = 0
	for i = 1, Game.HeroCount() do
		local minion = Game.Hero(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
end

local function MinionsAround(pos, range, team)
	local Count = 0
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team == team and not minion.dead and pos:DistanceTo(minion.pos) <= range then
			Count = Count + 1
		end
	end
	return Count
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

local function Rdmg(target)
	local level = myHero:GetSpellData(_R).level
	if Ready(_R) then
    	return CalcMagicalDamage(myHero, target, (100 + 150 * level + 0.6 * myHero.ap))
	end
	return 0
end

local function Idmg(target)
	if (myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1))
	or (myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2)) then
		return 50 + 20 * myHero.levelData.lvl
	end
	return 0
end

local function BSdmg(target)
	if (myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1))
	or (myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2)) then
		return 20 + 8 * myHero.levelData.lvl
	end
	return 0
end

local function RSdmg(target)
	if (myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1))
	or (myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2)) then
		return 54 + 6 * myHero.levelData.lvl
	end
	return 0
end

local function NoPotion()
	for i = 0, myHero.buffCount do 
	local buff = myHero:GetBuff(i)
		if buff.type == 13 and Game.Timer() < buff.expireTime then 
			return false
		end
	end
	return true
end

local sqrt = math.sqrt

local function GetDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return (dx * dx + dz * dz)
end

local function GetDistance(p1, p2)
    return sqrt(GetDistanceSqr(p1, p2))
end

local function GetDistance2D(p1,p2)
    return sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

local function ClosestToMouse(p1, p2) 
	if GetDistance(mousePos, p1) > GetDistance(mousePos, p2) then return p2 else return p1 end
end

local function CircleCircleIntersection(c1, c2, r1, r2) 
	local D = GetDistance(c1, c2)
	if D > r1 + r2 or D <= math.abs(r1 - r2) then return nil end 
	local A = (r1 * r2 - r2 * r1 + D * D) / (2 * D) 
	local H = math.sqrt(r1 * r1 - A * A)
	local Direction = (c2 - c1):Normalized() 
	local PA = c1 + A * Direction 
	local S1 = PA + H * Direction:Perpendicular() 
	local S2 = PA - H * Direction:Perpendicular() 
	return S1, S2 
end

local function EnableOrb(bool)
	if Orb == 1 then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif Orb == 2 then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
end

--// Menu
local Karthus = MenuElement({type = MENU, id = "Karthus", name = "HD Karthus"})

Karthus:MenuElement({id = "Script", name = "Karthus", drop = {"HD v1"}})
Karthus:MenuElement({name = " ", drop = {"Champion Core"}})
Karthus:MenuElement({type = MENU, id = "C", name = "Combo"})
Karthus:MenuElement({type = MENU, id = "H", name = "Harass"})
Karthus:MenuElement({type = MENU, id = "LC", name = "LaneClear"})
Karthus:MenuElement({type = MENU, id = "JC", name = "JungleClear"})
Karthus:MenuElement({name = " ", drop = {"Champion Utility"}})
Karthus:MenuElement({type = MENU, id = "K", name = "Keys"})
Karthus:MenuElement({type = MENU, id = "MM", name = "Mana"})
Karthus:MenuElement({type = MENU, id = "D", name = "Drawings"})
Karthus:MenuElement({type = MENU, id = "P", name = "Predict"})
Karthus:MenuElement({name = " ", drop = {"Extra Utility"}})
Karthus:MenuElement({type = MENU, id = "A", name = "Activator"})
Karthus:MenuElement({type = MENU, id = "Lv", name = "Auto Leveler"})

Karthus.C:MenuElement({id = "Q", name = "Q: " ..Q.Name, value = true})
Karthus.C:MenuElement({id = "W", name = "W: " ..W.Name, value = true})
Karthus.C:MenuElement({id = "E", name = "E: " ..E.Name, value = true})

Karthus.H:MenuElement({id = "Q", name = "Q: " ..Q.Name, value = true})

Karthus.LC:MenuElement({id = "Q", name = "Q: " ..Q.Name, value = true})
Karthus.LC:MenuElement({id = "QMin", name = "Minions to Q", value = 3, min = 1, max = 7})
Karthus.LC:MenuElement({id = "E", name = "E: " ..E.Name, value = true})
Karthus.LC:MenuElement({id = "EMin", name = "Minions to E", value = 5, min = 1, max = 7})

Karthus.JC:MenuElement({id = "Q", name = "Q: " ..Q.Name, value = true})
Karthus.JC:MenuElement({id = "E", name = "E: " ..E.Name, value = true})

Karthus.K:MenuElement({id = "Clear", name = "Spell Clear", key = string.byte("A"), toggle = true})
Karthus.K:MenuElement({id = "Harass", name = "Spell Harass", key = string.byte("S"), toggle = true})

Karthus.P:MenuElement({id = "Chance", name = "Predict Manager", value = 0.200, min = 0.100, max = 1.000, step = 0.05})

Karthus.MM:MenuElement({id = "C", name = "Mana % to Combo", value = 0, min = 0, max = 101})
Karthus.MM:MenuElement({id = "H", name = "Mana % to Harass", value = 35, min = 0, max = 101})
Karthus.MM:MenuElement({id = "LC", name = "Mana % to Lane", value = 35, min = 0, max = 101})
Karthus.MM:MenuElement({id = "JC", name = "Mana % to Jungle", value = 35, min = 0, max = 101})
Karthus.MM:MenuElement({id = "KS", name = "Mana % to Killsteal", value = 35, min = 0, max = 101})

Karthus.A:MenuElement({type = MENU, id = "P", name = "Potions"})
Karthus.A.P:MenuElement({id = "Pot", name = "All Potions", value = true})
Karthus.A.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
Karthus.A:MenuElement({type = MENU, id = "I", name = "Items"})
Karthus.A.I:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
Karthus.A.I:MenuElement({id = "Proto", name = "Hextec Items (all)", value = true})
Karthus.A.I:MenuElement({id = "Tiamat", name = "Tiamat Items (all)", value = true})
Karthus.A:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
		Karthus.A.S:MenuElement({id = "Smite", name = "Smite in Combo [?]", value = true, tooltip = "If Combo will kill"})
		Karthus.A.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		Karthus.A.S:MenuElement({id = "Heal", name = "Auto Heal", value = true})
		Karthus.A.S:MenuElement({id = "HealHP", name = "Health % to Heal", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		Karthus.A.S:MenuElement({id = "Barrier", name = "Auto Barrier", value = true})
		Karthus.A.S:MenuElement({id = "BarrierHP", name = "Health % to Barrier", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
		Karthus.A.S:MenuElement({id = "Ignite", name = "Ignite in Combo", value = true})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
		Karthus.A.S:MenuElement({id = "Exh", name = "Exhaust in Combo [?]", value = true, tooltip = "If Combo will kill"})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		Karthus.A.S:MenuElement({id = "Cleanse", name = "Auto Cleanse", value = true})
		Karthus.A.S:MenuElement({id = "Blind", name = "Blind", value = false})
		Karthus.A.S:MenuElement({id = "Charm", name = "Charm", value = true})
		Karthus.A.S:MenuElement({id = "Flee", name = "Flee", value = true})
		Karthus.A.S:MenuElement({id = "Slow", name = "Slow", value = false})
		Karthus.A.S:MenuElement({id = "Root", name = "Root/Snare", value = true})
		Karthus.A.S:MenuElement({id = "Poly", name = "Polymorph", value = true})
		Karthus.A.S:MenuElement({id = "Silence", name = "Silence", value = true})
		Karthus.A.S:MenuElement({id = "Stun", name = "Stun", value = true})
		Karthus.A.S:MenuElement({id = "Taunt", name = "Taunt", value = true})
	end
end, 2)
Karthus.A.S:MenuElement({type = SPACE, id = "Note", name = "Note: Ghost/TP/Flash is not supported"})

Karthus.D:MenuElement({id = "Q", name = "Q: " ..Q.Name, value = true})
Karthus.D:MenuElement({id = "W", name = "W: " ..W.Name, value = true})
Karthus.D:MenuElement({id = "E", name = "E: " ..E.Name, value = false})
Karthus.D:MenuElement({id = "Dmg", name = "R: " ..R.Name.. " [Damage]", value = false})
Karthus.D:MenuElement({id = "T", name = "Spell Toggle", value = true})

Karthus.Lv:MenuElement({id = "Enabled", name = "Enable", value = true})
Karthus.Lv:MenuElement({id = "Block", name = "Block on Level 1", value = true})
Karthus.Lv:MenuElement({id = "Order", name = "Skill Priority", value = 2, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

local function PredCast(hotkey,slot,target,predmode)
	local data = { range = slot.Range, delay = slot.Delay, speed = slot.Speed, width = slot.Width }
	local spell = Prediction:SetSpell(data, predmode, false)
	local pred = spell:GetPrediction(target,myHero.pos)
	if pred and pred.hitChance >= Karthus.P.Chance:Value() then
		Control.CastSpell(hotkey, pred.castPos)
	end
end

--// script
Callback.Add("Tick", function() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function AutoLevel()
	if Karthus.Lv.Enabled:Value() == false then return end
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
	local SkillPoints = myHero.levelData.lvl - (myHero:GetSpellData(_Q).level + myHero:GetSpellData(_W).level + myHero:GetSpellData(_E).level + myHero:GetSpellData(_R).level)
	local level = myHero.levelData.lvl
	local Check = Sequence[Karthus.Lv.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if Karthus.Lv.Block:Value() and level == 1 then return end
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

function Tick()
    local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	elseif Mode == "Clear" then
		Lane()
        Jungle()
	elseif Mode == "Harass" then
        Harass()
    else
        DisableE()
	end
        Summoners()
        Activator()
        AutoLevel()
end

function DisableE()
    if myHero.dead then return end
    if myHero:GetSpellData(_E).toggleState == 2 and Ready(_E) then
		Control.CastSpell(HK_E)
	end
end

function Combo()
    if Karthus.MM.C:Value() > PercentMP(myHero) then return end
    local target = GetTarget(W.Range)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) and Karthus.C.E:Value() and myHero:GetSpellData(_E).toggleState ~= 2 then
        Control.CastSpell(HK_E)
    end
    if Ready(_W) and ValidTarget(target, W.Range) and Karthus.C.W:Value() then
		EnableOrb(false)
		PredCast(HK_W, W, target, TYPE_LINE)
		DelayAction(function() EnableOrb(true) end, 0.4)
    end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Karthus.C.Q:Value() then
		EnableOrb(false)
		PredCast(HK_Q, Q, target, TYPE_CIRCLE)
		DelayAction(function() EnableOrb(true) end, 0.4)
    end
end

function Lane()
	if Karthus.K.Clear:Value() == false then return end
    if Karthus.MM.LC:Value() > PercentMP(myHero) then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 - myHero.team then
            if Ready(_E) and ValidTarget(minion, E.Range) and Karthus.LC.Q:Value() and MinionsAround(myHero.pos, E.Range, 300 - myHero.team) >= Karthus.LC.EMin:Value() and myHero:GetSpellData(_E).toggleState ~= 2 then
                Control.CastSpell(HK_E)
            end
            if Ready(_Q) and ValidTarget(minion, Q.Range) and Karthus.LC.Q:Value() and MinionsAround(minion.pos, 100, 300 - myHero.team) >= Karthus.LC.QMin:Value() - 1 then
                EnableOrb(false)
                PredCast(HK_Q, Q, minion, TYPE_CIRCLE)
                DelayAction(function() EnableOrb(true) end, 0.4)
            end
        end
    end
end

function Jungle()
	if Karthus.K.Clear:Value() == false then return end
    if Karthus.MM.JC:Value() > PercentMP(myHero) then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 then
            if Ready(_E) and ValidTarget(minion, E.Range) and Karthus.JC.Q:Value() and myHero:GetSpellData(_E).toggleState ~= 2 then
                Control.CastSpell(HK_E)
            end
            if Ready(_Q) and ValidTarget(minion, Q.Range) and Karthus.JC.Q:Value() then
                EnableOrb(false)
                PredCast(HK_Q, Q, minion, TYPE_CIRCLE)
                DelayAction(function() EnableOrb(true) end, 0.4)
            end
        end
    end
end

function Harass()
	if Karthus.K.Harass:Value() == false then return end
    if Karthus.MM.H:Value() > PercentMP(myHero) then return end
    local target = GetTarget(Q.Range)
    if target == nil then return end
	if Ready(_Q) and ValidTarget(target, Q.Range) and Karthus.H.Q:Value() then
        EnableOrb(false)
		PredCast(HK_Q, Q, target, TYPE_CIRCLE)
		DelayAction(function() EnableOrb(true) end, 0.4)
    end
end

function Summoners()
	local target = GetTarget(1500)
    if target == nil then return end
	if GetMode() == "Combo" then
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if Karthus.A.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + RSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Karthus.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Karthus.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + BSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Karthus.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Karthus.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if Karthus.A.S.Ignite:Value() then
				local IgDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + Idmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			if Karthus.A.S.Exh:Value() then
				local Damage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and Ready(SUMMONER_1) and Damage > target.health
				and myHero.pos:DistanceTo(target.pos) < 650 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and Ready(SUMMONER_1) and Damage > target.health
				and myHero.pos:DistanceTo(target.pos) < 650 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if Karthus.A.S.Heal:Value() then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < Karthus.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < Karthus.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if Karthus.A.S.Barrier:Value() then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < Karthus.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < Karthus.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		if Karthus.A.S.Cleanse:Value() then
			for i = 0, myHero.buffCount do
			local buff = myHero:GetBuff(i);
				if buff.count > 0 then
					if ((buff.type == 5 and Karthus.A.S.Stun:Value())
					or (buff.type == 7 and  Karthus.A.S.Silence:Value())
					or (buff.type == 8 and  Karthus.A.S.Taunt:Value())
					or (buff.type == 9 and  Karthus.A.S.Poly:Value())
					or (buff.type == 10 and  Karthus.A.S.Slow:Value())
					or (buff.type == 11 and  Karthus.A.S.Root:Value())
					or (buff.type == 21 and  Karthus.A.S.Flee:Value())
					or (buff.type == 22 and  Karthus.A.S.Charm:Value())
					or (buff.type == 25 and  Karthus.A.S.Blind:Value())
					or (buff.type == 28 and  Karthus.A.S.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) then
							Control.CastSpell(HK_SUMMONER_2)
						end
					end
				end
			end
		end
	end
end

function Activator()
	local target = GetTarget(900)
    if target == nil then return end
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
	end

	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and myHero:GetSpellData(Potion).currentCd == 0 and Karthus.A.P.Pot:Value() and PercentHP(myHero) < Karthus.A.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
	end

	if GetMode() == "Combo" then
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and Karthus.A.I.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end

		local Proto = items[3152] or items[3146] or items[3146] or items[3030]
		if Proto and myHero:GetSpellData(Proto).currentCd == 0 and Karthus.A.I.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Proto], target.pos)
        end
        local Tiamat = items[3077] or items[3074] or items[3748]
        if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and Karthus.A.I.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
            Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
	end
end

function Drawings()
    if myHero.dead then return end
	if Karthus.D.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 222, 255)) end
    if Karthus.D.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 255, 200, 000)) end
	if Karthus.D.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 246, 000, 255)) end
	if Karthus.D.T:Value() then
		local textPosC = myHero.pos:To2D()
		if Karthus.K.Clear:Value() then
			Draw.Text("Clear: On", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
		local textPosH = myHero.pos:To2D()
		if Karthus.K.Harass:Value() then
			Draw.Text("Harass: On", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
    end
    if Karthus.D.Dmg:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead and enemy.visible then
				local barPos = enemy.hpBar
				if Rdmg(enemy) > enemy.health then
    				Draw.Rect(barPos.x, barPos.y, (enemy.health / enemy.maxHealth ) * 100, 10, Draw.Color(170, 000, 255, 000))
                else
                    Draw.Rect(barPos.x + (((enemy.health - Rdmg(enemy)) / enemy.maxHealth) * 100), barPos.y, (Rdmg(enemy) / enemy.maxHealth )*100, 10, Draw.Color(170, 000, 222, 255))
                end
            end
		end
	end
end
