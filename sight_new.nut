enum AlertStage
{
    Idle_Peaceful,
    Idle_Seen,
    Idle_Heard_World,
    Idle_Heard_Player, // probably not gonna use this
    Alert_Heard_Combat,
    Alert_Seen,
    Alert_Body,
    Combat_Seen,
    Caution_Investigate,
    Follow_Called
}

enum ActionState
{
    Idle_Patrol,
    Idle_Approach_Seen,
    Idle_Approach_Heard_World,
    Idle_Approach_Heard_Player, // probably not gonna use this
    Alert_Approach_Heard_Combat,
    Alert_Approach_Seen,
    Alert_Approach_Body,
    Combat_Action,
    Caution_Hunt,
    Follow_Buddy
}

enum PatrolVars
{
    Walking,
    Waiting
}

//DEBUGGING
/*
local debugtext = SpawnEntityFromTable("point_message",
{ 
    radius = 4096
    targetname = "debug_" + self.GetName()
    origin = self.EyePosition()
})

local debugtext_1 = SpawnEntityFromTable("point_message",
{ 
    radius = 4096
    targetname = "debug1_" + self.GetName()
    origin = self.EyePosition()
})
*/

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

/*
local glow = SpawnEntityFromTable("point_glow",
{
    targetname = self.GetName() + "glow"
    target = self.GetName()
    GlowColor = "0 255 0 255"
})
*/

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

if(self.ValidateScriptScope())
{
    self.GetScriptScope().timesawenemy <- 0 // timer which increases so long as it hasn't seen the enemy
    self.GetScriptScope().cautionCoolDown <- 0
    self.GetScriptScope().foundbody <- false
    //self.GetScriptScope().followbuddy <- null
}

const AI_SENSING_SAMPLE_CONE = 0.5 // 1 is basically blind, 0 is basically 180
local playerInView = false
local raiseFactor = 500
local lowerFactor = 0.25
local DetectionBuildRate = 5
local maxSightDist = 1024
local waitTime = 0
local maxWaitTime = 5
local alertlevel = 0
local alertStage = AlertStage.Idle_Peaceful
local actionState = ActionState.Idle_Patrol
local patrolVar = PatrolVars.Walking
local currentWayPointIndex = 0
local staystill = 0
local fst_move = false
local squadManager = Squads
local red = 0
local green = 255
local waypoints = []

local fst_contact = false
local repatrol = false
local fst_player = false
local fst_caut = false

const maxCuriousCoolDown = 5
local curiousCoolDown = 0
const maxAlertCoolDown = 10
local alertCoolDown = 0
const maxCombatCoolDown = 10
local combatCoolDown = 0
local maxCautionCoolDown = 10

local bodyhunt = false

local saw_body = false

local should_hunt = false
local member_hunt = 0
local no_one_saw10 = 0

/* //DEBUGGING
DoEntFire("debug_" + self.GetName(), "SetParent", self.GetName(), 0, null, null) 
DoEntFire("debug1_" + self.GetName(), "SetParent", self.GetName(), 0, null, null) 
DoEntFire("debug1_" + self.GetName(), "SetParentAttachment", "lefthand", 0, null, null)
*/

DoEntFire(self.GetName() + "weaponcock", "SetParent", self.GetName(), 0, null, null)
DoEntFire(self.GetName() + "weaponcock", "SetParentAttachment", "eyes", 0, null, null)
//spawns a sprite at the NPC's eyes. Research self.GetForwardVector to see how apply the position in respect to the NPC
DoEntFire("sprite_sight_" + self.GetName(), "SetParent", self.GetName(), 0, null, null)
DoEntFire("sprite_sight_" + self.GetName(), "SetParentAttachment", "eyes", 0, null, null) 
// don't use SetParentAttachmentMaintainOffset, otherwise the sprite spawns very high above the soldier

self.ConnectOutput("OnDamagedByPlayer", "StealthKill")

