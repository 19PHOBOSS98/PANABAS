--[[
	DEBUGGER:
	Used to debug drones
	set DRONE_ID to the drone to be debugged

	keyBinds:
	"h" shutdown drone remotely
	"r" restart drone remotely
	"t" restart all drones in list
	"i" initialize hound pack
]]--

local quaternion = require "lib.quaternions"

modem = peripheral.find("modem")
rednet.open("back")


local DEBUG_TO_DRONE_CHANNEL = 9
local DRONE_TO_DEBUG_CHANNEL = 10
local REMOTE_TO_DRONE_CHANNEL = 7
local DRONE_TO_REMOTE_CHANNEL = 8
modem.open(DRONE_TO_DEBUG_CHANNEL)
modem.open(DRONE_TO_REMOTE_CHANNEL)

local DEBUG_THIS_DRONE = "45"

local DRONE_IDs = {
	"45"
	}

local ORBIT_FORMATION = {
	vector.new(-30,5,80),

}

function initDrones()
	for i,id in ipairs(DRONE_IDs) do
		transmit("orbit_offset",ORBIT_FORMATION[i],id)
		transmit("activate_defense_system",nil,id)
	end
	print("initialized Panabas")
end



function transmit(cmd,drone_id)
	modem.transmit(DEBUG_TO_DRONE_CHANNEL, DRONE_TO_DEBUG_CHANNEL,
	{drone_id=drone_id,msg={cmd=cmd,args=nil}})
end

function transmit(cmd,args,drone_id)
	modem.transmit(DEBUG_TO_DRONE_CHANNEL, DRONE_TO_DEBUG_CHANNEL,
	{drone_id=drone_id,msg={cmd=cmd,args=args}})
end

function transmitAsRC(cmd,args,drone_id)
	modem.transmit(REMOTE_TO_DRONE_CHANNEL, DRONE_TO_REMOTE_CHANNEL,
	{drone_id=drone_id,msg={cmd=cmd,args=args}})
end
local toggle_run_mode = true


local movement_key_tracker = {
								w=false,
								a=false,
								s=false,
								d=false,
								space=false,
								leftShift=false,}
local movement_key_tracker = {
								q=false,
								e=false,
								r=false,
								f=false,
								z=false,
								c=false}

local keyDown = {
	[keys.h] = function ()
		transmit("hush",nil,DEBUG_THIS_DRONE)
		transmit("HUSH",nil,DEBUG_THIS_DRONE)
		transmit("deactivate_defense_system",nil,DEBUG_THIS_DRONE)
		print("hush drone: ",DEBUG_THIS_DRONE)
	end,
	[keys.y] = function ()
		transmit("restart",nil,DEBUG_THIS_DRONE)
		print("restarted drone: ",DEBUG_THIS_DRONE)
	end,
	[keys.i] = function ()
		initDrones()
	end,
	[keys.k] = function ()
		for i,id in ipairs(DRONE_IDs) do 
			transmit("restart",nil,id)
			print("restarted drone: ",id)
		end
		os.sleep(1)
		initDrones()
	end,
	[keys.o] = function ()
		for i,id in ipairs(DRONE_IDs) do
			transmit("deactivate_defense_system",nil,id)
		end
		print("defense_systems: deactivated")
	end,
	[keys.l] = function ()
		for i,id in ipairs(DRONE_IDs) do
			transmit("activate_defense_system",nil,id)
		end
		print("defense_systems: activated")
	end,
	
	[keys.p] = function ()
		transmit("run_mode",toggle_run_mode,DEBUG_THIS_DRONE)
		print("run_mode: ",toggle_run_mode," ",DEBUG_THIS_DRONE)
		toggle_run_mode = not toggle_run_mode
	end,
	[keys.b] = function ()
		print("toggling blade_mode")
		transmit("blade_mode",toggle_run_mode,DEBUG_THIS_DRONE)
	end,
	[keys.g] = function ()
		print("toggling axe_mode")
		transmitAsRC("axe_mode",nil,DEBUG_THIS_DRONE)
	end,
	-- [keys.o] = function ()
	-- 	print("transmittingAsRC")
	-- 	transmitAsRC("get_settings_info",nil,DEBUG_THIS_DRONE)
	-- end,
	-- [keys.l] = function (arguments)
	-- 	os.reboot()
	-- end,
	
	[keys.w] = function ()
		movement_key_tracker.w = true
	end,
	[keys.a] = function ()
		movement_key_tracker.a = true
	end,
	[keys.s] = function ()
		movement_key_tracker.s = true
	end,
	[keys.d] = function ()
		movement_key_tracker.d = true
	end,
	[keys.space] = function ()
		movement_key_tracker.space = true
	end,
	[keys.leftShift] = function ()
		movement_key_tracker.leftShift = true
	end,
	[keys.q] = function ()
		movement_key_tracker.q = true
	end,
	[keys.e] = function ()
		movement_key_tracker.e = true
	end,
	[keys.r] = function ()
		movement_key_tracker.r = true
	end,
	[keys.f] = function ()
		movement_key_tracker.f = true
	end,
	[keys.z] = function ()
		movement_key_tracker.z = true
	end,
	[keys.c] = function ()
		movement_key_tracker.c = true
	end,
	default = function (key)
		print(keys.getName(key), "key not bound")
	end,
}

