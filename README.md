This is an unfinished but very workable Vscript that can be added to your Mapbase projects to give your NPCs some stealth mechanics. The main purpose is mostly to give players a template for stealth or to teach newer devs who want to use Vscript to see how it can be used by an example.

NPCs that run this script will patrol by themselves given a fixed set of waypoints (that the level designers place themselves), will investigate a player's last known position when the player is in their FOV for long enough, and resume patrol if they can't find the player afterwards. 
If they continue to see you, they'll engage in combat, but I didn't account yet for what happens once you decide to hide while in combat.

There is a crouch factor too, where if you are crouched, it takes longer for guards to see you.

If they spot a dead comrade, they will run to the body and stay there for a while before resuming patrol. This obviously can be reworked more so that there is a harsher penalty besides this, but this is fine for the most part I feel. Because they can see dead bodies, you can now move dead bodies using the use key with a command that is included in the map file.

If you attack them while they are idle, they will instantly die. This can be reworked further though I am not planning on anything yet.

I also added a few working sound behaviors too. If you throw an object that has the physics_sound.nut script nearby a guard, the guard will go and investigate it. If you walk nearby them, they will turn around and face you. If you fire a gunshot however, they will immediately go into combat. I currently plan for more complex behavior however rather than just attack the player, but it doesn't break the illusion of stealth too much I feel.

Combat sounds are currently difficult to implement together because the hearing range is surprisingly short, which can make guard behavior unpredictable.

There are a lot of new entities created at runtime, though only one will be visible so far, the sprite sight and I think it works well for the most part. Two entities created for debugging are a glow entity and a message entity which you can uncomment out in the script.

If you feel the sprite sight is intrusive, don't worry. I also included a gun cocking sound to indicate that a guard has noticed you and will investigate.

If you plan to use this for your mod and don't want to touch Vscript, be aware that it isn't super complex, so if you are looking for something very complex, I would say be patient as I try to flesh out the system.

You want to grab sight_new.nut, physics_sound.nut and stealth_intro.bsp. You can ignore everything else. Make sure you put the .nut files in the scripts/vscripts folder of your mod.

The example map given shows how to make NPCs use this script. You need to ensure that it is of course using "sight_new.nut" in the "Entity Scripts" field, and "Think" in the "Script think function" field. You then have to give it a name. The waypoints that this NPC then traverses also needs to be named properly.

For example, if you name your NPC "gary", the waypoints must be named in ascending numerical form with the suffix _wp*, where "*" is the number. So you have to name your waypoints gary_wp1, gary_wp2 and so on for as many waypoints you need (though I do recommend not using more than 10)

The ascending waypoints should also follow a path, since the npc will always patrol in ascending order before looping back to the lowest number once it reaches the highest number. Yes, this means that NPCs patrol a looping pattern rather than a back and forth one (for the time being).

The waypoints themselves use the path_corner entity. All you need to do is name them properly, and ensure to remove the connections between path_corners later. You don't have to do anything else with the entity.

I'm not a programmer, so I am pretty sure this can be written better. But better it be bad and exists than it not existing at all.
