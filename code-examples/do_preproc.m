% Preprocessing pipeline demo scripts - Preprocessing.
% This reads the session metadata and pre-processes sessions and trials.
% Written by Christopher Thomas.


%
% Setup and configuration.

do_setup_stuff;



%
% Read global metadata.

infile = [ sessiondir filesep 'dataset-meta.mat' ];
if ~exist(infile, 'file')
  disp('###  Can''t find global metadata. Bailing out.');
  exit;
else
  % This provides "sessionlist", "ttldefs", "probelabels", and "probetitles".
  % We only care about "sessionlist".
  load(infile);
end



%
% Do raw segmentation.


if want_do_segment

  % Use "before trial" processing to get the probe channel map.

  beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
    epIter_beforeFunc_readChanMap( ...
      [ sessiondir filesep sessionmeta.sessionlabel '-chanmap.mat' ], ...
      wantmsgs );

  % No "after trial" processing.

  % Use the FLToken 2022-2023 raw data extraction function for trial iteration.

  trialfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
      epIter_trialFunc_raw_FLToken2022( ...
        [ trialdir filesep '%s-%s/%s-ephysraw.mat' ], want_force_redo, ...
        sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs );

  % Iterate.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], beforefunc, NaN, ...
    trialfunc, want_parallel, want_messages );

end



%
% Do signal conditioning (artifact removal and notch filtering).


if want_do_sigcondition

  % No "before trial" processing.

  % No "after trial" processing.

  trialfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
      epIter_trialFunc_sigclean( ...
        [ trialdir filesep '%s-%s/%s-ephysclean.mat' ], ...
        [ trialdir filesep '%s-%s/%s-ephysraw.mat' ], want_force_redo, ...
        sessionmeta, probemeta, trialdefmeta, tidx, ...
        artifact_passes, artifact_func, ...
        notch_filter_freqs, notch_filter_bandwidth, wantmsgs );

  % Iterate.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], NaN, NaN, ...
    trialfunc, want_parallel, want_messages );

end



%
% Do bad channel analysis.


if want_do_analyze_badchans

  if want_detect_badchans
    badchansbyhand = struct();
  end

  % No "before trial" processing.

  afterfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, ...
      beforedata, trialresults, wantmsgs ) ...
      epIter_afterFunc_badInfoAll( ...
        [ sessiondir filesep '%s-%s-badinfo.mat' ], want_force_redo, ...
        sessionmeta, probemeta, trialdefmeta, ...
        trialresults, badconfigall, badchansbyhand, wantmsgs );

  trialfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
      epIter_trialFunc_badInfoAll( ...
        [ sessiondir filesep '%s-%s-badinfo.mat' ], ...
        [ trialdir filesep '%s-%s/%s-ephysclean.mat' ], want_force_redo, ...
        sessionmeta, probemeta, trialdefmeta, tidx, badconfigall, wantmsgs );

  % Iterate.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], NaN, afterfunc, ...
    trialfunc, want_parallel, want_messages );

end



%
% Use the bad channel analysis to build bad channel lists.


if want_do_list_badchans

  % "Before trial" processing handles list consolidation.

  beforefunc = ...
    @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
      epIter_beforeFunc_badListMergeInfo( ...
        [ sessiondir filesep '%s-%s-badlist.mat' ], ...
        [ sessiondir filesep '%s-%s-badinfo.mat' ], want_force_redo, ...
        sessionmeta, probemeta, badconfigall, wantmsgs );

  % "After trial" processing makes plots.

  afterfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, ...
      beforedata, trialresults, wantmsgs ) ...
      epIter_afterFunc_badListPlotAll( ...
        [ plotdir filesep '%s-%s' ], ...
        [ sessiondir filesep '%s-%s-badinfo.mat' ], ...
        beforedata, sessionmeta, probemeta, trialdefmeta, ...
        badplotconfigall, wantmsgs );

  % No "per trial" processing.

  % Iterate.
  % NOTE - Only the per trial stuff is parallelizable, so want_parallel
  % doesn't do anything here.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], beforefunc, afterfunc, ...
    NaN, want_parallel, want_messages );

end



%
% Get derived signals, discarding bad channels.
% This includes doing re-referencing, which is why bad channels have to be
% known.


if want_do_derived_signals

  % Use "before trial" to get the bad channel list.
  % We need to omit these from the re-referencing reference list.

  beforefunc = @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
    epIter_beforeFunc_readBadChanList( ...
      sprintf( [ sessiondir filesep '%s-%s-badlist.mat' ], ...
        sessionmeta.sessionlabel, probemeta.label ), wantmsgs );

  % No "after trial" processing.

  % Use the "getDerivedSignals" wrapper as the trial function.

  trialfunc = ...
    @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
      epIter_trialFunc_derived( ...
        [ trialdir filesep '%s-%s/%s-ephys%s.mat' ], ...
        [ trialdir filesep '%s-%s/%s-ephysclean.mat' ], want_force_redo, ...
        sessionmeta, probemeta, trialdefmeta, tidx, ...
        beforedata, derived_wanted, derived_config, wantmsgs );


  % Iterate.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], beforefunc, NaN, ...
    trialfunc, want_parallel, want_messages );

end



%
% Done.


%
% This is the end of the file.
