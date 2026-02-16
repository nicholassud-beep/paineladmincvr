-- PainelInfo.lua
-- V8.8.2 (RESTAURAÇÃO COMPLETA + TEMAS + BACKUP)
-- Baseado no backup 8.5.2, com adição das funcionalidades de Temas e Configurações.

require 'lib.moonloader'
require 'lib.sampfuncs'
local sampev = require 'lib.samp.events'
local bit = require 'bit'
local memory = require 'memory'

local imgui = require 'imgui'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
encoding.default = 'CP1252'
local u8 = function(s) return s and encoding.UTF8(s) or "" end

script_name("PainelInfo")
script_author("Gerado por ChatGPT (GPT-5 Thinking mini) - Consolidado e Corrigido por Gemini, KOP")
script_version("9.0.51")
local script_ver_num = 9051
script_version_number(script_ver_num)

-- VARIAVEIS DO ADMIN ESP (INTEGRACAO)
local esp_active = false
local prof_tags_active = false
local esp_font = renderCreateFont('Arial', 10, 5) -- Arial 10 com Borda
local prof_font = nil -- Inicializado apos carregar config
local esp_spectate_id = -1
local esp_spectate_vehicle_id = -1
local last_shot_times = {}
local last_shot_weapons = {}
local last_shot_log_times = {}
local session_date_str = os.date("%Y-%m-%d_%H-%M-%S")
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
    active_prof_sub_tab = 1,
    active_locais_sub_tab = 1, -- 1=Interiores, 2=Eventos
    theme_combo_idx = imgui.ImInt(0),
    search_text = imgui.ImBuffer(256),
    current_sort_column = "ID",
    sort_direction = 1,
    veh_type_filter_idx = imgui.ImInt(0),
    prof_type_filter_idx = imgui.ImInt(0),
    weapon_type_filter_idx = imgui.ImInt(0),
    target_id_buf = imgui.ImBuffer(8),
    ammo_amount_buf = imgui.ImBuffer(8),
    saved_pos_name = imgui.ImBuffer(32),
    ip_extractor_total_buf = imgui.ImBuffer(5),
    ip_extractor_check_dupes = imgui.ImBool(false),
    ip_extractor_auto_save = imgui.ImBool(true),
    admin_pass_buf = imgui.ImBuffer(64),
    device_scanner_active = false,
    current_scan_info = nil,
    scan_response_received = false,
    player_devices = {},
    device_scan_progress = 0,
    scan_message_count = 0,
    edit_fav_name_buf = imgui.ImBuffer(64),
    server_ip_buf = imgui.ImBuffer(32),
    stop_spec_requested = false,
    active_prof_veh_filter = nil,
    player_ips = {},
    window_duvidas = imgui.ImBool(false),
    window_locais = imgui.ImBool(false),
    window_ferramentas = imgui.ImBool(false),
    window_veiculos = imgui.ImBool(false),
    window_skins = imgui.ImBool(false),
    window_armas = imgui.ImBool(false),
    window_profissoes = imgui.ImBool(false),
    search_text_duvidas = imgui.ImBuffer(256),
    search_text_locais = imgui.ImBuffer(256),
    search_text_veiculos = imgui.ImBuffer(256),
    search_text_skins = imgui.ImBuffer(256),
    search_text_armas = imgui.ImBuffer(256),
    search_text_profissoes = imgui.ImBuffer(256),
    waiting_login_dialog = false,
    manual_scan_id_buf = imgui.ImBuffer(5)
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
        server_ip = "15.235.123.105:7777",
        check_updates = true,
        esp_show_prof = true,
        esp_prof_offset = 0,
        esp_prof_bg_color = 0xE0000000,
        esp_side_list = false,
        esp_side_list_x = 10,
        esp_side_list_y = 0,
        esp_side_list_font_size = 7,
        esp_side_list_show_fist = true
    },
    blacklist = {}
}
local cfg = inicfg.load(cfg_default, "PainelInfo_Config_v8.ini")
if not cfg then
    cfg = cfg_default
    inicfg.save(cfg, "PainelInfo_Config_v8.ini")
end
if not cfg.main then cfg.main = cfg_default.main end
if not cfg.main.admin_pass then cfg.main.admin_pass = cfg_default.main.admin_pass end
state.admin_pass_buf.v = cfg.main.admin_pass
if not cfg.main.bind then cfg.main.bind = 123 end
if cfg.main.check_updates == nil then cfg.main.check_updates = true end
if not cfg.main.server_ip or cfg.main.server_ip == "" then cfg.main.server_ip = cfg_default.main.server_ip end
if not cfg.main.theme then cfg.main.theme = "Padrao" end
if not cfg.main.transparency then cfg.main.transparency = 0.98 end
if not cfg.main.esp_distance or type(cfg.main.esp_distance) ~= "number" then cfg.main.esp_distance = 6000 end
if cfg.main.esp_show_prof == nil then cfg.main.esp_show_prof = true end
if not cfg.main.esp_prof_offset then cfg.main.esp_prof_offset = 0 end
if not cfg.main.esp_prof_bg_color then cfg.main.esp_prof_bg_color = 0xE0000000 end
if cfg.main.esp_side_list == nil then cfg.main.esp_side_list = false end
if not cfg.main.esp_side_list_x then cfg.main.esp_side_list_x = 10 end
if not cfg.main.esp_side_list_y then cfg.main.esp_side_list_y = 0 end
if not cfg.main.esp_side_list_font_size then cfg.main.esp_side_list_font_size = 7 end
if cfg.main.esp_side_list_show_fist == nil then cfg.main.esp_side_list_show_fist = true end
if not cfg.blacklist then cfg.blacklist = {} end

prof_font = renderCreateFont('Arial', cfg.main.esp_side_list_font_size, 5)

-- LISTA DE TEMAS ATUALIZADA
local theme_list = {"Padrao", "Claro", "Roxo", "Vermelho", "Verde", "Laranja", "Amarelo", "Rosa", "Ciano", "Escuro"}
local key_names = {}
for k, v in pairs(vkeys) do key_names[v] = k end
local waiting_for_bind = false
local sw_running = false
local sw_start_time = 0
local sw_elapsed = 0
local blacklist_nick_buf = imgui.ImBuffer(32)
local blacklist_reason_buf = imgui.ImBuffer(64)
local blacklist_ip_buf = imgui.ImBuffer(20)
local blacklist_device_buf = imgui.ImBuffer(20)
local manual_prof_buf = imgui.ImBuffer(64)
local manual_veh_buf = imgui.ImBuffer(10)
-- IP Extractor vars
local ip_extractor_active = false
local ip_extractor_current = 0
local extracted_ips = {}
local ip_req_queue = {}

local blacklist_data = cfg.blacklist
local pending_ip_capture = nil

-- Função para salvar blacklist
local function save_blacklist()
    cfg.blacklist = blacklist_data
    inicfg.save(cfg, "PainelInfo_Config_v8.ini")
end

-- Função para Backup de Configuração (GLOBAL E CORRIGIDA)
local function backup_config()
    local backup_dir = getWorkingDirectory() .. "\\config\\backups"
    if not doesDirectoryExist(backup_dir) then createDirectory(backup_dir) end
    local date_str = os.date("%Y-%m-%d_%H-%M-%S")
    local backup_name = "backups\\PainelInfo_Config_" .. date_str .. ".ini"
    if inicfg.save(cfg, backup_name) then
        print("[PainelInfo] Backup de configuracao salvo: " .. backup_name)
    end
end

-- Variáveis de estado para Busca e Ordenação
local veh_types = {"Todos", "Terrestre", "Aereo", "Nautico"}
local prof_types = {"Todas", "Honestas", "Mafia"}
local weapon_types = {"Todas", "Corpo a corpo", "Pistola", "Espingarda", "Submetralhadora", "Fuzil de Assalto", "Rifle", "Pesada", "Arremessavel", "Especial", "Presente"}


-- CONFIGURAÇÃO DE ADMIN
local staff_by_rank = {
    Desenvolvedor = { "LKWilliam" },
    Direcao = { ".42.", "Boris", "LucasFirmino" },
    Coordenador = { "Dog.", "Cleyton.", "MatheusUnity", "DiegoN_", "DaviL" },
    Administrador = { "Mirian", "TomRedl.", "KrugeR.", "Ryu." },
    Moderador = { ".Lacta", "Belo", "Rafael182", "MateusVictor", "chukc", "Dr.Manhattan_.", "Lucasfuj", "Davi.", "LeonardoX", "Caua.." },
    Ajudante = { "Koyama.", "ZeGotinha_.", "Uberzitoh", "NotoriousBIG", "Liima.", "Scheppard", ".RagnaroK", "Faggio", "YuriUnity." },
    ["Estagiario"] = { "D0uglitas", "Duarte.Tm", "MitoMitoso", ".PATCHENCO", ".BS", "Freitas_" }
}
local staff_nick_to_rank_map = {}
for rank, nicks in pairs(staff_by_rank) do
    for _, nick in ipairs(nicks) do
        staff_nick_to_rank_map[string.lower(nick)] = rank
    end
end

-- MAPAS DE COR E DISPLAY PARA STAFF
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
local copy_rank_map = { ["Estagiario"] = "Estagiario" }

-- DETECCAO POR COR E HELPERS (MOVIDO PARA CIMA PARA EVITAR ERRO DE UPVALUES)
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
    local s = tostring(str):lower()
    s = s:gsub("[\224\225\226\227]", "a") -- áàâã
    s = s:gsub("[\232\233\234]", "e")     -- éê
    s = s:gsub("[\236\237]", "i")         -- í
    s = s:gsub("[\242\243\244\245]", "o") -- óôõ
    s = s:gsub("[\249\250]", "u")         -- ú
    s = s:gsub("[\231]", "c")             -- ç
    return s
end

local function set_nametag_status(enable)
    local samp = getModuleHandle("samp.dll")
    if not samp or samp == 0 then return end
    
    pcall(function()
        -- Verifica se e R1 (Offset 0x71428 ou 458280)
        local is_r1 = false
        local check_r1_a = memory.read(samp + 0x71428, 1, true)
        local check_r1_b = memory.read(samp + 458280, 1, true)
        
        if (check_r1_a == 0x74 or check_r1_a == 0x90) or (check_r1_b == 0x74 or check_r1_b == 0x90) then
            is_r1 = true
        end

        if is_r1 then
            -- Logica do Wallhack Fix (R1) - Convertida para nativo (memory.fill/write)
            if enable then
                -- NOPs (Preenche com 0x90)
                memory.fill(samp + 457971, 0x90, 6, true)
                memory.fill(samp + 458004, 0x90, 6, true)
                memory.fill(samp + 458280, 0x90, 2, true)
                memory.fill(samp + 462648, 0x90, 2, true)
                memory.fill(samp + 462372, 0x90, 6, true)
                if sampSetNameTagDrawDistance then sampSetNameTagDrawDistance(cfg.main.esp_distance) end
            else
                -- Restore (Restaura valores originais)
                memory.write(samp + 457971, 0x24216591, 4, true)
                memory.write(samp + 457975, 0x0000, 2, true)
                memory.write(samp + 458004, 0x22053903, 4, true)
                memory.write(samp + 458008, 0x0000, 2, true)
                memory.write(samp + 458280, 0x4074, 2, true)
                memory.write(samp + 462648, 0x6174, 2, true)
                memory.write(samp + 462372, 0x24218127, 4, true)
                memory.write(samp + 462376, 0x0000, 2, true)
                if sampSetNameTagDrawDistance then sampSetNameTagDrawDistance(70.0) end
            end
            print("[PainelInfo] Wallhack (R1 Fix) " .. (enable and "Ativado" or "Desativado"))
        else
            -- Fallback para outras versoes (R2, R3, R4, DL) - Metodo Simples
            local offsets = {
                { ver="R2", off=0x714A8, on=0x9090, off_val=0x1D74 },
                { ver="R3", off=0x75218, on=0x9090, off_val=0x1D74 },
                { ver="R4", off=0x75948, on=0x9090, off_val=0x1D74 },
                { ver="DL", off=0x759D8, on=0x9090, off_val=0x1D74 }
            }
            
            local detected = nil
            for _, item in ipairs(offsets) do
                local addr = samp + item.off
                local check = memory.read(addr, 1, true)
                if check == 0x74 or check == 0x90 then
                    detected = item
                    break
                end
            end
            
            if detected then
                local addr = samp + detected.off
                if enable then
                    memory.write(addr, detected.on, 2, true)
                    if sampSetNameTagDrawDistance then sampSetNameTagDrawDistance(cfg.main.esp_distance) end
                else
                    memory.write(addr, detected.off_val, 2, true)
                    if sampSetNameTagDrawDistance then sampSetNameTagDrawDistance(70.0) end
                end
                print("[PainelInfo] Wallhack (" .. detected.ver .. ") " .. (enable and "Ativado" or "Desativado"))
            else
                sampAddChatMessage("[PI] Erro: Versao do SAMP nao suportada para Wallhack.", 0xFF0000)
            end
        end
    end)
end

local function getCityFromCoords(x, y)
    if x > -920 and x < 3000 and y > -3000 and y < 430 then return "Los Santos" end
    if x > -3000 and x < -850 and y > -2000 and y < 3000 then return "San Fierro" end
    if x > 850 and x < 3000 and y > 500 and y < 3000 then return "Las Venturas" end
    return "San Andreas" -- Countryside/Desert
end

local log_dir = getWorkingDirectory() .. "\\logs tiros"
local shooting_log_buffer = {}
local last_log_flush = os.clock()

local function flush_shooting_logs()
    if #shooting_log_buffer == 0 then return end
    pcall(function()
        if not doesDirectoryExist(log_dir) then createDirectory(log_dir) end
        local p = log_dir .. "\\PainelInfo_Shooting_" .. session_date_str .. ".txt"
        local f = io.open(p, "a+")
        if f then
            for _, l in ipairs(shooting_log_buffer) do f:write(l) end
            f:close()
        end
    end)
    shooting_log_buffer = {}
    last_log_flush = os.clock()
end

local function logShooting(id, nick, weapon, x, y, z)
    local t = os.date("[%H:%M:%S]")
    local zone_name = getGxtText(getNameOfZone(x, y, z)) or "Desconhecido"
    local city_name = getCityFromCoords(x, y)
    local full_loc = string.format("%s, %s", zone_name, city_name)
    local l = string.format("%s Atirador: %s [%d] | Arma: %s | Local: %s (%.1f, %.1f, %.1f)\n", t, nick, id, weapon, full_loc, x, y, z)
    table.insert(shooting_log_buffer, l)
    
    if #shooting_log_buffer >= 50 then flush_shooting_logs() end
end

local function check_shooting_logic(chars)
    for _, handle in ipairs(chars) do
        if doesCharExist(handle) and handle ~= PLAYER_PED then
            local res, id = sampGetPlayerIdByCharHandle(handle)
            if res and sampIsPlayerConnected(id) then
                if isCharShooting(handle) then
                    last_shot_times[id] = os.clock()
                    last_shot_weapons[id] = getCurrentCharWeapon(handle)
                    
                    if not last_shot_log_times[id] or (os.clock() - last_shot_log_times[id] > 1.0) then
                        local wep = getCurrentCharWeapon(handle)
                        local wep_name = weapon_names_esp[wep] or "Desconhecida"
                        
                        local nick = sampGetPlayerNickname(id) or "Unknown"
                        local px, py, pz = getCharCoordinates(handle)
                        logShooting(id, nick, wep_name, px, py, pz)
                        last_shot_log_times[id] = os.clock()
                    end
                end
            end
        end
    end
end

