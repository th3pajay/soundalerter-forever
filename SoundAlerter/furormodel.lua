local Furor = {}

Furor.SPELLS = { 17056, 17058, 17059, 17060, 17061 }
Furor.SHARE = 0.2
Furor.REGEN = 2
Furor.CAP = 20

function Furor.Rank(known)
    for rank = #Furor.SPELLS, 1, -1 do
        if known(Furor.SPELLS[rank]) then return rank end
    end
    return 0
end

function Furor.Share(rank)
    return Furor.SHARE * rank
end

function Furor.Cap(rank)
    return Furor.CAP * rank
end

function Furor.Regen(rank, seconds)
    if seconds <= 0 then return 0 end
    local regen = Furor.REGEN * rank * seconds
    local cap = Furor.CAP * rank
    if regen > cap then return cap end
    return regen
end

function Furor.NewClock()
    return { form = nil, leftAt = nil, bearSince = nil, bearTime = 0 }
end

function Furor.Note(clock, form, now)
    local old = clock.form
    if old == form then return end
    clock.form = form
    if old == "bear" and clock.bearSince then
        clock.bearTime = clock.bearTime + (now - clock.bearSince)
        clock.bearSince = nil
    end
    if form == "cat" then
        clock.leftAt, clock.bearSince, clock.bearTime = nil, nil, 0
        return
    end
    if old == "cat" or clock.leftAt == nil then
        clock.leftAt, clock.bearTime = now, 0
    end
    if form == "bear" then clock.bearSince = now end
end

function Furor.Outside(clock, now)
    if not clock.leftAt then return 0 end
    local bear = clock.bearTime
    if clock.bearSince then bear = bear + (now - clock.bearSince) end
    local outside = now - clock.leftAt - bear
    if outside < 0 then return 0 end
    return outside
end

function Furor.Growing(clock, rank, now)
    if rank <= 0 or clock.form == "bear" or clock.form == "cat" or clock.form == nil then return false end
    return Furor.Regen(rank, Furor.Outside(clock, now)) < Furor.Cap(rank)
end

SA_FurorModel = Furor
