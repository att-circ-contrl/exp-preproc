function beforedata = ...
  epIter_beforeFunc_makeFolders( targetfile, wantmsgs )

% function beforedata = ...
%   epIter_beforeFunc_makeFolders( targetfile, wantmsgs )
%
% This function checks that the path of "targetfile" exists, and creates it
% if it doesn't. This is a wrapper for nlUtil_makeSureFolderExists().
%
% This should be called in serial processing mode. The intention is to call
% this before making parallel processing calls to iterator functions, since
% folder-checking calls from those functions may encounter race conditions.
% If other iterators are called in serial processing mode, there's no need
% to use this function.
%
% "targetfile" is a character vector with a dummy filename, or a cell array
%   of several such character vectors. Only the path of the file is checked
%   (the filename itself is ignored).
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "beforedata" is NaN (a dummy return value).


% Dummy return value.
beforedata = NaN;


% Make sure we're dealing with a list of input files.
if ~iscell(targetfile)
  targetfile = { targetfile };
end


% NOTE - No console messages to emit.


% Check that each of the input paths exists.

for fidx = 1:length(targetfile)
  nlUtil_makeSureFolderExists( targetfile{fidx} );
end



% Done.
end


%
% This is the end of the file.
