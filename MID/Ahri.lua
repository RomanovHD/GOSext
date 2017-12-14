if myHero.charName ~= "Ahri" then return end

require "DamageLib"

local Q = { Delay = 0.25, Speed = 1700, Width = 80, Range = 880 }
local W = { Delay = 0.25, Speed = math.huge, Width = 0, Range = 700 }
local E = { Delay = 0.25, Speed = 1600, Width = 90, Range = 975 }
local R = { Delay = 0.25, Speed = math.huge, Width = 0, Range = 450 }

local _EnemyHeroes
local function GetEnemyHeroes()
	if _EnemyHeroes then return _EnemyHeroes end
	_EnemyHeroes = {}
	for i = 1, Game.HeroCount() do
		local unit = Game.Hero(i)
		if unit.isEnemy then
			table.insert(_EnemyHeroes, unit)
		end
	end
	return _EnemyHeroes
end

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 
end

local function IsImmune(unit)
    for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then 
            return true
        end
    end
    return false
end

local function IsValidTarget(target, range)
	range = range and range or math.huge
	return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range and IsImmune(target) == false
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
	if _G.EOWLoaded then
		target = EOW:GetTarget(range)
	elseif _G.SDK and _G.SDK.Orbwalker then 
		target = _G.SDK.TargetSelector:GetTarget(range)
	else
		target = _G.GOS:GetTarget(range)
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
			return "LastHit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
	else
		return GOS:GetMode()
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

local function Qdmg(target)
    local level = myHero:GetSpellData(_Q).level
	if Ready(_Q) then
    	return CalcMagicalDamage(myHero, target, (15 + 25*level + 0.35*myHero.ap))
	end
	return 0
end

local function Qmana()
    local level = myHero:GetSpellData(_Q).level
	if Ready(_Q) then
    	return 60 + 5 * level
	end
	return 0
end

local function Wdmg(target)
    local level = myHero:GetSpellData(_W).level
	if Ready(_W) then
    	return CalcMagicalDamage(myHero, target, (24 + 40*level + 0.48*myHero.ap))
	end
	return 0
end

local function Wmana()
	if Ready(_W) then
    	return 50
	end
	return 0
end

local function Edmg(target)
    local level = myHero:GetSpellData(_E).level
	if Ready(_E) then
        local firstmine = CalcMagicalDamage(myHero, target, (25 + 35*level + 0.6*myHero.ap))
    	return firstmine + (firstmine * 0.4) * 2
	end
	return 0
end

local function Emana()
	if Ready(_E) then
    	return 85
	end
	return 0
end

local function Rdmg(target)
    local level = myHero:GetSpellData(_R).level
	if Ready(_R) then
    	return CalcMagicalDamage(myHero, target, (90 + 120*level + 0.75*myHero.ap))
	end
	return 0
end

local function Rmana()
	if Ready(_R) then
    	return 100
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
    return p1:DistanceTo(p2)
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
function IsFacing(target)
    local V = Vector((target.pos - myHero.pos))
    local D = Vector(target.dir)
    local Angle = 180 - deg(acos(V*D/(V:Len()*D:Len())))
    if abs(Angle) < 80 then 
        return true  
    end
    return false
end

function Hitchance(target)
    for i = 0, target.buffCount do
		local buff = target:GetBuff(i)
        if buff.count > 0 then
            if (buff.type == 5 or buff.type == 8 or buff.type == 11 or buff.type == 18 or buff.type == 22 or buff.type == 24 or buff.type == 28 or buff.type == 29 or buff.type == 31) then
                return 4
            elseif (buff.type == 9 or buff.type == 10 or buff.type == 19 or buff.type == 21 or buff.type == 30) then
                return 3
            end
        end
    end
    if target.attackData.state == STATE_ATTACK or target.attackData.state == STATE_WINDUP then
      return 3
    end
    if target.distance < 600 then
        return 3
    end
    if target.ms > 400 then
        return 1
    end
    return 2
end

