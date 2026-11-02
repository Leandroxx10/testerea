-- CE Modern 0.2: integrated Brazilian Portuguese workspace using CE's real engine.
if CE_MODERN then CE_MODERN.form.show(); return end
local sep = package.config:sub(1, 1)
local root = getAutorunPath(); if root:sub(-1) ~= sep then root = root .. sep end
local assets = root .. 'ce_modern' .. sep
local core = dofile(assets .. 'core.lua')
local engine = dofile(assets .. 'engine.lua').new(_G)
local main = getMainForm()
local app = {voice = false, lastSequence = 0, page = 'scan', engine = engine}
local colors = {background = 0x211611, surface = 0x30231C, text = 0xF4EEE8, muted = 0xC6B4A3, accent = 0xC8D564}
local form = createForm(false); app.form = form; CE_MODERN = app
form.Caption = 'CE Modern • Português do Brasil'; form.Width = 1200; form.Height = 840
form.Position = 'poScreenCenter'; form.Color = colors.background
form.Font.Name = 'Segoe UI'; form.Font.Size = 10; form.Font.Color = colors.text
form.Constraints.MinWidth = 1200; form.Constraints.MinHeight = 840
local function label(parent, caption, x, y, w, size, color)
  local c = createLabel(parent); c.Parent = parent; c.Left = x; c.Top = y
  c.AutoSize = false; c.Width = w; c.Height = 36; c.WordWrap = true
  c.Caption = caption; c.Font.Size = size or 10; c.Font.Color = color or colors.text; return c
end
local function button(parent, caption, x, y, w, callback)
  local c = createButton(parent); c.Parent = parent; c.Left = x; c.Top = y
  c.Width = w; c.Height = 36; c.Caption = caption; c.OnClick = callback; return c
end
local function panel(parent, x, y, w, h)
  local c = createPanel(parent); c.Parent = parent; c.Left = x; c.Top = y
  c.Width = w; c.Height = h; c.Color = colors.surface; c.BevelOuter = 'bvNone'; return c
end
local sidebar = panel(form, 0, 0, 218, 840)
label(sidebar, 'CE / MODERN', 20, 26, 190, 18, colors.accent)
label(sidebar, 'Entenda. Encontre. Organize.', 20, 78, 184, 10, colors.muted)
local process = label(sidebar, 'PROCESSO\nNenhum selecionado', 20, 560, 184, 10, colors.muted); process.Height = 64
local voiceStatus = label(sidebar, 'VOZ DESLIGADA\nAtive quando precisar.', 20, 650, 184, 10, colors.muted); voiceStatus.Height = 60
local content = panel(form, 238, 20, 926, 730)
local status = label(form, 'Comece selecionando um processo na busca guiada.', 238, 770, 920, 10, colors.muted)
local function notify(message) status.Caption = tostring(message) end
local function protect(fn)
  return function(...) local ok, err = pcall(fn, ...); if not ok then notify(err); showMessage(tostring(err)) end end
