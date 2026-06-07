enum AlertStage
{
    Peaceful,
    Intrigued_H,
    Intrigued_S,
    Alerted_H
    Alerted_S,
    Alien,
    Caution
}

/*
Hierarchy of senses
Should go from lowest to highest state
- Peaceful    -> Did not see anything, nor heard anything
- Intrigued_H -> Did not see anything, heard something
- Intrigued_S -> Saw something
- Alerted_H     -> Did not see anything, heard a loud sound 
- Alerted_S     -> Saw player

Caution state should reuse intrigued code when hunting
Create checks for sight and sound

Hierarchy of actions
- Peaceful_Patrol
- Intrigued_Approach_H
- Intrigued_Approach_S
- Alert_Approach_H
- Alert_S
*/

enum ActionState
{
    Peaceful_Patrol,
    Intrigued_Approach_H,
    Intrigued_Approach_S,
    Alert_Approach_H,
    Alert_Seen,
    Sound_Distract,
    Sound_Combat
}

enum PatrolVars
{
    Walking,
    Waiting
}

local alertlevel = 0
local alertStage = AlertStage.Peaceful
local actionState = ActionState.Peaceful_Patrol
local patrolVar = PatrolVars.Walking
local currentWayPointIndex = 0
local raiseFactor = 500
local lowerFactor = 0.25
local DetectionBuildRate = 5
local maxSightDist = 1024

local squadManager = Squads

local red = 0
local green = 255

local waypoints = []

local debugtext = SpawnEntityFromTable("point_message",
{ 
    radius = 4096
    targetname = "debug_" + self.GetName()
    origin = self.EyePosition()
})

local sightsprite = SpawnEntityFromTable("env_sprite",
{
    disablereceiveshadows = 0
    Eflags = 0
    framerate = 10.0
    GlowProxySize = 15
    HDRColorScale = 1.0
    origin = self.EyePosition()
    model = "sprites/glow01.spr"
    targetname = "sprite_sight_" + self.GetName()
    rendercolor = "0 255 0"
    rendermode = 9
    scale = 0.25
    spawnflags = 1
})

local guncock = SpawnEntityFromTable("ambient_generic",
{
    origin = self.EyePosition()
    targetname = self.GetName() + "weaponcock"
    radius = 1024
    message = "weapons/alyx_gun/alyx_shotgun_cock1.wav"
    volstart = 10
    spawnflags = 48
    health = 10
})

local glow = SpawnEntityFromTable("point_glow",
{
    target = self.GetName()
    GlowColor = "115 247 255 255"
})

//spawns a sprite at the NPC's eyes. Research self.GetForwardVector to see how apply the position in respect to the NPC

DoEntFire("debug_" + self.GetName(), "SetParent", self.GetName(), 0, null, null)
//DoEntFire("debug_" + self.GetName(), "SetParentAttachment", "eyes", 0, null, null) 

DoEntFire(self.GetName() + "weaponcock", "SetParent", self.GetName(), 0, null, null)
DoEntFire(self.GetName() + "weaponcock", "SetParentAttachment", "eyes", 0, null, null)
DoEntFire("sprite_sight_" + self.GetName(), "SetParent", self.GetName(), 0, null, null)
DoEntFire("sprite_sight_" + self.GetName(), "SetParentAttachment", "eyes", 0, null, null) 
// don't use SetParentAttachmentMaintainOffset, otherwise the sprite spawns very high above the soldier

self.ConnectOutput("OnDamagedByPlayer", "StealthKill")

function NPC_TranslateActivity()
{
    local newactivity = -1
    
    /// This code currently handles sound checking, as NPCs will run to check sounds
    if(activity == "ACT_RUN" && self.GetNPCState() == NPC_STATE_IDLE)
    {
        newactivity = "ACT_WALK_AIM"
    }
    
    else if(alertStage == AlertStage.Intrigued_S && activity == "ACT_WALK") 
    {
        newactivity = "ACT_WALK_AIM"
    }
    
    else if(alertStage == AlertStage.Intrigued_S && activity == "ACT_IDLE")
    {
        newactivity = "ACT_IDLE_ANGRY"
    }
    
    return newactivity
    
}

