-- CE API contract tests with host objects; not a Windows rendering test.
local controls, records, scans, files = {}, {}, {}, {}
local pid, dialogResult, launches = 0, 6, 0
local function strings()
 local s={Text='',Count=0};s.add=function(v) s[s.Count]=v;s.Count=s.Count+1 end
 s.clear=function() for i=0,s.Count-1 do s[i]=nil end;s.Count=0 end
 s.loadFromFile=function(path) s.Text=files[path] end
 s.saveToFile=function(path) files[path]=s.Text end
 s.destroy=function() end;return s
end
local function widget(kind)
 local c={kind=kind,Font={},Constraints={},Items=strings(),Lines=strings(),ItemIndex=-1,Text='',Width=100,Height=100,Left=0,Top=0,Align='alNone'}
 c.destroy=function() c.destroyed=true end;c.show=function() c.visible=true end;c.hide=function() c.visible=false end
 c.bringToFront=function() end;c.showModal=function() return dialogResult end
 controls[#controls+1]=c;return c
end
for name,kind in pairs({createForm='form',createLabel='label',createButton='button',createPanel='panel',createEdit='edit',createComboBox='combo',createListBox='list',createMemo='memo',createTimer='timer'}) do _G[name]=function() return widget(kind) end end
local function find(caption)
 for i=#controls,1,-1 do if not controls[i].destroyed and controls[i].Caption==caption then return controls[i] end end
 error('Missing widget: '..caption)
end
local function last(kind)
 for i=#controls,1,-1 do if not controls[i].destroyed and controls[i].kind==kind then return controls[i] end end
 error('Missing kind: '..kind)
end
local main=widget('main');main.BorderStyle='bsSizeable';main.ComponentCount=0
getMainForm=function() return main end;getAutorunPath=function() return 'autorun' end
getOpenedProcessID=function() return pid end;openProcess=function(id) pid=id end;targetIs64Bit=function() return true end
createStringList=strings
getProcesslist=function(s) s.add('000A-tutorial.exe');s.add('0010-other.exe') end
createMemScan=function()
 local s={};s.firstScan=function() end;s.nextScan=function() end;s.waitTillDone=function() end;s.destroy=function() end;scans[#scans+1]=s;return s
end
createFoundList=function() return {Count=1,Address={[0]='1000'},Value={[0]='100'},initialize=function() end,destroy=function() end} end
local al=setmetatable({}, {__index=function(_,k) if k=='Count' then return #records end end})
al.createMemoryRecord=function()
 local r={Value='100',Type=2,Active=false};r.destroy=function() for i,v in ipairs(records) do if v==r then table.remove(records,i);break end end end
 records[#records+1]=r;return r
end
al.getMemoryRecord=function(i) return records[i+1] end
getAddressList=function() return al end
caHide=1;mrYes=6;mtConfirmation=3;mbYes=1;mbNo=2;vtAutoAssembler=11
vtDword=2;vtByte=0;vtWord=1;vtQword=3;vtSingle=4;vtDouble=5;rtRounded=0;fsmNotAligned=0
soExactValue=0;soBiggerThan=1;soSmallerThan=2;soUnknownValue=3;soChanged=4;soUnchanged=5;soIncreasedValue=6;soDecreasedValue=7
local message;showMessage=function(s) message=s end;messageDialog=function() return dialogResult end
getAddress=function(s) return assert(tonumber(s,16)) end
readBytes=function() local bytes={};for i=1,128 do bytes[i]=65 end;return bytes end
disassemble=function(n) return string.format('%X - nop',n) end;getInstructionSize=function() return 1 end
autoAssemble=function() return true end
local oldOpen,oldGetenv,oldTime=io.open,os.getenv,os.time;local clock=1000
os.time=function() return clock end
os.getenv=function(k) return k=='TEMP' and 'C:/Temp' or k=='SystemRoot' and 'C:/Windows' or nil end
io.open=function(path,mode)
 if mode=='wb' then return {write=function(_,v) files[path]=v end,close=function() end} end
 if files[path]~=nil then return {read=function() return files[path] end,close=function() end} end
 return oldOpen(path,mode)
end
shellExecute=function(_,args) launches=launches+1;assert(not args:find('Bypass',1,true)) end
dofile('autorun/ce_modern.lua')
assert(CE_MODERN and not main.visible and launches==0,'Panel must initialize without enabling microphone')
find('Primeira busca').OnClick();assert(message:find('processo'),'Missing process must be handled')
find('Selecionar processo').OnClick();assert(CE_MODERN.page=='process')
last('list').ItemIndex=1;find('Conectar ao processo').OnClick();assert(pid==10 and CE_MODERN.page=='scan')
CE_MODERN.value.Text='100';CE_MODERN.value.OnChange()
find('Primeira busca').OnClick();assert(CE_MODERN.engine.busy)
scans[1].OnScanDone();CE_MODERN.timer.OnTimer();assert(#CE_MODERN.engine.results==1)
last('list').ItemIndex=0;find('Adicionar resultado à tabela').OnClick();assert(#records==1)
find('02  Minha tabela').OnClick();last('list').ItemIndex=0;last('list').OnSelectionChange()
find('Congelar / descongelar').OnClick();assert(records[1].Active)
find('Congelar / descongelar').OnClick();assert(not records[1].Active)
find('03  Memória').OnClick();last('edit').Text='1000';find('Ler 128 bytes').OnClick();assert(last('memo').Lines.Text:find('41 41'))
find('Desmontar 30 instruções').OnClick();assert(last('memo').Lines.Text:find('nop'))
find('04  Scripts').OnClick();last('memo').Lines.Text='print("teste integrado")';find('Executar código').OnClick()
find('05  Recursos avançados').OnClick();assert(main.Parent~=nil,'Advanced tools must be hosted in the panel')
find('Ajuda e comandos').OnClick();assert(main.Parent==nil,'Leaving advanced area must restore original host')
find('01  Busca guiada').OnClick();assert(CE_MODERN.value.Text=='100')
find('Ativar / parar voz').OnClick();assert(launches==1 and CE_MODERN.voice)
local session=CE_MODERN.session;files[session..'.status']='ready';files[session..'.events']='1|help\n'
CE_MODERN.timer.OnTimer();assert(CE_MODERN.page=='help')
dialogResult=7;files[session..'.events']='1|help\n2|next\n';CE_MODERN.timer.OnTimer();assert(not CE_MODERN.engine.busy)
dialogResult=6;files[session..'.events']='1|help\n2|next\n3|next\n';CE_MODERN.timer.OnTimer();assert(CE_MODERN.engine.busy)
scans[1].OnScanDone();CE_MODERN.timer.OnTimer();assert(not CE_MODERN.engine.busy,'Polling should not repeat a consumed command')
files[session..'.events']='1|help\n2|next\n3|next\n4|stop\n5|scan\n';CE_MODERN.timer.OnTimer();assert(not CE_MODERN.voice and not CE_MODERN.engine.busy)
assert(files[session..'.stop']=='stop')
clock=clock+1;find('Ativar / parar voz').OnClick();clock=clock+21;CE_MODERN.timer.OnTimer();assert(not CE_MODERN.voice)
assert(CE_MODERN.form.OnClose()==caHide and main.visible)
io.open,os.getenv,os.time=oldOpen,oldGetenv,oldTime
print('PASS: integrated process selection, search/results, table/freezing, bytes/disassembly, scripts, hosting, voice confirmation and lifecycle')