end
local widgets = {}; local refreshPage; local mounted
local function remember(c) widgets[#widgets + 1] = c; return c end
local function text(s, x, y, w, size) return remember(label(content, s, x, y, w, size)) end
local function action(s, x, y, w, fn) return remember(button(content, s, x, y, w, protect(fn))) end
local function edit(x, y, w, value)
  local c = remember(createEdit(content)); c.Parent = content; c.Left = x; c.Top = y
  c.Width = w; c.Height = 32; c.Text = value or ''; return c
end
local function combo(x, y, w, values, selected)
  local c = remember(createComboBox(content)); c.Parent = content; c.Left = x; c.Top = y
  c.Width = w; c.Style = 'csDropDownList'
  for _, v in ipairs(values) do c.Items.add(v) end
  c.ItemIndex = selected or 0; return c
end
local function list(x, y, w, h)
  local c = remember(createListBox(content)); c.Parent = content; c.Left = x; c.Top = y
  c.Width = w; c.Height = h; return c
end
local function memo(x, y, w, h, value)
  local c = remember(createMemo(content)); c.Parent = content; c.Left = x; c.Top = y
  c.Width = w; c.Height = h; c.ScrollBars = 'ssBoth'; c.WordWrap = false
  c.Lines.Text = value or ''; return c
end
local function selected(listbox, rows)
  return assert(rows[listbox.ItemIndex + 1], 'Selecione um item da lista primeiro.')
end
local function confirm(message)
  local dialog = createForm(false)
  dialog.Caption = 'Confirmar ação'; dialog.Width = 540; dialog.Height = 250
  dialog.Position = 'poScreenCenter'; dialog.Color = colors.surface
  dialog.Font.Name = 'Segoe UI'; dialog.Font.Size = 10; dialog.Font.Color = colors.text
  label(dialog, message, 20, 20, 490, 11).Height = 120
  button(dialog, 'Confirmar', 20, 156, 230, function() dialog.ModalResult = mrYes end)
  button(dialog, 'Cancelar', 268, 156, 230, function() dialog.ModalResult = mrNo end)
  local accepted = dialog.showModal() == mrYes
  dialog.destroy(); return accepted
end
local function hasProcess()
  assert(getOpenedProcessID() ~= 0, 'Selecione um processo antes de usar esta ferramenta.'); return true
end
local render
local function detach()
  if not mounted then return end
  local host = mounted
  mounted = nil
  host.control.Parent = host.parent; host.control.Align = host.align
  host.control.Left = host.left; host.control.Top = host.top
  host.control.Width = host.width; host.control.Height = host.height
  host.control.BorderStyle = host.borderStyle; host.control.hide()
end
local function clearPage()
  refreshPage = nil; detach()
  for i = #widgets, 1, -1 do widgets[i].destroy() end
  widgets = {}
end
local function chooseProcess() render('process') end
local function performScan(nextScan)
  if app.page ~= 'scan' then render('scan') end
  local options = app.options()
  engine.begin(nextScan, options)
  notify('Buscando na memória… Aguarde. Você pode navegar pelas outras seções.')
end
local function fileDialog(save, filter, callback)
  local dialog = save and createSaveDialog(form) or createOpenDialog(form)
  dialog.Filter = filter
  if dialog.execute() then local ok, err = pcall(callback, dialog.FileName); dialog.destroy(); if not ok then error(err) end
  else dialog.destroy() end
end
local function header(kicker, title, help)
  text(kicker, 24, 16, 870, 10).Font.Color = colors.accent
  text(title, 24, 52, 870, 20).Height = 48
  text(help, 24, 106, 870, 10).Height = 50
end
render = function(page)
  clearPage(); app.page = page
  if page == 'process' then
    header('CONECTAR APLICATIVO', 'Qual aplicativo você quer analisar?', 'Procure o nome do programa, selecione-o e clique em Conectar.')
    local filter = edit(24, 170, 580, '')
    local processes = list(24, 218, 870, 380)
    local allRows, rows = engine.processes(), {}
    local function update()
      processes.Items.clear(); rows = {}
      for _, row in ipairs(allRows) do
        if row.name:lower():find(filter.Text:lower(), 1, true) then
          rows[#rows + 1] = row; processes.Items.add(row.name .. '   •   PID ' .. row.id)
        end
      end
    end
    filter.OnChange = update
    action('Atualizar lista', 626, 168, 268, function() allRows = engine.processes(); update() end)
    action('Conectar ao processo', 24, 620, 340, function()
      local row = selected(processes, rows); engine.connect(row.id)
      app.processName = row.name; process.Caption = 'CONECTADO\n' .. row.name .. '\nPID ' .. row.id
      notify('Conectado a ' .. row.name .. '. Agora procure o valor que aparece no aplicativo.'); render('scan')
    end)
    update()
  elseif page == 'scan' then
    header('01 / BUSCA GUIADA', 'Encontre um valor e refine os resultados.', '1. Conecte um processo.  2. Busque o valor atual.  3. Mude o valor no aplicativo e refine a busca.')
    action('Selecionar processo', 24, 163, 250, chooseProcess)
    text('Tipo de dado', 24, 214, 260)
    local types = {vtDword, vtByte, vtWord, vtQword, vtSingle, vtDouble}
    local names = {'Inteiro • 4 bytes', 'Inteiro • 1 byte', 'Inteiro • 2 bytes', 'Inteiro • 8 bytes', 'Decimal • precisão simples', 'Decimal • precisão dupla'}
    local typeBox = combo(24, 246, 300, names, app.typeIndex)
    text('O que comparar?', 348, 214, 280)
    local modes = {soExactValue, soBiggerThan, soSmallerThan, soUnknownValue, soChanged, soUnchanged, soIncreasedValue, soDecreasedValue}
    local modeBox = combo(348, 246, 546, {'Igual ao valor informado', 'Maior que o valor informado', 'Menor que o valor informado', 'Valor inicial desconhecido', 'Valor mudou • refinar', 'Valor não mudou • refinar', 'Valor aumentou • refinar', 'Valor diminuiu • refinar'}, app.modeIndex)
    text('Valor atual no aplicativo', 24, 290, 400)
    app.value = edit(24, 322, 300, app.savedValue)
    app.value.OnChange = function() app.savedValue = app.value.Text end
    typeBox.OnChange = function() app.typeIndex = typeBox.ItemIndex end
    modeBox.OnChange = function() app.modeIndex = modeBox.ItemIndex end
    app.options = function()
      local index = modeBox.ItemIndex + 1
      if not engine.scanned then assert(index <= 4, 'Essa comparação exige uma primeira busca. Escolha uma opção inicial.') end
      if engine.scanned and index == 4 then error('Valor desconhecido só pode ser usado na primeira busca. Clique em Limpar busca.') end
      return {value = app.value.Text, valueType = types[typeBox.ItemIndex + 1], mode = modes[index], needsValue = index <= 3}
    end
    action('Primeira busca', 348, 318, 168, function() performScan(false) end)
    action('Refinar busca', 530, 318, 174, function() performScan(true) end)
    action('Limpar busca', 720, 318, 174, function() engine.reset(); render('scan'); notify('Busca limpa. Faça uma nova primeira busca.') end)
    local count = text('Resultados aparecem abaixo. Exibimos até 500 endereços por vez.', 24, 376, 870)
    local results = list(24, 416, 870, 210)
    refreshPage = function()
      results.Items.clear()
      for _, row in ipairs(engine.results) do results.Items.add(row.address .. '   •   Valor: ' .. row.value) end
      count.Caption = engine.found and (tostring(engine.found.Count) .. ' resultados encontrados. Exibindo até 500.') or 'Nenhuma busca concluída.'
    end
    action('Adicionar resultado à tabela', 24, 650, 400, function()
      engine.addResult(results.ItemIndex + 1); notify('Endereço adicionado. Abra Minha tabela para dar um nome e acompanhar o valor.')
    end)
    refreshPage()
  elseif page == 'table' then
    header('02 / MINHA TABELA', 'Organize e acompanhe seus endereços.', 'Selecione um registro para editar seu nome, endereço ou valor. Congelar mantém o valor atual fixo.')
    local entries = list(24, 170, 870, 220)
    local rows = {}
    local function update()
      local index = entries.ItemIndex
      rows = engine.records(); entries.Items.clear()
      for _, record in ipairs(rows) do entries.Items.add((record.Active and '[CONGELADO] ' or '') .. record.Description .. '   •   ' .. record.Address .. '   •   ' .. tostring(record.Value)) end
      if index >= 0 and index < #rows then entries.ItemIndex = index end
    end
    text('Nome do registro', 24, 410, 280); text('Endereço', 326, 410, 260); text('Valor', 628, 410, 260)
    local name = edit(24, 442, 280); local address = edit(326, 442, 280); local value = edit(628, 442, 266)
    entries.OnSelectionChange = function()
      local record = rows[entries.ItemIndex + 1]
      if record then name.Text = record.Description; address.Text = record.Address; value.Text = tostring(record.Value) end
    end
    action('Aplicar alterações', 24, 500, 260, function()
      local r = selected(entries, rows)
      assert(r.Type ~= vtAutoAssembler and not r.IsGroupHeader, 'Edite scripts no editor e grupos nos recursos avançados.')
      assert(not r.Active, 'Descongele o registro antes de editar seu endereço ou valor.')
      if confirm('Aplicar as alterações ao registro selecionado?') then
        r.Description = name.Text; r.Address = address.Text; r.Value = value.Text; update()
      end
    end)
    action('Congelar / descongelar', 302, 500, 290, function()
      hasProcess(); local r = selected(entries, rows)
      assert(r.Type ~= vtAutoAssembler and not r.IsGroupHeader, 'Este botão congela valores, não ativa scripts ou grupos.')
      r.Active = not r.Active; update()
    end)
    action('Atualizar valores', 610, 500, 284, update)
    action('Abrir tabela .CT', 24, 566, 260, function()
      fileDialog(false, 'Tabela do Cheat Engine (*.ct)|*.ct', function(path) loadTable(path, true); update() end)
    end)
    action('Salvar tabela .CT', 302, 566, 290, function()
      fileDialog(true, 'Tabela do Cheat Engine (*.ct)|*.ct', function(path) if not path:lower():match('%.ct$') then path = path .. '.ct' end; saveTable(path) end)
    end)
    action('Excluir registro', 610, 566, 284, function()
      local r = selected(entries, rows)
      if confirm('Excluir este registro da tabela?') then r.destroy(); update() end
    end)
    text('A tabela é compartilhada com o mecanismo do Cheat Engine. Arquivos .CT são mesclados, preservando os registros atuais.', 24, 636, 870).Height = 60
    refreshPage = update; update()
  elseif page == 'memory' then
    header('03 / MEMÓRIA', 'Leia bytes e instruções sem sair daqui.', 'Informe um endereço hexadecimal ou símbolo. Ler bytes e desmontar instruções não altera o processo.')
    local address = edit(24, 172, 500, app.memoryAddress or '')
    local output = memo(24, 230, 870, 400, 'Os dados da memória aparecerão aqui.')
    action('Ler 128 bytes', 546, 168, 348, function()
      hasProcess(); app.memoryAddress = address.Text
      local base = getAddress(address.Text); local bytes = assert(readBytes(base, 128, true), 'Não foi possível ler o endereço.')
      local lines = {}
      for i = 1, #bytes, 16 do
        local hex, printable = {}, {}
        for j = i, math.min(i + 15, #bytes) do hex[#hex + 1] = string.format('%02X', bytes[j]); printable[#printable + 1] = bytes[j] >= 32 and bytes[j] <= 126 and string.char(bytes[j]) or '.' end
        lines[#lines + 1] = string.format('%X  %s  |%s|', base + i - 1, table.concat(hex, ' '), table.concat(printable))
      end
      output.Lines.Text = table.concat(lines, '\n')
    end)
    action('Desmontar 30 instruções', 24, 652, 400, function()
      hasProcess(); local position = getAddress(address.Text); local lines = {}
      for _ = 1, 30 do lines[#lines + 1] = disassemble(position); position = position + getInstructionSize(position) end
      output.Lines.Text = table.concat(lines, '\n')
    end)
  elseif page == 'scripts' then
    header('04 / SCRIPTS', 'Automação com editor integrado.', 'Lua automatiza tarefas. Auto Assembler executa instruções. Revise o código e confirme antes de executar.')
    local language = combo(24, 166, 400, {'Lua', 'Auto Assembler'}, app.language or 0)
    local editor = memo(24, 218, 870, 370, app.scriptText or '-- Escreva seu código Lua aqui.\nprint("Olá! CE Modern está pronto.")')
    editor.OnChange = function() app.scriptText = editor.Lines.Text end
    language.OnChange = function() app.language = language.ItemIndex end
    local result = text('A saída da execução aparecerá na barra de status.', 24, 600, 870)
    action('Executar código', 24, 652, 260, function()
      if not confirm('Executar o código mostrado no editor?') then return end
      if language.ItemIndex == 0 then
        local fn, err = load(editor.Lines.Text, 'CE Modern', 't', _G); assert(fn, err)
        local prior = print; local lines = {}
        print = function(...) local args = {}; for i = 1, select('#', ...) do args[i] = tostring(select(i, ...)) end; lines[#lines + 1] = table.concat(args, '\t') end
        local ok, output = pcall(fn); print = prior; assert(ok, output)
        result.Caption = #lines > 0 and table.concat(lines, ' | ') or ('Concluído: ' .. tostring(output or 'sem retorno'))
      else
        hasProcess(); local ok, info = autoAssemble(editor.Lines.Text); assert(ok, 'O Auto Assembler não pôde aplicar o código: ' .. tostring(info)); result.Caption = 'Auto Assembler: código aplicado.'
      end
    end)
    action('Abrir arquivo', 302, 652, 280, function()
      fileDialog(false, 'Código (*.lua;*.asm)|*.lua;*.asm|Todos os arquivos|*.*', function(path) editor.Lines.loadFromFile(path) end)
    end)
    action('Salvar arquivo', 600, 652, 294, function()
      fileDialog(true, 'Código (*.lua;*.asm)|*.lua;*.asm', function(path) editor.Lines.saveToFile(path) end)
    end)
  elseif page == 'advanced' then
    header('05 / RECURSOS AVANÇADOS', 'Ferramentas originais integradas.', 'A área original é incorporada abaixo. Recursos específicos podem abrir seus próprios diálogos do Cheat Engine.')
    local host = remember(panel(content, 24, 166, 870, 530))
    mounted = {control = main, parent = main.Parent, align = main.Align, left = main.Left, top = main.Top, width = main.Width, height = main.Height, borderStyle = main.BorderStyle}
    local ok, err = pcall(function() main.BorderStyle = 'bsNone'; main.Parent = host; main.Align = 'alClient'; main.show() end)
    if not ok then detach(); text('Não foi possível incorporar esta versão do Cheat Engine: ' .. tostring(err), 24, 210, 850).Height = 160 end
  else
    header('AJUDA EM PORTUGUÊS DO BRASIL', 'Uma etapa de cada vez.', 'Comece com o aplicativo de tutorial da sua instalação para conhecer o fluxo.')
    text('1. Selecione o processo que deseja analisar.\n2. Escolha o tipo de dado e busque o valor atual.\n3. Mude o valor no aplicativo e use Refinar busca.\n4. Adicione um resultado à tabela e dê um nome a ele.\n5. Na tabela, edite ou congele o valor quando precisar.', 24, 168, 870, 12).Height = 190
    text('Comandos de voz', 24, 384, 870, 16)
    text('Selecionar processo • Primeira busca • Próxima busca\nAbrir tabela • Abrir memória • Abrir scripts • Abrir ajuda\nInterface original (recursos avançados) • Parar escuta', 24, 436, 870, 11).Height = 110
    text('O microfone só liga ao clicar. A voz navega entre as áreas e pede confirmação para buscar. Valores e código continuam sendo digitados. É necessário um reconhecedor de fala pt-BR instalado no Windows.', 24, 570, 870, 11).Height = 120
  end
end
local function original() render('advanced') end
local function readFile(path)
  local file = io.open(path, 'rb'); if not file then return nil end
  local text = file:read(1048576); file:close(); return text
end
local function writeFile(path, value)
  local file = io.open(path, 'wb'); if not file then return false end
  file:write(value); file:close(); return true
end
local function stopVoice()
  if app.session then writeFile(app.session .. '.stop', 'stop') end
  app.voice = false; voiceStatus.Caption = 'VOZ DESLIGADA\nMicrofone desativado.'
end
local lastVoiceStatus
local voiceButton
local function startVoice()
  if app.voice then stopVoice(); return end
  local temp = os.getenv('TEMP')
  local windows = os.getenv('SystemRoot')
  if not temp or not windows then showMessage('Os comandos de voz precisam do Windows.'); return end
  local session = temp .. sep .. 'ce-modern-' .. os.time() .. '-' .. math.random(100000, 999999)
  local script = assets .. 'voice.ps1'
  if session:find('"', 1, true) or script:find('"', 1, true) then showMessage('Caminho de instalação não suportado.'); return end
  if not writeFile(session .. '.events', '') then showMessage('Não foi possível criar a sessão de voz na pasta temporária.'); return end
  app.session = session; app.lastSequence = 0; app.voice = true; app.started = os.time(); lastVoiceStatus = nil
  voiceStatus.Caption = 'INICIANDO MICROFONE\nAguarde o reconhecimento...'
  shellExecute(windows .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    '-NoProfile -File "' .. script .. '" -SessionPath "' .. session .. '"', nil, 0)
end
for index, item in ipairs({{'scan', '01  Busca guiada'}, {'table', '02  Minha tabela'}, {'memory', '03  Memória'}, {'scripts', '04  Scripts'}, {'advanced', '05  Recursos avançados'}, {'help', 'Ajuda e comandos'}}) do
  local page = item[1]
  button(sidebar, item[2], 20, 145 + (index - 1) * 54, 192, function() render(page) end)
end
voiceButton = button(sidebar, 'Ativar / parar voz', 16, 724, 186, startVoice)

local function confirmScan(nextScan)
  if app.page ~= 'scan' then render('scan') end
  if confirm('Executar ' .. (nextScan and 'próxima busca' or 'primeira busca') .. ' com o valor informado?') then protect(function() performScan(nextScan) end)() end
end
local voiceActions = {
  process = chooseProcess, scan = function() confirmScan(false) end,
  next = function() confirmScan(true) end, table = function() render('table') end,
  memory = function() render('memory') end, scripts = function() render('scripts') end,
  help = function() render('help') end, stop = stopVoice, original = original
}
local timer = createTimer(form, false); timer.Interval = 350
app.timer = timer
local lastProcess
 timer.OnTimer = function()
  local pollOK, changed, count = pcall(engine.poll)
  if not pollOK then engine.busy = false; notify('Falha ao atualizar resultados: ' .. tostring(changed))
  elseif changed then notify(tostring(count) .. ' resultados encontrados.'); if app.page == 'scan' and refreshPage then refreshPage() end end
  local pid = getOpenedProcessID()
  if pid ~= lastProcess then
    process.Caption = pid == 0 and 'PROCESSO\nNenhum selecionado' or 'PROCESSO CONECTADO\nPID ' .. tostring(pid)
    lastProcess = pid
  end
  if app.voice and app.session then
    local state = readFile(app.session .. '.status')
    if state then state = state:gsub('^\239\187\191', '') end
    if state ~= lastVoiceStatus then
      lastVoiceStatus = state
      if state == 'ready' then voiceStatus.Caption = 'OUVINDO EM PORTUGUÊS\nDiga: abrir ajuda.'
      elseif state == 'missing-locale' then
        stopVoice(); showMessage('Nenhum reconhecedor de fala pt-BR foi encontrado. Instale um mecanismo de reconhecimento de fala compatível com System.Speech no Windows. Um pacote de voz TTS sozinho não basta.')
      elseif state == 'error' then
        stopVoice(); showMessage('Falha no reconhecimento. Verifique o microfone padrão, as permissões de microfone e a disponibilidade do System.Speech no Windows.')
      elseif state == 'stopped' then stopVoice() end
    end
    if not state and os.time() - app.started > 20 then
      stopVoice(); showMessage('O serviço de voz não iniciou. Verifique se a política do PowerShell permite executar o arquivo ce_modern/voice.ps1. Nenhuma política foi alterada pela extensão.')
    end
    if app.voice then
      app.lastSequence = core.consume(readFile(app.session .. '.events') or '', app.lastSequence, function(token)
        if app.voice then
          notify('Comando reconhecido: ' .. token)
          core.dispatch(token, voiceActions)
        end
      end)
    end
  end
end
form.OnClose = function() stopVoice(); detach(); main.BorderStyle = 'bsSizeable'; main.show(); form.hide(); return caHide end
local menu = main.Menu
if menu then
  local item = createMenuItem(menu); item.Caption = 'CE Modern'; item.OnClick = function() form.show() end
  menu.Items.add(item)
end
render('scan'); timer.Enabled = true; main.hide(); form.show()
