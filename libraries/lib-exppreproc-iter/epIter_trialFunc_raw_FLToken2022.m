function trialresult = epIter_trialFunc_raw_FLToken2022( ...
  outfilepat, wantforce, sessionmeta, probemeta, trialdefmeta, tidx, ...
  chanmapdata, wantmsgs )

% function trialresult = epIter_trialFunc_raw_FLToken2022( ...
%   outfilepat, wantforce, sessionmeta, probemeta, trialdefmeta, tidx, ...
%   chanmapdata, wantmsgs )
%
% This function reads raw ephys data from a FLToken 2022-2023 session folder
% and saves the specified trial to disk in Field Trip Format (per
% PREPROCFILES.txt).
%
% This follows Charlie's conventions for channel labelling and ordering.
%
% This is intended to be called as a "trialfunc" function, per ITERFUNCS.txt.
% A typical implementation would be:
%
% trialfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
%     epIter_trialFunc_raw_FLToken2022( ...
%       [ destfolder filesep '%s-%s-%s-ephysraw.mat' ], want_force_raw, ...
%       sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs );
%
% "outfilepat" is a sprintf pattern used to generate the output file name
%   for saving Field Trip data. This needs three '%s' tokens, for the
%   session label, probe label, and trial label (in that order). The output
%   file will contain "ftdata_raw" and "ftlabels_cooked", per PREPROCFILES.txt.
% "wantforce" is true to redo processing even if the output file already
%   exists, and false to skip processing if the output file is present.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "tidx" is the row index of the present trial within trial metadata tables.
% "chanmapdata" is a structure with the following fields:
%   "chanlabels_raw" has unmapped channel labels from the map.
%   "chanlabels_cooked" has mapped channel labels from the map.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "trialresult" is always NaN (unused).


% Set the return value.
trialresult = NaN;


%
% Unpack various pieces of metadata we'll need.

outfile  = sprintf( outfilepat, sessionmeta.sessionlabel, ...
  probemeta.label, trialdefmeta.triallabels{tidx} );

% FLToken 2022-2023 saved data in Open Ephys format.
infolder = sessionmeta.folders_openephys{1};

thistrialdef = trialdefmeta.trialdefs(tidx,:);

chanlabels_raw = chanmapdata.chanlabels_raw;
chanlabels_cooked = chanmapdata.chanlabels_cooked;

% NOTE - This follow's Charlie's conventions for channel labels and indices.
desiredchanlabels = chanlabels_raw( probemeta.channums );


%
% Read this trial's raw data, and map/shuffle channels.

if (~wantforce) && exist(outfile, 'file')
  if wantmsgs
    disp('.. Raw segmented data is already present; skipping trial.');
  end
else

  if wantmsgs
    disp('.. Reading raw ephys data.');
    trialtime = tic;
  end


  % There's no point in calling "readAndCleanSignals" if we're not
  % using any of the features it provides.
  % Notch filtering happens after artifact rejection, not here.

  header_raw = ...
    ft_read_header( infolder, 'headerformat', 'nlFT_readHeader' );

  config_load = struct( ...
    'headerfile', infolder, 'headerformat', 'nlFT_readHeader', ...
    'datafile', infolder, 'dataformat', 'nlFT_readDataDouble', ...
    'trl', thistrialdef, ...
    'detrend', 'yes', 'feedback', 'no' );

  config_load.channel = ...
    ft_channelselection( desiredchanlabels, header_raw.label, {} );

  ftdata_raw = ft_preprocessing( config_load );


  % Charlie is leaving the raw names in ftdata but is sorting on their
  % cooked translations.

  ftlabels_cooked = nlFT_mapChannelLabels( ftdata_raw.label, ...
    chanlabels_raw, chanlabels_cooked );
  ftdata_raw = euFT_sortChannels( ftdata_raw, ftlabels_cooked );

  % Update the sorted labels to match the new order in ftdata_raw.
  % This should just be sort(ftlabels_cooked).
  ftlabels_cooked = nlFT_mapChannelLabels( ftdata_raw.label, ...
    chanlabels_raw, chanlabels_cooked );


  if wantmsgs
    disp('.. Writing raw ephys data to disk.');
  end

  % We have to use "-fromstruct" format inside parfor.
  savedata = struct();
  savedata.ftdata_raw = ftdata_raw;
  savedata.ftlabels_cooked = ftlabels_cooked;
  save( outfile, '-fromstruct', savedata, '-v7.3' );

  if wantmsgs
    durstring = nlUtil_makePrettyTime( toc(trialtime) );
    disp([ '.. Finished reading raw ephys data (' durstring ').' ]);
  end

end


% Done.
end


%
% This is the end of the file.