function NPC_TranslateActivity()
{
    local newactivity = -1

    if(activity == "ACT_RUN" && self.GetNPCState() == NPC_STATE_IDLE && alertStage == AlertStage.Idle_Seen)
    {
        newactivity = "ACT_WALK_AIM"
    }
    /// This code currently handles sound checking, as NPCs will run to check sounds
    if((alertStage == AlertStage.Idle_Heard_World || alertStage == AlertStage.Idle_Heard_Player) && activity == "ACT_RUN")
    {
        newactivity = "ACT_WALK_AIM"
    }

    else if((alertStage == AlertStage.Idle_Seen || alertStage == AlertStage.Alert_Body) && activity == "ACT_WALK") 
    {
        newactivity = "ACT_WALK_AIM"
    }
    
    else if((alertStage == AlertStage.Idle_Seen || alertStage == AlertStage.Alert_Body) && activity == "ACT_IDLE")
    {
        newactivity = "ACT_IDLE_ANGRY"
    }

    /*
    else if(alertStage == AlertStage.Alert_Heard_Combat && activity == "ACT_WALK")
    {
        newactivity = "ACT_RUN"
    }
    */
    return newactivity
}

function OnDeath()
{
    DoEntFire("sprite_sight_" + self.GetName(), "Kill", "", 0, self, self)
    DoEntFire(self.GetName() + "weaponcock", "Kill", "", 0, self, self)
    local mySquad = squadManager.FindCreateSquad(self.GetSquad().GetName()) 
    mySquad.RemoveFromSquad(self)
    DoEntFire("!self", "Kill", "", 0, self, self)
    DoEntFire("!self", "CreateSeparateRagdoll", "", 0, self, self)
}

function StealthKill()
{
    if(self.GetNPCState() != NPC_STATE_COMBAT)
    {
        DoEntFire("sprite_sight_" + self.GetName(), "Kill", "", 0, self, self)
        local mySquad = squadManager.FindCreateSquad(self.GetSquad().GetName()) 
        DoEntFire(self.GetName() + "weaponcock", "Kill", "", 0, self, self)
        mySquad.RemoveFromSquad(self) // normally, if a squad member dies, other members become alerted. Removing them first resolves this
        DoEntFire("!self", "DropWeapon", "", 0, self, self) // without this, the weapon floats in midair
        DoEntFire("!self", "Kill", "", 0, self, self)
        DoEntFire("!self", "CreateSeparateRagdoll", "", 0, self, self)
    }
}


function ColorLerp()
{
    local _red = null
    local _grn = null

    if(alertlevel <= 0)
    {
        red = 0
        green = 255
    }
    else if (alertlevel >= 1)
    {
        red = 255
        green = 0
    }
    else
    {
        _red = alertlevel*255
        _grn = alertlevel*255
        red = clamp(_red.tointeger(), 0, 255) 
        green = clamp(255 - _grn.tointeger(), 0, 255)
    }
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
        else if(alertStage == AlertStage.Combat_Seen)
        {
            DoEntFire("sprite_sight_" + self.GetName(), "Color", "255" + " " + "0" + " " + "0", 0, self, self)
        }
        else
        {
            DoEntFire("sprite_sight_" + self.GetName(), "Color", red + " " + green + " " + "0", 0, self, self)
        }
    }   
}

/*
function Color_change(red, green)
{
    if(self.GetNPCState() == NPC_STATE_COMBAT)
    {
        DoEntFire(self.GetName() + "glow", "SetGlowColor", "255" + " " + "0" + " " + "0", 0, self, self)
    }
    else
    {
        if(alertlevel == 0)
        {
            DoEntFire(self.GetName() + "glow", "SetGlowColor", "0" + " " + "255" + " " + "0", 0, self, self)
        }
        else if(alertStage == AlertStage.Combat_Seen)
        {
            DoEntFire(self.GetName() + "glow", "SetGlowColor", "255" + " " + "0" + " " + "0", 0, self, self)
        }
        else
        {
            DoEntFire(self.GetName() + "glow", "SetGlowColor", red + " " + green + " " + "0", 0, self, self)
        }
    }   
}
*/

