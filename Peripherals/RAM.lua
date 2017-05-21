--[[
Layout (96 KB)
--------------
0x0000 Meta Data (736 Bytes)
0x02E0 SpriteMap (12 KB)
0x32E0 Flags Data (288 Bytes)
0x3400 MapData (18 KB)
0x7C00 Sound Tracks (13 KB)
0x9C00 Compressed Lua Code (20 KB)
0xCC00 Persistant Data (2 KB)
0xD400 GPIO (128 Bytes)
0xD480 Reserved (768 Bytes)
0xD780 Draw State (64 Bytes)
0xD7C0 Free Space (1 KB)
0xDBC0 Reserved (4 KB)
0xEC00 Label Image (12 KBytes)
0x11C00 VRAM (12 KBytes)
0x14C00 End of memory

Meta Data (1 KB)
----------------
0x0000 Data Length (6 Bytes)
0x0006 Color Palette (64 Bytes)
0x0046 LIKO-12 Header (7 Bytes)
0x004D Disk Version (1 Byte)
0x004E Disk Meta (1 Byte)
0x004F Screen Width (2 Bytes)
0x0051 Screen Hight (2 Bytes)
0x0053 Reserved (1 Byte)
0x0054 SpriteMap Address (4 Bytes)
0x0058 MapData Address (4 Bytes)
0x005C Instruments Data Address (4 Bytes)
0x0060 Tracks Data Address (4 Bytes)
0x0064 Tracks Orders Address (4 Bytes)
0x0068 Compressed Lua Code Address (4 Bytes)
0x006C Author Name (16 Bytes)
0x007C Game Name (16 Bytes)
0x008C Reserved (600 Bytes)

Disk META:
--------------
1. Auto event loop.
2. Activate controllers.
3. Keyboad Only.
4. Mobile Friendly.
5. Static Resolution.
6. Compatibilty Mode.
7. Write Protection.
8. Licensed Under CC0.
]]

