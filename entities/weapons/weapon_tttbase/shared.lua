SWEP.Author = "Meepen"
SWEP.Instructions = "Use this as a base weapon."
SWEP.Slot = 1
SWEP.SlotPos = 0

SWEP.UseHands = true

SWEP.ReloadAnimation = ACT_VM_RELOAD

DEFINE_BASECLASS "weapon_base"

SWEP.Primary.Automatic   = true
SWEP.Primary.Delay       = 0.1
SWEP.Primary.DefaultClip = 100000
SWEP.Primary.ClipSize    = 32
SWEP.Primary.Damage      = 20

SWEP.Secondary.Delay     = 0.1
SWEP.ReloadSpeed         = 1

SWEP.HeadshotMultiplier  = 2
SWEP.DeploySpeed = 1

SWEP.Bullets = {
	HullSize = 0,
	Num = 1,
	DamageDropoffRange = 600,
	DamageDropoffRangeMax = 3600,
	DamageMinimumPercent = 0.1,
	Spread = Vector(0, 0, 0)
}

SWEP.Ironsights = {
	Pos = Vector(-8, 4, 3.9),
	Angle = Vector(0, 0, 1.5),
	TimeTo = 0.01,
	TimeFrom = 2,
	Editing
}

SWEP.AllowDrop = true

local tttrw_toggle_ads = CLIENT and CreateConVar("tttrw_toggle_ads", "0", FCVAR_USERINFO + FCVAR_ARCHIVE, "Toggle ADS on mouse2 instead of hold to ADS")

function SWEP:IsToggleADS()
	local owner = self:GetOwner()
	return (SERVER and IsValid(owner) and owner:GetInfoNum("tttrw_toggle_ads", 0) or tttrw_toggle_ads:GetInt()) ~= 0 
end

function SWEP:NetworkVarNotifyCallback(name, old, new)
	-- printf("%s::%s %s -> %s", self:GetClass(), name, old, new)
end

function SWEP:NetVar(name, type, default, notify)
	if (not self.NetVarTypes) then
		self.NetVarTypes = {}
	end

	local id = self.NetVarTypes[type] or 0
	self.NetVarTypes[type] = id + 1
	self:NetworkVar(type, id, name)

	if (default ~= nil) then
		self["Set"..name](self, default)
	end

	if (notify) then
		self:NetworkVarNotify(name, self.NetworkVarNotifyCallback)
	end
end

local scales = {
	[HITGROUP_LEFTARM] = 0.7,
	[HITGROUP_RIGHTARM] = 0.7,
	[HITGROUP_LEFTLEG] = 0.7,
	[HITGROUP_RIGHTLEG] = 0.7,
	[HITGROUP_GEAR] = 0.7
}

function SWEP:GetHitgroupScale(hg)
	if (hg == HITGROUP_HEAD) then
		return self.HeadshotMultiplier or 1
	end
	return scales[hitgroup] or 1
end

function SWEP:ScaleDamage(hitgroup, dmg)
	dmg:ScaleDamage(self:GetHitgroupScale(hitgroup))
end

function SWEP:SetupDataTables()
	self:NetVar("Ironsights", "Bool", false)
	self:NetVar("IronsightsTime", "Float", 0)
	self:NetVar("FOVMultiplier", "Float", 1)
	self:NetVar("OldFOVMultiplier", "Float", 1)
	self:NetVar("FOVMultiplierTime", "Float", -0.1)
	self:NetVar("FOVMultiplierDuration", "Float", 0.1)
	self:NetVar("ViewPunch", "Angle", angle_zero)
	self:NetVar("ViewPunchTime", "Float", -math.huge)
	self:NetVar("RealLastShootTime", "Float", -math.huge)
	self:NetVar("ConsecutiveShots", "Int", 0)
	self:NetVar("BulletsShot", "Int", 0)
	self:NetVar("ReloadEndTime", "Float", math.huge)
	self:NetVar("ReloadStartTime", "Float", math.huge)
	hook.Run("TTTInitWeaponNetVars", self)
end

function SWEP:Initialize()
	hook.Run("TTTWeaponInitialize", self)
	self:SetDeploySpeed(self.DeploySpeed)
	if (SERVER and self.Primary and self.Primary.Ammo == "Buckshot" and not self.PredictableSpread) then
		printf("Warning: %s weapon type has shotgun ammo and no predictable spread", self:GetClass())
	end
	if (SERVER) then
		self:SV_Initialize()
	end
	self:SetHoldType(self.HoldType)
end