-- FUNCAO LOGICA DO ESP (MOVIDA PARA CIMA)
local function draw_esp_logic(chars)
    local side_list_data = {}
    if (esp_active or prof_tags_active or cfg.main.esp_side_list) and esp_font and prof_font then
        local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
        local camX, camY, camZ = getActiveCameraCoordinates()
        local sw, sh = getScreenResolution()
        
        local render_list = {} 
        for _, handle in ipairs(chars) do
            if doesCharExist(handle) and handle ~= PLAYER_PED then
                local res, id = sampGetPlayerIdByCharHandle(handle)
                if res and sampIsPlayerConnected(id) then
                    local x, y, z = getCharCoordinates(handle)
                    local dist = getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z)
                    local onScreen = isPointOnScreen(x, y, z, 0.0)
                    if dist < cfg.main.esp_distance then
                        if onScreen or cfg.main.esp_side_list then
                            table.insert(render_list, {handle = handle, id = id, dist = dist, x = x, y = y, z = z, onScreen = onScreen})
                        end
                    end
                end
            end
        end
        
        table.sort(render_list, function(a, b) return a.dist < b.dist end)
        
        for _, item in ipairs(render_list) do
            local handle = item.handle
            local id = item.id
            local x, y, z = item.x, item.y, item.z

            -- Logica da Lista Lateral (Independente de estar na tela)
            if cfg.main.esp_side_list then
                local nick = sampGetPlayerNickname(id) or "Unknown"
                local rank = staff_nick_to_rank_map[string.lower(nick)]
                if not rank then
                    local s, n = pcall(encoding.CP1251, nick)
                    if s and n then rank = staff_nick_to_rank_map[string.lower(n)] end
                end
            
                if not rank then
                    local prof_name = get_closest_profession_name(sampGetPlayerColor(id))
                    if prof_name then
                        local wep_str = ""
                        local wep = getCurrentCharWeapon(handle)
                        if wep and wep > 0 and weapon_names_esp[wep] then wep_str = " [" .. weapon_names_esp[wep] .. "]" end
                        
                        table.insert(side_list_data, {id=id, nick=nick, prof=prof_name, color=sampGetPlayerColor(id), dist=item.dist, wep=wep_str})
                    end
                end
            end

            if (esp_active or prof_tags_active) and item.onScreen then
                local is_visible = true
                if not esp_active then
                    is_visible = isLineOfSightClear(camX, camY, camZ, x, y, z + 0.7, true, false, false, true, false)
                end

                if is_visible then
                    local drawX, drawY, drawZ
                    
                    if isCharInAnyCar(handle) then
                        local car = getCarCharIsUsing(handle)
                        if doesVehicleExist(car) then
                            local cx, cy, cz = getCarCoordinates(car)
                            drawX, drawY, drawZ = cx, cy, cz + 1.3
                        else
                            drawX, drawY, drawZ = x, y, z + 1.3
                        end
                    else
                        local res, hx, hy, hz = pcall(getBodyPartCoordinates, handle, 8) -- Bone 8 = Cabeca
                        if res and hx and hx ~= 0 then
                            drawX, drawY = hx, hy
                            drawZ = hz + (esp_active and 0.5 or 0.35)
                        else
                            drawX, drawY = x, y
                            drawZ = z + (esp_active and 2.1 or 1.95)
                        end
                    end
                    local headX, headY = convert3DCoordsToScreen(drawX, drawY, drawZ)
                    
                    if headX and headY then
                        local currentY = headY

                        if last_shot_times[id] and (os.clock() - last_shot_times[id] < 1.0) then
                            local wep_name = weapon_names_esp[last_shot_weapons[id]] or "Arma"
                            local shoot_text = "[ATIRANDO: " .. string.upper(wep_name) .. "]"
                            local sW = renderGetFontDrawTextLength(esp_font, shoot_text)
                            renderFontDrawText(esp_font, shoot_text, headX - (sW / 2), currentY - 12, 0xFFFF0000)
                        end

                        local nick = sampGetPlayerNickname(id) or "Unknown"

                        currentY = currentY + (cfg.main.esp_prof_offset or 0)

                        if (prof_tags_active or (esp_active and cfg.main.esp_show_prof)) and not cfg.main.esp_side_list then
                            local rank = staff_nick_to_rank_map[string.lower(nick)]
                            if not rank then
                                local s, n = pcall(encoding.CP1251, nick)
                                if s and n then rank = staff_nick_to_rank_map[string.lower(n)] end
                            end
                        
                            if not rank then
                                local prof_name = get_closest_profession_name(sampGetPlayerColor(id))
                                
                                if prof_name then
                                        local lines = {}
                                        table.insert(lines, string.format("[%d] %s", id, prof_name))
                                        
                                        if #lines > 0 then
                                            local maxW = 0
                                            for _, l in ipairs(lines) do local w = renderGetFontDrawTextLength(prof_font, l); if w > maxW then maxW = w end end
                                            local totalH = #lines * 10
                                            
                                            local bg_col = cfg.main.esp_prof_bg_color or 0xE0000000
                                            renderDrawBox(headX - (maxW / 2) - 2, currentY - 1, maxW + 4, totalH + 2, bg_col)
                                    
                                            local pColor = sampGetPlayerColor(id)
                                            if pColor == 0 then pColor = 0xFFFFFFFF end
                                            pColor = bit.bor(pColor, 0xFF000000)

                                            for i, l in ipairs(lines) do
                                                local w = renderGetFontDrawTextLength(prof_font, l)
                                                renderFontDrawText(prof_font, l, headX - (w / 2), currentY + ((i-1)*10), pColor)
                                            end
                                            currentY = currentY + totalH + 2
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if #side_list_data > 0 then
            table.sort(side_list_data, function(a, b) return a.id < b.id end) -- Ordena por ID para ficar fixo
            local startY = sh / 2 - (#side_list_data * 14) / 2
            local maxW = 0
            for _, item in ipairs(side_list_data) do
                local text = string.format("[%d] %s - %s%s (%.0fm)", item.id, item.nick, item.prof, item.wep or "", item.dist)
                local w = renderGetFontDrawTextLength(prof_font, text)
                if w > maxW then maxW = w end
            end
            
            renderDrawBox(10, startY - 5, maxW + 10, #side_list_data * 14 + 10, 0x80000000)
            
            for i, item in ipairs(side_list_data) do
                local text = string.format("[%d] %s - %s%s (%.0fm)", item.id, item.nick, item.prof, item.wep or "", item.dist)
                local pColor = item.color
                if pColor == 0 then pColor = 0xFFFFFFFF end
                pColor = bit.bor(pColor, 0xFF000000)
                
                renderFontDrawText(prof_font, text, 15, startY + (i-1)*14, pColor)
            end
        end
    end
end

-- LISTAS DE DADOS COMPLETAS
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
prof_type_map["ladrao de veiculos"] = "Mafia"
prof_type_map["chefao da mafia"] = "Mafia"
local weapons_list = { {id = 0, name = "Unarmed", type = "Corpo a corpo"}, {id = 1, name = "Brass Knuckles", type = "Corpo a corpo"}, {id = 2, name = "Golf Club", type = "Corpo a corpo"}, {id = 3, name = "Nite Stick", type = "Corpo a corpo"}, {id = 4, name = "Knife", type = "Corpo a corpo"}, {id = 5, name = "Baseball Bat", type = "Corpo a corpo"}, {id = 6, name = "Shovel", type = "Corpo a corpo"}, {id = 7, name = "Pool Cue", type = "Corpo a corpo"}, {id = 8, name = "Katana", type = "Corpo a corpo"}, {id = 9, name = "Chainsaw", type = "Corpo a corpo"}, {id = 10, name = "Purple Dildo", type = "Corpo a corpo"}, {id = 11, name = "Dildo", type = "Corpo a corpo"}, {id = 12, name = "Vibrator", type = "Corpo a corpo"}, {id = 13, name = "Silver Vibrator", type = "Corpo a corpo"}, {id = 14, name = "Flower", type = "Presente"}, {id = 15, name = "Cane", type = "Presente"}, {id = 16, name = "Grenade", type = "Arremessavel"}, {id = 17, name = "Tear Gas", type = "Arremessavel"}, {id = 18, name = "Molotov Cocktail", type = "Arremessavel"}, {id = 22, name = "9mm", type = "Pistola"}, {id = 23, name = "Silenced 9mm", type = "Pistola"}, {id = 24, name = "Desert Eagle", type = "Pistola"}, {id = 25, name = "Shotgun", type = "Espingarda"}, {id = 26, name = "Sawnoff Shotgun", type = "Espingarda"}, {id = 27, name = "Combat Shotgun", type = "Espingarda"}, {id = 28, name = "Micro Uzi (MP5)", type = "Submetralhadora"}, {id = 29, name = "MP5", type = "Submetralhadora"}, {id = 30, name = "AK-47", type = "Fuzil de Assalto"}, {id = 31, name = "M4", type = "Fuzil de Assalto"}, {id = 32, name = "Tec-9", type = "Submetralhadora"}, {id = 33, name = "Country Rifle", type = "Rifle"}, {id = 34, name = "Sniper Rifle", type = "Rifle"}, {id = 35, name = "RPG", type = "Pesada"}, {id = 36, name = "HS Rocket", type = "Pesada"}, {id = 37, name = "Flamethrower", type = "Pesada"}, {id = 38, name = "Minigun", type = "Pesada"}, {id = 39, name = "Satchel Charge", type = "Arremessavel"}, {id = 40, name = "Detonator", type = "Especial"}, {id = 41, name = "Spraycan", type = "Especial"}, {id = 42, name = "Fire Extinguisher", type = "Especial"}, {id = 43, name = "Camera", type = "Especial"}, {id = 44, name = "NV Goggles", type = "Especial"}, {id = 45, name = "IR Goggles", type = "Especial"}, {id = 46, name = "Parachute", type = "Especial"} }
local interiors_list = { {name = "Ringue Admin", x = -1021.416, y = 1061.801, z = 1343.177, id = 0, desc = "Eventos/Admins."}, {name = "Sweet's House", x = 2525.0420, y = -1679.1150, z = 1015.4990, id = 1, desc = "Casa do Sweet (LS)."}, {name = "Ammu-nation 1 (LS)", x = 289.7870, y = -35.7190, z = 1003.5160, id = 1, desc = "Ammu-nation genérica."}, {name = "Caligulas Casino", x = 2235.2524, y = 1708.5146, z = 1010.6129, id = 1, desc = "Cassino Caligula (LV)."}, {name = "The Camel's Toe safehouse (LV)", x = 2216.1282, y = -1076.3052, z = 1050.4844, id = 1, desc = "Safe House (LV)."}, {name = "Casa de Assalto (Modelo 1)", x = 224.6351, y = 1289.012, z = 1082.141, id = 1, desc = "Interior genérico casa."}, {name = "Transfender (LS)", x = 621.7850, y = -12.5417, z = 1000.9220, id = 1, desc = "Garagem Transfender."}, {name = "Liberty City", x = -741.8495, y = 493.0036, z = 1371.9766, id = 1, desc = "Interior Liberty City."}, {name = "Açougue", x = 963.0586, y = 2159.7563, z = 1011.0303, id = 1, desc = "Interior Açougue."}, {name = "Ryder's House", x = 2464.2110, y = -1697.9520, z = 1013.5080, id = 2, desc = "Casa Ryder (Ganton)."}, {name = "Angel Pine trailer", x = 0.3440, y = -0.5140, z = 1000.5490, id = 2, desc = "Interior trailer."}, {name = "Big Smoke's Crack Palace", x = 2543.6610, y = -1303.9320, z = 1025.0700, id = 2, desc = "Mansão (Missão)."}, {name = "Loco Low Co. (Garagem)", x = 612.5910, y = -75.6370, z = 997.9920, id = 2, desc = "Garagem Lowriders (LS)."}, {name = "Barbearia Reece's", x = 612.5910, y = -75.6370, z = 997.9920, id = 2, desc = "Barbearia (Idlewood)."}, {name = "CJ's House", x = 2496.0500, y = -1693.9260, z = 1015.4990, id = 3, desc = "Casa CJ (Ganton)."}, {name = "LVPD HQ", x = 288.4723, y = 170.0647, z = 1007.1794, id = 3, desc = "Sede Polícia (LV)."}, {name = "Planejamento Urbano", x = 374.6708, y = 173.8050, z = 1008.3893, id = 3, desc = "Prédio escritórios."}, {name = "Boate (Bordell)", x = 940.6520, y = -18.4860, z = 1000.9300, id = 3, desc = "Interior boate."}, {name = "OG Loc's House", x = 516.8890, y = -18.4120, z = 1001.5650, id = 3, desc = "Casa OG Loc (Ganton)."}, {name = "Tattoo Parlor (LV)", x = -204.4390, y = -43.6520, z = 1002.2990, id = 3, desc = "Loja tatuagens (LV)."}, {name = "Sex Shop", x = -106.7268, y = -19.6444, z = 1000.7190, id = 3, desc = "Interior Sex Shop."}, {name = "Jizzy's Pleasure Domes", x = -2636.7190, y = 1402.9170, z = 906.4609, id = 3, desc = "Boate Jizzy (SF)."}, {name = "24/7 shop 1", x = -27.3769, y = -27.6416, z = 1003.5570, id = 4, desc = "Loja 24/7 (Mod 1)."}, {name = "Ammu-Nation 2 (SF)", x = 285.8000, y = -84.5470, z = 1001.5390, id = 4, desc = "Ammu-nation."}, {name = "Madd Dogg's Mansion", x = 1262.1451, y = -785.3297, z = 1091.9062, id = 5, desc = "Mansão Mad Dogg."}, {name = "Well Stacked Pizza Co.", x = 377.7758, y = -126.2766, z = 1001.4920, id = 5, desc = "Pizzaria."}, {name = "Ganton Gym", x = 768.0793, y = 5.8606, z = 1000.7160, id = 5, desc = "Academia Ganton."}, {name = "LSPD HQ", x = 246.4510, y = 65.5860, z = 1003.6410, id = 6, desc = "Sede Polícia (LS)."}, {name = "RC Zero's Shop", x = -2241.0700, y = 128.5200, z = 1035.4195, id = 6, desc = "Loja RC Zero (SF)."}, {name = "24/7 shop 2", x = -26.7180, y = -55.9860, z = 1003.5470, id = 6, desc = "Loja 24/7 (Mod 2)."}, {name = "Interior/Eventos de X1", x = 773.8800, y = -47.7600, z = 1000.5800, id = 6, desc = "Academia SF."}, {name = "Safe House 3", x = 2333.0330, y = -1073.9600, z = 1049.0230, id = 6, desc = "Safe House (LV)."}, {name = "Millie's Bedroom", x = 344.5200, y = 304.8210, z = 999.1480, id = 6, desc = "Quarto Millie."}, {name = "Ammu-Nation 5 (2 Floors)", x = 315.3850, y = -142.2420, z = 999.6010, id = 7, desc = "Ammu-nation c/ tiro."}, {name = "8-Track Stadium", x = -1417.8720, y = -276.4260, z = 1051.1910, id = 7, desc = "Estádio 8-Track."}, {name = "Below the Belt Gym (LV)", x = 774.2430, y = -76.0090, z = 1000.6540, id = 7, desc = "Academia (LV)."}, {name = "Verdant Bluffs safehouse", x = 2365.1089, y = -1133.0795, z = 1050.875, id = 8, desc = "Safe House (LS)."}, {name = "Cluckin' Bell (Modelo 1)", x = 366.0002, y = -9.4338, z = 1001.8516, id = 9, desc = "Cluckin' Bell (Mod 1)."}, {name = "Safehouse 3 (Hospital LV)", x = 2319.1272, y = -1023.9562, z = 1050.2109, id = 9, desc = "Safe House (LV)."}, {name = "Four Dragons Casino", x = 2016.1156, y = 1017.1541, z = 996.875, id = 10, desc = "Cassino Four Dragons."}, {name = "SFPD HQ", x = 246.0688, y = 108.9703, z = 1003.2188, id = 10, desc = "Sede Polícia (SF)."}, {name = "Abandoned AC tower", x = 419.8936, y = 2537.1155, z = 10.0000, id = 10, desc = "Aeroporto Abandonado."}, {name = "Burger Shot (Modelo 2)", x = 366.0248, y = -73.3478, z = 1001.5078, id = 10, desc = "Burger Shot (Mod 2)."}, {name = "24/7 shop 3", x = 6.0780, y = -28.6330, z = 1003.5490, id = 10, desc = "Loja 24/7 (Mod 3)."}, {name = "Willowfield safehouse", x = 2282.9766, y = -1140.2861, z = 1050.8984, id = 11, desc = "Safe House (Willowfield)."}, {name = "Barbearia SF", x = 411.9707, y = -51.9217, z = 1001.8984, id = 12, desc = "Barbearia (SF)."}, {name = "Wardrobe/Changing room", x = 256.9047, y = -41.6537, z = 1002.0234, id = 14, desc = "Vestiário/Provador."}, {name = "Arena/Obstáculos (Eventos)", x = -1420.4200, y = 1616.9200, z = 1052.5300, id = 14, desc = "Interior arena."}, {name = "Binco (LS)", x = 207.5219, y = -109.7448, z = 1005.1328, id = 15, desc = "Loja Binco (LS)."}, {name = "Arena/Eventos2", x = -1401.0600, y = 1265.3700, z = 1039.8600, id = 16, desc = "Interior Arena 2."}, {name = "24/7 shop (Modelo 1)", x = -25.7220, y = -187.8216, z = 1003.5469, id = 17, desc = "Loja 24/7 (Mod 1)."}, {name = "Rusty Brown's Donuts", x = 378.026, y = -190.5155, z = 1000.6328, id = 17, desc = "Lanchonete Donuts."}, }

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
local events_file = getWorkingDirectory() .. "\\config\\PainelInfo_Events.json"
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

-- LISTA DE DUVIDAS (FAQ) - Preencha aqui
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

-- CORES IMGUI PADRÃO E FUNÇÕES UTILITÁRIAS
local UI_COLORS = {
    RED = imgui.ImVec4(1, 0, 0, 1),
    GREEN = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
    BLUE = imgui.ImVec4(0, 0.75, 1, 1),
    YELLOW = imgui.ImVec4(1, 1, 0, 1),
    WHITE = imgui.ImVec4(1, 1, 1, 1),
    GREY = imgui.ImVec4(0.5, 0.5, 0.5, 1),
    PINK = imgui.ImVec4(1, 0.4, 0.8, 1),
    BLACK = imgui.ImVec4(0, 0, 0, 1)
}
local SpanAllColumns = imgui.SelectableFlags and imgui.SelectableFlags.SpanAllColumns or 0

local function get_display_rank(k) return display_rank_map[k] or k end
local function get_rank_color(k) return rank_color_map[k] or rank_color_map.Default end
local function get_copy_rank(k) return copy_rank_map[k] or k or "?" end
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
local function logIPRequestToFile(id, nick)
    pcall(function()
        local dir = getWorkingDirectory() .. "\\logs ip"
        if not doesDirectoryExist(dir) then createDirectory(dir) end
        local date_str = os.date("%Y-%m-%d")
        local p = dir .. "\\PainelInfo_IP_Logs_" .. date_str .. ".txt"
        local t = os.date("[%Y-%m-%d %H:%M:%S]")
        local l = string.format("%s [ID: %d] [Nick: %s]\n", t, id, u8(nick))
        local f = io.open(p, "a+")
        if f then
            f:write(l)
            f:close()
        else
            print("[PI] Erro log IP:", p)
        end
    end)
end
local function get_ping_color(p)
    local n = (type(p) == "number" and p) or 0
    if n < 100 then return UI_COLORS.GREEN
    elseif n <= 200 then return UI_COLORS.YELLOW
    else return UI_COLORS.RED
    end
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
            for ip, entries in pairs(extracted_ips) do
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
    local tl = t -- Ja vem normalizado
    local tn = tonumber(t)
    for _, p in ipairs(l) do
        local nl = remove_accents(p.name or "")
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

local function filter_vehicles(l, t, scol, sdir, type_filter)
    local f = {}
    local tl = t -- Ja vem normalizado
    for _, v in ipairs(l) do
        local ids = tostring(v.id or "")
        local nl = remove_accents(v.name or "")
        local typl = remove_accents(v.type or "")
        local ps = tostring(v.price or "")
        local sps = tostring(v.speed or "")
        
        local type_match = true
        if type_filter and type_filter ~= "Todos" then
            if not (v.type and v.type:find(type_filter, 1, true)) then
                type_match = false
            end
        end

        if type_match and (ids:find(tl, 1, true) or nl:find(tl, 1, true) or typl:find(tl, 1, true) or ps:find(tl, 1, true) or sps:find(tl, 1, true)) then
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

-- =========================================================================
-- FUNÇÃO DE FILTRO DE SKINS CORRIGIDA (V8.4.16)
-- =========================================================================
local function filter_skins(t)
    local f = {}
    local tl = t -- Ja vem normalizado
    
    -- Itera a lista principal de skins (skins_list) diretamente
    for _, s in ipairs(skins_list) do
        local id_str = tostring(s.id)
        local name_lower = remove_accents(s.name or "")
        
        -- Verifica se o ID (string) ou o Nome (lowercase) batem com a busca
        if (id_str:find(tl, 1, true) or name_lower:find(tl, 1, true)) then
            -- Se bater, insere a tabela de skin *original* (que contém o ID correto)
            -- na lista filtrada 'f'.
            table.insert(f, s)
        end
    end
    
    -- Ordena a lista filtrada 'f' pelo ID da skin
    pcall(table.sort, f, function(a, b) return (a.id or -1) < (b.id or -1) end)
    
    -- Retorna a lista filtrada e ordenada
    return f
end
-- =========================================================================

local function filter_weapons(l, t, type_filter)
    local f = {}
    local tl = t -- Ja vem normalizado
    for _, w in ipairs(l) do
        local ids = tostring(w.id or "")
        local nl = remove_accents(w.name or "")
        local typl = remove_accents(w.type or "")
        
        local type_match = true
        if type_filter and type_filter ~= "Todas" then
            if w.type ~= type_filter then type_match = false end
        end

        if type_match and (ids:find(tl, 1, true) or nl:find(tl, 1, true) or typl:find(tl, 1, true)) then
            table.insert(f, w)
        end
    end
    pcall(table.sort, f, function(a, b) return (a.id or -1) < (b.id or -1) end)
    return f
end

local function filter_interiors(l, t)
    local f = {}
    local tl = t -- Ja vem normalizado
    for _, i in ipairs(l) do
        local nl = remove_accents(i.name or "")
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

local function strip_colors(s)
    if not s then return "" end
    s = s:gsub("{.-}", ""):gsub("~.-~", ""):gsub(" +", " ")
    return s:match("^%s*(.-)%s*$") or ""
end

function sampev.onServerMessage(color, text)
    if ip_extractor_active then
        local ip = text:match("(%d+%.%d+%.%d+%.%d+)")
        if ip then
            local log_text = text
            local p_info = nil
            if #ip_req_queue > 0 then
                local info = table.remove(ip_req_queue, 1)
                if info then
                    p_info = info
                    state.player_ips[info.id] = {ip = ip, nick = info.name}
                    log_text = string.format("Nick: %s (ID: %d) | %s", info.name, info.id, text)
                end
            end
            logFoundIP(log_text)
            if state.ip_extractor_check_dupes.v then
                if not extracted_ips[ip] then extracted_ips[ip] = {} end
                table.insert(extracted_ips[ip], { txt = log_text, info = p_info })
            end
        end
    end
    
    if state.device_scanner_active and state.current_scan_info and state.current_scan_info.name then
        local txt = text:lower()
        local name_lower = state.current_scan_info.name:lower()
        if txt:find(name_lower, 1, true) or txt:find("ip:") or txt:find("%d+%.%d+%.%d+%.[%d%*]+") or txt:find("android") or txt:find("mobile") or txt:find("celular") or txt:find("launcher") then
            local ip = text:match("(%d+%.%d+%.%d+%.%d+)")
            if ip then
                state.player_ips[state.current_scan_info.id] = {ip = ip, nick = state.current_scan_info.name}
                local log_text = string.format("Nick: %s (ID: %d) | %s", state.current_scan_info.name, state.current_scan_info.id, text)
                logFoundIP(log_text)
                if state.ip_extractor_check_dupes.v then
                    if not extracted_ips[ip] then extracted_ips[ip] = {} end
                    table.insert(extracted_ips[ip], { txt = log_text, info = state.current_scan_info })
                end
            end

            local detected = nil
            if txt:find("android") or txt:find("mobile") or txt:find("celular") then
                detected = "Mobile"
            elseif txt:find("%f[%a]pc%f[%A]") or txt:find("computador") or txt:find("windows") or txt:find("launcher") or txt:find("client") then
                detected = "PC"
            elseif txt:find("%d+%.%d+%.%d+%.[%d%*]+") then
                if not state.player_devices[state.current_scan_info.id] then
                    detected = "PC"
                end
            end

            if detected then 
                state.player_devices[state.current_scan_info.id] = detected 
                if detected == "Mobile" or txt:find("pc") then state.scan_response_received = true end
            end
            
            state.scan_message_count = state.scan_message_count + 1
            return false
        end
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if ip_extractor_active then
        local content = (text or "") .. " " .. (title or "")
        local ip = content:match("(%d+%.%d+%.%d+%.%d+)")
        if ip then
            local log_text = "Dialog: " .. (title or "") .. " " .. (text or "")
            local p_info = nil
            if #ip_req_queue > 0 then
                local info = table.remove(ip_req_queue, 1)
                if info then
                    p_info = info
                    state.player_ips[info.id] = {ip = ip, nick = info.name}
                    log_text = string.format("Nick: %s (ID: %d) | %s", info.name, info.id, log_text)
                end
            end
            logFoundIP(log_text)
            if state.ip_extractor_check_dupes.v then
                if not extracted_ips[ip] then extracted_ips[ip] = {} end
                table.insert(extracted_ips[ip], { txt = log_text, info = p_info })
            end
        end
        return false
    end

    if state.device_scanner_active then
        local content = strip_colors((title or "") .. " " .. (text or "")):lower()
        local raw_text = (title or "") .. " " .. (text or "")
        local ip = raw_text:match("(%d+%.%d+%.%d+%.%d+)")
        if ip and state.current_scan_info then
            state.player_ips[state.current_scan_info.id] = {ip = ip, nick = state.current_scan_info.name}
            local log_text = string.format("Nick: %s (ID: %d) | Dialog: %s", state.current_scan_info.name, state.current_scan_info.id, raw_text)
            logFoundIP(log_text)
            if state.ip_extractor_check_dupes.v then
                if not extracted_ips[ip] then extracted_ips[ip] = {} end
                table.insert(extracted_ips[ip], { txt = log_text, info = state.current_scan_info })
            end
        end

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
        return false
    end
end

function sampev.onDisplayGameText(style, time, text)
    if state.device_scanner_active then return false end
end

function sampev.onShowTextDraw(id, data)
    if state.device_scanner_active then return false end
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

-- HOOKS DO ESP (SPECTATE)
function sampev.onTogglePlayerSpectating(toggle)
    if not toggle then 
        esp_spectate_id = -1 
        esp_spectate_vehicle_id = -1
    end

    if toggle then
        state.stop_spec_requested = false
    elseif state.stop_spec_requested then
        state.stop_spec_requested = false
        lua_thread.create(function() wait(500) sampSendChat("/godmod") end)
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

function sampev.onSendCommand(cmd)
    local c = cmd:lower()
    if c:find("^/pararespiar") or c:find("^/specoff") or c:find("^/reoff") then
        state.stop_spec_requested = true
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

-- SETUP STYLE / TEMAS
local function apply_theme(theme_name)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local alpha = tonumber(cfg.main.transparency) or 0.98

    -- Arredondamentos e Tamanhos
    style.WindowRounding = 8.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5) -- Título centralizado
    style.FrameRounding = 4.0
    style.ItemSpacing = imgui.ImVec2(8, 4)
    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 9.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 3.0

    if theme_name == "Claro" then
        if imgui.StyleColorsLight then imgui.StyleColorsLight() end
        colors[clr.WindowBg] = ImVec4(0.82, 0.82, 0.82, alpha) -- Fundo cinza mais suave
        colors[clr.TitleBg] = ImVec4(0.70, 0.70, 0.70, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.55, 0.55, 0.55, 1.00)
        colors[clr.Button] = ImVec4(0.65, 0.65, 0.65, 0.40)
        colors[clr.ButtonHovered] = ImVec4(0.55, 0.55, 0.55, 0.50)
        colors[clr.ButtonActive] = ImVec4(0.45, 0.45, 0.45, 1.00)
        colors[clr.Separator] = ImVec4(0.3, 0.3, 0.3, 0.50) -- Cinza escuro para tema claro
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
        colors[clr.Separator] = ImVec4(0.80, 0.20, 0.20, 0.50) -- Vermelho mais vibrante
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
    elseif theme_name == "Rosa" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.12, 0.08, 0.10, alpha)
        colors[clr.TitleBg] = ImVec4(0.40, 0.05, 0.25, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.60, 0.10, 0.40, 1.00)
        colors[clr.Button] = ImVec4(0.50, 0.10, 0.30, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.70, 0.15, 0.45, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.80, 0.20, 0.50, 1.00)
        colors[clr.CheckMark] = ImVec4(1.00, 0.40, 0.80, 1.00)
        colors[clr.SliderGrab] = ImVec4(1.00, 0.40, 0.80, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(1.00, 0.60, 0.90, 1.00)
        colors[clr.Header] = ImVec4(0.50, 0.10, 0.30, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.70, 0.15, 0.45, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.80, 0.20, 0.50, 1.00)
        colors[clr.Separator] = ImVec4(0.80, 0.20, 0.50, 0.50)
        colors[clr.TextSelectedBg] = ImVec4(1.00, 0.40, 0.80, 0.35)
    elseif theme_name == "Ciano" then
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.WindowBg] = ImVec4(0.08, 0.12, 0.12, alpha)
        colors[clr.TitleBg] = ImVec4(0.05, 0.35, 0.40, 1.00)
        colors[clr.TitleBgActive] = ImVec4(0.10, 0.50, 0.55, 1.00)
        colors[clr.Button] = ImVec4(0.10, 0.45, 0.50, 0.60)
        colors[clr.ButtonHovered] = ImVec4(0.20, 0.65, 0.70, 0.80)
        colors[clr.ButtonActive] = ImVec4(0.30, 0.80, 0.85, 1.00)
        colors[clr.CheckMark] = ImVec4(0.20, 0.90, 1.00, 1.00)
        colors[clr.SliderGrab] = ImVec4(0.20, 0.90, 1.00, 1.00)
        colors[clr.SliderGrabActive] = ImVec4(0.40, 1.00, 1.00, 1.00)
        colors[clr.Header] = ImVec4(0.10, 0.45, 0.50, 0.50)
        colors[clr.HeaderHovered] = ImVec4(0.20, 0.65, 0.70, 0.80)
        colors[clr.HeaderActive] = ImVec4(0.30, 0.80, 0.85, 1.00)
        colors[clr.Separator] = ImVec4(0.20, 0.70, 0.75, 0.50)
        colors[clr.TextSelectedBg] = ImVec4(0.20, 0.90, 1.00, 0.35)
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
    else -- Padrao (Dark Blueish)
        if imgui.StyleColorsDark then imgui.StyleColorsDark() end
        colors[clr.Text]                  = ImVec4(0.95, 0.96, 0.98, 1.00)
        colors[clr.TextDisabled]          = ImVec4(0.36, 0.42, 0.47, 1.00)
        colors[clr.WindowBg]              = ImVec4(0.11, 0.12, 0.14, 0.98)
        colors[clr.ChildWindowBg]         = ImVec4(0.15, 0.16, 0.18, 0.00)
        colors[clr.PopupBg]               = ImVec4(0.08, 0.08, 0.08, 0.94)
        colors[clr.Border]                = ImVec4(0.08, 0.10, 0.12, 0.00)
        colors[clr.BorderShadow]          = ImVec4(0.00, 0.00, 0.00, 0.00)
        colors[clr.FrameBg]               = ImVec4(0.20, 0.22, 0.24, 0.54)
        colors[clr.FrameBgHovered]        = ImVec4(0.40, 0.42, 0.44, 0.40)
        colors[clr.FrameBgActive]         = ImVec4(0.28, 0.28, 0.28, 0.67)
        colors[clr.TitleBg]               = ImVec4(0.09, 0.09, 0.09, 1.00)
        colors[clr.TitleBgActive]         = ImVec4(0.13, 0.13, 0.13, 1.00)
        colors[clr.TitleBgCollapsed]      = ImVec4(0.00, 0.00, 0.00, 0.51)
        colors[clr.MenuBarBg]             = ImVec4(0.14, 0.14, 0.14, 1.00)
        colors[clr.ScrollbarBg]           = ImVec4(0.02, 0.02, 0.02, 0.53)
        colors[clr.ScrollbarGrab]         = ImVec4(0.31, 0.31, 0.31, 1.00)
        colors[clr.ScrollbarGrabHovered]  = ImVec4(0.41, 0.41, 0.41, 1.00)
        colors[clr.ScrollbarGrabActive]   = ImVec4(0.51, 0.51, 0.51, 1.00)
        colors[clr.CheckMark]             = ImVec4(0.26, 0.59, 0.98, 1.00)
        colors[clr.SliderGrab]            = ImVec4(0.24, 0.52, 0.88, 1.00)
        colors[clr.SliderGrabActive]      = ImVec4(0.26, 0.59, 0.98, 1.00)
        colors[clr.Button]                = ImVec4(0.20, 0.22, 0.24, 0.80)
        colors[clr.ButtonHovered]         = ImVec4(0.26, 0.59, 0.98, 0.50)
        colors[clr.ButtonActive]          = ImVec4(0.06, 0.53, 0.98, 1.00)
        colors[clr.Header]                = ImVec4(0.26, 0.59, 0.98, 0.31)
        colors[clr.HeaderHovered]         = ImVec4(0.26, 0.59, 0.98, 0.80)
        colors[clr.HeaderActive]          = ImVec4(0.26, 0.59, 0.98, 1.00)
        colors[clr.ResizeGrip]            = ImVec4(0.26, 0.59, 0.98, 0.25)
        colors[clr.ResizeGripHovered]     = ImVec4(0.26, 0.59, 0.98, 0.67)
        colors[clr.ResizeGripActive]      = ImVec4(0.26, 0.59, 0.98, 0.95)
        colors[clr.PlotLines]             = ImVec4(0.61, 0.61, 0.61, 1.00)
        colors[clr.PlotLinesHovered]      = ImVec4(1.00, 0.43, 0.35, 1.00)
        colors[clr.TextSelectedBg]        = ImVec4(0.26, 0.59, 0.98, 0.35)
        colors[clr.ModalWindowDarkening]  = ImVec4(0.80, 0.80, 0.80, 0.35)
        colors[clr.Separator]             = ImVec4(1.00, 1.00, 1.00, 0.25)
        colors[clr.SeparatorHovered]      = ImVec4(1.00, 1.00, 1.00, 0.50)
        colors[clr.SeparatorActive]       = ImVec4(1.00, 1.00, 1.00, 0.75)
    end
