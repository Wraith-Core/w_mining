Config = {}

-- Interaction & timing
Config.Key                 = 'J'
Config.InteractDistance    = 2.6
Config.ServerMaxDistance   = 8.0
Config.SpawnDistance       = 80.0
Config.Account             = 'cash'     -- 'cash' | 'bank'
Config.PickaxeItem         = 'pickaxe'
Config.PickaxeBreakChance  = 4          -- % chance per completed mine that the pickaxe breaks (0 = never)
Config.MineDurationMs      = 6500       -- ms progress bar per rock strike
Config.UseSkillCheck       = true       -- optional w_lib skillCheck for bonus yield
Config.NodeCooldownSec     = 75         -- seconds before the same rock node can be mined again
Config.AllowWildRocks      = true       -- allow mining wild RDR2 rocks outside restricted towns
Config.RockModel           = 'mp_sca_rock_grp_l_03'
Config.PickaxeModel        = 'p_pickaxe01x'
Config.MiningScenario      = 'WORLD_HUMAN_PICKAXE_WALL'
Config.MiningAnimDict      = 'amb_work@world_human_pickaxe@wall@male_d@base'
Config.MiningAnimClip      = 'base'
Config.CraftAnimDict       = 'mech_inventory@crafting@fallbacks'
Config.CraftAnimClip       = 'full_craft_and_stow'
Config.MaxBatch            = 25
Config.SmeltMsPerBar       = 2500
Config.CrushMsPerRock      = 1500
Config.WashMsPerNugget     = 1800

Config.CampBlip = {
    enabled = true,
    sprite  = 'blip_shop_blacksmith',
    scale   = 0.2,
}

-- Towns where wild rock mining is blocked (Annesburg mine is explicitly allowed)
Config.RestrictedTowns = {
    'Armadillo', 'Blackwater', 'Lagras', 'Rhodes', 'StDenis',
    'Strawberry', 'Tumbleweed', 'Valentine', 'Vanhorn',
}

-- 4 Mining Camps & Smelting Furnaces
Config.Camps = {
    {
        id     = 'annesburg',
        label  = 'loc_annesburg',
        coords = vec4(2818.06, 1360.32, 70.68, 45.27),
        model  = 'u_m_m_bht_mineforeman',
    },
    {
        id     = 'valentine',
        label  = 'loc_valentine',
        coords = vec4(499.53, 678.62, 117.44, 114.44),
        model  = 'a_m_m_asbminer_01',
    },
    {
        id     = 'gaptooth',
        label  = 'loc_gaptooth',
        coords = vec4(-5970.84, -3240.00, -21.65, 339.70),
        model  = 'u_m_m_bht_mineforeman',
    },
    {
        id     = 'grizzlies',
        label  = 'loc_grizzlies',
        coords = vec4(-1404.16, 1125.72, 228.53, 40.30),
        model  = 'u_m_m_bht_mineforeman',
    },
}

-- Mining camp supply shop
Config.Shop = {
    enabled = true,
    items = {
        { item = 'pickaxe', price = 25.00, count = 1 },
    },
}

