-- CE engine adapter. Real CE APIs only; no fabricated process or scan results.
local Engine = {}
function Engine.new(api)
  local self = {api = api, busy = false, scanned = false, results = {}, processID = 0}
  function self.processes()
    local list = api.createStringList()
    local ok, err = pcall(api.getProcesslist, list)
    if not ok then list.destroy(); error(err) end
    local rows = {}
    for i = 0, list.Count - 1 do
      local entry = list[i]
      local id, name = entry:match('^(%x+)%-(.*)$')
      if id then rows[#rows + 1] = {id = tonumber(id, 16), name = name} end
    end
    list.destroy()
    table.sort(rows, function(a, b) return a.name:lower() < b.name:lower() end)
    return rows
  end
  function self.reset()
    assert(not self.busy, 'Aguarde a busca terminar.')
    if self.found then self.found.destroy(); self.found = nil end
    if self.scan then self.scan.destroy(); self.scan = nil end
    self.scanned = false; self.results = {}
  end
  function self.connect(id)
    assert(not self.busy, 'Aguarde a busca terminar antes de trocar o processo.')
    api.openProcess(id)
    assert(api.getOpenedProcessID() == id, 'Não foi possível abrir o processo. Confira as permissões do Windows.')
    self.reset(); self.processID = id
  end
  function self.begin(nextScan, options)
    assert(api.getOpenedProcessID() ~= 0, 'Selecione um processo primeiro.')
    assert(not self.busy, 'Uma busca já está em andamento.')
    assert(not nextScan or self.scanned, 'Faça uma primeira busca antes de refinar os resultados.')
    if nextScan then
      assert(self.processID == api.getOpenedProcessID(), 'O processo mudou. Faça uma nova primeira busca.')
      assert(options.valueType == self.valueType, 'O tipo de dado mudou. Faça uma nova primeira busca.')
    end
    if options.needsValue then assert(options.value ~= '', 'Informe o valor que deseja procurar.') end
    if not nextScan then
      self.reset(); self.scan = api.createMemScan(); self.valueType = options.valueType
      self.processID = api.getOpenedProcessID()
    end
    if self.found then self.found.destroy(); self.found = nil end
    self.results = {}; self.done = false; self.busy = true
    self.scan.OnScanDone = function() self.done = true end
    local ok, err = pcall(function()
      if nextScan then
        self.scan.nextScan(options.mode, api.rtRounded, options.value, options.second or '', false, true, false, false, false)
      else
        local stopAddress = api.targetIs64Bit() and 0x7fffffffffff or 0xffffffff
        self.scan.firstScan(options.mode, options.valueType, api.rtRounded, options.value, options.second or '',
          0, stopAddress, '', api.fsmNotAligned, '1', false, true, false, false)
      end
    end)
    if not ok then self.busy = false; self.scanned = false; error(err) end
  end
  function self.poll()
    if not self.busy or not self.done then return false end
    self.scan.waitTillDone(); self.busy = false
    self.found = api.createFoundList(self.scan)
    self.found.initialize(); self.scanned = true
    self.results = {}
    for i = 0, math.min(self.found.Count, 500) - 1 do
      self.results[#self.results + 1] = {address = self.found.Address[i], value = self.found.Value[i]}
    end
    return true, self.found.Count
  end
  function self.addResult(index)
    assert(not self.busy and self.scanned, 'Aguarde os resultados da busca.')
    local row = assert(self.results[index], 'Selecione um resultado da busca.')
    local record = api.getAddressList().createMemoryRecord()
    record.Description = 'Novo endereço'; record.Address = row.address; record.Type = self.valueType
    return record
  end
  function self.records()
    local list, rows = api.getAddressList(), {}
    for i = 0, list.Count - 1 do rows[#rows + 1] = list.getMemoryRecord(i) end
    return rows
  end
  return self
end
return Engine