function IsCharmed(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.count > 0 then
			if buff.type == 22 then
				return true
			end
		end
	end
	return false
end

function IsUnderTurret(unit)
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if turret.isEnemy and not turret.dead then
            if turret.pos:DistanceTo(unit.pos) < range then
                return true
            end
        end
    end
    return false
end

--// Menu
local Icon = { Q = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/19/Orb_of_Deception.png",
    W = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a8/Fox-Fire.png",
    E = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/04/Charm.png",
    R = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/86/Spirit_Rush.png"}

local Ahri = MenuElement({type = MENU, id = "Ahri", name = "Ahri lost in Disney World"})

Ahri:MenuElement({id = "Script", name = "Ahri", drop = {"lost in Disney World v1"}})
Ahri:MenuElement({name = " ", drop = {"Champion Core"}})
Ahri:MenuElement({type = MENU, id = "C", name = "Combo"})
Ahri:MenuElement({type = MENU, id = "H", name = "Harass"})
Ahri:MenuElement({type = MENU, id = "LC", name = "LaneClear"})
Ahri:MenuElement({type = MENU, id = "F", name = "Flee"})
Ahri:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
Ahri:MenuElement({type = MENU, id = "D", name = "Drawings"})
Ahri:MenuElement({name = " ", drop = {"Extra Utility"}})
Ahri:MenuElement({type = MENU, id = "A", name = "Activator"})
Ahri:MenuElement({type = MENU, id = "Lv", name = "Auto Leveler"})

Ahri.C:MenuElement({id = "useQ", name = "Q: Orb of Deception", value = true, leftIcon = Icon.Q})
    Ahri.C:MenuElement({id = "Q", name = "Q - Settings", type = MENU})
    Ahri.C.Q:MenuElement({id = "landE", name = "Use after E landing", value = true})
    Ahri.C.Q:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 2})
Ahri.C:MenuElement({id = "useW", name = "W: Fox-Fire", value = true, leftIcon = Icon.W})  
Ahri.C:MenuElement({id = "useE", name = "E: Charm", value = true, leftIcon = Icon.E})
    Ahri.C:MenuElement({id = "E", name = "E - Settings", type = MENU})
    Ahri.C.E:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 3})
Ahri.C:MenuElement({id = "useR", name = "R: Spirit Rush", value = true, leftIcon = Icon.R})

Ahri.H:MenuElement({id = "useQ", name = "Q: Orb of Deception", value = true, leftIcon = Icon.Q})
    Ahri.H:MenuElement({id = "Q", name = "Q - Settings", type = MENU})
    Ahri.H.Q:MenuElement({id = "landE", name = "Use after E landing", value = true})
    Ahri.H.Q:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 2})
    Ahri.H.Q:MenuElement({id = "Mana", name = "Min mana %", value = 50, min = 0, max = 100})
Ahri.H:MenuElement({id = "useW", name = "W: Fox-Fire", value = true, leftIcon = Icon.W})
	Ahri.H:MenuElement({id = "W", name = "W - Settings", type = MENU})	
	Ahri.H.W:MenuElement({id = "Mana", name = "Min mana %", value = 70, min = 0, max = 100})
Ahri.H:MenuElement({id = "useE", name = "E: Charm", value = true, leftIcon = Icon.E})
    Ahri.H:MenuElement({id = "E", name = "E - Settings", type = MENU})
    Ahri.H.E:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 3})
    Ahri.H.E:MenuElement({id = "Mana", name = "Min mana %", value = 60, min = 0, max = 100})
Ahri.H:MenuElement({id = "Key", name = "Enable Spell Harass", key = string.byte("S"), toggle = true})

Ahri.LC:MenuElement({id = "useQ", name = "Q: Orb of Deception", value = true, leftIcon = Icon.Q})
    Ahri.LC:MenuElement({id = "Q", name = "Q - Settings", type = MENU})
    Ahri.LC.Q:MenuElement({id = "X", name = "Min minions [Lane]", value = 5, min = 1, max = 7})
    Ahri.LC.Q:MenuElement({id = "H", name = "Merge Clear with Harass", value = true})
    Ahri.LC.Q:MenuElement({id = "J", name = "Use against Jungle", value = true})
    Ahri.LC.Q:MenuElement({id = "Mana", name = "Min mana %", value = 30, min = 0, max = 100})