end

-- FUNÇÕES DE CABEÇALHO
-- [[ V8.4.11: draw_player_header com SameLine e cabecalhos sem acento ]]
local function draw_player_header(show_pcol)
    local idw=40; local nickw=show_pcol and 150 or 250; local profw=show_pcol and 160 or 0; local lvlw=40; local pingw=110
    local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]
    local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nickw
    imgui.Text("ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text("Nick")
    local p3ps,p3s,p4ls,p4s,p5ps
    if show_pcol then
        p3ps=p2s+sw+sp; p3s=p3ps+profw; imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps); imgui.Text("Profissão / Cargo")
        p4ls=p3s+sw+sp
    else
        p4ls=p2s+sw+sp
    end
    imgui.SameLine(show_pcol and p3s or p2s); imgui.TextColored(sc,st); imgui.SameLine(p4ls); imgui.Text("Nível")
    p4s=p4ls+lvlw; p5ps=p4s+sw+sp; imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ps); imgui.Text("Ping")
    local p5s=p5ps+pingw; local p6is=p5s+sw+sp; imgui.SameLine(p5s); imgui.TextColored(sc,st); imgui.SameLine(p6is); imgui.Text("IP")
    imgui.Separator()
end
local function draw_vehicle_header() 
    local idw=50; local nw=180; local pw=110; local spdw=110; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; 
    local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nw; local p3ps=p2s+sw+sp; local p3s=p3ps+pw; local p4ss=p3s+sw+sp; local p4s=p4ss+spdw; local p5ts=p4s+sw+sp; 
    local function sort_btn(lbl, col)
        local txt = lbl .. (state.current_sort_column == col and (state.sort_direction == 1 and " ^" or " v") or "")
        if imgui.Selectable(txt, false, 0, imgui.CalcTextSize(txt)) then if state.current_sort_column == col then state.sort_direction = state.sort_direction * -1 else state.current_sort_column = col; state.sort_direction = 1 end end
    end
    sort_btn("ID", "ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); 
    sort_btn("Nome", "Nome"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps); 
    sort_btn("Preço", "Preco"); imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4ss); 
    sort_btn("Velocidade", "Velocidade"); imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ts); 
    sort_btn("Tipo", "Tipo"); imgui.Separator() 
