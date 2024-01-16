TOOL.Category = "Camcoder"
TOOL.Name = "#tool.camcoder_player.name"

TOOL.Information = {
	{ name = "left_1", stage = 0, op = 0 },	
	{ name = "left_2", stage = 1, op = 0 },	
	{ name = "right_1", stage = 0, op = 0 },
	{ name = "right_2", stage = 0, op = -1 },
	{ name = "reload", stage = 0, op = 0}
}

TOOL.ClientConVar[ "countdowntime" ] = "0"
TOOL.ClientConVar[ "loadpaths" ] = "file"

local rname = "untitled.txt"

local function open(where, opencallback, nocallback)
	local pw, ph = 160*3, 90*3

	local Frame = vgui.Create( "DFrame" )
	Frame:SetSize( pw, ph ) 
	Frame:SetTitle( "Camcoder - Opening recording" ) 
	Frame:SetVisible( true ) 
	Frame:SetDraggable( true ) 
	Frame:ShowCloseButton( false )
	Frame:Center()
	Frame:MakePopup()

	local browser = vgui.Create( "DFileBrowser", Frame )
	browser:SetSize( pw-10, ph-50 )
	browser:SetPos( 5, 25 )
	browser:SetPath( "GAME" )
	file.CreateDir("camcoder/recordings")
	browser:SetBaseFolder( "data/camcoder/recordings" )
	browser:SetOpen( true )
	browser:SetCurrentFolder( "" )

	local DontOpenButton = vgui.Create( "DButton", Frame )
	DontOpenButton:SetPos(5, ph-25)
	DontOpenButton:SetTall(20)
	DontOpenButton:SetText(" Done ")
	DontOpenButton:SizeToContentsX()
	function DontOpenButton:DoClick()
		nocallback()
		self:GetParent():Close()
	end
	local OpenButton = vgui.Create( "DButton", Frame )
	OpenButton:SetTall(20)
	OpenButton:SetText(" Open ")
	OpenButton:SizeToContentsX()
	OpenButton:SetPos(pw-OpenButton:GetWide()-5, ph-25)
	local NameEntry = vgui.Create( "DTextEntry", Frame )
	NameEntry:SetPos( 5+DontOpenButton:GetWide(), ph-25 )
	NameEntry:SetSize( pw-10-OpenButton:GetWide()-DontOpenButton:GetWide(), 20 )
	NameEntry:SetText( rname )
	function browser:OnSelect( path, pnl )
		NameEntry:SetText(string.Explode("/", path)[#string.Explode("/", path)])
	end
	function OpenButton:DoClick()
		opencallback(NameEntry:GetValue())
		self:GetParent():Close()
	end
end

function TOOL:LeftClick( trace )
	if CLIENT then return end
	if self:GetStage() == 0 and self:GetOperation() == 0 then
		self:__replay_start(trace)
		return false
	elseif self:GetStage() == 1 and self:GetOperation() == 0 then
		self:__replay_stop()
		return false
	end
	return false
end

function TOOL:RightClick( trace )
	if CLIENT then return end
	if self:GetStage() == 0 and self:GetOperation() == 0 then
		self:SetOperation(-1)
		timer.Simple(math.max(0, self:GetClientNumber("countdowntime")), function()
			if self:GetOwner():GetActiveWeapon():GetClass() == "gmod_tool" and self:GetMode() == "camcoder_player" then
				if self:GetOperation() ~= -1 then return end
			else
				if self.data[2] ~= -1 then return end
			end
			self:__replay_start(trace)
		end)
		for i=0,math.max(0,self:GetClientNumber("countdowntime")-1),1 do
			timer.Simple(i, function()
				if self:GetOwner():GetActiveWeapon():GetClass() == "gmod_tool" and self:GetMode() == "camcoder_player" then
					if self:GetOperation() ~= -1 then return end
				else
					if self.data[2] ~= -1 then return end
				end
				if IsValid(self.SWEP) then
					self.SWEP:EmitSound("UI/buttonrollover.wav")
				end
			end)
		end
		return false
	end
	if self:GetStage() == 0 and self:GetOperation() == -1 then
		self:SetOperation(0)
		return false
	end
	return false
end

function TOOL:Reload( trace )
	if SERVER then return end
	function table_contains(table, element)
		for _, value in pairs(table) do
			if value == element then return true end
		end
		return false
	end
	local files = ""
	local lps = GetConVar( "camcoder_player_loadpaths" )
	lps:SetString(files)
	if self.loadedfiles ~= nil and #self.loadedfiles > 0 then
		for _,f in pairs(self.loadedfiles) do
			f:Close()
		end
	end
	self.loadedfiles = {}
	local work = true
	local function opnf()
		open("data/camcoder/recordings", function(fname)
			if files ~= "" and not table_contains(string.Explode(";", files), fname) then
				files = files..";"..fname
			else
				files = fname
			end
			lps:SetString(files)
			opnf()
		end, function()
			for _,f in pairs(self.loadedfiles) do
				f:Close()
			end
			self.loadedfiles = {}
		end)
	end
	opnf()
	return false
end

function TOOL:__replay_start(tr)
	if game.SinglePlayer() then
		self:__replay_stop()
		error("Can not use player in singleplayer as it uses bots.")
		return
	end
	if self and IsValid(self.SWEP) then
		self.SWEP:EmitSound("UI/buttonclick.wav")
	end
	if CLIENT then return end
	if self then
		if self:GetOwner():GetActiveWeapon():GetClass() == "gmod_tool" and self:GetMode() == "camcoder_player" then
			self:SetStage(1)
			self:SetOperation(0)
		else
			self.data = {1, 0}
		end
	end
	if not self.ents then self.ents = {} end
	if GetConVar( "camcoder_player_loadpaths" ):GetString() == "" then self:__replay_stop() return end
	for _,lp in pairs(string.Explode(";", self:GetClientInfo("loadpaths"))) do
		local ent = player.CreateNextBot("HelperBot "..math.random(10000,99999))
		if not ent then
			self:__replay_stop(1)
			error("Unable to spawn player representation. Do you have enough free player slots?")
			return
		end
		self.ents[#self.ents+1] = ent
		local f = file.Open("camcoder/recordings/"..lp, "r", "DATA")
		if not f then
			self:__replay_stop(1)
			error("Failed while opening CCREC file")
			return
		end
		local baseline = f:ReadLine()
		if baseline:sub(1,7) ~= "1 base " then
			self:__replay_stop(1)
			error("Invalid CCREC file start")
			return
		end
		baseline = baseline:sub(8)
		local params = {}
		for param in string.gmatch(baseline, '([^;]+)') do
		    params[#params+1] = param
		end
		ent:SetPos(Vector(params[3]))
		ent:SetVelocity(Vector(params[8]))
		ent:SetAngles(Angle(params[4]))
		ent:SetEyeAngles(Angle(params[5]))
		ent:SetPlayerColor(Vector(params[6]))
		ent:SetWeaponColor(Vector(params[7]))
		ent:StripWeapons()
		ent:StripAmmo()
		ent:SetModel(player_manager.TranslatePlayerModel(params[1]))
		ent:SetSkin(tonumber(params[9]))
		local groups = string.Explode(" ", params[10])
		for k = 0, ent:GetNumBodyGroups() - 1 do
			local v = tonumber(groups[k + 1]) or 0
			ent:SetBodygroup(k, v)
		end
		local bparams = params
		local tick = 0
		hook.Add("PlayerDeath", ent:Name(), function(ply)
			if not IsValid(ply) and not IsValid(ent) then return end
			if not ply:IsBot() or ply:Name() ~= ent:Name() then return end
			if self:__kill_bot(ent, "Bot died") then
				timer.Simple(0, function() self:__replay_stop() end)
			end
		end)
		hook.Add("PlayerSilentDeath", ent:Name(), function(ply)
			if not IsValid(ply) and not IsValid(ent) then return end
			if not ply:IsBot() or ply:Name() ~= ent:Name() then return end
			if self:__kill_bot(ent, "Bot died") then
				timer.Simple(0, function() self:__replay_stop() end)
			end
		end)
		hook.Add("StartCommand", ent:Name(), function(ply, cmd)
			if IsValid(ply) and IsValid(ent) and (not ply:IsBot() or ply:Name() ~= ent:Name()) then return end
			tick = tick + 1
			local params = {}
			local nextt = f:ReadLine()
			if nextt == nil then
				if self:__kill_bot(ent, "Replay stop") then
					timer.Simple(0, function() self:__replay_stop() end)
				end
				return
			end
			nextt = nextt:sub(#tostring(tick)+6)
			for param in string.gmatch(nextt, '([^;]+)') do
				params[#params+1] = param
			end
			cmd:ClearMovement() 
			cmd:ClearButtons()
			local tparams = {}
			for param in string.gmatch(params[1], '([^%s]+)') do
				tparams[#tparams+1] = param
			end
			cmd:SetForwardMove(tonumber(tparams[1]))
			cmd:SetSideMove(tonumber(tparams[2]))
			cmd:SetUpMove(tonumber(tparams[3]))
			local tparams = {}
			for param in string.gmatch(params[2], '([^%s]+)') do
				tparams[#tparams+1] = param
			end
			cmd:SetMouseX(tonumber(tparams[1]))
			cmd:SetMouseY(tonumber(tparams[2]))
			cmd:SetButtons(tonumber(params[3]))
			cmd:SetViewAngles(Angle(params[4]))
			ent:SetAngles(Angle(params[5]))
			ent:SetEyeAngles(Angle(params[6]))
			ent:Give(params[7])
			ent:GiveAmmo(params[8], params[10])
			ent:GiveAmmo(params[9], params[11])
			cmd:SelectWeapon(ply:GetWeapon(params[7]))
			cmd:SetImpulse(params[12])
			--cmd:SetButtons( IN_ATTACK )
			--cmd:SetForwardMove( ply:GetWalkSpeed() )
		end)
	end
end

function TOOL:__kill_bot(bot, reason)
	if not IsValid(bot) then return end
	hook.Remove("StartCommand", bot:Name())
	hook.Remove("PlayerDeath", bot:Name())
	hook.Remove("PlayerSilentDeath", bot:Name())
	bot:Kick(reason)
	shouldstop = 2
	for _,ent in pairs(self.ents) do
		shouldstop = shouldstop - (IsValid(ent) and 1 or 0)
	end
	return shouldstop == 1
end

function TOOL:__replay_stop(failed)
	if self and IsValid(self.SWEP) then
		self.SWEP:EmitSound("UI/buttonclickrelease.wav")
	end
	if CLIENT then return end
	if self then
		if self:GetOwner():GetActiveWeapon():GetClass() == "gmod_tool" and self:GetMode() == "camcoder_player" then
			self:SetStage(0)
			self:SetOperation(0)
		else
			self.data = {0, 0}
		end
	end
	local reason = "Replay stop"
	if failed then
		reason = "Failed while starting replay"
	end
	if not self.ents then self.ents = {} end
	for _,ent in pairs(self.ents) do
		self:__kill_bot(ent, reason)
	end
	self.ents = {}
end

function TOOL:Holster()
	self.data = {self:GetStage(), self:GetOperation()}
	if SERVER then return end
	if self.loadedfiles ~= nil and #self.loadedfiles > 0 then
		for _,f in pairs(self.loadedfiles) do
			f:Close()
		end
	end
	self.loadedfiles = {}
	if not self.GhostEntities then self.GhostEntities = {} end
	for _, ge in pairs(self.GhostEntities) do
		if IsValid(ge) then ge:Remove() end
	end
	self.GhostEntities = {}
end
function TOOL:Deploy()
	if not self.data then self.data = {0,0} end
	self:SetStage(self.data[1])
	self:SetOperation(self.data[2])
	self:Think()
end
function TOOL:Think()
	if SERVER then
		if self:GetStage() == 0 and self:GetOperation() == 0 then return end
		shouldstop = 0
		for _,ent in pairs(self.ents) do
			shouldstop = shouldstop + (not IsValid(ent) and 1 or 0)
		end
		if shouldstop == #self.ents then self:__replay_stop() end
		return
	end
	if not self.GhostEntities then self.GhostEntities = {} end
	for _, ge in pairs(self.GhostEntities) do
		if IsValid(ge) then ge:Remove() end
	end
	self.GhostEntities = {}
	if GetConVar( "camcoder_player_loadpaths" ):GetString() == "" then return end
	if self.loadedfiles == nil or #self.loadedfiles == 0 then
		self.loadedfiles = {}
		self.previewdata = {}
		for _,lp in pairs(string.Explode(";", self:GetClientInfo("loadpaths"))) do
			local f = file.Open("camcoder/recordings/"..lp, "r", "DATA")
			if not f then
				continue
			end
			self.loadedfiles[#self.loadedfiles+1] = f
			local bl = f:ReadLine()
			bl = bl:sub(8)
			local params = {}
			for param in string.gmatch(bl, '([^;]+)') do
			    params[#params+1] = param
			end
			self.previewdata[#self.previewdata+1] = {
				{
					Vector(params[3]),
					Angle(0, tonumber(string.Explode(" ", params[4])[2]), 0)
				}, {
					Vector(params[3]),
					Angle(tonumber(string.Explode(" ", params[4])[1]),
					tonumber(string.Explode(" ", params[4])[2]),
					tonumber(string.Explode(" ", params[4])[3]))
				}, {
					Vector(params[3]),
					Angle(90, tonumber(string.Explode(" ", params[4])[2]), 0),
					Angle(0, tonumber(string.Explode(" ", params[4])[2]), 0)
				}, {
					2
				}
			}
		end
	end
	for i,f in pairs(self.loadedfiles) do
		local ld = self.previewdata[i]
		if self:GetOwner():GetActiveWeapon():GetClass() == "gmod_tool" and self:GetMode() == "camcoder_player" then
			if self:GetStage() == 1 then return end
		else
			if self.data[1] == 1 then return end
		end
		self.GhostEntities[#self.GhostEntities+1] = ents.CreateClientProp("models/editor/playerstart.mdl")
		local ge0id = #self.GhostEntities
		self.GhostEntities[#self.GhostEntities+1] = ents.CreateClientProp("models/editor/camera.mdl")
		local ge1id = #self.GhostEntities
		self.GhostEntities[#self.GhostEntities+1] = ents.CreateClientProp("models/weapons/w_toolgun.mdl")
		local ge2id = #self.GhostEntities

		local offvec = Vector()
		if math.random(0,100) > 99 then
			offvec = VectorRand(-100, 100)
		end
		local ge = self.GhostEntities[ge0id]
			ge:SetPos(ld[1][1] + offvec)
			ge:SetAngles(ld[1][2])
			ge:PhysicsDestroy()
			ge:SetMoveType(MOVETYPE_NONE)
			ge:SetNotSolid(true)
			ge:SetRenderMode(RENDERMODE_TRANSCOLOR)
			ge:SetColor(Color(255, 255, 255, math.random(130,170)))
		local ge = self.GhostEntities[ge1id]
			ge:SetPos(ld[2][1]+offvec+Vector(0,0,65))
			ge:SetAngles(ld[2][2])
			ge:PhysicsDestroy()
			ge:SetMoveType(MOVETYPE_NONE)
			ge:SetNotSolid(true)
			ge:SetRenderMode(RENDERMODE_TRANSCOLOR)
			ge:SetColor(Color(255, 255, 255, math.random(130,170)))
		local ge = self.GhostEntities[ge2id]
			local rv = Vector(1, -10, 0)
			rv:Rotate(ld[3][3])
			ge:SetPos(ld[3][1]+offvec+Vector(0,0,32) + rv)
			ge:SetAngles(ld[3][2])
			ge:PhysicsDestroy()
			ge:SetMoveType(MOVETYPE_NONE)
			ge:SetNotSolid(true)
			ge:SetRenderMode(RENDERMODE_TRANSCOLOR)
			ge:SetColor(Color(255, 255, 255, math.random(130,170)))
		local spos = (ld[4][2] or ld[1][1])
		local tick = ld[4][1] or 2
		local nextt = f:ReadLine()
		if nextt == nil then
			ld[4][1] = 2
			f:Seek(0)
			f:ReadLine()
			continue
		end
		nextt = nextt:sub(#tostring(tick)+6)
		tick = tick + 1
		params = {}
		for param in string.gmatch(nextt, '([^;]+)') do
			params[#params+1] = param
		end
		ld[4][1] = tick
		local ge = ents.CreateClientProp("models/editor/playerstart.mdl")
		ge:SetPos(Vector(params[13]))
		ge:SetAngles(Angle(0, tonumber(string.Explode(" ", params[4])[2]), 0))
		ge:PhysicsDestroy()
		ge:SetMoveType(MOVETYPE_NONE)
		ge:SetNotSolid(true)
		ge:SetRenderMode(RENDERMODE_TRANSCOLOR)
		ge:SetColor(Color(255, 255, 255, math.random(130,170)))
		self.GhostEntities[#self.GhostEntities+1] = ge
		local ge = ents.CreateClientProp("models/editor/camera.mdl")
		ge:SetPos(Vector(params[13]) + Vector(0, 0, 65))
		ge:SetAngles(Angle(params[6]))
		ge:PhysicsDestroy()
		ge:SetMoveType(MOVETYPE_NONE)
		ge:SetNotSolid(true)
		ge:SetRenderMode(RENDERMODE_TRANSCOLOR)
		ge:SetColor(Color(255, 255, 255, math.random(130,170)))
		self.GhostEntities[#self.GhostEntities+1] = ge
	end
end

if CLIENT then
	surface.CreateFont( "camcoder_LFs", {
		font = "Arial",
		extended = false,
		size = 20,
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		underline = false,
		italic = false,
		strikeout = false,
		symbol = false,
		rotary = false,
		shadow = false,
		additive = false,
		outline = false,
	} )
end
function TOOL:DrawHUD()
	local lf = ""
	for _,f in pairs(string.Explode(";", self:GetClientInfo("loadpaths"))) do
		lf = lf.."  "..f.."\n"
	end
	if lf == "  \n" then
		lf = "<no files loaded...>\n"
	end
	surface.SetFont("camcoder_LFs")
	local w, h = surface.GetTextSize("Loaded files:\n"..lf)
	draw.RoundedBox(10, ScrW()-w-30, 10, w+20, h, Color(55,55,55,((math.sin(RealTime()*2)+1)/2*63+127)))
	draw.DrawText("Loaded files:\n"..lf, "camcoder_LFs", ScrW()-20, 20, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
end

function TOOL.BuildCPanel( CPanel )
	CPanel:SetName("#tool.camcoder_player.name")
	CPanel:NumberWang("#tool.camcoder_player.countdowntime", "camcoder_player_countdowntime", 0, 60)
	CPanel:Help("#tool.camcoder_player.countdowntime.help")
end

