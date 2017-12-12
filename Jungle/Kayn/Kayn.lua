if myHero.charName ~= "Kayn" then return end

require "DamageLib"
require "MapPositionGOS"
require "Eternal Prediction"

local Q = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e0/Reaping_Slash.png", Name = "Reaping Slash", Range = 350, Delay = 0.25, Speed = 500, Width = 175}
local W = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6d/Blade%27s_Reach.png", Name = "Blade's Reach", Range = 700, SRange = 900, Delay = 0.25, Speed = 500, Width = 125}
local E = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/d4/Shadow_Step.png", Name = "Shadow Step"}
local R = { Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/8d/Umbral_Trespass.png", Name = "Umbral Trespass", Range = 550, SRange = 750}

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

local function PredCast(hotkey,slot,target,predmode,rangee)
	local data = { range = rangee, delay = slot.Delay, speed = slot.Speed, width = slot.Width }
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

local Kayn = MenuElement({type = MENU, id = "Kayn", name = "Bronzillian Kayn"})

Kayn:MenuElement({leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/dd/Kayn_OriginalCircle.png", name = "Bronzillian Kayn", drop = {"1.0"}})
Kayn:MenuElement({id = "Form", name = "Kayn form", drop = {"Base","Rhaast","Shadow Assassin"}})
Kayn:MenuElement({leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/9b/Champ_Mastery_S3b.png", name = " ", drop = {"Core"}})
Kayn:MenuElement({type = MENU, id = "C", name = "Combo"})
Kayn:MenuElement({type = MENU, id = "H", name = "Harass"})
Kayn:MenuElement({type = MENU, id = "LC", name = "Clear"})
Kayn:MenuElement({type = MENU, id = "KS", name = "Killsteal"})
Kayn:MenuElement({type = MENU, id = "F", name = "Flee"})
Kayn:MenuElement({type = MENU, id = "AU", name = "Auto"})
Kayn:MenuElement({leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/0a/Classic_Ward.png", name = " ", drop = {"Utility"}})
Kayn:MenuElement({type = MENU, id = "A", name = "Activator"})
Kayn:MenuElement({type = MENU, id = "L", name = "Leveler"})
Kayn:MenuElement({type = MENU, id = "MM", name = "Mana Manager"})
Kayn:MenuElement({type = MENU, id = "K", name = "Keys"})
Kayn:MenuElement({type = MENU, id = "D", name = "Drawings"})

Kayn.C:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true, leftIcon = Q.Icon})
Kayn.C:MenuElement({id = "W", name = "W - " ..W.Name, value = true, leftIcon = W.Icon})
Kayn.C:MenuElement({id = "R", name = "R - " ..R.Name, value = true, leftIcon = R.Icon})

Kayn.H:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true, leftIcon = Q.Icon})
Kayn.H:MenuElement({id = "W", name = "W - " ..W.Name, value = true, leftIcon = W.Icon})

Kayn.LC:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true, leftIcon = Q.Icon})
Kayn.LC:MenuElement({id = "Qx", name = "Minions Hit by Q", value = 5, min = 1, max = 7})
Kayn.LC:MenuElement({id = "W", name = "W - " ..W.Name, value = true, leftIcon = W.Icon})
Kayn.LC:MenuElement({id = "Wx", name = "Minions Hit by W", value = 5, min = 1, max = 7})
Kayn.LC:MenuElement({name = " ", drop = {"Minions manager for lane only"}})

Kayn.KS:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true, leftIcon = Q.Icon})
Kayn.KS:MenuElement({id = "W", name = "W - " ..W.Name, value = true, leftIcon = W.Icon})
Kayn.KS:MenuElement({id = "R", name = "R - " ..R.Name, value = true, leftIcon = R.Icon})
Kayn.KS:MenuElement({id = "RC", name = "Dont KS if recalling", value = true})

Kayn.F:MenuElement({id = "Q", name = "Q - " ..Q.Name, value = true, leftIcon = Q.Icon})
Kayn.F:MenuElement({id = "E", name = "E - " ..E.Name, value = true, leftIcon = E.Icon})

