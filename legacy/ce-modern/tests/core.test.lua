local core = dofile('autorun/ce_modern/core.lua')
local count = 0
local function check(value, message)
  assert(value, message); count = count + 1
end
local clicks = 0
local button = {Enabled = true, Name = 'btnFirst', doClick = function() clicks = clicks + 1 end}
local form = {ComponentCount = 1, getComponent = function() return button end}
check(core.invoke(form, {'missing', 'btnFirst'}), 'Control discovery should find named components')
check(clicks == 1, 'Must invoke exactly once')
button.Enabled = false
check(not core.invoke(form, {'btnFirst'}), 'Must not invoke a disabled scan')
check(clicks == 1, 'Disabled control must remain untouched')
check(not core.invoke(form, {'unknown'}), 'Missing control must fail with a useful message')
button.Enabled = true; button.doClick = function() error('native error') end
check(not core.invoke(form, {'btnFirst'}), 'Native errors must be caught')
local routed = {}
local actions = {scan = function() routed[#routed + 1] = 'scan' end, help = function() routed[#routed + 1] = 'help' end}
local sequence = core.consume('1|scan\n2|help\n3|os\n4|scan', 0, function(token) core.dispatch(token, actions) end)
check(sequence == 3, 'Incomplete events must wait until the next read')
check(#routed == 2, 'Unknown command must never execute')
sequence = core.consume('1|scan\n2|help\n3|os\n4|scan\n', sequence, function(token) core.dispatch(token, actions) end)
check(sequence == 4 and #routed == 3, 'Must resume without duplicate execution')
check(not core.dispatch('os.execute("command")', actions), 'Speech must never be evaluated as code')
check(not core.dispatch('memory', actions), 'Absent handlers must be ignored')
print('PASS: ' .. count .. ' core assertions')
