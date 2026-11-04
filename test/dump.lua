-- MAME autoboot script: presses keys at given times and writes the 80-column
-- text screen (banks $E0/$E1, what the display shows) to text files.
--   DUMP_DIR   where the files go
--   KEYS       "secs:key,..."  key = text to type, mouse-X-Y (the pointer there),
--              click, dclick (a double click), or one of return, esc, tab,
--              delete, space, up, down, left, right, or cmd-<letter>;
--              hold=NAME / free=NAME: a key (Option...) held down, let go
--   SHOTS      "secs:name,..." a text dump (name.txt) and a snapshot at that time
--              (SNAPS=1: also MAME's own picture of the frame, in its snap folder)
local dir = os.getenv("DUMP_DIR")
local space = manager.machine.devices[":maincpu"].spaces["program"]

local function field(name)
    for _, port in pairs(manager.machine.ioport.ports) do
        if port.fields[name] then return port.fields[name] end
    end
end

local steps = {}
release, held = nil, nil
target, mx_, my_ = nil, 0, 0
local mfx, mfy = nil, nil
local function add(t, f) table.insert(steps, { t = t, f = f }) end
local function press(t, name)
    local fl = field(name)
    if not fl then print("no key " .. name) return end
    add(t, function() fl:set_value(1); release = fl end)   -- (let go on the next frame)
end

mfx, mfy = field("Mouse X"), field("Mouse Y")
for item in string.gmatch(os.getenv("KEYS") or "", "[^,]+") do
    local t, key = item:match("^%s*([%d%.]+):(.+)$")
    t = tonumber(t)
    local named = ({ up = "Up Arrow", down = "Down Arrow", left = "Left Arrow", right = "Right Arrow" })[key]
    local coded = ({ esc = "{ESC}", delete = "{BACKSPACE}", tab = "\t", ["return"] = "\r", space = " " })[key]
    local cmd = key:match("^cmd%-(.)$")
    local mx, my = key:match("^mouse%-(%d+)%-(%d+)$")
    local fname = key:match("^key=(.+)$")
    local hname = key:match("^hold=(.+)$")
    local uname = key:match("^free=(.+)$")
    if hname or uname then                       -- a key held down / let go
        local fl = field(hname or uname)
        if fl then add(t, function() if hname then fl:set_value(1) else fl:clear_value() end end)
        else print("no key " .. (hname or uname)) end
    elseif fname then
        press(t, fname)                          -- a keyboard key by its name
    elseif mx then
        -- the pointer to x, y (screen pixels, the menu bar's top is y 0)
        add(t, function() target = { x = tonumber(mx), y = tonumber(my) } end)
    elseif key == "mdown" or key == "mup" then      -- (for menus: down, move, up)
        local btn = field("Mouse Button 0")
        add(t, function() if key == "mdown" then btn:set_value(1) else btn:clear_value() end end)
    elseif key == "click" or key == "dclick" then
        local btn = field("Mouse Button 0")
        add(t, function() btn:set_value(1) end)
        add(t + 0.1, function() btn:clear_value() end)
        if key == "dclick" then
            add(t + 0.25, function() btn:set_value(1) end)
            add(t + 0.35, function() btn:clear_value() end)
        end
    elseif cmd then
        local command = field("Command")
        local letter = field(cmd:lower() .. "  " .. cmd:upper())
        add(t, function() command:set_value(1) end)
        add(t + 0.1, function() letter:set_value(1) end)
        add(t + 0.2, function() letter:clear_value() end)
        add(t + 0.3, function() command:clear_value() end)
    elseif named then
        press(t, named)
    elseif coded then
        add(t, function()
            if coded:sub(1, 1) == "{" then manager.machine.natkeyboard:post_coded(coded)
            else manager.machine.natkeyboard:post(coded) end
        end)
    else
        add(t, function() manager.machine.natkeyboard:post(key) end)
    end
end

local function dump(name)
    local tf = io.open(string.format("%s/%s.txt", dir, name), "w")
    for row = 0, 23 do
        local base = 0x400 + (row % 8) * 0x80 + (row // 8) * 0x28
        local line = {}
        for col = 0, 79 do
            local bank = (col % 2 == 0) and 0xE10000 or 0xE00000
            local c = space:read_u8(bank + base + col // 2)
            if c >= 0x80 then c = c & 0x7F
            elseif c < 0x20 then c = c + 0x40       -- inverse capitals
            elseif c >= 0x40 and c < 0x60 then c = 0x23   -- MouseText: '#'
            end
            line[#line + 1] = string.char(c)
        end
        tf:write(table.concat(line), "\n")
    end
    tf:close()
    if os.getenv("SNAPS") then manager.machine.video:snapshot() end   -- (the frame as shown)
    local sf = io.open(string.format("%s/%s.shr", dir, name), "wb")
    for a = 0xE12000, 0xE19FFF do sf:write(string.char(space:read_u8(a))) end
    sf:close()
    local st = manager.machine.devices[":maincpu"].state
    if os.getenv("DUMPBANK") then             -- (the bank the processor is in)
        local bk = st["PB"].value
        local bf = io.open(string.format("%s/%s.bank", dir, name), "wb")
        for a = bk << 16, (bk << 16) + 0xFFFF do bf:write(string.char(space:read_u8(a))) end
        bf:close()
    end
    local pf = io.open(string.format("%s/pc.txt", dir), "a")
    pf:write(string.format("%s PB=%02X PC=%04X S=%04X D=%04X DB=%02X P=%02X\n", name, st["PB"].value, st["PC"].value, st["S"].value, st["D"].value, st["DB"].value, st["P"].value))
    pf:close()
end

for item in string.gmatch(os.getenv("SHOTS") or "", "[^,]+") do
    local t, name = item:match("^%s*([%d%.]+):(.+)$")
    add(tonumber(t), function() dump(name) end)
end
table.sort(steps, function(a, b) return a.t < b.t end)
local nxt = 1
emu.register_periodic(function()
    local t = manager.machine.time:as_double()
    -- the mouse: nudged a step a frame until QuickDraw's pointer is on target
    if target then
        local qd = space:read_u32((space:read_u32(0xE103C8) & 0xFFFFFF) + 16) & 0xFFFFFF
        local v, h = space:read_u16(qd + 0x156), space:read_u16(qd + 0x158)
        local dx, dy = target.x - h, target.y - v
        if dx == 0 and dy == 0 then
            target.done = (target.done or 0) + 1
            if target.done > 3 then target = nil end
        else
            target.done = 0
            local function step(d) if d > 3 then return 3 elseif d < -3 then return -3 else return d end end
            mx_ = (mx_ + step(dx)) % 256; my_ = (my_ + step(dy)) % 256
            mfx:set_value(mx_); mfy:set_value(my_)
        end
    end
    if release then
        if not held then held = t
        elseif t > held then release:clear_value(); release = nil
            local lf = io.open(dir .. "/keys.txt", "a"); lf:write(string.format("down %.4f up %.4f\n", held, t)); lf:close()
            held = nil end
    end
    while nxt <= #steps and t >= steps[nxt].t do
        steps[nxt].f()
        nxt = nxt + 1
    end
end)