Kayn.L:MenuElement({id = "Enabled", name = "Auto Level Up", value = true})
Kayn.L:MenuElement({id = "Block", name = "1st Level Block", value = true})
Kayn.L:MenuElement({id = "Order", name = "Leveler Sequence", drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

Kayn.MM:MenuElement({id = "C", name = "Mana % to Combo", value = 0, min = 0, max = 100})
Kayn.MM:MenuElement({id = "H", name = "Mana % to Harass", value = 60, min = 0, max = 100})
Kayn.MM:MenuElement({id = "LC", name = "Mana % to Clear", value = 55, min = 0, max = 100})
Kayn.MM:MenuElement({id = "KS", name = "Mana % to Killsteal", value = 0, min = 0, max = 100})
Kayn.MM:MenuElement({id = "F", name = "Mana % to Flee", value = 5, min = 0, max = 100})

Kayn.K:MenuElement({id = "Clear", name = "Spell Clear", key = string.byte("A"), toggle = true})
Kayn.K:MenuElement({id = "Harass", name = "Spell Harass", key = string.byte("S"), toggle = true})

Kayn.D:MenuElement({id = "Q", name = "Q - "..Q.Name, value = true})
Kayn.D:MenuElement({id = "W", name = "W - "..W.Name, value = true})
Kayn.D:MenuElement({id = "R", name = "R - "..R.Name, value = true})
Kayn.D:MenuElement({id = "T", name = "Spell Toggle", value = true})
Kayn.D:MenuElement({id = "Dmg", name = "Damage HP bar", value = true})

Kayn.A:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
Kayn.A.CS:MenuElement({id = "Blind", name = "Blind", value = false})
Kayn.A.CS:MenuElement({id = "Charm", name = "Charm", value = true})
Kayn.A.CS:MenuElement({id = "Flee", name = "Flee", value = true})
Kayn.A.CS:MenuElement({id = "Slow", name = "Slow", value = false})
Kayn.A.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
Kayn.A.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
Kayn.A.CS:MenuElement({id = "Silence", name = "Silence", value = true})
Kayn.A.CS:MenuElement({id = "Stun", name = "Stun", value = true})
Kayn.A.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
Kayn.A:MenuElement({type = MENU, id = "P", name = "Potions"})
Kayn.A.P:MenuElement({id = "Pot", name = "All Potions", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/13/Health_Potion_item.png"})
Kayn.A.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
Kayn.A:MenuElement({type = MENU, id = "I", name = "Items"})
Kayn.A.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
Kayn.A.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Bilgewater_Cutlass_item.png"}) 
Kayn.A.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/69/Edge_of_Night_item.png"})
Kayn.A.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/77/Frost_Queen%27s_Claim_item.png"})
Kayn.A.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e4/Hextech_Revolver_item.png"})
Kayn.A.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6c/Ohmwrecker_item.png"})
Kayn.A.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/9f/Righteous_Glory_item.png"})
Kayn.A.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e3/Tiamat_item.png"})
Kayn.A.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/41/Youmuu%27s_Ghostblade_item.png"})
Kayn.A.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
Kayn.A.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e8/Face_of_the_Mountain_item.png"})
Kayn.A.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bd/Gargoyle_Stoneplate_item.png"})
Kayn.A.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/56/Locket_of_the_Iron_Solari_item.png"})
Kayn.A.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/de/Mikael%27s_Crucible_item.png"})
Kayn.A.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f9/Quicksilver_Sash_item.png"})
Kayn.A.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/08/Randuin%27s_Omen_item.png"})
Kayn.A.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b9/Seraph%27s_Embrace_item.png"})
Kayn.A.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
Kayn.A.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/9e/Banner_of_Command_item.png"})
Kayn.A.I.U:MenuElement({id = "Red", name = "Redemption", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/94/Redemption_item.png"})
Kayn.A.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/32/Talisman_of_Ascension_item.png"})
Kayn.A.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/fb/Zz%27Rot_Portal_item.png"})

Kayn.A:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
		Kayn.A.S:MenuElement({id = "Smite", name = "Combo Smite", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/05/Smite.png"})
		Kayn.A.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		Kayn.A.S:MenuElement({id = "Heal", name = "Heal", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6e/Heal.png"})
		Kayn.A.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		Kayn.A.S:MenuElement({id = "Barrier", name = "Barrier", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cc/Barrier.png"})
		Kayn.A.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
		Kayn.A.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
		Kayn.A.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"})
	end
end, 2)
DelayAction(function()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		Kayn.A.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/95/Cleanse.png"})
	end
end, 2)

local form = Kayn.Form:Value() -- 1 = base / 2 = rhaast / 3 = shadow assassin

local function Qdmg(target)
    local level = myHero:GetSpellData(_Q).level
    if Ready(_Q) then
        if form ~= 2 then
            return CalcPhysicalDamage(myHero, target, (80 + 40 * level + 1.3 * myHero.bonusDamage))
        else
            return CalcPhysicalDamage(myHero, target, (0.5 * myHero.totalDamage + ((0.05 + (0.04 * myHero.bonusDamage)) * target.maxHealth)))
        end
    end
    return 0
end

local function Wdmg(target)
    local level = myHero:GetSpellData(_W).level
    if Ready(_W) then
        return CalcPhysicalDamage(myHero, target, (45 + 45 * level + 1.2 * myHero.bonusDamage))
    end
    return 0
end

local function Edmg(target)
    return 0
end

local function Rdmg(target)
    local level = myHero:GetSpellData(_R).level
    if Ready(_R) then
        if form ~= 2 then
            return CalcPhysicalDamage(myHero, target, (50 + 100 * level + 1.5 * myHero.bonusDamage))
        else
            return CalcPhysicalDamage(myHero, target, ((0.1 + (0.13 * myHero.bonusDamage)) * target.maxHealth))
        end
    end
    return 0
end

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
        Activator()
        AutoLevel()
end

function AutoLevel()
    if Kayn.L.Enabled:Value() == false then return end
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
    local Check = Sequence[Kayn.L.Order:Value()][level - SkillPoints + 1]
    if SkillPoints > 0 then
        if Kayn.L.Block:Value() and level == 1 then return end
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
    if MP(myHero) < Kayn.MM.C:Value() then return end
    local target = GetTarget(900)
    if target == nil then return end
    if Ready(_R) and Kayn.C.R:Value() and Rdmg(target) + Wdmg(target) + Qdmg(target) > target.health then
        if form ~= 3 then
            if ValidTarget(target, R.Range) then
                Control.CastSpell(HK_R, target)
            end
        else
            if ValidTarget(target, R.SRange) then
                Control.CastSpell(HK_R, target)
            end
        end
    end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Kayn.C.Q:Value() then
        if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
        EnableOrb(false)
        PredCast(HK_Q, Q, target, TYPE_CIRCULAR, Q.Range)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_W) and Kayn.C.W:Value() then
        if form ~= 3 then
            if ValidTarget(target, W.Range) then
                if IsFacing(target) == false and (W.Range - target.distance)/target.ms < (W.Range/W.Speed) + W.Delay then return end
                EnableOrb(false)
                PredCast(HK_W, W, target, TYPE_LINE, W.Range)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        else
            if ValidTarget(target, W.SRange) then
                if IsFacing(target) == false and (W.SRange - target.distance)/target.ms < (W.SRange/W.Speed) + W.Delay then return end
                EnableOrb(false)
                PredCast(HK_W, W, target, TYPE_LINE, W.SRange)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        end
    end
end

function Clear()
	if Kayn.K.Clear:Value() == false then return end
    if Kayn.MM.LC:Value() > MP(myHero) then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 - myHero.team then
            if Ready(_W) and ValidTarget(minion, W.Range) and Kayn.LC.W:Value() and minion:GetCollision(W.Width, W.Speed, W.Delay) >= Kayn.LC.Wx:Value() then
				EnableOrb(false)
				PredCast(HK_W, W, minion, TYPE_LINE, W.Range)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
            if Ready(_Q) and ValidTarget(minion, Q.Range + 175) and Kayn.LC.Q:Value() and minion:GetCollision(100, Q.Speed, Q.Delay) >= Kayn.LC.Qx:Value() then
				EnableOrb(false)
				PredCast(HK_Q, Q, minion, TYPE_LINE, Q.Range)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
        elseif minion and minion.team == 300 then
            if Ready(_Q) and ValidTarget(minion, Q.Range) and Kayn.LC.Q:Value() then
				EnableOrb(false)
				PredCast(HK_Q, Q, minion, TYPE_CIRCULAR, Q.Range)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
            if Ready(_W) and ValidTarget(minion, W.Range) and Kayn.LC.W:Value() then
                EnableOrb(false)
				PredCast(HK_W, W, minion, TYPE_LINE, W.Range)
				DelayAction(function() EnableOrb(true) end, 0.2)
            end
        end
    end
end

function Harass()
    if Kayn.K.Harass:Value() == false then return end
    if MP(myHero) < Kayn.MM.H:Value() then return end
    local target = GetTarget(975)
    if target == nil then return end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Kayn.H.Q:Value() then
        if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
        EnableOrb(false)
        PredCast(HK_Q, Q, target, TYPE_CIRCULAR, Q.Range)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_W) and Kayn.H.W:Value() then
        if form ~= 3 then
            if ValidTarget(target, W.Range) then
                if IsFacing(target) == false and (W.Range - target.distance)/target.ms < (W.Range/W.Speed) + W.Delay then return end
                EnableOrb(false)
                PredCast(HK_W, W, target, TYPE_LINE, W.Range)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        else
            if ValidTarget(target, W.SRange) then
                if IsFacing(target) == false and (W.SRange - target.distance)/target.ms < (W.SRange/W.Speed) + W.Delay then return end
                EnableOrb(false)
                PredCast(HK_W, W, target, TYPE_LINE, W.SRange)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        end
    end
end

function Killsteal()
    if MP(myHero) < Kayn.MM.KS:Value() then return end
    if IsRecalling() and Kayn.KS.RC:Value() then return end
    local target = GetTarget(900)
    if target == nil then return end
    if Ready(_Q) and ValidTarget(target, Q.Range) and Kayn.KS.Q:Value() and Qdmg(target) > target.health then
        if IsFacing(target) == false and (Q.Range - target.distance)/target.ms < (Q.Range/Q.Speed) + Q.Delay then return end
        EnableOrb(false)
        PredCast(HK_Q, Q, target, TYPE_CIRCULAR, Q.Range)
        DelayAction(function() EnableOrb(true) end, 0.2)
    end
    if Ready(_R) and Kayn.KS.R:Value() and Rdmg(target) > target.health then
        if form ~= 3 then
            if ValidTarget(target, R.Range) then
                Control.CastSpell(HK_R, target)
            end
        else
            if ValidTarget(target, R.SRange) then
                Control.CastSpell(HK_R, target)
            end
        end
    end
    if Ready(_W) and Kayn.KS.W:Value() and Wdmg(target) > target.health then
        if form ~= 3 then
            if ValidTarget(target, W.Range) then
                if IsFacing(target) == false and (W.Range - target.distance)/target.ms < (W.Range/W.Speed) + W.Delay then return end
                EnableOrb(false)
                PredCast(HK_W, W, target, TYPE_LINE, W.Range)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        else
            if ValidTarget(target, W.SRange) then
                if IsFacing(target) == false and (W.SRange - target.distance)/target.ms < (W.SRange/W.Speed) + W.Delay then return end
                EnableOrb(false)
                PredCast(HK_W, W, target, TYPE_LINE, W.SRange)
                DelayAction(function() EnableOrb(true) end, 0.2)
            end
        end
    end
end

function Flee()
    if MP(myHero) < Kayn.MM.F:Value() then return end
    if Ready(_Q) and Kayn.F.Q:Value() then
        Control.CastSpell(HK_Q)
	end
	if Ready(_E) and Kayn.F.E:Value() then
		if MapPosition:inWall(cursorPos) and myHero.pos:DistanceTo(cursorPosw) < 200 then
			Control.CastSpell(HK_E)
		end
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
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and Kayn.A.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and Kayn.A.P.Pot:Value() and HP(myHero) < Kayn.A.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and Kayn.A.D.Face:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and Kayn.A.D.Garg:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and Kayn.A.U.Red:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and Kayn.A.D.SE:Value() and HP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and Kayn.A.D.Locket:Value() and HP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and Kayn.A.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and HP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if Kayn.A.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and HP(myHero) < Kayn.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and HP(myHero) < Kayn.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if Kayn.A.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and HP(myHero) < Kayn.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and HP(myHero) < Kayn.A.S.BarrierHP:Value() then
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
					if ((buff.type == 5 and Kayn.A.CS.Stun:Value())
					or (buff.type == 7 and  Kayn.A.CS.Silence:Value())
					or (buff.type == 8 and  Kayn.A.CS.Taunt:Value())
					or (buff.type == 9 and  Kayn.A.CS.Poly:Value())
					or (buff.type == 10 and  Kayn.A.CS.Slow:Value())
					or (buff.type == 11 and  Kayn.A.CS.Root:Value())
					or (buff.type == 21 and  Kayn.A.CS.Flee:Value())
					or (buff.type == 22 and  Kayn.A.CS.Charm:Value())
					or (buff.type == 25 and  Kayn.A.CS.Blind:Value())
					or (buff.type == 28 and  Kayn.A.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and Kayn.A.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and Kayn.A.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and Kayn.A.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and Kayn.A.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and Kayn.A.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and Kayn.A.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and Kayn.A.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and Kayn.A.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and Kayn.A.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and Kayn.A.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and Kayn.A.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and Kayn.A.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and Kayn.A.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and Kayn.A.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and Kayn.A.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if Kayn.A.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + RSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Kayn.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Kayn.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) + BSdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= Kayn.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= Kayn.A.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if Kayn.A.S.Ignite:Value() then
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
			if Kayn.A.S.Exh:Value() then
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
	if Kayn.D.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 222, 255)) end
    if Kayn.D.W:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 255, 200, 000)) end
	if Kayn.D.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 000, 043, 255)) end
	if MapPosition:inBase(myHero.pos) then Draw.Text("REMEMBER TO CHECK YOUR FORM IN MENU", 50, myHero.pos:To2D().x - 360, myHero.pos:To2D().y - 400, Draw.Color(255, 255, 000, 000)) end
	if Kayn.D.T:Value() then
		local textPosC = myHero.pos:To2D()
		if Kayn.K.Clear:Value() then
			Draw.Text("Clear: On", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
		local textPosH = myHero.pos:To2D()
		if Kayn.K.Harass:Value() then
			Draw.Text("Harass: On", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if Kayn.D.Dmg:Value() then
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