local investigating_sound = false
local repatrol = false
local soundcooldown = 0

function OnPostSpawn()
{
    //local mySquad = squadManager.FindCreateSquad(self.GetSquad().GetName()) 
    local ent = null
    //find all the waypoints associated with the npc
    
    for (local entity; entity = Entities.FindByName(entity, self.GetName() + "_wp*");)
    {
        printl(entity)
        waypoints.append(entity)
    }
    //then immediately start patrolling
    patrolVar = PatrolVars.Walking
    EntFire("!self", "SetTarget", waypoints[0].GetName(), 0, self, self)
    printl(self.GetName() + " is now going to " + waypoints[0].GetName())
}

function OnDeath()
{
    DoEntFire("sprite_sight_" + self.GetName(), "Kill", "", 0, self, self)
    DoEntFire(self.GetName() + "weaponcock", "Kill", "", 0, self, self)
    DoEntFire("!self", "Kill", "", 0, self, self)
    DoEntFire("!self", "CreateSeparateRagdoll", "", 0, self, self)
}

function StealthKill()
{
    if(self.GetNPCState() != NPC_STATE_COMBAT)
    {
        DoEntFire("sprite_sight_" + self.GetName(), "Kill", "", 0, self, self)
        local mySquad = squadManager.FindCreateSquad(self.GetSquad().GetName()) 
        // might want to put this OnPostSpawn. The line above only returns later on in the script, it won't work at the start of it
        mySquad.RemoveFromSquad(self) // normally, if a squad member dies, other members become alerted. Removing them first resolves this
        DoEntFire("!self", "DropWeapon", "", 0, self, self) // without this, the weapon floats in midair
        DoEntFire("!self", "Kill", "", 0, self, self)
        DoEntFire("!self", "CreateSeparateRagdoll", "", 0, self, self)
    }
}

function ColorLerpRaise()
{
    local _red = alertlevel*255
    local _grn = alertlevel*255
    red = clamp(_red.tointeger(), 0, 255) // red = alertlevel*255 use tointeger()
    green = clamp(255 - _grn.tointeger(), 0, 255) // green = 255
    //red = clamp(red + 50, 0, 255) // red = alertlevel*255 use tointeger()
    //green = clamp(green - 50, 0, 255) // green = 255
    Color_change(red, green)
}

function ColorLerpLower()
{
    local _red = alertlevel*255
    local _grn = alertlevel*255
    red = clamp(255 - _red.tointeger(), 0, 255)
    green = clamp(_grn.tointeger(), 0, 255)
    //red = clamp(red - 50, 0, 255)
    //green = clamp(green + 50, 0, 255)
    Color_change(red, green)
}

function Color_change(red, green)
{

    if(self.GetNPCState() == NPC_STATE_COMBAT)
    {
        DoEntFire("sprite_sight_" + self.GetName(), "Color", "255" + " " + "0" + " " + "0", 0, self, self)
    }
    else
    {
        if(alertlevel == 0)
        {
            DoEntFire("sprite_sight_" + self.GetName(), "Color", "0" + " " + "255" + " " + "0", 0, self, self)
        }
        else if(alertlevel == 1)
        {
            DoEntFire("sprite_sight_" + self.GetName(), "Color", "255" + " " + "0" + " " + "0", 0, self, self)
        }
        else
        {
            DoEntFire("sprite_sight_" + self.GetName(), "Color", red + " " + green + " " + "0", 0, self, self)
        }
    }   
}

const AI_SENSING_SAMPLE_CONE = 0.5 // 1 is basically blind, 0 is basically 180
const maxCuriousCoolDown = 5
const maxAlertCoolDown = 30
local curiousCoolDown = 0
local alertCoolDown = 0
local waitTime = 0
local maxWaitTime = 5
local fst_contact = false
local fst_eng = false
local fst_move = false
local playerInView = false
local heardPlayer = false

local debug_stage = "Peaceful"

