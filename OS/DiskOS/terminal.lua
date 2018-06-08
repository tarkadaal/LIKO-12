--The terminal !--
local _LIKO_Version, _LIKO_Old = BIOS.getVersion()
local _LIKO_TAG = _LIKO_Version:sub(-3,-1)
local _LIKO_DEV = (_LIKO_TAG == "DEV")
local _LIKO_BUILD = _LIKO_Version:sub(3,-5)

local MainDrive = fs.drive()
local GameDiskOS = (MainDrive == "GameDiskOS")

local PATH = "D:/Programs/;C:/Programs/;" --The system PATH variable, used by the terminal to search for programs.
local curdrive, curdir, curpath = "D", "/", "D:/" --The current active path in the terminal.

if GameDiskOS then
  PATH = "GameDiskOS:/Programs/;"
  curdrive, curpath = "GameDiskOS", "GameDiskOS:/"
end

local editor --The editors api, will be loaded later in term.init()

--Creates an iterator which returns each path in the PATH provided.
local function nextPath(p)
  if p:sub(-1)~=";" then p=p..";" end
  return p:gmatch("(.-);")
end

local fw, fh = fontSize() --The LIKO-12 GPU Font size.

local history = {} --The history of commands.
local hispos --The current item in the history.
local btimer, btime, blink = 0, 0.5, true  --The terminal cursor blink timer.
local ecommand --The editor command, used by the Ctrl-R hotkey to execute the 'run' program.
local buffer = "" --The terminal input buffer
local inputPos = 1 --The next input character position in the terminal buffer.

--Checks if the cursor is in the bounds of the screen.
local function checkCursor()
  local cx, cy = printCursor()
  local tw, th = termSize()
  if cx > tw then cx = tw end
  if cx < 0 then cx = 0 end
  if cy > th then cy = th end
  if cy < 0 then cy = 0 end
  printCursor(cx,cy,0)
  rect(cx*(fw+1)+1,blink and cy*(fh+2)+1 or cy*(fh+2),fw+1,blink and fh or fh+3,false,blink and 4 or 0) --The blink
  if inputPos <= buffer:len() then
    printCursor(cx,cy,-1)
    print(buffer:sub(inputPos,inputPos),false)
    printCursor(cx,cy,0)
  end
end

--Splits a string at each white space.
local function split(str)
  local t = {}
  for val in str:gmatch("%S+") do
    table.insert(t, val)
  end
  return unpack(t)
end

local term = {} --The terminal API

function term.init()
  editor = require("Editors") --Load the editors
  clear()
  if not GameDiskOS then
    fs.drive("D") --Set the HDD api active drive to D
  end
  color(12) print("SQULA-64")
  editor.editorsheet:draw(60,(fw+1)*6+1,fh+2)
  printCursor(0,4,0)
  cam("translate",0,3) color(12) print("D",false) color(6) print("isk",false) color(12) print("OS",false) color(6) cam("translate",0,-1) print("  ".._LIKO_BUILD) flip() sleep(0.125) cam()
  --color(6) print("\nhttp://github.com/ramilego4game/liko12")

  flip() sleep(0.0625)
  if GameDiskOS then
    if fs.exists("GameDiskOS:/autoexec.lua") then
      term.executeFile("GameDiskOS:/autoexec.lua")
    else
      color(9) print("Type help for help")
      flip() sleep(0.0625)
    end
  else
    if fs.exists("D:/autoexec.lua") then
      term.executeFile("D:/autoexec.lua")
    elseif fs.exists("C:/autoexec.lua") then
      term.executeFile("C:/autoexec.lua")
    else
      if _LIKO_Old then
        color(7) print("\n Updated LIKO-12 Successfully.\n Type ",false)
        color(6) print("help Whatsnew",false)
        color(7) print(" for changelog.\n")
      else
        term.execute("tip")
      end
      color(9) print("Type help for help")
      flip() sleep(0.0625)
    end
  end
end

--Reload the system
function term.reload()
  package.loaded = {} --Reset the package system
  package.loaded[MainDrive..":/terminal.lua"] = term --Restore the current terminal instance

  --Reload the APIS
  for k, file in ipairs(fs.getDirectoryItems(MainDrive..":/APIS/")) do
    dofile(MainDrive..":/APIS/"..file)
  end

  editor = require("Editors") --Re initialize the editors
end

function term.setdrive(d)
  if type(d) ~= "string" then return error("DriveLetter must be a string, provided: "..type(d)) end
  if not fs.drives()[d] then return error("Drive '"..d.."' doesn't exist !") end
  curdrive = d
  curpath = curdrive..":/"..curdir
end

