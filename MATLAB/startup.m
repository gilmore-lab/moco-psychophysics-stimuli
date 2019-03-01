% % Random number stream
% if verLessThan('matlab','8.2.0') % 2013b
%     RandStream.setDefaultStream(RandStream('mt19937ar','seed',sum(100*clock)));
% else
%     RandStream.setGlobalStream(RandStream('mt19937ar','seed',sum(100*clock)));
% end
% 
% localdir = '/Users/admin_rickgilmore/Documents/MATLAB/src/local/';
% % system([localdir 'chk' filesep 'verchk.sh']); % Run Update
% % 
% % mntdir = '~/Hammer/';
% usedir = '/Users/admin_rickgilmore/';
% 
% %fid = fopen('dev');
% %dev = str2double(fgetl(fid));
% %fclose(fid);
% 
% % Check dev status
% %if dev
% %    mntscrpt = 'mount-hammer.sh';
% %    fprintf('Attempting to mount hammer...\n');
% %    [stat] = system(['./' mntscrpt]);
% %    pause(1);
% %    if stat % Check mount status, appropriate path directory
% %        fprintf('Unable to mount hammer locally.  Check internet connection and mount settings (%s). \n', mntscrpt);
% %        fprintf('Using local directory (%s). \n\n', localdir);
% %        [~,d] = system(['ls -m ' localdir]);
% %        d = regexp(d(1:end-1),',\s','split');
% %        useflg = 1;
% %    else
% %        fprintf('Success! \n');
% %        fprintf('Hammer mounted on local drive (%s) \n\n', mntdir);
% %        [~,d] = system(['ls -m ' mntdir]);
% %        d = regexp(d(1:end-1),',\s','split');
% %        useflg = 2;
% %    end
% %else
%     [~,d] = system(['ls -m ' localdir]);
%     d = regexp(d(1:end-1),',\s','split');
%     useflg = 1;
% %end
% 
% % Add paths
% pass = 'README[.]md|ver';
% d = d(cellfun(@isempty,cellfun(@(y)(regexp(y,pass)),d,'UniformOutput',false)));
% cellfun(@(y)(addpath([usedir{useflg} strtrim(y)])),d,'UniformOutput',false);
% [~,d2] = system(['ls -mh ' usedir{useflg} 'exec']);
% d2 = regexp(d2(1:end-1),',\s','split');
% cellfun(@(y)(addpath([usedir{useflg} 'exec' filesep strtrim(y)])),d2,'UniformOutput',false);
% 
% %gilmoreCommands = cellfun(@(y)(['run' y]),d2,'UniformOutput',false)';
% 
% % Clean up
% clear d d2 localdir mntdir usedir useflg pass

