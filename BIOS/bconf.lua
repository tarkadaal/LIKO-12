--The bios configuration file.
--per ,err = P(peripheral,mountedName,configTable)

--Create a new cpu mounted as "CPU"
local CPU, yCPU, CPUKit = PA("CPU")

--Create a new gpu mounted as "GPU"
local GPU, yGPU, GPUKit = PA("GPU","GPU",{
  _ColorSet = { --The S64 Pallete
    {0,0,0,255}, --Black 1
    {26,67,214,255}, --Navy Blue 2
    {186,37,48,255}, --Dark Red 3
    {63,44,133,255}, --Dark Purple 4
    {143,109,76,255}, --Brown 5
    {24,158,143,255}, --Sea 6
    {143,128,109,255}, --Grey Brown 7
    {255,255,255,255}, --White 8
    {237,48,48,255}, --Cherry Red 9
    {251,144,4,255}, --Orange 10
    {240,180,0,255}, --Yellow 11
    {100,174,19,255}, --Green 12
    {25,204,233,255}, --Squla Blue 13
    {180,80,169,255}, --Purple 14
    {237,62,132,255}, --Magic Pink 15
    {121,214,246,255} --Pink 16
  },
  _ClearOnRender = true, --Speeds up rendering, but may cause glitches on some devices !
  CPUKit = CPUKit,
  title  = "SQULA-64"
})

local LIKO_W, LIKO_H = GPUKit._LIKO_W, GPUKit._LIKO_H
local ScreenSize = (LIKO_W/2)*LIKO_H

--Create Audio peripheral
PA("Audio")

--Create gamepad contols
PA("Gamepad","Gamepad",{CPUKit = CPUKit})

--Create Touch Controls
PA("TouchControls","TC",{CPUKit = CPUKit, GPUKit = GPUKit})

--Create a new keyboard api mounted as "KB"
PA("Keyboard","Keyboard",{CPUKit = CPUKit, GPUKit = GPUKit,_Android = (_OS == "Android"),_EXKB = false})

--Create a new virtual hdd system mounted as "HDD"
PA("HDD","HDD",{
  Drives = {
    C = 1024*1024 * 25, --Measured in bytes, equals 25 megabytes
    D = 1024*1024 * 25 --Measured in bytes, equals 25 megabytes
  }
})

local KB = function(v) return v*1024 end

local RAMConfig = {
  layout = {
    {ScreenSize,GPUKit.VRAMHandler}, --0x0 -> 0x2FFF - The Video ram
    {ScreenSize,GPUKit.LIMGHandler}, --0x3000 -> 0x5FFF - The Label image
    {KB(64)}  --0x6000 -> 0x15FFF - The floppy RAM
  }
}

local RAM, yRAM, RAMKit = PA("RAM","RAM",RAMConfig)

PA("FDD","FDD",{
  GPUKit = GPUKit,
  RAM = RAM,
  DiskSize = KB(64),
  FRAMAddress = 0x6000
})

local _, WEB, yWEB, WEBKit = P("WEB","WEB",{CPUKit = CPUKit})