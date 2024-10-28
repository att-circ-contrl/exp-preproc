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
%   epoched trial needs to cover, or [] to not filter by time range.
% "long_trial_threshold" is a factor to multiply the median non-epoched
%   trial duration by. Any non-epoched trial longer than this is discarded.
%   Use a threshold of inf to keep all trials.
% "trials_wanted" is a scalar, a boolean vector, or a structure indexed by
%   session label. If it's a scalar, it's the maximum number of trials to
%   keep (trials are decimated). If it's a boolean vector with a number of
%   elements equal to the number of trials, it indicates which trials from
%   the epoched (not original) trial definition list to keep (trials for
%   false elements are discarded). If it's a structure indexed by session
%   label, the corresponding element is either a scalar or a boolean vector
%   interpreted per above.
% "chans_wanted" is a scalar, a cell array, a boolean vector, or a structure
%   indexed by session label. If it's a scalar, it's the maximum number of
%   channels to keep (channels are decimated). If it's a cell array, it
%   contains cooked labels of channels to keep. If it's a boolean vector with
%   a number of elements equal to the number of channels, it indicates which
%   channels to keep (channels for false elements are discarded). If it's a
%   structure indexed by session label, the corresponding element is a
%   scalar, a cell array, or a boolean vector interpreted per above.
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



%
% Turn the channel specifier into a mask.

chanlistraw = oldephys.ftdata.label;
chanlistcooked = oldephys.ftlabels_cooked;

chanmask = true(size( chanlistraw ));

if isstruct(chans_wanted)
  if isfield( chans_wanted, sessionlabel )
    chans_wanted = chans_wanted.(sessionlabel);
  else
    chans_wanted = chanmask;
    if wantmsgs
      disp([ '###  [epIter_afterFunc_epochPrune]  ' ...
        'No field for session "' sessionlabel '" in chans_wanted.' ]);
    end
  end
end

if iscell(chans_wanted)
  % Preserve geometry of "chanmask" in case the cooked list is transposed.
  % This shouldn't be necessary and also shouldn't happen, but do it anyways.
  chanmask(:) = contains( chanlistcooked, chans_wanted );
end

if islogical(chans_wanted) || (~isscalar(chans_wanted))
  if ~islogical(chans_wanted)
    % Convert numeric vector to boolean vector.
    chans_wanted = logical(chans_wanted);
  end

  if length(chans_wanted) == length(chanmask)
    % Preserve geometry.
    chanmask(:) = chans_wanted(:);
  else
    if wantmsgs
      disp(sprintf( [ '###  [epIter_afterFunc_epochPrune]  ' ...
        'Expected %d elements in chans_wanted, given %d elements.' ], ...
        length(chanmask), length(chans_wanted) ));
    end
  end
else
  % Scalar.
  if chans_wanted < length(chanmask)
    chanmask = nlProc_decimateBresenham( chans_wanted, chanmask );
  end
end



%
% Turn the trial specifier into a mask.
% Don't decimate yet; we don't know how many trials will pass other filters.

trialmask = true(size( oldephys.ftdata.trial ));
maxtrialcount = inf;

if isstruct(trials_wanted)
  if isfield( trials_wanted, sessionlabel )
    trials_wanted = trials_wanted.(sessionlabel);
  else
    trials_wanted = trialmask;
    if wantmsgs
      disp([ '###  [epIter_afterFunc_epochPrune]  ' ...
        'No field for session "' sessionlabel '" in trials_wanted.' ]);
    end
  end
end

if islogical(trials_wanted) || (~isscalar(trials_wanted))
  if ~islogical(trials_wanted)
    % Convert numeric vector to boolean vector.
    trials_wanted = logical(trials_wanted);
  end

  if length(trials_wanted) == length(trialmask)
    % Preserve geometry.
    trialmask(:) = trials_wanted(:);
  else
    if wantmsgs
      disp(sprintf( [ '###  [epIter_afterFunc_epochPrune]  ' ...
        'Expected %d elements in trials_wanted, given %d elements.' ], ...
        length(trialmask), length(trials_wanted) ));
    end
  end
else
  % Scalar.
  maxtrialcount = trials_wanted;
end



%
% Identify before-epoch trials that are too long.


trialdeftab = oldmeta.oldtrialmeta.trialdeftable;

