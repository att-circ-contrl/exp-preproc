function trialresult = epIter_trialFunc_badInfoAll( ...
  outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
  trialdefmeta, tidx, configall, wantmsgs )

% function trialresult = epIter_trialFunc_badInfoAll( ...
%   outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
%   trialdefmeta, tidx, configall, wantmsgs )
%
% This function reads per-trial signal-conditioned ephys data and performs
% bad channel detection by various methods. The results structure contains
% raw analysis data from each algorithm (the "badchansXXX" fields described
% in PREPROCFILES.txt for "XXX-badinfo.mat").
%
% Algorithms are enabled by passing algorithm-specific configuration
% parameters as fields in "configall".
%
% NOTE - While this does not generate an output file itself, it does test
% for the presence of an output file to see if the analysis needs to be
% performed or can be skipped.
%
% This is intended to be called as a "trialfunc" function, per ITERFUNCS.txt.
% A typical implementation would be:
%
% trialfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
%     epIter_trialFunc_badInfoAll( ...
%       [ destfolder filesep '%s-%s-badinfo.mat' ], ...
%       [ srcfolder filesep '%s-%s-%s-ephysclean.mat' ], ...
%       want_force_badinfo, sessionmeta, probemeta, trialdefmeta, tidx, ...
%       bad_config_struct_all, wantmsgs );
%
% "outfilepat" is a sprintf pattern used to generate the output file name
%   for saving per-probe bad channel information. This needs two '%s' tokens,
%   for the session label and probe label (in that order).
%   NOTE - This function doesn't generate the output file. It tests for it
%   to skip analysis if the file exists and "wantforce" is false.
% "infilepat" is a sprintf pattern used to generate the input file name for
%   reading signal-conditioned trials in Field Trip format. This needs three
%   '%s' tokens, for the session label, probe label, and trial label (in that
%   order). The input file should contain "ftdata_clean" and
%   "ftlabels_cooked", per PREPROCFILES.txt.
% "wantforce" is true to redo processing even if the output file already
%   exists, and false to skip processing if the output file is present.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "tidx" is the row index of the present trial within trial metadata tables.
% "configall" is a configuration structure for bad channel analysis. Each
%   field corresponds to an algorithm and contains a configuration structure,
%   per BADCHANCONFIG.txt:
%   "log" contains configuration information for hand-annotated log entries.
%   "spect" contains configuration information for spectral analysis.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "trialresult" is a structure with fields with the same field names as
%   "configall". Each field contains a structure holding analysis results
%   and metadata. Additional fields "ftlabels_raw" and "ftlabels_cooked"
%   store raw and cooked channel labels.


% Initialize the return structure.

trialresult = struct();

trialresult.ftlabels_raw = {};
trialresult.ftlabels_cooked = {};



% Unpack various pieces of metadata we'll need.

% Output file only has two labels, not three.
outfile = sprintf( outfilepat, sessionmeta.sessionlabel, probemeta.label );

infile = sprintf( infilepat, sessionmeta.sessionlabel, ...
  probemeta.label, trialdefmeta.triallabels{tidx} );



if (~wantforce) && exist(outfile, 'file')
  if wantmsgs
    disp('.. Bad channel analysis data is already present; skipping trial.');
  end
elseif ~exist(infile, 'file')
  if wantmsgs
    disp([ '###  Input file "' infile '" does not exist!' ]);
  end
else

  if wantmsgs
    disp('.. Analyzing bad-channel signatures.');
    trialtime = tic;
  end


  % Load the raw data.
  % This gives us ftdata_clean and ftlabels_cooked.

  load(infile);

  ftlabels_raw = ftdata_clean.label;


  % Store channel name metadata.
  % Doing this per-trial is wasteful but tolerable.

  trialresult.ftlabels_raw = ftlabels_raw;
  trialresult.ftlabels_cooked = ftlabels_cooked;



  % Check for log annotations.

  % FIXME - We should do this only once, in the aggregation phase, but
  % we need raw and cooked label information, which we only have from trials.
  % We also need to know the channel order in the FT data, not just which
  % channels are used.
  % This is a fast operation, so live with duplicating it nTrials times.

  if isfield( configall, 'log' )

    % Merge the log file's per-probe lists. Probe indices may change due
    % to bad probe pruning, so we can't just select the one we want.

    lognums_good = sessionmeta.logdata.PROBE_goodchannels;
    lognums_good = [ lognums_good{:} ];

    lognums_bad = sessionmeta.logdata.PROBE_badchannels;
    lognums_bad = [ lognums_bad{:} ];


    % Select only the annotated numbers that are present on this probe.
    % NOTE - I'm assuming Louie and Charlie used the same numbering scheme
    % on their spreadsheet for probe definitions as they did in the log files
    % for annotating good and bad channels!
    % They're usually using cooked numbers for both.

    [ scratch nameidx logidx ] = intersect(probemeta.channums, lognums_good);
    thisgoodlog = probemeta.chanlabels(nameidx);

    [ scratch nameidx logidx ] = intersect(probemeta.channums, lognums_bad);
    thisbadlog = probemeta.chanlabels(nameidx);


    % Make sure we're dealing with raw labels.

    if configall.log.annotated_are_cooked
      thisgoodlog = nlFT_mapChannelLabels( thisgoodlog, ...
        ftlabels_cooked, ftlabels_raw );
      thisbadlog = nlFT_mapChannelLabels( thisbadlog, ...
        ftlabels_cooked, ftlabels_raw );
    end


    % Store log-based bad channel lists.

    logresults = struct();
    logresults.good = thisgoodlog;
    logresults.bad = thisbadlog;

    trialresult.log = logresults;

  end



  % Perform spectral analysis.

  if isfield( configall, 'spect' )

    configspect = configall.spect;

    % Copy config metadata.
    % Doing this per-trial is wasteful but tolerable.

    spectresults = struct();
    spectresults.freqedges = configspect.freqedges;


    % Do the spectral analysis.
    % NOTE - This tolerates multiple trials if our input data had them.
    [ spectraw toneraw ] = nlProc_getBandPower( ...
      ftdata_clean.trial, ftdata_clean.fsample, configspect.freqedges );

    % Convert relative tone measure to log10 scale.
    toneraw = log10(toneraw);

    % Store this trial's results.
    spectresults.bandpower = spectraw;
    spectresults.tonepower = toneraw;

    trialresult.spect = spectresults;

  end



   % FIXME - Time-domain PCA/ICA and XC analysis results go here.



  if wantmsgs
    durstring = nlUtil_makePrettyTime( toc(trialtime) );
    disp([ '.. Finished analyzing (' durstring ').' ]);
  end


% Done.
end


%
% This is the end of the file.
