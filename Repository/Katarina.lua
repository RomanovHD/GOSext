if myHero.charName ~= "Katarina" then return end

local Dagger = {}

require "DamageLib"

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0
end

local function PercentHP(target)
    return 100 * target.health / target.maxHealth
end

local function IsImmune(unit)
    for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and PercentHP(unit) <= 10 then
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

local Passive = {radius = 340}
local Q = {range = 625}
local W = {radius = 135}
local E = {range = 725}
local R = {range = 550}
local HG = {range = 700}
local BC = {range = 550}
local EX = {range = 650}
local IG = {range = 600}

local function Qdmg(target)
    if Ready(_Q) then
        return CalcMagicalDamage(myHero,target,(45 + 30 * myHero:GetSpellData(_Q).level + 0.3 * myHero.ap))
    end
    return 0
end

local function Edmg(target)
    if Ready(_E) then
        return CalcMagicalDamage(myHero,target,(15 * myHero:GetSpellData(_E).level + 0.5 * myHero.totalDamage + 0.25 * myHero.ap))
    end
    return 0
end

local function Rdmg(target)
    if Ready(_R) then
        return CalcMagicalDamage(myHero,target,(187.5 + 187.5 * myHero:GetSpellData(_R).level + 3.3 * myHero.bonusDamage + 2.85 * myHero.ap/2.5 * 0.9))
    end
    return 0
end

local function HGdmg(target)
    return CalcMagicalDamage(myHero,target,(170.5 + 4.5 * myHero.levelData.lvl + 0.3 * myHero.ap))
end

local function BCdmg(target)
    return CalcMagicalDamage(myHero,target,(100))
end

local function IGdmg(target)
    return 70 + 20 * myHero.levelData.lvl
end

local function GetDistance(p1, p2)
    return p1:DistanceTo(p2)
end

local function Spinning()
	for i = 0, myHero.buffCount do 
    local buff = myHero:GetBuff(i)
		if buff.name == "katarinarsound" then 
			return true
		end
	end
	return false
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

local HKITEM = {
	[ITEM_1] = HK_ITEM_1,
	[ITEM_2] = HK_ITEM_2,
	[ITEM_3] = HK_ITEM_3,
	[ITEM_4] = HK_ITEM_4,
	[ITEM_5] = HK_ITEM_5,
	[ITEM_6] = HK_ITEM_6,
	[ITEM_7] = HK_ITEM_7,
}

