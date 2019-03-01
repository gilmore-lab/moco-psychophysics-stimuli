% 11/5/2015
%
% rog, ars, and wrs created script
%
% This script is used to test which keyboard character an input device
% button is linked to.
%
%
input_device = input('Enter input device keyboard (k) or gampad (g):\n', 's');

switch lower(input_device)
    case 'k' %input_device = keyboard
        obj.deviceNumber = GetKeyboardIndices; %device number for keyboard
        spkey = KbName('Space');
        esckey = KbName('Escape');
        pkey = KbName('p');
        lkey = KbName('z');
        rkey = KbName('/?');
        obj.start_key = [spkey esckey]; % Define start_fcn keys in obj properties
        obj.timer_key = [lkey rkey pkey esckey]; % Define timer_fcn keys in obj properties
        ListenChar(2);
        HideCursor;

    case 'g' % input device = gamepad - Sabrent 12 button game controller
        obj.deviceNumber = GetGamepadIndices; %device number for game pad       
        spkey = KbName('c'); % 6 button; 'c' character
        esckey = KbName('a'); % 4 button; 'a' character
        pkey = KbName('b');  % 5 button; 'b' character
        lkey = KbName('f');   % Left front 2 button; 'f' character
        rkey = KbName('g');  % Right front 2 button; 'g' character
        obj.start_key = [spkey esckey]; % Define start_fcn keys in obj properties
        obj.timer_key = [lkey rkey pkey esckey]; % Define timer_fcn keys in obj properties
        ListenChar(2);
        HideCursor;
        
    otherwise
        disp('Unknown input method.')
        % break out of this function/method
        return
end

startSecs = GetSecs;
fprintf('Starting test.\n\n');
while 1
    [keyIsDown,secs,keyCode]=PsychHID('KbCheck',obj.deviceNumber);
    if keyIsDown
        fprintf('Pressed key %s at %4.3f\n', KbName(keyCode), secs-startSecs);
        if keyCode(esckey)
            fprintf('Yay, detected a key. Quitting.\n');
            break;
            % Allows keyboard to be active after esckey pressed
            ListenChar(0);
        end
    end
    
    % this checks for the escape key on the keyboard
    % regardless of desired input device 
    
    % this uses the defined esckey as chosen by the input device
    [keyIsDown,secs,keyCode]=KbCheck; 
    
    %[keyIsDown,secs,keyCode] = PsychHID('KbCheck',GetKeyboardIndices);
    if keyIsDown
        if keyCode(esckey)
            fprintf('Ending test.\n');
            break;
            ListenChar(0);
        end
    end
end
ListenChar(0);