local staystill = 0

function Sight_Behavior()
{
    local vecDelta = player.GetOrigin() - self.EyePosition()
    
    vecDelta.z = 0
    vecDelta.Norm()

    //local flDot = vecDelta.Dot(self.EyeDirection2D())
    //local flDot = vecDelta.Dot(self.EyeDirection3D())
    //local flDot = vecDelta.Dot(self.BodyDirection2D())
    local flDot = vecDelta.Dot(self.BodyDirection3D())

    local trace = TraceLineComplex(self.EyePosition(), player.EyePosition(), self, MASK_BLOCKLOS, COLLISION_GROUP_NONE)
    
    local distance = (player.EyePosition() - self.EyePosition()).Length()

    local dleft = (self.GetOrigin()-waypoints[currentWayPointIndex].GetOrigin()).Length()

    //DoEntFire("debug_" + self.GetName(), "SetMessage", "WaitTime: " + waitTime + " & " + "Distance: " + dleft, 0, null, null)

    DoEntFire("debug_" + self.GetName(), "SetMessage", "CuriousCD: " + curiousCoolDown + " Schedule: " + self.GetSchedule() + " & " + "State: " + self.GetNPCState(), 0, null, null)

    soundcooldown -= FrameTime()

    if(self.GetNPCState() == NPC_STATE_IDLE || self.GetNPCState() == NPC_STATE_ALERT) 
    {
        if (flDot > AI_SENSING_SAMPLE_CONE && !trace.DidHit() && distance < maxSightDist)
        {
            playerInView = true
        }
        else
        {
            playerInView = false
        }
    }
    _UpdateSightAlertState()
}

function QuerySeeEntity()
{
    if(self.GetNPCState() == NPC_STATE_COMBAT)
    {
        return true
    }

    if(self.GetNPCState() == NPC_STATE_IDLE || self.GetNPCState() == NPC_STATE_ALERT)
    {
        switch(alertStage)
        {
            case AlertStage.Peaceful:
                return false
            case AlertStage.Intrigued_S:
                return false
            case AlertStage.Alerted_S:
                return true
        }
    }
}

local lastEnemyTime = 0
local alert_heard = false

function _UpdateSight(distance)
{
    if(playerInView)
    {
        alertlevel = clamp(alertlevel + raiseFactor*(DetectionBuildRate)*FrameTime()/distance, 0, 1)
        ColorLerpRaise()
    }
    else
    {
        alertlevel = clamp(alertlevel - lowerFactor*(DetectionBuildRate)*FrameTime(), 0, 1)
        ColorLerpLower()
    }
}

function _UpdateSightAlertState()
{
    switch(alertStage)
    {
        case AlertStage.Peaceful:
        debug_stage = "Peaceful"
        if(!alert_heard)
        {
            _UpdateSight(distance)
            if(alertlevel >= 0.5)
            {
                fst_contact = true
                alertStage = AlertStage.Intrigued_S
            }
        }
        break

        case AlertStage.Intrigued_S:
        debug_stage = "Intrigued_S"
        if(!alert_heard)
        {
            _UpdateSight(distance)
            if(alertlevel >= 1)
            {
                fst_eng = true
                alertStage = AlertStage.Alerted_S
            }
            else if (alertlevel <= 0.5 && curiousCoolDown <= 0)
            {
                alertStage = AlertStage.Peaceful
            }
        }
        break

        case AlertStage.Alerted_H:
            _UpdateSight(distance)
            if(alertlevel >= 1)
            {
                fst_eng = true
                alertStage = AlertStage.Alerted_S
            }
        break

        case AlertStage.Alerted_S:
        debug_stage = "Alerted_S"
        lastEnemyTime = self.GetLastEnemyTime()
        break

        case AlertStage.Caution:
        break
    }
    _UpdateSchedule()
}

