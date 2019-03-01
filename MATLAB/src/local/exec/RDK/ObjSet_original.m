classdef ObjSet < handle
    % RDK Object Class
    % 1/17/13
    % Ken R. Hwang, M.S. & Rick O. Gilmore, Ph.D.
    % Penn State Brain Development Lab, SLEIC, PSU
    %
    % ObjSet is responsible for constructing the main class behind the RDK
    % experiment, instances of which (obj) will contain property
    % substructures: sys, exp, and pres. 'sys' contains system information
    % determined prior to instantiation.  'exp' contains experimental
    % parameters, a handful of which can be modified.  'pres' contains
    % properties that consist primarily of function handles utilized during
    % dot display.
    %
    % ObjSet also houses many methods.  The class constructor, which is
    % called within the main function rdkMain.m, sets the substructure
    % properties to the instance of class ObjSet.  During dot generation,
    % methods -- batchDot, trialDot, DotGen, and saveToStruct -- are
    % called.  batchDot is simply a 'for' loop that executes trialDot for
    % the number of block iterations.  trialDot is responsible for
    % reporting the block and trial iteration as well as estimated dot
    % generation time remaining (based on the previous trial generation
    % time).  In addition, trialDot calls DotGen -- the heart of the dot
    % generation process, and recursively calls itself until trial length
    % is reached. After every trial is generated, batchDot will call method
    % saveToStruct to save the newly created object with dot matrices to
    % the appropriate subject directory.
    %
    % DotGen: By utilizing, the dot matrix transformation algorithms
    % (represented as function handles in substructure exp), experimental
    % coherence matrix, and various experimental parameters (lifetime,
    % frames, phase duration, display dimensions, mask parameters, etc.)
    % DotGen will produce dot arrays (xy-coordinates) for every
    % frame and for each side of the display (if sys.display.dual is TRUE).
    %  It will also follow the experimental design structure by
    % appropriately displaying one of every coherence condition, for every
    % pattern type, for each side of the display.  Coherence condition is
    % defined as: the fraction of dots within the entire matrix that will
    % be transformed according to the respective pattern type.  As far as
    % the design of this experiment goes, only one side (if
    % sys.display.dual is TRUE) will be applicable for a coherence
    % condition.  The opposing side of the same trial will always be
    % entirely incoherent (random).  Other than applying motion gradients
    % to these dot arrays, DotGen also applies a dot lifetime to sections
    % of dots defined as "cohorts".  This means that after a certain
    % number of frames (specified by obj.exp.dotlifetime), a given cohort
    % of dots within the array will be re-randomized.  DotGen also
    % performs a bounds check and masking on the dots to ensure that dots
    % remain within exp.dot.field and only those that fall within the
    % parameters for exp.mask are displayed on screen.  The block, trial,
    % pattern type, left coherence, and right coherence are appended to
    % obj.out for this trial's dot set.  Lastly, the dots are filed into
    % dotStore -- a cell property for class ObjSet.
    %
    % Prior to the display sequence, screen handling and dot drawing
    % functions are also handled by class ObjSet.  To begin, an instance of
    % ObjSet will require a window pointer, w, as defined by PsychToolbox's
    % "Screen('OpenWindow')" function.  Afterwards, method tGen is called
    % to generate a timer object responsible for displaying dots within
    % obj.dotStore at a determined framerate.  The timer object can do this
    % by relying on ObjSet's method, timer_fcn. Like with DotGen, timer_fcn
    % performs screen functionality through function handles defined in the
    % 'pres' substructure.  Prior to each dot display is a blank screen and
    % a fixation screen, and this is performed by start_fcn, which also
    % depends on function_handles within 'pres'.  After each trial,
    % stop_fcn will report the trial and block that was just displayed by
    % the timer object. Thus, the timer object (obj.t) will cycle through
    % each block and trial displaying each frame within dotStore.  To
    % determine which doy array within dotStore is used, however, obj.t
    % depends solely on counters within 'pres': block_count and
    % trial_count. Consequently, rdkMain.m is able to have obj.t cycle by
    % updated these count parameters within 'for' loop for blocks and a
    % nested 'for' loop for trials.  Two other methods, begin_fcn and
    % err_fcn, are used by rdkMain.m and debugging, respectively.
    properties (SetObservable)
        dotStore  % Dot storage
        sys % System settings
        exp % Experimental parameter settings
        pres % Presentation Properties
        out = []; % Output recording
        start_key; % Keys to restrict to during start_fcn
        timer_key; % Keys to restrict to during timer_fcn
        gen_times = []; % Calculated generation times
        t % Timer object
    end
    
    methods
        
        function obj = ObjSet(sys,exp,pres)
            obj.sys = sys;
            obj.exp = exp;
            obj.pres = pres;
            obj.dotStore = cell([exp.trial_n exp.block]);
        end
        
        function tGen(obj) % Timer class constructor
            obj.t = timer('StartFcn',@(x,y)obj.start_fcn, ...
                'TimerFcn',@(x,y)obj.timer_fcn(obj.pres.block_count,obj.pres.trial_count), ...
                'StopFcn',@(x,y)obj.stop_fcn, ...
                'ErrorFcn',@(x,y)obj.err_fcn, ...
                'TasksToExecute',obj.exp.fr, ...
                'Period',obj.sys.display.ifi, ...
                'ExecutionMode','fixedRate');
        end
        
        function dotout = DotGen(obj) % DotGen method
            if obj.exp.trial_count <= obj.exp.trial_n % Fail-safe
                pattern = obj.exp.pattern{randi([1 length(obj.exp.pattern)])}; % Randomly generate pattern type
                while obj.exp.(pattern).count > length(obj.exp.(pattern).coh) % Check if count has been reached for this pattern
                    pattern = obj.exp.pattern{randi([1 length(obj.exp.pattern)])}; % Randomly generate pattern type
                end % End while
                
                obj.out{end+1,1} = obj.exp.block_count; % Block count
                obj.out{end,2} = obj.exp.trial_count; % Trial count
                obj.out{end,3} = pattern; % Pattern type
                obj.out{end,4} = obj.exp.(pattern).coh(obj.exp.(pattern).count,1); % Left Coherence
                if obj.sys.display.dual
                    obj.out{end,5} = obj.exp.(pattern).coh(obj.exp.(pattern).count,2); % Right Coherence
                end
                
                dotout = single(zeros([obj.exp.dot.n_masked 2 obj.exp.fr 2])); % Estimate of number dots for preallocation [x y frame stereo]
                
                for i = 1:1+obj.sys.display.dual % For each stereo display
                    dot = zeros([obj.exp.dot.n 2]); % Pre-allocate dot array for new generation
                    dot(:,1) = rand([obj.exp.dot.n 1])*(obj.exp.dot.field(i,3)-obj.exp.dot.field(i,1)) + ones([obj.exp.dot.n 1])*obj.exp.dot.field(i,1); % Random X coordinates (pix) of size obj.exp.dot.n
                    dot(:,2) = rand([obj.exp.dot.n 1])*(obj.exp.dot.field(i,4)-obj.exp.dot.field(i,2)) + ones([obj.exp.dot.n 1])*obj.exp.dot.field(i,2); % Random Y coordinates (pix) of size obj.exp.dot.n
                    dot = single(dot); % Convert to single precision
                    
                    cohort = zeros([length(dot)]);% Preallocate cohort, which will contain cohort values associated with dot indices in 'dot'
                    cohort_n = round(length(dot)/obj.exp.dotlifetime); % Size of dot cohort
                    cohort = repmat(0:obj.exp.dotlifetime-1,[cohort_n 1]); % Assigning cohort value
                    for ii = 1:obj.exp.fr % For each frame
                        % Select dots to refresh (if cohort value has
                        % reached 0)
                        dotrefresh_i = find(~cohort); % Select dots that have reached end of lifetime (if 0)
                        dot(dotrefresh_i,1) = rand([cohort_n 1])*(obj.exp.dot.field(i,3)-obj.exp.dot.field(i,1)) + ones([cohort_n 1])*obj.exp.dot.field(i,1); % Random X coordinates (pix) of size cohort_n
                        dot(dotrefresh_i,2) = rand([cohort_n 1])*(obj.exp.dot.field(i,4)-obj.exp.dot.field(i,2)) + ones([cohort_n 1])*obj.exp.dot.field(i,2); % Random Y coordinates (pix) of size cohort_n
                        cohort(dotrefresh_i) = obj.exp.dotlifetime; % Reset those selected dots to maximum dot lifetime
                        cohort = cohort-1; % Count down one lifetime across array
                        
                        % Direction/Coherency reversals
                        fr_in_cycle = mod( ii, floor(obj.exp.fpc*obj.exp.dutycycle*2) ); % Current frame within duty cycle  (Frames per cycle * duty cycle ratio)
                        if fr_in_cycle == 1 % If current frame is first in the duty cycle
                            obj.exp.drctn = -1*obj.exp.drctn; % Change direction
                        end
                        fr_in_cohcycle = mod( ii, floor(obj.exp.fpc*obj.exp.dutycycle) ); % Current frame within duty cycle  (Frames per cycle * duty cycle ratio)
                        if fr_in_cohcycle == 1 % If current frame is first in the duty cycle
                            obj.exp.cohflag = ~obj.exp.cohflag; % Change coherency
                        end
                        drctn = obj.exp.drctn; % Set drctn variable
                        
                        if obj.exp.cohflag
                            dotindex = obj.exp.dot.parse(dot,obj.exp.(pattern).coh(obj.exp.(pattern).count,i)); % Use dot.parse to obtain an index of coherently-selected dots
                            dot_parsed = dot(dotindex,:); % Dot array using index
                            for iii = 1:length(obj.exp.(pattern).([pattern '_fun']))
                                f = functions(obj.exp.(pattern).([pattern '_fun']){iii,1}); % Obtain function handle
                                arglist = regexp(f.function,'[@]{1,1}[(]{1,1}(.*)[)]{1,1}[(]{1,1}','tokens');
                                arglist = regexp(arglist{1}{1},'[,]','split'); % Obtain arglist
                                argstr = []; % Preallocate argument string
                                for iiii = 1:length(arglist) % For each argument
                                    arglist{iiii} = obj.exp.nomen{strcmp(arglist{iiii},obj.exp.nomen(:,1)),2}; % Rename arglist
                                    argstr = [argstr ',' arglist{iiii}]; % Construct argstr
                                end
                                try
                                    eval([obj.exp.(pattern).([pattern '_fun']){iii,2} ' = obj.exp.(pattern).([pattern ''_fun'']){iii,1}(' argstr(2:end) ');']); % Evaluate function handle with argstr
                                catch ME
                                    disp(pattern)
                                    disp([obj.exp.(pattern).([pattern '_fun']){iii,2} ' = obj.exp.(pattern).([pattern ''_fun'']){iii,1}(' argstr(2:end) ');'])
                                    disp(iii)
                                end
                            end
                            cohdot = newdot; % Coherent dot array
                            dot_parsed = dot(~dotindex,:); % Dot array of previously unselected dots
                        else
                            cohdot = []; % Empty dot array
                            dot_parsed = dot; % Dot array is entire dot vector
                        end
                        
                        for jjj = 1:length(obj.exp.random_fun) % For each function handle
                            f = functions(obj.exp.random_fun{jjj,1}); % Obtain function handle
                            arglist = regexp(f.function,'[@]{1,1}[(]{1,1}(.*)[)]{1,1}[(]{1,1}','tokens');
                            arglist = regexp(arglist{1}{1},'[,]','split'); % Obtain arglist
                            argstr = []; % Preallocate argument string
                            for jjjj = 1:length(arglist) % For each argument
                                arglist{jjjj} = obj.exp.nomen{strcmp(arglist{jjjj},obj.exp.nomen(:,1)),2}; % Rename arglist
                                argstr = [argstr ',' arglist{jjjj}]; % Construct argstr
                            end
                            eval([obj.exp.random_fun{jjj,2} ' = obj.exp.random_fun{jjj,1}(' argstr(2:end) ');']); % Evaluate function handle with argstr
                        end
                        incohdot = newdot; % Incoherent (random) dot array
                        dot = [cohdot;incohdot]; % Combine arrays & rewrite dot
                        
                        % Bounds Check
                        switch pattern
                            case 'radial'
                                % Because radial motion is applied directly
                                % into xy-plane, it is difficult to analyze
                                % what radii will be < 0 after motion is
                                % applied.  For now, a buffer will be
                                % applied
                                % (obj.exp.mask.annulus_buffer_pix).
                                % Anything greater than the outer radius
                                % plus the buffer will be recycled to the
                                % inner minus the buffer (0 if the latter
                                % is less than 0).  Vice versa for anything
                                % smaller than the inner radius minus the
                                % buffer.  This works ideally if an inner
                                % radius is applied because dots need to be
                                % within the inner radius minus the buffer
                                % for recycling to the outer ring to occur.
                                r = sqrt((dot(:,1)-obj.sys.display.center(1)).^2 + (dot(:,2)-obj.sys.display.center(2)).^2);
                                t = atan2(dot(:,2)-obj.sys.display.center(2),dot(:,1)-obj.sys.display.center(1));
                                rhi = r > obj.exp.mask.annulus_pix(2) + obj.exp.mask.annulus_buffer_pix;
                                rlo = r < obj.exp.mask.annulus_pix(1) - obj.exp.mask.annulus_buffer_pix;
                                if any(rhi)
                                    if (obj.exp.mask.annulus_pix(1) - obj.exp.mask.annulus_buffer_pix) > 0
                                        r(rhi) = obj.exp.mask.annulus_pix(1) - obj.exp.mask.annulus_buffer_pix; % Bring back to inner - buffer
                                    else
                                        r(rhi) = 0; % Set radius to 0
                                    end
                                end
                                if any(rlo)
                                    r(rlo) = obj.exp.mask.annulus_pix(2) + obj.exp.mask.annulus_buffer_pix; % Bring to out + buffer
                                end
                                dot(:,1) = (r.*cos( t ))+obj.sys.display.center(1); % Convert back to x coordinates
                                dot(:,2) = (r.*sin( t ))+obj.sys.display.center(2); % Convert back to y coordinates
                                
                            case 'linear'
                                xlo = find(dot(:,1) <= obj.exp.dot.field(i,1)); % X < XMin
                                xhi = find(dot(:,1) >= obj.exp.dot.field(i,3)); % X > XMax
                                ylo = find(dot(:,2) <= obj.exp.dot.field(i,2)); % Y < YMin
                                yhi = find(dot(:,2) >= obj.exp.dot.field(i,4)); % Y > YMax
                                
                                if any(xlo)
                                    dot(xlo,1) = obj.exp.dot.field(i,3) - (obj.exp.dot.field(i,1) - dot(xlo,1)); % Shifting X coordinates from left of dot field to left of right side of dot field
                                end
                                if any(xhi)
                                    dot(xhi,1) = obj.exp.dot.field(i,1) + (dot(xhi,1) - obj.exp.dot.field(i,3)); % Shifting X coordinates from right of dot field to right of left side of dot field
                                end
                                if any(ylo)
                                    dot(ylo,2) = obj.exp.dot.field(i,4) - (obj.exp.dot.field(i,2) - dot(ylo,2)); % Shifting Y coordinates from below dot field to below top of dot field
                                end
                                if any(yhi)
                                    dot(yhi,2) = obj.exp.dot.field(i,2) + (dot(yhi,2) - obj.exp.dot.field(i,4)); % Shifting Y coordinates from above dot field to above bottom of dot field
                                end
                        end
                        
                        % Mask (does not change dot matrix)
                        r = sqrt((dot(:,1) - obj.sys.display.center(1)).^2 + (dot(:,2) - obj.sys.display.center(2)).^2); % Determine radii in polar space
                        r_ind = (r >= obj.exp.mask.annulus_pix(1)) & (r <= obj.exp.mask.annulus_pix(2)); % Index of dots after mask
                        
                        % Output (Only record dot positions, not cohort
                        % index)
                        dotout(1:size(dot(r_ind,:),1),1:size(dot(r_ind,:),2),ii,i) = dot(r_ind,:); % Place 2-D array within frame and stereo index
                    end
                end
                obj.dotStore{obj.exp.trial_count,obj.exp.block_count} = dotout; % Save to dotStore property
                obj.exp.(pattern).count = obj.exp.(pattern).count + 1; % Add to pattern count
                obj.exp.trial_count = obj.exp.trial_count + 1; % Add to trial count
            end
        end
        
        function batchDot(obj) % batchDot method
            
            for i = 1:obj.exp.block
                obj.exp.block_count = i; % Setting block count
                obj.trialDot;
                
                % Resetting count values (trial_count and pattern type
                % counts)
                obj.exp.trial_count = 1;
                for j = 1:length(obj.exp.pattern)
                    pattern = obj.exp.pattern{j};
                    obj.exp.(pattern).count = 1;
                end
            end
            
            obj.saveToStruct([obj.exp.objpath filesep 'obj.mat']); % Saving object
            
        end
        
        function trialDot(obj) % trialDot method
            if obj.exp.trial_count <= obj.exp.trial_n
                fprintf('RDK: Populating block %i trial %i ... \n',obj.exp.block_count,obj.exp.trial_count); % Reporting block and trial count
                if ~isempty(obj.gen_times) % Reporting time remaining estimate based on previous trial generation time estimate
                    trial_remaining = ((obj.exp.block - obj.exp.block_count)*obj.exp.trial_n) + (obj.exp.trial_n - obj.exp.trial_count + 1);
                    time_remaining = trial_remaining * mean(obj.gen_times);
                    fprintf('RDK: Estimated time remaining = %4.2f sec (%2.1f min). \n', time_remaining, time_remaining/60);
                end
                tic; % Recording generation time
                obj.DotGen;
                obj.gen_times = [obj.gen_times toc]; % Accumulating trial generation times
                obj.trialDot; % Recursive call
            end
        end
        
        function saveToStruct(obj, filename) % saveToStruct method
            varname = inputname(1);
            props = properties(obj);
            %             meths = methods(obj);
            %             find(cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(regexp(y,'fcn')),meths,'UniformOutput',false)))
            for p = 1:numel(props)
                s.(props{p})=obj.(props{p});
            end
            eval([varname ' = s;'])
            fprintf('RDK: Saving object structure (%s).  One moment ... \n', obj.exp.objpath);
            try
                save(filename, varname)
            catch
                save(filename, varname, '-v7.3') % Different mat version save due to memory issues (Not fully tested)
            end
        end
        
        function begin_fcn(obj) % Beginning display function
            obj.pres.txt_size_fun(obj.sys.display.temp_w,obj.pres.txt_val);
            obj.pres.txt_fun(obj.pres.txt,obj.sys.display.temp_w,obj.sys.display.white);
            obj.pres.flip_fun(obj.sys.display.temp_w);
            KbStrokeWait;
        end
        
        function start_fcn(obj) % start_fcn method for timer
            % This function is used to display a black screen, wait for key
            % board press, display fixation dot, and wait for keyboard
            % press.  It will accomodate if the fixation needs to be drawn
            % in stereo or non-stereo mode.
            RestrictKeysForKbCheck(obj.start_key);
            if obj.sys.display.dual
                % Blank screen
                obj.pres.blank_fun(obj.sys.display.w,obj.sys.display.black );
                obj.pres.flip_fun(obj.sys.display.w);
                % Key wait, escape status noted
                [~,keyCode,~] = KbStrokeWait;
                if find(keyCode) == obj.start_key(end)
                    obj.pres.esc_flag = 1;
                    stop(obj.t)
                    return;
                end
                % Fixation
                if obj.exp.fix.status
                    obj.pres.fixL_fun(obj.sys.display.w,obj.exp.fix);
                    obj.pres.selectstereo_fun(obj.sys.display.w,1);
                    obj.pres.fixR_fun(obj.sys.display.w,obj.exp.fix);
                end
                obj.pres.flip_fun(obj.sys.display.w);
                % Key wait, escape status noted
                [~,keyCode,~] = KbStrokeWait;
                if find(keyCode) == obj.start_key(end)
                    obj.pres.esc_flag = 1;
                    stop(obj.t)
                    return;
                end
                % Blank Screen
                obj.pres.flip_fun(obj.sys.display.w);
            else
                
                obj.pres.blank_fun(obj.sys.display.w,obj.sys.display.black );
                obj.pres.flip_fun(obj.sys.display.w);
                
                [~,keyCode,~] = KbStrokeWait;
                if find(keyCode) == obj.start_key(end)
                    obj.pres.esc_flag = 1;
                    stop(obj.t)
                    return;
                end
                
                if obj.exp.fix.status
                    obj.pres.fix_fun(obj.sys.display.w,obj.exp.fix);
                end
                
                obj.pres.flip_fun(obj.sys.display.w);
                
                [~,keyCode,~] = KbStrokeWait;
                if find(keyCode) == obj.start_key(end)
                    obj.pres.esc_flag = 1;
                    stop(obj.t)
                    return;
                end
                
                obj.pres.flip_fun(obj.sys.display.w);
            end
            fprintf('RDK: Initiating trial %i of block %i.\n',obj.pres.trial_count,obj.pres.block_count); % Reporting start of display sequence
            obj.t.UserData = GetSecs; % Logging start time into UserData timer property
        end
        
        function timer_fcn(obj,b,t) % timer_fcn method for timer
            % This function is used to cycle through frames for the
            % respective dot array.  It will accomodate for whether the
            % dots need to be displayed in stereo mode or not (Only the
            % first set (left side) within the 4-D matrix of dots will appear if
            % non-stereo mode is selected.
            RestrictKeysForKbCheck(obj.timer_key);
            if obj.t.TasksExecuted < obj.exp.fr
                if obj.sys.display.dual
                    obj.pres.draw_fun(obj.dotStore{t,b}(:,:,obj.t.TasksExecuted+1,1),obj.sys.display.w);
                    obj.pres.selectstereo_fun(obj.sys.display.w,1);
                    obj.pres.draw_fun(obj.dotStore{t,b}(:,:,obj.t.TasksExecuted+1,2),obj.sys.display.w);
                    if obj.exp.fix.pers_fix % If persistent fixation
                        obj.pres.selectstereo_fun(obj.sys.display.w,0);
                        obj.pres.fixL_fun(obj.sys.display.w,obj.exp.fix);
                        obj.pres.selectstereo_fun(obj.sys.display.w,1);
                        obj.pres.fixR_fun(obj.sys.display.w,obj.exp.fix);
                    end
                    obj.pres.flip_fun(obj.sys.display.w);
                else
                    obj.pres.draw_fun(obj.dotStore{t,b}(:,:,obj.t.TasksExecuted+1,1),obj.sys.display.w);
                    if obj.exp.fix.pers_fix
                        obj.pres.fix_fun(obj.sys.display.w,obj.exp.fix);
                    end
                    obj.pres.flip_fun(obj.sys.display.w);
                end
            end
        end
        
        function err_fcn(obj) % err_fcn method for timer
            fprintf('RDK: Error. Aborting ...\n');
            Screen('CloseAll');
        end
        
        function stop_fcn(obj) % stop_fcn method for timer
            fprintf('RDK: Finished trial %i of block %i.\n',obj.pres.trial_count,obj.pres.block_count); % Reporting end of display sequence
        end
        
    end
    
    methods (Static)
        function sys = SysCheck
            
            %             % Set PTB path dependencies
            %             p = pathdef;
            %             matlabpath(p);
            
            % Core size
            [~, core_out ] = system('sysctl -n hw.ncpu');
            sys.core = uint8(str2double(strtrim(core_out)));
            
            % Devices (picked up by PTB)
            sys.io_device = PsychHID('Devices');
            
            % Get the parent process ID
            [s,ppid] = unix('ps -p $PPID -l | awk ''{ if(NR==1) for(i=1;i<=NF;i++) { if($i~/PPID/) { colnum=i;break} } else print $colnum }'' ' );
            % Get memory used by the parent process (resident set size)
            [s,thisused] = unix(['ps -O rss -p ' strtrim(ppid) ' | awk ''NR>1 {print$2}'' ']);
            % RSS is in kB, convert to bytes
            sys.mem.thisused = str2double(thisused)*1024;
            % Total memory (bytes)
            [~,total] = unix('sysctl hw.memsize | cut -d: -f2');
            sys.mem.total = str2double(strtrim(total));
            sys.mem.free = sys.mem.total - sys.mem.thisused;
            
            % Java memory
            java.lang.Runtime.getRuntime.gc; % Free/Reallocate? Memory
            sys.javmem.max = java.lang.Runtime.getRuntime.maxMemory;
            sys.javmem.free = java.lang.Runtime.getRuntime.freeMemory;
            sys.javmem.total = java.lang.Runtime.getRuntime.totalMemory;
            
            % Buffer size
            sys.buffer = 3*1024*1024*1024; % Buffer size (bytes): 3GB -- Guideline from MathWorks for 32-bit
            
            % Opening multiple labs (default is equal to number of cores
            %             matlabpool;
            
            % Display Settings
            sys.display.screens = Screen('Screens'); % Screens available
            sys.display.screenNumber = max( sys.display.screens ); % Screen to use
            
            [sys.display.width_pix, sys.display.height_pix]=Screen('WindowSize', sys.display.screenNumber); % Screen dimensions in pixels
            
            sys.display.dual = 1; % Dual screen (0/1)
            sys.display.width_pix_full = sys.display.width_pix; % Full width (pix)
            sys.display.width_pix_half = sys.display.width_pix_full/2; % Halve width (pix)
            
            if sys.display.dual
                sys.display.rw_pix = sys.display.width_pix_half;
                sys.display.stereo = 4; % Stereo value for 'Screen'
            else
                sys.display.rw_pix = sys.display.width_pix_full;
                sys.display.stereo = []; % Stereo value for 'Screen'
            end
            
            sys.display.rect = [0  0 sys.display.rw_pix sys.display.height_pix]; % Rectangle to use (pix)
            [sys.display.center(1), sys.display.center(2)] = RectCenter( sys.display.rect ); % Rectangle center (pix)
            
            sys.display.black = intmin('uint8'); % Black value
            sys.display.white = intmax('uint8'); % White value
            [sys.display.width_mm,sys.display.height_mm] = Screen('DisplaySize',sys.display.screenNumber); % Display size (mm)
            sys.display.width_cm = sys.display.width_mm/10; % Display width (cm)
            sys.display.height_cm = sys.display.height_mm/10; % Display height (cm)
            
            sys.display.view_dist_cm = 60; % View distance (variable)
            sys.display.fps = Screen('FrameRate', sys.display.screenNumber); % Frame rate (hz)
            if ~sys.display.fps
                sys.display.fps = 60;
            end
            
            sys.display.ifi = 1/sys.display.fps; % Inverse frame rate
            
            sys.display.ppd = pi * (sys.display.width_pix) / atan(sys.display.width_cm/sys.display.view_dist_cm/2) / 180; % Pixels per degree
            
        end
        
        function exp = ExpSet(sys,subjstr)
            % Path
            path = mfilename('fullpath');
            [exp.path,~,~] = fileparts(path);
            exp.objpath = [exp.path filesep 'exp' filesep subjstr];
            mkdir(exp.objpath);
            
            % General Experimental Parameters
            exp.block = 1; % Number of blocks
            exp.trial_t = 10; % Trial duration (sec)
            exp.fr = sys.display.fps*exp.trial_t; % Frames total
            exp.coh_mod_fr = 1; % 1.2 Hz frequency
            exp.fpc = (1/exp.coh_mod_fr) * sys.display.fps;
            
            exframes = mod(exp.fr,exp.fpc);
            
            if exframes
                exp.fr = exp.fr + (exp.fpc - exframes);
            end                
            
            if sys.display.dual             
                exp.reverse = 1; % Reverse sides (1/0)
            else
                exp.reverse = 0; % Reverse sides (1/0)
            end
            
            exp.pattern = {'radial','linear'}; % Pattern conditions
%             exp.coherence = [.05 .1 .15 .2]; % Coherence conditions
            exp.coherence = [.7 .8 .9]; % Practice Coherence conditions
            exp.v = 2; % Dot speed (deg/sec)
            exp.dotlifetime = 10; % Frame life of dots
            exp.dutycycle = .25; % Phase (default is 4-phase==.25; 4-phase includes direction reversals and coherency modulation
            exp.drctn = -1; % 1/-1 for direction reversal
            exp.cohflag = 0; % 0/1 for coherence reversal
            exp.ppf  = exp.v * sys.display.ppd / sys.display.fps; % Dot speed (pix/frame)
            exp.trial_n = length(exp.pattern) * length(exp.coherence) * (1 + exp.reverse); % Number of trials per block
            exp.trial_total = exp.trial_n * exp.block; % Total amount of trials
            exp.block_count = 1; % Block counter
            exp.trial_count = 1; % Trial counter
            
            if sys.display.dual % Different presmat depending on dual
                presmat = [zeros([length(exp.coherence) 1]) exp.coherence']; % Constructing presentation matrix
                if exp.reverse
                    presmat = [presmat; [presmat(:,2) presmat(:,1)]];  % Include reversed eyes
                end
            else
                presmat = exp.coherence'; % Constructing presentation matrix
            end
            
            % Mask Constraint Parameters
            exp.mask.annulus_deg = [1.5 5.5]; % Annulus radius minimum and maximum (deg)
            exp.mask.annulus_buffer_deg = 1; % Buffer radius to be recycled
            exp.mask.annulus_pix = exp.mask.annulus_deg * sys.display.ppd; % Annulus radius minimum and maximum (pix)
            exp.mask.adj_flag = 0;
%             if sys.display.dual
%                 exp.mask.extra_w = (sys.display.rect(3) - exp.mask.annulus_pix(2)*2)/2; % Amount of width left on one side of annulus, (Also default distance from center).
%                 exp.mask.interannulus_deg = (exp.mask.extra_w*2)/sys.display.ppd; % Degrees distance between annuluses outer radii
%                 if exp.mask.interannulus_deg < 5
%                     fprintf('RDK: Warning! Inter-annulus degree is less than 5 (%2.4f).\n', exp.mask.interannulus_deg)
%                     exp.mask.offset_deg = 5 - exp.mask.interannulus_deg;
%                     exp.mask.offset_pix = exp.mask.offset_deg*sys.display.ppd;
%                     exp.mask.extra_w_with_offset = (sys.display.center(1) - exp.mask.annulus_pix(2)) - exp.mask.offset_pix;
%                     if exp.mask.extra_w_with_offset < 0
%                         fprintf('RDK: Warning! Unable to adjust inter-annulus degree to greater than 5.  \nPixel offset is greater than available pixel width space (%4.4f > %4.4f).\n',exp.mask.offset_pix, (sys.display.center(1) - exp.mask.annulus_pix(2)))
%                         fprintf('RDK: Consider reducing outer annulus radius (Currently, %2.1f degrees).\n', exp.mask.annulus_deg(2));
%                     else
%                         fprintf('RDK: Adjusted inter-annulus degree to 5.  This will increase the distance between the left and right annuluses.\n');
%                         exp.mask.adj_flag = 1;
%                     end
%                 elseif exp.mask.interannulus_deg > 10
%                     fprintf('RDK: Warning! Inter-annulus degree is greater than 10 (%2.4f).\n', exp.mask.interannulus_deg)
%                     exp.mask.offset_deg = exp.mask.interannulus_deg - 10;
%                     exp.mask.offset_pix = exp.mask.offset_deg*sys.display.ppd;
%                     fprintf('RDK: Adjusted inter-annulus degree to 10.  This will decrease the distance between the left and right annuluses.\n');
%                     exp.mask.adj_flag = -1;
%                 end
%             end
            exp.mask.annulus_buffer_pix = exp.mask.annulus_buffer_deg * sys.display.ppd; % Buffer radius (pix)
            outerA = pi*exp.mask.annulus_pix(2)^2;
            innerA = pi*exp.mask.annulus_pix(1)^2;
            exp.mask.area = outerA - innerA; % Total area (pixels)
            
            % Fixation Parameters
            exp.fix.status = 1; % Fixation on or off (0/1)
            if exp.fix.status
                exp.fix.pers_fix = 1; % Persistent fixation (0/1)
            else
                exp.fix.pers_fix = 0; % Persistent fixation off if no fixation
            end
            exp.fix.size_deg = .15; % Fixation size in degrees
            exp.fix.size_pix = exp.fix.size_deg*sys.display.ppd; % Fixation size in pixels
            exp.fix.color = sys.display.white; % Fixation color (default white)
            
            if sys.display.dual
                exp.fix.coord = zeros([2 4]);
                exp.fix.coord(1,:) = [sys.display.rw_pix-exp.fix.size_pix/2 sys.display.center(2)-exp.fix.size_pix/2 sys.display.rw_pix+exp.fix.size_pix/2 sys.display.center(2)+exp.fix.size_pix/2]; % Fixation coordinates (Left)
                exp.fix.coord(2,:) = [0-exp.fix.size_pix/2 sys.display.center(2)-exp.fix.size_pix/2 0+exp.fix.size_pix/2 sys.display.center(2)+exp.fix.size_pix/2]; % Fixation coordinates (Right)
            else
                exp.fix.coord = [sys.display.center(1)-exp.fix.size_pix/2 sys.display.center(2)-exp.fix.size_pix/2 sys.display.center(1)+exp.fix.size_pix/2 sys.display.center(2)+exp.fix.size_pix/2]; % Fixation coordinates
            end
            
            % Dot Parameters
            exp.dot.dens = .15; % Dot density fraction
            exp.dot.size_deg = .1; % Dot size (deg)
            exp.dot.size_pix = round(exp.dot.size_deg * sys.display.ppd); % Dot size (pix)
            if exp.mask.adj_flag % Have to make two dot fields now, because of interannulus distance
                if exp.mask.adj_flag < 0
                    exp.dot.field(1,:) = [((sys.display.center(1) - exp.mask.annulus_pix(2))-exp.mask.offset_pix) (sys.display.center(2) - exp.mask.annulus_pix(2)) ((sys.display.center(1) + exp.mask.annulus_pix(2))-exp.mask.offset_pix) (sys.display.center(2) + exp.mask.annulus_pix(2)) ]; % Dot field (pix)
                    exp.dot.field(2,:) = [((sys.display.center(1) - exp.mask.annulus_pix(2))+exp.mask.offset_pix) (sys.display.center(2) - exp.mask.annulus_pix(2)) ((sys.display.center(1) + exp.mask.annulus_pix(2))+exp.mask.offset_pix) (sys.display.center(2) + exp.mask.annulus_pix(2)) ]; % Dot field (pix)
                else
                    exp.dot.field(1,:) = [((sys.display.center(1) - exp.mask.annulus_pix(2))+exp.mask.offset_pix) (sys.display.center(2) - exp.mask.annulus_pix(2)) ((sys.display.center(1) + exp.mask.annulus_pix(2))+exp.mask.offset_pix) (sys.display.center(2) + exp.mask.annulus_pix(2)) ]; % Dot field (pix)
                    exp.dot.field(2,:) = [((sys.display.center(1) - exp.mask.annulus_pix(2))-exp.mask.offset_pix) (sys.display.center(2) - exp.mask.annulus_pix(2)) ((sys.display.center(1) + exp.mask.annulus_pix(2))-exp.mask.offset_pix) (sys.display.center(2) + exp.mask.annulus_pix(2)) ]; % Dot field (pix)
                end
            else
                exp.dot.field(1,:) = [(sys.display.center(1) - exp.mask.annulus_pix(2)) (sys.display.center(2) - exp.mask.annulus_pix(2)) (sys.display.center(1) + exp.mask.annulus_pix(2)) (sys.display.center(2) + exp.mask.annulus_pix(2)) ]; % Dot field (pix)
                exp.dot.field(2,:) = [(sys.display.center(1) - exp.mask.annulus_pix(2)) (sys.display.center(2) - exp.mask.annulus_pix(2)) (sys.display.center(1) + exp.mask.annulus_pix(2)) (sys.display.center(2) + exp.mask.annulus_pix(2)) ]; % Dot field (pix)
            end
            exp.dot.field_area = (exp.dot.field(1,3) - exp.dot.field(1,1))*(exp.dot.field(1,4) - exp.dot.field(1,2));
            exp.dot.n = round( exp.dot.dens/(exp.dot.size_pix^2) * exp.dot.field_area ); % Number of dots for field
            exp.dot.prop = exp.mask.area/exp.dot.field_area; % Proportion of mask area relative to dot field
            exp.dot.n_masked = round(exp.dot.n*exp.dot.prop); % Number of estimated dots in masked area
            
            % Pattern Parameters
            for p = 1:length(exp.pattern);
                [pres_shuffle1,shufflesort] = Shuffle(presmat(:,1)); % Shuffle first column of pres
                if sys.display.dual
                    exp.(exp.pattern{p}).coh = [pres_shuffle1 presmat(shufflesort,2)]; % Reconstruct with sorted second column -- apply to pattern structure
                else
                    exp.(exp.pattern{p}).coh = pres_shuffle1; % Reconstruct with sorted second column -- apply to pattern structure
                end
                exp.(exp.pattern{p}).count = 1; % Initialize count
                switch exp.pattern{p}
                    case 'linear' % Linear function handles
                        exp.(exp.pattern{p}).dir_rads = pi/2; % Horizontal
                        lin1 = @(rad,ppf)([cos(rad) sin(rad)]*ppf); % Motion vector (exp.linear.dir_rads,exp.ppf)
                        lin2 = @(mot,dot,drctn)(dot + (repmat(mot, [size(dot,1) 1]) .* [repmat(drctn, [size(dot,1) 1]) repmat(drctn, [size(dot,1) 1])])); % New dot vector (output from lin1, dot vector, 1/-1)
                        exp.(exp.pattern{p}).linear_fun = {lin1, 'mot'; lin2, 'newdot'}; % Function handles and expected output
                    case 'radial' % Radial function handles
                        rad1 = @(dot)(atan2(dot(:,2)-sys.display.center(2),dot(:,1)-sys.display.center(1))); % Calculate theta (Dot array), relative to center
                        rad2 = @(theta,ppf,drctn)([cos(theta) sin(theta)] .* repmat(ppf*drctn,[length(theta) 2])); % Cos-Sin vector of theta values times motion matrix (output from rad1, exp.ppf, 1/-1)
                        rad3 = @(mot,dot)(dot + mot); % New dot vector (motion vector, dot array)
                        exp.(exp.pattern{p}).radial_fun = {rad1, 'theta'; rad2, 'mot'; rad3, 'newdot'}; % Function handles and expected output
                end
            end
            
            % Random function handles
            rand1 = @(dot)(rand(length(dot), 1)*2*pi); % Random direction (Dot array)
            rand2 = @(dot,ppf,mot)(dot + (repmat(ppf,[length(dot) 2]) .* [cos(mot) sin(mot)])); % New dots created by adding random direction vector (Dot array, exp.ppf, output from rand1)
            exp.random_fun = {rand1, 'mot'; rand2, 'newdot'}; % Function handles and expected output
            
            % Variable nomenclature
            exp.nomen = {'drctn', 'drctn'; 'dot', 'dot_parsed'; ...
                'mot', 'mot'; 'ppf', 'obj.exp.ppf'; ...
                'rad', 'obj.exp.(pattern).dir_rads'; ...
                'theta','theta'};
            
            % Dot parse function handle
            exp.dot.parse = @(dot,coh)(rand(size(dot(:,1))) < coh); % Variable each call
            
        end
        
        function pres = PresSet(sys)
            % Presentation count properties
            pres.block_count = [];
            pres.trial_count = [];
            
            % Presentation escape property
            pres.esc_flag = 0;
            
            % Presentation text
            pres.txt_val = 22;
            pres.txt = 'Motion coherence discrimination task.\n\n\n  Press spacebar to begin.';
            
            % Presentation function handles
            pres.open = @(screen,color,stereo)(Screen('OpenWindow',screen,color,[],[],[],stereo));
            pres.selectstereo_fun = @(w,stereoselect)(Screen('SelectStereoDrawBuffer', w, stereoselect)); % Select stereo buffer to draw
            
            if sys.display.dual
                pres.fixL_fun = @(w,fix)(Screen('FillOval',w,fix.color,fix.coord(1,:))); % Draw fixation (Left)
                pres.fixR_fun = @(w,fix)(Screen('FillOval',w,fix.color,fix.coord(2,:))); % Draw fixation (Right)
            else
                pres.fix_fun = @(w,fix)(Screen('FillOval',w,fix.color,fix.coord)); % Draw fixation
            end
            pres.txt_size_fun = @(w,size)(Screen('TextSize',w,size)); % Formats text size for screen
            pres.txt_fun = @(txt,w,color)(DrawFormattedText(w,txt,'center','center',color)); % Display text (in center)
            pres.draw_fun = @(dot,w)(Screen('DrawDots',w,double(dot)')); % Draw dots
            pres.blank_fun = @(w,color)(Screen('FillRect',w,color));
            pres.flip_fun = @(w)(Screen('Flip',w)); % Flip buffer
            
        end
        
    end
    
end