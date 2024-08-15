function trialresult = epIter_trialFunc_derived( ...
  outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
  trialdefmeta, tidx, badchans, derived_wanted, derived_config, wantmsgs )

% function trialresult = epIter_trialFunc_derived( ...
%   outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
%   trialdefmeta, tidx, badchans, derived_wanted, derived_config, wantmsgs )
%
% This function reads per-trial signal-conditioned ephys data and performs
% re-referencing, filtering, and rectification to produce derived signals.
% These are saved to disk in Field Trip format (per PREPROCFILES.txt).
%
% This is intended to be called as a "trialfunc" function, per ITERFUNCS.txt.
% A typical implementation would be:
%
% trialfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
%     epIter_trialFunc_derived( ...
%       [ destfolder filesep '%s-%s-%s-ephys%s.mat' ], ...
%       [ srcfolder filesep '%s-%s-%s-ephysclean.mat' ], ...
%       want_force_derived, sessionmeta, probemeta, trialdefmeta, tidx, ...
%       beforedata, derived_wanted_list, derived_config_struct, wantmsgs );
%
% "outfilepat" is a sprintf pattern used to generate the output file name
%   for saving Field Trip data. This needs four '%s' tokens, for the
%   session label, probe label, trial label, and signal type (in that order).
%   The output file will contain "ftdata_XXX" and "ftlabelscooked", per
%   PREPROCFILES.txt.
% "infilepat" is a sprintf pattern used to generate the input file name
%   for reading raw trials in Field Trip format. This needs three '%s', for
%   the session label, probe label, and trial label (in that order). The
%   input file should contain "ftdata_clean" and "ftlabels_cooked", per
%   PREPROCFILES.txt.
% "wantforce" is true to redo preprocessing even if the output files already
%   exist, and false to avoid overwriting existing output files.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "tidx" is the row index of the present trial within trial metadata tables.
% "badchans" is a structure containing all of the variables in the bad
%   channel list file, per PREPROCFILES.txt.
% "derived_wanted" is a cell array containing zero or more of 'wb', 'lfp',
%   'hp', and 'mua', per PREPROCFILES.txt.
% "derived_config" is a structure with the following fields (defined even
%   if the specified processing steps aren't requested):
%   "lfp_maxfreq" is the low-pass filter corner frequency for extracting LFP
%     signals.
%   "lfp_samprate" is the downsampled sampling rate for LFP signals.
%   "highpass_minfreq" is the high-pass filter corner frequency for
%     extracting spike waveforms.
%   "mua_band" [ min max ] specifies the band-pass filter corners for
%     extracting multi-unit activity prior to rectification.
%   "mua_lowpass" is the low-pass filter corner for smoothing multi-unit
%     activity after rectification.
%   "mua_samprate" is the downsampled sampling rate for MUA signals.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "trialresult" is always NaN (unused).


% Set the return value.
trialresult = NaN;


% Unpack various pieces of metadata we'll need.

infile = sprintf( infilepat, sessionmeta.sessionlabel, ...
  probemeta.label, trialdefmeta.triallabels{tidx} );

% Sanity-check the derived signals list.
derived_wanted = intersect( derived_wanted, { 'wb', 'lfp', 'hp', 'mua' } );

outfilelut = struct();
for didx = 1:length(derived_wanted)
  outfilelut.(derived_wanted{didx}) = ...
    sprintf( outfilepat, sessionmeta.sessionlabel, probemeta.label, ...
      trialdefmeta.triallabels{tidx}, derived_wanted{didx} );
end

% See if we already have all of the derived signals.
have_already = true;
for didx = 1:length(derived_wanted)
  outfile = outfilelut.(derived_wanted{didx});
  have_already = have_already & exist(outfile, 'file');
end



% Proceed with processing if we have input and need output.

if isempty(derived_wanted)
  % Covered by "have_already", but should get its own message, and shouldn't
  % be affected by "wantforce".
  if wantmsgs
    disp('.. No derived ephys signals requested.');
  end
elseif have_already && (~wantforce)
  if wantmsgs
    disp('.. Derived ephys signals are already present; skipping trial.');
  end
elseif ~exist(infile, 'file')
  if wantmsgs
    disp([ '###  Input file "' infile '" does not exist!' ]);
  end
else

  if wantmsgs
    disp('.. Performing re-referencing and computing derived signals.');
    trialtime = tic;
  end


  % Load the signal-conditioned raw data.
  % This gives us "ftdata_clean" and "ftlabels_cooked".

  load(infile);

  % Squash NaN holes but remember where they were.

  nanmask = nlFT_getNaNMask( ftdata_clean );
  ftdata_clean = nlFT_fillNaN( ftdata_clean );


  %
  % Re-referencing. This gives us wideband data.

  goodchans = setdiff( ftdata_clean.label, badchans.badraw );
  goodchans = reshape(goodchans, [], 1);

  ftconfig = struct( 'reref', 'yes', 'refmethod', 'median', ...
    'feedback', 'no' );
  ftconfig.channel = ftdata_clean.label;
  ftconfig.refchannel = goodchans;

  ftdata_wb = ft_preprocessing( ftconfig, ftdata_clean );


  %
  % Call the helper function for derived signals.

  want_ft_quiet = true;
  [ ftdata_lfp ftdata_hp ftdata_mua ] = euFT_getDerivedSignals( ...
    ftdata_wb, derived_config.lfp_maxfreq, derived_config.lfp_samprate, ...
    derived_config.highpass_minfreq, derived_config.mua_band, ...
    derived_config.mua_lowpass, derived_config.mua_samprate, want_ft_quiet );


  %
  % Save the data.

  % NOTE - Restoring NaN holes in wideband but not in derived signals!
  % We aren't equipped to restore holes in resampled signals.

  ftdata_wb = nlFT_applyNaNMask( ftdata_wb, nanmask );

  ftdatalut = struct();
  ftdatalut.wb = ftdata_wb;
  ftdatalut.lfp = ftdata_lfp;
  ftdatalut.hp = ftdata_hp;
  ftdatalut.mua = ftdata_mua;

  for didx = 1:length(derived_wanted)
    thislabel = derived_wanted{didx};
    outfile = outfilelut.(thislabel);

    if isfield( ftdatalut, thislabel )
      if wantforce || (~exist( outfile, 'file' ))
        % We have to use "-fromstruct" format inside parfor.
        savedata = struct();
        savedata.([ 'ftdata_' thislabel ]) = ftdatalut.(thislabel);
        savedata.ftlabels_cooked = ftlabels_cooked;
        save( outfile, '-fromstruct', savedata, '-v7.3' );
      end
    end
  end


  % Done.

  if wantmsgs
    durstring = nlUtil_makePrettyTime( toc(trialtime) );
    disp([ '.. Finished computing derived signals (' durstring ').' ]);
  end

end


% Done.
end


%
% This is the end of the file.
