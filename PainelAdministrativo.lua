-- PainelInfoHelper.lua
-- Versão para Ajudantes/Moderadores (Sem Interiores, Sem Painel Evento/Airdrop)
-- Baseado na v8.9.18 do PainelInfoadm+.lua

require 'lib.moonloader'
require 'lib.sampfuncs'
local sampev = require 'lib.samp.events'
local bit = require 'bit'

local imgui = require 'imgui'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
encoding.default = 'CP1252'
local u8 = function(s) return s and encoding.UTF8(s) or "" end

script_name("PainelInfoHelper")
script_author("Gerado por ChatGPT - Adaptado por Gemini")
script_version("1.0.70")
local script_ver_num = 1070
script_version_number(script_ver_num)

-- VARIAVEIS DO ADMIN ESP (INTEGRACAO)
local esp_active = false
local esp_font = renderCreateFont('Arial', 10, 5) -- Arial 10 com Borda
local esp_spectate_id = -1
local esp_spectate_vehicle_id = -1
local weapon_names_esp = {
    [0]="Punhos", [1]="Soco Ingles", [2]="Taco de Golf", [3]="Cassetete", [4]="Faca", [5]="Taco de Basebol",
    [6]="Pa", [7]="Taco de Bilhar", [8]="Katana", [9]="Serra Eletrica", [10]="Dildo Roxo", [11]="Dildo Branco",
    [12]="Vibrador", [13]="Vibrador Prata", [14]="Flores", [15]="Bengala", [16]="Granada", [17]="Gas Lacrimogeneo",
    [18]="Molotov", [22]="Pistola 9mm", [23]="Pistola Silenciada", [24]="Desert Eagle", [25]="Shotgun",
    [26]="Sawnoff", [27]="Combat Shotgun", [28]="Micro Uzi", [29]="MP5", [30]="AK-47", [31]="M4", [32]="Tec-9",
    [33]="Country Rifle", [34]="Sniper", [35]="RPG", [36]="Missil Teleguiado", [37]="Lanca Chamas", [38]="Minigun",
    [39]="C4", [40]="Detonador", [41]="Spray", [42]="Extintor", [43]="Camera", [44]="Visao Noturna", [45]="Visao Termica",
    [46]="Paraquedas"
}

-- Janela state
local state = {
    window_open = imgui.ImBool(false),
    active_tab = 2,
    active_info_sub_tab = 1, -- 1=Prof, 2=Veh, 3=Skins, 4=Armas
    active_locais_sub_tab = 2, -- 2=Favoritos (Interiores removido)
    theme_combo_idx = imgui.ImInt(0),
    online_filter_idx = imgui.ImInt(0),
    search_text = imgui.ImBuffer(256),
    current_sort_column = "ID",
    sort_direction = 1,
    target_id_buf = imgui.ImBuffer(8),
    ammo_amount_buf = imgui.ImBuffer(8),
    saved_pos_name = imgui.ImBuffer(32),
    ip_extractor_active = false,
    ip_extractor_total_buf = imgui.ImBuffer(5),
    ip_extractor_current = 0,
    ip_extractor_check_dupes = imgui.ImBool(false),
    extracted_ips = {},
    ip_req_queue = {},
    player_ips = {}, -- Armazena IPs capturados: [id] = {ip="...", nick="..."}
    device_scanner_active = false,
    current_scan_info = nil, -- {id=..., name=...}
    scan_response_received = false,
    player_devices = {}, -- [id] = "PC" or "Mobile"
    device_scan_progress = 0,
    scan_message_count = 0,
    stop_spec_requested = false,
    admin_pass_buf = imgui.ImBuffer(64),
    auto_cheat_check = imgui.ImBool(false),
    active_prof_veh_filter = nil,
}
state.ammo_amount_buf.v = "500"
state.ip_extractor_total_buf.v = "300"

local max_players = 300

-- Configuração e Temas
local inicfg = require 'inicfg'
local cfg_default = {
    main = {
        theme = "Padrao",
        transparency = 0.98,
        admin_pass = "7N0YU3EuhT",
        bind = 123, -- F12
        auto_cheat = false,
        check_updates = true
    },
    blacklist = {}
}
local cfg = inicfg.load(cfg_default, "PainelInfoHelper_Config.ini")
if not cfg then
    cfg = cfg_default
    inicfg.save(cfg, "PainelInfoHelper_Config.ini")
end
if not cfg.main then cfg.main = cfg_default.main end
if not cfg.main.admin_pass then cfg.main.admin_pass = cfg_default.main.admin_pass end
if not cfg.main.bind then cfg.main.bind = 123 end
if cfg.main.auto_cheat == nil then cfg.main.auto_cheat = false end
if cfg.main.check_updates == nil then cfg.main.check_updates = true end
if not cfg.main.esp_distance then cfg.main.esp_distance = 6000 end
if not cfg.blacklist then cfg.blacklist = {} end

-- LISTA DE TEMAS
local theme_list = {"Padrao", "Claro", "Roxo", "Vermelho", "Verde", "Laranja", "Amarelo", "Escuro"}
local online_filters = {"Todos", "PC", "Mobile", "Mafia", "Honestas"}
local key_names = {}
for k, v in pairs(vkeys) do key_names[v] = k end
local waiting_for_bind = false
state.admin_pass_buf.v = cfg.main.admin_pass
state.auto_cheat_check.v = cfg.main.auto_cheat

-- CONFIGURAÇÃO DE ADMIN (Mantida para visualização de staff online)
local staff_by_rank = {
    Desenvolvedor = { "LKWilliam" },
    Direcao = { ".42.", "Boris", "LucasFirmino" },
    Coordenador = { "Dog.", "Cleyton.", "MatheusUnity", "DiegoN_", "DaviL" },
    Administrador = { "Mirian", "TomRedl.", "KrugeR.", "Ryu." },
    Moderador = { ".Lacta", "Belo", "Rafael82", "MateusVictor", "chukc", "Dr.Manhattan_.", "Lucasfuj", "Davi.", "LeonardoX", "Caua.." },
    Ajudante = { "Koyama.", "ZeGotinha_.", "Uberzitoh", "NotoriousBIG", "Liima.", "Scheppard", ".RagnaroK", "Faggio", "YuriUnity." },
    ["Estagiario"] = { "D0uglitas", "Duarte.Tm", "MitoMitoso", ".PATCHENCO", ".BS", "Freitas_" }
}
local staff_nick_to_rank_map = {}
for rank, nicks in pairs(staff_by_rank) do
    for _, nick in ipairs(nicks) do
        staff_nick_to_rank_map[string.lower(nick)] = rank
    end
end

local rank_color_map = {
    Moderador = imgui.ImVec4(1.0, 0.5, 0.0, 1.0),
    Coordenador = imgui.ImVec4(0.6, 0.18, 1.0, 1.0),
    Direcao = imgui.ImVec4(0.75, 0.0, 0.0, 1.0),
    Administrador = imgui.ImVec4(0.18, 0.6, 1.0, 1.0),
    Ajudante = imgui.ImVec4(1.0, 1.0, 0.0, 1.0),
    Desenvolvedor = imgui.ImVec4(0.03, 0.54, 0.03, 1.0),
    ["Estagiario"] = imgui.ImVec4(0.627, 0.321, 0.176, 1.0),
    Default = imgui.ImVec4(1.0, 0.4, 0.4, 1.0)
}
local display_rank_map = { ["Estagiario"] = "Estagiario" }

