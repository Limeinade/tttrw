AddCSLuaFile()

SWEP.HoldType              = "ar2"

SWEP.PrintName          = "Rifle"
SWEP.Slot               = 2

SWEP.ViewModelFlip      = false
SWEP.ViewModelFOV       = 64

SWEP.Icon               = "vgui/ttt/icon_scout"
SWEP.IconLetter         = "w"

SWEP.Base                  = "weapon_tttbase"

SWEP.Kind                  = WEAPON_HEAVY
SWEP.WeaponID              = AMMO_RIFLE
SWEP.ViewModelFOV          = 85

SWEP.Bullets = {
	HullSize = 0,
	Num = 1,
	DamageDropoffRange = 5300,
	DamageDropoffRangeMax = 9600,
	DamageMinimumPercent = 0.1,
	Spread = Vector(0.002, 0.002, 0.002)
}

SWEP.TTTCompat = {"weapon_zm_rifle"}

SWEP.Primary.Damage        = 40
SWEP.Primary.Delay         = 1.5
SWEP.Primary.Recoil        = 5.2
SWEP.Primary.RecoilTiming  = 0.09
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "357"
SWEP.Primary.ClipSize      = 7
SWEP.Primary.DefaultClip   = 21
SWEP.Primary.MaxClip       = 28
SWEP.Primary.Sound         = Sound "Weapon_Scout.Single"

SWEP.Secondary.Sound       = Sound "Default.Zoom"

SWEP.HeadshotMultiplier    = 4

SWEP.AutoSpawnable         = true
SWEP.Spawnable             = true
SWEP.AmmoEnt               = "item_ammo_357_ttt"

SWEP.UseHands              = true
SWEP.ViewModel             = "models/weapons/cstrike/c_snip_scout.mdl"
SWEP.WorldModel            = "models/weapons/w_snip_scout.mdl"
SWEP.HasScope              = true

SWEP.Ironsights = {
	Pos = Vector(5, -15, -2),
	Angle = Vector(2.6, 1.37, 3.5),
	TimeTo = 0.075,
	TimeFrom = 0.1,
	SlowDown = 0.3,
	Zoom = 0.2,
}
