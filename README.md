This is an unfinished Vscript that can be added to your Mapbase projects to give your NPCs some stealth mechanics. The main purpose is mostly to give players a template for stealth or to teach newer devs who want to use Vscript to see how it can be used by an example.

NPCs that run this script will patrol by themselves given a fixed set of waypoints (that the level designers place themselves), will investigate a player's last known position when the player is in their FOV for long enough, and resume patrol if they can't find the player afterwards. 
If they continue to see you, they'll engage in combat, but I didn't account yet for what happens once you decide to hide while in combat.

I am currently working on adding sound behaviors too. Currently, all the NPCs that use this script are deaf, unable to hear the player or combat sounds. There's also no stance factor, so their sight meter increases at the same rate whether you are crouching or standing.

There are a lot of new entities created at runtime, and will immediately be visible when you load the map. If you plan to use this for your mod and don't want to touch Vscript, I would say be patient as I try to flesh out the system.

The example map given shows how to make NPCs use this script. You need to ensure that it is of course using "sight_new.nut" in the "Entity Scripts" field, and "Think" in the "Script think function" field. You then have to give it a name. The waypoints that this NPC then traverses also needs to be named properly.

For example, if you name your NPC "gary", the waypoints must be named in ascending numerical form with the suffix _wp*, where "*" is the number. So you have to name your waypoints gary_wp1, gary_wp2 and so on for as many waypoints you need (though I do recommend not using more than 10)

The ascending waypoints should also follow a path, since the npc will always patrol in ascending order before looping back to the lowest number once it reaches the highest number. Yes, this means that NPCs patrol a looping pattern rather than a back and forth one (for the time being).

The waypoints themselves use the path_corner entity. All you need to do is name them properly, you don't have to do anything else with the entity.