function term.setdirectory(d)
  if type(d) ~= "string" then return error("Directory must be a string, provided: "..type(d)) end
  local p = term.resolve(d)
  if not fs.exists(p) then return error("Directory doesn't exist !") end
  if not fs.isDirectory(p) then return error("It must be a directory, not a file") end
  term.setpath(p)
end

function term.setpath(p)
  if type(p) ~= "string" then return error("Path must be a string, provided: "..type(p)) end
  p = term.resolve(p)
  if not fs.exists(p) then return error("Directory doesn't exist !") end
  if not fs.isDirectory(p) then return error("It must be a directory, not a file") end
  local drive, path
  if p:sub(-2,-1) == ":/" then
    drive = p:sub(1,-3)
    path = ""
  else
    drive,path = p:match("(.+):/(.+)")
  end
  if p:sub(-1,-1) ~= "/" then p = p.."/" end

  curdrive, curdir, curpath = drive, "/"..path, p
end

function term.getpath() return curpath end
function term.getdrive() return curdrive end
function term.getdirectory() return curdir end

function term.setPATH(p) PATH = p end
function term.getPATH() return PATH end

function term.getMainDrive() return MainDrive end
function term.isGameDiskOS() return GameDiskOS end

function term.prompt()
  color(7) print(term.getpath().."> ",false)
end