function OnPostSpawn()
{
    local ent = null
    //find all the waypoints associated with the npc
    for (local entity; entity = Entities.FindByName(entity, self.GetName() + "_wp*");)
    {
        //printl(entity)
        waypoints.append(entity)
    }
    //then immediately start patrolling
    patrolVar = PatrolVars.Walking
    EntFire("!self", "SetTarget", waypoints[0].GetName(), 0, self, self)
    //printl(self.GetName() + " is now going to " + waypoints[0].GetName())
}

local deadbody_inv = null
local maxBodySightDist = 512

function BodyCheck()
{
    if(!bodyhunt)
    {
        for(local ragdoll; ragdoll = Entities.FindByClassname(ragdoll, "prop_ragdoll");)
        {
            if(ragdoll.GetName() != "found_dead_body")
            {
                local vecDelta = ragdoll.GetOrigin() - self.EyePosition()
                vecDelta.z = 0
                vecDelta.Norm()

                local flDot = vecDelta.Dot(self.BodyDirection3D())

                local trace = TraceLineComplex(self.EyePosition(), ragdoll.GetOrigin(), self, MASK_BLOCKLOS, COLLISION_GROUP_NONE)

                local distance = (ragdoll.GetOrigin() - self.EyePosition()).Length()

                if(flDot > AI_SENSING_SAMPLE_CONE && !trace.DidHit() && distance < maxBodySightDist)
                {
                    deadbody_inv = ragdoll
                    saw_body = true
                    ragdoll.SetName("found_dead_body")
                    alertCoolDown = maxAlertCoolDown
                    self.GetScriptScope().foundbody = true // this is only set once. It will never be set to false if set to true
                    alertStage = AlertStage.Alert_Body
                }
            }
        }
    }
}

function Think() // handles rising sight meter
{
    local vecDelta = player.GetOrigin() - self.EyePosition()
    
    vecDelta.z = 0
    vecDelta.Norm()

    local flDot = vecDelta.Dot(self.BodyDirection3D())

    local trace = TraceLineComplex(self.EyePosition(), player.EyePosition(), self, MASK_BLOCKLOS, COLLISION_GROUP_NONE)
    
    local distance = (player.EyePosition() - self.EyePosition()).Length()

    local dleft = (self.GetOrigin()-waypoints[currentWayPointIndex].GetOrigin()).Length()
    //DoEntFire("debug_" + self.GetName(), "SetMessage", "AlertStage: " + alertStage + " & " + "cautioncooldown: " + self.GetScriptScope().cautionCoolDown, 0, null, null)
    //DoEntFire("debug1_" + self.GetName(), "SetMessage", "Schedule: " + self.GetSchedule() + " & " + "Combatcooldown: " + combatCoolDown, 0, null, null)

    //DoEntFire("debug_" + self.GetName(), "SetMessage", "AlertStage: " + alertStage + " & " + "alertlevel: " + alertlevel, 0, null, null)
    //DoEntFire("debug_" + self.GetName(), "SetMessage", "WaitTime: " + waitTime + " & " + "Distance: " + dleft, 0, null, null)
    //DoEntFire("debug_" + self.GetName(), "SetMessage", "CuriousCD: " + curiousCoolDown + " Schedule: " + self.GetSchedule() + " & " + "State: " + self.GetNPCState(), 0, null, null)

    if (flDot > AI_SENSING_SAMPLE_CONE && !trace.DidHit() && distance < maxSightDist)
    {
        playerInView = true
    }
    else
    {
        playerInView = false
    }

    if(self.GetScriptScope().foundbody)
    {
        raiseFactor = 1000
        lowerFactor = 0.15
        maxSightDist = 1280
        maxBodySightDist = 768
    }

    ColorLerp()
    BodyCheck()      // I saw a body
    //CalledToFollow() // My ally saw a body and they are calling me // this is hard to implement without a rework
    _UpdateSightAlertState(distance)
}

