% Preprocessing pipeline demo scripts - Common setup tasks.
% Written by Christopher Thomas.


%
% First, set up paths.

do_paths;


%
% Next, do configuration.
% Some of this calls library functions, so we need the paths.

do_config;


%
% Finally, do other setup tasks, which may depend on configuration switches.


% Matlab warnings.

oldwarnstate = warning('off');


% Field Trip initialization and messages.

nlFT_initFTQuietly;


% LoopUtil configuration.

% We use about 1 GB per channel-hour. The sweet spot to reduce loading time
% is 4 channels or more.
nlFT_setMemChans(4);


% Initialize parallel processing if requested.

if want_parallel
  % Ask for 4-8 workers.
  parpool([4 8]);
end


%
% This is the end of the file.