-- Spawned ore rock nodes across the 3 classic RDR2 mines (Annesburg, Gaptooth Breach, Grizzlies)
Config.MineNodes = {
    -- Annesburg Mine
    { id = 'ann_01', coords = vec3(2791.47, 1345.14, 71.91), kind = 'ore' },
    { id = 'ann_02', coords = vec3(2793.63, 1336.06, 71.92), kind = 'ore' },
    { id = 'ann_03', coords = vec3(2780.24, 1335.81, 71.54), kind = 'ore' },
    { id = 'ann_04', coords = vec3(2767.23, 1337.07, 70.95), kind = 'salt' },
    { id = 'ann_05', coords = vec3(2765.50, 1335.66, 70.78), kind = 'ore' },
    { id = 'ann_06', coords = vec3(2761.83, 1331.62, 70.53), kind = 'ore' },
    { id = 'ann_07', coords = vec3(2752.02, 1332.12, 70.63), kind = 'ore' },
    { id = 'ann_08', coords = vec3(2741.38, 1319.45, 70.48), kind = 'salt' },
    { id = 'ann_09', coords = vec3(2745.59, 1325.21, 70.48), kind = 'ore' },
    { id = 'ann_10', coords = vec3(2761.12, 1310.74, 70.49), kind = 'ore' },
    { id = 'ann_11', coords = vec3(2755.89, 1301.89, 70.50), kind = 'salt' },
    { id = 'ann_12', coords = vec3(2738.29, 1309.38, 70.39), kind = 'ore' },
    { id = 'ann_13', coords = vec3(2727.73, 1319.83, 70.23), kind = 'ore' },
    { id = 'ann_14', coords = vec3(2736.05, 1322.34, 70.20), kind = 'ore' },
    { id = 'ann_15', coords = vec3(2749.87, 1347.13, 69.16), kind = 'ore' },
    { id = 'ann_16', coords = vec3(2765.42, 1351.20, 71.08), kind = 'salt' },
    -- Gaptooth Breach Mine
    { id = 'gap_01', coords = vec3(-5962.11, -3218.08, -21.03), kind = 'ore' },
    { id = 'gap_02', coords = vec3(-5961.68, -3211.58, -21.02), kind = 'ore' },
    { id = 'gap_03', coords = vec3(-5967.36, -3204.54, -20.89), kind = 'ore' },
    { id = 'gap_04', coords = vec3(-5960.54, -3192.35, -21.11), kind = 'salt' },
    { id = 'gap_05', coords = vec3(-5958.53, -3188.99, -21.14), kind = 'ore' },
    { id = 'gap_06', coords = vec3(-5955.86, -3180.31, -21.85), kind = 'ore' },
    { id = 'gap_07', coords = vec3(-5961.79, -3173.27, -22.59), kind = 'ore' },
    { id = 'gap_08', coords = vec3(-5966.98, -3172.77, -23.50), kind = 'salt' },
    { id = 'gap_09', coords = vec3(-5969.88, -3170.77, -24.24), kind = 'ore' },
    { id = 'gap_10', coords = vec3(-5975.62, -3167.88, -25.00), kind = 'ore' },
    -- Grizzlies Mine
    { id = 'gri_01', coords = vec3(-1418.20, 1138.40, 225.80), kind = 'ore' },
    { id = 'gri_02', coords = vec3(-1424.10, 1146.50, 225.40), kind = 'ore' },
    { id = 'gri_03', coords = vec3(-1430.50, 1152.20, 224.90), kind = 'ore' },
    { id = 'gri_04', coords = vec3(-1436.80, 1158.90, 224.60), kind = 'salt' },
    { id = 'gri_05', coords = vec3(-1411.50, 1142.10, 226.10), kind = 'ore' },
    { id = 'gri_06', coords = vec3(-1406.40, 1134.80, 227.10), kind = 'ore' },
}

-- Weighted ore drops when mining standard ore nodes
Config.OreDrops = {
    { item = 'rock',       weight = 24, min = 1, max = 3 },
    { item = 'coal',       weight = 22, min = 1, max = 3 },
    { item = 'iron',       weight = 20, min = 1, max = 3 },
    { item = 'copper',     weight = 16, min = 1, max = 2 },
    { item = 'clay',       weight = 14, min = 1, max = 2 },
    { item = 'lead_ore',   weight = 12, min = 1, max = 2 },
    { item = 'sulfur',     weight = 10, min = 1, max = 2 },
    { item = 'nitrite',    weight = 8,  min = 1, max = 2 },
    { item = 'raw_silver', weight = 6,  min = 1, max = 2 },
    { item = 'goldnugget', weight = 4,  min = 1, max = 2 },
}

-- Weighted drops when mining salt-vein nodes
Config.SaltDrops = {
    { item = 'salt',       weight = 48, min = 2, max = 4 },
    { item = 'nitrite',    weight = 24, min = 1, max = 2 },
    { item = 'sulfur',     weight = 20, min = 1, max = 2 },
    { item = 'rock',       weight = 15, min = 1, max = 2 },
}

-- Rare gems (chance in % per mine or rock crush; doubled on perfect skillCheck)
Config.GemChance = 6
Config.Gems = {
    { item = 'ruby',          weight = 45 },
    { item = 'uncut_emerald', weight = 35 },
    { item = 'uncut_diamond', weight = 20 },
}

-- Weighted outputs when crushing raw `rock` at a mining camp
Config.CrushDrops = {
    { item = 'coal',       weight = 26, min = 1, max = 2 },
    { item = 'iron',       weight = 22, min = 1, max = 2 },
    { item = 'copper',     weight = 18, min = 1, max = 2 },
    { item = 'clay',       weight = 16, min = 1, max = 2 },
    { item = 'lead_ore',   weight = 12, min = 1, max = 1 },
    { item = 'sulfur',     weight = 10, min = 1, max = 1 },
    { item = 'raw_silver', weight = 6,  min = 1, max = 1 },
    { item = 'goldnugget', weight = 4,  min = 1, max = 1 },
}