return function(config)
  local ramsize = config.size or 80*1024 --Defaults to 80 KBytes.
  local lastaddr = string.format("0x%X",ramsize-1)
  local ram = string.rep("\0",ramsize)
  
  local handlers = {}
  
  local devkit = {}
  
  function devkit.addHandler(startAddress, endAddress, handler)
    if type(startAddress) ~= "number" then return error("Start address must be a number, provided: "..type(startAddress)) end
    if type(endAddress) ~= "number" then return error("End address must be a number, provided: "..type(endAddress)) end
    if type(handler) ~= "function" then return error("Handler must be a function, provided: "..type(handler)) end
    
    if startAddress < 0 then return error("Start Address out of range ("..startAddress..") Must be [0,"..(ramsize-1).."]") end
    if startAddress > ramsize-1 then return error("Start Address out of range ("..startAddress..") Must be [0,"..(ramsize-1).."]") end
    if endAddress < 0 then return error("End Address out of range ("..startAddress..") Must be [0,"..(ramsize-1).."]") end
    if endAddress > ramsize-1 then return error("End Address out of range ("..startAddress..") Must be [0,"..(ramsize-1).."]") end
    
    table.insert(handlers,{startAddr = startAddress, endAddr = endAddress, handler = handler})
    table.sort(handlers, function(t1,t2)
      return (t1.startAddr < t2.startAddr)
    end)
  end
  
  --Writes and reads from the RAM string.
  function devkit.defaultHandler(mode,...)
    local args = {...}
    if mode == "poke" then
      local address, value = unpack(args)
      ram = ram:sub(0,address) .. string.char(value) .. ram:sub(address+2,-1)
    elseif mode == "peek" then
      local address = args[1]
      return string.byte(ram:sub(address+1,address+1))
    elseif mode == "memcpy" then
      local from, to, len = unpack(args)
      local str = ram:sub(from+1,from+len)
      ram = ram:sub(0,to) .. str .. ram:sub(to+len,-1)
    elseif mode == "memset" then
      local address, value = unpack(args)
      local len = value:len()
      ram = ram:sub(0,address) .. value .. ram:sub(address+len,-1)
    elseif mode == "memget" then
      local address, len = unpack(args)
      return ram:sub(address+1,address+len)
    end
  end
  
  local function tohex(val) return string.format("0x%X",val) end
  
  local api = {}
  
  function api:poke(address,value)
    if type(address) ~= "number" then return false, "Address must be a number, provided: "..type(address) end
    if type(value) ~= "number" then return false, "Value must be a number, provided: "..type(value) end
    address, value = math.floor(address), math.floor(value)
    if address < 0 or address > ramsize-1 then return false, "Address out of range ("..tohex(address).."), must be in range [0x0,"..lastaddr.."]" end
    if value < 0 or value > 255 then return false, "Value out of range ("..value..") must be in range [0,255]" end
    
    local handler = devkit.defaultHandler
    for k,h in ipairs(handlers) do
      if address <= h.endAddr then
        handler = h.handler
        break
      end
    end
    return true, handler("poke",address,value)
  end
  
  function api:peek(address)
    if type(address) ~= "number" then return false, "Address must be a number, provided: "..type(address) end
    address = math.floor(address)
    if address < 0 or address > ramsize-1 then return false, "Address out of range ("..tohex(address).."), must be in range [0x0,"..lastaddr.."]" end
    
    local handler = devkit.defaultHandler
    for k,h in ipairs(handlers) do
      if address <= h.endAddr then
        handler = h.handler
        break
      end
    end
    return true, handler("peek",address)
  end
  
  function api:memget(address,length)
    if type(address) ~= "number" then return false, "Address must be a number, provided: "..type(address) end
    if type(length) ~= "number" then return false, "Length must be a number, provided: "..type(length) end
    address, length = math.floor(address), math.floor(length)
    if address < 0 or address > ramsize-1 then return false, "Address out of range ("..tohex(address).."), must be in range [0x0,"..lastaddr.."]" end
    if length == 0 or address+length < 0 or address+length > ramsize then return false, "Length out of range ("..length..")" end
    local endAddress = address+length-1
    
    local str = ""
    for k,h in ipairs(handlers) do
      if endAddress > h.startAddr then
        if address < h.endAddr then
          local sa, ea = address, endAddress
          if sa < h.startAddr then sa = h.startAddr end
          if ea > h.endAddr then ea = h.endAddr end
          local data = h.handler("memget",sa,ea-address+1)
          str = str .. data
        end
      end
    end
    
    return true, str
  end
  
  function api:memset(address,data)
    if type(address) ~= "number" then return false, "Address must be a number, provided: "..type(address) end
    if type(data) ~= "string" then return false, "Data must be a string, provided: "..type(data) end
    address = math.floor(address)
    if address < 0 or address > ramsize-1 then return false, "Address out of range ("..tohex(address).."), must be in range [0x0,"..lastaddr.."]" end
    local length = data:len()
    if length == 0 then return false, "Cannot set empty string" end
    if address+length < 1 or address+length > ramsize then return false, "Data too long to fit in the memory ("..length.." character)" end
    local endAddress = address+length-1
    
    for k,h in ipairs(handlers) do
      if endAddress > h.startAddr then
        if address < h.endAddr then
          local sa, ea, d = address, endAddress, data
          if sa < h.startAddr then sa = h.startAddr end
          if ea > h.endAddr then ea = h.endAddr end
          d = data:sub(sa-address+1,ea-address+1)
          h.handler("memset",sa,data)
        end
      end
    end
    
    return true
  end
  
  function api:memcpy(from_address,to_address,length)
    if type(from_address) ~= "number" then return false, "Source Address must be a number, provided: "..type(from_address) end
    if type(to_address) ~= "number" then return false, "Destination Address must be a number, provided: "..type(to_address) end
    if type(length) ~= "number" then return false,"Length must be a number, provided: "..type(length) end
    from_address, to_address, length = math.floor(from_address), math.floor(to_address), math.floor(length)
    if from_address < 0 or from_address > ramsize-1 then return false, "Source Address out of range ("..tohex(from_address).."), must be in range [0x0,"..lastaddr.."]" end
    if to_address < 0 or to_address > ramsize-1 then return false, "Destination Address out of range ("..tohex(to_address).."), must be in range [0x0,"..lastaddr.."]" end
    if length == 0 then return false, "Length can't be 0" end
    if from_address+length < 1 or from_address+length > ramsize then return false, "Length out of range ("..length..")" end
    if to_address+length < 1 then length = 1-to_address end
    if to_address+length > ramsize then length = ramsize-to_address end
    local from_end = from_address+length-1
    local to_end = to_address+length-1
    
    for k1,h1 in ipairs(handlers) do
      if from_end > h1.startAddr and from_address < h1.endAddr then
        local sa1, ea1 = from_address, from_end
        if sa1 < h1.startAddr then sa1 = h1.startAddr end
        if ea1 > h1.endAddr then ea1 = h1.endAddr end
        for k2,h2 in ipairs(handlers) do
          if to_end > h2.startAddr and to_address < h2.endAddr then
            local sa2, ea2 = to_address, to_end
            if sa2 < h2.startAddr then sa2 = h2.startAddr end
            if ea2 > h2.endAddr then ea2 = h2.endAddr end
            if h1.handler == h2.handler then --Direct Copy
              h1.handler("memcpy",sa1,sa2,ea2-to_address+1)
            else --InDirect Copy
              local d = h1.handler("memget",sa1,ea2-to_address+1)
              h2.handler("memset",sa2,d)
            end
          end
        end
      end
    end
    
    return true
  end
  
  devkit.ramsize = ramsize
  setmetatable(devkit,{
    __index = function(t,k)
      if k == "ram" then return ram end
    end
  })
  
  return api, devkit
end