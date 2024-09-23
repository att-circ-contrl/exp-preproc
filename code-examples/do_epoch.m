% Preprocessing pipeline demo scripts - Epoch extraction.
% Written by Christopher Thomas.


%
% Setup and configuration.

do_setup_stuff;



%
% Read global metadata.

infile = [ sessiondir filesep 'dataset-meta.mat' ];
if ~exist(infile)
  disp('###  Can''t find global metadata. Bailing out.');
  edit;
else
  % This provides "sessionlist", "ttldefs", "probelabels", and "probetitles".
  % We only care about "sessionlist".
  load(infile);
end



%
% Do epoch segmentation and alignment.

% Iterate signal types as the outer loop.

for sigidx = 1:length(epoch_sigs_wanted)

  thissig = epoch_sigs_wanted{sigidx};

  disp([ '== Processing "' thissig '".' ]);


  % We have to set up handles inside the signal type loop, since filenames
  % and "ftdata_XXX" variable names depend on signal type.


  % Use "before trial" to get the bad channel list.
  % These will be dropped from the trials.

  beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
    epIter_beforeFunc_readBadChanList( ...
      sprintf( [ sessiondir filesep '%s-%s-badlist.mat' ], ...
        sessionmeta.sessionlabel, probemeta.label ), wantmsgs );

  % Use "after processing" to merge and save the trimmed trials.

  afterfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, ...
      beforedata, trialresults, wantmsgs ) ...
      epIter_afterFunc_epoch( ...
        [ epochdir filesep '%s-%s-' thissig '-ephys.mat' ], ...
        [ epochdir filesep '%s-%s-' thissig '-meta.mat' ], ...
        sessionmeta, probemeta, trialdefmeta, trialresults, wantmsgs );

  % Use "per trial" processing to read and trim individual trials.

  trialfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
      epIter_trialFunc_epoch( ...
        [ trialdir filesep '%s-%s/%s-ephys%s.mat' ], ...
        thissig, sessionmeta, probemeta, trialdefmeta, tidx, ...
        beforedata, trialdefmeta.metabytrial(tidx).(epoch_align_feature), ...
        epoch_timespan_sec, wantmsgs );


  % Iterate.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], ...
    beforefunc, afterfunc, trialfunc, want_parallel, want_messages );


  %
  % Make plots if requested.

  beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
    helper_plotEpochData( ...
      sprintf( [ epochdir filesep '%s-%s-' thissig '-ephys.mat' ], ...
        sessionmeta.sessionlabel, probemeta.label ), ...
      sprintf( [ epochdir filesep '%s-%s-' thissig '-meta.mat' ], ...
        sessionmeta.sessionlabel, probemeta.label ), ...
      plotdir, thissig, plotconfig_epoch, wantmsgs );

  if plotconfig_epoch.want_timelock || plotconfig_epoch.want_trials
    epIter_processSessions( sessionlist, ...
      [ sessiondir filesep '%s-trialmeta.mat' ], ...
      beforefunc, NaN, NaN, want_parallel, want_messages );
  end


  % Ending banner.

  disp([ '== Finished processing "' thissig '".' ]);

end



%
% Helper functions.


function retval = helper_plotEpochData( ...
  ephysfile, metafile, plotfolder, siglabel, plotconfig, wantmsgs )

  % Return value isn't used, so set it to NaN.
  retval = NaN;


  % This has "ftdata" and "ftlabels_cooked".
  load(ephysfile);

  % Swap in cooked lables for plotting.
  ftdata.label = ftlabels_cooked;


  % This has metadata variables per PREPROCFILES.txt.
  % Put them all into a structure for convenience.
  epochmeta = load(metafile);

  % Unpack some of the metadata.
  sessionlabel = epochmeta.sessionmeta.sessionlabel;
  sessiontitle = epochmeta.sessionmeta.sessiontitle;
  probelabel = epochmeta.probemeta.label;
  probetitle = epochmeta.probemeta.title;
  trialtitles = epochmeta.newtrialmeta.trialnames;

  % Reasonable plotting defaults.
  plotsigma = 2.0;
  zoomranges = {[]};
  zoomlabels = {'wide'};


  if plotconfig.want_timelock
    % Generate timelock data.
    % We need to force alignment sanity first.

    ftdata = nlFT_roundTrialTimestamps( ftdata );
    fttimelock = ft_timelockanalysis( struct(), ftdata );


    % Render the plots.

    if wantmsgs
      disp('-- Plotting time-locked data.');
    end

    euPlot_plotFTTimelock( fttimelock, ...
      plotsigma, plotconfig.timelock_types, zoomranges, zoomlabels, ...
      plotconfig.max_plots, ...
      [ sessiontitle ' - ' probetitle ' - ' siglabel ], ...
      [ plotfolder filesep 'timelock-' sessionlabel '-' probelabel ...
        '-' siglabel ] );
  end


  if plotconfig.want_trials
    % Render the plots.

    if wantmsgs
      disp('-- Plotting trials.');
    end

    euPlot_plotFTTrials( ftdata, ftdata.fsample, [], ...
      trialtitles, NaN, struct(), NaN, plotconfig.trial_types, ...
      zoomranges, zoomlabels, plotconfig.max_plots, ...
      [ sessiontitle ' - ' probetitle ' - ' siglabel ], ...
      [ plotfolder filesep 'trials-' sessionlabel '-' probelabel ...
        '-' siglabel ] );
  end

end



%
% This is the end of the file.
