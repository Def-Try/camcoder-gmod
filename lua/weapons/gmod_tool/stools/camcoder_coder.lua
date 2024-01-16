TOOL.Category = "Camcoder"
TOOL.Name = "#tool.camcoder_coder.name"

TOOL.Information = {
	{ name = "left_1", stage = 0, op = 0 },
	{ name = "left_1", stage = 0, op = 1 },	
	{ name = "left_2", stage = 1, op = 0 },	
	{ name = "right_1", stage = 0, op = 0 },
	{ name = "right_2", stage = 0, op = -1 },
	--{ name = "reload" }
}

TOOL.ClientConVar[ "countdowntime" ] = "5"
TOOL.ClientConVar[ "recordtime" ] = "5"
TOOL.ClientConVar[ "savepath" ] = "file"

local rname = "untitled.txt"

function TOOL:LeftClick( trace )
	if CLIENT then return end
	if self:GetStage() == 0 and self:GetOperation() == 0 then
		self:SetStage(1)
		self:__record_start()
		return false
	elseif self:GetStage() == 1 and self:GetOperation() == 0 then
		self:SetStage(0)
		self:__record_stop()
		return false
	end
	return false
end

local function confirm(message, yescallback, nocallback)
	local pw, ph = 160*2, 90*2

	local Frame = vgui.Create( "DFrame" )
	Frame:SetSize( pw, ph ) 
	Frame:SetTitle( "Camcoder - Confirmation" ) 
	Frame:SetVisible( true ) 
	Frame:SetDraggable( true ) 
	Frame:ShowCloseButton( false )
	Frame:Center()
	Frame:MakePopup()

	local Label = vgui.Create( "DLabel", Frame )
	Label:SetText( message )
	Label:SizeToContents()
	Label:Center()

	local CancelButton = vgui.Create( "DButton", Frame )
	CancelButton:SetPos(5, ph-50)
	CancelButton:SetSize(40, 40)
	CancelButton:SetText("   No   ")
	function CancelButton:DoClick()
		nocallback()
		self:GetParent():Close()
	end
	local ConfirmButton = vgui.Create( "DButton", Frame )
	ConfirmButton:SetSize(40, 40)
	ConfirmButton:SetText("   Yes   ")
	ConfirmButton:SetPos(pw-ConfirmButton:GetWide()-10, ph-50)
	function ConfirmButton:DoClick()
		yescallback()
		self:GetParent():Close()
	end
end

