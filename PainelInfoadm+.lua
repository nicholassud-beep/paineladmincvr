script_name("PainelInfoHelper")
script_author("Gerado por ChatGPT - Adaptado por Gemini")
script_version("1.0.45")

-- Janela state
local state = {
-- =========================================================
local UPDATE_URL = "https://raw.githubusercontent.com/nicholassud-beep/paineladmincvr/main/PainelInfoHelper.lua"

local function check_update(notify_only)
    if not UPDATE_URL or #UPDATE_URL == 0 then
        if not notify_only then
            sampAddChatMessage("[PI] Erro: Link de atualizacao nao configurado no script!", 0xFF0000)
            sampAddChatMessage("[PI] Edite o script e adicione o link RAW na variavel UPDATE_URL.", 0xFF0000)
        end
        return
    end
    
    if not notify_only then sampAddChatMessage("[PI] Verificando atualizacoes...", 0xFFFF00) end
    local temp_path = os.getenv("TEMP") .. "\\painelhelper_update.tmp"
    downloadUrlToFile(UPDATE_URL, temp_path, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                
                if ver_remota then
                    if ver_remota ~= ver_atual then
                        if notify_only then
                            sampAddChatMessage("[PI] Nova versao disponivel: " .. ver_remota .. " (Atual: " .. ver_atual .. ")", 0x00FF00)
                            sampAddChatMessage("[PI] Abra a aba Config para atualizar.", 0x00FF00)
                        else
                            sampAddChatMessage("[PI] Nova versao encontrada: " .. ver_remota .. " (Atual: " .. ver_atual .. ")", 0x00FF00)
                            sampAddChatMessage("[PI] Atualizando...", 0x00FF00)
                            
                            local f_w = io.open(thisScript().path, "w")
                            if f_w then f_w:write(content); f_w:close(); sampAddChatMessage("[PI] Atualizado! Recarregando script...", 0x00FF00); thisScript():reload()
                            else sampAddChatMessage("[PI] Erro ao gravar o arquivo do script.", 0xFF0000) end
                        end
                    else
                        if not notify_only then sampAddChatMessage("[PI] Voce ja esta na versao mais recente (" .. ver_atual .. ").", 0x00FF00) end
                    end
                else
                    if not notify_only then
                        sampAddChatMessage("[PI] Erro: Nao foi possivel identificar a versao remota.", 0xFF0000)
                        sampAddChatMessage("[PI] Verifique se o arquivo existe no GitHub.", 0xFF0000)
                    end
                end
                os.remove(temp_path)
            end
        elseif status == dlstatus.STATUS_DOWNLOADERROR then
            if not notify_only then
                sampAddChatMessage("[PI] Erro de conexao ao verificar atualizacoes.", 0xFF0000)
                sampAddChatMessage("[PI] Verifique se o repositorio e Publico e o arquivo existe.", 0xFF0000)
            end
        end
    end)
end
            imgui.Spacing()
            
            if imgui.Button("Verificar Atualizacao", imgui.ImVec2(-1, 25)) then
                check_update(false)
            end
            
            if imgui.Button("Favoritar Tema (Salvar)", imgui.ImVec2(-1, 25)) then
    local font_esp = renderCreateFont('Arial', 10, 5)
    sampAddChatMessage("[PainelInfoHelper] Carregado e funcional! Pressione F12.", 0x00FF00)
    check_update(true)
    
    local last_update_check = os.time()

    while true do wait(0)
        if os.time() - last_update_check > 1800 then -- Verifica a cada 30 minutos (1800 segundos)
            check_update(true)
            last_update_check = os.time()
        end

        if waiting_for_bind then
            for k = 1, 255 do
