function rdkMain(varpick)
% Primary RDK function for loading parameters, displaying dots, recording
% behavioral response, and writing output.
%
% 1/17/13
% Ken R. Hwang, M.S. & Rick O. Gilmore, Ph.D.
% Penn State Brain Development Lab, SLEIC, PSU
%
% usage: rdkMain(option)
%   options: 'prepare','newrun', 'oldload' (Note: arguments must be
%   surrounded by single quotes)
%   
%   prepare: Will request number of iterations and subject testing date and
%   time.  This option will allow the user to prepare, in advance, a
%   certain number of dot displays.
%
%   newrun: Will run one iteration of dot generation, then advance directly
%   into dot display.  This option should be used if no dots have been
%   pre-generated, and you require a dot set for a current experimental
%   session.
%
%   oldload: Does not execute dot generation, but will request an old
%   'obj.mat' to be loaded so that it can begin dot display.  This option
%   is for when there are pre-generated dots available for a current
%   experimental session.  Be aware that the output, out.csv, is written
%   exclusively to the subject folder.  So, if you have an old out.csv in
%   that subject folder that you would like to keep, backup the old out.csv
%   and/or subject folder before running 'oldload'.

% Put into high priority
Priority(1);

% create a diary output of everything that happened
diary ON

warning('off','MATLAB:TIMER:RATEPRECISION');
% Error displays
err_disp = {'Test date is not of appropriate length (YYYYMMDD).', ...
    'Test time is not of appropriate length (HHMM).', ...
    'Test date is not numeric.', ...
    'Test time is not numeric.'};

participant_id = input('Enter the participant id (XXXX):\n', 's');
run_number = input('Enter the run number (1-4):\n', 's');
run_velocity = input('Enter the velocity (2 or 8):\n', 's');
out_file_name = strcat( datestr(now, 'yymmdd'), participant_id, run_number, run_velocity, '.csv')

%out_file_name = strcat( datestr(now, 'yyyy-mm-dd-HH-MM-SS'), '.csv')

switch varpick
    case 'prepare'
        
        prepare_n = input('RDK: Enter number of iterations:\n');
        fprintf('RDK: Test time and date is required to label each dot set.\n');
        
        % Error displays
        err_disp = {'Test date is not of appropriate length (YYYYMMDD).', ...
            'Test time is not of appropriate length (HHMM).', ...
            'Test date is not numeric.', ...
            'Test time is not numeric.'};
        
        for i = 1:prepare_n
            % User input
            testdate = input('RDK: Enter testing date (YYYYMMDD):','s');
            testtime = input('RDK: Enter testing time (HHMM):','s');
            % String checks
            prep_kick = 0;
            err_h = zeros([1 4]);
            if length(testdate)~=8
                err_h(1) = 1;
                prep_kick = 1;
            end
            if length(testtime)~=4
                err_h(2) = 1;
                prep_kick = 1;
            end
            if isnan(str2double(testdate))
                err_h(3) = 1;
                prep_kick = 1;
            end
            if isnan(str2double(testtime))
                err_h(4) = 1;
                prep_kick = 1;
            end
            
            if prep_kick
                for err_i = 1:length(err_h)
                    if err_h(err_i)
                        fprintf('RDK: %s\n',err_disp{err_i});
                    end
                end
                error('RDK: Rerun script with appropriate time and date entries.');
            else
                subjstr = [testdate '_' testtime];
            end
            
            fprintf('RDK: Preparing iteration %i.\n', prepare_n); % Report
            % Property values
            sys = ObjSet.SysCheck;
            exp = ObjSet.ExpSet(sys,subjstr);
            pres = ObjSet.PresSet(sys);
            
            % Object definition
            obj = ObjSet(sys,exp,pres);
            obj.batchDot;
            clear obj
            
            
        end
        return; % Exit script
        
    case 'newrun'
        % User input
        testdate = input('RDK: Enter testing date (YYYYMMDD):','s');
        testtime = input('RDK: Enter testing time (HHMM):','s');
        % String checks
        kick = 0;
        err_h = zeros([1 4]);
        if length(testdate)~=8
            err_h(1) = 1;
            kick = 1;
        end
        if length(testtime)~=4
            err_h(2) = 1;
            kick = 1;
        end
        if isnan(str2double(testdate))
            err_h(3) = 1;
            kick = 1;
        end
        if isnan(str2double(testtime))
            err_h(4) = 1;
            kick = 1;
        end
        
        if kick
            for err_i = 1:length(err_h)
                if err_h(err_i)
                    fprintf('RDK: %s\n',err_disp{err_i});
                end
            end
            error('RDK: Rerun script with appropriate time and date entries.');
        else
            subjstr = [testdate '_' testtime];
        end
        
        % Property values
        sys = ObjSet.SysCheck;
        exp = ObjSet.ExpSet(sys,subjstr);
        pres = ObjSet.PresSet(sys);
        
        % Object definition
        obj = ObjSet(sys,exp,pres);
        obj.batchDot;
        
    case 'oldload'
        
        % Old property values
        [f,p] = uigetfile;
        fprintf('RDK: Loading object (%s).  One moment.\n', [p f]); % Report
        old_instance = load([p f]);
        old_strval = fieldnames(old_instance);
        
        %
        %         % Screen set-up
        %         obj.sys.display.w = obj.pres.open(eval([oldstrval{1} '.sys.display.screenNumber']),eval([old_strval{1} '.sys.display.black']),eval([old_strval{1} '.sys.display.stereo'])); % Open Window
        %
        % Object definition
        obj = ObjSet(eval(['old_instance.' old_strval{1} '.sys']),eval(['old_instance.' old_strval{1} '.exp']),eval(['old_instance.' old_strval{1} '.pres']));
        obj.dotStore = old_instance.(old_strval{1}).dotStore;
        obj.out = old_instance.(old_strval{1}).out;
        
    case 'practice'
        
        rdkMain('oldload')
        return;
        
    otherwise
        
        error('RDK: Invalid option.')
        
