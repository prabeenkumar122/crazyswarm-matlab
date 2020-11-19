classdef Crazyswarm < handle
    %CRAZYSWARM Container for all crazyflies in a swarm. Allows to send
    %broadcasting commands to all crazyflies at once.
    
    properties (GetAccess='public', SetAccess='private')
        % Properties
        crazyflies
                
        % Services
        takeoffService
        landService
        goToService
    end
    
    methods
        function obj = Crazyswarm(crazyflies_yaml)
            %CRAZYSWARM Construct an instance of this class            
            obj.takeoffService = rossvcclient("/takeoff");
            obj.landService = rossvcclient("/land");
            obj.goToService = rossvcclient("/go_to");
            
            cfg = yaml.ReadYaml(convertStringsToChars(crazyflies_yaml));
            tfTree = rostf;

            obj.crazyflies = {};
            
            for crazyflie = cfg.crazyflies
                id = crazyflie{1}.id;
                obj.crazyflies{end+1} = Crazyflie(id, tfTree);
            end            
        end
        
       function delete(obj)
            %DELETE Delete the swarm object and all contained crazyflies.
            for cf = obj.crazyflies
                cf{1}.delete()
                clear cf
            end
        end
        
        function state = state(obj)
            %STATE Get state matrix of crazyswarm.
            n_cfs = length(obj.crazyflies);
            state = zeros(n_cfs, 6);  % Prealocate state matrix
            for i = 1:n_cfs
                cf = obj.crazyflies{i};
                state(i, 1:3) = cf.position;
                state(i, 4:6) = cf.velocity;
            end
        end
        
        
        function cmdPosition(obj, posVec, yawVec)
            %CMDPOSITION Sends a streaming command of absolute position and
            %yaw setpoint for each crazyflie in the swarm.
            n_cfs = length(obj.crazyflies);
            for i = 1:n_cfs
                pos = posVec(i, :);
                yaw = yawVec(i);
                obj.crazyflies{i}.cmdPosition(pos, yaw);
            end
        end
        
        function cmdVelocityWorld(obj, velVec, yawRateVec)
            %CMDVELOCITYWORLD Sends a streaming velocity-world controller
            %setpoint command for all crazyflies in the swarm.
            n_cfs = length(obj.crazyflies);
            for i = 1:n_cfs
                vel = velVec(i, :);
                yawRate = yawRateVec(i);
                obj.crazyflies{i}.cmdPosition(vel, yawRate);
            end
        end
        
        function cmdFullState(obj, posVec, velVec, accVec, yawVec, omegaVec)
            %CMDFULLSTATE Sends a streaming full-state controller setpoint
            %command for each crazyflie in the swarm.
            n_cfs = length(obj.crazyflies);
            for i = 1:n_cfs
                pos = posVec(i, :);
                vel = velVec(i, :);
                acc = accVec(i, :);
                yaw = yawVec(i);
                omega = omegaVec(i, :);
                obj.crazyflies{i}.cmdPosition(pos, vel, acc, yaw, omega);
            end
        end
               
        function takeoff(obj, targetHeight, duration, groupMask)
            %TAKEOFF Broadcasted takeoff - fly straight up, then hover indefinitely.
            if nargin < 4  || isempty(groupMask)
                groupMask = 0;
            end
            
            request = rosmessage(obj.takeoffService);
            request.Height    = targetHeight;
            request.Duration  = rosduration(duration);
            request.GroupMask = groupMask;
            
            call(obj.takeoffService, request);
        end
        
        function land(obj, targetHeight, duration, groupMask)
            %LAND Broadcasted landing - fly straight down. User must cut power after.
            if nargin < 4  || isempty(groupMask)
                groupMask = 0;
            end
            
            request = rosmessage(obj.landService);
            request.Height    = targetHeight;
            request.Duration  = rosduration(duration);
            request.GroupMask = groupMask;
            
            call(obj.landService, request);
        end
        
        function goTo(obj, goal, yaw, duration, groupMask)
            %GOTO Broadcasted goTo - Move smoothly to the goal, then hover indefinitely.
            %Always in relative coordinates because absolute goTo would
            %cause collisions.
            if nargin < 5  || isempty(groupMask)
                groupMask = 0;
            end
            request = rosmessage(obj.goToService);
            request.Goal.X    = goal(1);
            request.Goal.Y    = goal(2);
            request.Goal.Z    = goal(3);
            request.Yaw       = yaw;  % In degrees
            request.Duration  = rosduration(duration);
            request.Relative  = true;
            request.GroupMask = groupMask;
            
            call(obj.goToService, request);
        end
    end
end
