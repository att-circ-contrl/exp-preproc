function badliststruct = ...
  epIter_beforeFunc_readBadChanList( listfile, wantmsgs )

% function badliststruct = ...
%   epIter_beforeFunc_readBadChanList( listfile, wantmsgs )
%
% This function reads a bad channel list metadata file and returns its
% contents in a structure.
%
% This is intended to be called as a "prebebeforefunc" function, per
% ITERFUNCS.txt. A typical implementation would be:
%
% beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
%   epIter_beforeFunc_readBadChanList( ...
%     sprintf(listfilepat, sessionmeta.sessionlabel, probemeta.label), ...
%     wantmsgs );
%
% "listfile" is the name of the file to read bad channel list metadata
%   from, per PREPROCFILES.txt.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "badliststruct" is a structure containg all of the variables that were in
%   the bad channel list metadata file, per PREPROCFILES.txt.


% Initialize. We can't really build safe output here.
badliststruct = struct([]);


if ~exist(listfile, 'file')
  if wantmsgs
    disp([ '###  Can''t find bad channel list file "' listfile '".' ]);
  end
else

  % Load the file variables into the return structure directly.
  badliststruct = load(listfile);

end


% Done.
end


%
% This is the end of the file.