end

% Initialization
addpath(obj.exp.path); % Add path

% PsychJavaTrouble();
% Input Devices

[spkey, esckey, lkey, rkey, pkey, deviceNumber] = inputDevice(); %Run input device choice and definition script
obj.start_key = [spkey esckey]; % Define start_fcn keys in obj properties
obj.timer_key = [lkey rkey pkey esckey]; % Define timer_fcn keys in obj properties
obj.deviceNumber = deviceNumber;


% Output Setup
if obj.sys.display.dual
    out = cell([size(obj.out,1) size(obj.out,2)+3]); % obj.out with 3 columns for L/R response, RT, and Acc
    out(1:size(obj.out,1),1:size(obj.out,2)) = obj.out;
    LRkey = cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(find(y)),obj.out(:,4:5),'UniformOutput',false)); % If isn't empty (aka coherent), then matrix index will contain '1'
else
    out = obj.out; % Same out output if single display
end

% Starting window set-up
% oldVisualDebugLevel = Screen('Preference','VisualDebugLevel',1);
Screen('Preference','SkipSyncTests',0);
obj.sys.display.temp_w = obj.pres.open(obj.sys.display.screenNumber,obj.sys.display.black,0); % Open Window
% Commented out because the defined spkey on the gamepad did not work
% RestrictKeysForKbCheck(spkey);


%Restrict Keys for keyboard checking - ars17 2/18/16
enabledKeys = [obj.start_key obj.timer_key];
scanList = zeros(1,256);
scanList(enabledKeys) = 1; %scanList = variable limiting keys during KbCheck



obj.begin_fcn; % Display starting text

% Screen and timer set-up
% Screen('Preference','SkipSyncTests',0);
oldVisualDebugLevel = Screen('Preference','VisualDebugLevel',1);
Screen('Preference','SkipSyncTests',1);
obj.sys.display.w = obj.pres.open(obj.sys.display.screenNumber,obj.sys.display.black,obj.sys.display.stereo); % Open Window
obj.tGen;

% Display sequence
obj.pres.esc_flag = 0;

