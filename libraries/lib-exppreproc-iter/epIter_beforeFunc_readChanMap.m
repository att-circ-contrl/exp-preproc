function chanstruct = epIter_beforeFunc_readChanMap( chanfile, wantmsgs )

% function chanstruct = epIter_beforeFunc_readChanMap( chanfile, wantmsgs )
%
% This function reads channel map information and returns it in a structure.
%
% This is intended to be called as part of a "probebeforefunc" function,
% per ITERFUNCS.txt. Typical implementations would be:
%
% beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
%   epIter_beforeFunc_readChanMap( ...
%      sprintf(chanfilepat, sessionmeta.sessionlabel), wantmsgs );
%
% Or, to aggregate channel map information with other information:
%
% beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
%   struct( 'chanmap', epIter_beforeFunc_readChanMap( ... ), ... );
%
%
% "chanfile" is the name of the name of the file to read channel map
%   metadata from, per PREPROCFILES.txt.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "chanstruct" is a structure with the following fields:
%   "chanlabels_raw" has unmapped channel labels from the map.
%   "chanlabels_cooked" has mapped channel labels from the map.


% Initialize to safe values.

chanstruct = struct();
chanstruct.chanlabels_raw = {};
chanstruct.chanlabels_cooked = {};


if ~exist(chanfile)
  if wantmsgs
    disp([ '###  Can''t find channel map file "' chanfile '".' ]);
  end
else
  % This has "chanlabels_raw" and "chanlabels_cooked".
  % We can just load the file variables into the return structure directly.

  chanstruct = load(chanfile);
end


% Done.
end


%
% This is the end of the file.
