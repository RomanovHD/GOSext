if myHero.charName ~= "Katarina" then return end

require "DamageLib"

local Dagger = {}

local function Ready(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0
end

local Me = {
    range = 125,
}

local Passive = {
    radius = 340,
}

local Q = {
    range = 625,
}

local W = {
    particle = "Katarina_Base_W_Indicator_Ally",
    radius = 135,
}

local E = {
    range = 725,
}

local R = {
    range = 550,
    buff = "katarinarsound",
}

local HG = {
    range = 700,
}

local BC = {
    range = 550,
}

local EX = {
    range = 650,
}

local IG = {
    range = 600,
}

local function Passivedmg(target)
    for i = 1, #Dagger do
        if GetDistance(Dagger[i],target.pos) < W.radius + Passive.radius then
            return CalcMagicalDamage(myHero,target,(({75,80,87,94,102,111,120,131,143,155,168,183,198,214,231,248,267,287})[myHero.level] + myHero.bonusDamage + ((0.55 + ({0.15,0.3,0.45})[myHero.level * 5]) * myHero.ap)))
        end
    end
    return 0
end

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
    if myHero:GetSpellData(spell).currentCd == 0 then
        return CalcMagicalDamage(myHero,target,(187.5 + 187.5 * myHero:GetSpellData(_R).level + 3.3 * myHero.bonusDamage + 2.85 * myHero.ap)/2.5)
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
		if buff.name == R.buff then 
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

local RepoKatarina = MenuElement({type = MENU, id = "RepoKatarina", name = "Romanov's Repository 7.24", leftIcon = "https://raw.githubusercontent.com/RomanovHD/GOSext/master/Repository/Screenshot_1.png"})

RepoKatarina:MenuElement({id = "Me", name = "Katarina", drop = {"v1.0"}})
RepoKatarina:MenuElement({id = "Core", name = " ", drop = {"Champion Core"}})
RepoKatarina:MenuElement({id = "Combo", name = "Combo", type = MENU})
    RepoKatarina.Combo:MenuElement({id = "Q", name = "Q - Bouncing Blade", type = MENU})
        RepoKatarina.Combo.Q:MenuElement({id = "Enable", name = "Enable", value = true})
        RepoKatarina.Combo.Q:MenuElement({id = "Mode", name = "When", drop = {"After E (recommended)","Before E"}})
        RepoKatarina.Combo.Q:MenuElement({id = "AA", name = "After AA if in range", value = true})
    RepoKatarina.Combo:MenuElement({id = "W", name = "W - Preparation", type = MENU})
        RepoKatarina.Combo.W:MenuElement({id = "Enable", name = "Enable", value = true})
        RepoKatarina.Combo.W:MenuElement({id = "Mode", name = "When", drop = {"After E (recommended)","Before E"}})
        RepoKatarina.Combo.W:MenuElement({id = "AA", name = "Priorize W over AA (recommended)", value = true})
    RepoKatarina.Combo:MenuElement({id = "E", name = "E - Shunpo", type = MENU})
        RepoKatarina.Combo.E:MenuElement({id = "Enable", name = "Enable", value = true})
        RepoKatarina.Combo.E:MenuElement({id = "Mode", name = "Mode", drop = {"Dynamic (recommended)","Only for daggers","Only for enemies"}})
        RepoKatarina.Combo.E:MenuElement({id = "AA", name = "Reset AA if possible", value = true})
    RepoKatarina.Combo:MenuElement({id = "R", name = "R - Death Lotus", type = MENU})
        RepoKatarina.Combo.R:MenuElement({id = "Enable", name = "Enable", value = true})
        RepoKatarina.Combo.R:MenuElement({id = "Implement", name = "Implement to Combo if target is killable", value = true})
        RepoKatarina.Combo.R:MenuElement({id = "RAoE", name = "Enable R AoE", value = true})
        RepoKatarina.Combo.R:MenuElement({id = "Rx", name = "X enemies to R", value = 3, min = 2, max = 5})
        RepoKatarina.Combo.R:MenuElement({id = "Stop", name = "Stop R if no targets", value = true})

Callback.Add("Tick", function() Tick() end)

function Tick()
    local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	--[[elseif Mode == "Clear" then
		Lane()
        Jungle()
	elseif Mode == "Harass" then
		Harass()
    elseif Mode == "Flee" then
        Flee()]]--
	end
	--Killsteal()
    --Activator()
    CancelR()
    RebootOrb()
    DaggerAdd()
    DaggerRemove()
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

function Combo()
    local target = GetTarget(725 + Passive.radius)
    if target == nil then return end

    local items = {}
	for slot = ITEM_1,ITEM_6 do
		local id = myHero:GetItemData(slot).itemID 
		if id > 0 then
			items[id] = slot
		end
    end
    
    local Qmode = RepoKatarina.Combo.Q.Mode:Value()
    local Wmode = RepoKatarina.Combo.W.Mode:Value()
    local Emode = RepoKatarina.Combo.E.Mode:Value()
    
    if RepoKatarina.Combo.Q.Enable:Value() and Ready(_Q) then
        if GetDistance(myHero.pos,target.pos) > Q.range then return end
        if Qmode == 1 then
            if not Ready(_E) then
                if GetDistance(myHero.pos,target.pos) < Me.range then
                    if RepoKatarina.Combo.Q.AA:Value() then
                        if myHero.attackData.state == 2 then
                            Control.CastSpell(HK_Q,target)
                        end
                    else
                        Control.CastSpell(HK_Q,target)
                    end
                else
                    Control.CastSpell(HK_Q,target)
                end
            end
        else
            if GetDistance(myHero.pos,target.pos) < Q.range then
                Control.CastSpell(HK_Q,target)
            end
        end
    end

    if RepoKatarina.Combo.W.Enable:Value() and Ready(_W) then
        if Wmode == 1 then
            if not Ready(_E) then
                if GetDistance(myHero.pos,target.pos) < Me.range then
                    if not RepoKatarina.Combo.W.AA:Value() then
                        if myHero.attackData.state == 2 then
                            Control.CastSpell(HK_W)
                        end
                    else
                        Control.CastSpell(HK_W)
                    end
                else
                    Control.CastSpell(HK_W)
                end
            end
        else
            Control.CastSpell(HK_W)
        end
    end

    if RepoKatarina.Combo.E.Enable:Value() and Ready(_E) then
        if (Qmode == 2 and Ready(_Q)) or (Wmode == 2 and Ready(_W)) then return end
        if Emode == 1 then
            for i = 1, #Dagger do
                local Evector = Vector(Dagger[i]) - Vector(Vector(Dagger[i]) - Vector(target.pos)):Normalized()*135
                if GetDistance(Dagger[i],target.pos) < W.radius + Passive.radius then
                    if RepoKatarina.Combo.E.AA:Value() then
                        if GetDistance(myHero.pos,target.pos) < Me.range then
                            if myHero.attackData.state == 2 then
                                if GetDistance(Dagger[i],target.pos) > W.radius then
                                    Control.CastSpell(HK_E,Evector)
                                else
                                    Control.CastSpell(HK_E,Dagger[i])
                                end
                            end
                        else
                            if GetDistance(Dagger[i],target.pos) > W.radius then
                                Control.CastSpell(HK_E,W.vector)
                            else
                                Control.CastSpell(HK_E,Dagger[i])
                            end
                        end
                    else
                        if GetDistance(Dagger[i],target.pos) > W.radius then
                            Control.CastSpell(HK_E,Evector)
                        else
                            Control.CastSpell(HK_E,Dagger[i])
                        end
                    end
                end
            end
            if GetDistance(myHero.pos,target.pos) < E.range then
                if RepoKatarina.Combo.E.AA:Value() then
                    if GetDistance(myHero.pos,target.pos) < Me.range then
                        if myHero.attackData.state == 2 then
                            Control.CastSpell(HK_E,target)
                        end
                    else
                        Control.CastSpell(HK_E,target)
                    end
                else
                    Control.CastSpell(HK_E,target)
                end
            end
        elseif Emode == 2 then
            for i = 1, #Dagger do
                if GetDistance(Dagger[i],target.pos) > W.radius + Passive.radius then return end
                if RepoKatarina.Combo.E.AA:Value() then
                    if GetDistance(myHero.pos,target.pos) < Me.range then
                        if myHero.attackData.state == 2 then
                            if GetDistance(Dagger[i],target.pos) > W.radius then
                                Control.CastSpell(HK_E,W.vector)
                            else
                                Control.CastSpell(HK_E,Dagger[i])
                            end
                        end
                    else
                        if GetDistance(Dagger[i],target.pos) > W.radius then
                            Control.CastSpell(HK_E,W.vector)
                        else
                            Control.CastSpell(HK_E,Dagger[i])
                        end
                    end
                else
                    if GetDistance(Dagger[i],target.pos) > W.radius then
                        Control.CastSpell(HK_E,W.vector)
                    else
                        Control.CastSpell(HK_E,Dagger[i])
                    end
                end
            end
        elseif Emode == 3 then
            if GetDistance(myHero.pos,target.pos) > E.range then return end
            if RepoKatarina.Combo.E.AA:Value() then
                if GetDistance(myHero.pos,target.pos) < Me.range then
                    if myHero.attackData.state == 2 then
                        Control.CastSpell(HK_E,target)
                    end
                else
                    Control.CastSpell(HK_E,target)
                end
            else
                Control.CastSpell(HK_E,target)
            end
        end
    end

    if RepoKatarina.Combo.R.Enable:Value() and Game.CanUseSpell(_R) == 0 then
        if RepoKatarina.Combo.R.Implement:Value() then
            if GetDistance(myHero.pos,target.pos) < R.range then
                if (R.range - target.distance)/target.ms * Rdmg(target) >= target.health then
                    EnableOrb(false)
                    Control.CastSpell(HK_R)
                end
            end
        end
        if GetDistance(myHero.pos,target.pos) < R.range then
            if RepoKatarina.Combo.R.RAoE:Value() then
                if RepoKatarina.Combo.R.Rx:Value() <= HeroesAround(myHero.pos, 550, 300 - myHero.team) then
                    EnableOrb(false)
                    Control.CastSpell(HK_R)
                end
            end
        end
    end
end
