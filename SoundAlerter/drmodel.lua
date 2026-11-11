SA_DRModel = {}

local Model = SA_DRModel

Model.RESET = 18
Model.STEPS = { 1, 0.5, 0.25 }
Model.MAX = #Model.STEPS
Model.MAX_AGE = 60
Model.ORDER = { "stun", "kidney", "incap", "fear", "silence", "root", "charm", "procstun", "procroot", "horror" }

Model.CATEGORIES = {
    stun = { tag = "ST", name = "Stun", color = { 1, 0.48, 0.27 }, base = 5, icon = 853 },
    kidney = { tag = "KS", name = "Kidney Shot", color = { 1, 0.72, 0.3 }, base = 6, icon = 408 },
    incap = { tag = "IN", name = "Incapacitate", color = { 0.78, 0.61, 1 }, base = 10, icon = 118 },
    fear = { tag = "FE", name = "Fear and disorient", color = { 0.72, 0.42, 1 }, base = 8, icon = 5782 },
    silence = { tag = "SI", name = "Silence", color = { 0.48, 0.82, 1 }, base = 4, icon = 15487 },
    root = { tag = "RO", name = "Root", color = { 0.36, 0.88, 0.54 }, base = 8, icon = 339 },
    charm = { tag = "CH", name = "Charm", color = { 1, 0.6, 0.85 }, base = 8, icon = 605 },
    procstun = { tag = "PS", name = "Proc stun", color = { 1, 0.6, 0.45 }, base = 3, icon = 12355 },
    procroot = { tag = "PR", name = "Proc root", color = { 0.55, 0.95, 0.7 }, base = 5, icon = 19306 },
    horror = { tag = "HO", name = "Horror", color = { 1, 0.42, 0.69 }, base = 3, icon = 6789 },
}

Model.BUILD = "1.60.1.70888"

Model.SEEDS = {
    stun = {
        45, 228, 692, 835, 851, 853, 1833, 2647, 2880, 3109, 3609, 3635,
        3636, 4064, 4065, 4066, 4067, 4068, 4069, 4159, 4538, 5211, 5276, 5588,
        5589, 5918, 6409, 6798, 6927, 7922, 8151, 8983, 9005, 9823, 9827, 10308,
        11020, 11836, 11876, 12421, 12543, 12562, 12809, 13005, 13237, 13808, 14902, 15239,
        15593, 15749, 16727, 16740, 17286, 18763, 18798, 19131, 19482, 19769, 19784, 20253,
        20310, 20549, 20614, 20615, 22120, 22561, 22692, 22911, 22915, 24023, 24193, 24315,
        24375, 24394, 24408, 25056, 25821, 27757, 27758, 27868, 28725, 30112, 368127, 411688,
        412790, 427746, 428739, 436100, 438540, 440488, 440586, 446369, 448707, 460403, 460406, 460408,
        460585, 460766, 461396, 461402, 462258, 462260, 462586, 462937, 463168, 470031, 1213301, 1213463,
        1214214, 1222567, 1228295, 1229228, 1231431, 1232702, 1232842, 1235538, 1237147, 1239456, 1249991, 1250226,
        1258520, 1264478, 1264479, 1264480, 1264481, 1264482, 1264548, 1269161, 1269192, 1269216, 1269268, 1269272,
        1269278, 1269330, 1269334, 1283073, 1283407, 1283425, 1292252, 1294626, 1296564, 1299443, 1302937, 1309719,
        1315972, 1317288, 1317450, 1317472, 1328028,
    },
    kidney = {
        408, 8643, 27615, 400009,
    },
    incap = {
        118, 700, 710, 1090, 1776, 1777, 2070, 2637, 3355, 4511, 5403, 6728,
        6770, 8040, 8399, 8629, 8901, 8902, 9159, 9484, 9485, 10955, 11285, 11286,
        11297, 11444, 12098, 12540, 12824, 12825, 12826, 13323, 13327, 13579, 14308, 14309,
        14621, 15534, 15535, 15970, 16451, 16798, 18647, 18657, 18658, 19503, 20066, 20663,
        20669, 20989, 22274, 23103, 23603, 24335, 24698, 25189, 26180, 27760, 28270, 28271,
        28272, 28456, 29848, 402686, 434754, 448572, 450662, 457326, 457569, 460756, 461637, 462577,
        465352, 469155, 1215753, 1222578, 1231616, 1232013, 1236174, 1236290, 1240869, 1270942, 1270943, 1270944,
        1277331, 1277332, 1277333, 1277334, 1277335, 1277455, 1297068, 1300241, 1303598, 1326114,
    },
    fear = {
        16, 1513, 2878, 5134, 5246, 5484, 5627, 5782, 6213, 6215, 6358, 8122,
        8124, 8225, 10326, 10888, 10890, 12096, 12542, 13704, 14326, 14327, 17928, 20511,
        21898, 22678, 22884, 23275, 25260, 25815, 26042, 26070, 27610, 27641, 27990, 29168,
        29419, 29544, 30001, 30002, 31365, 411959, 425891, 437532, 460086, 469065, 469521, 1213452,
        1221571, 1222563, 1230086, 1231885, 1247087, 1249834, 1257055, 1264437, 1271593, 1283934, 1293306, 1297109,
        1299440, 1300784, 1313471, 1315557, 1323802, 1328372, 1328373, 1328374,
    },
    silence = {
        3603, 4243, 4320, 6726, 15471, 15487, 18278, 18425, 18469, 18498, 19821, 22666,
        23207, 24110, 27559, 435968, 462664, 1213924, 1214273, 1219090, 1224125, 1269337, 1293308, 1293654,
        1302715, 1329552,
    },
    root = {
        122, 339, 865, 1062, 5195, 5196, 6131, 9852, 9853, 10230, 10253, 11920,
        19970, 19971, 19972, 19973, 19974, 19975, 440574, 447590, 460690, 465230, 1238289, 1265843,
        1265878, 1265880, 1265881, 1265883, 1294112, 1300493, 1300496, 1307520, 1312052,
    },
    charm = {
        260, 605, 1098, 3442, 7033, 10911, 10912, 11725, 11726, 13181, 17405, 26740,
        437987, 1222581, 1231845, 1296664, 1300754,
    },
    procstun = {
        56, 11650, 12355, 13907, 15269, 15283, 15753, 16600, 16922, 17308, 17500, 18093,
        19410, 20170, 21152, 21990, 23454, 26108, 28445, 429147, 436473, 446391, 446707, 1214205,
        1214223, 1227820, 1232312, 1291806, 1292648, 1294340, 1294343, 1318178,
    },
    procroot = {
        12494, 19185, 19229, 19306, 20909, 20910, 23694, 1242634, 1306620,
    },
}