-- Smelting furnace recipes (inputs consumed per 1 smelted bar)
Config.SmeltRecipes = {
    {
        id     = 'iron_bar',
        output = 'iron_bar',
        count  = 1,
        inputs = { { item = 'iron', amount = 4 }, { item = 'coal', amount = 2 } },
    },
    {
        id     = 'copper_bar',
        output = 'copper_bar',
        count  = 1,
        inputs = { { item = 'copper', amount = 4 }, { item = 'coal', amount = 2 } },
    },
    {
        id     = 'lead_bar',
        output = 'lead_bar',
        count  = 1,
        inputs = { { item = 'lead_ore', amount = 4 }, { item = 'coal', amount = 2 } },
    },
    {
        id     = 'silver_bar',
        output = 'silver_bar',
        count  = 1,
        inputs = { { item = 'raw_silver', amount = 4 }, { item = 'coal', amount = 2 } },
    },
    {
        id     = 'steel_bar',
        output = 'steel_bar',
        count  = 1,
        inputs = { { item = 'iron', amount = 3 }, { item = 'coal', amount = 2 }, { item = 'sulfur', amount = 1 } },
    },
    {
        id     = 'goldbar_raw',
        output = 'goldbar',
        count  = 1,
        inputs = { { item = 'goldnugget', amount = 5 }, { item = 'coal', amount = 3 } },
    },
    {
        id     = 'goldbar_washed',
        output = 'goldbar',
        count  = 1,
        inputs = { { item = 'washed_gold', amount = 3 }, { item = 'coal', amount = 2 } },
    },
}

-- Minerals, gems, and smelted bars bought by the mining camp foreman
Config.SellPrices = {
    rock          = 0.75,
    clay          = 1.00,
    coal          = 1.50,
    salt          = 1.50,
    nitrite       = 2.25,
    sulfur        = 2.50,
    iron          = 2.25,
    copper        = 2.50,
    lead_ore      = 2.50,
    raw_silver    = 4.50,
    goldnugget    = 6.00,
    washed_gold   = 9.00,
    iron_bar      = 15.00,
    copper_bar    = 17.00,
    lead_bar      = 16.50,
    steel_bar     = 22.00,
    silver_bar    = 28.00,
    goldbar       = 45.00,
    ruby          = 25.00,
    uncut_emerald = 32.00,
    uncut_diamond = 48.00,
}

-- Wild RDR2 rock models that can also be mined outside restricted towns
Config.WildRockModels = {
    'alp_rock_01', 'alp_rock_02', 'alp_rock_03', 'alp_rock_04', 'alp_rock_05',
    'alp_rock_scree_01', 'alp_rock_scree_02', 'alp_rock_scree_03',
    'bgv_rock_01', 'bgv_rock_02', 'bgv_rock_03', 'bgv_rock_04', 'bgv_rock_05',
    'bgv_rock_06', 'bgv_rock_07', 'bgv_rock_08', 'bgv_rock_09', 'bgv_rock_10',
    'bgv_rock_scree_01', 'bgv_rock_scree_02', 'bgv_rock_scree_03',
    'cumb_rock_01', 'cumb_rock_02', 'cumb_rock_03', 'cumb_rock_04', 'cumb_rock_05',
    'cumb_rock_06', 'cumb_rock_07', 'cumb_rock_08', 'cumb_rock_hero_01',
    'dak_rock_stg1_01', 'dak_rock_stg1_02', 'dak_rock_stg1_03', 'dak_rock_stg1_04',
    'dak_rock_stg2_01', 'dak_rock_stg2_02', 'dak_rock_stg2_03', 'dak_rock_stg2_04',
    'dak_rock_stg345_01', 'dak_rock_stg345_02', 'dak_rock_stg345_03', 'dak_rock_stg345_04',
    'gri_rock_01', 'gri_rock_02', 'gri_rock_03', 'gri_rock_04', 'gri_rock_05',
    'hnt_rock_01', 'hnt_rock_02', 'hnt_rock_03', 'hnt_rock_04', 'hnt_rock_05',
    'mp_sca_rock_grp_l_01', 'mp_sca_rock_grp_l_02', 'mp_sca_rock_grp_l_03',
    'p_rock_01', 'p_rock_02', 'p_rock_03', 'p_rock_04', 'p_rock_05',
    'roan_rock_01', 'roan_rock_02', 'roan_rock_03', 'roan_rock_04', 'roan_rock_05',
    'sca_rock_01', 'sca_rock_02', 'sca_rock_03', 'sca_rock_04', 'sca_rock_05',
    'tal_rock_01', 'tal_rock_02', 'tal_rock_03', 'tal_rock_04', 'tal_rock_05',
}
