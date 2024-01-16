TOOL.Category = "Camcoder"
TOOL.Name = "#tool.camcoder_manager.name"

TOOL.Information = {
	{ name = "left" }
}

if SERVER then
	util.AddNetworkString("camcoder_delete_recording")
	util.AddNetworkString("camcoder_rename_recording")
	net.Receive("camcoder_delete_recording", function()
		file.Delete(net.ReadString())
	end)
	net.Receive("camcoder_rename_recording", function()
		file.Rename(net.ReadString(), net.ReadString())
	end)
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

function TOOL:LeftClick( trace )
	if SERVER then return true end
	local pw = ScrW() / 1.25
	local ph = ScrH() / 1.25
	local lpath = ""
	local Frame = vgui.Create( "DFrame" )
	Frame:SetSize( pw, ph ) 
	Frame:SetTitle( "Camcoder manager" ) 
	Frame:SetVisible( true ) 
	Frame:SetDraggable( true ) 
	Frame:ShowCloseButton( true )
	Frame:Center()
	Frame:MakePopup()

	local browser = vgui.Create( "DFileBrowser", Frame )
	browser:SetSize( pw/5-10, ph-30 )
	browser:SetPos( 5, 25 )
	browser:SetPath( "GAME" )
	file.CreateDir("camcoder/recordings")
	browser:SetBaseFolder( "data/camcoder/recordings" )
	browser:SetOpen( true )
	browser:SetCurrentFolder( "" )

	local model = vgui.Create( "DModelPanel", Frame )
	model:SetSize( pw/3, pw/3 )
	model:SetPos( pw/5, 25 )
	model:SetModel( "error" )
	model:GetEntity():SetAngles( Angle() )

	local DeleteButton = vgui.Create( "DButton", Frame )
	DeleteButton:SetPos(pw/5, pw/3+30)
	DeleteButton:SetTall(20)
	DeleteButton:SetText(" Delete ")
	DeleteButton:SizeToContentsX()
	DeleteButton:SetEnabled(false)
	function DeleteButton:DoClick()
		confirm("Are you sure?", function()
			net.Start("camcoder_delete_recording")
				net.WriteString(lpath)
			net.SendToServer()
			file.Delete(lpath)
			browser:Setup()
			model:SetModel( "error" )
			Frame:SetTitle( "Camcoder manager" ) 
		end,  function() end)
	end

	local RenameButton = vgui.Create( "DButton", Frame )
	RenameButton:SetPos(pw/5+5+DeleteButton:GetWide(), pw/3+30)
	RenameButton:SetTall(20)
	RenameButton:SetText(" Rename ")
	RenameButton:SizeToContentsX()
	RenameButton:SetEnabled(false)
	function RenameButton:DoClick()
		local pw, ph = 160*2, 90*2

		local RFrame = vgui.Create( "DFrame" )
		RFrame:SetSize( pw, ph ) 
		RFrame:SetTitle( "Camcoder - Renaming "..string.Explode("/", lpath)[#string.Explode("/", lpath)] ) 
		RFrame:SetVisible( true ) 
		RFrame:SetDraggable( true ) 
		RFrame:ShowCloseButton( false )
		RFrame:Center()
		RFrame:MakePopup()

		local Label = vgui.Create( "DLabel", RFrame )
		Label:SetText( "Rename "..string.Explode("/", lpath)[#string.Explode("/", lpath)] )
		Label:SizeToContents()
		Label:Dock( TOP )

		local TargetName = vgui.Create( "DTextEntry", RFrame )
		TargetName:Dock( TOP )

		local CancelButton = vgui.Create( "DButton", RFrame )
		CancelButton:SetPos(5, ph-50)
		CancelButton:SetSize(40, 40)
		CancelButton:SetText("Cancel")
		function CancelButton:DoClick()
			self:GetParent():Close()
		end
		local ConfirmButton = vgui.Create( "DButton", RFrame )
		ConfirmButton:SetSize(40, 40)
		ConfirmButton:SetText("OK")
		ConfirmButton:SetPos(pw-ConfirmButton:GetWide()-10, ph-50)
		function ConfirmButton:DoClick()
			local tp = "camcoder/recordings/"..TargetName:GetValue()
			confirm("Are you sure?", function()
				net.Start("camcoder_rename_recording")
					net.WriteString(lpath)
					net.WriteString(tp)
				net.SendToServer()
				file.Rename(lpath, tp)
				browser:Setup()
				browser:OnSelect(tp)
			end,  function() end)
			self:GetParent():Close()
		end
	end

	function model:LayoutEntity( ent )
		ent:SetAngles( ent:GetAngles() + Angle(0,5*FrameTime(),0) )
	end

	function model:Paint( w, h )
		draw.RoundedBox(0, 0, 0, w, h, Color(63, 63, 63, 255))
		draw.SimpleText(self:GetEntity():GetModel(), "DermaDefault", 0, 0)
		if ( !IsValid( self.Entity ) ) then return end
		local x, y = self:LocalToScreen( 0, 0 )
		self:LayoutEntity( self.Entity )
		local ang = self.aLookAngle
		if ( !ang ) then
			ang = ( self.vLookatPos - self.vCamPos ):Angle()
		end
		cam.Start3D( self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ )
		render.SuppressEngineLighting( true )
		render.SetLightingOrigin( self.Entity:GetPos() )
		render.ResetModelLighting( self.colAmbientLight.r / 255, self.colAmbientLight.g / 255, self.colAmbientLight.b / 255 )
		render.SetColorModulation( self.colColor.r / 255, self.colColor.g / 255, self.colColor.b / 255 )
		render.SetBlend( ( self:GetAlpha() / 255 ) * ( self.colColor.a / 255 ) )
		for i = 0, 6 do
			local col = self.DirectionalLight[ i ]
			if ( col ) then
				render.SetModelLighting( i, col.r / 255, col.g / 255, col.b / 255 )
			end
		end
		self:DrawModel()
		render.SuppressEngineLighting( false )
		cam.End3D()
		self.LastPaint = RealTime()
	end

	function browser:OnSelect( path, pnl )
		lpath = "camcoder/recordings/"..string.Explode("/", path)[#string.Explode("/", path)]
		Frame:SetTitle( "Camcoder manager - "..string.Explode("/", path)[#string.Explode("/", path)] ) 
		local f = file.Open(lpath, "r", "DATA")
		if not f then
			return
		end
		local bl = f:ReadLine()
		f:Close()
		bl = bl:sub(8)
		local params = {}
		for param in string.gmatch(bl, '([^;]+)') do
		    params[#params+1] = param
		end
		local oagls = model:GetEntity():GetAngles()
		model:SetModel(player_manager.TranslatePlayerModel(params[1]))
		model:GetEntity().GetPlayerColor = function()
			return Vector(params[6])
		end
		model:GetEntity().GetWeaponColor = function()
			return Vector(params[7])
		end
		model:GetEntity():SetAngles(oagls)
		DeleteButton:SetEnabled(true)
		RenameButton:SetEnabled(true)
	end

	return true
end

function TOOL:RightClick( trace )
	return false
end

function TOOL:Reload( trace )
	return false
end