Ahri.LC:MenuElement({id = "useW", name = "W: Fox-Fire", value = true, leftIcon = Icon.W})
    Ahri.LC:MenuElement({id = "W", name = "W - Settings", type = MENU})
    Ahri.LC.W:MenuElement({id = "X", name = "Min minions [Lane]", value = 3, min = 1, max = 3})
    Ahri.LC.W:MenuElement({id = "H", name = "Merge Clear with Harass", value = true})
    Ahri.LC.W:MenuElement({id = "J", name = "Use against Jungle", value = true})
    Ahri.LC.W:MenuElement({id = "Mana", name = "Min mana %", value = 50, min = 0, max = 100})
Ahri.LC:MenuElement({id = "useE", name = "E: Charm", value = true, leftIcon = Icon.E})
    Ahri.LC:MenuElement({id = "E", name = "E - Settings", type = MENU})
    Ahri.LC.E:MenuElement({id = "S", name = "Lasthit Siege out of AA range", value = true})
    Ahri.LC.E:MenuElement({id = "H", name = "Merge Clear with Harass", value = true})
    Ahri.LC.E:MenuElement({id = "J", name = "Use against Jungle", value = true})
    Ahri.LC.E:MenuElement({id = "Mana", name = "Min mana %", value = 80, min = 0, max = 100})
Ahri.LC:MenuElement({id = "Key", name = "Enable Spell Clear", key = string.byte("A"), toggle = true})

Ahri.F:MenuElement({id = "useQ", name = "Q: Orb of Deception", value = true, leftIcon = Icon.Q})
    Ahri.F:MenuElement({id = "Q", name = "Q - Settings", type = MENU})
    Ahri.F.Q:MenuElement({id = "Mana", name = "Min mana %", value = 30, min = 0, max = 100})
Ahri.F:MenuElement({id = "useE", name = "E: Charm", value = true, leftIcon = Icon.E})
    Ahri.F:MenuElement({id = "E", name = "E - Settings", type = MENU})
    Ahri.F.E:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 2})
    Ahri.F.E:MenuElement({id = "Mana", name = "Min mana %", value = 30, min = 0, max = 100})

Ahri.KS:MenuElement({id = "useQ", name = "Q: Orb of Deception", value = true, leftIcon = Icon.Q})
    Ahri.KS:MenuElement({id = "Q", name = "Q - Settings", type = MENU})
    Ahri.KS.Q:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 2})
    Ahri.KS.Q:MenuElement({id = "Mana", name = "Min mana %", value = 20, min = 0, max = 100})
Ahri.KS:MenuElement({id = "useE", name = "E: Charm", value = true, leftIcon = Icon.E})
    Ahri.KS:MenuElement({id = "E", name = "E - Settings", type = MENU})
    Ahri.KS.E:MenuElement({id = "Hit", name = "Hitchance", drop = {"Low","Normal","High","Very High"}, value = 2})
    Ahri.KS.E:MenuElement({id = "Mana", name = "Min mana %", value = 30, min = 0, max = 100})