/*
function CalledToFollow()
{
    if(self.GetScriptScope().followbuddy != null)
    {
        alertStage = AlertStage.Follow_Called
        repatrol = true // remember to repatrol afterwards
    }
}
*/

function _UpdateSight(distance)
{
    if(playerInView)
    {
        local duckingfactor = 1
        if(player.GetFlags() & FL_DUCKING)
        {
            printl( "Player is crouching" )
            duckingfactor = 0.5
        }
        alertlevel = clamp(alertlevel + raiseFactor*duckingfactor*(DetectionBuildRate)*FrameTime()/distance, 0, 1)
    }
    else
    {
        alertlevel = clamp(alertlevel - lowerFactor*(DetectionBuildRate)*FrameTime(), 0, 1)
    }
}

function QuerySeeEntity()
{
    if(entity != player) // if you saw anything else besides the player, just behave as vanilla
    {
        return true
    }

    switch(alertStage)
    {
        case AlertStage.Idle_Peaceful:
            return false
        case AlertStage.Idle_Seen:
            return false
        case AlertStage.Alert_Seen:
            return false
        case AlertStage.Combat_Seen:
            return true
    }
    
}

function _UpdateSightAlertState(distance)
{
    switch(alertStage)
    {
        case AlertStage.Idle_Peaceful:
            _UpdateSight(distance)
            if(alertlevel >= 0.5 && alertlevel < 1)
            {
                fst_contact = true
                alertStage = AlertStage.Idle_Seen
            }
            else if (alertlevel >= 1 || self.GetNPCState() == NPC_STATE_COMBAT)
            {
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }  
        break

        case AlertStage.Idle_Seen:
            _UpdateSight(distance)
            if(alertlevel < 0.5 && curiousCoolDown <= 0)
            {
                alertStage = AlertStage.Idle_Peaceful
            }
            else if (alertlevel >= 1 || self.GetNPCState() == NPC_STATE_COMBAT)
            {
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }
        break

        case AlertStage.Idle_Heard_World:
            _UpdateSight(distance)
            if(alertlevel >= 1 || self.GetNPCState() == NPC_STATE_COMBAT)
            {
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }
            else if(alertlevel < 0.5 && self.GetSchedule() != "SCHED_INVESTIGATE_SOUND")
            {
                alertStage = AlertStage.Idle_Peaceful
            }
            else if(alertlevel >= 0.5)
            {
                fst_contact = true
                alertStage = AlertStage.Idle_Seen
            }
        break

        case AlertStage.Idle_Heard_Player:
            _UpdateSight(distance)
            if(alertlevel >= 1 || self.GetNPCState() == NPC_STATE_COMBAT)
            {
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }
            else if(alertlevel < 0.5 && self.GetSchedule() != "SCHED_ALERT_FACE_BESTSOUND")
            {
                alertStage = AlertStage.Idle_Peaceful
            }
            else if(alertlevel >= 0.5)
            {
                fst_contact = true
                alertStage = AlertStage.Idle_Seen
            }
        break

        /*
        case AlertStage.Alert_Heard_Combat:
            
            _UpdateSight(distance)
            if(alertlevel >= 1)
            {
                alertStage = AlertStage.Combat_Seen
            }
            else if(alertlevel < 0.5 && self.GetSchedule() != "SCHED_INVESTIGATE_SOUND")
            {
                alertStage = AlertStage.Idle_Peaceful
            }
            else if(alertlevel >= 0.5)
            {
                fst_contact = true
                alertStage = AlertStage.Alert_Seen
            }
        break
        */

        case AlertStage.Alert_Seen:
            _UpdateSight(distance)
            if (alertlevel >= 1 || self.GetNPCState() == NPC_STATE_COMBAT)
            {
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }
            if(alertlevel < 0.5 && alertCoolDown <= 0)
            {
                alertStage = AlertStage.Idle_Peaceful
            }
        break

        case AlertStage.Alert_Body:
            _UpdateSight(distance)
            if(alertlevel >= 1 || self.GetNPCState() == NPC_STATE_COMBAT)
            {
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }
            if(alertlevel < 0.5 && alertCoolDown <= 0)
            {
                alertStage = AlertStage.Idle_Peaceful
            }
        break

        case AlertStage.Combat_Seen:
            _UpdateSight(distance)
            if(combatCoolDown <= 0)
            {
                fst_caut = true
                alertStage = AlertStage.Caution_Investigate
            }
        break
        case AlertStage.Caution_Investigate:
            _UpdateSight(distance)
            if(alertlevel >= 0.5) // I removed the NPC_STATE_COMBAT condition, because I think this is forcing the NPC to go back to combat_see
            {                     // A cleaner implementation might be necessary, like whether or not they or their squadmates saw the player.
                fst_player = true
                alertStage = AlertStage.Combat_Seen
            }
            if(self.GetScriptScope().cautionCoolDown <= 0)
            {
                alertStage = AlertStage.Idle_Peaceful
            }
        break
    }
    _UpdateSchedule()
}

