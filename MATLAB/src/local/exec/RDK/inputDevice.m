function [spkey, esckey, lkey, rkey, pkey, deviceNumber] = inputDevice()
% 1/6/2016
% Created by ars
%
% inputDevice() is used to determine which input device is to be used in
% rdkMain.m

% Determine which input device is to be used
input_device = input('Enter input device keyboard (k) or gampad (g):\n', 's');


KbName('UnifyKeyNames'); % Unify keys

% use the defined keypresses as keyboard characters depending on which
% input device is used
switch lower(input_device)
    case 'k' %input_device = keyboard
        deviceNumber = GetKeyboardIndices; %device number for keyboard
        spkey = KbName('Space');
        esckey = KbName('Escape');
        pkey = KbName('p');
        lkey = KbName('z');
        rkey = KbName('/?');
              
        ListenChar(2);
        HideCursor;

    case 'g' % input device = gamepad - Sabrent 12 button game controller
        deviceNumber = GetGamepadIndices; %device number for game pad       
        spkey = KbName('c'); % 6 button; 'c' character
        esckey = KbName('a'); % 4 button; 'a' character
        pkey = KbName('b');  % 5 button; 'b' character
        lkey = KbName('f');   % Left front 2 button; 'f' character
        rkey = KbName('g');  % Right front 2 button; 'g' character
             
        ListenChar(2);
        HideCursor;
        
    otherwise
        disp('Unknown input method.')
        % break out of this function/method
        return
end
end