local function SlowImmobile(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.count > 0 then
            if (buff.type == 5 or 
                buff.type == 8 or
                buff.type == 9 or
                buff.type == 10 or
                buff.type == 11 or 
                buff.type == 18 or
                buff.type == 19 or
                buff.type == 21 or 
                buff.type == 22 or 
                buff.type == 24 or 
                buff.type == 28 or 
                buff.type == 29 or 
                buff.type == 30 or
                buff.type == 31) 
            then
				return true
			end
		end
	end
	return false
end

local function IsUnderTurret(unit)
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

local RepoKatarina = MenuElement({type = MENU, id = "RepoKatarina", name = "Romanov's Repository 7.24", leftIcon = "https://raw.githubusercontent.com/RomanovHD/GOSext/master/Repository/Screenshot_1.png"})

RepoKatarina:MenuElement({id = "Me", name = "Katarina", drop = {"v3.0"}})
RepoKatarina:MenuElement({id = "Core", name = " ", drop = {"Champion Core"}})
RepoKatarina:MenuElement({id = "Combo", name = "Combo", type = MENU})
    RepoKatarina.Combo:MenuElement({id = "Q", name = "Q - Bouncing Blade", value = true})
    RepoKatarina.Combo:MenuElement({id = "W", name = "W - Preparation", value = true})
    RepoKatarina.Combo:MenuElement({id = "E", name = "E - Shunpo", value = true})
	RepoKatarina.Combo:MenuElement({id = "R", name = "R - Death Lotus", value = true})
	RepoKatarina.Combo:MenuElement({id = "RAoE", name = "X enemies to R", value = 3, min = 2, max = 6})
    RepoKatarina.Combo:MenuElement({id = "HG", name = "Item - Hextech Gunblade", value = true})
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        RepoKatarina.Combo:MenuElement({id = "IG", name = "Spell - Ignite", value = true})
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        RepoKatarina.Combo:MenuElement({id = "EX", name = "Spell - Exhaust", value = true})
    end
    RepoKatarina.Combo:MenuElement({id = "Mode", name = "Alternate Modes [Safe/Tryhard]", key = string.byte("S"), toggle = true})

RepoKatarina:MenuElement({id = "Clear", name = "Clear", type = MENU})
	RepoKatarina.Clear:MenuElement({id = "Q", name = "Q - Bouncing Blade", value = true})
	RepoKatarina.Clear:MenuElement({id = "W", name = "W - Preparation", value = true})
	RepoKatarina.Clear:MenuElement({id = "E", name = "E - Shunpo [Jungle only]", value = true})
	RepoKatarina.Clear:MenuElement({id = "Key", name = "Enable/Disable", key = string.byte("A"), toggle = true})

RepoKatarina:MenuElement({id = "Utility", name = " ", drop = {"Champion Utility"}})
RepoKatarina:MenuElement({id = "Leveler", name = "Auto Leveler", type = MENU})
    RepoKatarina.Leveler:MenuElement({id = "Enabled", name = "Enable", value = true})
    RepoKatarina.Leveler:MenuElement({id = "Block", name = "Block on Level 1", value = true})
    RepoKatarina.Leveler:MenuElement({id = "Order", name = "Skill Priority", value = 2, drop = {"[Q] - [W] - [E] > Max [Q]","[Q] - [E] - [W] > Max [Q]","[W] - [Q] - [E] > Max [W]","[W] - [E] - [Q] > Max [W]","[E] - [Q] - [W] > Max [E]","[E] - [W] - [Q] > Max [E]"}})

RepoKatarina:MenuElement({type = MENU, id = "Activator", name = "Activator"})
	RepoKatarina.Activator:MenuElement({type = MENU, id = "CS", name = "Cleanse Settings"})
	RepoKatarina.Activator.CS:MenuElement({id = "Blind", name = "Blind", value = false})
	RepoKatarina.Activator.CS:MenuElement({id = "Charm", name = "Charm", value = true})
	RepoKatarina.Activator.CS:MenuElement({id = "Flee", name = "Flee", value = true})
	RepoKatarina.Activator.CS:MenuElement({id = "Slow", name = "Slow", value = false})
	RepoKatarina.Activator.CS:MenuElement({id = "Root", name = "Root/Snare", value = true})
	RepoKatarina.Activator.CS:MenuElement({id = "Poly", name = "Polymorph", value = true})
	RepoKatarina.Activator.CS:MenuElement({id = "Silence", name = "Silence", value = true})
	RepoKatarina.Activator.CS:MenuElement({id = "Stun", name = "Stun", value = true})
	RepoKatarina.Activator.CS:MenuElement({id = "Taunt", name = "Taunt", value = true})
	RepoKatarina.Activator:MenuElement({type = MENU, id = "P", name = "Potions"})
	RepoKatarina.Activator.P:MenuElement({id = "Pot", name = "All Potions", value = true})
	RepoKatarina.Activator.P:MenuElement({id = "HP", name = "Health % to Potion", value = 60, min = 0, max = 100})
	RepoKatarina.Activator:MenuElement({type = MENU, id = "I", name = "Items"})
	RepoKatarina.Activator.I:MenuElement({id = "O", name = "Offensive Items", type = MENU})
	RepoKatarina.Activator.I.O:MenuElement({id = "Bilge", name = "Bilgewater Cutlass (all)", value = true}) 
	RepoKatarina.Activator.I.O:MenuElement({id = "Edge", name = "Edge of the Night", value = true})
	RepoKatarina.Activator.I.O:MenuElement({id = "Frost", name = "Frost Queen's Claim", value = true})
	RepoKatarina.Activator.I.O:MenuElement({id = "Proto", name = "Hextec Revolver (all)", value = true})
	RepoKatarina.Activator.I.O:MenuElement({id = "Ohm", name = "Ohmwrecker", value = true})
	RepoKatarina.Activator.I.O:MenuElement({id = "Glory", name = "Righteous Glory", value = true})
	RepoKatarina.Activator.I.O:MenuElement({id = "Tiamat", name = "Tiamat (all)", value = true})
	RepoKatarina.Activator.I.O:MenuElement({id = "YG", name = "Youmuu's Ghostblade", value = true})
	RepoKatarina.Activator.I:MenuElement({id = "D", name = "Defensive Items", type = MENU})
	RepoKatarina.Activator.I.D:MenuElement({id = "Face", name = "Face of the Mountain", value = true})
	RepoKatarina.Activator.I.D:MenuElement({id = "Garg", name = "Gargoyle Stoneplate", value = true})
	RepoKatarina.Activator.I.D:MenuElement({id = "Locket", name = "Locket of the Iron Solari", value = true})
	RepoKatarina.Activator.I.D:MenuElement({id = "MC", name = "Mikael's Crucible", value = true})
	RepoKatarina.Activator.I.D:MenuElement({id = "QSS", name = "Quicksilver Sash", value = true})
	RepoKatarina.Activator.I.D:MenuElement({id = "RO", name = "Randuin's Omen", value = true})
	RepoKatarina.Activator.I.D:MenuElement({id = "SE", name = "Seraph's Embrace", value = true})
	RepoKatarina.Activator.I:MenuElement({id = "U", name = "Utility Items", type = MENU})
	RepoKatarina.Activator.I.U:MenuElement({id = "Ban", name = "Banner of Command", value = true})
	RepoKatarina.Activator.I.U:MenuElement({id = "Red", name = "Redemption", value = true})
	RepoKatarina.Activator.I.U:MenuElement({id = "TA", name = "Talisman of Ascension", value = true})
	RepoKatarina.Activator.I.U:MenuElement({id = "ZZ", name = "Zz'Rot Portal", value = true})
	
	RepoKatarina.Activator:MenuElement({type = MENU, id = "S", name = "Summoner Spells"})
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			RepoKatarina.Activator.S:MenuElement({id = "Smite", name = "Combo Smite", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/05/Smite.png"})
			RepoKatarina.Activator.S:MenuElement({id = "SmiteS", name = "Smite Stacks to Combo", value = 1, min = 1, max = 2})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
			RepoKatarina.Activator.S:MenuElement({id = "Heal", name = "Heal", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/6e/Heal.png"})
			RepoKatarina.Activator.S:MenuElement({id = "HealHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
			RepoKatarina.Activator.S:MenuElement({id = "Barrier", name = "Barrier", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cc/Barrier.png"})
			RepoKatarina.Activator.S:MenuElement({id = "BarrierHP", name = "HP Under %", value = 25, min = 0, max = 100})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			RepoKatarina.Activator.S:MenuElement({id = "Ignite", name = "Combo Ignite", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			RepoKatarina.Activator.S:MenuElement({id = "Exh", name = "Combo Exhaust", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"})
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" then
			RepoKatarina.Activator.S:MenuElement({id = "Cleanse", name = "Cleanse", value = true, leftIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/95/Cleanse.png"})
		end

RepoKatarina:MenuElement({id = "Draw", name = "Drawings", type = MENU})
    RepoKatarina.Draw:MenuElement({id = "Q", name = "Q - Bouncing Blade", value = true})
    RepoKatarina.Draw:MenuElement({id = "E", name = "E - Shunpo", value = true})
    RepoKatarina.Draw:MenuElement({id = "R", name = "R - Death Lotus", value = true})
    RepoKatarina.Draw:MenuElement({id = "C", name = "Enable Text", value = true})
    RepoKatarina.Draw:MenuElement({id = "D", name = "Damage by %", value = true})

Callback.Add("Tick", function() Tick() end)
Callback.Add("Draw", function() Drawings() end)

function Tick()
    local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	elseif Mode == "Clear" then
		Lane()
	end
	Activator()
	Activator2()
    AutoLevel()
    CancelR()
    RebootOrb()
    DaggerAdd()
    DaggerRemove()
end

function AutoLevel()
	if RepoKatarina.Leveler.Enabled:Value() == false then return end
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
	local Check = Sequence[RepoKatarina.Leveler.Order:Value()][level - SkillPoints + 1]
	if SkillPoints > 0 then
		if RepoKatarina.Leveler.Block:Value() and level == 1 then return end
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

function CancelR()
    if HeroesAround(myHero.pos, 550, 300 - myHero.team) == 0 and Spinning() then
        EnableOrb(true)
    end
end

function RebootOrb()
    if Spinning() == false then
        EnableOrb(true)
    end
end

function DaggerAdd()
	for u = 1, Game.ParticleCount() do
		local particle = Game.Particle(u)
		if particle and particle.name == "Katarina_Base_W_Indicator_Ally.troy" then
			local found = false
			for i = 1, #Dagger do
				if Dagger[i] == particle.pos then
					found = true
				end
			end
			if found == false then
				table.insert(Dagger, particle.pos)
			end
		end
	end
end

function DaggerRemove()
	for i = 1, #Dagger do
		local found = false
		for u = 1, Game.ParticleCount() do
			local particle = Game.Particle(u)
			if particle and particle.name == "Katarina_Base_W_Indicator_Ally.troy" then
				if Dagger[i] == particle.pos then
					found = true
				end
			end
		end
		if found == false then
			table.remove(Dagger, i)
		end
	end
end

lastW = Game.Timer()
function Combo()
    local target = GetTarget(E.range + Passive.radius)
    if target == nil then return end

    if IsValidTarget(target,W.radius + Passive.radius/2) and RepoKatarina.Combo.W:Value() and Ready(_W) then
        Control.CastSpell(HK_W)
        lastW = Game.Timer()
    end
    
    if IsValidTarget(target,Q.range) and RepoKatarina.Combo.Q:Value() and Ready(_Q) then
        if GetDistance(myHero.pos,target.pos) < 500 then
            if myHero:GetSpellData(_W).level ~= 0 then
                if Game.Timer() - lastW > 1.25 then
                    Control.CastSpell(HK_Q,target)
                end
            else
                Control.CastSpell(HK_Q,target)
            end
        else
            Control.CastSpell(HK_Q,target)
        end
    end

    if IsValidTarget(target,E.range + Passive.radius) and RepoKatarina.Combo.E:Value() and Ready(_E) then
        if RepoKatarina.Combo.Mode:Value() and (IsUnderTurret(target) or MinionsAround(target.pos, 550, 300 - myHero.team) >= 5 or PercentHP(myHero) <= PercentHP(target) + 15 ) then return end
        for i = 1, #Dagger do
            if GetDistance(myHero.pos,Dagger[i]) < E.range + W.radius then
                local Edge = Vector(Dagger[i]) - Vector(Vector(Dagger[i]) - Vector(target.pos)):Normalized()*135
                if GetDistance(target.pos,Dagger[i]) < W.radius + Passive.radius then
                    if GetDistance(target.pos,Dagger[i]) < W.radius then
                        Control.CastSpell(HK_E,Dagger[i])
                    elseif GetDistance(target.pos,Dagger[i]) >= W.radius then
                        Control.CastSpell(HK_E,Edge)
                    end
                elseif GetDistance(target.pos,Dagger[i]) >= W.radius + Passive.radius then
                    if GetDistance(target.pos,Dagger[i]) < GetDistance(myHero.pos,target.pos) then
                        Control.CastSpell(HK_E,Edge)
                    end
                end
            end
        end
        if GetDistance(myHero.pos,target.pos) < E.range then
            if myHero:GetSpellData(_Q).level ~= 0 then
                if GetDistance(myHero.pos,target.pos) < Q.range then
                    if myHero:GetSpellData(_Q).currentCd >= 2 then
                        Control.CastSpell(HK_E,target)
                    end
                elseif GetDistance(myHero.pos,target.pos) > Q.range then
                    Control.CastSpell(HK_E,target)
                end
            else
                Control.CastSpell(HK_E,target)
            end
        end
    end

    if IsValidTarget(target,R.range) and RepoKatarina.Combo.R:Value() and Game.CanUseSpell(_R) == 0 then
        if RepoKatarina.Combo.Mode:Value() and IsUnderTurret(myHero) then return end
        if (R.range - target.distance)/target.ms * Rdmg(target) >= target.health then
            EnableOrb(false)
            Control.CastSpell(HK_R)
		end
		if RepoKatarina.Combo.RAoE:Value() <= HeroesAround(myHero.pos, R.range, 300 - myHero.team) then
			EnableOrb(false)
			Control.CastSpell(HK_R)
		end
    end
end

function Lane()
	if RepoKatarina.Clear.Key:Value() == false then return end
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion then
			if minion.team == 300 - myHero.team then
				if IsValidTarget(minion,Q.range) and RepoKatarina.Clear.Q:Value() and Ready(_Q) and MinionsAround(minion.pos, 400, 300 - myHero.team) >= 3 then
					Control.CastSpell(HK_Q,minion)
				end
				if RepoKatarina.Clear.W:Value() and Ready(_W) and MinionsAround(myHero.pos, Passive.radius, 300 - myHero.team) >= 4 then
					Control.CastSpell(HK_W)
				end
			end
			if minion.team == 300 then
				if IsValidTarget(minion,Q.range) and RepoKatarina.Clear.Q:Value() and Ready(_Q) then
					Control.CastSpell(HK_Q,minion)
				end
				if IsValidTarget(minion,Passive.radius) and RepoKatarina.Clear.W:Value() and Ready(_W) then
					Control.CastSpell(HK_W)
				end
				if IsValidTarget(minion,E.range) and RepoKatarina.Clear.E:Value() and Ready(_E) then
					Control.CastSpell(HK_E,minion)
				end
			end
		end
	end
end

function Activator()
	local target = GetTarget(E.range + Passive.radius)
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    if GetMode() == "Combo" then
    if target == nil then return end
        local HG = items[3146]
        if HG and myHero:GetSpellData(HG).currentCd == 0 and RepoKatarina.Combo.HG:Value() and GetDistance(myHero.pos,target.pos) < R.range then
            if Game.CanUseSpell(_R) == 0 and (R.range - target.distance)/(0.6 * target.ms) * Rdmg(target) + HGdmg(target) >= target.health then
                Control.CastSpell(HKITEM[HG], target)
            end
        end
        local BC = items[3144]
        if BC and myHero:GetSpellData(BC).currentCd == 0 and RepoKatarina.Combo.HG:Value() and GetDistance(myHero.pos,target.pos) < R.range then
            if Game.CanUseSpell(_R) == 0 and (R.range - target.distance)/(0.75 * target.ms) * Rdmg(target) + BCdmg(target) >= target.health then
                Control.CastSpell(HKITEM[BC], target)
            end
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RepoKatarina.Combo.IG:Value() then
				local IgDamage = (R.range - target.distance)/target.ms * Rdmg(target) + IGdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and IgDamage > target.health
				and Game.CanUseSpell(_R) == 0 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and IgDamage > target.health
				and Game.CanUseSpell(_R) == 0 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
			if RepoKatarina.Combo.EX:Value() then
				local Damage = (R.range - target.distance)/(0.7 * target.ms) * Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and Ready(SUMMONER_1) and Damage > target.health
				and Game.CanUseSpell(_R) == 0 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and Ready(SUMMONER_2) and Damage > target.health
				and Game.CanUseSpell(_R) == 0 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
    end
end

function Activator2()
	local target = GetTarget(1575)
	local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    local Banner = items[3060]
    if Banner and myHero:GetSpellData(Banner).currentCd == 0 and RepoKatarina.Activator.I.U.Ban:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and myHero.pos:DistanceTo(minion.pos) < 1200 then
                Control.CastSpell(HKITEM[Banner], minion)
            end
        end
    end
	local Potion = items[2003] or items[2010] or items[2031] or items[2032] or items[2033]
	if Potion and target and myHero:GetSpellData(Potion).currentCd == 0 and RepoKatarina.Activator.P.Pot:Value() and PercentHP(myHero) < RepoKatarina.Activator.P.HP:Value() and NoPotion() then
		Control.CastSpell(HKITEM[Potion])
    end
    local Face = items[3401]
	if Face and target and myHero:GetSpellData(Face).currentCd == 0 and RepoKatarina.Activator.D.Face:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Face])
    end
    local Garg = items[3193]
	if Garg and target and myHero:GetSpellData(Garg).currentCd == 0 and RepoKatarina.Activator.D.Garg:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Garg])
    end
    local Red = items[3107]
	if Red and target and myHero:GetSpellData(Red).currentCd == 0 and RepoKatarina.Activator.U.Red:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Red], myHero.pos)
    end
    local SE = items[3048]
	if SE and target and myHero:GetSpellData(SE).currentCd == 0 and RepoKatarina.Activator.D.SE:Value() and PercentHP(myHero) < 30 and MP(myHero) > 45 then
		Control.CastSpell(HKITEM[SE])
    end
    local Locket = items[3190]
	if Locket and target and myHero:GetSpellData(Locket).currentCd == 0 and RepoKatarina.Activator.D.Locket:Value() and PercentHP(myHero) < 30 then
		Control.CastSpell(HKITEM[Locket])
    end
    local ZZ = items[3144] or items[3153]
    if ZZ and myHero:GetSpellData(ZZ).currentCd == 0 and RepoKatarina.Activator.I.U.ZZ:Value() then
        for i = 1, Game.TurretCount() do
            local turret = Game.Turret(i)
            if turret and turret.isAlly and HP(turret) < 100 and myHero.pos:DistanceTo(turret.pos) < 400 then    
                Control.CastSpell(HKITEM[ZZ], turret.pos)
            end
        end
    end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
		if RepoKatarina.Activator.S.Heal:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoKatarina.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoKatarina.Activator.S.HealHP:Value() then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
	end
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier"
	or myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
		if RepoKatarina.Activator.S.Barrier:Value() and target then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and Ready(SUMMONER_1) and PercentHP(myHero) < RepoKatarina.Activator.S.BarrierHP:Value() then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and Ready(SUMMONER_2) and PercentHP(myHero) < RepoKatarina.Activator.S.BarrierHP:Value() then
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
					if ((buff.type == 5 and RepoKatarina.Activator.CS.Stun:Value())
					or (buff.type == 7 and  RepoKatarina.Activator.CS.Silence:Value())
					or (buff.type == 8 and  RepoKatarina.Activator.CS.Taunt:Value())
					or (buff.type == 9 and  RepoKatarina.Activator.CS.Poly:Value())
					or (buff.type == 10 and  RepoKatarina.Activator.CS.Slow:Value())
					or (buff.type == 11 and  RepoKatarina.Activator.CS.Root:Value())
					or (buff.type == 21 and  RepoKatarina.Activator.CS.Flee:Value())
					or (buff.type == 22 and  RepoKatarina.Activator.CS.Charm:Value())
					or (buff.type == 25 and  RepoKatarina.Activator.CS.Blind:Value())
					or (buff.type == 28 and  RepoKatarina.Activator.CS.Flee:Value())) then
						if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and Ready(SUMMONER_1) and RepoKatarina.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_1)
						elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and Ready(SUMMONER_2) and RepoKatarina.Activator.S.Cleanse:Value() then
							Control.CastSpell(HK_SUMMONER_2)
                        end
                        local MC = items[3222]
                        if MC and myHero:GetSpellData(MC).currentCd == 0 and RepoKatarina.Activator.I.D.MC:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[MC])
                        end
                        local QSS = items[3140] or items[3139]
                        if QSS and myHero:GetSpellData(QSS).currentCd == 0 and RepoKatarina.Activator.I.D.QSS:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
                            Control.CastSpell(HKITEM[QSS])
                        end
					end
				end
			end
		end
	end
    if GetMode() == "Combo" then
        local Bilge = items[3144] or items[3153]
		if Bilge and myHero:GetSpellData(Bilge).currentCd == 0 and RepoKatarina.Activator.I.O.Bilge:Value() and myHero.pos:DistanceTo(target.pos) < 550 then
			Control.CastSpell(HKITEM[Bilge], target.pos)
        end
        local Edge = items[3144] or items[3153]
		if Edge and myHero:GetSpellData(Edge).currentCd == 0 and RepoKatarina.Activator.I.O.Edge:Value() and myHero.pos:DistanceTo(target.pos) < 1200 then
			Control.CastSpell(HKITEM[Edge])
        end
        local Frost = items[3092]
		if Frost and myHero:GetSpellData(Frost).currentCd == 0 and RepoKatarina.Activator.I.O.Frost:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Frost])
		end
		local Randuin = items[3143]
		if Randuin and myHero:GetSpellData(Randuin).currentCd == 0 and RepoKatarina.Activator.I.D.RO:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
			Control.CastSpell(HKITEM[Randuin])
		end
		local Hex = items[3152] or items[3146] or items[3030]
		if Hex and myHero:GetSpellData(Hex).currentCd == 0 and RepoKatarina.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) > 550 then
			Control.CastSpell(HKITEM[Hex], target.pos)
        end
        local Pistol = items[3146]
        if Pistol and myHero:GetSpellData(Pistol).currentCd == 0 and RepoKatarina.Activator.I.O.Proto:Value() and myHero.pos:DistanceTo(target.pos) < 700 then
            Control.CastSpell(HKITEM[Pistol], target.pos)
        end
        local Ohm = items[3144] or items[3153]
		if Ohm and myHero:GetSpellData(Ohm).currentCd == 0 and RepoKatarina.Activator.I.O.Ohm:Value() and myHero.pos:DistanceTo(target.pos) < 800 then
            for i = 1, Game.TurretCount() do
                local turret = Game.Turret(i)
                if turret and turret.isEnemy and turret.isTargetableToTeam and myHero.pos:DistanceTo(turret.pos) < 775 then    
                    Control.CastSpell(HKITEM[Ohm])
                end
            end
        end
        local Glory = items[3800]
		if Glory and myHero:GetSpellData(Glory).currentCd == 0 and RepoKatarina.Activator.I.O.Glory:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[Glory])
        end
        local Tiamat = items[3077] or items[3748] or items[3074]
		if Tiamat and myHero:GetSpellData(Tiamat).currentCd == 0 and RepoKatarina.Activator.I.O.Tiamat:Value() and myHero.pos:DistanceTo(target.pos) < 400 and myHero.attackData.state == 2 then
			Control.CastSpell(HKITEM[Tiamat], target.pos)
        end
        local YG = items[3142]
		if YG and myHero:GetSpellData(YG).currentCd == 0 and RepoKatarina.Activator.I.O.YG:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[YG])
        end
        local TA = items[3069]
		if TA and myHero:GetSpellData(TA).currentCd == 0 and RepoKatarina.Activator.I.D.TA:Value() and myHero.pos:DistanceTo(target.pos) < 1575 then
			Control.CastSpell(HKITEM[TA])
        end
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" then
			if RepoKatarina.Activator.S.Smite:Value() then
				local RedDamage = Qdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_1) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoKatarina.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and Ready(SUMMONER_2) and RedDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoKatarina.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
				local BlueDamage = Qdmg(target) + Edmg(target) + Rdmg(target)
				if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_1) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_1).ammo >= RepoKatarina.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_1, target)
				elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and Ready(SUMMONER_2) and BlueDamage > target.health
				and myHero:GetSpellData(SUMMONER_2).ammo >= RepoKatarina.Activator.S.SmiteS:Value() and myHero.pos:DistanceTo(target.pos) < 500 then
					Control.CastSpell(HK_SUMMONER_2, target)
				end
			end
		end
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot"
		or myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
			if RepoKatarina.Activator.S.Ignite:Value() then
				local IgDamage = IGdmg(target)
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