Ahri.KS:MenuElement({id = "Recall", name = "Disable While Recalling", value = true})

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
Ahri.A.P:MenuElement({id = "Pot", name = "All Potions", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/13/Health_Potion_item.png"})
Ahri.A.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
Ahri.A:MenuElement({type = MENU, id = "I", name = "Items"})
Ahri.A.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
Ahri.A.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Bilgewater_Cutlass_item.png"}) 
Ahri.A.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/69/Edge_of_Night_item.png"})
Ahri.A.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/77/Frost_Queen%27s_Claim_item.png"})
Ahri.A.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e4/Hextech_Revolver_item.png"})
Ahri.A.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6c/Ohmwrecker_item.png"})
Ahri.A.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/9f/Righteous_Glory_item.png"})
Ahri.A.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e3/Tiamat_item.png"})
Ahri.A.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/41/Youmuu%27s_Ghostblade_item.png"})
Ahri.A.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
Ahri.A.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e8/Face_of_the_Mountain_item.png"})
Ahri.A.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bd/Gargoyle_Stoneplate_item.png"})
Ahri.A.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/56/Locket_of_the_Iron_Solari_item.png"})
Ahri.A.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/de/Mikael%27s_Crucible_item.png"})
Ahri.A.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f9/Quicksilver_Sash_item.png"})
Ahri.A.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/08/Randuin%27s_Omen_item.png"})
Ahri.A.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b9/Seraph%27s_Embrace_item.png"})
Ahri.A.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
Ahri.A.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/9e/Banner_of_Command_item.png"})
Ahri.A.I.U:MenuElement({id = "Red", name = "Redemption", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/94/Redemption_item.png"})
Ahri.A.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/32/Talisman_of_Ascension_item.png"})
Ahri.A.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/fb/Zz%27Rot_Portal_item.png"})

Ahri.A:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
		Ahri.A.S:MenuElement({id = "Smite", name = "Combo Smite", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/05/Smite.png"})
		Ahri.A.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		Ahri.A.S:MenuElement({id = "Heal", name = "Heal", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6e/Heal.png"})
		Ahri.A.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		Ahri.A.S:MenuElement({id = "Barrier", name = "Barrier", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cc/Barrier.png"})
		Ahri.A.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
		Ahri.A.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"})
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
		Ahri.A.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"})
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
		Ahri.A.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/95/Cleanse.png"})
	end

Ahri.D:MenuElement({id = "useQ", name = "Q: Orb of Deception", value = true, leftIcon = Icon.Q})
Ahri.D:MenuElement({id = "useW", name = "W: Fox-Fire", value = true, leftIcon = Icon.W})
Ahri.D:MenuElement({id = "useE", name = "E: Charm", value = true, leftIcon = Icon.E})
Ahri.D:MenuElement({id = "useR", name = "R: Spirit Rush", value = true, leftIcon = Icon.R})
Ahri.D:MenuElement({id = "T", name = "Spell Toggle", value = true})
Ahri.D:MenuElement({id = "D", name = "Damage by %", value = true})

Ahri.Lv:MenuElement({id = "Enabled", name = "Enable", value = true})
Ahri.Lv:MenuElement({id = "Block", name = "Block on Level 1", value = true})
Ahri.Lv:MenuElement({id = "Order", name = "Skill Priority", value = 2, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

--// script
Callback.Add("Tick", function() AutoLevel() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function AutoLevel()
	if Ahri.Lv.Enabled:Value() == false then return end
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
	local Check = Sequence[Ahri.Lv.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if Ahri.Lv.Block:Value() and level == 1 then return end
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
    elseif Mode == "Flee" then
        Flee()
	end
		Killsteal()
        Activator()
end

local _OnVision = {}
function OnVision(unit)
	if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {state = unit.visible , tick = GetTickCount(), pos = unit.pos} end
	if _OnVision[unit.networkID].state == true and not unit.visible then _OnVision[unit.networkID].state = false _OnVision[unit.networkID].tick = GetTickCount() end
	if _OnVision[unit.networkID].state == false and unit.visible then _OnVision[unit.networkID].state = true _OnVision[unit.networkID].tick = GetTickCount() end
	return _OnVision[unit.networkID]
end
Callback.Add("Tick", function() OnVisionF() end)
local visionTick = GetTickCount()
function OnVisionF()
	if GetTickCount() - visionTick > 100 then
		for i,v in pairs(GetEnemyHeroes()) do
			OnVision(v)
		end
	end
end

local _OnWaypoint = {}
function OnWaypoint(unit)
	if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo , speed = unit.ms, time = Game.Timer()} end
	if _OnWaypoint[unit.networkID].pos ~= unit.posTo then 
		-- print("OnWayPoint:"..unit.charName.." | "..math.floor(Game.Timer()))
		_OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo , speed = unit.ms, time = Game.Timer()}
			DelayAction(function()
				local time = (Game.Timer() - _OnWaypoint[unit.networkID].time)
				local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
				if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos,_OnWaypoint[unit.networkID].pos) > 200 then
					_OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
					-- print("OnDash: "..unit.charName)
				end
			end,0.05)
	end
	return _OnWaypoint[unit.networkID]
end

local function GetPred(unit,speed,delay,sourcePos)
	local speed = speed or math.huge
	local delay = delay or 0.25
	local sourcePos = sourcePos or myHero.pos
	local unitSpeed = unit.ms
	if OnWaypoint(unit).speed > unitSpeed then unitSpeed = OnWaypoint(unit).speed end
	if OnVision(unit).state == false then
		local unitPos = unit.pos + Vector(unit.pos,unit.posTo):Normalized() * ((GetTickCount() - OnVision(unit).tick)/1000 * unitSpeed)
		local predPos = unitPos + Vector(unit.pos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(sourcePos,unitPos)/speed)))
		if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
		return predPos
	else
		if unitSpeed > unit.ms then
			local predPos = unit.pos + Vector(OnWaypoint(unit).startPos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(sourcePos,unit.pos)/speed)))
			if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
			return predPos
		elseif IsImmobileTarget(unit) then
			return unit.pos
		else
			return unit:GetPrediction(speed,delay)
		end
	end
end

local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local function CastSpell(spell,pos,range,delay)
local range = range or math.huge
local delay = delay or 250
local ticker = GetTickCount()

	if castSpell.state == 0 and GetDistance(myHero.pos,pos) < range and ticker - castSpell.casting > delay + Game.Latency() and pos:ToScreen().onScreen then
		castSpell.state = 1
		castSpell.mouse = mousePos
		castSpell.tick = ticker
	end
	if castSpell.state == 1 then
		if ticker - castSpell.tick < Game.Latency() then
			Control.SetCursorPos(pos)
			Control.KeyDown(spell)
			Control.KeyUp(spell)
			castSpell.casting = ticker + delay
			DelayAction(function()
				if castSpell.state == 1 then
					Control.SetCursorPos(castSpell.mouse)
					castSpell.state = 0
				end
			end,Game.Latency()/1000)
		end
		if ticker - castSpell.casting > Game.Latency() then
			Control.SetCursorPos(castSpell.mouse)
			castSpell.state = 0
		end
	end
end

function CastQ(target)
	if Ready(_Q) and castSpell.state == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local qPred = GetPred(target,Q.Speed,Q.Delay + Game.Latency()/1000)
            if GetDistance(myHero.pos,qPred) < Q.Range then
                CastSpell(HK_Q,qPred,Q.Range + 200,250)
            end
        end
	end
end

function CastE(target)
	if Ready(_E) and castSpell.state == 0 and target:GetCollision(E.Width, E.Speed, E.Delay) == 0 then
        if (Game.Timer() - OnWaypoint(target).time < 0.15 or Game.Timer() - OnWaypoint(target).time > 1.0) then
            local ePred = GetPred(target,E.Speed,E.Delay + Game.Latency()/1000)
            if GetDistance(myHero.pos,ePred) < E.Range then
                CastSpell(HK_E,ePred,E.Range + 200,250)
            end
        end
	end
end

function CastR(target)
    if Ready(_R) and castSpell.state == 0 then
        if Qdmg(target) + Wdmg(target) + Edmg(target) + Rdmg(target) > target.health then
			if target.distance > 600 then
				Control.CastSpell(HK_R, target)
			else
				local c1, c2, r1, r2 = Vector(myHero.pos), Vector(target.pos), myHero.range, target.range 
				local O1, O2 = CircleCircleIntersection(c1, c2, r1, r2) 
				if O1 or O2 then
					local pos = c1:Extended(Vector(ClosestToMouse(O1, O2)), R.Range)
					Control.CastSpell(HK_R, pos)
				end
			end
        end
	end
end

function Combo()
    local target = GetTarget(1000)
    if target == nil then return end
    if Ready(_R) and IsValidTarget(target, 1000) and Ahri.C.useR:Value() then
        CastR(target)
    end
	if Ready(_E) and IsValidTarget(target, E.Range) and Ahri.C.useE:Value() and Hitchance(target, E.Range, E.Speed, E.Delay) >= Ahri.C.E.Hit:Value() then
        CastE(target)
    end
	if Ready(_Q) and IsValidTarget(target, Q.Range) and Ahri.C.useQ:Value() and Hitchance(target, Q.Range, Q.Speed, Q.Delay) >= Ahri.C.Q.Hit:Value() then
		if Ahri.C.Q.landE:Value() and not IsCharmed(target) then return end
		CastQ(target)
    end
    if Ready(_W) and IsValidTarget(target, W.Range) and Ahri.C.useW:Value() then
        Control.CastSpell(HK_W)
    end
end

function Harass()
    local target = GetTarget(975)
	if target == nil then return end
	if Ahri.H.Key:Value() then
		if Ready(_E) and IsValidTarget(target, E.Range) and Ahri.H.useE:Value() and Hitchance(target, E.Range, E.Speed, E.Delay) >= Ahri.H.E.Hit:Value() then
			if Ahri.H.E.Mana:Value() > PercentMP(myHero) then return end
			CastE(target)
    	end
		if Ready(_Q) and IsValidTarget(target, Q.Range) and Ahri.H.useQ:Value() and Hitchance(target, Q.Range, Q.Speed, Q.Delay) >= Ahri.H.Q.Hit:Value() then
			if Ahri.H.Q.landE:Value() and not IsCharmed(target) then return end
			if Ahri.H.Q.Mana:Value() > PercentMP(myHero) then return end
			CastQ(target)
    	end
   		if Ready(_W) and IsValidTarget(target, W.Range) and Ahri.H.useW:Value() then
    	    if Ahri.H.W.Mana:Value() > PercentMP(myHero) then return end
			Control.CastSpell(HK_W)
		end
	end
end

function Lane()
	local target = GetTarget(975)
	if Ahri.LC.Key:Value() == false then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 - myHero.team then
            if Ready(_Q) and Ahri.LC.useQ:Value() and IsValidTarget(minion, Q.Range) and Ahri.LC.Q.Mana:Value() < PercentMP(myHero) then
                if minion:GetCollision(Q.Width, Q.Speed, Q.Delay) >= Ahri.LC.Q.X:Value() + 1 then
                    CastQ(minion)
                end
            end
            if Ready(_W) and Ahri.LC.useW:Value() and IsValidTarget(minion, W.Range) and Ahri.LC.W.Mana:Value() < PercentMP(myHero) then
                if MinionsAround(myHero.pos, 700, 300 - myHero.team) >= Ahri.LC.W.X:Value() then
                   	Control.CastSpell(HK_W)
                end
			end
			if Ready(_E) and Ahri.LC.useE:Value() and IsValidTarget(minion, E.Range) and Ahri.LC.E.Mana:Value() < PercentMP(myHero) then
                if minion.charName == "Siege" and Edmg(minion) > minion.health and Ahri.LC.E.S:Value() and GetDistance(myHero.pos,minion) > myHero.range then
                   	CastE(minion)
                end
			end
        end
	end
	if Ready(_Q) and Ahri.LC.useQ:Value() and IsValidTarget(target, Q.Range) and Ahri.LC.Q.Mana:Value() < PercentMP(myHero) then
		if Ahri.LC.Q.H:Value() then
			if target:GetCollision(Q.Width, Q.Speed, Q.Delay) >= Ahri.LC.Q.X:Value() then
				CastQ(target)
			end
		end
	end
	if Ready(_W) and Ahri.LC.useW:Value() and IsValidTarget(target, W.Range) and Ahri.LC.W.Mana:Value() < PercentMP(myHero) then
		if Ahri.LC.W.H:Value() then
			if MinionsAround(myHero.pos, 700, 300 - myHero.team) >= Ahri.LC.W.X:Value() then
				Control.CastSpell(HK_W)
			end
		end
	end
end

function Jungle()
	if Ahri.LC.Key:Value() == false then return end
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
        if minion and minion.team == 300 then
            if Ready(_Q) and Ahri.LC.useQ:Value() and IsValidTarget(minion, Q.Range) and Ahri.LC.Q.Mana:Value() < PercentMP(myHero) then
                if Ahri.LC.Q.J:Value() then
                    CastQ(minion)
                end
            end
            if Ready(_W) and Ahri.LC.useW:Value() and IsValidTarget(minion, W.Range) and Ahri.LC.W.Mana:Value() < PercentMP(myHero) then
                if Ahri.LC.W.J:Value() then
                   	Control.CastSpell(HK_W)
                end
			end
			if Ready(_E) and Ahri.LC.useE:Value() and IsValidTarget(minion, E.Range) and Ahri.LC.E.Mana:Value() < PercentMP(myHero) then
                if Ahri.LC.E.J:Value() then
                   	CastE(minion)
                end
			end
        end
    end
end

function Flee()
    local target = GetTarget(E.Range)
    if target and Ready(_E) and IsValidTarget(target, E.Range) and Ahri.F.useE:Value() and Hitchance(target, E.Range, E.Speed, E.Delay) >= Ahri.F.E.Hit:Value() then
		if Ahri.F.E.Mana:Value() > PercentMP(myHero) then return end
		CastE(target)
	end
	if Ready(_Q) and Ahri.F.useQ:Value() then
		if Ahri.F.Q.Mana:Value() > PercentMP(myHero) then return end
		local qFlee = myHero.pos:Extend(cursorPos, -880)
		Control.CastSpell(HK_Q, qFlee)
	end
end

function Killsteal()
    local target = GetTarget(E.Range)
    if target == nil then return end
    if Ready(_E) and IsValidTarget(target, E.Range) and Edmg(target) > target.health and Ahri.KS.useE:Value() and Hitchance(target, E.Range, E.Speed, E.Delay) >= Ahri.KS.E.Hit:Value() then
		if Ahri.KS.E.Mana:Value() > PercentMP(myHero) then return end
		CastE(target)
	end
	if Ready(_Q) and IsValidTarget(target, Q.Range) and Qdmg(target) > target.health and Ahri.KS.useQ:Value() and Hitchance(target, Q.Range, Q.Speed, Q.Delay) >= Ahri.KS.Q.Hit:Value() then
		if Ahri.KS.Q.Mana:Value() > PercentMP(myHero) then return end
		CastQ(target)
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
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and Ahri.A.P.Pot:Value() and PercentHP(myHero) < Ahri.A.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and Ahri.A.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and Ahri.A.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and Ahri.A.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and Ahri.A.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and Ahri.A.D.Locket:Value() and PercentHP(myHero) < 30 then
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
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < Ahri.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < Ahri.A.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if Ahri.A.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < Ahri.A.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < Ahri.A.S.BarrierHP:Value() then
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
	if Ahri.D.useQ:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.Range, 3,  Draw.Color(255, 000, 222, 255)) end
    if Ahri.D.useW:Value() and Ready(_W) then Draw.Circle(myHero.pos, W.Range, 3,  Draw.Color(255, 255, 200, 000)) end
	if Ahri.D.useE:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.Range, 3,  Draw.Color(255, 000, 043, 255)) end
	if Ahri.D.useR:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.Range, 3,  Draw.Color(255, 246, 000, 255)) end
	if Ahri.D.T:Value() then
		local textPosC = myHero.pos:To2D()
		if Ahri.LC.Key:Value() then
			Draw.Text("Clear: On", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Clear: Off", 20, textPosC.x - 33, textPosC.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
		local textPosH = myHero.pos:To2D()
		if Ahri.H.Key:Value() then
			Draw.Text("Harass: On", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("Harass: Off", 20, textPosH.x - 40, textPosH.y + 80, Draw.Color(255, 255, 000, 000)) 
		end
	end
	if Ahri.D.D:Value() then
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
					Draw.Text(tostring(0.1*math.floor(1000*math.min(1,Damage/enemy.health))).." %", 30, enemy.pos:To2D().x, enemy.pos:To2D().y, Draw.Color(255, 255, 000, 000))
				else
    				Draw.Text("KILLABLE", 30, enemy.pos:To2D().x, enemy.pos:To2D().y, Draw.Color(255, 255, 000, 000))
				end
			end
		end
	end
end
