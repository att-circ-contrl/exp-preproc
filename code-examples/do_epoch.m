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
        [ trialdir filesep '%s-%s-%s-ephys%s.mat' ], ...
        thissig, sessionmeta, probemeta, trialdefmeta, tidx, ...
        beforedata, trialdefmeta.metabytrial(tidx).(epoch_align_feature), ...
        epoch_timespan_sec, wantmsgs );


  % Iterate.

  epIter_processSessions( sessionlist, ...
    [ sessiondir filesep '%s-trialmeta.mat' ], ...
    beforefunc, afterfunc, trialfunc, want_parallel, want_messages );


  disp([ '== Finished processing "' thissig '".' ]);

end



%
% This is the end of the file.
