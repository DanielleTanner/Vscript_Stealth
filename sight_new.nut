enum AlertStage
{
    Idle_Peaceful,
    Idle_Seen,
    Idle_Heard_World,
    Idle_Heard_Player, // probably not gonna use this
    Alert_Heard_Combat,
    Alert_Seen,
    Combat_Seen
}

enum ActionState
{
    Idle_Patrol,
    Idle_Approach_Seen,
    Idle_Approach_Heard_World,
    Idle_Approach_Heard_Player, // probably not gonna use this
    Alert_Approach_Heard_Combat,
    Alert_Approach_Seen,
    Combat_Action
}

enum PatrolVars
{
    Walking,
    Waiting
}

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

DoEntFire("debug_" + self.GetName(), "SetParent", self.GetName(), 0, null, null)
//DoEntFire("debug_" + self.GetName(), "SetParentAttachment", "eyes", 0, null, null) 
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
    
    /// This code currently handles sound checking, as NPCs will run to check sounds
    if(activity == "ACT_RUN" && self.GetNPCState() == NPC_STATE_IDLE)
    {
        newactivity = "ACT_WALK_AIM"
    }
    
    else if(alertStage == AlertStage.Idle_Seen && activity == "ACT_WALK") 
    {
        newactivity = "ACT_WALK_AIM"
    }
    
    else if(alertStage == AlertStage.Idle_Seen && activity == "ACT_IDLE")
    {
        newactivity = "ACT_IDLE_ANGRY"
    }
    return newactivity
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
    red = clamp(_red.tointeger(), 0, 255) 
    green = clamp(255 - _grn.tointeger(), 0, 255)
    Color_change(red, green)
}

function ColorLerpLower()
{
    local _red = alertlevel*255
    local _grn = alertlevel*255
    red = clamp(255 - _red.tointeger(), 0, 255)
    green = clamp(_grn.tointeger(), 0, 255)
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

function OnPostSpawn()
{
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

function Think() // handles rising sight meter
{
    local vecDelta = player.GetOrigin() - self.EyePosition()
    
    vecDelta.z = 0
    vecDelta.Norm()

    local flDot = vecDelta.Dot(self.BodyDirection3D())

    local trace = TraceLineComplex(self.EyePosition(), player.EyePosition(), self, MASK_BLOCKLOS, COLLISION_GROUP_NONE)
    
    local distance = (player.EyePosition() - self.EyePosition()).Length()

    local dleft = (self.GetOrigin()-waypoints[currentWayPointIndex].GetOrigin()).Length()
    //DoEntFire("debug_" + self.GetName(), "SetMessage", "AlertStage: " + alertStage + " & " + "Distance: " + dleft, 0, null, null)
    DoEntFire("debug_" + self.GetName(), "SetMessage", "WaitTime: " + waitTime + " & " + "Distance: " + dleft, 0, null, null)
    //DoEntFire("debug_" + self.GetName(), "SetMessage", "CuriousCD: " + curiousCoolDown + " Schedule: " + self.GetSchedule() + " & " + "State: " + self.GetNPCState(), 0, null, null)

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
    _UpdateSightAlertState(distance)
}

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
}

local fst_contact = false
local repatrol = false

const maxCuriousCoolDown = 5
local curiousCoolDown = 0
const maxAlertCoolDown = 5
local alertCoolDown = 0

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
            else if (alertlevel >= 1)
            {
                alertStage = AlertStage.Combat_Seen
            }  
        break

        case AlertStage.Idle_Seen:
            _UpdateSight(distance)
            if(alertlevel < 0.5 && curiousCoolDown <= 0)
            {
                alertStage = AlertStage.Idle_Peaceful
            }
            else if (alertlevel >= 1)
            {
                alertStage = AlertStage.Combat_Seen
            }
        break

        case AlertStage.Idle_Heard_World:
            _UpdateSight(distance)
            if(alertlevel >= 1)
            {
                alertStage = AlertStage.Combat_Seen
            }
            else if(alertlevel < 0.5 && self.GetSchedule() != "SCHED_INVESTIGATE_SOUND")
            {
                alertStage = AlertStage.Idle_Peaceful
            }
        break

        case AlertStage.Alert_Seen:
            _UpdateSight(distance)
            if (alertlevel >= 1)
            {
                alertStage = AlertStage.Combat_Seen
            }
            if(alertlevel < 0.5 && alertCoolDown <= 0)
            {
                alertStage = AlertStage.Idle_Seen
            }
        break

        case AlertStage.Combat_Seen:
        break
    }
    _UpdateSchedule()
}

function QueryHearSound()
{
    if(sound.SoundType() & (SOUND_COMBAT))
    {
        return false
    }
    if(sound.SoundType() & (SOUND_PLAYER))
    {
        return false
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

        break

        case AlertStage.Combat_Seen:
        actionState = ActionState.Combat_Action
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

        case ActionState.Idle_Approach_Seen:
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

        case ActionState.Combat_Action:

        break
    }
}