function SWEP:ChangeIronsights(on)
	if (not self.Ironsights) then
		return
	end

	if (self:GetIronsights() == on) then
		return
	end

	self:SetIronsights(not self:GetIronsights())

	local old, new
	if (self:GetIronsights()) then
		old, new = self:GetIronsightsTimeFrom(), self:GetIronsightsTimeTo()
	else
		new, old = self:GetIronsightsTimeFrom(), self:GetIronsightsTimeTo()
	end

	local frac = math.min(1, (CurTime() - self:GetIronsightsTime()) / old) * new

	self:SetIronsightsTime(CurTime() - new + frac)

	if (CLIENT and IsFirstTimePredicted()) then
		self:CalcViewModel()
	end

	self:DoZoom(self:GetIronsights())
end

function SWEP:DoZoom(state)
	if (not self.Ironsights) then
		return
	end

	if (state) then
		self:ChangeFOVMultiplier(self.Ironsights.Zoom, self:GetIronsightsTimeTo())
	elseif (self.HasScope) then
		self:ChangeFOVMultiplier(1, 0)
	else
		self:ChangeFOVMultiplier(1, self:GetIronsightsTimeFrom())
	end
end

function SWEP:Deploy()
	self:ChangeIronsights(false)
	self:SetIronsightsTime(0)
	self:SetOldFOVMultiplier(1)
	self:SetFOVMultiplier(1)
	if (CLIENT) then
		self:CalcFOV()
	end
	if (IsValid(self:GetOwner()) and IsValid(self:GetOwner():GetHands())) then
		self:GetOwner():GetHands():SetNoDraw(not self.UseHands)
	end
	self:SendWeaponAnim(ACT_VM_DEPLOY)

	return true
end

function SWEP:OnReloaded()
	self:SetDeploySpeed(self.DeploySpeed)
end

function SWEP:Reload()
	if (self:GetReloadEndTime() ~= math.huge or self:Clip1() == self:GetMaxClip1() or self:GetOwner():GetAmmoCount(self:GetPrimaryAmmoType()) <= 0) then
		return
	end
	self:ChangeIronsights(false)
	if (CLIENT) then
		self:CalcFOV()
	end
	self:DoReload(self.ReloadAnimation)
end

function SWEP:SecondaryAttack()
	if (self:IsToggleADS()) then
		self:ChangeIronsights(not self:GetIronsights())
	else
		self:ChangeIronsights(true)
	end
end

function SWEP:GetDeveloperMode()
	return false
end

local informations = {}

function SWEP:OnDrop()
	self:SetIronsightsTime(CurTime() - self:GetIronsightsTimeFrom())
	self:SetIronsights(false)
	self:DoZoom(false)
end

function SWEP:DoDamageDropoff(tr, dmginfo)
	local distance = tr.HitPos:Distance(tr.StartPos)
	local dropoff = self:GetDamageDropoffRange()
	local max = self:GetDamageDropoffRangeMax()
	local min = self:GetDamageMinimumPercent()

	if (distance > dropoff) then
		local pct = math.min(1, (distance - dropoff) / (max - dropoff))
		dmginfo:ScaleDamage(1 - pct * (1 - min))
	end
end

ttt.ModelHitboxes = ttt.ModelHitboxes or {}

local function GetModel(ply)
	local m = ply:GetModel()
	local r = ttt.ModelHitboxes[m]

	if (not r) then
		local f = file.Open(ply:GetModel(), "rb", "GAME")

		if (not f) then
			error("PlayerModel File doesn't exist!: " .. ply:GetModel())
		end

		f:Seek(176)
		local offset = f:ReadLong()

		r = {}
		ttt.ModelHitboxes[m] = r

		for group = 0, ply:GetHitboxSetCount() - 1 do
			r[group] = {}
			f:Seek(offset + 12 * group + 8)
			local new_offset = offset + f:ReadLong()
			for hitbox = 0, ply:GetHitBoxCount(group) - 1 do
				f:Seek(new_offset + hitbox * 68 + 4)	

				r[group][hitbox] = {
					Collide = CreatePhysCollideBox(ply:GetHitBoxBounds(hitbox, group)),
					Group = f:ReadLong(),
					Bone = ply:GetHitBoxBone(hitbox, group),
				}
			end
		end

		f:Close()
	end

	return r
end


local ignore = {
	[HITGROUP_LEFTARM] = true,
	[HITGROUP_RIGHTARM] = true,
}

