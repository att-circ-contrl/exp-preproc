function epIter_afterFunc_epochPrune( ...
  infilepat_ephys, infilepat_meta, outfilepat_ephys, outfilepat_meta, ...
  sessionlabel, probelabel, required_time_range, long_trial_threshold, ...
  trials_wanted, chans_wanted, wantmsgs )

% function epIter_afterFunc_epochPrune( ...
%   infilepat_ephys, infilepat_meta, outfilepat_ephys, outfilepat_meta, ...
%   sessionlabel, probelabel, required_time_range, long_trial_threshold, ...
%   trials_wanted, chans_wanted, wantmsgs )
%
% This function discards trials from epoched metadata that don't meet
% acceptance criteria. Epoched trials must cover a desired time range,
% trials before epoch trimming must not have been too long, and trials and
% channels may also be filtered or decimated to generate smaller test
% datasets.
%
% "infilepat_ephys" is a sprintf pattern used to generate the input file name
%   for per-probe epoched Field Trip data (per PREPROCFILES.txt). This needs
%   two '%s' tokens, for the session label and probe label (in that order).
% "infilepat_meta" is a sprintf pattern used to generate the input file name
%   for per-probe epoched metadata (per PREPROCFILES.txt). This needs two
%   '%s' tokens, for the session label and probe label (in that order).
% "outfilepat_ephys" is a sprintf pattern used to generate the output file
%   name for the pruned Field Trip data.
% "outfilepat_meta" is a sprintf pattern used to generate the output file
%   name for the pruned metadata.
% "sessionlabel" is the filename-safe session label (from session metadata).
% "probelabel" is the filename-safe probe label (from the probe definition).
% "required_time_range" [ min max ] is the time range in seconds that the
%   epoched trial needs to cover.
% "long_trial_threshold" is a factor to multiply the median non-epoched
%   trial duration by. Any non-epoched trial longer than this is discarded.
% "trials_wanted" is either a scalar (the maximum number of trials to save)
%   or a boolean vector (true for trials to be kept, false to discard).
% "chans_wanted" is either a scalar (the maximum number of channels to save)
%   or a cell array containing cooked channel labels to be kept. Channels
%   that are in this list but not the data are ignored (so a global list
%   rather than per-probe lists is fine).
% "wantmsgs" is true to emit console messages and false otherwise.
%
% No return value.


% Get filenames.

infile_ephys = sprintf( infilepat_ephys, sessionlabel, probelabel );
infile_meta = sprintf( infilepat_meta, sessionlabel, probelabel );

outfile_ephys = sprintf( outfilepat_ephys, sessionlabel, probelabel );
outfile_meta = sprintf( outfilepat_meta, sessionlabel, probelabel );

nlUtil_makeSureFolderExists(outfile_ephys);
nlUtil_makeSureFolderExists(outfile_meta);



% Load the epoched data and metadata.

if wantmsgs
  disp('.. Reading full epoched dataset.');
end

oldmeta = load(infile_meta);
oldephys = load(infile_ephys);



% Identify before-epoch trials that are too long.

trialdeftab = oldmeta.oldtrialmeta.trialdeftable;

durlist = trialdeftab.timeend - trialdeftab.timestart;

durmedian = median(durlist);
durlong = long_trial_threshold * durmedian;

keepmasklong = (durlist <= durlong);
trialcountorig = length(keepmasklong);



% Identify epoched trials that are too short.
% We have to do this by looking at timestamps, since we didn't save the
% trial definitioni structures for making epoched data.

epsilon = 1e-3;
mintime = min(required_time_range) + epsilon;
maxtime = max(required_time_range) - epsilon;

timeliststart = [];
timelistend = [];

trialcountepoched = length(oldephys.ftdata.time);
for tidx = 1:trialcountepoched
  thistime = oldephys.ftdata.time{tidx};
  timeliststart(tidx) = min(thistime);
  timelistend(tidx) = max(thistime);
end

keepmaskshort = (timeliststart <= mintime) & (timelistend >= maxtime);

% FIXME - Diagnostics.
if false && wantmsgs
  scratch = prctile(timeliststart, [ 10 25 50 75 90 ]);
  disp(sprintf( 'xx  Start times:  %+.2f / %+.2f | %+.2f | %+.2f / %+.2f', ...
    scratch(1), scratch(2), scratch(3), scratch(4), scratch(5) ));
  scratch = prctile(timelistend, [ 1 2 5 10 25 50 75 90 ]);
  disp(sprintf( [ 'xx  End times:  %+.2f / %+.2f / %+.2f / ' ...
    '%+.2f / %+.2f | %+.2f | %+.2f / %+.2f' ], ...
    scratch(1), scratch(2), scratch(3), ...
    scratch(4), scratch(5), scratch(6), scratch(7), scratch(8) ));
  disp(sprintf( 'xx  Want %+.2f to %+.2f.', mintime, maxtime ));
