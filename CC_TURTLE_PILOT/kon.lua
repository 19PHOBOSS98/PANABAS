
shipControl=peripheral.find("shipControlInterface")

local flight_utilities = require "lib.flight_utilities"
local pidcontrollers = require "lib.pidcontrollers"
local getLocalPositionError = flight_utilities.getLocalPositionError
local quaternion = require "lib.quaternions"
local clamp_vector3 = utilities.clamp_vector3
--CONFIGURABLES--
local ion_thrusters_count = { --number of thrusters pointing in each cardinal direction
    pos=vector.new(2,2,2),
    neg=vector.new(2,2,2)
}
local target_aim = vector.new(0,-0.707,-0.707)--point local Z axis
local target_global_pos = vector.new(14,10,14) -- fly to world coordinates


local ionThrust_config = 4
local ion_thruster_base_force = ionThrust_config*100000
local global_gravity_vector = vector.new(0,-9.8,0)
--CONFIGURABLES--

local mass = ship.getMass()

local net_base_thrust = {
    pos=vector.new(0,0,0),
    neg=vector.new(0,0,0)
}
net_base_thrust.pos = ion_thrusters_count.pos*ion_thruster_base_force
net_base_thrust.neg = ion_thrusters_count.neg*ion_thruster_base_force

local pos_PID_settings = {
    P=0.04,
    I=0.001,
    D=0.05,
    clamp_value = {min=-1,max=1},
}
local pos_PID = pidcontrollers.PID_Discrete_Vector(	pos_PID_settings.P,
                                                    pos_PID_settings.I,
                                                    pos_PID_settings.D,
                                                    pos_PID_settings.clamp_value.min,
                                                    pos_PID_settings.clamp_value.max)

local run_firmware = true

function resetPeripherals()
    shipControl.setMovement(0,0,0)
end

function checkInterupt()
	while run_firmware do
		local event, key, isHeld = os.pullEvent("key")
		if (key == keys.q) then
			resetPeripherals()
            run_firmware = false
			return
		end
	end
end

function flightLoop()
	while run_firmware do
        local rot = shipControl.getRotation()
        rot = quaternion.new(rot.w,rot.x,rot.y,rot.z)
        local target_y = Quaternion.rotateVectorByAxis(rot:localPositiveY(),rot:localPositiveZ(),-45)
        local new_rot = quaternion.fromToRotation(target_y, vector.new(0,1,0))*rot
        new_rot = quaternion.fromToRotation(new_rot:localPositiveZ(), target_aim)*new_rot
        shipControl.setRotation(new_rot[2],new_rot[3],new_rot[4],new_rot[1])

        local curr_pos = shipControl.getPosition()
        curr_pos = vector.new(curr_pos.x,curr_pos.y,curr_pos.z)
        local curr_rot = shipControl.getRotation()
        curr_rot = quaternion.new(curr_rot.w,curr_rot.x,curr_rot.y,curr_rot.z)
        local position_error = getLocalPositionError(target_global_pos,curr_pos,curr_rot)
        print("err",textutils.serialise(position_error))
        local pid_local_linear_power_percentage = pos_PID:run(position_error)
        local local_gravity_acceleration = curr_rot:inv():rotateVector3(global_gravity_vector)
        local local_inv_gravity_force = -local_gravity_acceleration*mass
        local net_power_percentage = local_inv_gravity_force
        local percentage_coefficients = vector.new(0,0,0)
        
        if(local_inv_gravity_force.x>=0) then
            percentage_coefficients.x = 1/net_base_thrust.pos.x
        elseif(local_inv_gravity_force.x<0)then
            percentage_coefficients.x = 1/net_base_thrust.neg.x
        end
        
        if(local_inv_gravity_force.y>=0)then
            percentage_coefficients.y = 1/net_base_thrust.pos.y
        elseif(local_inv_gravity_force.y<0)then
            percentage_coefficients.y = 1/net_base_thrust.neg.y
        end

        if(local_inv_gravity_force.z>=0)then
            percentage_coefficients.z = 1/net_base_thrust.pos.z
        elseif(local_inv_gravity_force.z<0)then
            percentage_coefficients.z = 1/net_base_thrust.neg.z
        end
        net_power_percentage.x = net_power_percentage.x*percentage_coefficients.x
        net_power_percentage.y = net_power_percentage.y*percentage_coefficients.y
        net_power_percentage.z = net_power_percentage.z*percentage_coefficients.z
        net_power_percentage = net_power_percentage + pid_local_linear_power_percentage
        print("net_power_percentage",textutils.serialise(net_power_percentage))
        net_power_percentage = clamp_vector3(net_power_percentage,-1,1)
        shipControl.setMovement(net_power_percentage.x,net_power_percentage.y,net_power_percentage.z)--check if controlBlock is facing the right way (towards +X axis)

        os.sleep(0.05)
    end
end

local threads = {
    function()
        flightLoop()
    end,
    function()
        checkInterupt()
    end,
}

function run()
	parallel.waitForAny(unpack(threads))
end

run()