function QueryHearSound()
{
    if(sound.SoundType() & (SOUND_BULLET_IMPACT))
    {
        return false
    }

    if(sound.SoundType() & (SOUND_COMBAT))
    {
        if(sound.Volume() == 1024) // don't do anything if you hear a fleshy body is attacked
        {
            return false
        }
        if(alertStage != AlertStage.Combat_Seen)
        {
            fst_player = true
            alertStage = AlertStage.Combat_Seen // I am just going to make the assumption that if the 
                                            // player is going to fire a loud weapon, they intend to be in combat
        }
        
        _UpdateSchedule()
    }

    /*
    if(sound.SoundType() & (SOUND_THUMPER))
    {
        
    }
    */

    if(sound.SoundType() & (SOUND_DANGER)) 
    {                          
        if(alertStage != AlertStage.Combat_Seen)
        {
            fst_player = true
            alertStage = AlertStage.Combat_Seen // I am just going to make the assumption that if the 
                                            // player is going to fire a loud weapon, they intend to be in combat
        }
        _UpdateSchedule()
    }

    if(sound.SoundType() & (SOUND_WORLD))
    {
        if(alertStage == AlertStage.Idle_Peaceful)
        {
            alertStage = AlertStage.Idle_Heard_World
            repatrol = true
            self.SetSchedule("SCHED_INVESTIGATE_SOUND")
            _UpdateSchedule()
        }
    }

    if(sound.SoundType() & (SOUND_PLAYER))
    {
        if(alertStage == AlertStage.Idle_Peaceful || alertStage == AlertStage.Idle_Heard_World || alertStage == AlertStage.Alert_Body)
        {
            alertStage = AlertStage.Idle_Heard_Player
            repatrol = true
            self.SetSchedule("SCHED_ALERT_FACE_BESTSOUND")
            _UpdateSchedule()
        }
    }
}

function _UpdateSchedule()
{
    switch(alertStage)
    {
        case AlertStage.Idle_Peaceful:
        actionState = ActionState.Idle_Patrol
        break

        case AlertStage.Idle_Seen:
        actionState = ActionState.Idle_Approach_Seen
        break

        case AlertStage.Idle_Heard_World:
        actionState = ActionState.Idle_Approach_Heard_World
        break

        case AlertStage.Idle_Heard_Player:
        actionState = ActionState.Idle_Approach_Heard_Player
        break

        //case AlertStage.Alert_Heard_Combat:
        //actionState = ActionState.Combat_Action
        //break

        case AlertStage.Alert_Seen:
        actionState = ActionState.Alert_Approach_Seen
        break

        case AlertStage.Alert_Body:
        actionState = ActionState.Alert_Approach_Body
        break

        case AlertStage.Combat_Seen:
        actionState = ActionState.Combat_Action
        break

        case AlertStage.Caution_Investigate:
        actionState = ActionState.Caution_Hunt
        break

        case AlertStage.Follow_Called:
        actionState = ActionState.Follow_Buddy
        break
    }
    _UpdateAction()
}