end
local function draw_profession_header() local nw=250; local lw=100; local swid=110; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=nw; local p2ls=p1s+sw+sp; local p2s=p2ls+lw; local p3ss=p2s+sw+sp; imgui.Text("Profissão"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ls); imgui.Text("Lvl Min"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ss); imgui.Text("Salário"); imgui.Separator() end
local function draw_skin_header() local idw=50; local namew=200; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+namew; local p3as=p2s+sw+sp; imgui.Text("ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text("Nome"); imgui.Separator() end
local function draw_weapon_header() local idw=60; local nw=250; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=idw; local p2ns=p1s+sw+sp; local p2s=p2ns+nw; local p3ts=p2s+sw+sp; imgui.Text("ID"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text("Nome"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ts); imgui.Text("Tipo"); imgui.Separator() end
local function draw_interior_header() local nw=300; local cw=200; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local sc=imgui.GetStyle().Colors[imgui.Col.Separator]; local p1s=nw; local p2cs=p1s+sw+sp; local p2s=p2cs+cw; local p3is=p2s+sw+sp; imgui.Text("Nome"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2cs); imgui.Text("Coords (X,Y,Z)"); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3is); imgui.Text("ID"); imgui.Separator() end

local function HelpMarker(desc)
    imgui.TextDisabled("(?)")
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(450.0)
        imgui.TextUnformatted(desc)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

-- =========================================================================
-- NOVA FUNÇÃO DE CONFIGURAÇÃO (VISUAL)
-- =========================================================================
local update_history = {
    { version = "9.0.51", date = "14/02/2026", changes = { "Novo: Opcao de escanear ID especifico manualmente na aba Online." } },
    { version = "9.0.49", date = "14/02/2026", changes = { "Melhoria: Lista lateral agora ordenada por ID (fixa).", "Novo: Log de tiros com cidade e comando /local." } },
    { version = "9.0.48", date = "13/02/2026", changes = { "Melhoria: Adicionada localizacao (Zona e Coords) no log de tiros." } },
    { version = "9.0.47", date = "12/02/2026", changes = { "Melhoria: Renomeado 'CP' para 'Copiar' no menu de contexto." } },
    { version = "9.0.46", date = "12/02/2026", changes = { "Melhoria: 'Escanear Dispositivos' agora tambem salva o IP do jogador." } },
    { version = "9.0.45", date = "12/02/2026", changes = { "Log de tiros agora cria um arquivo novo por sessao (ao abrir o jogo)." } },
    { version = "9.0.44", date = "12/02/2026", changes = { "Removido campo 'Alvo' do log de tiros (estava impreciso)." } },
    { version = "9.0.43", date = "12/02/2026", changes = { "Correcao: Removida deteccao de alvo instavel no log de tiros." } },
    { version = "9.0.42", date = "11/02/2026", changes = { "Novo: Sistema de Log de Tiros (Salva em 'logs tiros')." } },
    { version = "9.0.41", date = "11/02/2026", changes = { "Melhoria: Aviso '[ATIRANDO]' agora mostra o nome da arma." } },
    { version = "9.0.40", date = "11/02/2026", changes = { "Removido: Opcao 'Linhas de Mira' (Tracers) pois nao funcionou como esperado." } },
    { version = "9.0.39", date = "11/02/2026", changes = { "Novo: Adicionada opcao 'Linhas de Mira' (Tracers) no ESP." } },
    { version = "9.0.38", date = "11/02/2026", changes = { "Melhoria: Aviso '[ATIRANDO]' agora permanece por 1s para evitar piscar." } },
    { version = "9.0.37", date = "11/02/2026", changes = { "Novo: Adicionado aviso visual '[ATIRANDO]' no ESP quando um jogador dispara." } },
    { version = "9.0.36", date = "11/02/2026", changes = { "Correcao: Protecao contra crash ao ajustar distancia (funcao inexistente)." } },
    { version = "9.0.35", date = "11/02/2026", changes = { "Correcao: Removido salvamento excessivo nos sliders (evita crash ao arrastar)." } },
    { version = "9.0.34", date = "11/02/2026", changes = { "Otimizacao: Wallhack R1 agora usa funcoes nativas (independente de outros scripts)." } },
    { version = "9.0.33", date = "11/02/2026", changes = { "Correcao: Melhorada deteccao do SA-MP R1 para Wallhack (Verifica multiplos enderecos)." } },
    { version = "9.0.32", date = "11/02/2026", changes = { "Correcao: Integrado codigo do 'Wallhack Fix' para R1 (5 patches)." } },
    { version = "9.0.31", date = "11/02/2026", changes = { "Correcao: Wallhack simplificado para garantir compatibilidade (Removeu patches instaveis)." } },
    { version = "9.0.30", date = "11/02/2026", changes = { "Correcao: Crash ao ajustar distancia (removido save excessivo).", "Limpeza: Removido ESP visual antigo (foco no Wallhack nativo)." } },
    { version = "9.0.29", date = "11/02/2026", changes = { "Correcao: Melhorada deteccao do Wallhack R1 (Fallback)." } },
    { version = "9.0.28", date = "11/02/2026", changes = { "Limpeza: Removido codigo duplicado (funcoes de cor e texto)." } },
    { version = "9.0.27", date = "11/02/2026", changes = { "Melhoria: Integrado Wallhack Avancado (R1) que remove limites de distancia." } },
    { version = "9.0.26", date = "11/02/2026", changes = { "Melhoria: Feedback visual ao ativar Wallhack (Detecta versao R1-DL)." } },
    { version = "9.0.25", date = "11/02/2026", changes = { "Correcao: ESP Wallhack agora suporta versoes R2/R3/R4/DL do SAMP." } },
    { version = "9.0.24", date = "11/02/2026", changes = { "Correcao: Protecao contra crash ao ativar ESP (Memory Write)." } },
    { version = "9.0.23", date = "11/02/2026", changes = { "ESP agora usa tags nativas do SAMP (Wallhack de NameTag)." } },
    { version = "9.0.22", date = "11/02/2026", changes = { "Removidas barras de vida e colete do ESP (Usa padrao do SAMP)." } },
    { version = "9.0.21", date = "11/02/2026", changes = { "Adicionado indicador '[ATIRANDO]' no ESP quando o jogador atira." } },
    { version = "9.0.20", date = "10/02/2026", changes = { "Melhoria: Removido nome duplicado no ESP (Usa tag nativa do SAMP)." } },
    { version = "9.0.19", date = "08/02/2026", changes = { "Melhoria: Removido nome duplicado no ESP (Usa tag nativa do SAMP)." } },
    { version = "9.0.17", date = "08/02/2026", changes = { "Correcao: Sincronizacao da deteccao de arma na lista lateral." } },
    { version = "9.0.16", date = "08/02/2026", changes = { "Melhoria: Metodo de deteccao de armas aprimorado (Slot Check)." } },
    { version = "9.0.15", date = "08/02/2026", changes = { "Correcao: Mensagem 'nil' na lista lateral (protecao de variavel)." } },
    { version = "9.0.14", date = "08/02/2026", changes = { "Melhoria: Adicionada deteccao de arma na lista lateral de profissoes." } },
    { version = "9.0.13", date = "08/02/2026", changes = { "Removida 'Caixa de Profissoes na Tela' (Obsoleto).", "Adicionada opcao de tamanho da fonte na lista lateral." } },
    { version = "9.0.12", date = "08/02/2026", changes = { "Correcao: Lista lateral agora funciona mesmo com ESP/Tags desligados." } },
    { version = "9.0.11", date = "08/02/2026", changes = { "Melhoria: Lista lateral agora e movel (X/Y) e independente das tags." } },
    { version = "9.0.10", date = "08/02/2026", changes = { "Melhoria: Lista lateral de profissoes agora mostra jogadores fora da tela." } },
    { version = "9.0.09", date = "08/02/2026", changes = { "Melhoria: Auto-Login agora aguarda o dialogo (mais confiavel).", "Correcao: Flag SpanAllColumns corrigida nas listas." } },
    { version = "9.0.08", date = "08/02/2026", changes = { "Correcao: Erro 'function has more than 60 upvalues' (Reorganizacao de codigo)." } },
    { version = "9.0.07", date = "08/02/2026", changes = { "Adicionada opcao de Lista Lateral para tags de profissao (Menu Config)." } },
    { version = "9.0.06", date = "08/02/2026", changes = { "Melhoria: Tag em veiculos agora fica acima do carro (Alinhado ao SAMP)." } },
    { version = "9.0.05", date = "08/02/2026", changes = { "Removido fundo (faixa) da tag de profissao (Solicitado)." } },
    { version = "9.0.04", date = "08/02/2026", changes = { "Melhoria: Tag de profissao agora usa a cor da profissao (Player Color)." } },
    { version = "9.0.03", date = "08/02/2026", changes = { "Correcao: Erro de sintaxe (end extra) no ESP." } },
    { version = "9.0.02", date = "08/02/2026", changes = { "Adicionado sistema anti-sobreposicao (Tags nao se misturam em veiculos)." } },
    { version = "9.0.01", date = "08/02/2026", changes = { "Ajuste fino na altura da tag (Mais proxima da cabeca/barra de vida)." } },
    { version = "9.0.00", date = "08/02/2026", changes = { "Correcao: Protecao contra crash no getBodyPartCoordinates (Bone)." } },
    { version = "8.9.99", date = "08/02/2026", changes = { "Correcao: Erro critico no ESP (Validacao de cor e fonte)." } },
    { version = "8.9.98", date = "08/02/2026", changes = { "Melhoria: Tag agora segue a cabeca do jogador (Bone) para evitar desvios." } },
    { version = "8.9.97", date = "08/02/2026", changes = { "Correcao: Erro ao selecionar cor (acesso incorreto a variavel ImFloat4)." } },
    { version = "8.9.96", date = "08/02/2026", changes = { "Correcao: Removida funcao incompativel (IsItemDeactivatedAfterEdit) que causava crash." } },
    { version = "8.9.95", date = "08/02/2026", changes = { "Correcao: Crash ao abrir aba Comandos (Protecao na cor da tag e variaveis)." } },
    { version = "8.9.94", date = "08/02/2026", changes = { "Correcao: Crash ao editar cor da tag (Salvamento otimizado)." } },
    { version = "8.9.93", date = "08/02/2026", changes = { "Adicionada opcao para alterar a cor de fundo da tag de profissao." } },
    { version = "8.9.92", date = "08/02/2026", changes = { "Correcao critica: Crash ao ativar ESP (Variavel incorreta na barra de vida)." } },
    { version = "8.9.91", date = "08/02/2026", changes = { "Correcao: Tag sumia ao entrar em veiculos (Line of Sight ignorando veiculos)." } },
    { version = "8.9.90", date = "08/02/2026", changes = { "Adicionada verificacao de parede (Line of Sight) quando ESP esta desligado." } },
    { version = "8.9.89", date = "08/02/2026", changes = { "Ajuste automatico da posicao da tag quando ESP esta desligado (Alinhado ao SAMP)." } },
    { version = "8.9.88", date = "08/02/2026", changes = { "Adicionado slider para ajustar altura da tag de profissao." } },
    { version = "8.9.87", date = "08/02/2026", changes = { "Ajuste na posicao da tag de profissao (Mais abaixo do colete)." } },
    { version = "8.9.86", date = "08/02/2026", changes = { "Removida exibicao de tag de profissao/cargo para Admins (Solicitado)." } },
    { version = "8.9.85", date = "08/02/2026", changes = { "Adicionado ID na tag de profissao e suporte a profissao dupla (Staff + Cor)." } },
    { version = "8.9.84", date = "08/02/2026", changes = { "Ajuste no fundo da tag de profissao (Mais escuro para melhor leitura)." } },
    { version = "8.9.83", date = "08/02/2026", changes = { "Melhoria na exibicao da profissao no ESP (Fundo escuro para evitar sobreposicao)." } },
    { version = "8.9.82", date = "08/02/2026", changes = { "Tag de profissao movida para baixo do HP (centralizada)." } },
    { version = "8.9.81", date = "08/02/2026", changes = { "Ajuste visual nas tags de profissao (fonte menor e mais discreta)." } },
    { version = "8.9.80", date = "08/02/2026", changes = { "Habilitado ESP/Tags no jogador que voce esta espiando (Spectate)." } },
    { version = "8.9.79", date = "08/02/2026", changes = { "Tag de profissao movida para o lado do personagem (mais discreta)." } },
    { version = "8.9.78", date = "07/02/2026", changes = { "Correcao: ESP/Tags agora aparecem sempre (mesmo proximo e visivel)." } },
    { version = "8.9.77", date = "07/02/2026", changes = { "Separada a funcao de ver profissao do ESP (Tags de Profissao)." } },
    { version = "8.9.76", date = "07/02/2026", changes = { "Adicionada opcao para desativar tag de profissao no ESP." } },
    { version = "8.9.75", date = "07/02/2026", changes = { "Adicionado profissao/cargo no ESP (Tag no jogador)." } },
    { version = "8.9.74", date = "03/02/2026", changes = { "Correcao de crash ao verificar atualizacoes (Funcao movida e protegida)." } },
    { version = "8.9.73", date = "03/02/2026", changes = { "Adicionados campos de ID e Municao nas janelas separadas de Skins e Armas." } },
    { version = "8.9.72", date = "03/02/2026", changes = { "Layout das janelas separadas otimizado (Modo Compacto)." } },
    { version = "8.9.71", date = "03/02/2026", changes = { "Janelas redimensionadas para serem mais compactas." } },
    { version = "8.9.70", date = "03/02/2026", changes = { "Barras de pesquisa discretas adicionadas em todas as janelas separadas." } },
    { version = "8.9.69", date = "03/02/2026", changes = { "Correção final para janelas separadas e controle do cursor." } },
    { version = "8.9.68", date = "03/02/2026", changes = { "Correcao de crash: Janelas separadas movidas para OnDrawFrame.", "Correcao de conflitos de ID ImGui." } },
    { version = "8.9.67", date = "03/02/2026", changes = { "Correcao de crash no ImGui (Buffer de pesquisa separado para janela de Duvidas)." } },
    { version = "8.9.66", date = "03/02/2026", changes = { "Correcao de crash na janela /duvidas (Buffer de texto aumentado).", "Adicionada barra de pesquisa na janela /duvidas." } },
    { version = "8.9.65", date = "03/02/2026", changes = { "Adicionados comandos para abrir abas em janelas separadas (/duvidas, /locais, /veiculos, etc)." } },
    { version = "8.9.64", date = "02/02/2026", changes = { "Removida lista de presos (funcionalidade desativada)." } },
    { version = "8.9.63", date = "02/02/2026", changes = { "Atualizado comando de teste para incluir Prisao Municipal." } },
    { version = "8.9.62", date = "02/02/2026", changes = { "Lista de Presos: Federal (Vermelho) e Municipal (Azul)." } },
    { version = "8.9.61", date = "02/02/2026", changes = { "Adicionado comando '/testepresos' para testar a lista.", "Reaplicada melhoria de leitura de presos (hifen/barra)." } },
    { version = "8.9.57", date = "02/02/2026", changes = { "Adicionado leitor de '/presos' integrado.", "Nova janela 'Lista de Presos' na aba Online." } },
    { version = "8.9.56", date = "01/02/2026", changes = { "Atualizados links uteis (Forum, Adm, Servidor, Changelog)." } },
    { version = "8.9.55", date = "01/02/2026", changes = { "Adicionada sub-aba 'Links' em Informacoes com atalhos uteis." } },
    { version = "8.9.54", date = "01/02/2026", changes = { "Adicionado botao para abrir Regras do Servidor (Forum)." } },
    { version = "8.9.53", date = "01/02/2026", changes = { "Respostas do FAQ agora sao selecionaveis (para copiar partes)." } },
    { version = "8.9.52", date = "01/02/2026", changes = { "Adicionado botao 'Copiar' para respostas do FAQ." } },
    { version = "8.9.51", date = "01/02/2026", changes = { "Adicionada Tabela de Tempos de Prisao e Regras de Banimento.", "Atualizados Cooldowns e Requisitos de Policia." } },
    { version = "8.9.50", date = "01/02/2026", changes = { "Unificadas informacoes de todos os Chats (Regras, Mods, Economia e Cooldowns)." } },
    { version = "8.9.49", date = "01/02/2026", changes = { "Atualizada lista de FAQ com todas as informacoes do Chat HTML (Cooldowns, Economia, Regras)." } },
    { version = "8.9.46", date = "01/02/2026", changes = { "Busca agora ignora acentos (Ex: 'policia' acha 'Polícia').", "Adicionada barra de pesquisa na aba Duvidas (FAQ)." } },
    { version = "8.9.45", date = "25/01/2026", changes = { "Extrator de IPs agora fecha TODAS as janelas automaticamente." } },
    { version = "8.9.44", date = "25/01/2026", changes = { "Extrator de IPs agora mantem a ultima janela aberta (para conferencia)." } },
    { version = "8.9.43", date = "25/01/2026", changes = { "Bloqueio automatico de dialogos durante o scan de IP e Dispositivos." } },
    { version = "8.9.42", date = "25/01/2026", changes = { "Adicionada opcao 'Copiar IP' no menu de contexto do jogador (se o IP estiver visivel)." } },
    { version = "8.9.41", date = "25/01/2026", changes = { "Ajuste na largura da coluna Ping para nao sobrepor o IP." } },
    { version = "8.9.40", date = "25/01/2026", changes = { "Ajuste na largura das colunas para exibir IP corretamente." } },
    { version = "8.9.38", date = "22/01/2026", changes = { "Adicionado filtro de veiculos por profissao (Botao 'Veiculos' na aba Profissoes)." } },
    { version = "8.9.37", date = "22/01/2026", changes = { "Correcao de erro ao abrir aba de Skins (draw_skin_header)." } },
    { version = "8.9.36", date = "22/01/2026", changes = { "Correcao de acentuacao (removido u8 duplicado).", "Adicionados acentos na interface." } },
    { version = "8.9.35", date = "22/01/2026", changes = { "Adicionado botao manual de verificar atualizacoes na aba Config." } },
    { version = "8.9.34", date = "20/01/2026", changes = { "Adicionado /godmod automatico ao usar /pararespiar." } },
    { version = "8.9.33", date = "20/01/2026", changes = { "Adicionado icone de ajuda (?) com guia rapido das funcoes." } },
    { version = "8.9.31", date = "15/01/2026", changes = { "Refatorado o codigo para corrigir erro de 'upvalues'." } },
    { version = "8.9.29", date = "15/01/2026", changes = { "Adicionadas descricoes breves em cada aba." } },
    { version = "8.9.28", date = "15/01/2026", changes = { "Adicionado botao para favoritar tema.", "Adicionada opcao para alterar tecla de atalho." } },
    { version = "8.9.27", date = "15/01/2026", changes = { "Adicionado botao 'Ir para Marcacao (Mapa)' na aba Locais." } },
    { version = "8.9.26", date = "15/01/2026", changes = { "Correcao de alinhamento nas colunas da aba Veiculos." } },
    { version = "8.9.25", date = "15/01/2026", changes = { "Adicionada mensagem no chat ao carregar o script." } },
    { version = "8.9.24", date = "15/01/2026", changes = { "Correcao: Salvar local agora detecta o ID do Interior automaticamente." } },
    { version = "8.9.23", date = "15/01/2026", changes = { "Movida a funcao de salvar/voltar local da aba Comandos para Locais." } },
    { version = "8.9.22", date = "15/01/2026", changes = { "Adicionada opcao de salvar posicao diretamente na aba Locais." } },
    { version = "8.9.21", date = "15/01/2026", changes = { "Adicionado filtro de tipo e ordenacao por colunas na aba Veiculos." } },
    { version = "8.9.18", date = "15/01/2026", changes = { "Removida opcao 'Log IPs' do menu de jogadores (Online)." } },
    { version = "8.9.17", date = "15/01/2026", changes = { "Adicionado auto /cheat e /godmod ao logar na admin." } },
    { version = "8.9.16", date = "15/01/2026", changes = { "Melhoria no relatorio de duplicados (mostra Conta e ID claramente)." } },
    { version = "8.9.15", date = "15/01/2026", changes = { "Correcao na abertura dos logs (abre a pasta se o arquivo nao existir)." } },
    { version = "8.9.14", date = "15/01/2026", changes = { "Logs de IP agora sao salvos em arquivos separados por dia." } },
    { version = "8.9.13", date = "15/01/2026", changes = { "Adicionado nome e ID do jogador nos logs de IP." } },
    { version = "8.9.12", date = "15/01/2026", changes = { "Logs de IP movidos para a pasta 'moonloader/logs ip'." } },
    { version = "8.9.11", date = "15/01/2026", changes = { "Correcao de erro critico ao abrir logs (getMoonloaderDirectory)." } },
    { version = "8.9.10", date = "15/01/2026", changes = { "Adicionados botoes para abrir logs de IPs diretamente." } },
    { version = "8.9.9", date = "15/01/2026", changes = { "Adicionado log de IPs extraidos.", "Adicionado verificador de IPs duplicados." } },
    { version = "8.9.8", date = "15/01/2026", changes = { "Integrado Extrator de IPs na aba Comandos." } },
    { version = "8.9.7", date = "15/01/2026", changes = { "Adicionado botao de Reconexao Rapida na aba Config." } },
    { version = "8.9.6", date = "15/01/2026", changes = { "Adicionado botao de Copiar Coordenadas.", "Adicionado botao para ir ao ultimo local salvo.", "Pequenos ajustes visuais." } },
    { version = "8.9.5", date = "15/01/2026", changes = { "Adicionado botao para salvar posicao atual na aba Comandos." } },
    { version = "8.9.4", date = "15/01/2026", changes = { "Renomeada aba 'Eventos' para 'Favoritos'.", "Ajustes nos textos de contexto." } },
    { version = "8.9.3", date = "15/01/2026", changes = { "Aba 'Duvidas' movida para dentro de 'Informacoes'.", "Painel mais compacto." } },
    { version = "8.9.2", date = "15/01/2026", changes = { "Abas 'Interiores' e 'Eventos' unificadas na aba 'Locais'.", "Painel mais limpo e organizado." } },
    { version = "8.9.1", date = "15/01/2026", changes = { "Adicionada aba 'Comandos' com atalhos.", "Painel redesenhado para ser mais compacto." } },
    { version = "8.9.0", date = "15/01/2026", changes = { "Correcao critica: Migracao dos eventos para JSON (evita crash).", "Melhoria na estabilidade do salvamento." } },
    { version = "8.8.9", date = "15/01/2026", changes = { "Adicionada opcao de favoritar interiores para a aba Eventos (Botao Direito).", "Adicionada opcao de remover locais da aba Eventos." } },
    { version = "8.8.8", date = "15/01/2026", changes = { "Adicionada aba 'Eventos' com locais populares.", "Adicionados 23 locais de eventos." } },
    { version = "8.8.6", date = "15/01/2026", changes = { "Adicionado Historico de Atualizacoes na aba Duvidas." } },
    { version = "8.8.5", date = "15/01/2026", changes = { "Removida caixa de pesquisa da aba Config.", "Ajustes visuais na aba Config." } },
    { version = "8.8.4", date = "15/01/2026", changes = { "Adicionado Auto Login Admin (/flogar).", "Adicionado atalho ALT+L para login.", "Senha admin salva no config." } },
    { version = "8.8.3", date = "15/01/2026", changes = { "Adicionada aba de FAQ/Duvidas.", "Adicionada tabela de limites de transferencia." } },
    { version = "8.8.2", date = "15/01/2026", changes = { "Restauracao completa do codigo.", "Correcao de temas e cores.", "Correcao do botao de backup." } },
}

-- Forward declaration
local check_update

check_update = function(notify)
    local dlstatus = require('moonloader').download_status
    math.randomseed(os.time())
    local temp_path = os.getenv('TEMP') .. '\\painelinfo_ver_' .. os.time() .. '_' .. math.random(1000, 9999) .. '.json'
    downloadUrlToFile("https://raw.githubusercontent.com/nicholassud-beep/paineladmincvr/main/version.json?t="..os.time(), temp_path, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local f = io.open(temp_path, 'r')
            if f then
                local content = f:read('*a')
                f:close()
                os.remove(temp_path)
                local ok, info = pcall(decodeJson, content)
                if ok and info then
                    local remote_ver = tonumber(info.latest_version_number)
                    local local_ver = script_ver_num
                    if remote_ver and remote_ver > local_ver then
                        sampAddChatMessage("[PainelInfo] Nova versao disponivel: v" .. (info.latest_version_text or "?"), 0xFFFF00)
                        sampAddChatMessage("[PainelInfo] Acesse o GitHub para baixar a atualizacao.", 0xFFFF00)
                    elseif notify then
                        sampAddChatMessage("[PainelInfo] Voce ja esta usando a versao mais recente (v" .. thisScript().version .. ").", 0x00FF00)
                    end
                elseif notify then
                    sampAddChatMessage("[PainelInfo] Erro ao ler informacoes de versao.", 0xFF0000)
                end
            end
        end
    end)
end

local function draw_faq_tab(search_buf, suffix, compact)
    if not compact then
        imgui.TextColored(UI_COLORS.GREEN, "Duvidas e FAQ"); imgui.Separator()
    end
    if imgui.Button("Abrir Regras do Servidor (Forum)", imgui.ImVec2(-1, 25)) then
        os.execute('explorer "https://www.loskatchorros.com.br/forum/index.php?/topic/328257-regras-do-servidor/"')
    end
    imgui.Spacing()
    imgui.BeginChild("DuvidasFAQ"..(suffix or ""), imgui.ImVec2(0,0), true)
    
    local search_term = remove_accents(search_buf and search_buf.v or state.search_text.v)
    
    if imgui.CollapsingHeader("Perguntas Frequentes") then
        imgui.Spacing()
        for i, item in ipairs(faq_list) do
            local q_norm = remove_accents(item.q)
            local a_norm = remove_accents(item.a)
            if search_term == "" or q_norm:find(search_term, 1, true) or a_norm:find(search_term, 1, true) then
                if imgui.CollapsingHeader(u8(item.q)) then
                    if not item.buf then
                        item.buf = imgui.ImBuffer(u8(item.a), math.max(#item.a * 2, 4096)) -- Buffer maior para evitar crash
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

    if imgui.CollapsingHeader("Limites de Transferencia") then
        imgui.Spacing()
        imgui.Columns(2, "tf_cols", false)
        imgui.SetColumnWidth(0, 250)
        imgui.Text("Faixa Lvl")
        imgui.NextColumn()
        imgui.Text("Limite Max")
        imgui.NextColumn()
        imgui.Separator()
        local tf_limits={{40,99,5000},{100,199,10000},{200,299,15000},{300,399,20000},{400,499,25000},{500,599,30000},{600,699,35000},{700,799,40000},{800,899,45000},{900,999,50000},{1000,1099,55000},{1100,1199,60000},{1200,1299,65000},{1300,1399,70000},{1400,1499,75000},{1500,1599,80000},{1600,1699,85000},{1700,1799,90000},{1800,1899,95000},{1900,1999,100000},{2000,2099,105000},{2100,2199,110000},{2200,2299,115000},{2300,2399,120000},{2400,2499,125000},{2500,2599,130000},{2600,2699,135000},{2700,2799,140000},{2800,2899,145000},{2900,2999,150000},{3000,3099,155000},{3100,3199,160000},{3200,3299,165000},{3300,9999,500000}}
        for _,item in ipairs(tf_limits) do local r_str=item[2]==9999 and string.format("Lvl %d+",item[1]) or string.format("Lvl %d-%d",item[1],item[2]); local l_str="$"..formatPrice(item[3]); imgui.Text(r_str); imgui.NextColumn(); imgui.TextColored(UI_COLORS.YELLOW,l_str); imgui.NextColumn(); imgui.Separator() end; imgui.Columns(1); imgui.Spacing()
    end

    if imgui.CollapsingHeader("Historico de Atualizacoes") then
        imgui.Spacing()
        for _, update in ipairs(update_history) do
            imgui.TextColored(UI_COLORS.YELLOW, string.format("v%s - %s", update.version, update.date))
            for _, change in ipairs(update.changes) do
                imgui.BulletText(u8(change))
            end
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
        end
    end
    
    imgui.EndChild()
end

local function start_admin_login()
    sampSendChat("/logaradm")
    lua_thread.create(function()
        local timeout = 0
        while not sampIsDialogActive() and timeout < 2000 do
            wait(100)
            timeout = timeout + 100
        end
        if sampIsDialogActive() then
            sampSendDialogResponse(sampGetCurrentDialogId(), 1, 0, cfg.main.admin_pass)
            sampCloseCurrentDialogWithButton(1)
            sampAddChatMessage("[PI] Senha enviada via Auto-Login!", -1)
            wait(1000)
            sampSendChat("/cheat")
            wait(500)
            sampSendChat("/godmod")
        else
            sampAddChatMessage("[PI] Erro: Dialog nao abriu a tempo ou lag.", 0xFF0000)
        end
    end)
end

local function draw_config_tab()
    imgui.TextColored(UI_COLORS.GREEN, "Configuracoes"); imgui.Separator()
    imgui.TextDisabled("Ajuste temas, transparencia, senha de admin e gerencie backups.")
    imgui.Spacing()
    imgui.Spacing()

    local check_updates = imgui.ImBool(cfg.main.check_updates)
    if imgui.Checkbox("Verificar Atualizacoes ao Iniciar", check_updates) then
        cfg.main.check_updates = check_updates.v
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
    end

    if imgui.Button("Verificar Atualizacoes Agora", imgui.ImVec2(-1, 25)) then
        check_update(true)
    end
    
    if imgui.Button("Abrir Pasta de Backups", imgui.ImVec2(-1, 25)) then
        local backup_dir = getWorkingDirectory() .. "\\config\\backups"
        if not doesDirectoryExist(backup_dir) then createDirectory(backup_dir) end
        os.execute('explorer "' .. backup_dir .. '"')
    end

    if imgui.Button("Abrir Repositorio GitHub", imgui.ImVec2(-1, 25)) then
        os.execute('explorer "https://github.com/nicholassud-beep/paineladmincvr"')
    end
    imgui.Spacing()
    
    if imgui.Button("Favoritar Tema (Salvar)", imgui.ImVec2(-1, 25)) then
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
        sampAddChatMessage("[PI] Tema e configuracoes salvos como favoritos!", -1)
    end
    
    imgui.Text("Senha Admin:")
    imgui.PushItemWidth(150)
    if imgui.InputText("##AdminPass", state.admin_pass_buf, imgui.InputTextFlags.Password) then
        cfg.main.admin_pass = state.admin_pass_buf.v
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
    end
    imgui.PopItemWidth()
    imgui.SameLine(); imgui.TextDisabled("(Salva auto)")
    
    if imgui.Button("Logar Admin (/flogar)", imgui.ImVec2(-1, 25)) then
        start_admin_login()
    end
    
    imgui.Text("IP Servidor (Reconectar):")
    if imgui.InputText("##ServerIP", state.server_ip_buf) then
        cfg.main.server_ip = state.server_ip_buf.v
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
    end
    imgui.SameLine(); imgui.TextDisabled("(Vazio=Atual)")

    if imgui.Button("Reconectar (Fast Connect)", imgui.ImVec2(-1, 25)) then
        sampSetGamestate(1)
        local ip_str = state.server_ip_buf.v
        if #ip_str > 0 then
            local ip, port = ip_str:match("^(.-):(%d+)$")
            if not ip then ip = ip_str; port = 7777 end
            sampConnectToServer(ip, tonumber(port))
        else
            sampSetGamestate(1)
        end
    end
    imgui.Spacing()

    if imgui.Combo("Tema", state.theme_combo_idx, theme_list) then
        local selected = theme_list[state.theme_combo_idx.v + 1]
        if selected then
            cfg.main.theme = selected
            inicfg.save(cfg, "PainelInfo_Config_v8.ini")
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
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
    end
    
    imgui.Spacing()
    imgui.Text("Tecla de Atalho:")
    local k_name = key_names[cfg.main.bind] or tostring(cfg.main.bind)
    if waiting_for_bind then k_name = "Aguardando..." end
    if imgui.Button(k_name .. "##BindBtn", imgui.ImVec2(120, 25)) then
        waiting_for_bind = true
    end
    if waiting_for_bind then imgui.SameLine(); imgui.Text("Pressione uma tecla...") end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
end

-- =========================================================================
-- FUNÇÕES DE RENDERIZAÇÃO DAS ABAS (PARA CORRIGIR ERRO DE UPVALUE)
-- =========================================================================

local function draw_players_tab()
    local is_nov = (state.active_tab == 1)
    local is_on = (state.active_tab == 2)
    local show_pcol = is_on
    local hdr = is_nov and "Novatos:" or (is_on and "Online:" or "")
    
    imgui.Text(hdr)
    imgui.Separator()
    
    local data = {}
    local staff = {}
    local players = {}
    local cnt = 0
    local maxid = sampGetMaxPlayerId()
    
    if is_nov then
        imgui.TextDisabled("Lista de jogadores novatos (Nivel < 12). Botao direito no nome para opcoes.")
    else
        imgui.TextDisabled("Lista de todos os jogadores online. Staff no topo. Botao direito para opcoes.")
    end
    
    local search_norm = remove_accents(state.search_text.v)
    for i = 0, maxid do
        if sampIsPlayerConnected(i) then
            local nick = sampGetPlayerNickname(i)
            if nick and #nick > 0 then
                local rank = staff_nick_to_rank_map[string.lower(nick)]
                if not rank then
                    local s, n = pcall(encoding.CP1251, nick)
                    if s and n then rank = staff_nick_to_rank_map[string.lower(n)] end
                end
                
                local ping = sampGetPlayerPing(i) or 0
                local score = sampGetPlayerScore(i) or 0
                local color
                local prof
                
                if rank then
                    color = get_rank_color(rank)
                    prof = get_display_rank(rank)
                else
                    local argb = sampGetPlayerColor(i)
                    color = convert_samp_color(argb)
                    prof = get_closest_profession_name(argb)
                end
                
                local pdata = {
                    id = i,
                    nick = nick,
                    rank = rank,
                    color = color,
                    is_staff = (rank ~= nil),
                    Level = score,
                    Ping = ping,
                    profession = prof
                }
                
                local paused = sampIsPlayerPaused(i) or false
                local passes = (is_on) or (is_nov and pdata.Level < 12 and not paused)
                
                if passes then
                    local prof_norm = remove_accents(pdata.profession or "")
                    local nick_norm = remove_accents(nick)
                    local id_s = tostring(i)
                    
                    local m_txt = nick_norm:find(search_norm, 1, true) or prof_norm:find(search_norm, 1, true)
                    local m_id = id_s:find(search_norm, 1, true)
                    
                    if m_txt or m_id then
                        table.insert(data, pdata)
                        if is_on then
                            if pdata.is_staff then
                                table.insert(staff, pdata)
                            else
                                table.insert(players, pdata)
                            end
                        else
                            table.insert(players, pdata)
                        end
                    end
                    cnt = cnt + 1
                end
            end
        end
    end
    
    local total_pc = 0
    local total_mobile = 0
    local total_mafia = 0
    local total_honest = 0
    
    for _, p in ipairs(data) do
        if state.player_devices[p.id] == "PC" then
            total_pc = total_pc + 1
        elseif state.player_devices[p.id] == "Mobile" then
            total_mobile = total_mobile + 1
        end
        
        if not p.is_staff then
            local p_type = prof_type_map[(p.profession or ""):lower()]
            if p_type == "Mafia" then
                total_mafia = total_mafia + 1
            else
                total_honest = total_honest + 1
            end
        end
    end

    imgui.Text(string.format("Total: %d", #data))
    if is_on then
        imgui.SameLine(); imgui.TextColored(UI_COLORS.GREY, "|")
        imgui.SameLine(); imgui.TextColored(UI_COLORS.GREEN, string.format("Honestas: %d", total_honest))
        imgui.SameLine(); imgui.TextColored(UI_COLORS.RED, string.format("Mafia: %d", total_mafia))
        imgui.SameLine(); imgui.TextColored(UI_COLORS.GREY, "|")
        imgui.SameLine(); imgui.TextColored(UI_COLORS.BLUE, string.format("PC: %d", total_pc))
        imgui.SameLine(); imgui.TextColored(UI_COLORS.PINK, string.format("Mobile: %d", total_mobile))
        imgui.SameLine()
        if not state.device_scanner_active then
            if imgui.Button("Escanear Dispositivos") then
                lua_thread.create(function()
                    state.device_scanner_active = true
                    state.player_devices = {}
                    sampAddChatMessage("[PI] Iniciando scan de dispositivos (/ip)...", 0x00FF00)
                    local max_id = sampGetMaxPlayerId()
                    for i = 0, max_id do
                        if not state.device_scanner_active then break end
                        if sampIsPlayerConnected(i) then
                            local nick = sampGetPlayerNickname(i)
                            if nick then
                                for attempt = 1, 2 do
                                    if state.player_devices[i] then break end
                                    state.current_scan_info = {id = i, name = nick}
                                    state.scan_response_received = false
                                    state.scan_message_count = 0
                                    sampSendChat("/ip " .. i)
                                    state.device_scan_progress = i
                                    local timeout = 0
                                    while not state.scan_response_received and timeout < 200 do
                                        wait(10)
                                        timeout = timeout + 10
                                        if state.scan_message_count > 0 and timeout > 50 then break end
                                    end
                                    if attempt == 1 and not state.player_devices[i] then wait(50) end
                                end
                                if sampIsDialogActive() then sampCloseCurrentDialogWithButton(0) end
                            end
                        end
                    end
                    state.current_scan_info = nil
                    state.device_scanner_active = false
                    sampAddChatMessage("[PI] Scan de dispositivos concluido!", 0x00FF00)
                end)
            end
            imgui.SameLine()
            imgui.PushItemWidth(40)
            imgui.InputText("##ManualScanID", state.manual_scan_id_buf)
            imgui.PopItemWidth()
            if imgui.IsItemHovered() then imgui.SetTooltip("Digite o ID para escanear individualmente") end
            imgui.SameLine()
            if imgui.Button("Scan ID") then
                local id = tonumber(state.manual_scan_id_buf.v)
                if id and sampIsPlayerConnected(id) then
                    lua_thread.create(function()
                        state.device_scanner_active = true
                        local nick = sampGetPlayerNickname(id)
                        sampAddChatMessage(string.format("[PI] Escaneando ID %d (%s)...", id, nick), 0x00FF00)
                        
                        for attempt = 1, 2 do
                            if state.player_devices[id] then break end
                            state.current_scan_info = {id = id, name = nick}
                            state.scan_response_received = false
                            state.scan_message_count = 0
                            sampSendChat("/ip " .. id)
                            state.device_scan_progress = id
                            local timeout = 0
                            while not state.scan_response_received and timeout < 200 do
                                wait(10)
                                timeout = timeout + 10
                                if state.scan_message_count > 0 and timeout > 50 then break end
                            end
                            if attempt == 1 and not state.player_devices[id] then wait(50) end
                        end
                        if sampIsDialogActive() then sampCloseCurrentDialogWithButton(0) end
                        
                        state.current_scan_info = nil
                        state.device_scanner_active = false
                        if state.player_devices[id] then
                            sampAddChatMessage(string.format("[PI] ID %d detectado: %s", id, state.player_devices[id]), 0x00FF00)
                        else
                            sampAddChatMessage(string.format("[PI] ID %d: Dispositivo nao detectado.", id), 0xFFFF00)
                        end
                    end)
                else
                    sampAddChatMessage("[PI] ID invalido ou desconectado.", 0xFF0000)
                end
            end
        else
            imgui.TextColored(UI_COLORS.YELLOW, string.format("Escaneando... ID %d", state.device_scan_progress))
        end
    end
    
    imgui.Separator()
    imgui.BeginChild("plist_child", imgui.ImVec2(0, 0), true)

    local function render_plist(list, show_pc)
        local idw = 40
        local nickw = show_pc and 150 or 250
        local profw = show_pc and 160 or 0
        local lvlw = 40
        local pingw = 110
        local sc = imgui.GetStyle().Colors[imgui.Col.Separator]
        local st = "|"
        local sw = imgui.CalcTextSize(st).x
        local sp = imgui.GetStyle().ItemSpacing.x

        for _,p in ipairs(list) do
            local is_s = p.is_staff
            local paused = sampIsPlayerPaused(p.id)
            local disp_p = p.profession or "?"
            if paused then
                if is_s then
                    disp_p = u8(p.profession) .. " (AFK)"
                else
                    disp_p = "AFK"
                end
            end
            
            local curX = imgui.GetCursorPosX()
            local line_lbl = string.format("##p_%d", p.id)
            imgui.Selectable(line_lbl, false, SpanAllColumns, imgui.ImVec2(0, imgui.GetTextLineHeight()))
            imgui.SetItemAllowOverlap()
            
            if imgui.BeginPopupContextItem("p_act" .. p.id) then
                if imgui.MenuItem("Copiar Nick") then
                    imgui.SetClipboardText(u8(p.nick))
                    sampAddChatMessage("Nick Copiado", 0)
                end
                if p.profession then
                    if imgui.MenuItem("Copiar Info") then
                        imgui.SetClipboardText(u8(p.profession))
                        sampAddChatMessage("Info Copiada", 0)
                    end
                end
                local ip_data = state.player_ips[p.id]
                if ip_data and ip_data.nick == p.nick then
                    if imgui.MenuItem("Copiar IP") then
                        imgui.SetClipboardText(ip_data.ip)
                        sampAddChatMessage("[PI] IP copiado: " .. ip_data.ip, -1)
                    end
                end
                imgui.Separator()
                if imgui.MenuItem("Ir ID") then
                    sampSendChat("/ir " .. p.id)
                    state.window_open.v = false
                    imgui.Process = false
                end
                if imgui.MenuItem("Espiar ID") then
                    sampSendChat("/espiar " .. p.id)
                    state.window_open.v = false
                    imgui.Process = false
                end
                if imgui.MenuItem("Ver IP") then
                    sampSendChat("/ip " .. p.id)
                    logIPRequestToFile(p.id, p.nick)
                end
                if imgui.MenuItem("Ver Docs") then
                    sampSendChat("/documentos " .. p.id)
                    state.window_open.v = false
                    imgui.Process = false
                end
                imgui.EndPopup()
            end

            local p1s = idw
            local p2ns = p1s + sw + sp
            local p2s = p2ns + nickw
            local p3ps, p3s, p4ls

            imgui.SameLine(curX)
            imgui.TextColored(p.color, tostring(p.id))
            imgui.SameLine(p1s)
            imgui.TextColored(sc, st)
            imgui.SameLine(p2ns)
            imgui.TextColored(p.color, u8(p.nick))

            if show_pc then
                p3ps = p2s + sw + sp
                p3s = p3ps + profw
                imgui.SameLine(p2s)
                imgui.TextColored(sc, st)
                imgui.SameLine(p3ps)
                local tc = paused and UI_COLORS.GREY or p.color
                imgui.TextColored(tc, u8(disp_p))
                p4ls = p3s + sw + sp
                imgui.SameLine(p3s)
                imgui.TextColored(sc, st)
            else
                p4ls = p2s + sw + sp
                imgui.SameLine(p2s)
                imgui.TextColored(sc, st)
            end

            imgui.SameLine(p4ls)
            local lvl = p.Level or 0
            imgui.TextColored(p.color, tostring(lvl))
            local p4s = p4ls + lvlw
            imgui.SameLine(p4s)
            imgui.TextColored(sc, st)
            local p5ps = p4s + sw + sp
            imgui.SameLine(p5ps)
            local ping = p.Ping or 0
            local pc = get_ping_color(ping)
            local dev_str = state.player_devices[p.id] and (" [" .. state.player_devices[p.id] .. "]") or ""
            local pt = string.format("%d ms%s", math.floor(ping), dev_str)
            imgui.TextColored(pc, pt)

            local p5s = p5ps + pingw
            local p6is = p5s + sw + sp
            imgui.SameLine(p5s)
            imgui.TextColored(sc, st)
            imgui.SameLine(p6is)
            local ip_data = state.player_ips[p.id]
            local ip_str = (ip_data and ip_data.nick == p.nick) and ip_data.ip or "-"
            imgui.TextDisabled(ip_str)
        end
    end

    if #data == 0 then
        imgui.Text("Nenhum.")
    else
        draw_player_header(show_pcol)
        imgui.Separator()
        table.sort(staff, function(a, b) return a.id < b.id end)
        table.sort(players, function(a, b) return a.id < b.id end)
        if is_on and #staff > 0 then
            render_plist(staff, show_pcol)
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
        end
        render_plist(players, show_pcol)
    end
    imgui.EndChild()
end

local function draw_professions_content(search_val, compact)
    local search_norm = remove_accents(search_val or state.search_text.v)
    if not compact then imgui.TextDisabled("Lista de profissoes. Duplo clique para definir (setprof).") end
    imgui.PushItemWidth(120)
    imgui.Combo("##ProfTypeFilter", state.prof_type_filter_idx, prof_types)
    imgui.PopItemWidth()
    imgui.SameLine()
    local selected_prof_type = prof_types[state.prof_type_filter_idx.v + 1]
    imgui.TextColored(UI_COLORS.GREEN,"Profissões:"); imgui.Separator(); local filt_p=filter_professions(professions,search_norm); local cnt=#filt_p; local leg,maf={}, {}; for _,p in ipairs(filt_p) do if p.type=="Mafia" then table.insert(maf,p) else table.insert(leg,p) end end; imgui.Text("Encontradas: "..cnt); imgui.Separator(); imgui.BeginChild("ProfListInfo",imgui.ImVec2(0,0),true); draw_profession_header(); 
    local function rend_p(l,h,c) 
        if #l>0 then 
            imgui.TextColored(c,h); imgui.Spacing(); 
            local nw=250; local lw=100; local salw=110; 
            local sc=UI_COLORS.GREY; local st="|"; local stw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; 
            local p1s=nw; local p2ls=p1s+stw+sp; local p2s=p2ls+lw; local p3ss=p2s+stw+sp; local p3s=p3ss+salw; local p4as=p3s+stw+sp; 
            for _,p in ipairs(l) do 
                local curX = imgui.GetCursorPosX()
                local lbl=string.format("##pli_%s%d",p.name or "u", p.level or 0); 
                imgui.Selectable(lbl,false,SpanAllColumns,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
                imgui.SetItemAllowOverlap()
                if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then 
                    sampSendChat(string.format("/setprof %d", p.id)); 
                    sampAddChatMessage(string.format("{FFFFFF}[PI] Profissao definida: {FFFF00}%s {FFFFFF}(ID: %d)", p.name or "?", p.id), -1) 
                end; 
                imgui.SameLine(curX); imgui.Text(p.name or "?"); 
                imgui.SameLine(p1s); imgui.TextColored(sc,st); 
                imgui.SameLine(p2ls); imgui.Text(tostring(p.level or "?")); 
                imgui.SameLine(p2s); imgui.TextColored(sc,st); 
                imgui.SameLine(p3ss); imgui.TextColored(UI_COLORS.YELLOW,"$"..formatPrice(p.salary or 0)) 
                imgui.SameLine(p3s); imgui.TextColored(sc,st); 
                imgui.SameLine(p4as); 
                if imgui.SmallButton("Aplicar##"..p.id) then 
                    sampSendChat(string.format("/setprof %d", p.id)); 
                    sampAddChatMessage(string.format("{FFFFFF}[PI] Profissao definida: {FFFF00}%s {FFFFFF}(ID: %d)", p.name or "?", p.id), -1) 
                end; 
                if imgui.IsItemHovered() then imgui.SetTooltip("Clique para definir a profissao: " .. (p.name or "?")) end
                if profession_vehicles_map[p.name:lower()] then
                    imgui.SameLine()
                    if imgui.SmallButton("Veiculos##"..p.id) then
                        state.active_info_sub_tab = 2
                        state.active_prof_veh_filter = p.name
                        state.search_text.v = ""
                    end
                end
            end 
        end 
    end; 
    if cnt==0 then imgui.Text("Nenhuma.") else 
        local sc=UI_COLORS.GREY; local st="|"; local stw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; 
        if selected_prof_type == "Todas" or selected_prof_type == "Honestas" then rend_p(leg,"--- Honestas ---",UI_COLORS.GREEN) end
        if selected_prof_type == "Todas" and #leg>0 and #maf>0 then imgui.Spacing(); imgui.Separator(); imgui.Spacing() end
        if selected_prof_type == "Todas" or selected_prof_type == "Mafia" then rend_p(maf,"--- Mafia ---",UI_COLORS.RED) end
    end; 
    imgui.EndChild()
end

local function draw_vehicles_content(search_val, compact)
    local search_norm = remove_accents(search_val or state.search_text.v)
    local filt_v = {}
    if state.active_prof_veh_filter then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 0, 0, 1))
        imgui.Text("Veículos de " .. state.active_prof_veh_filter)
        imgui.PopStyleColor()
        if imgui.Button("Voltar / Todos") then 
            state.active_prof_veh_filter = nil 
        end
        
        if state.active_prof_veh_filter then
            local target_vehs = profession_vehicles_map[state.active_prof_veh_filter:lower()] or {}
            local allowed = {}
            for _, vname in ipairs(target_vehs) do allowed[vname:lower()] = true end
            for _, v in ipairs(vehicles) do
                if allowed[v.name:lower()] then table.insert(filt_v, v) end
            end
            pcall(table.sort, filt_v, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
        end
    else
            if not compact then imgui.TextDisabled("Lista de veiculos. Duplo clique para criar (/cv).") end
        imgui.PushItemWidth(120)
        imgui.Combo("##VehTypeFilter", state.veh_type_filter_idx, veh_types)
        imgui.PopItemWidth()
        imgui.SameLine()
        local selected_type = veh_types[state.veh_type_filter_idx.v + 1]
        filt_v=filter_vehicles(vehicles,search_norm,state.current_sort_column,state.sort_direction,selected_type)
    end
    
    local cnt=#filt_v; imgui.Text("Veículos: "..cnt); imgui.Separator();
    imgui.BeginChild("VehListInfo",imgui.ImVec2(0,0),true); draw_vehicle_header(); if cnt==0 then imgui.Text("Nenhum.") else 
        local idw=50; local nw=180; local pw=110; local swid=110; local typew=100; 
        local sc=UI_COLORS.GREY; local st="|"; local stw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; 
        local align_offset = imgui.GetStyle().FramePadding.x
        local p1s=idw; local p2ns=p1s+stw+sp; local p2s=p2ns+nw; local p3ps=p2s+stw+sp; local p3s=p3ps+pw; local p4ss=p3s+stw+sp; local p4s=p4ss+swid; local p5ts=p4s+stw+sp; local p5s=p5ts+typew; local p6as=p5s+stw+sp; 
        for _,v in ipairs(filt_v) do 
            local curX = imgui.GetCursorPosX()
            local lbl=string.format("##vli_%d",v.id); 
            imgui.Selectable(lbl,false,SpanAllColumns,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
            imgui.SetItemAllowOverlap()
            if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then 
                sampSendChat("/cv "..v.id)
                sampAddChatMessage("[PI] Criando veiculo ID "..v.id.." ("..v.name..")",-1) 
            end; 
            local p_str=(v.price and v.price>0) and ("$"..formatPrice(v.price)) or "0"; local s_str=v.speed and (v.speed.." km/h") or "?"; local t_str=v.type or "?"; 
            imgui.SameLine(curX + align_offset); imgui.Text(tostring(v.id)); 
            imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns + align_offset); imgui.Text(v.name); 
            imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ps + align_offset); imgui.TextColored(UI_COLORS.YELLOW,p_str); 
            imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4ss + align_offset); imgui.TextColored(UI_COLORS.PINK,s_str); 
            imgui.SameLine(p4s); imgui.TextColored(sc,st); imgui.SameLine(p5ts + align_offset); imgui.TextColored(UI_COLORS.BLUE,t_str) 
            imgui.SameLine(p5s); imgui.TextColored(sc,st); imgui.SameLine(p6as); 
            if imgui.SmallButton("Criar##btn_v_"..v.id) then 
                sampSendChat("/cv "..v.id)
                sampAddChatMessage("[PI] Criando veiculo ID "..v.id.." ("..v.name..")",-1) 
            end 
        end 
    end; imgui.EndChild()
end

local function draw_skins_content(search_val, compact)
    local search_norm = remove_accents(search_val or state.search_text.v)
    if not compact then imgui.TextDisabled("Lista de skins. Defina o ID alvo acima e duplo clique para aplicar.") end
    if not skin_search_map then imgui.TextColored(UI_COLORS.RED,"Erro!") else local filt_s=filter_skins(search_norm); local cnt=#filt_s; imgui.Text("Skins: "..cnt); imgui.Separator(); imgui.BeginChild("SkinListInfo",imgui.ImVec2(0,0),true); draw_skin_header(); if cnt==0 then imgui.Text("Nenhuma.") else 
        local idw=50; local namew=200; local sc=UI_COLORS.GREY; local st="|"; local stw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; 
        local p1s=idw; local p2ns=p1s+stw+sp; local p2s=p2ns+namew; local p3as=p2s+stw+sp; 
        for _,s in ipairs(filt_s) do 
            local curX = imgui.GetCursorPosX()
            local lbl=string.format("##sli_%d",s.id); 
            imgui.Selectable(lbl,false,SpanAllColumns,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
            imgui.SetItemAllowOverlap()
            if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then 
                local tid=tonumber(state.target_id_buf.v); 
                if not tid or tid<0 then local _,myid=sampGetPlayerIdByCharHandle(PLAYER_PED); tid=myid end
                if tid then 
                    sampSendChat(string.format("/skins %d %d",tid,s.id)); 
                    sampAddChatMessage(string.format("[PI] Skin %d aplicada no ID %d.",s.id,tid),-1) 
                end 
            end; 
            imgui.SameLine(curX); imgui.Text(tostring(s.id)); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text(s.name or "?") 
            imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3as); 
            if imgui.SmallButton("Aplicar##btn_s_"..s.id) then 
                local tid=tonumber(state.target_id_buf.v); 
                if not tid or tid<0 then local _,myid=sampGetPlayerIdByCharHandle(PLAYER_PED); tid=myid end
                if tid then 
                    sampSendChat(string.format("/skins %d %d",tid,s.id)); 
                    sampAddChatMessage(string.format("[PI] Skin %d aplicada no ID %d.",s.id,tid),-1) 
                end 
            end
        end 
    end; imgui.EndChild() end
end

local function draw_weapons_content(search_val, compact)
    local search_norm = remove_accents(search_val or state.search_text.v)
    if not compact then imgui.TextDisabled("Lista de armas. Defina ID alvo e municao acima, duplo clique para dar.") end
    imgui.PushItemWidth(120)
    imgui.Combo("##WeaponTypeFilter", state.weapon_type_filter_idx, weapon_types)
    imgui.PopItemWidth()
    imgui.SameLine()
    local selected_w_type = weapon_types[state.weapon_type_filter_idx.v + 1]
    local filt_w=filter_weapons(weapons_list,search_norm,selected_w_type); local cnt=#filt_w; imgui.Text("Armas: "..cnt); imgui.Separator(); imgui.BeginChild("WeaponListInfo",imgui.ImVec2(0,0),true); draw_weapon_header(); if cnt==0 then imgui.Text("Nenhuma.") else 
        local idw=60; local nw=200; local typew=120; 
        local sc=UI_COLORS.GREY; local st="|"; local stw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; 
        local p1s=idw; local p2ns=p1s+stw+sp; local p2s=p2ns+nw; local p3ts=p2s+stw+sp; local p3s=p3ts+typew; local p4as=p3s+stw+sp; 
        for _,w in ipairs(filt_w) do 
            local curX = imgui.GetCursorPosX()
            local lbl=string.format("##wli_%d",w.id); 
            imgui.Selectable(lbl,false,SpanAllColumns,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
            imgui.SetItemAllowOverlap()
            if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then 
                local tid=tonumber(state.target_id_buf.v); local ammo=tonumber(state.ammo_amount_buf.v) or 500; 
                if not tid or tid<0 then local _,myid=sampGetPlayerIdByCharHandle(PLAYER_PED); tid=myid end
                if tid then 
                    sampSendChat(string.format("/dararma %d %d %d",tid,w.id,ammo)); 
                    sampAddChatMessage(string.format("[PI] Arma %s (%d) dada ao ID %d.",w.name or "?",ammo,tid),-1) 
                end 
            end; 
            imgui.SameLine(curX); imgui.Text(tostring(w.id)); 
            imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2ns); imgui.Text(w.name or "?"); 
            imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3ts); imgui.TextColored(UI_COLORS.BLUE,w.type or "?") 
            imgui.SameLine(p3s); imgui.TextColored(sc,st); imgui.SameLine(p4as); 
            if imgui.SmallButton("Setar##btn_w_"..w.id) then 
                local tid=tonumber(state.target_id_buf.v); local ammo=tonumber(state.ammo_amount_buf.v) or 500; 
                if not tid or tid<0 then local _,myid=sampGetPlayerIdByCharHandle(PLAYER_PED); tid=myid end
                if tid then 
                    sampSendChat(string.format("/dararma %d %d %d",tid,w.id,ammo)); 
                    sampAddChatMessage(string.format("[PI] Arma %s (%d) dada ao ID %d.",w.name or "?",ammo,tid),-1) 
                end 
            end
        end 
    end; imgui.EndChild()
end

local function draw_info_tab()
    local sub_tabs={{1,"Profissões"},{2,"Veículos"},{3,"Skins"},{4,"Armas"},{5,"Dúvidas"},{6,"Links"}}; local sub_space=(imgui.GetWindowWidth()-25)/#sub_tabs; local sub_btn_w=imgui.ImVec2(math.floor(sub_space)-5,22); local act_bg=UI_COLORS.WHITE; local act_hov=imgui.ImVec4(.8,.8,.8,1); local act_txt=UI_COLORS.BLACK; local inact_bg=imgui.GetStyle().Colors[imgui.Col.Button]; local inact_hov=imgui.GetStyle().Colors[imgui.Col.ButtonHovered]; local inact_txt=imgui.GetStyle().Colors[imgui.Col.Text]
    for i,sub in ipairs(sub_tabs) do local sid,snm=sub[1],sub[2]; local is_act=state.active_info_sub_tab==sid; if is_act then imgui.PushStyleColor(imgui.Col.Button,act_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,act_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,act_hov); imgui.PushStyleColor(imgui.Col.Text,act_txt) else imgui.PushStyleColor(imgui.Col.Button,inact_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,inact_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,inact_hov); imgui.PushStyleColor(imgui.Col.Text,inact_txt) end; if imgui.Button(snm,sub_btn_w) then state.active_info_sub_tab=sid end; imgui.PopStyleColor(4); if i<#sub_tabs then imgui.SameLine(0,2) end end; imgui.Spacing(); imgui.Separator()
    if state.active_info_sub_tab==3 or state.active_info_sub_tab==4 then imgui.Text("Aplicar em:"); imgui.SameLine(); imgui.PushItemWidth(80); imgui.InputText("ID##TargetID",state.target_id_buf); imgui.PopItemWidth(); imgui.SameLine(); if imgui.Button("Eu") then local _,mid=sampGetPlayerIdByCharHandle(PLAYER_PED); state.target_id_buf.v=tostring(mid) end; if state.active_info_sub_tab==4 then imgui.SameLine(); imgui.Text("Munição:"); imgui.SameLine(); imgui.PushItemWidth(80); imgui.InputText("##AmmoAmount",state.ammo_amount_buf); imgui.PopItemWidth() end; imgui.Spacing() end

    if state.active_info_sub_tab == 1 then -- Profissoes
        draw_professions_content()
    elseif state.active_info_sub_tab == 2 then -- Veiculos
        draw_vehicles_content()
    elseif state.active_info_sub_tab == 3 then -- Skins
        draw_skins_content()
    elseif state.active_info_sub_tab == 4 then -- Armas
        draw_weapons_content()
    elseif state.active_info_sub_tab == 5 then -- Duvidas
        imgui.TextDisabled("Perguntas frequentes e historico de atualizacoes.")
        draw_faq_tab(state.search_text, "Main")
    elseif state.active_info_sub_tab == 6 then -- Links Uteis
        imgui.TextColored(UI_COLORS.GREEN, "Links Uteis do Forum"); imgui.Separator(); imgui.Spacing()
        local btn_size = imgui.ImVec2(-1, 30)
        if imgui.Button("Forum - Pagina Inicial", btn_size) then os.execute('explorer "https://www.loskatchorros.com.br/forum/index.php"') end
        if imgui.Button("Regras do Servidor", btn_size) then os.execute('explorer "https://www.loskatchorros.com.br/forum/index.php?/topic/328257-regras-do-servidor/"') end
        if imgui.Button("Administracao", btn_size) then os.execute('explorer "https://www.loskatchorros.com.br/forum/index.php?/forum/13-administra%C3%A7%C3%A3o/"') end
        if imgui.Button("Servidor", btn_size) then os.execute('explorer "https://www.loskatchorros.com.br/forum/index.php?/forum/151-servidor/"') end
        if imgui.Button("Changelog (Atualizacoes)", btn_size) then os.execute('explorer "https://www.loskatchorros.com.br/forum/index.php?/forum/71-changelog/"') end
    end
end

local function draw_locais_tab(search_val, compact)
    local search_norm = remove_accents(search_val or state.search_text.v)
    local sub_tabs={{1,"Interiores"},{2,"Favoritos"}}; local sub_space=(imgui.GetWindowWidth()-25)/#sub_tabs; local sub_btn_w=imgui.ImVec2(math.floor(sub_space)-5,22); local act_bg=UI_COLORS.WHITE; local act_hov=imgui.ImVec4(.8,.8,.8,1); local act_txt=UI_COLORS.BLACK; local inact_bg=imgui.GetStyle().Colors[imgui.Col.Button]; local inact_hov=imgui.GetStyle().Colors[imgui.Col.ButtonHovered]; local inact_txt=imgui.GetStyle().Colors[imgui.Col.Text]
    for i,sub in ipairs(sub_tabs) do local sid,snm=sub[1],sub[2]; local is_act=state.active_locais_sub_tab==sid; if is_act then imgui.PushStyleColor(imgui.Col.Button,act_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,act_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,act_hov); imgui.PushStyleColor(imgui.Col.Text,act_txt) else imgui.PushStyleColor(imgui.Col.Button,inact_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,inact_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,inact_hov); imgui.PushStyleColor(imgui.Col.Text,inact_txt) end; if imgui.Button(snm,sub_btn_w) then state.active_locais_sub_tab=sid end; imgui.PopStyleColor(4); if i<#sub_tabs then imgui.SameLine(0,2) end end; imgui.Spacing(); imgui.Separator()

    if state.active_locais_sub_tab == 1 then
        if not compact then imgui.TextDisabled("Interiores do jogo. Duplo clique para ir. Botao direito para favoritar.") end
        local filt_int=filter_interiors(interiors_list,search_norm); local cnt=#filt_int; imgui.Text("Interiores: "..cnt); imgui.Separator(); imgui.BeginChild("IntList",imgui.ImVec2(0,0),true); draw_interior_header(); 
        if cnt==0 then imgui.Text("Nenhum.") else 
            local nw=300; local cw=200; local sc=UI_COLORS.GREY; local st="|"; local sw=imgui.CalcTextSize(st).x; local sp=imgui.GetStyle().ItemSpacing.x; local p1s=nw; local p2cs=p1s+sw+sp; local p2s=p2cs+cw; local p3is=p2s+sw+sp; 
            for _,i in ipairs(filt_int) do 
                local curX = imgui.GetCursorPosX()
                local lbl=string.format("##int_%s%.1f",i.name or "u",i.x or 0); 
                imgui.Selectable(lbl,false,SpanAllColumns,imgui.ImVec2(0,imgui.GetTextLineHeight())); 
                imgui.SetItemAllowOverlap()
                
                if imgui.BeginPopupContextItem() then
                    if imgui.Selectable("Adicionar aos Favoritos") then
                        table.insert(event_locations, i)
                        save_events()
                        sampAddChatMessage("[PI] Local adicionado aos Favoritos: " .. i.name, -1)
                    end
                    imgui.EndPopup()
                end

                if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then local cmd=string.format("/tp %.4f %.4f %.4f %d",i.x,i.y,i.z,i.id); sampSendChat(cmd); sampAddChatMessage(string.format("[PI] TP para %s (ID:%d)",i.name or "?",i.id),-1) end; 
                if imgui.IsItemHovered() then imgui.SetTooltip("Botao Direito: Favoritar | Duplo Clique: Ir") end
                
                imgui.SameLine(curX); imgui.Text(i.name or "?"); imgui.SameLine(p1s); imgui.TextColored(sc,st); imgui.SameLine(p2cs); local ct=string.format("%.1f,%.1f,%.1f",i.x or 0,i.y or 0,i.z or 0); imgui.TextColored(UI_COLORS.PINK,ct); imgui.SameLine(p2s); imgui.TextColored(sc,st); imgui.SameLine(p3is); imgui.TextColored(UI_COLORS.BLUE,tostring(i.id or "?")) 
            end 
        end; imgui.EndChild()
    elseif state.active_locais_sub_tab == 2 then
        if not compact then imgui.TextDisabled("Seus locais salvos. Use 'Salvar Atual' para gravar sua posicao.") end
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
        if imgui.Button("Ir para Marcacao (Mapa)", imgui.ImVec2(-1, 25)) then
            local res, x, y, z = getTargetBlipCoordinates()
            if res then
                local cmd = string.format("/tp %.2f %.2f %.2f 0", x, y, z + 50)
                sampSendChat(cmd)
                sampAddChatMessage("[PI] Teleportando para marcacao...", -1)
            else
                sampAddChatMessage("[PI] Marque um local no mapa primeiro.", 0xFF0000)
            end
        end
        imgui.Separator()

        local filt_evt = filter_interiors(event_locations, search_norm); local cnt = #filt_evt; imgui.Text("Locais Favoritos: " .. cnt); imgui.Separator(); imgui.BeginChild("EventLocs", imgui.ImVec2(0,0), true)
        local should_open_edit_popup = false
        
        local nw = 300; local cw = 200
        local st = "|"; local sw = imgui.CalcTextSize(st).x
        local sp = imgui.GetStyle().ItemSpacing.x
        local sc = imgui.GetStyle().Colors[imgui.Col.Separator]
        
        local p1s = nw; local p2cs = p1s + sw + sp; local p2s = p2cs + cw; local p3is = p2s + sw + sp
        imgui.Text("Nome Local"); imgui.SameLine(p1s); imgui.TextColored(sc, st); imgui.SameLine(p2cs); imgui.Text("Coords (X,Y,Z)"); imgui.SameLine(p2s); imgui.TextColored(sc, st); imgui.SameLine(p3is); imgui.Text("Int")
        imgui.Separator()

        for _, loc in ipairs(filt_evt) do
            local curX = imgui.GetCursorPosX()
            local lbl = string.format("##evt_%s", loc.name)
            imgui.Selectable(lbl, false, SpanAllColumns, imgui.ImVec2(0, imgui.GetTextLineHeight()))
            imgui.SetItemAllowOverlap()
            
            if imgui.BeginPopupContextItem() then
                if imgui.Selectable("Editar Nome") then
                    state.edit_fav_name_buf.v = loc.name
                    state.edit_fav_ref = loc
                    should_open_edit_popup = true
                end
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

            imgui.SameLine(curX); imgui.Text(loc.name or "Sem Nome")
            imgui.SameLine(p1s); imgui.TextColored(sc, st)
            imgui.SameLine(p2cs); imgui.TextColored(UI_COLORS.PINK, string.format("%.1f, %.1f, %.1f", loc.x, loc.y, loc.z))
            imgui.SameLine(p2s); imgui.TextColored(sc, st)
            imgui.SameLine(p3is); imgui.TextColored(UI_COLORS.BLUE, tostring(loc.id or 0))
        end
        imgui.EndChild()

        if should_open_edit_popup then imgui.OpenPopup("EditarFavoritoPopup") end

        if imgui.BeginPopupModal("EditarFavoritoPopup", nil, imgui.WindowFlags.AlwaysAutoResize) then
            imgui.Text("Editar nome do local:")
            imgui.InputText("##EditFavName", state.edit_fav_name_buf)
            imgui.Spacing()
            if imgui.Button("Salvar", imgui.ImVec2(100, 25)) then
                if state.edit_fav_ref then
                    state.edit_fav_ref.name = state.edit_fav_name_buf.v
                    save_events()
                    sampAddChatMessage("[PI] Local renomeado para: " .. state.edit_fav_name_buf.v, -1)
                end
                imgui.CloseCurrentPopup()
                state.edit_fav_ref = nil
            end
            imgui.SameLine()
            if imgui.Button("Cancelar", imgui.ImVec2(100, 25)) then
                imgui.CloseCurrentPopup()
                state.edit_fav_ref = nil
            end
            imgui.EndPopup()
        end
    end
end

local function draw_comandos_tab(compact)
    if not compact then
        imgui.Text("Comandos Rapidos"); imgui.Separator()
        imgui.TextDisabled("Atalhos para comandos uteis e ferramentas administrativas.")
    end
    imgui.BeginChild("CmdsList", imgui.ImVec2(0,0), true)
    
    if imgui.Button("/painelevento", imgui.ImVec2(150, 30)) then sampSendChat("/painelevento") end
    imgui.SameLine(); imgui.Text("Abre o painel de eventos do servidor.")

    if imgui.Button("/painelairdrop", imgui.ImVec2(150, 30)) then sampSendChat("/painelairdrop") end
    imgui.SameLine(); imgui.Text("Abre o painel de airdrop do servidor.")

    if imgui.Button("/comandosadm", imgui.ImVec2(150, 30)) then sampSendChat("/comandosadm") end
    imgui.SameLine(); imgui.Text("Mostra a lista de comandos administrativos.")

    if imgui.Button(esp_active and "Desativar ESP" or "Ativar ESP", imgui.ImVec2(150, 30)) then
        esp_active = not esp_active
        set_nametag_status(esp_active)
        sampAddChatMessage(esp_active and "[PI] ESP Admin Ativado (SAMP Tags)." or "[PI] ESP Admin Desativado.", -1)
    end
    imgui.SameLine(); imgui.Text("Wallhack de nome/vida/colete (Estilo SA-MP).")
    
    if imgui.Button(prof_tags_active and "Desativar Tags Profissao" or "Ativar Tags Profissao", imgui.ImVec2(150, 30)) then
        prof_tags_active = not prof_tags_active
        sampAddChatMessage(prof_tags_active and "[PI] Tags de Profissao Ativadas." or "[PI] Tags de Profissao Desativadas.", -1)
    end
    imgui.SameLine(); imgui.Text("Mostra apenas a profissao/cargo acima da cabeca.")

    local dist_esp = imgui.ImFloat(cfg.main.esp_distance)
    if imgui.SliderFloat("Distancia ESP", dist_esp, 100.0, 30000.0, "%.0f") then
        cfg.main.esp_distance = dist_esp.v
        if esp_active and sampSetNameTagDrawDistance then sampSetNameTagDrawDistance(cfg.main.esp_distance) end
    end

    local show_prof = imgui.ImBool(cfg.main.esp_show_prof)
    if imgui.Checkbox("Mostrar Profissao no ESP", show_prof) then
        cfg.main.esp_show_prof = show_prof.v
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
    end
    
    local side_list = imgui.ImBool(cfg.main.esp_side_list)
    if imgui.Checkbox("Lista Lateral de Profissoes", side_list) then
        cfg.main.esp_side_list = side_list.v
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
    end
    
    if cfg.main.esp_side_list then
        local side_x = imgui.ImInt(cfg.main.esp_side_list_x or 10)
        if imgui.SliderInt("Posicao Lista X", side_x, 0, 1920) then
            cfg.main.esp_side_list_x = side_x.v
        end
        local side_y = imgui.ImInt(cfg.main.esp_side_list_y or 0)
        if imgui.SliderInt("Posicao Lista Y (Offset)", side_y, -500, 500) then
            cfg.main.esp_side_list_y = side_y.v
        end
        local side_font = imgui.ImInt(cfg.main.esp_side_list_font_size or 7)
        if imgui.SliderInt("Tamanho Fonte Lista", side_font, 5, 20) then
            cfg.main.esp_side_list_font_size = side_font.v
            prof_font = renderCreateFont('Arial', cfg.main.esp_side_list_font_size, 5)
        end
        local side_fist = imgui.ImBool(cfg.main.esp_side_list_show_fist)
        if imgui.Checkbox("Mostrar 'Punhos' na Lista", side_fist) then
            cfg.main.esp_side_list_show_fist = side_fist.v
            inicfg.save(cfg, "PainelInfo_Config_v8.ini")
        end
    end


    local prof_offset = imgui.ImInt(cfg.main.esp_prof_offset or 0)
    if imgui.SliderInt("Altura Tag Profissao", prof_offset, -50, 50) then
        cfg.main.esp_prof_offset = prof_offset.v
    end

    local col_val = tonumber(cfg.main.esp_prof_bg_color) or 0xE0000000
    local a = bit.band(bit.rshift(col_val, 24), 0xFF)
    local r = bit.band(bit.rshift(col_val, 16), 0xFF)
    local g = bit.band(bit.rshift(col_val, 8), 0xFF)
    local b = bit.band(col_val, 0xFF)
    local bg_color_vec = imgui.ImFloat4(r/255, g/255, b/255, a/255)
    if bg_color_vec then
        if imgui.ColorEdit4("Cor Fundo Tag", bg_color_vec) then
            local v1, v2, v3, v4
            if bg_color_vec.v then v1, v2, v3, v4 = bg_color_vec.v[1], bg_color_vec.v[2], bg_color_vec.v[3], bg_color_vec.v[4]
            else v1, v2, v3, v4 = bg_color_vec.x, bg_color_vec.y, bg_color_vec.z, bg_color_vec.w end
            
            local new_r = math.floor((v1 or 0) * 255)
            local new_g = math.floor((v2 or 0) * 255)
            local new_b = math.floor((v3 or 0) * 255)
            local new_a = math.floor((v4 or 1) * 255)
            cfg.main.esp_prof_bg_color = bit.bor(bit.lshift(new_a, 24), bit.lshift(new_r, 16), bit.lshift(new_g, 8), new_b)
        end
        imgui.SameLine()
        if imgui.Button("Salvar##Color") then
            inicfg.save(cfg, "PainelInfo_Config_v8.ini")
            sampAddChatMessage("[PI] Cor salva!", -1)
        end
    end

    imgui.Separator()
    imgui.Text("Extrator de IPs")
    if not ip_extractor_active then
        imgui.Text("Quantidade:")
        imgui.SameLine()
        imgui.PushItemWidth(80)
        imgui.InputText("##IPTotal", state.ip_extractor_total_buf)
        imgui.PopItemWidth()
        imgui.SameLine()
        imgui.Checkbox("Verif. Duplicados", state.ip_extractor_check_dupes)
        imgui.SameLine()
        imgui.Checkbox("Salvar Auto (.txt)", state.ip_extractor_auto_save)
        imgui.SameLine()
        if imgui.Button("Iniciar", imgui.ImVec2(80, 25)) then
            local total = tonumber(state.ip_extractor_total_buf.v)
            if total and total > 0 then
                lua_thread.create(function()
                    ip_extractor_active = true
                    ip_extractor_current = 0
                    extracted_ips = {}
                    ip_req_queue = {}
                    sampAddChatMessage("[PI] Iniciando extração de IPs...", 0x00FF00)
                    for i = 0, total - 1 do
                        if not ip_extractor_active then
                            sampAddChatMessage("[PI] Extração de IPs interrompida.", 0xFFD700)
                            break
                        end
                        ip_extractor_current = i
                        if sampIsPlayerConnected(i) then
                            local nick = sampGetPlayerNickname(i)
                            table.insert(ip_req_queue, {id = i, name = nick})
                            sampSendChat("/IP " .. i)
                            wait(50)
                        end
                        if i % 50 == 0 then wait(0) end
                    end
                    wait(1000) -- Espera respostas finais
                    if ip_extractor_active then
                        sampAddChatMessage("[PI] Extração de IPs concluída!", 0x00FF00)
                        if state.ip_extractor_check_dupes.v then
                            saveDuplicatesReport()
                        end
                    end
                    ip_extractor_active = false
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
        imgui.Text(string.format("Progresso: %d / %s", ip_extractor_current, state.ip_extractor_total_buf.v))
        if imgui.Button("Parar", imgui.ImVec2(80, 25)) then
            ip_extractor_active = false
            ip_req_queue = {}
        end
    end

    imgui.EndChild()
end

-- =========================================================================
-- FUNÇÃO PRINCIPAL DO SCRIPT (ON_DRAW_FRAME) - ATUALIZADA (V8.4.16)
-- =========================================================================
function imgui.OnDrawFrame()
    if state.window_open.v then
        local sw, sh = getScreenResolution(); imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5)); imgui.SetNextWindowSize(imgui.ImVec2(600, 400), imgui.Cond.FirstUseEver)
        
        imgui.Begin("Painel Admin [F12] - v" .. thisScript().version, state.window_open)

        local tabs = { {1, "Novatos"}, {2, "Online"}, {4, "Informações"}, {9, "Locais"}, {13, "Comandos"}, {11, "Config"} }; local btn_space = imgui.GetWindowWidth() / #tabs; local btn_w = imgui.ImVec2(math.floor(btn_space) - 5, 25); local act_bg=UI_COLORS.WHITE; local act_hov=imgui.ImVec4(.8,.8,.8,1); local act_txt=UI_COLORS.BLACK; local inact_bg=imgui.GetStyle().Colors[imgui.Col.Button]; local inact_hov=imgui.GetStyle().Colors[imgui.Col.ButtonHovered]; local inact_txt=imgui.GetStyle().Colors[imgui.Col.Text]
        for i, tab in ipairs(tabs) do local tid, tnm = tab[1], tab[2]; local is_act = state.active_tab == tid; if is_act then imgui.PushStyleColor(imgui.Col.Button,act_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,act_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,act_hov); imgui.PushStyleColor(imgui.Col.Text,act_txt) else imgui.PushStyleColor(imgui.Col.Button,inact_bg); imgui.PushStyleColor(imgui.Col.ButtonHovered,inact_hov); imgui.PushStyleColor(imgui.Col.ButtonActive,inact_hov); imgui.PushStyleColor(imgui.Col.Text,inact_txt) end; if imgui.Button(tnm, btn_w) then if state.active_tab ~= tid then state.active_tab=tid end end; imgui.PopStyleColor(4); if i < #tabs then imgui.SameLine(0, 2) end end; imgui.Separator(); imgui.Text(string.format("Hora: %s", os.date("%H:%M:%S"))); 
        imgui.SameLine()
        HelpMarker("GUIA RAPIDO DO PAINEL:\n\n[Novatos/Online]\n- Lista jogadores e Staff.\n- Botao Direito no nome: Opcoes (Ir, Espiar, IP, Docs).\n- Filtros: PC/Mobile, Mafia/Honestas.\n\n[Informacoes]\n- Listas de IDs (Veiculos, Skins, Armas).\n- Duplo Clique: Cria veiculo, seta skin ou da arma.\n- Botoes 'Aplicar': Executam a acao no ID alvo.\n\n[Locais]\n- Interiores: Lista de interiores do jogo (Duplo clique para ir).\n- Favoritos: Salve sua posicao atual ou gerencie locais.\n\n[Comandos]\n- Atalhos uteis (/painelevento, /comandosadm).\n- Ferramentas: ESP (Wallhack) e Extrator de IPs.\n\n[Config]\n- Temas, Transparencia e Senha Admin.")
        imgui.Spacing()
        local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED); if myid then local mynick=sampGetPlayerNickname(myid) or "?"; imgui.TextColored(UI_COLORS.YELLOW, string.format("Voce: %s (ID: %d)", u8(mynick), myid)); imgui.Spacing() end

        local search_lbl = ""; local show_search = true
        if state.active_tab == 1 then search_lbl="Pesq. Novato" elseif state.active_tab == 2 then search_lbl="Pesq. Online" elseif state.active_tab == 4 then if state.active_info_sub_tab == 1 then search_lbl="Pesq. Prof" elseif state.active_info_sub_tab == 2 then search_lbl="Pesq. Veh" elseif state.active_info_sub_tab == 3 then search_lbl="Pesq. Skin" elseif state.active_info_sub_tab == 4 then search_lbl="Pesq. Arma" elseif state.active_info_sub_tab == 5 then search_lbl="Pesq. FAQ" elseif state.active_info_sub_tab == 6 then show_search = false else search_lbl="Pesq." end elseif state.active_tab == 9 then if state.active_locais_sub_tab == 1 then search_lbl="Pesq. Interior" else search_lbl="Pesq. Favorito" end elseif state.active_tab == 11 or state.active_tab == 13 then show_search = false else search_lbl="Pesq." end
        if show_search then imgui.InputText(search_lbl, state.search_text, imgui.ImVec2(300, 0)); imgui.Spacing() elseif state.active_tab ~= 11 and (state.active_tab ~= 4 or state.active_info_sub_tab ~= 5) then imgui.TextColored(UI_COLORS.GREY,"Selecione topico."); imgui.Spacing() end

        if state.active_tab == 1 or state.active_tab == 2 then
            draw_players_tab()
        elseif state.active_tab == 4 then
            draw_info_tab()
        elseif state.active_tab == 9 then
            draw_locais_tab()
        elseif state.active_tab == 13 then
            draw_comandos_tab()
        elseif state.active_tab == 11 then
            draw_config_tab()
        end -- Fim do active_tab

        imgui.End()
    end

    -- JANELAS SEPARADAS (MOVIDAS PARA ONDRAWFRAME PARA EVITAR CRASH)
    if state.window_duvidas.v then
        imgui.SetNextWindowSize(imgui.ImVec2(400, 300), imgui.Cond.FirstUseEver)
        if imgui.Begin("Duvidas e FAQ", state.window_duvidas, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(-1)
            imgui.InputText("##searchDuvidas", state.search_text_duvidas)
            imgui.PopItemWidth()
            draw_faq_tab(state.search_text_duvidas, "Win", true)
        end
        imgui.End()
    end

    if state.window_locais.v then
        imgui.SetNextWindowSize(imgui.ImVec2(400, 300), imgui.Cond.FirstUseEver)
        if imgui.Begin("Locais e Teleportes", state.window_locais, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(-1)
            imgui.InputText("##searchLocais", state.search_text_locais)
            imgui.PopItemWidth()
            imgui.PushID("WinLocais")
            draw_locais_tab(state.search_text_locais.v, true)
            imgui.PopID()
        end
        imgui.End()
    end

    if state.window_ferramentas.v then
        imgui.SetNextWindowSize(imgui.ImVec2(300, 250), imgui.Cond.FirstUseEver)
        if imgui.Begin("Ferramentas e Atalhos", state.window_ferramentas, imgui.WindowFlags.NoCollapse) then
            imgui.PushID("WinFerramentas")
            draw_comandos_tab(true)
            imgui.PopID()
        end
        imgui.End()
    end

    if state.window_veiculos.v then
        imgui.SetNextWindowSize(imgui.ImVec2(500, 350), imgui.Cond.FirstUseEver)
        if imgui.Begin("Lista de Veiculos", state.window_veiculos, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(-1)
            imgui.InputText("##searchVeh", state.search_text_veiculos)
            imgui.PopItemWidth()
            imgui.PushID("WinVeh")
            draw_vehicles_content(state.search_text_veiculos.v, true)
            imgui.PopID()
        end
        imgui.End()
    end

    if state.window_skins.v then
        imgui.SetNextWindowSize(imgui.ImVec2(350, 350), imgui.Cond.FirstUseEver)
        if imgui.Begin("Lista de Skins", state.window_skins, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(-1)
            imgui.InputText("##searchSkins", state.search_text_skins)
            imgui.PopItemWidth()
            
            imgui.Text("ID:")
            imgui.SameLine()
            imgui.PushItemWidth(60)
            imgui.InputText("##TargetID_Skins", state.target_id_buf)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button("Eu##Skins") then local _,mid=sampGetPlayerIdByCharHandle(PLAYER_PED); state.target_id_buf.v=tostring(mid) end

            imgui.PushID("WinSkins")
            draw_skins_content(state.search_text_skins.v, true)
            imgui.PopID()
        end
        imgui.End()
    end

    if state.window_armas.v then
        imgui.SetNextWindowSize(imgui.ImVec2(400, 300), imgui.Cond.FirstUseEver)
        if imgui.Begin("Lista de Armas", state.window_armas, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(-1)
            imgui.InputText("##searchArmas", state.search_text_armas)
            imgui.PopItemWidth()

            imgui.Text("ID:")
            imgui.SameLine()
            imgui.PushItemWidth(50)
            imgui.InputText("##TargetID_Armas", state.target_id_buf)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button("Eu##Armas") then local _,mid=sampGetPlayerIdByCharHandle(PLAYER_PED); state.target_id_buf.v=tostring(mid) end
            
            imgui.SameLine()
            imgui.Text("Munição:")
            imgui.SameLine()
            imgui.PushItemWidth(60)
            imgui.InputText("##Ammo_Armas", state.ammo_amount_buf)
            imgui.PopItemWidth()

            imgui.PushID("WinArmas")
            draw_weapons_content(state.search_text_armas.v, true)
            imgui.PopID()
        end
        imgui.End()
    end

    if state.window_profissoes.v then
        imgui.SetNextWindowSize(imgui.ImVec2(500, 350), imgui.Cond.FirstUseEver)
        if imgui.Begin("Lista de Profissoes", state.window_profissoes, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(-1)
            imgui.InputText("##searchProf", state.search_text_profissoes)
            imgui.PopItemWidth()
            imgui.PushID("WinProf")
            draw_professions_content(state.search_text_profissoes.v, true)
            imgui.PopID()
        end
        imgui.End()
    end
end

-- FUNÇÃO PRINCIPAL E DE TOGGLE
local function check_process()
    imgui.Process = state.window_open.v or state.window_duvidas.v or state.window_locais.v or state.window_ferramentas.v or state.window_veiculos.v or state.window_skins.v or state.window_armas.v or state.window_profissoes.v
end

local function toggle_window() state.window_open.v = not state.window_open.v; check_process() end
sampRegisterChatCommand("painelinfo", toggle_window); sampRegisterChatCommand("pinfo", toggle_window)
sampRegisterChatCommand("flogar", start_admin_login)
sampRegisterChatCommand("pe", function() sampSendChat("/painelevento") end)
sampRegisterChatCommand("pa", function() sampSendChat("/paineladmin") end)
sampRegisterChatCommand("pdrop", function() sampSendChat("/painelairdrop") end)
sampRegisterChatCommand("cadm", function() sampSendChat("/comandosadm") end)
sampRegisterChatCommand("cadmin", function() sampSendChat("/comandosadm") end)
sampRegisterChatCommand("admesp", function() 
    esp_active = not esp_active
    set_nametag_status(esp_active)
    sampAddChatMessage(esp_active and "[PI] ESP Admin Ativado (SAMP Tags)." or "[PI] ESP Admin Desativado.", -1)
end)
sampRegisterChatCommand("proftags", function() 
    prof_tags_active = not prof_tags_active
    sampAddChatMessage(prof_tags_active and "[PI] Tags de Profissao Ativadas." or "[PI] Tags de Profissao Desativadas.", -1)
end)
sampRegisterChatCommand("verversao", function() check_update(true) end)
sampRegisterChatCommand("duvidas", function() state.window_duvidas.v = not state.window_duvidas.v; check_process() end)
sampRegisterChatCommand("locais", function() state.window_locais.v = not state.window_locais.v; check_process() end)
sampRegisterChatCommand("ferramentas", function() state.window_ferramentas.v = not state.window_ferramentas.v; check_process() end)
sampRegisterChatCommand("veiculos", function() state.window_veiculos.v = not state.window_veiculos.v; check_process() end)
sampRegisterChatCommand("skins", function() state.window_skins.v = not state.window_skins.v; check_process() end)
sampRegisterChatCommand("armas", function() state.window_armas.v = not state.window_armas.v; check_process() end)
sampRegisterChatCommand("profissoes", function() state.window_profissoes.v = not state.window_profissoes.v; check_process() end)
sampRegisterChatCommand("local", function()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local zone_name = getGxtText(getNameOfZone(x, y, z)) or "Desconhecido"
    local city_name = getCityFromCoords(x, y)
    sampAddChatMessage(string.format("[PI] Local atual: %s, %s (%.1f, %.1f, %.1f)", zone_name, city_name, x, y, z), -1)
end)
sampRegisterChatCommand("limparchat", function()
    for i = 1, 100 do sampAddChatMessage("", -1) end
    sampAddChatMessage("[PainelInfo] Chat limpo localmente.", 0x00FF00)
end)

function main()
    while not isSampfuncsLoaded() do wait(100) end; while not isSampAvailable() do wait(100) end; check_process()
    
    -- Criar backup da configuração ao iniciar
    if backup_config then backup_config() end
    
    -- Carregar tema salvo
    local saved_theme = (cfg.main and cfg.main.theme) or "Padrao"
    for i, t in ipairs(theme_list) do 
        if t == saved_theme then 
            state.theme_combo_idx.v = i - 1 
            break
        end 
    end
    state.ip_extractor_total_buf.v = "300"
    state.server_ip_buf.v = cfg.main.server_ip or ""
    apply_theme(saved_theme)
    sampAddChatMessage("[PainelInfo] Carregado! Tema: " .. saved_theme, 0x00FF00)
    if cfg.main.check_updates then
        check_update()
    end

    while true do wait(0)
        local chars = getAllChars()
        check_shooting_logic(chars)
        draw_esp_logic(chars)

        if os.clock() - last_log_flush > 5.0 then
            flush_shooting_logs()
        end

        if waiting_for_bind then
            for k = 1, 255 do
                if wasKeyPressed(k) then
                    cfg.main.bind = k
                    inicfg.save(cfg, "PainelInfo_Config_v8.ini")
                    sampAddChatMessage("[PI] Nova tecla de atalho definida: " .. (key_names[k] or k), -1)
                    waiting_for_bind = false
                    break
                end
            end
        elseif wasKeyPressed(cfg.main.bind) and not sampIsChatInputActive() and not sampIsDialogActive() then toggle_window() end
        if isKeyDown(vkeys.VK_MENU) and wasKeyPressed(vkeys.VK_L) and not sampIsChatInputActive() and not sampIsDialogActive() then
            start_admin_login()
        end

        check_process() -- Garante que o estado do cursor seja sempre atualizado
    end
end

function onScriptTerminate(script, quit)
    if script == thisScript() then
        set_nametag_status(false)
        inicfg.save(cfg, "PainelInfo_Config_v8.ini")
        flush_shooting_logs()
    end
end