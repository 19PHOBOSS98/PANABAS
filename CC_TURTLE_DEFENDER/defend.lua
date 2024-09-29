local wand = peripheral.find("wand")
local modem = peripheral.find("modem")
local quaternion = require "lib.quaternions"
local HexPatterns = require "lib.hexTweaks.HexPatterns"

local IOTAS = HexPatterns.IOTAS
local Hex = HexPatterns(wand)

local MAX_SPELL_RANGE = 32

local FILTER_PUSH_ONLY = {-- true to keep in scan; false to remove from scan. Is false by default if not in list
    ["PHO"]=false,
    ["username_here"]=false,
    ["Seat"]=false,
    ["entity.vs_clockwork.sequenced_seat"]=false,
    ["entity.valkyrienskies.ship_mounting_entity"]=false,
    ["entity.kontraption.kontraption_ship_mounting_entity"]=false,
    ["Pitch Contraption"]=false,
    ["Cannon Carriage"]=false,
    ["Spell Projectile"]=true,
    
    ["Solid Shot"]=true,
    ["Armor Piercing (AP) Shot"]=true,
    ["Mortar Stone"]=true,
    ["Bag of GrapeShot"]=true,
    ["High Explosive (HE) Shell"]=true,
    ["Armor Piercing (AP) Shell"]=true,
    ["Shrapnel Shell"]=true,
    ["Fluid Shell"]=true,
    ["Smoke Shell"]=true,
    ["Drop Mortar Shell"]=true,
}

function filterScanPush(scan, i,j) -- Return true to keep the value, or false to discard it. Is false by default if not in list
    local key = scan[i].name
    if(string.find(key, "Autocannon Round") or string.find(key, "Shell")) then
        return true
    end
    return FILTER_PUSH_ONLY[key] == nil and false or FILTER_PUSH_ONLY[key]
end

function ArrayExtract(t, fnKeep)
    local j, n = 1, #t;
    local new_t={}
    for i=1,n do
        if (fnKeep(t, i, j)) then
            table.insert(new_t,t[i])
        end
    end
    return new_t;
end

local FILTER_BURN_AND_PUSH = {-- true to keep in scan; false to remove from scan. Is true by default if not in list
    ["PHO"]=false,
    ["username_here"]=false,
    ["Seat"]=false,
    ["entity.vs_clockwork.sequenced_seat"]=false,
    ["entity.valkyrienskies.ship_mounting_entity"]=false,
    ["entity.kontraption.kontraption_ship_mounting_entity"]=false,
    ["Pitch Contraption"]=true,
    ["Cannon Carriage"]=true,
    ["Spell Projectile"]=false,
    
    ["Solid Shot"]=false,
    ["Armor Piercing (AP) Shot"]=false,
    ["Mortar Stone"]=false,
    ["Bag of GrapeShot"]=false,
    ["High Explosive (HE) Shell"]=false,
    ["Armor Piercing (AP) Shell"]=false,
    ["Shrapnel Shell"]=false,
    ["Fluid Shell"]=false,
    ["Smoke Shell"]=false,
    ["Drop Mortar Shell"]=false,
}

function filterScanBurnAndPush(scan, i,j) -- Return true to keep the value, or false to discard it. Is true by default if not in list
    local key = scan[i].name
    if(string.find(key, "Autocannon Round") or string.find(key, "Shell")) then
        return false
    end
    return FILTER_BURN_AND_PUSH[key] == nil and true or FILTER_BURN_AND_PUSH[key]
end

--https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
--by Mitch McMabers
function ArrayRemove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

function activateEnergyShield(activate)
    redstone.setOutput("right",activate)
end

function pulseArmorRegen()
    redstone.setOutput("left",true)
    sleep(0.1)
    redstone.setOutput("left",false)
    sleep(0.1)
end

local FULL_MASS = 0

function checkArmorRegen()
    if (redstone.getOutput("right")) then
        local current_mass = ship.getMass()
        if (current_mass<FULL_MASS) then
            pulseArmorRegen()
        end
    end
end

function onInitialize()
    activateEnergyShield(true)
    sleep(1)
    pulseArmorRegen()
    sleep(1)
    FULL_MASS = ship.getMass()
    --print("FULL_MASS: ",FULL_MASS)
end

function onTerminate()
    activateEnergyShield(false)
end

function onPause()
    activateEnergyShield(false)
