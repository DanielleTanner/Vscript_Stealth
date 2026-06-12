self.AddOutput("OnPhysGunDrop", "!self", "CallScriptFunction", "CoordinatesOnDrop", 0, 0)
self.AddOutput("OnPhysGunPickup", "!self", "CallScriptFunction", "BeingPickedUp", 0, 0)

local dropLocation = self.GetOrigin()
local pickup = false
local wasthrown = false

function BeingPickedUp()
{
    pickup = true
}

function CoordinatesOnDrop()
{
    wasthrown = true
    pickup = false
    dropLocation = self.GetOrigin()
}

function VPhysicsCollision()
{
   if(!pickup && wasthrown)
    {
        wasthrown = false
        local collisionLocation = self.GetOrigin()
        local distance = (dropLocation-collisionLocation).Length()

        if(distance > 32)
        {
            local soundemitter = SpawnEntityFromTable("ai_sound",
            {
                origin = self.GetOrigin()
                duration = 0.5
                soundcontext = SOUND_CONTEXT_REACT_TO_SOURCE 
                soundtype = SOUND_WORLD                    
                targetname = "ai_sound_emitter"
                volume = 1000
            })
            DoEntFire("ai_sound_emitter", "EmitAISound", "", 0, null, null)
            DoEntFire("ai_sound_emitter", "Kill", "", 1, null, null)
            
        }
    }
}

function QueryHearSound()
{
    printl(sound.GetSoundOrigin())
}
