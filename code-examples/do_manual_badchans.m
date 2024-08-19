% Preprocessing pipeline demo scripts - Manual bad channels.
% We can override the results of bad channel detection with the manual lists
% defined here.
% Written by Christopher Thomas.


% These are manually-compiled bad channel lists.

% Automated detection isn't perfect, so for each session, I plotted the
% results of the bad channel analysis and comiled lists of bad channels by
% hand based on those plots.

% These are cooked channel labels, just like the experiment log.


badchansbyhand = struct();


% 2022 07 13 session.

scratch = struct();

% Also suspicious: 259, 260, 284, 291, 292, 304.
scratch.('prACC1') = ...
{ 'CH_257', 'CH_258', 'CH_269', 'CH_285', 'CH_286', 'CH_297', 'CH_300', ...
  'CH_316', 'CH_317', 'CH_318', 'CH_319', 'CH_320' };

% This looks like it had four very different layers.
% Also suspicious: 001, 002, 044.
% 016/017/018/045 might be a bad group or might be a real feature.
scratch.('prPFC1') = ...
{ 'CH_029', 'CH_030', 'CH_060', 'CH_061', 'CH_062', 'CH_063', 'CH_064' };

% This also seems to have layers and several different mixed types.
% Might be bad or might be real: 131/132/133 blob at 60-120 Hz.
scratch.('prCD1') = ...
{ 'CH_130', 'CH_158', 'CH_188', 'CH_189', 'CH_190', 'CH_191', 'CH_192' };

badchansbyhand.('FrProbe0322071300201') = scratch;


%
% This is the end of the file.