local function save(where, savecallback, nocallback)
	local pw, ph = 160*3, 90*3

	local Frame = vgui.Create( "DFrame" )
	Frame:SetSize( pw, ph ) 
	Frame:SetTitle( "Camcoder - Saving recording" ) 
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

	local DontSaveButton = vgui.Create( "DButton", Frame )
	DontSaveButton:SetPos(5, ph-25)
	DontSaveButton:SetTall(20)
	DontSaveButton:SetText(" Don't save ")
	DontSaveButton:SizeToContentsX()
	function DontSaveButton:DoClick()
		nocallback()
		self:GetParent():Close()
	end
	local SaveButton = vgui.Create( "DButton", Frame )
	SaveButton:SetTall(20)
	SaveButton:SetText(" Save ")
	SaveButton:SizeToContentsX()
	SaveButton:SetPos(pw-SaveButton:GetWide()-5, ph-25)
	local NameEntry = vgui.Create( "DTextEntry", Frame )
	NameEntry:SetPos( 5+DontSaveButton:GetWide(), ph-25 )
	NameEntry:SetSize( pw-10-SaveButton:GetWide()-DontSaveButton:GetWide(), 20 )
	NameEntry:SetText( rname )
	function browser:OnSelect( path, pnl )
		NameEntry:SetText(string.Explode("/", path)[#string.Explode("/", path)])
	end
	function SaveButton:DoClick()
		savecallback(NameEntry:GetValue())
		self:GetParent():Close()
	end
end

function TOOL:RightClick( trace )
	if CLIENT then return end
	if self:GetStage() == 0 and self:GetOperation() == 0 then
		self:SetOperation(-1)
		timer.Simple(math.max(0, self:GetClientNumber("countdowntime")), function()
			if self:GetOwner():GetActiveWeapon():GetClass() ~= "gmod_tool" and self:GetMode() ~= "camcoder_coder" then
				if self.data[2] ~= -1 then return end
			else
				if self:GetOperation() ~= -1 then return end
			end
			if self:GetOwner():GetActiveWeapon():GetClass() == "gmod_tool" and self:GetMode() == "camcoder_coder" then
				self:SetStage(1)
				self:SetOperation(0)
			else
				self.data = {1, 0}
			end
			self:__record_start(trace)
		end)
		for i=0,math.max(0,self:GetClientNumber("countdowntime")-1),1 do
			timer.Simple(i, function()
				if self:GetOwner():GetActiveWeapon():GetClass() ~= "gmod_tool" and self:GetMode() ~= "camcoder_coder" then
					if self.data[2] ~= -1 then return end
				else
					if self:GetOperation() ~= -1 then return end
				end
				self.SWEP:EmitSound("UI/buttonrollover.wav")
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
	return false
end

function TOOL:Holster()
	self.data = {self:GetStage(), self:GetOperation()}
end
function TOOL:Deploy()
	if not self.data then self.data = {0,0} end
	self:SetStage(self.data[1])
	self:SetOperation(self.data[2])
	if CLIENT then return end
	if (CurTime() - self:GetWeapon():GetNWFloat("record_start_time")) >= self:GetClientNumber("recordtime") and self:GetClientNumber("recordtime") ~= 0 then
		self:SetStage(0)
	end
end

function TOOL:__record_start()
	self:GetWeapon():SetNWFloat("record_start_time", CurTime())
	self.SWEP:EmitSound("UI/buttonclick.wav")
	self.codingid = math.random(10000, 99999)
	local nply = self:GetOwner()
	self.movdatas = {
		{type="base", data={
			origin=nply:GetPos(),
			vel=nply:GetVelocity(),
			angles=nply:GetAngles(),
			pm=nply:GetInfo("cl_playermodel"),
			eangles=nply:EyeAngles(),
			weapon=nply:GetActiveWeapon():GetClass(),
			wcl = nply:GetWeaponColor(),
			pcl = nply:GetPlayerColor(),
			skin = nply:GetInfoNum("cl_playerskin", 0),
			body = nply:GetInfo("cl_playerbodygroups") or ""
			}
		}
	}
	hook.Add("StartCommand", "CAMCODER_rec_"..self.codingid, function(ply, cmd)
		if ply ~= nply then return end
		local wepdata = {nply:GetActiveWeapon():GetClass(), nply:GetActiveWeapon():GetPrimaryAmmoType(), nply:GetActiveWeapon():GetSecondaryAmmoType(), nply:GetAmmoCount(nply:GetActiveWeapon():GetPrimaryAmmoType()), nply:GetAmmoCount(nply:GetActiveWeapon():GetSecondaryAmmoType())}
		if #self.movdatas > 2 and self.movdatas[#self.movdatas].data.wep[1] == nply:GetActiveWeapon():GetClass() then wepdata[4] = 0 wepdata[5] = 0 end
		self.movdatas[#self.movdatas+1] = {type="key", data={
			mv={cmd:GetForwardMove(), cmd:GetSideMove(), cmd:GetUpMove()},
			msp={cmd:GetMouseX(), cmd:GetMouseY(), cmd:GetMouseWheel()},
			bts={cmd:GetButtons()},
			ang={cmd:GetViewAngles(), nply:GetAngles(), nply:EyeAngles()},
			imp=cmd:GetImpulse(),
			wep=wepdata,
			pos=nply:GetPos()
		}}
		if (CurTime() - self:GetWeapon():GetNWFloat("record_start_time")) >= self:GetClientNumber("recordtime") and self:GetClientNumber("recordtime") ~= 0 then
			self:SetStage(0)
			self:__record_stop()
		end
	end)
end
if SERVER then
	util.AddNetworkString("camcoder_saving")
	util.AddNetworkString("camcoder_saving_confirm")
	util.AddNetworkString("camcoder_saving_cancel")
end

function TOOL:__record_stop()
	if IsValid(self) and IsValid(self.SWEP) then
		self.SWEP:EmitSound("UI/buttonclickrelease.wav")
	end
	self:SetOperation(1)
	if SERVER then
		hook.Remove("StartCommand", "CAMCODER_rec_"..self.codingid)
		net.Start("camcoder_saving")
		net.Send(self:GetOwner())
		self.donemovdatas = self.movdatas

		local function savedata(fname)
			local f = file.Open("camcoder/recordings/"..fname, "w", "DATA")
			if not f then
				error("Failed while opening CCcamcoder_REC file")
				return
			end
			for k, md in pairs(self.donemovdatas) do
				f:Write(k.." "..md.type.." ")
				if md.type == "base" then
					f:Write(md.data.pm)
					f:Write(";")
					f:Write(md.data.weapon)
					f:Write(";")
					f:Write(md.data.origin.x)
					f:Write(" ")
					f:Write(md.data.origin.y)
					f:Write(" ")
					f:Write(md.data.origin.z)
					f:Write(";")
					f:Write(md.data.angles.p)
					f:Write(" ")
					f:Write(md.data.angles.y)
					f:Write(" ")
					f:Write(md.data.angles.r)
					f:Write(";")
					f:Write(md.data.eangles.p)
					f:Write(" ")
					f:Write(md.data.eangles.y)
					f:Write(" ")
					f:Write(md.data.eangles.r)
					f:Write(";")
					f:Write(md.data.pcl.x)
					f:Write(" ")
					f:Write(md.data.pcl.y)
					f:Write(" ")
					f:Write(md.data.pcl.z)
					f:Write(";")
					f:Write(md.data.wcl.x)
					f:Write(" ")
					f:Write(md.data.wcl.y)
					f:Write(" ")
					f:Write(md.data.wcl.z)
					f:Write(";")
					f:Write(md.data.vel.x)
					f:Write(" ")
					f:Write(md.data.vel.y)
					f:Write(" ")
					f:Write(md.data.vel.z)
					f:Write(";")
					f:Write(md.data.skin)
					f:Write(";")
					f:Write(md.data.body)
					f:Write("\n")
					continue
				end
				f:Write(md.data.mv[1].." "..md.data.mv[2].." "..md.data.mv[3])
				f:Write(";")
				f:Write(md.data.msp[1].." "..md.data.msp[2].." "..md.data.msp[3])
				f:Write(";")
				f:Write(md.data.bts[1])
				f:Write(";")
				f:Write(md.data.ang[1].p.." "..md.data.ang[1].y.." "..md.data.ang[1].r)
				f:Write(";")
				f:Write(md.data.ang[2].p.." "..md.data.ang[2].y.." "..md.data.ang[2].r)
				f:Write(";")
				f:Write(md.data.ang[3].p.." "..md.data.ang[3].y.." "..md.data.ang[3].r)
				f:Write(";")
				f:Write(md.data.wep[1])
				f:Write(";")
				f:Write(md.data.wep[2])
				f:Write(";")
				f:Write(md.data.wep[3])
				f:Write(";")
				f:Write(md.data.wep[4])
				f:Write(";")
				f:Write(md.data.wep[5])
				f:Write(";")
				f:Write(md.data.imp)
				f:Write(";")
				f:Write(md.data.pos[1].." "..md.data.pos[2].." "..md.data.pos[3])
				f:Write("\n")
			end
			f:Close()
		end

		net.Receive("camcoder_saving", function(ply)
			local fname = net.ReadString()
			if file.Exists("camcoder/recordings/"..fname, "DATA") then
				net.Start("camcoder_saving_confirm")
				net.Send(self:GetOwner())
				self:SetOperation(1)
				self.pendingname = fname
				return
			end
			self:SetOperation(0)
			savedata(fname)
		end)
		net.Receive("camcoder_saving_confirm", function(ply)
			self:SetOperation(0)
			savedata(self.pendingname)
		end)
		net.Receive("camcoder_saving_cancel", function(ply)
			self:SetOperation(0)
		end)
		return
	end
	local function scb(fname)
		net.Start("camcoder_saving")
		net.WriteString(fname)
		net.SendToServer()
	end
	save("data/camcoder/recordings", scb, function() net.Start("camcoder_saving_cancel") net.SendToServer() end)
end

function TOOL.BuildCPanel( CPanel )
	CPanel:SetName("#tool.camcoder_coder.name")
	CPanel:NumberWang("#tool.camcoder_coder.countdowntime", "camcoder_coder_countdowntime", 0, 60)
	CPanel:Help("#tool.camcoder_coder.countdowntime.help")
	CPanel:NumberWang("#tool.camcoder_coder.recordtime", "camcoder_coder_recordtime", 0, 2^32-1)
	CPanel:Help("#tool.camcoder_coder.recordtime.help")
end

if CLIENT then
	surface.CreateFont( "camcoder_REC", {
		font = "Arial",
		extended = false,
		size = 50,
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
	local txt = "IDL"
	local ftime = "0:00:00:00.000"
	local ftimes = "0:00:00:00.000"
	local ftimecol = Color(255, 255, 255)
	local col = Color(55,55,55,((math.sin(RealTime())+1)/2*127+127))

	local mod, floor = math.mod, math.floor
	local rtime = self:GetClientNumber("recordtime")
	local days = floor(rtime/86400)
	local hours = floor(mod(rtime, 86400)/3600)
	local minutes = floor(mod(rtime,3600)/60)
	local seconds = floor(mod(rtime,60))
	local microseconds = floor(mod(rtime*1000,1000))
	ftimes = string.format("%d:%02d:%02d:%02d.%03d",days,hours,minutes,seconds,microseconds)

	local op, stage = self.SWEP:GetNWInt("Op", 0), self.SWEP:GetNWInt("Stage", 0)
	local isontool = true
	if self:GetOwner():GetActiveWeapon():GetClass() ~= "gmod_tool" and self:GetMode() ~= "camcoder_coder" then
		if not self.data then self.data = {0,0} end
		stage, op = self.data[1], self.data[2]
		isontool = false
	end

	if op == 1 then
		col = Color(0,127,255,((math.sin(RealTime()*2)+1)/2*127+127))
		txt = "SAV"
		local days = floor(self.rec_time/86400)
		local hours = floor(mod(self.rec_time, 86400)/3600)
		local minutes = floor(mod(self.rec_time,3600)/60)
		local seconds = floor(mod(self.rec_time,60))
		local microseconds = floor(mod(self.rec_time*1000,1000))
		ftime = string.format("%d:%02d:%02d:%02d.%03d",days,hours,minutes,seconds,microseconds)
		ftimecol = Color(255,255,255,255*math.abs(math.Round((math.sin(RealTime()*2)+1)/2)))
	elseif stage == 1 then
		if self:GetWeapon():GetNWFloat("record_start_time") then 
			self.rec_time = CurTime() - self:GetWeapon():GetNWFloat("record_start_time")
			local days = floor(self.rec_time/86400)
			local hours = floor(mod(self.rec_time, 86400)/3600)
			local minutes = floor(mod(self.rec_time,3600)/60)
			local seconds = floor(mod(self.rec_time,60))
			local microseconds = floor(mod(self.rec_time*1000,1000))
			ftime = string.format("%d:%02d:%02d:%02d.%03d",days,hours,minutes,seconds,microseconds)
		end
		col = Color(255,0,0,255*math.abs(math.Round((math.sin(RealTime()*2)+1)/2)))
		txt = "REC"
	end

	if txt == "IDL" and not isontool then return end
	draw.RoundedBox(10, ScrW()-160, 10, 150, 50, Color(55,55,55,((math.sin(RealTime()*2)+1)/2*63+127)))
	draw.RoundedBox(10, ScrW()-160, 70, 150, 25, Color(55,55,55,((math.sin(RealTime()*2)+1)/2*63+127)))
	draw.RoundedBox(10, ScrW()-160, 100, 150, 25, Color(55,55,55,((math.sin(RealTime()*2)+1)/2*63+127)))
	draw.RoundedBox(10, ScrW()-150, 20, 30, 30, col)
	draw.DrawText(txt, "camcoder_REC", ScrW()-110, 10, Color(255,255,255), TEXT_ALIGN_LEFT)
	draw.DrawText(ftime, "DermaDefault", ScrW()-85, 75, ftimecol, TEXT_ALIGN_CENTER)
	draw.DrawText(ftimes, "DermaDefault", ScrW()-85, 105, ftimecol, TEXT_ALIGN_CENTER)
end

function TOOL:__init()
	net.Receive("camcoder_saving", function()
		self:__record_stop()
	end)
	net.Receive("camcoder_saving_confirm", function()
		self:SetOperation(1)
		confirm("This file already exists. Overwrite?", function()
			net.Start("camcoder_saving_confirm")
			net.SendToServer()
		end, function()
			net.Start("camcoder_saving_cancel")
			net.SendToServer()
		end)
	end)
end

TOOL:__init()