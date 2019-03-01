% Displays the key number when the user presses a key.

fprintf('1 of 4.  Testing KbCheck and KbName: press a key to see its number.\n');
fprintf('Press the escape key to proceed to the next demo.\n');

KbName('UnifyKeyNames'); % Unify keys

deviceNumber = GetKeyboardIndices;


%escapeKey = KbName('ESCAPE');
spkey = KbName('Space');
esckey = KbName('Escape');
pkey = KbName('p');
lkey = KbName('z');
rkey = KbName('/?');
        
start_key = [spkey esckey]; % Define start_fcn keys in obj properties
timer_key = [lkey rkey pkey esckey];

% Restrict Keys to check 
enabledKeys = [start_key timer_key];
scanList = zeros(1,256);
scanList(enabledKeys) = 1;

while KbCheck; end % Wait until all keys are released.

while 1
    % Check the state of the keyboard.
	%[ keyIsDown, seconds, keyCode ] = KbCheck;
    
    [keyIsDown,secs,keyCode] = PsychHID('KbCheck', deviceNumber, scanList); 

    % If the user is pressing a key, then display its code number and name.
    if keyIsDown
        
        % Note that we use find(keyCode) because keyCode is an array.
        % See 'help KbCheck'
        fprintf('You pressed key %i which is %s\n', find(keyCode), KbName(keyCode));
        
        
        if keyCode(41)
            break;
        end
        
          
        % If the user holds down a key, KbCheck will report multiple events.
        % To condense multiple 'keyDown' events into a single event, we wait until all
        % keys have been released.
        while KbCheck; end
    end
end