Model.UNTABLED = {
    fear = { 2094 },
    silence = { 24259 },
    incap = { 450600 },
    horror = { 6789, 17925, 17926 },
}

Model.LEVELS = {
    { 0.24, 0.86, 0.52 },
    { 1, 0.82, 0.24 },
    { 1, 0.3, 0.3 },
}

function Model.New()
    return { count = 0, version = 0 }
end

function Model.Expired(record, now)
    return record.count == 0 or (record.resetAt ~= nil and now >= record.resetAt)
end

function Model.Up(record, now)
    return record.count > 0 and (record.fadeAt == nil or now < record.fadeAt)
end

function Model.Apply(record, now, icon, expires, duration)
    if Model.Expired(record, now) then record.count = 0 end
    local before = record.count
    local count = before < Model.MAX and before + 1 or Model.MAX
    record.count = count
    record.appliedAt, record.fadeAt, record.resetAt = now, nil, nil
    record.icon, record.expires, record.duration, record.estimate = icon, expires, duration, false
    record.version = record.version + 1
    return count, count == Model.MAX and before < Model.MAX
end

function Model.Hold(record, expires, duration)
    record.fadeAt, record.resetAt, record.estimate = nil, nil, false
    if expires then record.expires, record.duration = expires, duration end
    record.version = record.version + 1
end

function Model.Fade(record, now, reset)
    if record.count == 0 then return false end
    if record.fadeAt ~= nil and record.fadeAt <= now then return false end
    record.fadeAt, record.resetAt, record.estimate = now, now + reset, false
    record.version = record.version + 1
    return true
end

function Model.Lose(record, now, reset, base)
    if not Model.Up(record, now) or record.fadeAt ~= nil then return false end
    local at = record.expires
    local estimate = at == nil
    if estimate then at = record.appliedAt + base * (Model.STEPS[record.count] or 1) end
    record.fadeAt, record.resetAt, record.estimate = at, at + reset, estimate
    record.version = record.version + 1
    return true
end

function Model.Deadline(record, base)
    if record.count == 0 or record.fadeAt ~= nil or not record.appliedAt then return nil end
    local length = record.duration or base * (Model.STEPS[record.count] or 1)
    return record.appliedAt + math.min(Model.MAX_AGE, length * 2)
end

function Model.Cap(record, now, reset, base)
    local deadline = Model.Deadline(record, base)
    if not deadline or now < deadline then return false end
    record.fadeAt, record.resetAt, record.estimate = deadline, deadline + reset, true
    record.version = record.version + 1
    return true
end

function Model.Level(count)
    return Model.LEVELS[math.max(1, math.min(count, Model.MAX))]
end

function Model.NextChange(record, now)
    if record.count == 0 then return nil end
    if record.fadeAt and now < record.fadeAt then return record.fadeAt end
    return record.resetAt
end