function SWEP:FireBulletsCallback(tr, dmginfo)
	local bullet = dmginfo:GetInflictor().Bullets

	self:DoDamageDropoff(tr, dmginfo)

	if (tr.IsFake) then
		return
	end

	if (IsValid(tr.Entity) and tr.Entity:IsPlayer()) then
		if (CLIENT and IsFirstTimePredicted()) then

			local mdl = GetModel(tr.Entity)

			local hitgroup = tr.HitGroup

			if (mdl) then
				local d = dmginfo:GetDamage()
				local best = 0
			
				for _, hitbox in pairs(mdl[tr.Entity:GetHitboxSet()]) do
					local matr = tr.Entity:GetBoneMatrix(hitbox.Bone)
					if (not IsValid(hitbox.Collide)) then
						continue
					end

					local hitpos, norm, frac = hitbox.Collide:TraceBox(matr:GetTranslation(), matr:GetAngles(), tr.StartPos, tr.StartPos + tr.Normal * 10000, vector_origin, vector_origin)
					if (hitpos and (ignore[tr.HitGroup] or hitpos:Distance(tr.HitPos) < 14)) then
						dmginfo:SetDamage(d)
						self:DoDamageDropoff(tr, dmginfo)
						self:ScaleDamage(hitbox.Group, dmginfo)

						if (dmginfo:GetDamage() > best) then
							best, hitgroup = dmginfo:GetDamage(), hitbox.Group
						end
					end
				end

				dmginfo:SetDamage(d)
			end

			self.HitboxHit = hitgroup
			self.EntityHit = tr.Entity
		elseif (SERVER) then
			dmginfo:SetDamageCustom(tr.Entity:LastHitGroup())
		end
		if (self.Bullets.Num == 1) then
			dmginfo:SetDamage(0)
		end
	end
	
	if (SERVER) then
		self.HitEntity = false and IsValid(tr.Entity) and tr.Entity:IsPlayer()
		self.TickCount = self:GetOwner():GetCurrentCommand():TickCount()
		self.LastShootTrace = tr
	end
end