function term.resolve(path)
  path = path:gsub("\\","/") --Windows users :P

  if path:sub(-1,-1) == ":" then -- C:
    path = path.."/"
    return path, fs.exists(path)
  end

  if path:sub(-2,-1) == ":/" then -- C:/
    return path, fs.exists(path)
  end

  if not path:match("(.+):/(.+)") then
    if path:sub(1,1) == "/" then -- /Programs
      path = curdrive..":"..path
    else
      if curpath:sub(-1,-1) == "/" then
        path = curpath..path -- Demos/bump
      else
        path = curpath.."/"..path -- Demos/bump
      end
    end
  end

  local d, p = path:match("(.+):/(.+)") --C:/./Programs/../Editors
  if d and p then
    p = "/"..p.."/"; local dirs = {}
    p = p:gsub("/","//"):sub(2,-1)
    for dir in string.gmatch(p,"/(.-)/") do
      if dir == "." then
        --Do nothing, it's useless
      elseif dir == ".." then
        if #dirs > 0 then
          table.remove(dirs,#dirs) --remove the last directory
        end
      elseif dir ~= "" then
        table.insert(dirs,dir)
      end
    end

    path = d..":/"..table.concat(dirs,"/")
    return path, fs.exists(path)
  end
end

function term.executeFile(file,...)
  local chunk, err = fs.load(file)
  if not chunk then color(7) return 3, "\nL-ERR:"..tostring(err) end
  local ok, err, e = pcall(chunk,...)
  color(7) pal() palt() cam() clip() patternFill()
  if not ok then color(7) cprint("Program Error:",err) return 2, "\nERR: "..tostring(err) end
  if not fs.drives()[curdrive] then curdrive, curdir, curpath = MainDrive, "/", MainDrive..":/" end
  if not fs.exists(curpath) then curdir, curpath = "/", curdrive..":/" end
  return tonumber(err) or 0, e
end

--[[
Exit codes:
-----------
0 -> Success
1 -> Failure
2 -> Execution Error
3 -> Compilation Error
4 -> Command not found 404
]]

function term.execute(command,...)
  if not command then return 4, "No command" end
  if fs.exists(curpath..command..".lua") then
    local exitCode, err = term.executeFile(curpath..command..".lua",...)
    if exitCode > 0 then color(8) print(err or "Failed !") color(7) end
    textinput(true)
    return exitCode, err
  end
  for path in nextPath(PATH) do
    if fs.exists(path) then
      local files = fs.getDirectoryItems(path)
      for _,file in ipairs(files) do
        if file == command..".lua" then
          local exitCode, err = term.executeFile(path..file,...)
          if exitCode > 0 then color(8) print(err or "Failed !") color(7) end
          textinput(true)
          return exitCode, err
        end
      end
    end
  end
  color(9) print("Command not found: " .. command) color(7) return 4, "Command not found"
end

function term.ecommand(command) --Editor post command
	ecommand = command
end

local function splitFilePath(path) return path:match("(.-)([^\\/]-%.?([^%.\\/]*))$") end --A function to split path to path, name, extension.

function term.loop() --Enter the while loop of the terminal
  cursor("none")
  clearEStack()
  checkCursor() term.prompt()
  buffer, inputPos = "", 1
  for event, a,b,c,d,e,f in pullEvent do
    checkCursor() --Which also draws the cursor blink
    
    if event == "filedropped" then
      local p, n, e = splitFilePath(a)
      if e == "png" or e == "lk12" then
        if b then
          fs.write(MainDrive..":/.temp/"..n,b)
          blink = false; checkCursor()
          print("load "..n)
          term.execute("load",MainDrive..":/.temp/"..n)
          term.prompt()
          blink = true; checkCursor()
        else
          blink = false; checkCursor()
          print("load "..n)
          color(8) print("Failed to read file.") color(7)
          term.prompt()
          blink = true; checkCursor()
        end
      end
    elseif event == "textinput" then
      print(a..buffer:sub(inputPos,-1),false)
      for i=inputPos,buffer:len() do printBackspace(-1) end
      buffer = buffer:sub(1,inputPos-1)..a..buffer:sub(inputPos,-1)
      inputPos = inputPos + a:len()
    elseif event == "keypressed" then
      if a == "return" then
        if hispos then table.remove(history,#history) hispos = false end
        table.insert(history, buffer)
        blink = false; checkCursor()
        print("") -- insert newline after Enter
        term.execute(split(buffer)) buffer, inputPos = "", 1
        checkCursor() term.prompt() blink = true cursor("none")
      elseif a == "backspace" then
        blink = false; checkCursor()
        if buffer:len() > 0 then
          --Remove the character
          printBackspace()
          
          --Re print the buffer
          for char in string.gmatch(buffer:sub(inputPos,-1),".") do
            print(char,false)
          end
          
          --Erase the last character
          print("-",false) printBackspace()
          
          --Go back to the input position
          for i=#buffer,inputPos,-1 do
            printBackspace(-1)
          end
          
          --Remove the character from the buffer
          buffer = buffer:sub(1,inputPos-2) .. buffer:sub(inputPos,-1)
          
          --Update input postion
          inputPos = inputPos-1
        end
        blink = true; checkCursor()
      elseif a == "delete" then
        blink = false; checkCursor()
        print(buffer:sub(inputPos,-1),false)
        for i=1,buffer:len() do
          printBackspace()
        end
        buffer, inputPos = "", 1
        blink = true; checkCursor()
      elseif a == "escape" then
        local screenbk = screenshot()
        local oldx, oldy, oldbk = printCursor()
        editor:loop() cursor("none")
        printCursor(oldx,oldy,oldbk)
        palt(0,false) screenbk:image():draw(0,0) color(7) palt(0,true) flip()
        if ecommand then
          term.execute(split(ecommand))
          checkCursor() term.prompt() blink = true cursor("none")
          ecommand = false
        end
      elseif a == "up" then
        if not hispos then
          table.insert(history,buffer)
          hispos = #history
        end

        if hispos > 1 then
          hispos = hispos-1
          blink = false; checkCursor()
          print(buffer:sub(inputPos,-1),false)
          for i=1,buffer:len() do
            printBackspace()
          end
          buffer = history[hispos]
          inputPos = buffer:len() + 1
          for char in string.gmatch(buffer,".") do
            print(char,false)
          end
          blink = true; checkCursor()
        end
      elseif a == "down" then
        if hispos and hispos < #history then
          hispos = hispos+1
          blink = false; checkCursor()
          print(buffer:sub(inputPos,-1),false)
          for i=1,buffer:len() do
            printBackspace()
          end
          buffer = history[hispos]
          inputPos = buffer:len() + 1
          for char in string.gmatch(buffer,".") do
            print(char,false)
          end
          if hispos == #history then table.remove(history,#history) hispos = false end
          blink = true; checkCursor()
        end
      elseif a == "left" then
        blink = false; checkCursor()
        if inputPos > 1 then
          inputPos = inputPos - 1
          printBackspace(-1)
        end
        blink = true; checkCursor()
      elseif a == "right" then
        blink = false; checkCursor()
        if inputPos <= buffer:len() then
          print(buffer:sub(inputPos,inputPos),false)
          inputPos = inputPos + 1
        end
        blink = true; checkCursor()
      elseif a == "c" then
        if isKDown("lctrl","rctrl") then
          clipboard(buffer)
        end
      elseif a == "v" then
        if isKDown("lctrl","rctrl") then
          local paste = clipboard() or ""

          for char in string.gmatch(paste..buffer:sub(inputPos,-1),".") do
            print(char,false)
          end

          for i=inputPos,buffer:len() do printBackspace(-1) end

          buffer = buffer:sub(1,inputPos-1)..paste..buffer:sub(inputPos,-1)
          inputPos = inputPos + paste:len()
        end
      end
    elseif event == "touchpressed" then
      textinput(true)
    elseif event == "update" then
      btimer = btimer + a
      if btimer > btime then
        btimer = btimer%btime
        blink = not blink
      end
    end
  end
end

return term
