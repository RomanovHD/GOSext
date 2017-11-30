if myHero.charName ~= "Ahri" then return end

require "DamageLib"
require "Eternal Prediction"

local Q = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/19/Orb_of_Deception.png", Name = "Orb of Deception", Range = 880, Delay = 0.25, Speed = 1700, Width = 80}
local W = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a8/Fox-Fire.png", Name = "Fox-Fire", Range = 700}
local E = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/04/Charm.png", Name = "Charm", Range = 925, Delay = 0.25, Speed = 1600, Width = 90}
local R = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/86/Spirit_Rush.png", Name = "Spirit Rush", Range = 425}

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function ValidTarget(target, range)
	range = range and range or math.huge
	return target ~= nil and target.valid and target.isTargetable and target.visible and not target.dead and target.distance <= range and not target.isImmortal
end

local function HP(unit)
    return 100 * unit.health / unit.maxHealth
end

local function MP(unit)
    return 100 * unit.mana / unit.maxMana
end

local function OnScreen(unit)
	return unit.pos:To2D().onScreen;
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

local function GetTarget(range)
	local target = nil 
	if _G.EOWLoaded then
		target = EOW:GetTarget(range)
	elseif _G.SDK and _G.SDK.Orbwalker then 
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = _G.GOS:GetTarget(range)
	end
	return target
end

function GetMode()
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
			return "LastHit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
	else
		return GOS:GetMode()
	end
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

local abs = math.abs 
local deg = math.deg 
local acos = math.acos
function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - deg(acos(V*D/(V:Len()*D:Len())))
    if abs(Angle) < 80 then 
        return true  
    end
    return false
end

local function PredCast(hotkey,slot,target,predmode)
	local data = { range = slot.Range, delay = slot.Delay, speed = slot.Speed, width = slot.Width }
	local spell = Prediction:SetSpell(data, predmode, false)
	local pred = spell:GetPrediction(target,myHero.pos)
	if pred and pred.hitChance >= 0.250 then
		Control.CastSpell(hotkey, pred.castPos)
	end
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

local function Qdmg(target)
    local level = myHero:GetSpellData(_Q).level
	if Ready(_Q) then
    	return CalcMagicalDamage(myHero, target, (15 + 25 * level + 0.35 * myHero.ap))
	end
	return 0
end

local function Wdmg(target)
    local level = myHero:GetSpellData(_W).level
	if Ready(_W) then
    	return CalcMagicalDamage(myHero, target, (15 + 25 * level + 0.3 * myHero.ap))
	end
	return 0
end

local function Edmg(target)
    local level = myHero:GetSpellData(_E).level
	if Ready(_E) then
        return CalcMagicalDamage(myHero, target, (25 + 35 * level + 0.6 * myHero.ap))
	end
	return 0
end

local function Rdmg(target)
    local level = myHero:GetSpellData(_R).level
	if Ready(_R) then
    	return CalcMagicalDamage(myHero, target, (30 + 40 * level + 0.25 * myHero.ap))
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

local function IsRecalling()
    for i = 1, myHero.buffCount do
    local buff = myHero:GetBuff(i) 
        if buff.count > 0 and buff.name == "recall" and Game.Timer() < buff.expireTime then
            return true
        end
    end 
    return false
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

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

local Ahri = MenuElement({type = MENU, id = "Ahri", name = "VIP Ahri"})

Ahri:MenuElement({name = "VIP Ahri", drop = {"1.0"}})
Ahri:MenuElement({name = " ", drop = {"Core"}})
Ahri:MenuElement({type = MENU, id = "C", name = "Combo"})
Ahri:MenuElement({type = MENU, id = "H", name = "Harass"})
Ahri:MenuElement({type = MENU, id = "LC", name = "Clear"})
Ahri:MenuElement({type = MENU, id = "KS", name = "Killsteal"})
Ahri:MenuElement({type = MENU, id = "F", name = "Flee"})
Ahri:MenuElement({type = MENU, id = "AU", name = "Auto"})
Ahri:MenuElement({name = " ", drop = {"Utility"}})
Ahri:MenuElement({type = MENU, id = "A", name = "Activator"})
Ahri:MenuElement({type = MENU, id = "L", name = "Leveler"})
Ahri:MenuElement({type = MENU, id = "MM", name = "Mana Manager"})
Ahri:MenuElement({type = MENU, id = "K", name = "Keys"})
Ahri:MenuElement({type = MENU, id = "D", name = "Drawings"})