local vehicles = { {id = 417, name = "Leviathan", price = 230000, speed = 153, type = "Aereo"}, {id = 469, name = "Sparrow", price = 180000, speed = 132, type = "Aereo"}, {id = 487, name = "Maverick", price = 220000, speed = 179, type = "Aereo"}, {id = 511, name = "Beagle", price = 200000, speed = 130, type = "Aereo"}, {id = 607, name = "Cropduster", price = 130000, speed = 125, type = "Aereo"}, {id = 513, name = "Stuntplane", price = 160000, speed = 149, type = "Aereo"}, {id = 519, name = "Shamal", price = 1500000, speed = 272, type = "Aereo"}, {id = 592, name = "Dodo", price = 100000, speed = 145, type = "Aereo"}, {id = 460, name = "Skimmer", price = 105000, speed = 144, type = "Aereo/Nautico"}, {id = 593, name = "Andromada", price = 0, speed = 272, type = "Aereo"}, {id = 594, name = "Nevada", price = 0, speed = 198, type = "Aereo"}, {id = 520, name = "Hydra", price = 0, speed = 272, type = "Aereo"}, {id = 548, name = "Cargobob", price = 0, speed = 158, type = "Aereo"}, {id = 563, name = "Raindance", price = 0, speed = 163, type = "Aereo"}, {id = 425, name = "Hunter", price = 0, speed = 210, type = "Aereo"}, {id = 446, name = "Squalo", price = 220000, speed = 243, type = "Nautico"}, {id = 452, name = "Speeder", price = 180000, speed = 235, type = "Nautico"}, {id = 454, name = "Tropic", price = 300000, speed = 132, type = "Nautico"}, {id = 473, name = "Dinghy", price = 10000, speed = 106, type = "Nautico"}, {id = 484, name = "Marquis", price = 230000, speed = 62, type = "Nautico"}, {id = 493, name = "Jetmax", price = 240000, speed = 181, type = "Nautico"}, {id = 539, name = "Vortex", price = 250000, speed = 100, type = "Nautico/Terrestre"}, {id = 453, name = "Reefer", price = 0, speed = 54, type = "Nautico"}, {id = 430, name = "Predator", price = 0, speed = 186, type = "Nautico"}, {id = 400, name = "Landstalker", price = 45000, speed = 159, type = "Terrestre"}, {id = 401, name = "Bravura", price = 20000, speed = 148, type = "Terrestre"}, {id = 402, name = "Buffalo", price = 25000, speed = 187, type = "Terrestre"}, {id = 403, name = "Linerunner", price = 220000, speed = 111, type = "Terrestre"}, {id = 404, name = "Perennial", price = 28000, speed = 133, type = "Terrestre"}, {id = 405, name = "Sentinel", price = 23000, speed = 165, type = "Terrestre"}, {id = 408, name = "Trashmaster", price = 60000, speed = 100, type = "Terrestre"}, {id = 409, name = "Stretch", price = 110000, speed = 159, type = "Terrestre"}, {id = 410, name = "Manana", price = 16000, speed = 130, type = "Terrestre"}, {id = 411, name = "Infernus", price = 200000, speed = 223, type = "Terrestre"}, {id = 412, name = "Voodoo", price = 42000, speed = 169, type = "Terrestre"}, {id = 413, name = "Pony", price = 50000, speed = 111, type = "Terrestre"}, {id = 414, name = "Mule", price = 55000, speed = 106, type = "Terrestre"}, {id = 415, name = "Cheetah", price = 40000, speed = 193, type = "Terrestre"}, {id = 418, name = "Moonbeam", price = 61000, speed = 116, type = "Terrestre"}, {id = 419, name = "Esperanto", price = 34000, speed = 150, type = "Terrestre"}, {id = 421, name = "Washington", price = 28000, speed = 154, type = "Terrestre"}, {id = 422, name = "Bobcat", price = 42000, speed = 141, type = "Terrestre"}, {id = 424, name = "BF Injection", price = 12000, speed = 136, type = "Terrestre"}, {id = 426, name = "Premier", price = 19000, speed = 174, type = "Terrestre"}, {id = 429, name = "Banshee", price = 50000, speed = 203, type = "Terrestre"}, {id = 431, name = "Bus", price = 330000, speed = 131, type = "Terrestre"}, {id = 434, name = "Hotknife", price = 53000, speed = 168, type = "Terrestre"}, {id = 436, name = "Previon", price = 22000, speed = 150, type = "Terrestre"}, {id = 437, name = "Coach", price = 350000, speed = 158, type = "Terrestre"}, {id = 439, name = "Stallion", price = 21000, speed = 169, type = "Terrestre"}, {id = 440, name = "Rumpo", price = 38000, speed = 137, type = "Terrestre"}, {id = 442, name = "Romero", price = 18000, speed = 140, type = "Terrestre"}, {id = 443, name = "Packer", price = 150000, speed = 124, type = "Terrestre"}, {id = 444, name = "Monster", price = 81000, speed = 111, type = "Terrestre"}, {id = 445, name = "Admiral", price = 15000, speed = 165, type = "Terrestre"}, {id = 451, name = "Turismo", price = 190000, speed = 194, type = "Terrestre"}, {id = 455, name = "Flatbed", price = 80000, speed = 158, type = "Terrestre"}, {id = 456, name = "Yankee", price = 70000, speed = 106, type = "Terrestre"}, {id = 458, name = "Solair", price = 32000, speed = 158, type = "Terrestre"}, {id = 459, name = "Berkleys RC Van", price = 48000, speed = 137, type = "Terrestre"}, {id = 461, name = "PCJ-600", price = 15000, speed = 162, type = "Terrestre"}, {id = 462, name = "Faggio", price = 4000, speed = 111, type = "Terrestre"}, {id = 463, name = "Freeway", price = 50000, speed = 104, type = "Terrestre"}, {id = 466, name = "Glendale", price = 34000, speed = 148, type = "Terrestre"}, {id = 467, name = "Oceanic", price = 38000, speed = 141, type = "Terrestre"}, {id = 468, name = "Sanchez", price = 8000, speed = 145, type = "Terrestre"}, {id = 471, name = "Quad", price = 10000, speed = 110, type = "Terrestre"}, {id = 474, name = "Hermes", price = 33000, speed = 150, type = "Terrestre"}, {id = 475, name = "Sabre", price = 30000, speed = 174, type = "Terrestre"}, {id = 477, name = "ZR-350", price = 150000, speed = 187, type = "Terrestre"}, {id = 478, name = "Walton", price = 32000, speed = 118, type = "Terrestre"}, {id = 479, name = "Regina", price = 28000, speed = 141, type = "Terrestre"}, {id = 480, name = "Comet", price = 20000, speed = 185, type = "Terrestre"}, {id = 481, name = "BMX", price = 500, speed = 97, type = "Terrestre"}, {id = 482, name = "Burrito", price = 58000, speed = 157, type = "Terrestre"}, {id = 483, name = "Camper", price = 28000, speed = 123, type = "Terrestre"}, {id = 489, name = "Rancher", price = 54000, speed = 140, type = "Terrestre"}, {id = 491, name = "Virgo", price = 38000, speed = 150, type = "Terrestre"}, {id = 492, name = "Greenwood", price = 31000, speed = 141, type = "Terrestre"}, {id = 494, name = "Hotring Racer", price = 160000, speed = 216, type = "Terrestre"}, {id = 495, name = "Sandking", price = 83000, speed = 177, type = "Terrestre"}, {id = 496, name = "Blista Compact", price = 16000, speed = 163, type = "Terrestre"}, {id = 498, name = "Boxville", price = 68000, speed = 108, type = "Terrestre"}, {id = 499, name = "Benson", price = 56000, speed = 123, type = "Terrestre"}, {id = 500, name = "Mesa", price = 40000, speed = 141, type = "Terrestre"}, {id = 502, name = "Hotring Racer 2", price = 162000, speed = 216, type = "Terrestre"}, {id = 503, name = "Hotring Racer 3", price = 164000, speed = 216, type = "Terrestre"}, {id = 504, name = "Bloodring Banger", price = 30000, speed = 174, type = "Terrestre"}, {id = 505, name = "Rancher", price = 52000, speed = 140, type = "Terrestre"}, {id = 506, name = "Super GT", price = 80000, speed = 180, type = "Terrestre"}, {id = 507, name = "Elegant", price = 29000, speed = 167, type = "Terrestre"}, {id = 508, name = "Journey", price = 110000, speed = 108, type = "Terrestre"}, {id = 509, name = "Bike", price = 300, speed = 105, type = "Terrestre"}, {id = 510, name = "Mountain Bike", price = 800, speed = 130, type = "Terrestre"}, {id = 514, name = "Tanker", price = 210000, speed = 121, type = "Terrestre"}, {id = 515, name = "Roadtrain", price = 230000, speed = 143, type = "Terrestre"}, {id = 516, name = "Nebula", price = 20000, speed = 158, type = "Terrestre"}, {id = 517, name = "Majestic", price = 22000, speed = 158, type = "Terrestre"}, {id = 518, name = "Buccaneer", price = 31000, speed = 165, type = "Terrestre"}, {id = 521, name = "FCR-900", price = 20000, speed = 162, type = "Terrestre"}, {id = 522, name = "NRG-500", price = 80000, speed = 178, type = "Terrestre"}, {id = 524, name = "Cement Truck", price = 84000, speed = 131, type = "Terrestre"}, {id = 525, name = "Towtruck", price = 66000, speed = 161, type = "Terrestre"}, {id = 526, name = "Fortune", price = 20000, speed = 158, type = "Terrestre"}, {id = 527, name = "Cadrona", price = 19000, speed = 150, type = "Terrestre"}, {id = 529, name = "Willard", price = 23000, speed = 150, type = "Terrestre"}, {id = 533, name = "Feltzer", price = 22000, speed = 168, type = "Terrestre"}, {id = 534, name = "Remington", price = 48000, speed = 169, type = "Terrestre"}, {id = 535, name = "Slamvan", price = 64000, speed = 159, type = "Terrestre"}, {id = 536, name = "Blade", price = 32000, speed = 174, type = "Terrestre"}, {id = 540, name = "Vincent", price = 25000, speed = 150, type = "Terrestre"}, {id = 541, name = "Bullet", price = 180000, speed = 204, type = "Terrestre"}, {id = 542, name = "Clover", price = 12000, speed = 165, type = "Terrestre"}, {id = 543, name = "Sadler", price = 31000, speed = 151, type = "Terrestre"}, {id = 545, name = "Hustler", price = 47000, speed = 148, type = "Terrestre"}, {id = 546, name = "Intruder", price = 28000, speed = 150, type = "Terrestre"}, {id = 547, name = "Primo", price = 20000, speed = 143, type = "Terrestre"}, {id = 549, name = "Tampa", price = 18000, speed = 154, type = "Terrestre"}, {id = 550, name = "Sunrise", price = 38000, speed = 145, type = "Terrestre"}, {id = 551, name = "Merit", price = 30000, speed = 158, type = "Terrestre"}, {id = 554, name = "Yosemite", price = 45000, speed = 144, type = "Terrestre"}, {id = 555, name = "Windsor", price = 60000, speed = 159, type = "Terrestre"}, {id = 556, name = "Monster A", price = 85000, speed = 111, type = "Terrestre"}, {id = 557, name = "Monster B", price = 88000, speed = 111, type = "Terrestre"}, {id = 558, name = "Uranus", price = 33000, speed = 157, type = "Terrestre"}, {id = 559, name = "Jester", price = 24000, speed = 179, type = "Terrestre"}, {id = 560, name = "Sultan", price = 53000, speed = 170, type = "Terrestre"}, {id = 561, name = "Stratum", price = 33000, speed = 155, type = "Terrestre"}, {id = 562, name = "Elegy", price = 62000, speed = 179, type = "Terrestre"}, {id = 565, name = "Flash", price = 30000, speed = 166, type = "Terrestre"}, {id = 566, name = "Tahoma", price = 26000, speed = 161, type = "Terrestre"}, {id = 567, name = "Savanna", price = 50000, speed = 174, type = "Terrestre"}, {id = 568, name = "Bandito", price = 18000, speed = 147, type = "Terrestre"}, {id = 571, name = "Kart", price = 14000, speed = 93, type = "Terrestre"}, {id = 573, name = "Dune", price = 140000, speed = 111, type = "Terrestre"}, {id = 575, name = "Broadway", price = 28000, speed = 158, type = "Terrestre"}, {id = 576, name = "Tornado", price = 45000, speed = 158, type = "Terrestre"}, {id = 578, name = "DFT-30", price = 112000, speed = 131, type = "Terrestre"}, {id = 579, name = "Huntley", price = 30000, speed = 158, type = "Terrestre"}, {id = 580, name = "Stafford", price = 30000, speed = 154, type = "Terrestre"}, {id = 581, name = "BF-400", price = 18000, speed = 152, type = "Terrestre"}, {id = 585, name = "Emperor", price = 27000, speed = 154, type = "Terrestre"}, {id = 586, name = "Wayfarer", price = 25000, speed = 145, type = "Terrestre"}, {id = 587, name = "Euros", price = 43000, speed = 166, type = "Terrestre"}, {id = 589, name = "Club", price = 30000, speed = 163, type = "Terrestre"}, {id = 600, name = "Picador", price = 38000, speed = 152, type = "Terrestre"}, {id = 602, name = "Alpha", price = 53000, speed = 170, type = "Terrestre"}, {id = 603, name = "Phoenix", price = 82000, speed = 172, type = "Terrestre"}, {id = 609, name = "Boxville", price = 72000, speed = 108, type = "Terrestre"}, {id = 457, name = "Caddy", price = 0, speed = 95, type = "Terrestre"}, {id = 531, name = "Tractor", price = 0, speed = 70, type = "Terrestre"}, {id = 532, name = "Combine Harvester", price = 0, speed = 111, type = "Terrestre"}, {id = 552, name = "Utility Van", price = 0, speed = 122, type = "Terrestre"}, {id = 428, name = "Securicar", price = 0, speed = 157, type = "Terrestre"}, {id = 448, name = "Pizzaboy", price = 0, speed = 143, type = "Terrestre"}, {id = 438, name = "Cabbie", price = 0, speed = 111, type = "Terrestre"}, {id = 420, name = "Taxi", price = 0, speed = 146, type = "Terrestre"}, {id = 490, name = "FBI Rancher", price = 0, speed = 158, type = "Terrestre"}, {id = 427, name = "Enforcer", price = 0, speed = 166, type = "Terrestre"}, {id = 596, name = "Police LS", price = 0, speed = 176, type = "Terrestre"}, {id = 597, name = "Police SF", price = 0, speed = 176, type = "Terrestre"}, {id = 598, name = "Police LV", price = 0, speed = 176, type = "Terrestre"}, {id = 523, name = "HPV1000", price = 0, speed = 152, type = "Terrestre"}, {id = 528, name = "FBI Truck", price = 0, speed = 178, type = "Terrestre"}, {id = 601, name = "S.W.A.T.", price = 0, speed = 111, type = "Terrestre"}, {id = 599, name = "Police Ranger", price = 0, speed = 159, type = "Terrestre"}, {id = 416, name = "Ambulance", price = 0, speed = 154, type = "Terrestre"}, {id = 407, name = "Fire Truck", price = 0, speed = 149, type = "Terrestre"}, {id = 512, name = "Freight", price = 0, speed = 181, type = "Terrestre"}, {id = 530, name = "Forklift", price = 0, speed = 60, type = "Terrestre"}, {id = 432, name = "Rhino", price = 0, speed = 94, type = "Terrestre"}, {id = 470, name = "Patriot", price = 0, speed = 158, type = "Terrestre"}, {id = 433, name = "Barracks", price = 0, speed = 111, type = "Terrestre"}, }
local profession_vehicles_map = {
    ["entregador de jornal"] = {"Mountain Bike"},
    ["gari"] = {"Trashmaster"},
    ["pizzaboy"] = {"Pizzaboy"},
    ["operador de empilhadeira"] = {"Caddy"},
    ["motoboy"] = {"BF-400"},
    ["pescador"] = {"Reefer"},
    ["correios"] = {"Pony"},
    ["agente funerario"] = {"Romero"},
    ["fazendeiro"] = {"Walton", "Combine Harvester", "Tractor"},
    ["mecanico"] = {"Towtruck"},
    ["eletricista"] = {"Utility Van"},
    ["meteorologista"] = {"Sanchez"},
    ["processador de petroleo"] = {"Benson"},
    ["paramedico"] = {"Ambulance"},
    ["transportador"] = {"DFT-30"},
    ["motorista de betoneira"] = {"Cement Truck"},
    ["motorista de onibus"] = {"Bus", "Coach"},
    ["caminhoneiro"] = {"Linerunner", "Roadtrain", "Tanker"},
    ["taxista"] = {"Cabbie", "Taxi", "Maverick"},
    ["maquinista"] = {"Streak", "Freight"},
    ["motorista de carro forte"] = {"Securicar"},
    ["piloto"] = {"Dodo", "Nevada", "Andromada"},
    ["guarda civil metropolitana"] = {"Securicar"},
    ["policia penal"] = {"Securicar", "Police LS", "Police LV", "Police SF"},
    ["policia militar"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus"},
    ["policia civil"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus"},
    ["delegado"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus", "Police Ranger"},
    ["policia rodoviaria estadual"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus", "Police Ranger", "Enforcer"},
    ["policia rodoviaria federal"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus", "Police Ranger", "Enforcer", "FBI Truck"},
    ["policia federal"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus", "Police Ranger", "Enforcer", "FBI Truck", "FBI Rancher", "Patriot"},
    ["marinha"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus", "Police Ranger", "Enforcer", "FBI Truck", "FBI Rancher", "Patriot", "Barracks", "Cargobob", "Rhino"},
    ["aeronautica"] = {"Securicar", "Police LS", "Police LV", "Police SF", "Infernus", "Police Ranger", "Enforcer", "FBI Truck", "FBI Rancher", "Patriot", "Barracks", "Cargobob", "Rhino", "Hunter", "Hydra"},
    ["bombeiro"] = {"Fire Truck", "Fire Truck LA"},
    ["contrabandista nautico"] = {"Squalo"},
    ["contrabandista aereo"] = {"Dodo"},
    ["chefão da mafia"] = {"Voodoo"},
    ["terrorista"] = {"Voodoo"}
}
local skins_list = { {id = 1, name = "The Truth"}, {id = 2, name = "Maccer"}, {id = 3, name = "Andre"}, {id = 4, name = "Barry \"Big Bear\" Thorne [Thin]"}, {id = 5, name = "Barry \"Big Bear\" Thorne [Big]"}, {id = 6, name = "Emmet"}, {id = 7, name = "Taxi Driver/Train Driver"}, {id = 8, name = "Janitor"}, {id = 9, name = "Normal Ped"}, {id = 10, name = "Old Woman"}, {id = 11, name = "Casino croupier"}, {id = 12, name = "Rich Woman"}, {id = 13, name = "Street Girl"}, {id = 14, name = "Normal Ped"}, {id = 15, name = "Mr.Whittaker (RS Haul Owner)"}, {id = 16, name = "Airport Ground Worker"}, {id = 17, name = "Businessman"}, {id = 18, name = "Beach Visitor"}, {id = 19, name = "DJ"}, {id = 20, name = "Rich Guy (Madd Dogg's Manager)"}, {id = 21, name = "Normal Ped"}, {id = 22, name = "Normal Ped"}, {id = 23, name = "BMXer"}, {id = 24, name = "Madd Dogg Bodyguard"}, {id = 25, name = "Madd Dogg Bodyguard"}, {id = 26, name = "Backpacker"}, {id = 27, name = "Construction Worker"}, {id = 28, name = "Drug Dealer"}, {id = 29, name = "Drug Dealer"}, {id = 30, name = "Drug Dealer"}, {id = 31, name = "Farm-Town inhabitant"}, {id = 32, name = "Farm-Town inhabitant"}, {id = 33, name = "Farm-Town inhabitant"}, {id = 34, name = "Farm-Town inhabitant"}, {id = 35, name = "Gardener"}, {id = 36, name = "Golfer"}, {id = 37, name = "Golfer"}, {id = 38, name = "Normal Ped"}, {id = 39, name = "Normal Ped"}, {id = 40, name = "Normal Ped"}, {id = 41, name = "Normal Ped"}, {id = 42, name = "Jethro"}, {id = 43, name = "Normal Ped"}, {id = 44, name = "Normal Ped"}, {id = 45, name = "Beach Visitor"}, {id = 46, name = "Normal Ped"}, {id = 47, name = "Normal Ped"}, {id = 48, name = "Normal Ped"}, {id = 49, name = "Snakehead (Da Nang)"}, {id = 50, name = "Mechanic"}, {id = 51, name = "Mountain Biker"}, {id = 52, name = "Mountain Biker"}, {id = 53, name = "Unknown"}, {id = 54, name = "Normal Ped"}, {id = 55, name = "Normal Ped"}, {id = 56, name = "Normal Ped"}, {id = 57, name = "Oriental Ped"}, {id = 58, name = "Oriental Ped"}, {id = 59, name = "Normal Ped"}, {id = 60, name = "Normal Ped"}, {id = 61, name = "Pilot"}, {id = 62, name = "Colonel Fuhrberger"}, {id = 63, name = "Prostitute"}, {id = 64, name = "Prostitute"}, {id = 65, name = "Kendl Johnson"}, {id = 66, name = "Pool Player"}, {id = 67, name = "Pool Player"}, {id = 68, name = "Priest/Preacher"}, {id = 69, name = "Normal Ped"}, {id = 70, name = "Scientist"}, {id = 71, name = "Security Guard"}, {id = 72, name = "Hippy"}, {id = 73, name = "Hippy"}, {id = 74, name = "Normal Ped"}, {id = 75, name = "Prostitute"}, {id = 76, name = "Stewardess"}, {id = 77, name = "Homeless"}, {id = 78, name = "Homeless"}, {id = 79, name = "Homeless"}, {id = 80, name = "Boxer"}, {id = 81, name = "Boxer"}, {id = 82, name = "Black Elvis"}, {id = 83, name = "White Elvis"}, {id = 84, name = "Blue Elvis"}, {id = 85, name = "Prostitute"}, {id = 86, name = "Ryder with robbery mask"}, {id = 87, name = "Stripper"}, {id = 88, name = "Normal Ped"}, {id = 89, name = "Normal Ped"}, {id = 90, name = "Jogger"}, {id = 91, name = "Rich Woman"}, {id = 92, name = "Rollerskater"}, {id = 93, name = "Normal Ped"}, {id = 94, name = "Normal Ped"}, {id = 95, name = "Normal Ped"}, {id = 96, name = "Jogger"}, {id = 97, name = "Lifeguard"}, {id = 98, name = "Normal Ped"}, {id = 99, name = "Rollerskater"}, {id = 100, name = "Biker"}, {id = 101, name = "Normal Ped"}, {id = 102, name = "Balla"}, {id = 103, name = "Balla"}, {id = 104, name = "Balla"}, {id = 105, name = "Grove Street Families"}, {id = 106, name = "Grove Street Families"}, {id = 107, name = "Grove Street Families"}, {id = 108, name = "Los Santos Vagos"}, {id = 109, name = "Los Santos Vagos"}, {id = 110, name = "Los Santos Vagos"}, {id = 111, name = "The Russian Mafia"}, {id = 112, name = "The Russian Mafia"}, {id = 113, name = "The Russian Mafia"}, {id = 114, name = "Varios Los Aztecas"}, {id = 115, name = "Varios Los Aztecas"}, {id = 116, name = "Varios Los Aztecas"}, {id = 117, name = "Triad"}, {id = 118, name = "Triad"}, {id = 119, name = "Johhny Sindacco"}, {id = 120, name = "Triad Boss"}, {id = 121, name = "Da Nang Boy"}, {id = 122, name = "Da Nang Boy"}, {id = 123, name = "Da Nang Boy"}, {id = 124, name = "The Mafia"}, {id = 125, name = "The Mafia"}, {id = 126, name = "The Mafia"}, {id = 127, name = "The Mafia"}, {id = 128, name = "Farm Inhabitant"}, {id = 129, name = "Farm Inhabitant"}, {id = 130, name = "Farm Inhabitant"}, {id = 131, name = "Farm Inhabitant"}, {id = 132, name = "Farm Inhabitant"}, {id = 133, name = "Farm Inhabitant"}, {id = 134, name = "Homeless"}, {id = 135, name = "Homeless"}, {id = 136, name = "Normal Ped"}, {id = 137, name = "Homeless"}, {id = 138, name = "Beach Visitor"}, {id = 139, name = "Beach Visitor"}, {id = 140, name = "Beach Visitor"}, {id = 141, name = "Businesswoman"}, {id = 142, name = "Taxi Driver"}, {id = 143, name = "Crack Maker"}, {id = 144, name = "Crack Maker"}, {id = 145, name = "Crack Maker"}, {id = 146, name = "Crack Maker"}, {id = 147, name = "Businessman"}, {id = 148, name = "Businesswoman"}, {id = 149, name = "Big Smoke Armored"}, {id = 150, name = "Businesswoman"}, {id = 151, name = "Normal Ped"}, {id = 152, name = "Prostitute"}, {id = 153, name = "Construction Worker"}, {id = 154, name = "Beach Visitor"}, {id = 155, name = "Well Stacked Pizza Worker"}, {id = 156, name = "Barber"}, {id = 157, name = "Hillbilly"}, {id = 158, name = "Farmer"}, {id = 159, name = "Hillbilly"}, {id = 160, name = "Hillbilly"}, {id = 161, name = "Farmer"}, {id = 162, name = "Hillbilly"}, {id = 163, name = "Black Bouncer"}, {id = 164, name = "White Bouncer"}, {id = 165, name = "White MIB agent"}, {id = 166, name = "Black MIB agent"}, {id = 167, name = "Cluckin' Bell Worker"}, {id = 168, name = "Hotdog/Chilli Dog Vendor"}, {id = 169, name = "Normal Ped"}, {id = 170, name = "Normal Ped"}, {id = 171, name = "Blackjack Dealer"}, {id = 172, name = "Casino croupier"}, {id = 173, name = "San Fierro Rifa"}, {id = 174, name = "San Fierro Rifa"}, {id = 175, name = "San Fierro Rifa"}, {id = 176, name = "Barber"}, {id = 177, name = "Barber"}, {id = 178, name = "Whore"}, {id = 179, name = "Ammunation Salesman"}, {id = 180, name = "Tattoo Artist"}, {id = 181, name = "Punk"}, {id = 182, name = "Cab Driver"}, {id = 183, name = "Normal Ped"}, {id = 184, name = "Normal Ped"}, {id = 185, name = "Normal Ped"}, {id = 186, name = "Normal Ped"}, {id = 187, name = "Businessman"}, {id = 188, name = "Normal Ped"}, {id = 189, name = "Valet"}, {id = 190, name = "Barbara Schternvart"}, {id = 191, name = "Helena Wankstein"}, {id = 192, name = "Michelle Cannes"}, {id = 193, name = "Katie Zhan"}, {id = 194, name = "Millie Perkins"}, {id = 195, name = "Denise Robinson"}, {id = 196, name = "Farm-Town inhabitant"}, {id = 197, name = "Hillbilly"}, {id = 198, name = "Farm-Town inhabitant"}, {id = 199, name = "Farm-Town inhabitant"}, {id = 200, name = "Hillbilly"}, {id = 201, name = "Farmer"}, {id = 202, name = "Farmer"}, {id = 203, name = "Karate Teacher"}, {id = 204, name = "Karate Teacher"}, {id = 205, name = "Burger Shot Cashier"}, {id = 206, name = "Cab Driver"}, {id = 207, name = "Prostitute"}, {id = 208, name = "Su Xi Mu (Suzie)"}, {id = 209, name = "Oriental Noodle stand vendor"}, {id = 210, name = "Oriental Boating School Instructor"}, {id = 211, name = "Clothes shop staff"}, {id = 212, name = "Homeless"}, {id = 213, name = "Weird old man"}, {id = 214, name = "Waitress (Maria Latore)"}, {id = 215, name = "Normal Ped"}, {id = 216, name = "Normal Ped"}, {id = 217, name = "Clothes shop staff"}, {id = 218, name = "Normal Ped"}, {id = 219, name = "Rich Woman"}, {id = 220, name = "Cab Driver"}, {id = 221, name = "Normal Ped"}, {id = 222, name = "Normal Ped"}, {id = 223, name = "Normal Ped"}, {id = 224, name = "Normal Ped"}, {id = 225, name = "Normal Ped"}, {id = 226, name = "Normal Ped"}, {id = 227, name = "Oriental Businessman"}, {id = 228, name = "Oriental Ped"}, {id = 229, name = "Oriental Ped"}, {id = 230, name = "Homeless"}, {id = 231, name = "Normal Ped"}, {id = 232, name = "Normal Ped"}, {id = 233, name = "Normal Ped"}, {id = 234, name = "Cab Driver"}, {id = 235, name = "Normal Ped"}, {id = 236, name = "Normal Ped"}, {id = 237, name = "Prostitute"}, {id = 238, name = "Prostitute"}, {id = 239, name = "Homeless"}, {id = 240, name = "The D.A"}, {id = 241, name = "Afro-American"}, {id = 242, name = "Mexican"}, {id = 243, name = "Prostitute"}, {id = 244, name = "Stripper"}, {id = 245, name = "Prostitute"}, {id = 246, name = "Stripper"}, {id = 247, name = "Biker"}, {id = 248, name = "Biker"}, {id = 249, name = "Pimp"}, {id = 250, name = "Normal Ped"}, {id = 251, name = "Lifeguard"}, {id = 252, name = "Naked Valet"}, {id = 253, name = "Bus Driver"}, {id = 254, name = "Biker Drug Dealer"}, {id = 255, name = "Chauffeur (Limo Driver)"}, {id = 256, name = "Stripper"}, {id = 257, name = "Stripper"}, {id = 258, name = "Heckler"}, {id = 259, name = "Heckler"}, {id = 260, name = "Construction Worker"}, {id = 261, name = "Cab driver"}, {id = 262, name = "Cab driver"}, {id = 263, name = "Normal Ped"}, {id = 264, name = "Clown (Ice-cream Van Driver)"}, {id = 265, name = "Officer Frank Tenpenny (Corrupt Cop)"}, {id = 266, name = "Officer Eddie Pulaski (Corrupt Cop)"}, {id = 267, name = "Officer Jimmy Hernandez"}, {id = 268, name = "Dwaine/Dwayne"}, {id = 269, name = "Melvin \"Big Smoke\" Harris (Mission)"}, {id = 270, name = "Sean 'Sweet' Johnson"}, {id = 271, name = "Lance 'Ryder' Wilson"}, {id = 272, name = "Mafia Boss"}, {id = 273, name = "T-Bone Mendez"}, {id = 274, name = "Paramedic (EMT)"}, {id = 275, name = "Paramedic (EMT)"}, {id = 276, name = "Paramedic (EMT)"}, {id = 277, name = "Firefighter"}, {id = 278, name = "Firefighter"}, {id = 279, name = "Firefighter"}, {id = 280, name = "Los Santos Police Officer"}, {id = 281, name = "San Fierro Police Officer"}, {id = 282, name = "Las Venturas Police Officer"}, {id = 283, name = "County Sheriff"}, {id = 284, name = "LSPD Motorbike Cop"}, {id = 285, name = "S.W.A.T Special Forces"}, {id = 286, name = "FBI Agent"}, {id = 287, name = "San Andreas Army Soldier"}, {id = 288, name = "Desert Sheriff"}, {id = 289, name = "Zero"}, {id = 290, name = "Ken Rosenberg"}, {id = 291, name = "Kent Paul"}, {id = 292, name = "Cesar Vialpando"}, {id = 293, name = "Jeffery \"OG Loc\" Martin/Cross"}, {id = 294, name = "Wu Zi Mu (Woozie)"}, {id = 295, name = "Michael Toreno (Mike)"}, {id = 296, name = "Jizzy B."}, {id = 297, name = "Madd Dogg"}, {id = 298, name = "Catalina"}, {id = 299, name = "Claude Speed"}, {id = 300, name = "LSPD Officer (No holster)"}, {id = 301, name = "SFPD Officer (No holster)"}, {id = 302, name = "LVPD Officer (No holster)"}, {id = 303, name = "LSPD Officer (No uniform)"}, {id = 304, name = "LSPD Officer (No uniform)"}, {id = 305, name = "LVPD Officer (No uniform)"}, {id = 306, name = "LSPD Officer"}, {id = 307, name = "SFPD Officer"}, {id = 308, name = "SF Paramedic (EMT)"}, {id = 309, name = "LVPD Officer"}, {id = 310, name = "Country Sheriff (No hat)"}, {id = 311, name = "Desert Sheriff (No hat)"}, }
local skin_search_map = {}; for _, s in ipairs(skins_list) do skin_search_map[s.id] = (s.name or ""):lower() end
local professions = { { name = "Entregador de Jornal", level = 0, salary = 1000, type = "Legal" }, { name = "Gari", level = 0, salary = 1000, type = "Legal" }, { name = "PizzaBoy", level = 0, salary = 1000, type = "Legal" }, { name = "Vendedor de Rua", level = 2, salary = 1020, type = "Legal" }, { name = "Operador de Empilhadeira", level = 4, salary = 1040, type = "Legal" }, { name = "MotoBoy", level = 6, salary = 1060, type = "Legal" }, { name = "Lenhador", level = 10, salary = 1100, type = "Legal" }, { name = "Pescador", level = 15, salary = 1150, type = "Legal" }, { name = "Correios", level = 20, salary = 1200, type = "Legal" }, { name = "Agente Funerario", level = 25, salary = 1250, type = "Legal" }, { name = "Fazendeiro", level = 30, salary = 1300, type = "Legal" }, { name = "Mecanico", level = 35, salary = 1350, type = "Legal" }, { name = "Eletricista", level = 40, salary = 1400, type = "Legal" }, { name = "Meteorologista", level = 60, salary = 1600, type = "Legal" }, { name = "Processador de Petroleo", level = 80, salary = 1800, type = "Legal" }, { name = "Advogado", level = 100, salary = 2000, type = "Legal" }, { name = "Paramedico", level = 150, salary = 2500, type = "Legal" }, { name = "Transportador", level = 3, salary = 1030, type = "Legal" }, { name = "Motorista de Betoneira", level = 5, salary = 1050, type = "Legal" }, { name = "Motorista de Onibus", level = 7, salary = 1070, type = "Legal" }, { name = "Caminhoneiro", level = 9, salary = 1090, type = "Legal" }, { name = "Taxista", level = 12, salary = 1120, type = "Legal" }, { name = "Maquinista", level = 17, salary = 1170, type = "Legal" }, { name = "Motorista de Carro Forte", level = 85, salary = 1850, type = "Legal" }, { name = "Piloto", level = 200, salary = 3000, type = "Legal" }, { name = "Seguranca de Carro Forte", level = 80, salary = 2800, type = "Legal" }, { name = "Guarda Civil Metropolitana", level = 100, salary = 3000, type = "Legal" }, { name = "Policia Penal", level = 200, salary = 3400, type = "Legal" }, { name = "Policia Militar", level = 300, salary = 3800, type = "Legal" }, { name = "Policia Civil", level = 400, salary = 4200, type = "Legal" }, { name = "Delegado", level = 500, salary = 4600, type = "Legal" }, { name = "Policia Rodoviaria Estadual", level = 600, salary = 5000, type = "Legal" }, { name = "Policia Rodoviaria Federal", level = 700, salary = 5400, type = "Legal" }, { name = "Policia Federal", level = 800, salary = 5800, type = "Legal" }, { name = "Bombeiro", level = 200, salary = 6300, type = "Legal" }, { name = "Marinha", level = 1300, salary = 6300, type = "Legal" }, { name = "Exercito", level = 1500, salary = 6500, type = "Legal" }, { name = "Aeronautica", level = 1700, salary = 6700, type = "Legal" }, { name = "Corregedoria", level = 2000, salary = 7000, type = "Legal" }, { name = "Plantador de Maconha", level = 20, salary = 0, type = "Mafia" }, { name = "Vendedor de Drogas", level = 30, salary = 0, type = "Mafia" }, { name = "Produtor de Drogas", level = 40, salary = 0, type = "Mafia" }, { name = "Ladrão de Veículos", level = 50, salary = 0, type = "Mafia" }, { name = "Vendedor de Armas", level = 60, salary = 0, type = "Mafia" }, { name = "Contrabandista Nautico", level = 100, salary = 0, type = "Mafia" }, { name = "Contrabandista Aereo", level = 150, salary = 0, type = "Mafia" }, { name = "Assassino", level = 200, salary = 0, type = "Mafia" }, { name = "Assaltante", level = 300, salary = 0, type = "Mafia" }, { name = "Terrorista", level = 1100, salary = 0, type = "Mafia" }, { name = "Chefão da Mafia", level = 2000, salary = 0, type = "Mafia" } }
for i,v in ipairs(professions) do v.id = i end
local prof_type_map = {}
for _, p in ipairs(professions) do prof_type_map[p.name:lower()] = p.type end
prof_type_map["desempregado"] = "Legal"
-- Correcao para nomes sem acento vindos da deteccao por cor
prof_type_map["ladrao de veiculos"] = "Mafia"
prof_type_map["chefao da mafia"] = "Mafia"

local weapons_list = { {id = 0, name = "Unarmed", type = "Corpo a corpo"}, {id = 1, name = "Brass Knuckles", type = "Corpo a corpo"}, {id = 2, name = "Golf Club", type = "Corpo a corpo"}, {id = 3, name = "Nite Stick", type = "Corpo a corpo"}, {id = 4, name = "Knife", type = "Corpo a corpo"}, {id = 5, name = "Baseball Bat", type = "Corpo a corpo"}, {id = 6, name = "Shovel", type = "Corpo a corpo"}, {id = 7, name = "Pool Cue", type = "Corpo a corpo"}, {id = 8, name = "Katana", type = "Corpo a corpo"}, {id = 9, name = "Chainsaw", type = "Corpo a corpo"}, {id = 10, name = "Purple Dildo", type = "Corpo a corpo"}, {id = 11, name = "Dildo", type = "Corpo a corpo"}, {id = 12, name = "Vibrator", type = "Corpo a corpo"}, {id = 13, name = "Silver Vibrator", type = "Corpo a corpo"}, {id = 14, name = "Flower", type = "Presente"}, {id = 15, name = "Cane", type = "Presente"}, {id = 16, name = "Grenade", type = "Arremessavel"}, {id = 17, name = "Tear Gas", type = "Arremessavel"}, {id = 18, name = "Molotov Cocktail", type = "Arremessavel"}, {id = 22, name = "9mm", type = "Pistola"}, {id = 23, name = "Silenced 9mm", type = "Pistola"}, {id = 24, name = "Desert Eagle", type = "Pistola"}, {id = 25, name = "Shotgun", type = "Espingarda"}, {id = 26, name = "Sawnoff Shotgun", type = "Espingarda"}, {id = 27, name = "Combat Shotgun", type = "Espingarda"}, {id = 28, name = "Micro Uzi (MP5)", type = "Submetralhadora"}, {id = 29, name = "MP5", type = "Submetralhadora"}, {id = 30, name = "AK-47", type = "Fuzil de Assalto"}, {id = 31, name = "M4", type = "Fuzil de Assalto"}, {id = 32, name = "Tec-9", type = "Submetralhadora"}, {id = 33, name = "Country Rifle", type = "Rifle"}, {id = 34, name = "Sniper Rifle", type = "Rifle"}, {id = 35, name = "RPG", type = "Pesada"}, {id = 36, name = "HS Rocket", type = "Pesada"}, {id = 37, name = "Flamethrower", type = "Pesada"}, {id = 38, name = "Minigun", type = "Pesada"}, {id = 39, name = "Satchel Charge", type = "Arremessavel"}, {id = 40, name = "Detonator", type = "Especial"}, {id = 41, name = "Spraycan", type = "Especial"}, {id = 42, name = "Fire Extinguisher", type = "Especial"}, {id = 43, name = "Camera", type = "Especial"}, {id = 44, name = "NV Goggles", type = "Especial"}, {id = 45, name = "IR Goggles", type = "Especial"}, {id = 46, name = "Parachute", type = "Especial"} }
local interiors_list = {} -- Lista vazia para versão Helper
local faq_list = {
    { q = "Tabela de Tempos de Prisao (Regras)", a = "V.A (Veiculo Agencia): 50 min\nD.M (Death Match): 30-40 min\nD.B (Drive By): 50 min\nD.R (Desrespeito): 30-50 min\nA.R (Anti-RPG): 40 min\nA.J (Anti-Jogo): 40 min\nD.V (Divulgacao): 60 min a Ban\nP.D (Proibicoes): 30-40 min\nA.T (Atrapalhar Trab.): 50-70 min\nMUC (Mau Uso Cmd): 40 min\nA.A (Atacar Aviao): 80-100 min\nC.L (Caps Lock): 20 min\nVLP (Veic Local Proibido): 80 min\nMOV (Msg Ofensiva Veic): 80 min" },
    { q = "Regras: Banimentos e Infracoes Graves", a = "Ofensa a Staff: Ban Permanente\nRacismo: 200m -> 5d -> 10d -> Perm\nCheater/Cumplice: Ban 16 dias (temp) ou Perm\nConta Fake com Propriedade: Ban 16 dias\nFree Kill em Favela/Base: Ban 16 dias\nExplosivos em Interiores: 3 a 10 dias\nMod Proibido (Arvores/Postes): 2d -> 5d -> Perm" },
    { q = "Regras: Matar Novatos (Lvl < 10)", a = "Terroristas/Assassinos: 150 min -> 2 dias\nOutras Profissoes: 100 min -> 150 min" },
    { q = "Cooldowns (Tempos de Espera)", a = "Taxi: 30s | Uber: 64s\nParamedico: 15s (Vacina: 40s)\nMecanico/Vendedor: 40s\nOLX: 50s\n/Transferir: 4 min (Max $1.000)\nRespawn Veiculo Casa: 5 min\nSair de Suspeitos: 15 min\nReparo Caixa Eletronico: 15 min\nPix / Contrato / Trocar Profissao: 30 min\nAssalto Banco: 1h\nAssalto Player/Caixa: A cada UP de XP\nMercadoria Empresa: A cada UP de Level\nLoteria: 1h\nVender Casa apos compra: 5 dias\nRecontratar funcionario: 3h\n/Arrombarporta: 3 min\nCodigo Senha/Email: 20 min" },
    { q = "Investimentos (Banco)", a = "1M-5M: 0.002% (Saque 720 lvls)\n5M-10M: 0.004% (Saque 2160 lvls)\n10M-15M: 0.006% (Saque 4320 lvls)\n15M+: 0.008% (Saque 8760 lvls)\nTaxa de saque antecipado: 20% sobre o valor investido." },
    { q = "Valores das Habilitacoes", a = "Moto: $2.000\nCarro: $3.500\nCaminhao: $6.000\nOnibus: $8.000\nCarreta: $10.000\nBarco: $25.000\nHeli: $150.000\nAviao: $200.000\nRenovacao: 50% do valor." },
    { q = "Precos Mecanico (Tabelado)", a = "Reparo: $2.500 - $4.000\nLataria: $1.200 - $3.000\nPneu: $600 - $1.000\nKit Reparo: $2.000 - $3.000 (Conveniencia: $4.800)" },
    { q = "Bases e Empresas", a = "Mini Base: $300k + 30k Coins (30 membros). Sem veiculos/DM.\nBase Grande: $500k + 50k Coins (50 membros). Com veiculos/DM.\nRenovacao: 30d (40k coins) a 120d (160k coins).\nDeposito maximo no cofre: $100k a cada 30min.\nLucro Dono Empresa: 0.1% do valor padrao por entrega." },
    { q = "Requisitos de Prisoes (Policia/Gov)", a = "PM: 100 | Civil: 200 | Delegado: 300\nPRE: 400 | PRF: 500 | PF: 600\nMarinha: 750 | Exercito: 900 | Aero: 1050\nCorregedoria: 1250" },
    { q = "Multas e CNH", a = "Perde CNH com: 21 multas.\nValores Multa: Moto $300, Carro $350, Caminhao $400, Onibus $450, Carreta $500." },
    { q = "Assalto ao Banco", a = "Porta do cofre fica aberta por: 2 minutos\nLaser do cofre volta em: 4 minutos\nTempo para abrir com /abrircofre: 30 segundos\nCooldown geral: 1 hora" },
    { q = "Regras e Sistemas Diversos", a = "Porte de Armas: Level 10\nAssalto (Vitima): Level 20+\nTop Kills: /topskill\nCores ID: /coresid\nPrisoes: /topprisoes\nMax Estrelas: 500 (3 min cada)\nParabens Level: 100, 500, 1000, 2k, 3k, 4k, 5k+" },
    { q = "Veiculos com Paintjob", a = "Sultan, Slamvan, Camper, Remington, Blade, Uranus, Jester, Stratum, Elegy, Flash, Savanna, Broadway, Tornado" },
    { q = "Denuncias e Punicoes", a = "Motivos que contam nivel de denuncia: D.B, A.R, A.J, A.T.\nD.F (Denuncia Forum) acrescenta tempo extra.\nMotivos que removem na despunicao: D.B, D.F, A.R, A.J, A.T." },
}

-- LISTA DE LOCAIS PARA EVENTOS (DEFAULT)
local default_event_locations = {
    {name = "Monte Chiliad (Topo)", x = -2325.6, y = -1620.4, z = 483.7, id = 0},
    {name = "Aeroporto Abandonado", x = 405.4, y = 2451.4, z = 16.5, id = 0},
    {name = "Area 51 (Entrada)", x = 213.8, y = 1865.5, z = 13.1, id = 0},
    {name = "Praia Santa Maria (LS)", x = 362.6, y = -2037.8, z = 7.8, id = 0},
    {name = "Glen Park (Lago)", x = 1926.3, y = -1186.6, z = 20.1, id = 0},
    {name = "Estadio 8-Track", x = -1394.2, y = -257.4, z = 1043.5, id = 7},
    {name = "Estadio Bloodring", x = -1394.2, y = 987.6, z = 1023.9, id = 15},
    {name = "Estadio Dirtring", x = -1424.9, y = -664.6, z = 1059.5, id = 4},
    {name = "Estadio Kickstart", x = -1410.7, y = 1591.2, z = 1052.5, id = 14},
    {name = "Kart (Interior)", x = -1455.9, y = 1142.3, z = 1037.5, id = 14},
    {name = "Big Ear (Antena)", x = -310.8, y = 1534.7, z = 75.5, id = 0},
    {name = "Topo Maze Bank (LS)", x = 1544.3, y = -1353.4, z = 329.4, id = 0},
    {name = "Navio Cargueiro (SF)", x = -2228.9, y = 2325.2, z = 7.5, id = 0},
    {name = "Represa Sherman", x = -738.6, y = 2062.6, z = 60.3, id = 0},
    {name = "Piramide (LV)", x = 2253.7, y = 1656.9, z = 1008.3, id = 1},
    {name = "Caligulas (Telhado)", x = 2188.8, y = 1677.6, z = 11.8, id = 0},
    {name = "Groove Street", x = 2495.1, y = -1667.3, z = 13.3, id = 0},
    {name = "Prefeitura (LS)", x = 1481.0, y = -1771.1, z = 18.7, id = 0},
    {name = "Delegacia (LS)", x = 1555.4, y = -1675.6, z = 16.1, id = 0},
    {name = "Banco (LS)", x = 1462.3, y = -1013.4, z = 26.8, id = 0},
    {name = "Aeroporto LS (Pista)", x = 1961.8, y = -2494.1, z = 13.5, id = 0},
    {name = "Aeroporto SF (Pista)", x = -1426.3, y = -292.6, z = 14.1, id = 0},
    {name = "Aeroporto LV (Pista)", x = 1596.3, y = 1447.6, z = 10.8, id = 0},
}

-- SISTEMA DE SALVAMENTO DE EVENTOS (JSON)
local events_file = getWorkingDirectory() .. "\\config\\PainelInfoHelper_Events.json"
local event_locations = {}

local function save_events()
    local f = io.open(events_file, "w")
    if f then
        f:write(encodeJson(event_locations))
        f:close()
    end
end

local function load_events()
    if doesFileExist(events_file) then
        local f = io.open(events_file, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local decoded = decodeJson(content)
            if decoded then event_locations = decoded else event_locations = default_event_locations end
        end
    else
        event_locations = default_event_locations
        save_events()
    end
end
load_events()

-- CORES IMGUI PADRÃO E FUNÇÕES UTILITÁRIAS
local IMAGE_RED = imgui.ImVec4(1, 0, 0, 1)
local IMAGE_GREEN = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
local IMAGE_BLUE = imgui.ImVec4(0, 0.75, 1, 1)
local IMAGE_YELLOW = imgui.ImVec4(1, 1, 0, 1)
local IMAGE_WHITE = imgui.ImVec4(1, 1, 1, 1)
local IMAGE_GREY = imgui.ImVec4(0.5, 0.5, 0.5, 1)
local IMAGE_PINK = imgui.ImVec4(1, 0.4, 0.8, 1)
local IMAGE_BLACK = imgui.ImVec4(0, 0, 0, 1)

-- DETECCAO POR COR
local profession_colors_hex = { ["desempregado"] = 0xFFFFFFFF, ["entregador de jornal"] = 0xFFBEF781, ["gari"] = 0xFFB45F04, ["pizzaboy"] = 0xFFFAAC58, ["vendedor de rua"] = 0xFF00EE00, ["operador de empilhadeira"] = 0xFFBDBDBD, ["motoboy"] = 0xFF3CB671, ["leiteiro"] = 0xFFE6E6E6, ["lenhador"] = 0xFFA99C68, ["pescador"] = 0xFF00E2EE, ["correios"] = 0xFFEECA00, ["agente funerario"] = 0xFF863E14, ["fazendeiro"] = 0xFFBFB838, ["mecanico"] = 0xFF8B6969, ["eletricista"] = 0xFFEEDB82, ["meteorologista"] = 0xFF04B45F, ["processador de petroleo"] = 0xFF848484, ["advogado"] = 0xFF751EBC, ["paramedico"] = 0xFF58FAAC, ["transportador"] = 0xFF14A21B, ["motorista de betoneira"] = 0xFF696969, ["motorista de onibus"] = 0xFF0B6138, ["caminhoneiro"] = 0xFF585858, ["taxista"] = 0xFFFCFF00, ["maquinista"] = 0xFFFF8A68, ["motorista de carro forte"] = 0xFFCED8F6, ["piloto"] = 0xFF2A8C9F, ["seguranca de carro forte"] = 0xFFA9D0F5, ["guarda civil metropolitana"] = 0xFF64D4F9, ["policia penal"] = 0xFF00B3EE, ["policia militar"] = 0xFF2E9AFE, ["policia"] = 0xFF2E9AFE, ["policia civil"] = 0xFF2E64FE, ["delegado"] = 0xFF3A60CD, ["policia rodoviaria estadual"] = 0xFF5858FA, ["policia rodoviaria federal"] = 0xFF013ADF, ["policia federal"] = 0xFF3104B4, ["marinha"] = 0xFF2323BB, ["exercito"] = 0xFF2F4F4F, ["aeronautica"] = 0xFF8D840C, ["bombeiro"] = 0xFFFF8000, ["corregedoria"] = 0xFF363D75, ["plantador de maconha"] = 0xFFFFCCCC, ["vendedor de drogas"] = 0xFFFF9999, ["produtor de drogas"] = 0xFFFF6666, ["ladrao de veiculos"] = 0xFFFE4040, ["vendedor de armas"] = 0xFFDE2222, ["contrabandista nautico"] = 0xFFFF0000, ["contrabandista aereo"] = 0xFFFF0000, ["assassino"] = 0xFFC40202, ["assaltante"] = 0xFF990000, ["terrorista"] = 0xFF691313, ["chefao da mafia"] = 0xFF600000 }

local function extract_rgb(argb)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return r, g, b
end
local function capitalize_each_word(str)
    if not str then return "" end
    local r = str:gsub("(%a)([%w']*)", function(f, rest) return f:upper() .. rest:lower() end)
    r = r:gsub(" De ", " de ")
    return r
end
local function get_closest_profession_name(argb)
    if not argb then return "?" end
    if argb == 0xFFFFFFFF then return "Desempregado" end
    local pr, pg, pb = extract_rgb(argb)
    local min_d = math.huge
    local key = "Desempregado"
    for pk, ph in pairs(profession_colors_hex) do
        local cr, cg, cb = extract_rgb(ph)
        local dr = pr - cr
        local dg = pg - cg
        local db = pb - cb
        local d = dr * dr + dg * dg + db * db
        if d < min_d then
            min_d = d
            key = pk
        end
    end
    if min_d > 70 * 70 then return "Desempregado" end
    return capitalize_each_word(key)
end

local function convert_samp_color(argb)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return imgui.ImVec4(r / 255, g / 255, b / 255, 1.0)
end

local function remove_accents(str)
    if not str then return "" end
    local s = str:lower()
    s = s:gsub("[\224\225\226\227]", "a") -- áàâã
    s = s:gsub("[\232\233\234]", "e")     -- éê
    s = s:gsub("[\236\237]", "i")         -- í
    s = s:gsub("[\242\243\244\245]", "o") -- óôõ
    s = s:gsub("[\249\250]", "u")         -- ú
    s = s:gsub("[\231]", "c")             -- ç
    return s
end

local function draw_player_header()
    local idw=35; local nickw=130; local profw=150; local lvlw=40; local pingw=110
    local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]
    local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nickw
    local align_offset = imgui.GetStyle().FramePadding.x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + align_offset); imgui.Text("ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text("Nick")
    local p3ps=p2s+sw+sp; local p3s=p3ps+profw
    imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps); imgui.Text("Profissao / Cargo")
    local p4ls=p3s+sw+sp
    imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4ls); imgui.Text("Nivel")
    local p4s=p4ls+lvlw; local p5ps=p4s+sw+sp; imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ps); imgui.Text("Ping")
    local p5s=p5ps+pingw; local p6is=p5s+sw+sp; imgui.SameLine(p5s); imgui.TextColored(sc,st); imgui.SameLine(p6is); imgui.Text("IP")
    imgui.Separator()
end

local function get_display_rank(k) return display_rank_map[k] or k end
local function get_rank_color(k) return rank_color_map[k] or rank_color_map.Default end
local function formatPrice(n)
    if not n or n == 0 then return "0" end
    local s = tostring(n)
    local d = ""
    while #s > 3 do
        d = "." .. string.sub(s, -3) .. d
        s = string.sub(s, 1, -4)
    end
    return s .. d
end

local function logFoundIP(text)
    pcall(function()
        local dir = getWorkingDirectory() .. "\\logs ip"
        if not doesDirectoryExist(dir) then createDirectory(dir) end
        local date_str = os.date("%Y-%m-%d")
        local p = dir .. "\\PainelInfo_ExtractedIPs_" .. date_str .. ".txt"
        local t = os.date("[%Y-%m-%d %H:%M:%S]")
        local f = io.open(p, "a+")
        if f then
            f:write(t .. " " .. text .. "\n")
            f:close()
        end
    end)
end

local function saveDuplicatesReport()
    pcall(function()
        local dir = getWorkingDirectory() .. "\\logs ip"
        if not doesDirectoryExist(dir) then createDirectory(dir) end
        local p = dir .. "\\PainelInfo_Duplicates.txt"
        local f = io.open(p, "w")
        if f then
            f:write("Relatorio de IPs Duplicados - " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n")
            f:write("=================================================\n")
            local found_dupes = false
            for ip, entries in pairs(state.extracted_ips) do
                if #entries > 1 then
                    found_dupes = true
                    f:write("IP: " .. ip .. " (Encontrado " .. #entries .. " vezes)\n")
                    for _, entry in ipairs(entries) do
                        if entry.info then
                            f:write("  -> Conta: " .. entry.info.name .. " (ID: " .. entry.info.id .. ")\n")
                        else
                            f:write("  -> " .. entry.txt .. "\n")
                        end
                    end
                    f:write("-------------------------------------------------\n")
                end
            end
            if not found_dupes then f:write("Nenhum IP duplicado encontrado nesta sessao.\n") end
            f:close()
            sampAddChatMessage("[PI] Relatorio de duplicados salvo em: logs ip\\PainelInfo_Duplicates.txt", -1)
        end
    end)
end

-- FUNÇÕES DE FILTRAGEM
local function filter_professions(l, t)
    local f = {}
    local tl = t:lower()
    local tn = tonumber(t)
    for _, p in ipairs(l) do
        local nl = (p.name or ""):lower()
        local lvln = p.level or 0
        local lvls = tostring(lvln)
        local saln = p.salary or 0
        local sals = tostring(saln)
        if (nl:find(tl, 1, true) or lvls:find(tl, 1, true) or sals:find(tl, 1, true) or (tn and lvln == tn) or (tn and saln == tn)) then
            table.insert(f, p)
        end
    end
    table.sort(f, function(a, b) return (a.level or 0) < (b.level or 0) end)
    return f
end

local function filter_vehicles(l, t, scol, sdir)
    local f = {}
    local tl = t:lower()
    for _, v in ipairs(l) do
        local ids = tostring(v.id or "")
        local nl = (v.name or ""):lower()
        local typl = (v.type or ""):lower()
        local ps = tostring(v.price or "")
        local sps = tostring(v.speed or "")
        if (ids:find(tl, 1, true) or nl:find(tl, 1, true) or typl:find(tl, 1, true) or ps:find(tl, 1, true) or sps:find(tl, 1, true)) then
            table.insert(f, v)
        end
    end
    pcall(table.sort, f, function(a, b)
        local va, vb
        local isnum = false
        if scol == "ID" then va = a.id; vb = b.id; isnum = true
        elseif scol == "Nome" then va = a.name; vb = b.name
        elseif scol == "Preco" then va = a.price; vb = b.price; isnum = true
        elseif scol == "Velocidade" then va = a.speed; vb = b.speed; isnum = true
        elseif scol == "Tipo" then va = a.type; vb = b.type
        else return false end
        if isnum then
            if type(va) ~= "number" then va = 0 end
            if type(vb) ~= "number" then vb = 0 end
        else
            if type(va) ~= "string" then va = "" end
            if type(vb) ~= "string" then vb = "" end
            va = va:lower(); vb = vb:lower()
        end
        local res
        if va < vb then res = true elseif va > vb then res = false else return false end
        return sdir == -1 and not res or res
    end)
    return f
end

local function filter_skins(t)
    local f = {}
    local tl = t:lower()
    for _, s in ipairs(skins_list) do
        local id_str = tostring(s.id)
        local name_lower = (s.name or ""):lower()
        if (id_str:find(tl, 1, true) or name_lower:find(tl, 1, true)) then
            table.insert(f, s)
        end
    end
    pcall(table.sort, f, function(a, b) return (a.id or -1) < (b.id or -1) end)
    return f
end

local function filter_weapons(l, t)
    local f = {}
    local tl = t:lower()
    for _, w in ipairs(l) do
        local ids = tostring(w.id or "")
        local nl = (w.name or ""):lower()
        local typl = (w.type or ""):lower()
        if (ids:find(tl, 1, true) or nl:find(tl, 1, true) or typl:find(tl, 1, true)) then
            table.insert(f, w)
        end
    end
    pcall(table.sort, f, function(a, b) return (a.id or -1) < (b.id or -1) end)
    return f
end

local function filter_interiors(l, t)
    local f = {}
    local tl = t:lower()
    for _, i in ipairs(l) do
        local nl = (i.name or ""):lower()
        local ids = tostring(i.id or "")
        local xs = string.format("%.1f", i.x or 0)
        local ys = string.format("%.1f", i.y or 0)
        local zs = string.format("%.1f", i.z or 0)
        if (nl:find(tl, 1, true) or ids:find(tl, 1, true) or xs:find(tl, 1, true) or ys:find(tl, 1, true) or zs:find(tl, 1, true)) then
            table.insert(f, i)
        end
    end
    pcall(table.sort, f, function(a, b) return (a.id or -1) < (b.id or -1) end)
    return f
end

-- FUNCAO LOGICA DO ESP (DESENHO NA TELA)
local function draw_esp_logic()
    if esp_active and esp_font then
        local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
        
        for _, handle in ipairs(getAllChars()) do
            if doesCharExist(handle) and handle ~= PLAYER_PED then
                local res, id = sampGetPlayerIdByCharHandle(handle)
                if res and sampIsPlayerConnected(id) then
                    -- Protecao de Spectate (Nao mostrar quem voce esta telando)
                    local skip = false
                    if esp_spectate_id ~= -1 and id == esp_spectate_id then skip = true end
                    if not skip and esp_spectate_vehicle_id ~= -1 and isCharInAnyCar(handle) then
                        local car = getCarCharIsUsing(handle)
                        local res, carId = sampGetVehicleIdByCarHandle(car)
                        if res and carId == esp_spectate_vehicle_id then skip = true end
                    end

                    if not skip then
                        local x, y, z = getCharCoordinates(handle)
                        
                        -- Verifica se esta no campo de visao
                        if isPointOnScreen(x, y, z, 0.0) then
                            local dist = getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z)
                            
                            -- Verifica barreiras
                            local checkVeh = true
                            if isCharInAnyCar(handle) then checkVeh = false end
                            local camX, camY, camZ = getActiveCameraCoordinates()
                            local visible = isLineOfSightClear(camX, camY, camZ, x, y, z + 0.7, true, checkVeh, false, true, false)
                            
                            -- Wallhack ou Distancia > 65m
                            if dist < cfg.main.esp_distance and (not visible or dist > 65) then
                                local headX, headY = convert3DCoordsToScreen(x, y, z + 2.6)
                                
                                if headX and headY then
                                    local nick = sampGetPlayerNickname(id) or "Unknown"
                                    local hp = getCharHealth(handle)
                                    local armor = getCharArmour(handle)
                                    if hp > 100 then hp = 100 end; if hp < 0 then hp = 0 end; if armor > 100 then armor = 100 end
                                    
                                    local pColor = sampGetPlayerColor(id)
                                    if pColor == 0 then pColor = 0xFFFFFFFF end
                                    pColor = bit.bor(pColor, 0xFF000000)
                                    
                                    local text = string.format("%s (%d)", nick, id)
                                    local textLen = renderGetFontDrawTextLength(esp_font, text)
                                    local textX = headX - (textLen / 2); local textY = headY
                                    renderFontDrawText(esp_font, text, textX, textY, pColor)
                                    
                                    local barW = 40; local barH = 5; local barX = headX - (barW / 2); local barY = textY + 15
                                    renderDrawBox(barX - 1, barY - 1, barW + 2, barH + 2, 0xFF000000)
                                    if hp > 0 then local hpW = barW * (hp / 100); renderDrawBox(barX, barY, hpW, barH, 0xFFB92228) end

                                    local nextY = barY + barH + 3
                                    if armor > 0 then
                                        local armY = nextY
                                        renderDrawBox(barX - 1, armY - 1, barW + 2, barH + 2, 0xFF000000)
                                        local armW = barW * (armor / 100)
                                        renderDrawBox(barX, armY, armW, barH, 0xFFF5F5F5)
                                        nextY = armY + barH + 2
                                    end

                                    local wep = getCurrentCharWeapon(handle)
                                    if wep and wep > 0 and weapon_names_esp[wep] then
                                        local wname = weapon_names_esp[wep]
                                        local wLen = renderGetFontDrawTextLength(esp_font, wname)
                                        renderFontDrawText(esp_font, wname, headX - (wLen / 2), nextY, 0xFFFFFFFF)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function getPlayerId(arg)
    local id = tonumber(arg)
    if id then return id end
    local name = arg:lower()
    for i = 0, 1000 do
        if sampIsPlayerConnected(i) then
            local nick = sampGetPlayerNickname(i)
            if nick and nick:lower():find(name, 1, true) then return i end
        end
    end
    return nil
end

function sampev.onServerMessage(color, text)
    if state.ip_extractor_active then
        local ip = text:match("(%d+%.%d+%.%d+%.%d+)")
        if ip then
            local log_text = text
            local p_info = nil
            if #state.ip_req_queue > 0 then
                local info = table.remove(state.ip_req_queue, 1)
                if info then
                    p_info = info
                    state.player_ips[info.id] = {ip = ip, nick = info.name} -- Salva o IP na lista
                    log_text = string.format("Nick: %s (ID: %d) | %s", info.name, info.id, text)
                end
            end
            logFoundIP(log_text)
            if state.ip_extractor_check_dupes.v then
                if not state.extracted_ips[ip] then state.extracted_ips[ip] = {} end
                table.insert(state.extracted_ips[ip], { txt = log_text, info = p_info })
            end
        end
    end
    
    if state.device_scanner_active and state.current_scan_info and state.current_scan_info.name then
        local txt = text:lower()
        local name_lower = state.current_scan_info.name:lower()
        -- Verifica se a mensagem tem o NICK do jogador atual ou padrao de IP (mesmo com *)
        if txt:find(name_lower, 1, true) or txt:find("ip:") or txt:find("%d+%.%d+%.%d+%.[%d%*]+") or txt:find("android") or txt:find("mobile") or txt:find("celular") or txt:find("launcher") then
            local detected = nil
            if txt:find("android") or txt:find("mobile") or txt:find("celular") then
                detected = "Mobile"
            elseif txt:find("%f[%a]pc%f[%A]") or txt:find("computador") or txt:find("windows") or txt:find("launcher") or txt:find("client") then
                detected = "PC"
            elseif txt:find("%d+%.%d+%.%d+%.[%d%*]+") then
                -- Se achou IP mas nao achou Mobile, assume PC provisoriamente (muitos servers nao escrevem PC)
                if not state.player_devices[state.current_scan_info.id] then
                    detected = "PC"
                end
            end

            if detected then 
                state.player_devices[state.current_scan_info.id] = detected 
                -- Se for Mobile ou PC explicito, podemos parar. Se for PC implicito (IP), continuamos lendo caso venha "Mobile" na proxima linha.
                if detected == "Mobile" or txt:find("pc") then state.scan_response_received = true end
            end
            
            state.scan_message_count = state.scan_message_count + 1
            return false -- Bloqueia a mensagem no chat
        end
    end
end

function sampev.onSendCommand(cmd)
    local c = cmd:lower()
    if c:find("^/pararespiar") or c:find("^/specoff") or c:find("^/reoff") then
        state.stop_spec_requested = true
        -- Reseta a flag apos 3 segundos caso o servidor nao responda ou algo falhe
        lua_thread.create(function() wait(3000) state.stop_spec_requested = false end)
    end
    
    local cmd_name, params = cmd:match("^/([%w_]+)%s*(.*)")
    if cmd_name == "espiar" or cmd_name == "re" or cmd_name == "spec" then
        if #params > 0 then
            local id = getPlayerId(params)
            if id then esp_spectate_id = id end
        end
    end
end

function sampev.onTogglePlayerSpectating(toggle)
    if not toggle then 
        esp_spectate_id = -1 
        esp_spectate_vehicle_id = -1
    end

    if toggle then
        state.stop_spec_requested = false -- Garante que a flag esteja desligada ao entrar no spec
    elseif state.stop_spec_requested then
        state.stop_spec_requested = false
        lua_thread.create(function()
            wait(500)
            sampSendChat("/godmod")
        end)
    end
end

function sampev.onSpectatePlayer(playerId, camType)
    esp_spectate_id = playerId
    esp_spectate_vehicle_id = -1
end

function sampev.onSpectateVehicle(vehicleId, camType)
    esp_spectate_vehicle_id = vehicleId
    esp_spectate_id = -1
end

local function strip_colors(text)
    return text:gsub("{......}", "")
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if state.ip_extractor_active then
        local content = (text or "") .. " " .. (title or "")
        local ip = content:match("(%d+%.%d+%.%d+%.%d+)")
        if ip then
            local log_text = "Dialog: " .. (title or "") .. " " .. (text or "")
            local p_info = nil
            if #state.ip_req_queue > 0 then
                local info = table.remove(state.ip_req_queue, 1)
                if info then
                    p_info = info
                    state.player_ips[info.id] = {ip = ip, nick = info.name}
                    log_text = string.format("Nick: %s (ID: %d) | %s", info.name, info.id, log_text)
                end
            end
            logFoundIP(log_text)
            if state.ip_extractor_check_dupes.v then
                if not state.extracted_ips[ip] then state.extracted_ips[ip] = {} end
                table.insert(state.extracted_ips[ip], { txt = log_text, info = p_info })
            end
        end
        return false
    end

    if state.device_scanner_active then
        -- Tenta ler o dialog para achar PC/Mobile sem mostrar na tela
        local content = strip_colors((title or "") .. " " .. (text or "")):lower()
        local detected = nil
        if content:find("android") or content:find("mobile") or content:find("celular") or content:find("ios") then
            detected = "Mobile"
        elseif content:find("pc") or content:find("computador") or content:find("windows") or content:find("launcher") or content:find("client") or content:find("desktop") then
            detected = "PC"
        end

        if state.current_scan_info and detected then
            state.player_devices[state.current_scan_info.id] = detected
        end
        
        state.scan_response_received = true
        return false -- Bloqueia o dialog
    end
end

function sampev.onDisplayGameText(style, time, text)
    if state.device_scanner_active then return false end
end

function sampev.onShowTextDraw(id, data)
    if state.device_scanner_active then
        if data and data.text then
            local content = strip_colors(data.text):lower()
            local detected = nil
            if content:find("android") or content:find("mobile") or content:find("celular") or content:find("ios") then
                detected = "Mobile"
            elseif content:find("pc") or content:find("computador") or content:find("windows") or content:find("launcher") or content:find("client") or content:find("desktop") then
                detected = "PC"
            end
            if state.current_scan_info and detected then
                state.player_devices[state.current_scan_info.id] = detected
                state.scan_response_received = true
            end
        end
        return false 
    end
end

-- SETUP STYLE / TEMAS (Simplificado para Padrao)
function apply_theme(theme_name)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local alpha = tonumber(cfg.main.transparency) or 0.98

    style.WindowRounding = 8.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.FrameRounding = 4.0
    style.ItemSpacing = imgui.ImVec2(8, 4)
    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 9.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 3.0

    if theme_name == "Claro" then
        if imgui.StyleColorsLight then imgui.StyleColorsLight() end
        colors[clr.WindowBg] = ImVec4(0.82, 0.82, 0.82, alpha)
        colors[clr.TitleBg] = ImVec4(0.70, 0.70, 0.70, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.55, 0.55, 0.55, 1.00)
        colors[clr.Button] = ImVec4(0.65, 0.65, 0.65, 0.40)
        colors[clr.ButtonHovered] = ImVec4(0.55, 0.55, 0.55, 0.50)
        colors[clr.ButtonActive] = ImVec4(0.45, 0.45, 0.45, 1.00)
        colors[clr.Separator] = ImVec4(0.3, 0.3, 0.3, 0.50)
    elseif theme_name == "Roxo" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.13, 0.10, 0.16, alpha)
        colors[clr.TitleBg] = ImVec4(0.25, 0.05, 0.35, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.35, 0.10, 0.45, 1.00)
        colors[clr.Button] = ImVec4(0.35, 0.15, 0.45, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.45, 0.20, 0.55, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.55, 0.25, 0.65, 1.00)
        colors[clr.CheckMark] = ImVec4(0.70, 0.30, 0.90, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.70, 0.30, 0.90, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(0.80, 0.40, 1.00, 1.00)
        colors[clr.Header] = ImVec4(0.35, 0.15, 0.45, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.45, 0.20, 0.55, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.55, 0.25, 0.65, 1.00)
        colors[clr.TextSelectedBg] = ImVec4(0.70, 0.30, 0.90, 0.35)
        colors[clr.Separator] = ImVec4(0.60, 0.30, 0.80, 0.50)
    elseif theme_name == "Vermelho" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.12, 0.08, 0.08, alpha)
        colors[clr.TitleBg] = ImVec4(0.40, 0.05, 0.05, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.60, 0.10, 0.10, 1.00)
        colors[clr.Button] = ImVec4(0.50, 0.10, 0.10, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.70, 0.15, 0.15, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.80, 0.20, 0.20, 1.00)
        colors[clr.CheckMark] = ImVec4(0.90, 0.20, 0.20, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.80, 0.20, 0.20, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(0.90, 0.20, 0.20, 1.00)
        colors[clr.Header] = ImVec4(0.50, 0.10, 0.10, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.70, 0.15, 0.15, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.80, 0.20, 0.20, 1.00)
        colors[clr.TextSelectedBg] = ImVec4(0.90, 0.20, 0.20, 0.35)
        colors[clr.Separator] = ImVec4(0.80, 0.20, 0.20, 0.50)
    elseif theme_name == "Verde" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.06, 0.09, 0.06, alpha)
        colors[clr.TitleBg] = ImVec4(0.05, 0.20, 0.05, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.10, 0.30, 0.10, 1.00)
        colors[clr.Button] = ImVec4(0.10, 0.30, 0.10, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.20, 0.50, 0.20, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.30, 0.70, 0.30, 1.00)
        colors[clr.CheckMark] = ImVec4(0.20, 0.80, 0.20, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.20, 0.80, 0.20, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(0.30, 0.90, 0.30, 1.00)
        colors[clr.Header] = ImVec4(0.10, 0.30, 0.10, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.20, 0.50, 0.20, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.30, 0.70, 0.30, 1.00)
        colors[clr.Separator] = ImVec4(0.20, 0.60, 0.20, 0.50)
        colors[clr.TextSelectedBg] = ImVec4(0.20, 0.80, 0.20, 0.35)
    elseif theme_name == "Laranja" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.10, 0.08, 0.05, alpha)
        colors[clr.TitleBg] = ImVec4(0.30, 0.15, 0.05, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.45, 0.20, 0.05, 1.00)
        colors[clr.Button] = ImVec4(0.45, 0.20, 0.05, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.60, 0.30, 0.10, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.75, 0.35, 0.10, 1.00)
        colors[clr.CheckMark] = ImVec4(0.90, 0.45, 0.10, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.90, 0.45, 0.10, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(1.00, 0.55, 0.10, 1.00)
        colors[clr.Header] = ImVec4(0.45, 0.20, 0.05, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.60, 0.30, 0.10, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.75, 0.35, 0.10, 1.00)
        colors[clr.Separator] = ImVec4(0.80, 0.40, 0.10, 0.50)
        colors[clr.TextSelectedBg] = ImVec4(0.90, 0.45, 0.10, 0.35)
    elseif theme_name == "Amarelo" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.10, 0.10, 0.08, alpha)
        colors[clr.TitleBg] = ImVec4(0.40, 0.35, 0.05, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.55, 0.50, 0.05, 1.00)
        colors[clr.Button] = ImVec4(0.50, 0.45, 0.05, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.70, 0.65, 0.10, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.85, 0.80, 0.10, 1.00)
        colors[clr.CheckMark] = ImVec4(1.00, 0.90, 0.00, 1.00)
        colors[clr.SliderGrab] = ImVec4(1.00, 0.90, 0.00, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(1.00, 1.00, 0.20, 1.00)
        colors[clr.Header] = ImVec4(0.50, 0.45, 0.05, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.70, 0.65, 0.10, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.85, 0.80, 0.10, 1.00)
        colors[clr.Separator] = ImVec4(0.80, 0.75, 0.10, 0.50)
        colors[clr.TextSelectedBg] = ImVec4(1.00, 0.90, 0.00, 0.35)
    elseif theme_name == "Escuro" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.05, 0.05, 0.05, alpha)
        colors[clr.TitleBg] = ImVec4(0.08, 0.08, 0.08, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.12, 0.12, 0.12, 1.00)
        colors[clr.Button] = ImVec4(0.15, 0.15, 0.15, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.25, 0.25, 0.25, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.35, 0.35, 0.35, 1.00)
        colors[clr.CheckMark] = ImVec4(0.80, 0.80, 0.80, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.80, 0.80, 0.80, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(1.00, 1.00, 1.00, 1.00)
        colors[clr.Header] = ImVec4(0.15, 0.15, 0.15, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.25, 0.25, 0.25, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.35, 0.35, 0.35, 1.00)
        colors[clr.Separator] = ImVec4(0.40, 0.40, 0.40, 0.50)
        colors[clr.TextSelectedBg] = ImVec4(0.50, 0.50, 0.50, 0.35)
    else -- Padrao
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.11, 0.12, 0.14, alpha)
        colors[clr.TitleBg] = ImVec4(0.09, 0.09, 0.09, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.13, 0.13, 0.13, 1.00)
        colors[clr.Button] = ImVec4(0.20, 0.22, 0.24, 0.80)
        colors[clr.ButtonHovered] = ImVec4(0.26, 0.59, 0.98, 0.50)
        colors[clr.ButtonActive] = ImVec4(0.06, 0.53, 0.98, 1.00)
        colors[clr.Separator] = ImVec4(1.00, 1.00, 1.00, 0.25)
        colors[clr.CheckMark] = ImVec4(0.26, 0.59, 0.98, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.24, 0.52, 0.88, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(0.26, 0.59, 0.98, 1.00)
        colors[clr.Header] = ImVec4(0.26, 0.59, 0.98, 0.31)
        colors[clr.HeaderHovered] = ImVec4(0.26, 0.59, 0.98, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.26, 0.59, 0.98, 1.00)
        colors[clr.TextSelectedBg] = ImVec4(0.26, 0.59, 0.98, 0.35)
    end
end

-- SISTEMA DE ATUALIZACAO AUTOMATICA (GITHUB)
local script_url = "https://raw.githubusercontent.com/cvradmin/paineladmincvr/main/PainelAdministrativo.lua"

function check_update(notify_no_update)
    local dlstatus = require('moonloader').download_status
    local temp_path = os.getenv('TEMP') .. '\\PainelInfoHelper_update_' .. os.time() .. '_' .. math.random(1, 100000) .. '.lua'
    
    if notify_no_update then sampAddChatMessage("[PainelInfoHelper] Verificando atualizacoes...", -1) end

    downloadUrlToFile(script_url .. "?t=" .. os.time(), temp_path, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local f = io.open(temp_path, 'r')
            if f then
                local content = f:read('*a')
                f:close()
                os.remove(temp_path)
                
                local remote_ver_str = content:match('script_version%s*%(%s*"([^"]+)"%s*%)')
                local remote_ver = tonumber(content:match("script_version_number%s*%(%s*(%d+)%s*%)"))
                local local_ver = script_ver_num
                
                if remote_ver and remote_ver > local_ver then
                    sampAddChatMessage("[PainelInfoHelper] Nova versao disponivel: v" .. (remote_ver_str or remote_ver), 0xFFFF00)
                    sampAddChatMessage("[PainelInfoHelper] Acesse o GitHub para baixar a atualizacao.", 0xFFFF00)
                elseif notify_no_update then
                        sampAddChatMessage("[PainelInfoHelper] Voce ja esta usando a versao mais recente.", 0x00FF00)
                end
            end
        end
    end)
end

-- FUNÇÕES DE CABEÇALHO
local function draw_vehicle_header() 
    local idw=50; local nw=180; local pw=100; local spdw=100; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; 
    local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nw; local p3ps=p2s+sw+sp; local p3s=p3ps+pw; local p4ss=p3s+sw+sp; local p4s=p4ss+spdw; local p5ts=p4s+sw+sp; 
    local function sort_btn(lbl, col)
        local txt = lbl .. (state.current_sort_column == col and (state.sort_direction == 1 and " ^" or " v") or "")
        local size = imgui.CalcTextSize(txt)
        size.x = size.x + imgui.GetStyle().FramePadding.x * 2
        if imgui.Selectable(txt, false, 0, size) then if state.current_sort_column == col then state.sort_direction = state.sort_direction * -1 else state.current_sort_column = col; state.sort_direction = 1 end end
    end
    sort_btn("ID", "ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); 
    sort_btn("Nome", "Nome"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps); 
    sort_btn("Preco", "Preco"); imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4ss); 
    sort_btn("Velocidade", "Velocidade"); imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ts); 
    sort_btn("Tipo", "Tipo"); 
    local p6as = p5ts + 100 + sp
    imgui.SameLine(p6as); imgui.Text("Acao"); imgui.Separator() 
end
local function draw_skin_header() local idw=50; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp; local align_offset = imgui.GetStyle().FramePadding.x; imgui.SetCursorPosX(imgui.GetCursorPosX() + align_offset); imgui.Text("ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text("Nome"); imgui.Separator() end
local function draw_profession_header() local nw=220; local lw=60; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=nw; local p2ls=p1s+sw+sp; local p2s=p2ls+lw; local p3ss=p2s+sw+sp; local align_offset = imgui.GetStyle().FramePadding.x; imgui.SetCursorPosX(imgui.GetCursorPosX() + align_offset); imgui.Text("Profissao"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ls); imgui.Text("Lvl Min"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ss); imgui.Text("Salario"); imgui.Separator() end
local function draw_weapon_header() local idw=50; local nw=200; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nw; local p3ts=p2s+sw+sp; local align_offset = imgui.GetStyle().FramePadding.x; imgui.SetCursorPosX(imgui.GetCursorPosX() + align_offset); imgui.Text("ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text("Nome"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ts); imgui.Text("Tipo"); imgui.Separator() end

local function draw_faq_tab()
    imgui.TextColored(IMAGE_GREEN, "Duvidas e FAQ"); imgui.Separator()
    imgui.BeginChild("DuvidasFAQ", imgui.ImVec2(0,0), true)
    
    local search_term = remove_accents(state.search_text.v)
    
    if imgui.CollapsingHeader("Perguntas Frequentes") then
        imgui.Spacing()
        for i, item in ipairs(faq_list) do
            local q_norm = remove_accents(item.q)
            local a_norm = remove_accents(item.a)
            if search_term == "" or q_norm:find(search_term, 1, true) or a_norm:find(search_term, 1, true) then
                if imgui.CollapsingHeader(u8(item.q)) then
                    if not item.buf then
                        item.buf = imgui.ImBuffer(u8(item.a), #item.a + 1024)
                    end
                    local width = imgui.GetWindowWidth() - 50
                    local text_size = imgui.CalcTextSize(u8(item.a), false, width)
                    local height = text_size.y + 30
                    if height < 60 then height = 60 end
                    if height > 300 then height = 300 end
                    imgui.InputTextMultiline("##ans_"..i, item.buf, imgui.ImVec2(-1, height), imgui.InputTextFlags.ReadOnly)
                    if imgui.Button("Copiar Tudo##faq_"..i) then
                        imgui.SetClipboardText(u8(item.a))
                        sampAddChatMessage("[PI] Resposta copiada para a area de transferencia.", -1)
                    end
                    imgui.Spacing()
                end
            end
        end
        imgui.Spacing()
    end
    imgui.EndChild()
end

local function start_admin_login()
    sampSendChat("/logaradm")
    lua_thread.create(function()
        wait(250)
        if sampIsDialogActive() then
            sampSendDialogResponse(sampGetCurrentDialogId(), 1, 0, cfg.main.admin_pass)
            sampCloseCurrentDialogWithButton(1)
            sampAddChatMessage("[PI] Senha enviada via Auto-Login!", -1)
            wait(1000)
            if cfg.main.auto_cheat then
                sampSendChat("/cheat")
                wait(500)
            end
            sampSendChat("/godmod")
        else
            sampAddChatMessage("[PI] Erro: Dialog nao abriu a tempo ou lag.", 0xFF0000)
        end
    end)
end

-- =========================================================================
-- FUNÇÃO PRINCIPAL DO SCRIPT (ON_DRAW_FRAME)
-- =========================================================================
function imgui.OnDrawFrame()
    if state.window_open.v then
        local sw, sh = getScreenResolution(); imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5)); imgui.SetNextWindowSize(imgui.ImVec2(700, 500), imgui.Cond.FirstUseEver)
        
        imgui.Begin("Painel Helper [F12] - v1.0.69", state.window_open)

        local tabs = { {1, "Novatos"}, {2, "Online"}, {4, "Informacoes"}, {9, "Locais"}, {13, "Comandos"}, {11, "Config"} }; local btn_space = imgui.GetWindowWidth() / #tabs; local btn_w = imgui.ImVec2(math.floor(btn_space) - 5, 25); local act_bg=IMAGE_WHITE; local act_hov=imgui.ImVec4(.8,.8,.8,1); local act_txt=IMAGE_BLACK; local inact_bg=imgui.GetStyle().Colors[imgui.Col.Button]; local inact_hov=imgui.GetStyle().Colors[imgui.Col.ButtonHovered]; local inact_txt=imgui.GetStyle().Colors[imgui.Col.Text]
        for i, tab in ipairs(tabs) do local tid, tnm = tab[1], tab[2]; local is_act = state.active_tab == tid; if is_act then imgui.PushStyleColor(imgui.Col.Button,act_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,act_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,act_hov); imgui.PushStyleColor(imgui.Col.Text,act_txt) else imgui.PushStyleColor(imgui.Col.Button,inact_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,inact_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,inact_hov); imgui.PushStyleColor(imgui.Col.Text,inact_txt) end; if imgui.Button(tnm, btn_w) then if state.active_tab ~= tid then state.active_tab=tid end end; imgui.PopStyleColor(4); if i < #tabs then imgui.SameLine(0, 2) end end; imgui.Separator(); imgui.Text(string.format("Atualizacao: %s", os.date("%H:%M:%S"))); imgui.Spacing()
        local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED); if myid then local mynick=sampGetPlayerNickname(myid) or "?"; imgui.TextColored(IMAGE_YELLOW, string.format("Voce: %s (ID: %d)", u8(mynick), myid)); imgui.Spacing() end

        local search_lbl = ""; local show_search = true
        if state.active_tab == 1 then search_lbl="Pesq. Novato" elseif state.active_tab == 2 then search_lbl="Pesq. Online" elseif state.active_tab == 4 then if state.active_info_sub_tab == 1 then search_lbl="Pesq. Prof" elseif state.active_info_sub_tab == 2 then search_lbl="Pesq. Veh" elseif state.active_info_sub_tab == 3 then search_lbl="Pesq. Skin" elseif state.active_info_sub_tab == 4 then search_lbl="Pesq. Arma" elseif state.active_info_sub_tab == 5 then search_lbl="Pesq. FAQ" else search_lbl="Pesq." end elseif state.active_tab == 9 then search_lbl="Pesq. Favorito" elseif state.active_tab == 11 or state.active_tab == 13 then show_search = false else search_lbl="Pesq." end
        if show_search then imgui.InputText(search_lbl, state.search_text, imgui.ImVec2(300, 0)); imgui.Spacing() elseif state.active_tab ~= 11 then imgui.TextColored(IMAGE_GREY,"Selecione topico."); imgui.Spacing() end
        local search_u8 = u8(state.search_text.v):lower(); local search_cp = string.lower(state.search_text.v)

        -- [[ ABA NOVATOS (1) E ONLINE (2) ]]
        if state.active_tab == 1 or state.active_tab == 2 then
            local is_nov = (state.active_tab == 1)
            local hdr = is_nov and "Novatos:" or "Online:"
            imgui.Text(hdr)
            imgui.SameLine()
            imgui.PushItemWidth(150)
            imgui.Combo("##OnlineFilter", state.online_filter_idx, online_filters)
            imgui.PopItemWidth()
            imgui.Separator()
            if is_nov then 
                imgui.TextDisabled("Lista de jogadores novatos (Nivel < 12). Botao direito no nome para opcoes.") 
            else
                imgui.TextDisabled("Lista de todos os jogadores online. Staff no topo. Botao direito para opcoes.")
            end

            local staff={}; local players={}; local maxid=sampGetMaxPlayerId()
            local total_mafia = 0; local total_honest = 0; local total_pc = 0; local total_mobile = 0
            for i=0,maxid do 
                if sampIsPlayerConnected(i) then 
                    local nick=sampGetPlayerNickname(i); 
                    if nick and #nick>0 then 
                        local rank=staff_nick_to_rank_map[string.lower(nick)]; 
                        if not rank then local s,n=pcall(encoding.CP1251,nick); if s and n then rank=staff_nick_to_rank_map[string.lower(n)] end end; 
                        local ping=sampGetPlayerPing(i) or 0; 
                        local score=sampGetPlayerScore(i) or 0; 
                        local color; 
                        local prof;
                        if rank then 
                            color=get_rank_color(rank)
                            prof=get_display_rank(rank)
                        else 
                            local argb=sampGetPlayerColor(i); 
                            color=convert_samp_color(argb)
                            prof=get_closest_profession_name(argb)
                        end; 
                        local pdata={id=i,nick=nick,rank=rank,color=color,is_staff=rank~=nil,Level=score,Ping=ping,profession=prof}; 

                        if not rank then
                            local p_type = prof_type_map[prof:lower()]
                            if p_type == "Mafia" then total_mafia = total_mafia + 1 else total_honest = total_honest + 1 end
                        end
                        
                        local dev = state.player_devices[i]
                        if dev == "PC" then total_pc = total_pc + 1 
                        elseif dev == "Mobile" then total_mobile = total_mobile + 1 end
                        
                        local paused = sampIsPlayerPaused(i) or false
                        
                        local filter_sel = online_filters[state.online_filter_idx.v + 1]
                        local filter_pass = true
                        if filter_sel == "PC" then
                            if dev ~= "PC" then filter_pass = false end
                        elseif filter_sel == "Mobile" then
                            if dev ~= "Mobile" then filter_pass = false end
                        elseif filter_sel == "Mafia" then
                            if prof_type_map[prof:lower()] ~= "Mafia" then filter_pass = false end
                        elseif filter_sel == "Honestas" then
                            if prof_type_map[prof:lower()] ~= "Legal" then filter_pass = false end
                        end

                        local passes = ((not is_nov) or (is_nov and pdata.Level < 12 and not paused)) and filter_pass

                        if passes then
                            local nick_u8=u8(nick):lower(); local prof_u8=u8(pdata.profession or ""):lower(); local id_s=tostring(i); 
                            local m_txt=nick_u8:find(search_u8,1,true) or prof_u8:find(search_u8,1,true); 
                            local m_id=id_s:find(search_cp,1,true); 
                            if m_txt or m_id then 
                                if pdata.is_staff and not is_nov then table.insert(staff,pdata) else table.insert(players,pdata) end 
                            end 
                        end
                    end 
                end 
            end
            
            if is_nov then
                imgui.Text(string.format("Total: %d", #players))
            else
                imgui.Text(string.format("Total: %d (Staff: %d | Players: %d)", #staff+#players, #staff, #players))
                imgui.SameLine(); imgui.TextColored(IMAGE_GREY, "|")
                imgui.SameLine(); imgui.TextColored(IMAGE_GREEN, string.format("Honestas: %d", total_honest))
                imgui.SameLine(); imgui.TextColored(IMAGE_RED, string.format("Mafia: %d", total_mafia))
                imgui.SameLine(); imgui.TextColored(IMAGE_GREY, "|")
                imgui.SameLine(); imgui.TextColored(IMAGE_BLUE, string.format("PC: %d", total_pc))
                imgui.SameLine(); imgui.TextColored(IMAGE_PINK, string.format("Mobile: %d", total_mobile))
                
                imgui.SameLine()
                if not state.device_scanner_active then
                    if imgui.Button("Escanear Dispositivos") then
                        lua_thread.create(function()
                            state.device_scanner_active = true
                            state.player_devices = {} -- Limpa dados anteriores
                            sampAddChatMessage("[PI] Iniciando scan de dispositivos (/dispositivo)...", 0x00FF00)
                            local max_id = sampGetMaxPlayerId()
                            for i = 0, max_id do
                                if not state.device_scanner_active then break end
                                if sampIsPlayerConnected(i) then
                                    local nick = sampGetPlayerNickname(i)
                                    if nick then
                                        -- Tenta ate 2 vezes se falhar (Double Check)
                                        for attempt = 1, 2 do
                                            if state.player_devices[i] then break end -- Ja detectou, pula retry

                                            state.current_scan_info = {id = i, name = nick}
                                            state.scan_response_received = false
                                            state.scan_message_count = 0
                                            
                                            sampSendChat("/ip " .. i)
                                            state.device_scan_progress = i
                                            
                                            -- Espera a resposta ou timeout (200ms)
                                            local timeout = 0
                                            while not state.scan_response_received and timeout < 200 do
                                                wait(10)
                                                timeout = timeout + 10
                                                -- Se ja recebeu msg (IP) e passou 50ms, assume que acabou (para PC implicito ser rapido)
                                                if state.scan_message_count > 0 and timeout > 50 then break end
                                            end
                                            
                                            if attempt == 1 and not state.player_devices[i] then wait(50) end -- Delay antes do retry
                                        end
                                        -- Garante que qualquer dialog residual seja fechado
                                        if sampIsDialogActive() then sampCloseCurrentDialogWithButton(0) end
                                    end
                                end
                            end
                            state.current_scan_info = nil
                            state.device_scanner_active = false
                            sampAddChatMessage("[PI] Scan de dispositivos concluido!", 0x00FF00)
                        end)
                    end
                else
                    imgui.TextColored(IMAGE_YELLOW, string.format("Escaneando... ID %d", state.device_scan_progress))
                end
            end
            imgui.Separator(); imgui.BeginChild("plist_child",imgui.ImVec2(0,0),true)
            
            local function render_list(list)
                local idw=35; local nickw=130; local profw=150; local lvlw=40; local pingw=110
                local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x
                local align_offset = imgui.GetStyle().FramePadding.x
                for _,p in ipairs(list) do
                    local is_s=p.is_staff; local paused=sampIsPlayerPaused(p.id); local disp_p=p.profession or "?"; if paused then if is_s then disp_p=u8(p.profession).." (AFK)" else disp_p="AFK" end end
                    local curX = imgui.GetCursorPosX()
                    local line_lbl=string.format("##p_%d",p.id)
                    imgui.Selectable(line_lbl, false, 0, imgui.ImVec2(0, imgui.GetTextLineHeight()))
                    if imgui.BeginPopupContextItem("p_act"..p.id) then 
                        if imgui.MenuItem("CP Nick") then imgui.SetClipboardText(u8(p.nick)); sampAddChatMessage("Nick CP",0) end; 
                        if p.profession then if imgui.MenuItem("CP Info") then imgui.SetClipboardText(u8(p.profession)); sampAddChatMessage("Info CP",0) end end; 
                        local ip_data = state.player_ips[p.id]
                        if ip_data and ip_data.nick == p.nick then if imgui.MenuItem("Copiar IP") then imgui.SetClipboardText(ip_data.ip); sampAddChatMessage("[PI] IP copiado: " .. ip_data.ip, -1) end end
                        imgui.Separator(); 
                        if imgui.MenuItem("Ir ID") then sampSendChat("/ir "..p.id); state.window_open.v=false; imgui.Process=false end; 
                        if imgui.MenuItem("Espiar ID") then sampSendChat("/espiar "..p.id); state.window_open.v=false; imgui.Process=false end; 
                        imgui.EndPopup() 
                    end
                    
                    local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nickw; local p3ps=p2s+sw+sp; local p3s=p3ps+profw; local p4ls=p3s+sw+sp; local p4s=p4ls+lvlw; local p5ps=p4s+sw+sp; local p5s=p5ps+pingw; local p6is=p5s+sw+sp
                    imgui.SameLine(curX + align_offset); imgui.TextColored(p.color,tostring(p.id))
                    imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.TextColored(p.color,u8(p.nick))
                    imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps); local tc=paused and IMAGE_GREY or p.color; imgui.TextColored(tc,u8(disp_p))
                    imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4ls); imgui.TextColored(p.color,tostring(p.Level))
                    imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ps); local pc=(p.Ping<100) and IMAGE_GREEN or (p.Ping<=200 and IMAGE_YELLOW or IMAGE_RED); 
                    local dev_str = state.player_devices[p.id] and (" ["..state.player_devices[p.id].."]") or ""; imgui.TextColored(pc,tostring(p.Ping).." ms"..dev_str)
                    
                    imgui.SameLine(p5s); imgui.TextColored(sc,st); imgui.SameLine(p6is); 
                    local ip_data = state.player_ips[p.id]
                    local ip_str = (ip_data and ip_data.nick == p.nick) and ip_data.ip or "-"
                    imgui.TextDisabled(ip_str)
                end
            end
            
            if #staff==0 and #players==0 then imgui.Text("Nenhum.") else
                draw_player_header()
                if #staff > 0 then render_list(staff); imgui.Separator() end
                render_list(players)
            end
            imgui.EndChild()

        -- [[ ABA INFORMACOES (ID 4) ]]
        elseif state.active_tab == 4 then
            local sub_tabs={{1,"Profissoes"},{2,"Veiculos"},{3,"Skins"},{4,"Armas"},{5,"Duvidas"}}; local sub_space=(imgui.GetWindowWidth()-25)/#sub_tabs; local sub_btn_w=imgui.ImVec2(math.floor(sub_space)-5,22); local act_bg=IMAGE_WHITE; local act_hov=imgui.ImVec4(.8,.8,.8,1); local act_txt=IMAGE_BLACK; local inact_bg=imgui.GetStyle().Colors[imgui.Col.Button]; local inact_hov=imgui.GetStyle().Colors[imgui.Col.ButtonHovered]; local inact_txt=imgui.GetStyle().Colors[imgui.Col.Text]
            for i,sub in ipairs(sub_tabs) do local sid,snm=sub[1],sub[2]; local is_act=state.active_info_sub_tab==sid; if is_act then imgui.PushStyleColor(imgui.Col.Button,act_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,act_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,act_hov); imgui.PushStyleColor(imgui.Col.Text,act_txt) else imgui.PushStyleColor(imgui.Col.Button,inact_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,inact_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,inact_hov); imgui.PushStyleColor(imgui.Col.Text,inact_txt) end; if imgui.Button(snm,sub_btn_w) then state.active_info_sub_tab=sid end; imgui.PopStyleColor(4); if i<#sub_tabs then imgui.SameLine(0,2) end end; imgui.Spacing(); imgui.Separator()

            if state.active_info_sub_tab == 1 then -- Profissoes
                imgui.TextDisabled("Lista de profissoes com nivel e salario. Apenas informativo.")
                imgui.TextColored(IMAGE_GREEN,"Profissoes:"); imgui.Separator(); local filt_p=filter_professions(professions,search_cp); local cnt=#filt_p; local leg,maf={}, {}; for _,p in ipairs(filt_p) do if p.type=="Mafia" then table.insert(maf,p) else table.insert(leg,p) end end; imgui.Text("Encontradas: "..cnt); imgui.Separator(); imgui.BeginChild("ProfListInfo",imgui.ImVec2(0,0),true); draw_profession_header(); 
                local function rend_p(l,h,c) 
                    if #l>0 then 
                        imgui.TextColored(c,h); imgui.Spacing(); 
                        local align_offset = imgui.GetStyle().FramePadding.x
                        for _,p in ipairs(l) do 
                            local curX = imgui.GetCursorPosX()
                            local nw=220; local lw=60; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=nw; local p2ls=p1s+sw+sp; local p2s=p2ls+lw; local p3ss=p2s+sw+sp;
                            local lbl=string.format("##pli_%s%d",p.name or "u", p.level or 0); 
                            imgui.Selectable(lbl,false,0,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
                            imgui.SetItemAllowOverlap()
                            imgui.SameLine(curX + align_offset); imgui.Text(p.name or "?"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ls); imgui.Text(tostring(p.level or "?")); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ss); imgui.TextColored(IMAGE_YELLOW,"$"..formatPrice(p.salary or 0)) 
                            
                            if profession_vehicles_map[p.name:lower()] then
                                imgui.SameLine()
                                if imgui.SmallButton("Veiculos##"..p.id) then
                                    state.active_info_sub_tab = 2
                                    state.active_prof_veh_filter = p.name
                                    state.search_text.v = ""
                                    sampAddChatMessage("[PI] Filtrando veiculos de: " .. p.name, -1)
                                end
                            end
                        end 
                    end 
                end; 
                if cnt==0 then imgui.Text("Nenhuma.") else rend_p(leg,"--- Honestas ---",IMAGE_GREEN); if #leg>0 and #maf>0 then imgui.Spacing(); imgui.Separator(); imgui.Spacing() end; rend_p(maf,"--- Mafia ---",IMAGE_RED) end; 
                imgui.EndChild()
            elseif state.active_info_sub_tab == 2 then -- Veiculos
                local filt_v = {}
                local current_prof_filter = state.active_prof_veh_filter
                if current_prof_filter then
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 0, 0, 1))
                    imgui.Text("Veiculos de " .. current_prof_filter)
                    imgui.PopStyleColor()
                    if imgui.Button("Voltar / Todos") then 
                        state.active_prof_veh_filter = nil 
                    end
                    
                    local target_vehs = profession_vehicles_map[current_prof_filter:lower()] or {}
                    local allowed = {}
                    for _, vname in ipairs(target_vehs) do allowed[vname:lower()] = true end
                    for _, v in ipairs(vehicles) do
                        if allowed[v.name:lower()] or allowed[v.name] then table.insert(filt_v, v) end
                    end
                    table.sort(filt_v, function(a, b) return a.id < b.id end)
                else
                    imgui.TextDisabled("Lista de veiculos. Duplo clique para criar (/cv).")
                    imgui.TextDisabled("Lista de veiculos. Use o botao para Criar (/cv).")
                    filt_v=filter_vehicles(vehicles,search_u8,state.current_sort_column,state.sort_direction)
                end

                local cnt=#filt_v; imgui.Text("Veiculos: "..cnt); imgui.Separator();
                imgui.BeginChild("VehListInfo",imgui.ImVec2(0,0),true); draw_vehicle_header(); if cnt==0 then imgui.Text("Nenhum.") else 
                    for _,v in ipairs(filt_v) do 
                        local curX = imgui.GetCursorPosX()
                        local idw=50; local nw=180; local pw=100; local spdw=100; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nw; local p3ps=p2s+sw+sp; local p3s=p3ps+pw; local p4ss=p3s+sw+sp; local p4s=p4ss+spdw; local p5ts=p4s+sw+sp;
                        local p6as = p5ts + 100 + sp
                        local align_offset = imgui.GetStyle().FramePadding.x
                        local lbl=string.format("##vli_%d",v.id); 
                        imgui.Selectable(lbl,false,0,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
                        imgui.SetItemAllowOverlap()
                        if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then sampSendChat("/cv "..v.id); sampAddChatMessage("[PI] Criando veiculo ID "..v.id.." ("..v.name..")",-1) end; 
                        imgui.SameLine(curX + align_offset); imgui.Text(tostring(v.id)); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns + align_offset); imgui.Text(v.name); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps + align_offset); imgui.TextColored(IMAGE_YELLOW,"$"..formatPrice(v.price)); imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4ss + align_offset); imgui.TextColored(IMAGE_PINK,v.speed.." km/h"); imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ts + align_offset); imgui.TextColored(IMAGE_BLUE,v.type) 
                        
                        imgui.SameLine(p6as + align_offset)
                        if imgui.SmallButton("Criar##btn_v_"..v.id) then 
                            sampSendChat("/cv "..v.id); 
                            sampAddChatMessage("[PI] Criando veiculo ID "..v.id.." ("..v.name..")",-1) 
                        end
                    end 
                end; imgui.EndChild()
            elseif state.active_info_sub_tab == 3 then -- Skins
                imgui.TextDisabled("Lista de skins e IDs. Apenas informativo.")
                local filt_s=filter_skins(search_u8); local cnt=#filt_s; imgui.Text("Skins: "..cnt); imgui.Separator(); imgui.BeginChild("SkinListInfo",imgui.ImVec2(0,0),true); draw_skin_header(); if cnt==0 then imgui.Text("Nenhuma.") else 
                    local align_offset = imgui.GetStyle().FramePadding.x
                    for _,s in ipairs(filt_s) do 
                        local curX = imgui.GetCursorPosX()
                        local idw=50; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp;
                        local lbl=string.format("##sli_%d",s.id); 
                        imgui.Selectable(lbl,false,0,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
                        imgui.SameLine(curX + align_offset); imgui.Text(tostring(s.id)); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text(s.name or "?") 
                    end 
                end; imgui.EndChild()
            elseif state.active_info_sub_tab == 4 then -- Armas
                imgui.TextDisabled("Lista de armas e IDs. Apenas informativo.")
                local filt_w=filter_weapons(weapons_list,search_u8); local cnt=#filt_w; imgui.Text("Armas: "..cnt); imgui.Separator(); imgui.BeginChild("WeaponListInfo",imgui.ImVec2(0,0),true); draw_weapon_header(); if cnt==0 then imgui.Text("Nenhuma.") else 
                    local align_offset = imgui.GetStyle().FramePadding.x
                    for _,w in ipairs(filt_w) do 
                        local curX = imgui.GetCursorPosX()
                        local idw=50; local nw=200; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nw; local p3ts=p2s+sw+sp;
                        local lbl=string.format("##wli_%d",w.id); 
                        imgui.Selectable(lbl,false,0,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
                        imgui.SameLine(curX + align_offset); imgui.Text(tostring(w.id)); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text(w.name or "?"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ts); imgui.TextColored(IMAGE_BLUE,w.type or "?") 
                    end 
                end; imgui.EndChild()
            elseif state.active_info_sub_tab == 5 then -- Duvidas
                imgui.TextDisabled("Perguntas frequentes e historico de atualizacoes.")
                draw_faq_tab()
            end

        -- [[ ABA LOCAIS (ID 9) - APENAS FAVORITOS ]]
        elseif state.active_tab == 9 then
            local sub_tabs={{2,"Favoritos"}}; local sub_space=(imgui.GetWindowWidth()-25)/#sub_tabs; local sub_btn_w=imgui.ImVec2(math.floor(sub_space)-5,22); local act_bg=IMAGE_WHITE; local act_hov=imgui.ImVec4(.8,.8,.8,1); local act_txt=IMAGE_BLACK; local inact_bg=imgui.GetStyle().Colors[imgui.Col.Button]; local inact_hov=imgui.GetStyle().Colors[imgui.Col.ButtonHovered]; local inact_txt=imgui.GetStyle().Colors[imgui.Col.Text]
            for i,sub in ipairs(sub_tabs) do local sid,snm=sub[1],sub[2]; local is_act=state.active_locais_sub_tab==sid; if is_act then imgui.PushStyleColor(imgui.Col.Button,act_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,act_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,act_hov); imgui.PushStyleColor(imgui.Col.Text,act_txt) else imgui.PushStyleColor(imgui.Col.Button,inact_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,inact_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,inact_hov); imgui.PushStyleColor(imgui.Col.Text,inact_txt) end; if imgui.Button(snm,sub_btn_w) then state.active_locais_sub_tab=sid end; imgui.PopStyleColor(4); if i<#sub_tabs then imgui.SameLine(0,2) end end; imgui.Spacing(); imgui.Separator()

            if state.active_locais_sub_tab == 2 then
                imgui.TextDisabled("Seus locais salvos. Use 'Salvar Atual' para gravar sua posicao.")
                imgui.Text("Novo Favorito:")
                imgui.SameLine()
                imgui.PushItemWidth(170)
                imgui.InputText("Nome##PosNameLoc", state.saved_pos_name)
                imgui.PopItemWidth()
                imgui.SameLine()
                if imgui.Button("Salvar Atual", imgui.ImVec2(100, 25)) then
                    local x, y, z = getCharCoordinates(PLAYER_PED)
                    local name = state.saved_pos_name.v
                    if #name == 0 then name = "Local " .. os.date("%H:%M:%S") end
                    table.insert(event_locations, {name = name, x = x, y = y, z = z, id = getActiveInterior()})
                    save_events()
                    sampAddChatMessage("[PI] Local salvo em Favoritos: " .. name, -1)
                end
                imgui.SameLine()
                if imgui.Button("Copiar##CopyPosLoc", imgui.ImVec2(60, 25)) then
                    local x, y, z = getCharCoordinates(PLAYER_PED)
                    local txt = string.format("%.2f, %.2f, %.2f", x, y, z)
                    imgui.SetClipboardText(txt)
                    sampAddChatMessage("[PI] Coordenadas copiadas.", -1)
                end
                if #event_locations > 0 then
                    if imgui.Button("Ir para o Ultimo Local Salvo", imgui.ImVec2(-1, 25)) then
                        local last = event_locations[#event_locations]
                        local cmd = string.format("/tp %.2f %.2f %.2f %d", last.x, last.y, last.z, last.id or 0)
                        sampSendChat(cmd)
                        sampAddChatMessage(string.format("[PI] Indo para: %s", last.name), -1)
                    end
                end
                imgui.Separator()

                local filt_evt = filter_interiors(event_locations, search_u8); local cnt = #filt_evt; imgui.Text("Locais Favoritos: " .. cnt); imgui.Separator(); imgui.BeginChild("EventLocs", imgui.ImVec2(0,0), true)
                
                local nw = 300; local cw = 200
                local st = "|"; local sw = imgui.CalcTextSize(st).x
                local sp = imgui.GetStyle().ItemSpacing.x
                local sc = imgui.GetStyle().Colors[imgui.Col.Separator]
                
                local p1s = nw; local p2cs = p1s + sw + sp; local p2s = p2cs + cw; local p3is = p2s + sw + sp
                local align_offset = imgui.GetStyle().FramePadding.x
                imgui.SetCursorPosX(imgui.GetCursorPosX() + align_offset); imgui.Text("Nome Local"); imgui.SameLine(p1s); imgui.TextColored(sc, st); imgui.SameLine(p2cs); imgui.Text("Coords (X,Y,Z)"); imgui.SameLine(p2s); imgui.TextColored(sc, st); imgui.SameLine(p3is); imgui.Text("Int")
                imgui.Separator()

                local align_offset = imgui.GetStyle().FramePadding.x
                for _, loc in ipairs(filt_evt) do
                    local curX = imgui.GetCursorPosX()
                    local lbl = string.format("##evt_%s_%s", loc.name, tostring(loc))
                    imgui.Selectable(lbl, false, 0, imgui.ImVec2(0, imgui.GetTextLineHeight()))
                    
                    if imgui.BeginPopupContextItem() then
                        if imgui.Selectable("Remover dos Favoritos") then
                            for k, v in ipairs(event_locations) do
                                if v.name == loc.name and v.x == loc.x then
                                    table.remove(event_locations, k)
                                    save_events()
                                    sampAddChatMessage("[PI] Local removido dos Favoritos.", -1)
                                    break
                                end
                            end
                        end
                        imgui.EndPopup()
                    end

                    if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then
                        local cmd = string.format("/tp %.2f %.2f %.2f %d", loc.x, loc.y, loc.z, loc.id or 0)
                        sampSendChat(cmd)
                        sampAddChatMessage(string.format("[PI] Teleportando para: %s", loc.name), -1)
                    end
                    if imgui.IsItemHovered() then imgui.SetTooltip("Duplo clique para ir") end

                    imgui.SameLine(curX + align_offset); imgui.Text(loc.name or "Sem Nome")
                    imgui.SameLine(p1s); imgui.TextColored(sc, st)
                    imgui.SameLine(p2cs); imgui.TextColored(IMAGE_PINK, string.format("%.1f, %.1f, %.1f", loc.x, loc.y, loc.z))
                    imgui.SameLine(p2s); imgui.TextColored(sc, st)
                    imgui.SameLine(p3is); imgui.TextColored(IMAGE_BLUE, tostring(loc.id or 0))
                end
                imgui.EndChild()
            end

        -- [[ ABA COMANDOS (ID 13) ]]
        elseif state.active_tab == 13 then
            imgui.Text("Comandos Rapidos"); imgui.Separator()
            imgui.TextDisabled("Atalhos para comandos uteis e ferramentas administrativas.")
            imgui.BeginChild("CmdsList", imgui.ImVec2(0,0), true)
            
            if imgui.Button("/comandosadm", imgui.ImVec2(150, 30)) then sampSendChat("/comandosadm") end
            imgui.SameLine(); imgui.Text("Mostra a lista de comandos administrativos.")

            if imgui.Button(esp_active and "Desativar ESP" or "Ativar ESP", imgui.ImVec2(150, 30)) then
                esp_active = not esp_active
                sampAddChatMessage(esp_active and "[PI] ESP Admin Ativado." or "[PI] ESP Admin Desativado.", -1)
            end
            imgui.SameLine(); imgui.Text("Wallhack de nome/vida/colete (Estilo SA-MP).")
            
            local dist_esp = imgui.ImFloat(cfg.main.esp_distance)
            if imgui.SliderFloat("Distancia ESP", dist_esp, 100.0, 30000.0, "%.0f") then
                cfg.main.esp_distance = dist_esp.v
                inicfg.save(cfg, "PainelInfoHelper_Config.ini")
            end

            imgui.Separator()
            imgui.Text("Extrator de IPs")
            if not state.ip_extractor_active then
                imgui.Text("Quantidade:")
                imgui.SameLine()
                imgui.PushItemWidth(80)
                imgui.InputText("##IPTotal", state.ip_extractor_total_buf)
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.Checkbox("Verif. Duplicados", state.ip_extractor_check_dupes)
                imgui.SameLine()
                if imgui.Button("Iniciar", imgui.ImVec2(80, 25)) then
                    local total = tonumber(state.ip_extractor_total_buf.v)
                    if total and total > 0 then
                        lua_thread.create(function()
                            state.ip_extractor_active = true
                            state.ip_extractor_current = 0
                            state.extracted_ips = {}
                            state.ip_req_queue = {}
                            
                            sampAddChatMessage("[PI] Iniciando extração de IPs...", 0x00FF00)
                            for i = 0, total - 1 do
                                if not state.ip_extractor_active then
                                    sampAddChatMessage("[PI] Extração de IPs interrompida.", 0xFFD700)
                                    break
                                end
                                state.ip_extractor_current = i
                                if sampIsPlayerConnected(i) then
                                    local nick = sampGetPlayerNickname(i)
                                    table.insert(state.ip_req_queue, {id = i, name = nick})
                                    sampSendChat("/IP " .. i)
                                    wait(50)
                                end
                                if i % 50 == 0 then wait(0) end
                            end
                            wait(1000) -- Espera respostas finais
                            if state.ip_extractor_active then
                                sampAddChatMessage("[PI] Extração de IPs concluída!", 0x00FF00)
                                if state.ip_extractor_check_dupes.v then
                                    saveDuplicatesReport()
                                end
                            end
                            state.ip_extractor_active = false
                        end)
                    else
                        sampAddChatMessage("[PI] Quantidade de IPs inválida.", 0xFF0000)
                    end
                end
                
                imgui.Spacing()
                if imgui.Button("Abrir Log (Hoje)", imgui.ImVec2(120, 25)) then
                    local date_str = os.date("%Y-%m-%d")
                    local path = getWorkingDirectory() .. '\\logs ip\\PainelInfo_ExtractedIPs_' .. date_str .. '.txt'
                    if doesFileExist(path) then
                        os.execute('explorer "' .. path .. '"')
                    else
                        local dir = getWorkingDirectory() .. '\\logs ip'
                        if not doesDirectoryExist(dir) then createDirectory(dir) end
                        os.execute('explorer "' .. dir .. '"')
                    end
                end
                imgui.SameLine()
                if imgui.Button("Abrir Relatorio Duplicados", imgui.ImVec2(180, 25)) then
                    local path = getWorkingDirectory() .. '\\logs ip\\PainelInfo_Duplicates.txt'
                    if doesFileExist(path) then
                        os.execute('explorer "' .. path .. '"')
                    else
                        local dir = getWorkingDirectory() .. '\\logs ip'
                        if not doesDirectoryExist(dir) then createDirectory(dir) end
                        os.execute('explorer "' .. dir .. '"')
                    end
                end
            else -- Extractor is active
                imgui.Text(string.format("Progresso: %d / %s", state.ip_extractor_current, state.ip_extractor_total_buf.v))
                if imgui.Button("Parar", imgui.ImVec2(80, 25)) then
                    state.ip_extractor_active = false
                    state.ip_req_queue = {}
                end
            end

            imgui.EndChild()

        -- [[ ABA CONFIG (ID 11) ]]
        elseif state.active_tab == 11 then
            imgui.TextColored(IMAGE_GREEN, "Configuracoes"); imgui.Separator()
            imgui.TextDisabled("Ajuste temas, transparencia, senha de admin e gerencie backups.")
            imgui.Spacing()
            
            local check_upd = imgui.ImBool(cfg.main.check_updates)
            if imgui.Checkbox("Verificar Atualizacoes ao Iniciar", check_upd) then
                cfg.main.check_updates = check_upd.v
                inicfg.save(cfg, "PainelInfoHelper_Config.ini")
            end
            
            if imgui.Button("Favoritar Tema (Salvar)", imgui.ImVec2(-1, 25)) then
                inicfg.save(cfg, "PainelInfoHelper_Config.ini")
                sampAddChatMessage("[PI] Tema e configuracoes salvos como favoritos!", -1)
            end

            if imgui.Button("Verificar Atualizacoes", imgui.ImVec2(-1, 25)) then
                check_update(true)
            end

            if imgui.Button("Abrir Repositorio GitHub", imgui.ImVec2(-1, 25)) then
                os.execute('explorer "https://github.com/cvradmin/paineladmincvr"')
            end
            
            imgui.Text("Senha Admin:")
            imgui.PushItemWidth(150)
            if imgui.InputText("##AdminPass", state.admin_pass_buf, imgui.InputTextFlags.Password) then
                cfg.main.admin_pass = state.admin_pass_buf.v
                inicfg.save(cfg, "PainelInfoHelper_Config.ini")
            end
            imgui.PopItemWidth()
            imgui.SameLine(); imgui.TextDisabled("(Salva auto)")
            
            if imgui.Button("Logar Admin (/flogar)", imgui.ImVec2(-1, 25)) then
                start_admin_login()
            end
            
            if imgui.Checkbox("Enviar /cheat no Login", state.auto_cheat_check) then
                cfg.main.auto_cheat = state.auto_cheat_check.v
                inicfg.save(cfg, "PainelInfoHelper_Config.ini")
            end
            imgui.SameLine(); imgui.TextDisabled("(Moderadores)")

            if imgui.Button("Reconectar (Fast Connect)", imgui.ImVec2(-1, 25)) then
                sampConnectToServer("15.235.123.105", 7777)
            end
            imgui.Spacing()

            if imgui.Combo("Tema", state.theme_combo_idx, theme_list) then
                local selected = theme_list[state.theme_combo_idx.v + 1]
                if selected then
                    cfg.main.theme = selected
                    inicfg.save(cfg, "PainelInfoHelper_Config.ini")
                    apply_theme(selected)
                    sampAddChatMessage("[PI] Tema alterado para: " .. selected, -1)
                end
            end

            imgui.Spacing()
            imgui.Text("Transparencia:")
            local alpha_val = imgui.ImFloat(tonumber(cfg.main.transparency) or 0.98)
            if imgui.SliderFloat("##AlphaSlider", alpha_val, 0.2, 1.0) then
                cfg.main.transparency = alpha_val.v
                apply_theme(cfg.main.theme)
                inicfg.save(cfg, "PainelInfoHelper_Config.ini")
            end
            
            imgui.Spacing()
            imgui.Text("Tecla de Atalho:")
            local k_name = key_names[cfg.main.bind] or tostring(cfg.main.bind)
            if waiting_for_bind then k_name = "Aguardando..." end
            if imgui.Button(k_name .. "##BindBtn", imgui.ImVec2(120, 25)) then
                waiting_for_bind = true
            end
            if waiting_for_bind then imgui.SameLine(); imgui.Text("Pressione uma tecla...") end
        end

        imgui.End()
    end
end

local function toggle_window() state.window_open.v = not state.window_open.v; imgui.Process = state.window_open.v end
sampRegisterChatCommand("painelhelper", toggle_window); sampRegisterChatCommand("phelper", toggle_window)
sampRegisterChatCommand("flogar", start_admin_login)
sampRegisterChatCommand("admesp", function() 
    esp_active = not esp_active
    sampAddChatMessage(esp_active and "[PI] ESP Admin Ativado." or "[PI] ESP Admin Desativado.", -1)
end)

function main()
    while not isSampfuncsLoaded() do wait(100) end; while not isSampAvailable() do wait(100) end; imgui.Process = state.window_open.v
    
    local saved_theme = (cfg.main and cfg.main.theme) or "Padrao"
    for i, t in ipairs(theme_list) do if t == saved_theme then state.theme_combo_idx.v = i - 1 end end
    state.ip_extractor_total_buf.v = "300"
    apply_theme(saved_theme)
    sampAddChatMessage("[PainelInfoHelper] Carregado e funcional! Pressione F12.", 0x00FF00)
    
    lua_thread.create(function()
        wait(2000)
        if cfg.main.check_updates then
            check_update()
        end
    end)

    while true do wait(0)
        draw_esp_logic()
        if waiting_for_bind then
            for k = 1, 255 do
                if wasKeyPressed(k) then
                    cfg.main.bind = k
                    inicfg.save(cfg, "PainelInfoHelper_Config.ini")
                    sampAddChatMessage("[PI] Nova tecla de atalho definida: " .. (key_names[k] or k), -1)
                    waiting_for_bind = false
                    break
                end
            end
        elseif wasKeyPressed(cfg.main.bind) and not sampIsChatInputActive() and not sampIsDialogActive() then toggle_window() end; imgui.Process = state.window_open.v
        if isKeyDown(vkeys.VK_MENU) and wasKeyPressed(vkeys.VK_L) and not sampIsChatInputActive() and not sampIsDialogActive() then
            start_admin_login()
        end
    end
end