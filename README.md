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


Commands
--------
**Client commands**
/deathmatch: join / leave dm

**Admin commands**
/deathmatch arenaname: create dm with specific arena instead of random
/dmdebugstart: create debug arena which will work with 1p and wont check finished checks for first 60 sec
/dmjoinall: join all players in current dm
/p: log current pos to /server/arenas/SpawnPointsOutput.txt (for spawn point creation in arena's)


ARENA SETTINGS
--------------
-Location(Name): Name
-Players(min,max): Min players before match can start. Max players must equal spawn points
-Boundary(x, y, z, radius): Center point of arena. Radius defines radius, if player leaves this he will be killed within 20 seconds. 
-MaximumY(ymax): maximum y
-MinimumY(ymin): minimum y
-GraplingHookAllowed(bool): whether the grapplinghook is allowed to be used
-ParachuteAllowed(bool): whether the parachute is allowed to be used
-Spawn(x, y, z, dir, 0, 0): A spawn location. Multiple fore more locations, must match maxplayers.
-Weapon(Handgun): Weapons pool, 1 weapon will be randomly drawn from all weapons. New line for each weapon. 
	Examples of weapons:
	Handgun,Revolver,SMG,SawnOffShotgun,Assault,Shotgun,Sniper,MachineGun
	Or Weapon(id,ammo,spare ammo)

	
TODO
----
-List of admins
-Health/weapon drops
-Arena & weapon voting


Credits
-------
Patawic: I used his derby script as a basis for this script.