function _UpdateSchedule()
{
    switch(alertStage)
    {
        case AlertStage.Peaceful:
            actionState = ActionState.Peaceful_Patrol
            break
        case AlertStage.Intrigued_S:
            actionState = ActionState.Intrigued_Approach_S
            break
        case AlertStage.Intrigued_H:
            actionState = ActionState.Intrigued_Approach_H
            break
        case AlertStage.Alerted_H:
            actionState = ActionState.Alert_Approach_H
            break
        case AlertStage.Alerted_S:
            actionState = ActionState.Alert_Seen
            break
    }
    _UpdateAction()
}

function _UpdateAction()
{
    switch(actionState)
    {
        case ActionState.Peaceful_Patrol: 
            if(repatrol)
            {
                repatrol = false
                local patrolpoint = Entities.FindByNameNearest(self.GetName() + "_wp*", self.GetOrigin(), 2048)
                DoEntFire("!self","SetTarget",patrolpoint.GetName(),0,self,self)
            }
            else
            {
                if(patrolVar == PatrolVars.Walking)
                {
                    if((self.GetOrigin()-waypoints[currentWayPointIndex].GetOrigin()).Length() < 8) // in game this is apparently the distance between the npc and the node
                    {
                        patrolVar = PatrolVars.Waiting
                        waitTime = maxWaitTime
                    }
                }
                if(patrolVar == PatrolVars.Waiting)
                {
                    waitTime -= 7*FrameTime()
                    if(waitTime < 0)
                    {
                        patrolVar = PatrolVars.Walking
                        currentWayPointIndex = (currentWayPointIndex + 1) % waypoints.len()
                        EntFire("!self", "SetTarget", waypoints[currentWayPointIndex].GetName(), 0, self, self)
                    }
                }
            }
            break
        case ActionState.Intrigued_Approach_S:

            local aifollow = SpawnEntityFromTable("ai_goal_follow"
            {
                actor = self.GetName()
                goal = self.GetName() + "playercornerpath"
                Formation = 0
                targetname = self.GetName() + "aifollow"
                StartActive = 0
            })

            local playerpos = SpawnEntityFromTable("path_corner",
            {
                origin = self.GetOrigin()
                targetname = self.GetName() + "playercornerpath"
            })

            if(fst_contact) // fst_contact should be the setup
            {
                DoEntFire(self.GetName() + "weaponcock", "PlaySound", "",0,null,null)
                playerpos.SetOrigin(player.GetOrigin())
                self.ClearSchedule("SCHED_IDLE_WALK")
                curiousCoolDown = maxCuriousCoolDown
                fst_contact = false
                fst_move = true
                staystill = 2
            }
            else
            {
                if(staystill > 0)
                {
                    staystill -= 5*FrameTime()
                }
                else if (staystill <= 0)
                {
                    if(fst_move)
                    {
                        
                        DoEntFire(self.GetName() + "aifollow", "Activate", "",0,self,self)
                        fst_move = false
                    }
                    else
                    {
                        if(playerInView) // update player position and movement
                        {
                            playerpos.SetOrigin(player.GetOrigin()) // hmm... this doesn't seem to work
                            curiousCoolDown = maxCuriousCoolDown
                        }
                        
                        if(self.GetActivity() == "ACT_IDLE")
                        {
                            curiousCoolDown -= 7*FrameTime()
                        }
                        
                        if(curiousCoolDown <= 0)
                        {
                            repatrol = true
                            DoEntFire(self.GetName() + "aifollow", "Deactivate", "",0,self,self)
                            DoEntFire(self.GetName() + "aifollow", "Kill", "",0,self,self)
                            DoEntFire(self.GetName() + "playercornerpath", "Kill", "",0,self,self)
                        }
                    }
                }
            }
            break
        case ActionState.Alert_Seen:

            //EntFire("!self","UpdateEnemyMemory","!player",0,null,null) //sometimes even though alertlevel is equals 1, it doesn't always cause the NPC to react. This should fix it
            /*
            if(fst_eng)
            {
                EntFire("!self","UpdateEnemyMemory","!player",0,null,null) //sometimes even though alertlevel is equals 1, it doesn't always cause the NPC to react. This should fix it
                self.GetSquad.UpdateEnemyMemory(self, player, player.GetOrigin())
                alertCoolDown = maxAlertCoolDown
            }
            */
            break
        case ActionState.Intrigued_Approach_H:
            if(investigating_sound)
            {
                self.SetSchedule("SCHED_INVESTIGATE_SOUND")
                investigating_sound = false
            }
            
            break
        case ActionState.Alert_Approach_H:
            if(investigating_sound)
            {
                self.SetSchedule("SCHED_INVESTIGATE_SOUND")
                investigating_sound = false
            }
            break
    }
}

