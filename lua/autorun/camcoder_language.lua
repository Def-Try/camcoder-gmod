if SERVER then return end

local lang = GetConVar("gmod_language"):GetString()
local strings

local fileName = "camcoder_lang_"..lang..".lua" -- Replace with the name of the Lua file you want to check
local filePath = "lua/autorun/" .. fileName -- Construct the path to the file

if file.Exists(filePath, "GAME") then
  strings = include("camcoder_lang_"..lang..".lua")
else
  strings = include("camcoder_lang_en.lua")
end

for k,v in pairs(strings) do
	language.Add(k, v)
end