Ahri.C:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true})
Ahri.C:MenuElement({id = "W", name = "W - " ..W.Name, value = true})
Ahri.C:MenuElement({id = "E", name = "E - " ..E.Name, value = true})
Ahri.C:MenuElement({id = "R", name = "R - " ..R.Name, value = true})
Ahri.C:MenuElement({id = "Ra", name = "Only R if already active", value = false})
Ahri.C:MenuElement({name = " ", drop = {"R only when combo will kill"}})

Ahri.H:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true})
Ahri.H:MenuElement({id = "W", name = "W - " ..W.Name, value = true})
Ahri.H:MenuElement({id = "E", name = "E - " ..E.Name, value = true})

Ahri.LC:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true})
Ahri.LC:MenuElement({id = "Qx", name = "Minions Hit by Q", value = 4, min = 1, max = 7})
Ahri.LC:MenuElement({id = "W", name = "W - " ..W.Name, value = true})
Ahri.LC:MenuElement({id = "Wx", name = "Minions Hit by W", value = 3, min = 1, max = 3})
Ahri.LC:MenuElement({id = "E", name = "E - " ..E.Name, value = false})
Ahri.LC:MenuElement({name = " ", drop = {"E for jungle only"}})
Ahri.LC:MenuElement({name = " ", drop = {"Minions manager for lane only"}})

Ahri.KS:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true})
Ahri.KS:MenuElement({id = "E", name = "E - " ..E.Name, value = true})
Ahri.KS:MenuElement({id = "RC", name = "Dont KS if recalling", value = true})

Ahri.F:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true})
Ahri.F:MenuElement({id = "E", name = "E - " ..E.Name, value = true})
Ahri.F:MenuElement({id = "R", name = "R - " ..R.Name, value = true})
Ahri.F:MenuElement({id = "Ra", name = "Only R if already active", value = true})

Ahri.AU:MenuElement({id = "Q", name = "Auto Q on CC", value = true})
Ahri.AU:MenuElement({id = "E", name = "Safe auto E", value = true})
Ahri.AU:MenuElement({id = "Eg", name = "E Anti-gapclose", value = true})

Ahri.L:MenuElement({id = "Enabled", name = "Auto Level Up", value = true})
Ahri.L:MenuElement({id = "Block", name = "1st Level Block", value = true})
Ahri.L:MenuElement({id = "Order", name = "Leveler Sequence", drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

Ahri.MM:MenuElement({id = "C", name = "Mana % to Combo", value = 0, min = 0, max = 100})
Ahri.MM:MenuElement({id = "H", name = "Mana % to Harass", value = 60, min = 0, max = 100})
Ahri.MM:MenuElement({id = "LC", name = "Mana % to Clear", value = 55, min = 0, max = 100})
Ahri.MM:MenuElement({id = "KS", name = "Mana % to Killsteal", value = 0, min = 0, max = 100})
Ahri.MM:MenuElement({id = "F", name = "Mana % to Flee", value = 5, min = 0, max = 100})
Ahri.MM:MenuElement({id = "A", name = "Mana % to Auto Cast", value = 60, min = 0, max = 100})

Ahri.K:MenuElement({id = "Clear", name = "Spell Clear", key = string.byte("A"), toggle = true})
Ahri.K:MenuElement({id = "Harass", name = "Spell Harass", key = string.byte("S"), toggle = true})

Ahri.D:MenuElement({id = "Q", name = "Q - "..Q.Name, value = true})
Ahri.D:MenuElement({id = "W", name = "W - "..W.Name, value = true})
Ahri.D:MenuElement({id = "E", name = "E - "..E.Name, value = true})
Ahri.D:MenuElement({id = "R", name = "R - "..R.Name, value = true})
Ahri.D:MenuElement({id = "T", name = "Spell Toggle", value = true})
Ahri.D:MenuElement({id = "Dmg", name = "Damage HP bar", value = true})

Ahri.A:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
Ahri.A.CS:MenuElement({id = "Blind", name = "Blind", value = false})
Ahri.A.CS:MenuElement({id = "Charm", name = "Charm", value = true})
Ahri.A.CS:MenuElement({id = "Flee", name = "Flee", value = true})
Ahri.A.CS:MenuElement({id = "Slow", name = "Slow", value = false})
Ahri.A.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
Ahri.A.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
Ahri.A.CS:MenuElement({id = "Silence", name = "Silence", value = true})
Ahri.A.CS:MenuElement({id = "Stun", name = "Stun", value = true})
Ahri.A.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
Ahri.A:MenuElement({type = MENU, id = "P", name = "Potions"})
Ahri.A.P:MenuElement({id = "Pot", name = "All Potions", value = true})
Ahri.A.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
Ahri.A:MenuElement({type = MENU, id = "I", name = "Items"})
Ahri.A.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
Ahri.A.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
Ahri.A.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
Ahri.A.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
Ahri.A.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
Ahri.A.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
Ahri.A.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
Ahri.A.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
Ahri.A.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
Ahri.A.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
Ahri.A.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
Ahri.A.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
Ahri.A.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
Ahri.A.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
Ahri.A.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
Ahri.A.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
Ahri.A.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
Ahri.A.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
Ahri.A.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
Ahri.A.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
Ahri.A.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
Ahri.A.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})