function NPC_TranslateSchedule()
{
    if(self.GetSchedule() != "SCHED_INVESTIGATE_SOUND")
    //if(self.GetSchedule() == "SCHED_IDLE_STAND" && investigating_sound == true)
    {
        investigating_sound = false
        local patrolpoint = Entities.FindByNameNearest(self.GetName() + "_wp*", self.GetOrigin(), 2048)
        DoEntFire("!self","SetTarget",patrolpoint.GetName(),0,self,self)
    }
}

function QueryHearSound()
{
    if(alertStage != AlertStage.Alerted_S)
    {
        alert_heard = true // this should lock out any other state except for the alert one
        if(sound.SoundType() & (SOUND_COMBAT))
        {
            alertStage = AlertStage.Alerted_H
            investigating_sound = true
        }
    }
    
    if(alertStage == AlertStage.Peaceful)
    {
        if (sound.SoundType() & (SOUND_WORLD)) // somehow need to account for thrown object then investigate player LKP
        {
            alertStage = AlertStage.Intrigued_H
            investigating_sound = true
        }
    }

    

    /*
    else if (sound.SoundType() & (SOUND_PLAYER) && soundcooldown <= 0)
    {
        soundcooldown = 1
        local soundemitter = SpawnEntityFromTable("ai_sound",
        {
            origin = self.GetOrigin()
            duration = 0.5
            soundcontext = SOUND_CONTEXT_REACT_TO_SOURCE 
            soundtype = SOUND_WORLD                    
            targetname = "ai_sound_emitter_player"
            volume = 200
        })
        DoEntFire("ai_sound_emitter_player", "EmitAISound", "", 0, null, null)
        DoEntFire("ai_sound_emitter_player", "Kill", "", 1, null, null)
    }
    */
    /*
    else 
    {
        if(self.GetSchedule("SCHED_IDLE_STAND") && investigating_sound == true)
        {
            investigating_sound = false
            local patrolpoint = Entities.FindByClassnameNearest( "path_corner", self, 2048 )
            DoEntFire("!self","SetTarget",patrolpoint.GetName(),0,self,self)
        }
        
        if(invescooldown > 0 && investigating_sound == true)
        {
            invescooldown -= 7*FrameTime()
            self.SetSchedule("SCHED_IDLE_WALK")
        }
        else if (invescooldown < 0)
        {
            self.ClearSchedule("SCHED_INVESTIGATE_SOUND")
            investigating_sound = false
            local patrolpoint = Entities.FindByClassnameNearest( "path_corner", self, 2048 )
            DoEntFire("!self","SetTarget",patrolpoint.GetName(),0,self,self)
        }
    }*/
}

/*
To do: Make the patrolling be tied to the scripting
SetTarget must somehow be cancelled, and the state must change

*/

//OnPostSpawn is a hook

//self.SetEnemyDiscardTime(1000)
//self.ClearEnemyMemory(player)
//this can be pretty buggy if applied incorrectly

//printl("NPC is now " + self.GetNPCState())
                    //self.SetNPCTarget(player)


 //printl("NPC is now " + self.GetNPCState())
                        //printl(self.GetEnemyLKP())
                        //self.ClearEnemyMemory(player)


//DoEntFire("!self", "ForgetEntity", "", 0, self, self)
//DoEntFire("!self", "MoveToPosition", "", 0, self, self)//this one might not work since it is dependent on scripted sequence, though I suppose we could create a ss where the player was

//search CAI_BaseNPC 
//self.GetEnemyLKP
//self.GetLastEnemyTime()