durlist = trialdeftab.timeend - trialdeftab.timestart;

durmedian = median(durlist);
durlong = long_trial_threshold * durmedian;

% NOTE - This mask uses before-epoching trial indexing.
keepmasklong_orig = (durlist <= durlong);
trialcountorig = length(keepmasklong_orig);


% Convert this to epoched indexing and apply it to the mask.

keepmasklong = true(size( trialmask ));
keepmasklong(:) = keepmasklong_orig( oldmeta.trial_origfrommasked );
trialmask = trialmask & keepmasklong;



%
% Identify epoched trials that are too short.
% We have to do this by looking at timestamps, since we didn't save the
% trial definitioni structures for making epoched data.

% Initialize all-pass versions of the mask for reporting.
keepmaskshort = true(size( oldephys.ftdata.time ));
trialcountepoched = length(keepmaskshort);

if ~isempty(required_time_range)

  epsilon = 1e-3;
  mintime = min(required_time_range) + epsilon;
  maxtime = max(required_time_range) - epsilon;

  timeliststart = [];
  timelistend = [];

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

  % Apply this to the trial mask.
  trialmask(:) = trialmask(:) & keepmaskshort(:);

end



%
% Report wrong-size trials.

if wantmsgs
  disp(sprintf( '..  %d short trials (of %d), %d long trials (of %d).', ...
    trialcountepoched - sum(keepmaskshort), trialcountepoched, ...
    trialcountorig - sum(keepmasklong_orig), trialcountorig ));
end



%
% Decimate trials if requested.

if maxtrialcount < sum(trialmask)
  masklut = find(trialmask);
  maskmask = nlProc_decimateBresenham( maxtrialcount, masklut );
  trialmask(masklut) = maskmask;
end



%
% Apply the trial mask to metadata and to Field Trip data.


% Get a trial mask version that's expanded to the original size.
trialmask_orig = false(size( keepmasklong_orig ));
trialmask_orig( oldmeta.trial_origfrommasked ) = trialmask;

if wantmsgs
  disp(sprintf( '.. Keeping %d of %d epoched trials (%d of %d original).', ...
    sum(trialmask), length(trialmask), ...
    sum(trialmask_orig), length(trialmask_orig) ));
end


% Mask the metadata.

newmeta = oldmeta;

% Re-filter using the original non-epoched metadata.
[ newtrialmeta new_origfrommasked new_maskedfromorig ] = ...
  epIter_helper_pruneTrialMetadata( oldmeta.oldtrialmeta, trialmask_orig );

% Drop trial definitions and alignment code, since they're no longer valid.
newtrialmeta = rmfield( newtrialmeta, ...
  { 'trialdefs', 'trialdeftable', 'trial_align_evcode' } );

newmeta.newtrialmeta = newtrialmeta;
newmeta.trial_origfrommasked = new_origfrommasked;
newmeta.trial_maskedfromorig = new_maskedfromorig;


% Mask the ephys trials.
% Use the epoched version of the mask, since we're working on epoched data.

newephys = oldephys;

newephys.ftdata.time = newephys.ftdata.time(trialmask);
newephys.ftdata.trial = newephys.ftdata.trial(trialmask);

if isfield(newephys.ftdata, 'sampleinfo')
  newephys.ftdata.sampleinfo = newephys.ftdata.sampleinfo(trialmask,:);
end

if isfield(newephys.ftdata, 'trialinfo')
  newephys.ftdata.trialinfo = newephys.ftdata.trialinfo(trialmask,:);
end



%
% Apply the channel mask.

if wantmsgs
  disp(sprintf( '.. Keeping %d of %d channels.', ...
    sum(chanmask), length(chanmask) ));
end

newmeta.ftlabels_raw = newmeta.ftlabels_raw(chanmask);
newmeta.ftlabels_cooked = newmeta.ftlabels_cooked(chanmask);

newephys.ftlabels_cooked = newephys.ftlabels_cooked(chanmask);

newephys.ftdata.label = newephys.ftdata.label(chanmask);

trialcount = length(newephys.ftdata.time);
for tidx = 1:trialcount
  newephys.ftdata.trial{tidx} = newephys.ftdata.trial{tidx}(chanmask,:);
end



%
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