function _UpdateAction()
{
    switch(actionState)
    {
        case ActionState.Idle_Patrol:
            if(repatrol)
            {
                repatrol = false
                DoEntFire("!self","SetTarget",waypoints[currentWayPointIndex].GetName(),0,self,self)
            }
            else
            {
                if(patrolVar == PatrolVars.Walking)
                {
                    if((self.GetOrigin()-waypoints[currentWayPointIndex].GetOrigin()).Length() < 8) // in game this is the distance between the npc and the node when npc is on top of the node
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

        case ActionState.Idle_Approach_Seen:
            if(fst_contact) // fst_contact should be the setup
            {
                DoEntFire(self.GetName() + "weaponcock", "PlaySound", "",0,null,null)
                playerpos.SetOrigin(player.GetOrigin())
                self.ClearSchedule("SCHED_IDLE_WALK")
                self.ClearSchedule("SCHED_INVESTIGATE_SOUND")
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
                        if(playerInView) // update player position and movement if within LOS
                        {
                            playerpos.SetOrigin(player.GetOrigin()) 
                            curiousCoolDown = maxCuriousCoolDown
                        }
                        
                        if(self.GetActivity() == "ACT_IDLE") // if npc is currently not moving, implying it has reached its destination
                        {
                            curiousCoolDown -= 7*FrameTime()
                        }
                        
                        if(curiousCoolDown <= 0)
                        {
                            repatrol = true
                            DoEntFire(self.GetName() + "aifollow", "Deactivate", "",0,self,self)
                        }
                    }
                }
            }
        break

        case ActionState.Alert_Approach_Seen:
            /*

            if(fst_contact) // fst_contact should be the setup
            {
                DoEntFire(self.GetName() + "weaponcock", "PlaySound", "",0,null,null)
                playerpos.SetOrigin(player.GetOrigin())
                self.ClearSchedule("SCHED_INVESTIGATE_SOUND")
                alertCoolDown = maxAlertCoolDown
                DoEntFire(self.GetName() + "aifollow", "Activate", "",0,self,self)
                fst_contact = false
            }
            else
            {
                if(playerInView)
                {
                    playerpos.SetOrigin(player.GetOrigin()) // hmm... this doesn't seem to work
                    alertCoolDown = maxAlertCoolDown
                }
                if(self.GetActivity() != "ACT_RUN") // if npc is currently not moving, implying it has reached its destination
                {
                    alertCoolDown -= 7*FrameTime()
                }
                if(alertCoolDown <= 0)
                {
                    repatrol = true
                    DoEntFire(self.GetName() + "aifollow", "Deactivate", "",0,self,self)
                    DoEntFire(self.GetName() + "aifollow", "Kill", "",0,self,self)
                    DoEntFire(self.GetName() + "playercornerpath", "Kill", "",0,self,self)
                }
            }
            */
        break

        case ActionState.Idle_Approach_Heard_World:

        break

        case ActionState.Idle_Approach_Heard_Player:

        break

        case ActionState.Alert_Approach_Heard_Combat:

        break

        case ActionState.Alert_Approach_Body:

            if(saw_body) // fst_contact should be the setup
            {
                DoEntFire(self.GetName() + "weaponcock", "PlaySound", "",0,null,null)
                playerpos.SetOrigin(deadbody_inv.GetOrigin())
                self.ClearSchedule("SCHED_INVESTIGATE_SOUND")
                alertCoolDown = maxAlertCoolDown
                DoEntFire(self.GetName() + "aifollow", "Activate", "",0,self,self)
                saw_body = false

                /*
                buddy = Entities.FindByClassnameNearest(self.GetClassname(),self.GetOrigin(),1024)
                if(buddy != null)
                {
                    buddy.GetScriptScope().followbuddy = self.GetName()
                }
                */
            }

            if(self.GetActivity() == "ACT_IDLE") // if npc is currently not moving, implying it has reached its destination
            {
                alertCoolDown -= 7*FrameTime()
            }

            if(alertCoolDown <= 0)
            {
                repatrol = true
                DoEntFire(self.GetName() + "aifollow", "Deactivate", "",0,self,self)

                /*
                if(buddy != null)
                {
                    buddy.GetScriptScope().followbuddy = null
                }
                */
            }
            
        break

        case ActionState.Combat_Action:
            self.GetScriptScope().foundbody = true
            local mySquad = self.GetSquad()
            if(fst_player)
            {
                DoEntFire(self.GetName() + "aifollow", "Deactivate", "",0,self,self) // if it happens to be following anything, deactivate
                combatCoolDown = maxCombatCoolDown
                EntFire("!self","UpdateEnemyMemory","!player",0,null,null)
                fst_player = false
            }

            /*
            if(playerInView || self.HasCondition("COND_HEAR_DANGER") == true || self.HasCondition("COND_HEAR_COMBAT") == true)
            //got to make sure I can only start increasing if there is no other danger present
            {
                if(playerInView)
                {
                    playerpos.SetOrigin(player.GetOrigin()) // only change the position of the ai follower if you saw the player
                }
                self.GetScriptScope().timesawenemy = 0
            }
            */
            if(playerInView)
            {
                playerpos.SetOrigin(player.GetOrigin()) // only change the position of the ai follower if you saw the player
                self.GetScriptScope().timesawenemy = 0
            }
            else
            {
                self.GetScriptScope().timesawenemy += 10*FrameTime()
                //this makes some sense, since timesawenemy can only reach a maximum of maxCombatCoolDown units of time, in which otherwise it would have moved on to the next state
                //generally speaking, the soldier we want to investigate the player's position will be the one where timesawenemy - combatCoolDown = maxCombatCoolDown
                //however it is possible for combatCoolDown to be maximum while timesawenemy has not reset to 0 for even the last soldier that saw it (the intended soldier to hunt)
                //this is due to combatCoolDown being maxCombatCoolDown because it heard danger or combat or its squad members heard danger or combat even though it didn't see the player
                //during the hunting stage therefore, no one will hunt, since all of their timesawenemy will be more than the maxCombatCoolDown
                //this isn't really a bug but is worth addressing. I tried to add cond_hear_combat and danger but it doesn't seem to go down
                //if all else fails and one really wants an investigation, it would simply be best to grab everyone's timesawenemy and do a quicksort then
            }

            local lostPlayer = 0
            for(local member = 0; member < mySquad.NumMembers(true); member++)
            {
                //if any of my squadmates haven't seen the player (including myself)
                //increase by 1
                if(mySquad.GetMember(member).HasCondition("COND_SEE_ENEMY") == false && mySquad.GetMember(member).IsAlive())
                {
                    lostPlayer++
                }
                //otherwise if at least one of my teammates have seen them
                //then make sure I am fully in combat
                if(mySquad.GetMember(member).HasCondition("COND_SEE_ENEMY") == true || 
                   mySquad.GetMember(member).HasCondition("COND_HEAR_DANGER") == true ||
                   mySquad.GetMember(member).HasCondition("COND_HEAR_COMBAT") == true ||
                   self.HasCondition("COND_HEAR_DANGER") == true ||
                   self.HasCondition("COND_HEAR_COMBAT") == true)
                {
                    combatCoolDown = maxCombatCoolDown
                    break
                }
            }
            if(lostPlayer == mySquad.NumMembers(true)) //if none of my squadmates have seen the player, begin cooldown
            {
                if(combatCoolDown > 0)
                {
                    combatCoolDown = clamp(combatCoolDown - 10*FrameTime(), 0, maxCombatCoolDown)
                }
            }
            if(combatCoolDown <= 0)
            {
                alertlevel = 0 // this seems like a really bad idea...
                EntFire(self.GetName(), "ForgetEntity", "!player",0,null,null)
                self.SetSchedule("SCHED_NONE")
                self.GetScriptScope().cautionCoolDown = maxCautionCoolDown
            }
        break

        case ActionState.Caution_Hunt:
            local mySquad = self.GetSquad()
            if(fst_caut)
            {
                no_one_saw10 = 0
                fst_caut = false
                self.ClearSchedule("SCHED_COMBINE_PATROL")
                self.SetSchedule("SCHED_NONE")
                for(local member = 0; member < mySquad.NumMembers(true); member++)
                {
                    if(mySquad.GetMember(member).ValidateScriptScope() && ("timesawenemy" in mySquad.GetMember(member).GetScriptScope()))
                    {
                        printl(mySquad.GetMember(member) + ": " + mySquad.GetMember(member).GetScriptScope().timesawenemy)
                        if((mySquad.GetMember(member).GetScriptScope().timesawenemy-combatCoolDown).tointeger() == maxCombatCoolDown)
                        {
                            member_hunt = member // i need to tell the other squad members who is the one investigating
                            if(self.GetName() == mySquad.GetMember(member).GetName())
                            {
                                should_hunt = true
                                printl(self.GetName() + " shall hunt")
                                DoEntFire(self.GetName() + "aifollow", "Activate", "",0,self,self)
                            }
                            else
                            {
                                should_hunt = false
                            }
                            break
                        }
                        else  // no one saw the player in the last 10 units of time 
                        {
                            printl(self.GetName() + " did not see")
                            no_one_saw10++
                        }
                    }
                }
            }

            if(no_one_saw10 == mySquad.NumMembers(true)) // if no one saw the player the last 10 units of time
            {                                            // I need to account for the fact that it is possible everyone that could have seen the 
                                                         // player is dead and they haven't, but their cooldown still needs to happen.
                self.GetScriptScope().cautionCoolDown -= 10*FrameTime()
                if(self.GetScriptScope().cautionCoolDown <= 0)
                {
                    repatrol = true
                }
            }
            else if(should_hunt)
            {
                if(!self.IsMoving()) // || self.GetSchedule() == "SCHED_FOLLOW"
                {
                    self.GetScriptScope().cautionCoolDown -= 10*FrameTime()
                }
                
                if(self.GetScriptScope().cautionCoolDown <= 0)
                {
                    repatrol = true
                    DoEntFire(self.GetName() + "aifollow", "Deactivate", "",0,self,self)
                }
            }
            else
            {
                if(mySquad.GetMember(member_hunt).GetScriptScope().cautionCoolDown <= 0)
                {
                    self.GetScriptScope().cautionCoolDown = 0
                    repatrol = true
                }
            }
        break
        case ActionState.Follow_Buddy:
        /*
            aifollow.GetScriptScope().goal = self.GetScriptScope().followbuddy
            DoEntFire(self.GetName() + "aifollow", "Activate", "",0,self,self)
        */
        break
    }
}

