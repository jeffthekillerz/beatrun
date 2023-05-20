if SERVER then
	local meta = FindMetaTable("Player")

	util.AddNetworkString("SPParkourEvent")

	local spawn = {
		"PlayerGiveSWEP",
		"PlayerSpawnEffect",
		"PlayerSpawnNPC",
		"PlayerSpawnObject",
		"PlayerSpawnProp",
		"PlayerSpawnRagdoll",
		"PlayerSpawnSENT",
		"PlayerSpawnSWEP",
		"PlayerSpawnVehicle"
	}

	local function BlockSpawn(ply)
		if not ply:IsSuperAdmin() then
			return false
		end
	end

	for k, v in ipairs(spawn) do
		hook.Add(v, "BlockSpawn", BlockSpawn)
	end

	hook.Add("IsSpawnpointSuitable", "NoSpawnFrag", function (ply)
		return true
	end)
	hook.Add("AllowPlayerPickup", "AllowAdminsPickUp", function (ply, ent)
		local sa = ply:IsSuperAdmin()

		if not sa then
			return false
		end
	end)

	function meta:GTAB(minutes)
		local ID = self:SteamID64()

		for k, v in pairs(player.GetAll()) do
			v:EmitSound("gtab.mp3", 0, 100, 1)
		end

		timer.Simple(7.5, function ()
			if IsValid(self) and self:SteamID64() == ID then
				self:Ban(minutes, "GTAB")

				for k, v in pairs(player.GetAll()) do
					v:EmitSound("vinethud.mp3", 0, 100, 1)
				end
			end
		end)
	end
end

if CLIENT then
	CreateClientConVar("Beatrun_FOV", 90, true, true, "'Woah how are you moving this fast' and other hilarious jokes", 70, 175)
	CreateClientConVar("Beatrun_CPSave", 1, true, true, "Respawning during a course will go back to the last hit checkpoint", 0, 1)
end

hook.Add("PlayerNoClip", "BlockNoClip", function (ply, enabled)
	if enabled and Course_Name ~= "" and ply:GetNW2Int("CPNum", 1) ~= -1 then
		ply:SetNW2Int("CPNum", -1)

		if CLIENT_IFTP() then
			notification.AddLegacy("Noclip Enabled: Respawn to run the course", NOTIFY_ERROR, 2)
		elseif SERVER and game.SinglePlayer() then
			ply:SendLua("notification.AddLegacy( \"Noclip Enabled: Respawn to run the course\", NOTIFY_ERROR, 2 )")
		end
	end

	if enabled and (GetGlobalBool(GM_INFECTION) or GetGlobalBool(GM_DATATHEFT)) then
		return false
	end
end)

function ParkourEvent(event, ply, ignorepred)
	if IsFirstTimePredicted() or ignorepred then
		hook.Run("OnParkour", event, ply or CLIENT and LocalPlayer())

		if game.SinglePlayer() and SERVER then
			net.Start("SPParkourEvent")
			net.WriteString(event)
			net.Broadcast()
		end
	end
end

hook.Add("SetupMove", "JumpDetect", function (ply, mv, cmd)
	if ply:OnGround() and not ply:GetWasOnGround() and mv:GetVelocity():Length() > 50 and ply:GetMEMoveLimit() < 375 then
		local vel = mv:GetVelocity()
		vel.z = 0

		ply:SetMEMoveLimit(math.max(vel:Length(), 150))

		if ply:GetMESprintDelay() < 0 then
			ply:SetMEMoveLimit(350)
			ply:SetMESprintDelay(0)
		end

		ply.QuakeJumping = false

		if game.SinglePlayer() then
			ply:SendLua("LocalPlayer().QuakeJumping = false")
		end
	end

	local activewep = ply:GetActiveWeapon()

	if IsValid(activewep) and activewep:GetClass() == "runnerhands" then
		ply:SetWasOnGround(ply:OnGround())

		return
	end

	local ismoving = mv:GetVelocity():Length() > 100 and not mv:KeyDown(IN_BACK) and not ply:Crouching() and not mv:KeyDown(IN_DUCK)
	local eyeang = cmd:GetViewAngles()
	local eyeangx = eyeang.x
	eyeang.x = 0
	eyeang.z = 0

	if not ply:OnGround() and ply:GetWasOnGround() and not ply:GetJumpTurn() then
		if ismoving and mv:GetVelocity().z > 50 then
			ply:ViewPunch(Angle(-2, 0, 0))

			if not util.QuickTrace(mv:GetOrigin() + eyeang:Forward() * 200, Vector(0, 0, -100), ply).Hit then
				ParkourEvent("jumpfar", ply)
			else
				ParkourEvent("jump", ply)
			end
		elseif ply:GetSafetyRollKeyTime() <= CurTime() and ply:GetSafetyRollTime() <= CurTime() then
			ParkourEvent("fall", ply)
		end
	end

	if not ply:GetSliding() and not ply:GetJumpTurn() and not ply:Crouching() then
		ply:SetCurrentViewOffset(Vector(0, 0, 64) + eyeang:Forward() * math.Clamp(eyeangx * 0.177, 0, 90))
	end

	ply:SetWasOnGround(ply:OnGround())
end)
hook.Add("CanProperty", "BlockProperty", function (ply)
	if not ply:IsSuperAdmin() then
		return false
	end
end)
hook.Add("CanDrive", "BlockDrive", function (ply)
	if not ply:IsSuperAdmin() then
		return false
	end
end)

if CLIENT and game.SinglePlayer() then
	net.Receive("SPParkourEvent", function ()
		local event = net.ReadString()

		hook.Run("OnParkour", event, LocalPlayer())
	end)
end

if SERVER then
	hook.Add("OnEntityCreated", "RemoveMirrors", function (ent)
		if IsValid(ent) and ent:GetClass() == "func_reflective_glass" then
			SafeRemoveEntityDelayed(ent, 0.1)
		end
	end)
end

if CLIENT then
	local blur = Material("pp/blurscreen")

	function draw_blur(a, d)
		if render.GetDXLevel() < 90 then
			return
		end

		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(blur)

		for i = 1, d do
			blur:SetFloat("$blur", i / d * a)
			blur:Recompute()
			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		end
	end

	local draw_blur = draw_blur
	local impactblurlerp = 0
	local lastintensity = 0

	hook.Add("HUDPaint", "DrawImpactBlur", function ()
		if impactblurlerp > 0 then
			impactblurlerp = math.Approach(impactblurlerp, 0, 25 * FrameTime())

			draw_blur(math.min(impactblurlerp, 10), 4)
		end
	end)

	function DoImpactBlur(intensity)
		impactblurlerp = intensity
		lastintensity = intensity
	end
end