function Drawings()
    if myHero.dead then return end
	if RepoKatarina.Draw.Q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, Q.range, 3,  Draw.Color(255, 000, 222, 255)) end
	if RepoKatarina.Draw.E:Value() and Ready(_E) then Draw.Circle(myHero.pos, E.range, 3,  Draw.Color(255, 000, 043, 255)) end
	if RepoKatarina.Draw.R:Value() and Ready(_R) then Draw.Circle(myHero.pos, R.range, 3,  Draw.Color(255, 246, 000, 255)) end
	if RepoKatarina.Draw.C:Value() then
		local textPos = myHero.pos:To2D()
		if RepoKatarina.Combo.Mode:Value() then
			Draw.Text("SAFE MODE", 20, textPos.x - 57, textPos.y + 60, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("TRYHARD MODE", 20, textPos.x - 57, textPos.y + 60, Draw.Color(255, 225, 000, 000)) 
		end
		if RepoKatarina.Clear.Key:Value() then
			Draw.Text("CLEAR ENABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 000, 255, 000)) 
		else
			Draw.Text("CLEAR DISABLED", 20, textPos.x - 57, textPos.y + 40, Draw.Color(255, 225, 000, 000)) 
		end
	end
	if RepoKatarina.Draw.D:Value() then
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.isEnemy and not enemy.dead and enemy.visible then
				local barPos = enemy.hpBar
				local health = enemy.health
				local maxHealth = enemy.maxHealth
				local Qdmg = Qdmg(enemy)
				local Wdmg = 0
				local Edmg = Edmg(enemy)
				local Rdmg = Rdmg(enemy) * 2.5
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
