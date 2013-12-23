JC2MP Deathmatch
================
Author: m1nd0 (joopselen@gmail.com)

Description
------------
Deathmatch mode for JC2MP. 


Installation
------------
Drop in /scripts/ folder.
Edit /server/DeathMatchManager.lua with your own admin ID.
Edit /server/arenas/Manifest.txt for desired arena's


How it works
------------
**Client**
- pres 'k' or type /dm or /deathmatch to open the GUI

**Admin**
- Start: starts the event (disregarding minplayers, and any timers)
- Debugstart: starts the event (disregarding minplayers, and any timers) and doesn't check finish criteria for first 60 seconds

ARENA SETTINGS
--------------
- Location(Name): Name
- Players(min,max): Min players before match can start. Max players must equal spawn points
- Boundary(x, y, z, radius): Center point of arena. Radius defines radius, if player leaves this he will be killed within 20 seconds. 
- MaximumY(ymax): maximum y
- MinimumY(ymin): minimum y
- GrapplingHookAllowed(bool): whether the grapplinghook is allowed to be used
- ParachuteAllowed(bool): whether the parachute is allowed to be used
- Spawn(x, y, z, dir, 0, 0): A spawn location. Multiple fore more locations, must match maxplayers.
- Weapon(Handgun): Weapons pool, 1 weapon will be randomly drawn from all weapons. New line for each weapon. 
	Examples of weapons:
	Handgun,Revolver,SMG,SawnOffShotgun,Assault,Shotgun,Sniper,MachineGun
	Or Weapon(id,ammo,spare ammo)

Credits
-------
Patawic: I used his derby script as a basis for this script.