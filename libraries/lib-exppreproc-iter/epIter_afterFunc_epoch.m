function epIter_afterFunc_epoch( ...
  outfilepat_ephys, outfilepat_meta, ...
  sessionmeta, probemeta, trialdefmeta, trialresults, wantmsgs )

% function epIter_afterFunc_epoch( ...
%   outfilepat_ephys, outfilepat_meta, ...
%   sessionmeta, probemeta, trialdefmeta, trialresults, wantmsgs )
%
% This function aggregates per-trial ephys data into per-probe ephys data.
% This is intended to be used with cropped downsampled data. Otherwise this
% will take up a very large amount of memory.
%
% This is intended to be called as a "probefuncafter" function, per
% ITERFUNCS.txt. A typical implementation would be:
%
% afterfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, ...
%     beforedata, trialresults, wantmsgs ) ...
%     [ destfolder filesep '%s-%s-seg-ephys.mat' ], ...
%     [ destfolder filesep '%s-%s-seg-meta.mat' ], ...
%     sessionmeta, probemeta, trialdefmeta, trialresults, wantmsgs );
%
% "outfilepat_ephys" is a sprintf pattern used to generate the output file
%   name for saving per-probe merged Field Trip data. This needs two '%s'
%   tokens, for the session label and probe label (in that order). This
%   file contains single a variable called "ftdata".
% "outfilepat_meta" is a sprintf pattern used to generate the output file
%   name for saving metadata for the merged ephys data. This needs two '%s'
%   tokens, for the session label and probe label (in that order). This file
%   contains several metadata structures, per PREPROCFILES.txt.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "trialresults" is a cell array indexed by trial row number that contains
%   the ft_datatype_raw structures returned by epIter_trialFunc_epoch().
%   These will be struct([]) for trials that were dropped.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% No return value.


% Initialize.

outfile_ft = ...
  sprintf( outfilepat_ephys, sessionmeta.sessionlabel, probemeta.label );
outfile_meta = ...
  sprintf( outfilepat_meta, sessionmeta.sessionlabel, probemeta.label );

trialcount = length(trialresults);
trialmask = true([ trialcount 1 ]);

ftdata_aggregate = struct([]);



% Walk through the trials, building aggregated output.

is_first_trial = true;

for tidx = 1:trialcount
  ftdata_trial = trialresults{tidx};

  if isempty(ftdata_trial)
    trialmask(tidx) = false;
  else

    if wantmsgs
      disp(sprintf( '.. Merging trial %d/%d (%s).', ...
        tidx, trialcount, trialdefmeta.trialnames{tidx} ));
    end

    if is_first_trial
      ftdata_aggregate = ftdata_trial;
      is_first_trial = false;
    else
      ftdata_aggregate = ...
        ft_appenddata( struct( 'keepsampleinfo', 'no' ), ...
          ftdata_aggregate, ftdata_trial );
    end

    % FIXME - Remove provenance. Otherwise it gets nested absurdly deeply.
    % Matlab really hates that.
    ftdata_aggregate = rmfield(ftdata_aggregate, 'cfg');

  end
end

if isempty(ftdata_aggregate) && wantmsgs
  disp('###  Aggregate ephys data has no trials!');
end



% Build a filtered trial metadata struture.
% We're dropping trial definitions and alignment, since those are no longer
% valid.

newtrialmeta = struct();

newtrialmeta = struct( ...
  'codesbytrial', { trialdefmeta.codesbytrial(trialmask) }, ...
  'metabytrial', trialdefmeta.metabytrial(trialmask), ...
  'trialindices', trialdefmeta.trialindices(trialmask), ...
  'triallabels', { trialdefmeta.triallabels(trialmask) }, ...
  'trialnames', { trialdefmeta.trialnames(trialmask) }, ...
  'sessionlabel', trialdefmeta.sessionlabel, ...
  'sessiontitle', trialdefmeta.sessiontitle );

trial_origfrommasked = find(trialmask);
trial_maskedfromorig = nan(size(trialmask));
trial_maskedfromorig(trial_origfrommasked) = ...
  1:length(trial_origfrommasked);


% Save all of the metadata we have.
% Use "-fromstruct" format, in case we're inside parfor.

savedata = struct();

savedata.newtrialmeta = newtrialmeta;
savedata.oldtrialmeta = trialdefmeta;

savedata.trialmask = trialmask;
savedata.trial_maskedfromorig = trial_maskedfromorig;
savedata.trial_origfrommasked = trial_origfrommasked;

savedata.sessionmeta = sessionmeta;
savedata.probemeta = probemeta;

save( outfile_meta, '-fromstruct', savedata, '-v7.3' );


% Save the ephys data.

if wantmsgs
  disp('.. Writing ephys data to disk.');
end

savedata = struct();
savedata.ftdata = ftdata_aggregate;

save( outfile_ft, '-fromstruct', savedata, '-v7.3' );

if wantmsgs
  disp('.. Finished writing ephys data to disk.');
end



% Done.
end


%
% This is the end of the file.
