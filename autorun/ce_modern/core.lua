-- Pure command routing; never evaluates speech or arbitrary Lua.
local M = {}
M.voiceCommands = {
  process = 'process', scan = 'scan', next = 'next',
  table = 'table', memory = 'memory', scripts = 'scripts',
  help = 'help', stop = 'stop', original = 'original'
}
function M.control(form, names)
  for _, name in ipairs(names) do
    local ok, value = pcall(function() return form[name] end)
    if ok and value then return value end
    for i = 0, form.ComponentCount - 1 do
      local item = form.getComponent(i)
      if item.Name == name then return item end
    end
  end
end
function M.invoke(form, names)
  local control = M.control(form, names)
  if not control then return false, 'Controle indisponível nesta versão. Use a janela original.' end
  if control.Enabled == false then return false, 'Esta ação ainda não está disponível. Verifique o processo e a busca atual.' end
  local ok, err = pcall(function() control.doClick() end)
  if not ok then return false, 'O Cheat Engine recusou a ação: ' .. tostring(err) end
  return true
end
function M.dispatch(token, actions)
  local name = M.voiceCommands[token]
  if not name or not actions[name] then return false end
  actions[name]()
  return true
end
function M.consume(text, lastSequence, dispatch)
  for sequence, token in text:gmatch('(%d+)|([a-z]+)\r?\n') do
    sequence = tonumber(sequence)
    if sequence > lastSequence then
      dispatch(token)
      lastSequence = sequence
    end
  end
  return lastSequence
end
return M