end



local position = ship.getShipyardPosition()
--[[
local DEFENDER_TURTLE_SHIPYARD_POSITION = vector.new(-28649431,85,12290066) -- found on specific ship
print(textutils.serialise(vector.new(position.x,position.y,position.z)))
print(textutils.serialise(vector.new(position.x,position.y,position.z) - DEFENDER_TURTLE_SHIPYARD_POSITION))
]]--
local CENTER_OFFSET = vector.new(-3.8482,4.2874,0.5032)
position = vector.new(position.x,position.y,position.z) + CENTER_OFFSET

local run_firmware = true
local active = false
function defend()
    while run_firmware do
        
        if (not active) then
            sleep(0)
            goto continue
        end
        checkArmorRegen()
        Hex:scanEntitiesInZone(position,MAX_SPELL_RANGE,IOTAS.getEntitiesInZone.non_item)
        local scan = wand.getStack()[1]
        
        if(#scan>0) then
            local scan_push_only = ArrayExtract(scan, filterScanPush)
            local scan_burn_and_push = ArrayRemove(scan, filterScanBurnAndPush)

            local ship_rotation = ship.getQuaternion()
            ship_rotation = quaternion.new(ship_rotation.w,ship_rotation.x,ship_rotation.y,ship_rotation.z)
            local rotated_offset = ship_rotation:rotateVector3(CENTER_OFFSET)
            local repel_center = ship.getWorldspacePosition()
            repel_center = vector.new(repel_center.x,repel_center.y,repel_center.z)
            repel_center = repel_center + rotated_offset
            
            if(#scan_push_only>0) then
                --print(textutils.serialise(scan_push_only))
                wand.clearStack()
                wand.pushStack(Hex:repelEntityIota(repel_center,10))
                wand.pushStack(scan_push_only)
                Hex:executePatternOnTable()
            end
            
            if(#scan_burn_and_push>0) then
                --print(textutils.serialise(scan_burn_and_push))
                wand.clearStack()
                wand.pushStack(Hex:repelandFireballEntityIota(repel_center,10,2))
                wand.pushStack(scan_burn_and_push)
                Hex:executePatternOnTable()
            end
        end
        
        wand.clearStack()
        ::continue::
    end
end

function protocols(msg)
	local command = msg.cmd
	command = command and tonumber(command) or command
	case =
	{
	["activate_defense_system"] = function (args)
        onInitialize()
		active = true
        print("Defense System Activated...")
	end,
    ["deactivate_defense_system"] = function (args)
        onPause()
		active = false
        print("Defense System Deactivated...")
	end,
    ["hush"] = function (args)
        onTerminate()
		run_firmware = false
	end,
    ["HUSH"] = function (args)
        onTerminate()
		run_firmware = false
	end,
    ["restart"] = function (args) --kill command
		onTerminate()
		os.reboot()
	end,
	 default = function ()
        if(command == "move") then
            return --ignore "move"
        end
		print(textutils.serialize(command)) 
		print("protocols: default case executed")
	end,
	}
	if case[command] then
	 case[command](msg.args)
	else
	 case["default"]()
	end
end

local DEBUG_TO_DRONE_CHANNEL = 9
local DRONE_TO_DEBUG_CHANNEL = 10
local REMOTE_TO_DRONE_CHANNEL = 7
local DRONE_TO_REMOTE_CHANNEL = 8
modem.open(DEBUG_TO_DRONE_CHANNEL)
modem.open(REMOTE_TO_DRONE_CHANNEL)
local DRONE_ID = ship.getId()
function receiveCommand()
	while run_firmware do
		local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
		if (senderChannel==REMOTE_TO_DRONE_CHANNEL or senderChannel==DEBUG_TO_DRONE_CHANNEL) then
			if (message) then
				if (tostring(message.drone_id) == tostring(DRONE_ID)) then
                    protocols(message.msg)
				end
			end
		end
	end
end

function checkInterupt()
	while run_firmware do
		local event, key, isHeld = os.pullEvent("key")
		if (key == keys.q) then
            run_firmware = false
			return
		end
	end
end

local threads = {
    function()
        defend()
    end,
    function()
        receiveCommand()
    end,
    function()
        checkInterupt()
    end,
}

function run()
	parallel.waitForAny(unpack(threads))
end

print("\nActive Defense System Online...")
run()