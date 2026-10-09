local dropLocation = null
local pickup = false
local wasthrown = false

function Thinky()
{
    ListenToGameEvent("player_use", function(ev)
    {
        local heldobject = GetPlayerHeldEntity(player) // tag the object to be processed
        if(heldobject != null)
        {
            heldobject.AddOutput("OnPhysGunPickup", "physics_sound_logic_script", "CallScriptFunction", "BeingPickedUp", 0, 0)
            heldobject.AddOutput("OnPhysGunDrop", "physics_sound_logic_script", "CallScriptFunction", "CoordinatesOnDrop", 0, 0)
            local objectScope = heldobject.GetOrCreatePrivateScriptScope();
            objectScope.VPhysicsCollision <- function()
            {
                if(!pickup && wasthrown)
                {
                    if(entity.GetClassname() == "npc_combine_s")
                    {
                        wasthrown = false
                        printl("I hit a combine soldier")
                    }
                    else
                    {
                        wasthrown = false
                        //local collisionLocation = heldobject.GetOrigin()
                        //local distance = (dropLocation-collisionLocation).Length()

                        if(speed > 200)
                        {
                            local soundemitter = SpawnEntityFromTable("ai_sound",
                            {
                                origin = heldobject.GetOrigin()
                                duration = 0.5
                                soundcontext = SOUND_CONTEXT_REACT_TO_SOURCE 
                                soundtype = SOUND_WORLD                    
                                targetname = "ai_sound_emitter"
                                volume = 300
                            })
                            printl("I am very loud right now")
                            DoEntFire("ai_sound_emitter", "EmitAISound", "", 0, null, null)
                            DoEntFire("ai_sound_emitter", "Kill", "", 1, null, null)
                        }
                    }
                }
            }
            //printl("Player is holding " + heldobject)
        }
    },"")
}

function BeingPickedUp()
{
    //printl("Object being picked up by player")
    pickup = true
}

function CoordinatesOnDrop()
{
    //printl("Object dropped by player")
    wasthrown = true
    pickup = false
}

