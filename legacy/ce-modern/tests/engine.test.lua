local Engine = dofile('autorun/ce_modern/engine.lua')
local passed = 0
local function check(ok, message) assert(ok, message); passed = passed + 1 end
local pid, scans, records = 0, {}, {}
local api = {rtRounded=0, fsmNotAligned=0}
api.createStringList = function() local s = {[0]='000A-zeta.exe', [1]='0010-alfa.exe', Count=2}; s.destroy=function() s.destroyed=true end; return s end
api.getProcesslist = function() end
api.openProcess = function(id) pid=id end
api.getOpenedProcessID = function() return pid end
api.targetIs64Bit = function() return true end
api.createMemScan = function()
 local s={}
 s.firstScan=function(...) s.first={...} end; s.nextScan=function(...) s.next={...} end
 s.waitTillDone=function() s.waited=true end; s.destroy=function() s.destroyed=true end
 scans[#scans+1]=s; return s
end
api.createFoundList = function(scan)
 check(scan.waited, 'Must wait for completed scanner before reading result files')
 local f={Count=600, Address={}, Value={}}
 for i=0,599 do f.Address[i]=string.format('%X',4096+i); f.Value[i]='100' end
 f.initialize=function() f.initialized=true end; f.destroy=function() f.destroyed=true end
 return f
end
local addressList = setmetatable({}, {__index=function(_,k) if k=='Count' then return #records end end})
addressList.createMemoryRecord=function() local r={}; records[#records+1]=r; return r end
addressList.getMemoryRecord=function(index) return records[index+1] end
api.getAddressList=function() return addressList end
local e=Engine.new(api)
local processes=e.processes(); check(processes[1].name=='alfa.exe' and processes[1].id==16, 'Processes must be parsed as hex IDs and sorted')
local options={value='100',valueType=2,mode=1,needsValue=true}
check(not pcall(e.begin,false,options), 'No scans without a selected process')
e.connect(16); check(pid==16,'Connecting must select the actual requested PID')
check(not pcall(e.begin,true,options), 'No refinement before an initial scan')
e.begin(false,options); check(e.busy and scans[1].first[7]==0x7fffffffffff,'64-bit bounds must be correct')
check(not pcall(e.begin,false,options),'Concurrent scans must be rejected')
check(not pcall(e.connect,10),'Cannot switch processes during a scan')
check(not pcall(e.reset),'Cannot clear a running scan')
check(not e.poll(),'Polling must not read unfinished scans')
scans[1].OnScanDone(); local done,count=e.poll()
check(done and count==600 and #e.results==500,'Results must preserve total count and limit visible rows')
local r=e.addResult(1);check(r.Address=='1000' and r.Type==2,'Added record must use the actual found address and type')
check(not pcall(e.addResult,501),'Out-of-range results must be rejected')
check(#e.records()==1,'Records must come from the native shared table')
check(not pcall(e.begin,true,{value='100',valueType=3,mode=1,needsValue=true}),'Refinement must preserve value type')
pid=10;check(not pcall(e.begin,true,options),'Refinement must reject process changes');pid=16
local old=e.found;e.begin(true,options);check(old.destroyed and scans[1].next[3]=='100','Refinement must close previous results and use requested value')
scans[1].OnScanDone();e.poll();e.reset();check(not e.scanned and not e.scan and #e.results==0,'Reset must release owned scan objects')
check(not pcall(e.begin,false,{value='',valueType=2,mode=1,needsValue=true}),'Empty exact searches must be blocked')
print('PASS: '..passed..' engine assertions')
