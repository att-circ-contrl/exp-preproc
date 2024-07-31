function addPathsExpPreproc

% function addPathsExpPreproc
%
% This function detects its own path and adds appropriate child paths to
% Matlab's search path.
%
% No arguments or return value.


% Detect the current path.

fullname = which('addPathsExpPreproc');
[ thisdir fname fext ] = fileparts(fullname);


% Add the new paths.
% (This checks for duplicates, so we don't have to.)

% FIXME - NYI.
%addpath([ thisdir filesep 'lib-exppreproc-' ]);



% Done.
end


%
% This is the end of the file.