for block_i = 1:obj.exp.block % For each block
    obj.pres.block_count = block_i; % Changing presentation block_count
    trial_i = 1;
    while trial_i <= obj.exp.trial_n % For each trial
        obj.pres.trial_count = trial_i; % Changing presentation trial_count
        resp = ' '; % Reset response
        respchk = []; % Reset response accuracy check index
        keyCode = []; % Reset keyCode
                
        fprintf('RDKmain line 215: Calling start(obj.t)\n');
        start(obj.t); % Start timer
        
        while strcmp(obj.t.Running,'on') % While the timer is running
            %[keyIsDown,secs,keyCode] = KbCheck; % Used for keyboard only
            [keyIsDown,secs,keyCode] = PsychHID('KbCheck', obj.deviceNumber, scanList); %new line to accept any input device - scanList to limit keys bor KbCheck
            ListenChar(0)            
            if keyIsDown
                fprintf('Input Device Number: %i \n', obj.deviceNumber)
                break;
            end
        end
        fprintf('RDKmain line 227: Calling stop(obj.t)\n');
        stop(obj.t); % Stop timer
        
        % Response handling
        if find(keyCode) == esckey % If escape  - esc during dot display
            obj.pres.esc_flag = 1;
            fprintf('RDK: Aborting display sequence -line 233 rdkMain esc key pressed during dot display. \n');
            Screen('CloseAll');
            ListenChar(0);
            return;
            
        end
        if obj.pres.esc_flag % Abort - esc during blank screen or fixation 
            fprintf('RDK: Aborting display sequence -line 240 rdkMain esc key pressed during blank screen or fixation. \n');
            Screen('CloseAll')
            ListenChar(0);
            return;
        end
        
        if find(keyCode) == pkey % If 'p'
            trial_i = trial_i - 1; % Revert trial iteration
        else
            if obj.sys.display.dual % Perform logging only if dual
                if find(keyCode) == lkey % If left arrow press
                    resp = 'L';
                    respchk = 1;
                elseif find(keyCode) == rkey % If right arrow press
                    resp = 'R';
                    respchk = 2;
                end
                fprintf('RDK: Logging L/R line 257. \n');
                % Logging output
                nextcell = find(cellfun(@isempty,out(:,size(obj.out,2)+1)),1); % Next empty cell
                out{nextcell,size(obj.out,2)+1} = resp; % Log response
                if regexp(resp,'\s') % Check if whitespace
                    out{nextcell,size(obj.out,2)+2} = 0; % No RT if no response
                else
                    out{nextcell,size(obj.out,2)+2} = secs - obj.t.UserData; % Log RT
                end
                if isempty(respchk) % Check if still empty
                    out{nextcell,size(obj.out,2)+3} = 0; % Miss if respchk is empty (no response)
                    beep;
                else
                    out{nextcell,size(obj.out,2)+3} = LRkey(nextcell,respchk); % Log LRkey entry
                    if ~LRkey(nextcell,respchk)
                        beep;
                    end
                end
            end
        end
        
        % exit cleanly out of program after the last block of the last
        % trial
         
            
        
        trial_i = trial_i + 1; % Add iteration
        
    end
    if obj.pres.esc_flag % Abort
        fprintf('RDK: Aborting display sequence -line 282 rdkMain. \n');
        break;
    end
    
    % exit cleanly out of loop and continue to write output file after the last block of the last
    % trial. This keeps the program from closing out of the program with a beep/error. - added by ars17 2/18/16
    if block_i == obj.exp.block && trial_i == obj.exp.trial_n
        return;
    end  
end

% Output

%fprintf('RDK: Writing data output (%s). \n\n\n', [obj.exp.objpath filesep
%out_file_name ]); % refer to folder where orig.mat file was created
fprintf('RDK: Writing data output (%s). \n\n\n', [p filesep out_file_name ]); % p = refer to folder where the .mat file was opened from. ars17 2/18/16

if obj.sys.display.dual % Different output header information if dual
    out_h = {'Block','Trial','PatternType','LeftCoh','RightCoh','Response','RT','Acc'};
else
    out_h = {'Block','Trial','PatternType','Coh'};
end

%cell2csv([obj.exp.objpath filesep out_file_name ],[out_h; out]); % Write
%output in folder where orig .mat file was created
cell2csv([p filesep out_file_name ],[out_h; out]); % Write output in the folder where the .mat file was opened from (p). ars17 2/18/16

% Clean-up
Screen('Preference','VisualDebugLevel',oldVisualDebugLevel);
Screen('CloseAll');
ListenChar(0);
ShowCursor;
% Close top priority
Priority(0)

end