/*
local ai_rallypnt = SpawnEntityFromTable("assault_rallypoint"
            {
                targetname = self.GetName() + "rally"
                assaultpoint = self.GetName() + "assault"
                origin = deadbody_inv.GetOrigin()
            })

            local ai_assaultpnt = SpawnEntityFromTable("assault_assaultpoint"
            {
                targetname = self.GetName() + "assault"
                origin = deadbody_inv.GetOrigin()
            })

            if(saw_body) // fst_contact should be the setup
            {
                DoEntFire(self.GetName() + "weaponcock", "PlaySound", "",0,null,null)
                ai_assaultpnt.SetOrigin(deadbody_inv.GetOrigin())
                self.ClearSchedule("SCHED_INVESTIGATE_SOUND")
                alertCoolDown = maxAlertCoolDown
                DoEntFire(self.GetName(), "Assault", "",0,self,self)
                saw_body = false
            }

            if(self.GetActivity() == "ACT_IDLE") // if npc is currently not moving, implying it has reached its destination
            {
                alertCoolDown -= 7*FrameTime()
            }

            if(alertCoolDown <= 0)
            {
                repatrol = true
                DoEntFire(self.GetName() + "rally", "Kill", "",0,self,self)
                DoEntFire(self.GetName() + "assault", "Kill", "",0,self,self)
            }
*/