Ahri.A:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
		Ahri.A.S:MenuElement({id = "Smite", name = "Combo Smite", value = true})
		Ahri.A.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		Ahri.A.S:MenuElement({id = "Heal", name = "Heal", value = true})
		Ahri.A.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		Ahri.A.S:MenuElement({id = "Barrier", name = "Barrier", value = true})
		Ahri.A.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
		Ahri.A.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
		Ahri.A.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		Ahri.A.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true})
	end
end, 2)

Callback.Add("Tick", function() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function Tick()
    if Game.IsChatOpen() then return end
    local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	elseif Mode == "Clear" then
		Clear()
	elseif Mode == "Harass" then
        Harass()
    elseif Mode == "Flee" then
        Flee()
    end
        Killsteal()
        AutoCast()
        Activator()
        AutoLevel()
end

function AutoLevel()
    if Ahri.L.Enabled:Value() == false then return end
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
    local Check = Sequence[Ahri.L.Order:Value()][level - SkillPoints + 1]
    if SkillPoints > 0 then
        if Ahri.L.Block:Value() and level == 1 then return end
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

function Combo()
    if MP(myHero) < Ahri.MM.C:Value() then return end
    local target = GetTarget(1050)
    if target == nil then return end
    if Ready(_R) and ValidTarget(target, 1050) then
        if myHero:GetSpellData(_R).castTime > 10 and Ahri.C.Ra:Value() then return end
        if Ahri.C.R:Value() and Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) * 2 > target.health then
            if target.distance > 600 then
				EnableOrb(false)
				Control.CastSpell(HK_R, pos)
				DelayAction(function() EnableOrb(true) end, 0.2) 
			else
				local c1, c2, r1, r2 = Vector(myHero.pos), Vector(target.pos), myHero.range, 525 
				local O1, O2 = CircleCircleIntersection(c1, c2, r1, r2) 
				if O1 or O2 then
					local pos = c1:Extended(Vector(ClosestToMouse(O1, O2)), 425)
					EnableOrb(false)
					Control.CastSpell(HK_R, pos)
					DelayAction(function() EnableOrb(true) end, 0.2) 
				end
			end
        end
    end
    if Ready(_E) and ValidTarget(target, E.Range) and Ahri.C.E:Value() and target:GetCollision(Q.Width, Q.Speed, Q.Speed) == 0 then
        if IsFacing(target) == false and (E.Range - target.distance)/target.ms < (E.Range/E.Speed) + E.Delay then return end
        EnableOrb(false)
        PredCast(HK_E, E, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Ahri.C.Q:Value() then
        if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
        EnableOrb(false)
        PredCast(HK_Q, Q, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_W) and ValidTarget(target, W.Range) and Ahri.C.W:Value() then
        Control.CastSpell(HK_W)
    end
end

function Clear()
	if Ahri.K.Clear:Value() == false then return end
    if Ahri.MM.LC:Value() > MP(myHero) then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 - myHero.team then
            if Ready(_Q) and ValidTarget(minion, Q.Range) and Ahri.LC.Q:Value() and minion:GetCollision(Q.Width, Q.Speed, Q.Speed) >= Ahri.LC.Qx:Value() then
				EnableOrb(false)
				PredCast(HK_Q, Q, minion, TYPE_LINE)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
            if Ready(_W) and ValidTarget(minion, W.Range) and Ahri.LC.W:Value() and MinionsAround(myHero.pos, 700, 300 - myHero.team) >= Ahri.LC.Wx:Value() then
				Control.CastSpell(HK_W)
			end
        elseif minion and minion.team == 300 then
            if Ready(_Q) and ValidTarget(minion, Q.Range) and Ahri.LC.Q:Value() then
				EnableOrb(false)
				PredCast(HK_Q, Q, minion, TYPE_LINE)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
            if Ready(_W) and ValidTarget(minion, W.Range) and Ahri.LC.W:Value() then
                Control.CastSpell(HK_W)
            end
            if Ready(_E) and ValidTarget(minion, E.Range) and Ahri.LC.E:Value() then
                EnableOrb(false)
				PredCast(HK_E, E, minion, TYPE_LINE)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
        end
    end
end

function Harass()
    if Ahri.K.Harass:Value() == false then return end
    if MP(myHero) < Ahri.MM.H:Value() then return end
    local target = GetTarget(975)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) and Ahri.H.E:Value() and target:GetCollision(Q.Width, Q.Speed, Q.Speed) == 0 then
        if IsFacing(target) == false and (E.Range - target.distance)/target.ms < (E.Range/E.Speed) + E.Delay then return end
        EnableOrb(false)
        PredCast(HK_E, E, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Ahri.H.Q:Value() then
        if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
        EnableOrb(false)
        PredCast(HK_Q, Q, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_W) and ValidTarget(target, W.Range) and Ahri.H.W:Value() then
        Control.CastSpell(HK_W)
    end
end

function Killsteal()
    if MP(myHero) < Ahri.MM.KS:Value() then return end
    if IsRecalling() and Ahri.KS.RC:Value() then return end
    local target = GetTarget(975)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) and Ahri.KS.E:Value() and Edmg(target) > target.health and target:GetCollision(Q.Width, Q.Speed, Q.Speed) == 0 then
        if IsFacing(target) == false and (E.Range - target.distance)/target.ms < (E.Range/E.Speed) + E.Delay then return end
        EnableOrb(false)
        PredCast(HK_E, E, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Ahri.KS.Q:Value() and Qdmg(target) > target.health then
        if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
        EnableOrb(false)
        PredCast(HK_Q, Q, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
end

function AutoCast()
    if MP(myHero) < Ahri.MM.A:Value() then return end
    local target = GetTarget(975)
    if target == nil then return end
    for i = 1, Game.HeroCount() do
		local enemy = Game.Hero(i)
        if enemy and enemy.team == 300 - myHero.team then
            if Ready(_E) and ValidTarget(enemy, E.Range) and Ahri.AU.Eg:Value() and target:GetCollision(Q.Width, Q.Speed, Q.Speed) == 0 then
                if enemy.ms > 700 and myHero.pos:DistanceTo(enemy.pos) < 300 then
                    EnableOrb(false)
                    PredCast(HK_E, E, target, TYPE_LINE)
                    DelayAction(function() EnableOrb(true) end, 0.2)
                end
            end
        end
    end
    if Ready(_E) and ValidTarget(target, E.Range) and Ahri.AU.E:Value() and target:GetCollision(Q.Width, Q.Speed, Q.Speed) == 0 then
        if IsFacing(target) == false and (E.Range - target.distance)/target.ms < (E.Range/E.Speed) + E.Delay then return end
        EnableOrb(false)
        PredCast(HK_E, E, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Ahri.AU.Q:Value() then
        for i = 0, target.buffCount do
            local buff = target:GetBuff(i)
            if buff and (buff.type == 5 or buff.type == 8 or buff.type == 9  or buff.type == 11 or buff.type == 21 or buff.type == 22 or buff.type == 28 or buff.type == 29 or buff.type == 24 or buff.name == "recall") and buff.count > 0 then
                if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
                EnableOrb(false)
                PredCast(HK_Q, Q, target, TYPE_LINE)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        end
    end
end

function Flee()
    if MP(myHero) < Ahri.MM.F:Value() then return end
    local target = GetTarget(1575)
    if target == nil then return end
    if Ready(_E) and ValidTarget(target, E.Range) and Ahri.F.E:Value() and target:GetCollision(Q.Width, Q.Speed, Q.Speed) == 0 then
        if IsFacing(target) == false and (E.Range - target.distance)/target.ms < (E.Range/E.Speed) + E.Delay then return end
        EnableOrb(false)
        PredCast(HK_E, E, target, TYPE_LINE)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_Q) and Ahri.F.Q:Value() then
        local Vec = Vector(myHero.pos):Normalized() * - (myHero.boundingRadius*1.1)
        Control.CastSpell(HK_Q, Vec)
    end
    if Ready(_R) and Ahri.F.Ralue() then
        if myHero:GetSpellData(_R).castTime > 10 and Ahri.F.Ra:Value() then return end
        Control.CastSpell(HK_R)
    end
end

function Activator()
	local target = GetTarget(1575)
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Banner = items[3060]
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and Ahri.A.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and Ahri.A.P.Pot:Value() and HP(myHero) < Ahri.A.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and Ahri.A.D.Face:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and Ahri.A.D.Garg:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and Ahri.A.U.Red:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and Ahri.A.D.SE:Value() and HP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and Ahri.A.D.Locket:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and Ahri.A.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and HP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if Ahri.A.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and HP(myHero) < Ahri.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and HP(myHero) < Ahri.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if Ahri.A.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and HP(myHero) < Ahri.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and HP(myHero) < Ahri.A.S.BarrierHP:Value() then
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
					if ((buff.type == 5 and Ahri.A.CS.Stun:Value())
					or (buff.type == 7 and  Ahri.A.CS.Silence:Value())
					or (buff.type == 8 and  Ahri.A.CS.Taunt:Value())
					or (buff.type == 9 and  Ahri.A.CS.Poly:Value())
					or (buff.type == 10 and  Ahri.A.CS.Slow:Value())
					or (buff.type == 11 and  Ahri.A.CS.Root:Value())
					or (buff.type == 21 and  Ahri.A.CS.Flee:Value())
					or (buff.type == 22 and  Ahri.A.CS.Charm:Value())
					or (buff.type == 25 and  Ahri.A.CS.Blind:Value())
					or (buff.type == 28 and  Ahri.A.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and Ahri.A.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and Ahri.A.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and Ahri.A.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and Ahri.A.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and Ahri.A.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and Ahri.A.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and Ahri.A.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and Ahri.A.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and Ahri.A.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and Ahri.A.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and Ahri.A.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and Ahri.A.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and Ahri.A.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and Ahri.A.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and Ahri.A.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if Ahri.A.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + RSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + BSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Ahri.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if Ahri.A.S.Ignite:Value() then
				local IgDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + Idmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and IgDamage > target.health
				and myHero.pos:DistanceTo(target.pos) < 600 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			if Ahri.A.S.Exh:Value() then
				local Damage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and Ready(SUMMONER_1) and Damage > target.health
				and myHero.pos:DistanceTo(target.pos) < 650 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and Ready(SUMMONER_2) and Damage > target.health
				and myHero.pos:DistanceTo(target.pos) < 650 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
	end
end

function Drawings()
    if myHero.dead then return end
	if Ahri.D.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 222, 255)) end
    if Ahri.D.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 255, 200, 000)) end
	if Ahri.D.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 246, 000, 255)) end
	if Ahri.D.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 000, 043, 255)) end
	if Ahri.D.T:Value() then
		local textPosC = myHero.pos:To2D()
		if Ahri.K.Clear:Value() then
			Draw.Text("Clear: On", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
		local textPosH = myHero.pos:To2D()
		if Ahri.K.Harass:Value() then
			Draw.Text("Harass: On", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if Ahri.D.Dmg:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead and enemy.visible then
				local barPos = enemy.hpBar
				local health = enemy.health
				local maxHealth = enemy.maxHealth
				local Qdmg = Qdmg(enemy)
				local Wdmg = Wdmg(enemy)
				local Edmg = Edmg(enemy)
				local Rdmg = Rdmg(enemy)
				local Damage = Qdmg + Wdmg + Edmg + Rdmg
				if Damage < health then
					Draw.Rect(barPos.x + (((health - Qdmg) / maxHealth) * 100), barPos.y, (Qdmg / maxHealth )*100, 10, Draw.Color(170, 000, 222, 255))
					Draw.Rect(barPos.x + (((health - (Qdmg + Wdmg)) / maxHealth) * 100), barPos.y, (Wdmg / maxHealth )*100, 10, Draw.Color(170, 255, 200, 000))
					Draw.Rect(barPos.x + (((health - (Qdmg + Wdmg + Edmg)) / maxHealth) * 100), barPos.y, (Edmg / maxHealth )*100, 10, Draw.Color(170, 246, 000, 255))
					Draw.Rect(barPos.x + (((health - (Qdmg + Wdmg + Edmg + Rdmg)) / maxHealth) * 100), barPos.y, (Rdmg / maxHealth )*100, 10, Draw.Color(170, 000, 043, 255))
				else
    				Draw.Rect(barPos.x, barPos.y, (health / maxHealth ) * 100, 10, Draw.Color(170, 000, 255, 000))
				end
			end
		end
	end
end