end



% Report wrong-size trials.

if wantmsgs
  disp(sprintf( '..  %d short trials (of %d), %d long trials (of %d).', ...
    trialcountepoched - sum(keepmaskshort), trialcountepoched, ...
    trialcountorig - sum(keepmasklong), trialcountorig ));
end



% Decimate trials, if requested.

if islogical(trials_wanted) || (~isscalar(trials_wanted))
  keepmaskdecim = logical(trials_wanted);
  keepmaskdecim = reshape( keepmaskdecim, size(keepmaskshort) );
else
  keepmaskdecim = true(size( keepmaskshort ));
  if trialcountepoched > trials_wanted
    keepmaskdecim = nlProc_decimateBresenham( trials_wanted, keepmaskdecim );
  end
end



% Build the final trial-pruning mask.

% Mask off old trials that weren't used to make epoched trials.
keepmask = false(size( keepmasklong ));
keepmask( oldmeta.trial_origfrommasked ) = true;

% Mask off old trials that were too long.
keepmask = keepmask & keepmasklong;

% Expand the short-trial and decimation masks to the original size.
keepmaskshortdecim = false(size( keepmasklong ));
keepmaskshortdecim( oldmeta.trial_origfrommasked ) = ...
  keepmaskshort & keepmaskdecim;
keepmask = keepmask & keepmaskshortdecim;

if wantmsgs
  disp(sprintf( '.. Keeping %d of %d trials.', ...
    sum(keepmask), length(keepmask) ));
end



% Apply the trial mask to metadata and to Field Trip data.

newmeta = oldmeta;

[ newtrialmeta new_origfrommasked new_maskedfromorig ] = ...
  epIter_helper_pruneTrialMetadata( oldmeta.oldtrialmeta, keepmask );

% Drop trial definitions and alignment code, since they're no longer valid.
newtrialmeta = rmfield( newtrialmeta, ...
  { 'trialdefs', 'trialdeftable', 'trial_align_evcode' } );

newmeta.newtrialmeta = newtrialmeta;
newmeta.trial_origfrommasked = new_origfrommasked;
newmeta.trial_maskedfromorig = new_maskedfromorig;

newephys = oldephys;

% Remember that the old Field Trip trials were already masked.
keepmask = keepmask( oldmeta.trial_origfrommasked );

newephys.ftdata.time = newephys.ftdata.time(keepmask);
newephys.ftdata.trial = newephys.ftdata.trial(keepmask);

if isfield(newephys.ftdata, 'sampleinfo')
  newephys.ftdata.sampleinfo = newephys.ftdata.sampleinfo(keepmask,:);
end

if isfield(newephys.ftdata, 'trialinfo')
  newephys.ftdata.trialinfo = newephys.ftdata.trialinfo(keepmask,:);
end



% Build the channel mask.

chancount = length(newephys.ftdata.label);

chanmask = true(size( newephys.ftdata.label ));

if iscell(chans_wanted)
% FIXME - Need to build a channel mask vector here!
% FIXME - Add mask syntax too.
elseif chancount > chans_wanted
  chanmask = nlProc_decimateBresenham( chans_wanted, chanmask );
end

if wantmsgs
  disp(sprintf( '.. Keeping %d of %d channels.', ...
    sum(chanmask), length(chanmask) ));
end



% Apply the channel mask.

newmeta.ftlabels_raw = newmeta.ftlabels_raw(chanmask);
newmeta.ftlabels_cooked = newmeta.ftlabels_cooked(chanmask);

newephys.ftlabels_cooked = newephys.ftlabels_cooked(chanmask);

newephys.ftdata.label = newephys.ftdata.label(chanmask);

trialcount = length(newephys.ftdata.time);
for tidx = 1:trialcount
  newephys.ftdata.trial{tidx} = newephys.ftdata.trial{tidx}(chanmask,:);
end



% Save the revised data.

if wantmsgs
  disp('.. Writing pruned epoched dataset to disk.');
end

% Using "-fromestruct" format, in case we're inside parfor.
% The data is already packaged for this.

save( outfile_meta, '-fromstruct', newmeta, '-v7.3' );
save( outfile_ephys, '-fromstruct', newephys, '-v7.3' );



%
% This is the end of the file.