function SWEP:Hitboxes()
	if (self:GetDeveloperMode()) then
		local owner = self:GetOwner()
		if (not IsValid(owner) or owner:IsBot()) then
			return 
		end
		local tick = math.floor(CurTime() / engine.TickInterval())

		if (math.floor(tick % 5) ~= 0) then
			return
		end

		local hitboxes = {}
		local otherstuff = {}

		otherstuff.CurTime = CurTime()

		owner:LagCompensation(true)


		if (SERVER) then
			net.Start("tttrw_developer_hitboxes", true)
			net.WriteUInt(tick, 32)
			net.WriteEntity(self)
		end
		for _, ply in pairs(player.GetAll()) do
			if (not ply:Alive() or ply == owner) then
				continue
			end

			local group = ply:GetHitboxSet()
			net.WriteUInt(ply:GetHitBoxCount(group), 16)
			for hitbox = 0, ply:GetHitBoxCount(group) - 1 do
				local bone = ply:GetHitBoxBone(hitbox, group)
				local pos, angles = ply:GetBonePosition(bone)
				local min, max = ply:GetHitBoxBounds(hitbox, group)
				if (SERVER) then
					net.WriteVector(pos)
					net.WriteVector(min)
					net.WriteVector(max)
					net.WriteAngle(angles)
				else
					hitboxes[#hitboxes + 1] = {pos, min, max, angles}
				end
			end
		end
		owner:LagCompensation(false)

		if (CLIENT) then
			self.DeveloperInformations = {
				Tick = tick,
				hitboxes = hitboxes,
			}
		else
			net.Send(self:GetOwner())
		end
	end
end


local vector_origin = vector_origin

function SWEP:ShootBullet()
	local owner = self:GetOwner()
	
	self:Hitboxes()

	self:SetRealLastShootTime(CurTime())
	owner:LagCompensation(true)

	if (SERVER) then
		self.LastHitboxes = {}
		for _, ply in pairs(player.GetAll()) do
			if (not ply:Alive() or ply == owner) then
				continue
			end

			--[[
			local hitboxes = {}

			local group = ply:GetHitboxSet()
			for hitbox = 0, ply:GetHitBoxCount(group) - 1 do
				local bone = ply:GetHitBoxBone(hitbox, group)
				local pos, angles = ply:GetBonePosition(bone)
				local min, max = ply:GetHitBoxBounds(hitbox, group)
				hitboxes[hitbox] = {pos, min, max, angles}
			end

			self.LastHitboxes[ply:EntIndex()] = hitboxes
			]]

			local mn, mx = ply:GetHull()
			self.LastHitboxes[ply] = {
				Mins = mn,
				Maxs = mx,
				Pos = ply:GetPos()
			}
		end
	end

	self:DoFireBullets()
	owner:LagCompensation(false)

	-- how this happen?
	if (IsValid(self.Owner)) then
		self:ShootEffects()
	end
end

function SWEP:DoFireBullets()
	local bullet_info = self.Bullets
	local owner = self:GetOwner()

	local src = owner:GetShootPos()
	local dir = owner:EyeAngles():Forward()
	local force = 2 / math.max(bullet_info.Num / 2, 1)

	local bullets = {
		Num = bullet_info.Num,
		Attacker = owner,
		Damage = self:GetDamage(),
		Tracer = 0,
		TracerName = self:GetTracerName(),
		Spread = self:GetSpread(),
		HullSize = bullet_info.HullSize,
		Force = force,
		Callback = function(atk, tr, dmg)
			if (IsValid(self)) then
				self:FireBulletsCallback(tr, dmg)
				self:TracerEffect(tr, dmg)
			end
		end,
		Src = src,
		Dir = dir,
	}

	self.LastBullets = table.Copy(bullets)

	self:FireBullets(bullets)

	self:SetBulletsShot(self:GetBulletsShot() + 1)
end

function SWEP:TracerEffect(tr, dmg)
	if ((not CLIENT or IsFirstTimePredicted()) and self:GetTracers() ~= 0 and self:GetBulletsShot() % self:GetTracers() == 0) then
		local d = EffectData()
		d:SetScale(4000)
		d:SetFlags(0)
		d:SetStart(tr.StartPos)
		d:SetOrigin(tr.HitPos or tr.StartPos)
		d:SetDamageType(dmg:GetDamageType())
		d:SetColor(1)

		local r
		if (SERVER) then
			r = RecipientFilter()
			r:AddAllPlayers()
		end
		util.Effect(self:GetTracerName(), d, true, r)
	end
end

function SWEP:GetSpread()
	return self.Bullets.Spread * (self.Primary.Ammo:lower() == "buckshot" and 1 or (0.25 + (-self:GetMultiplier() + 2) * 0.75)) * (0.5 + self:GetCurrentZoom() / 2) ^ 0.7
end

function SWEP:CanPrimaryAttack()
	if (self:Clip1() > 0) then
		return true
	end
	self:EmitSound "Weapon_Pistol.Empty"
	self:SetNextPrimaryFire(CurTime() + 0.2)
	self:Reload()
	return false
end

function SWEP:PrimaryAttack()
	if (not self:CanPrimaryAttack()) then
		return
	end

	local interval = engine.TickInterval()
	local delay = math.ceil(self:GetDelay() / interval) * interval
	local diff = (CurTime() - self:GetRealLastShootTime()) / delay

	-- do this before consecutive
	self:SetNextPrimaryFire(CurTime() + self:GetDelay())

	if (diff <= 1.25) then
		self:SetConsecutiveShots(self:GetConsecutiveShots() + 1)
	else
		self:SetConsecutiveShots(0)
	end

	if (self:Clip1() <= math.max(self:GetMaxClip1() * 0.15, 3)) then
		self:EmitSound("weapons/pistol/pistol_empty.wav", self.Primary.SoundLevel, 255, 2, CHAN_USER_BASE + 1)
	end

	self:EmitSound(self.Primary.Sound, self.Primary.SoundLevel)

	self:ShootBullet()

	if (not self:GetDeveloperMode()) then
		self:TakePrimaryAmmo(1)
	end

	self:ViewPunch()
end

local quat_zero = Quaternion()

function SWEP:GetCurrentViewPunch()
	local delay = self.Primary.RecoilTiming or self:GetDelay()
	local time = self:GetViewPunchTime()
	local frac = (CurTime() - time) / delay
	
	if (frac >= 1) then
		return angle_zero
	end

	local vp = self:GetViewPunch()
	local diff = Quaternion():SetEuler(-vp):Slerp(quat_zero, frac):ToEulerAngles()

	return diff
end

function SWEP:ViewPunch()
	if (self:GetDeveloperMode()) then
		return
	end
	
	local vp = self:GetViewPunchAngles()
	self:SetViewPunch(vp)
	self:SetViewPunchTime(CurTime())

	if (not CLIENT or not IsFirstTimePredicted()) then
		return
	end

	local own = self:GetOwner()
	own:SetEyeAngles(own:EyeAngles() + vp)

	self:CalcViewPunch()
end

function SWEP:Think()
	local reloadtime = self:GetReloadEndTime()
	if (reloadtime ~= math.huge) then
		if (reloadtime > CurTime()) then
			local time = (CurTime() - self:GetReloadStartTime())

			local snd = IsFirstTimePredicted() and self.Sounds and self.Sounds.reload
			if (snd) then
				for _ = #snd, 1, -1 do
					local inf = snd[_]
					if (inf.time / self:GetReloadAnimationSpeed() <= time) then
						if (self.LastSound ~= inf.sound) then
							self:EmitSound(inf.sound)
							print(inf.sound)
							self.LastSound = inf.sound
						end
						break
					end
				end
			end

			return
		end


		local ammocount = self:GetOwner():GetAmmoCount(self:GetPrimaryAmmoType())
		local needed = self:GetMaxClip1() - self:Clip1()

		local added = math.min(needed, ammocount)

		self:GetOwner():SetAmmo(ammocount - added, self:GetPrimaryAmmoType())

		self:SetClip1(self:Clip1() + added)
		self:SetReloadEndTime(math.huge)
		self:SendWeaponAnim(ACT_VM_IDLE)
	end

	if (not self:IsToggleADS()) then
		if (not self:GetIronsights() and self:GetOwner():KeyDown(IN_ATTACK2)) then
			self:SecondaryAttack()
		elseif (self:GetIronsights() and not self:GetOwner():KeyDown(IN_ATTACK2)) then
			self:ChangeIronsights(false)
		end
	end

	if (CLIENT) then
		self:CalcAllUnpredicted()
	end

	self:Hitboxes()
end

function SWEP:GetCurrentFOVMultiplier()
	return self:GetOldFOVMultiplier() + (self:GetFOVMultiplier() - self:GetOldFOVMultiplier()) * math.min(1, (CurTime() - self:GetFOVMultiplierTime()) / self:GetFOVMultiplierDuration())
end

function SWEP:ChangeFOVMultiplier(fovmult, duration)
	self:SetOldFOVMultiplier(self:GetCurrentFOVMultiplier())
	self:SetFOVMultiplier(fovmult)
	self:SetFOVMultiplierDuration(duration)
	self:SetFOVMultiplierTime(CurTime())
end

function SWEP:GetCurrentZoom()
	local mult = 1
	if (self.Ironsights) then
		local base = self.Ironsights.Zoom
		mult = (self:GetCurrentFOVMultiplier() - base) / (1 - base)
	end
	return mult
end

function SWEP:GetMultiplier()
	return (1 + math.max(0, 1 - self:GetConsecutiveShots() / 4))
end

function SWEP:GetViewPunchAngles()
	return Angle((-self.Primary.Recoil * self:GetMultiplier() * (0.5 + self:GetCurrentZoom() / 2) ^ 0.7))
end

function SWEP:AdjustMouseSensitivity()
	if (self:GetIronsights()) then
		return self.Ironsights.Zoom
	end
end

function SWEP:GetReloadAnimationSpeed()
	return self.ReloadSpeed
end

function SWEP:DoReload(act)
	local speed = self:GetReloadAnimationSpeed()

	self:SendWeaponAnim(act)
	self:SetPlaybackRate(speed)
	if (IsValid(self:GetOwner())) then
		self:GetOwner():GetViewModel():SetPlaybackRate(speed)
		self:GetOwner():DoCustomAnimEvent(PLAYERANIMEVENT_RELOAD, 0)
	end

	local endtime = CurTime() + self:SequenceDuration() / speed + 0.1

	self.LastSound = nil
	self:SetReloadStartTime(CurTime())
	self:SetReloadEndTime(endtime)
	self:SetNextPrimaryFire(endtime)
	self:SetNextSecondaryFire(endtime)
end

function SWEP:CancelReload()
	self:SetNextPrimaryFire(CurTime() + self:GetDelay())
	self:SetNextSecondaryFire(CurTime() + self:GetDelay())
	self:SetReloadEndTime(math.huge)
end

function SWEP:Holster()
	self:CancelReload()
	self:SendWeaponAnim(ACT_VM_DEPLOY)
	return true
end


-- accessors for stuff so you can override easier

function SWEP:GetDamage()
	return self.Primary.Damage
end

function SWEP:GetTracers()
	return self.Bullets.Tracer or 1
end

function SWEP:GetTracerName()
	return self.Bullets.TracerName or "Tracer"
end

function SWEP:GetDamageDropoffRange()
	return self.Bullets.DamageDropoffRange
end

function SWEP:GetDamageDropoffRangeMax()
	return self.Bullets.DamageDropoffRangeMax
end

function SWEP:GetDamageMinimumPercent()
	return self.Bullets.DamageMinimumPercent
end

function SWEP:GetIronsightsTimeFrom()
	return self.Ironsights.TimeFrom
end

function SWEP:GetIronsightsTimeTo()
	return self.Ironsights.TimeTo
end

function SWEP:GetDelay()
	return self.Primary.Delay
end