function keyPress()
	while true do
		local event, key, isHeld = os.pullEvent("key")
		if keyDown[key] then
			keyDown[key]()
		else
			keyDown["default"](key)
		end
	end
end

local keyUp = {
	[keys.w] = function ()
		movement_key_tracker.w = false
	end,
	[keys.a] = function ()
		movement_key_tracker.a = false
	end,
	[keys.s] = function ()
		movement_key_tracker.s = false
	end,
	[keys.d] = function ()
		movement_key_tracker.d = false
	end,
	[keys.space] = function ()
		movement_key_tracker.space = false
	end,
	[keys.leftShift] = function ()
		movement_key_tracker.leftShift = false
	end,
	[keys.q] = function ()
		movement_key_tracker.q = false
	end,
	[keys.e] = function ()
		movement_key_tracker.e = false
	end,
	[keys.r] = function ()
		movement_key_tracker.r = false
	end,
	[keys.f] = function ()
		movement_key_tracker.f = false
	end,
	[keys.z] = function ()
		movement_key_tracker.z = false
	end,
	[keys.c] = function ()
		movement_key_tracker.c = false
	end,
	default = function (key)
		--print(keys.getName(key), "key not bound")
	end,
}

function keyRelease()
	while true do
		local event, key = os.pullEvent("key_up")
		if keyUp[key] then
			keyUp[key]()
		else
			keyUp["default"](key)
		end
	end
end

local moveVectorLinear={
	["a"] = vector.new(0,0,1),
	["s"] = vector.new(1,0,0),
	["d"] = vector.new(0,0,-1),
	["w"] = vector.new(-1,0,0),--the ship is built facing -X
	["space"] = vector.new(0,1,0),
	["leftShift"] = vector.new(0,-1,0),
}

local moveVectorAngular={
	--yaw
	["q"] = vector.new(0,1,0),
	["e"] = vector.new(0,-1,0),
	--pitch (it's centered on the z axis because the ship is actually built facing -X)
	["r"] = vector.new(0,0,1),
	["f"] = vector.new(0,0,-1),
	--roll
	["z"] = vector.new(1,0,0),
	["c"] = vector.new(-1,0,0),
}


function transmitMovement()
	while true do
		local net_move = {linear=vector.new(0,0,0), angular=vector.new(0,0,0)}
		for key,pressed in pairs(movement_key_tracker) do
			if(pressed) then
				if(moveVectorLinear[key]) then
					net_move.linear = net_move.linear + moveVectorLinear[key]
				elseif(moveVectorAngular[key]) then
					net_move.angular = net_move.angular + moveVectorAngular[key]
				end
			end
		end
		net_move.linear = net_move.linear:length()~=0 and net_move.linear:normalize() or vector.new(0,0,0)
		transmitAsRC("move",net_move,DEBUG_THIS_DRONE)
		sleep(0)
	end
end

function listen()
	while true do
		local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
		term.clear()
		term.setCursorPos(1,1)
		print(senderChannel)
		if message then
			print(textutils.serialize(message))
		end
	end
end

--parallel.waitForAny(listen,keyPress,keyRelease,movement)
parallel.waitForAny(listen,keyPress,keyRelease,transmitMovement)