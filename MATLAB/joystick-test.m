escapeKey = KbName('ESCAPE');

while 1
    [keyIsDown,secs,keyCode]=PsychHID('KbCheck',2);
    if keyIsDown
        fprintf('Pressed key %i at %3.3f\n', keyCode, secs);
    end
    [keyIsDown,secs,keyCode]=KbCheck;
    if keyIsDown
        if keyCode(escapeKey)
            break;
        end
    end
end