function epIter_afterFunc_badInfoAll( ...
  outfilepat, wantforce, sessionmeta, probemeta, trialdefmeta, ...
  trialresults, configall, wantmsgs )

% function epIter_afterFunc_badInfoAll( ...
%   outfilepat, wantforce, sessionmeta, probemeta, trialdefmeta, ...
%   trialresults, configall, wantmsgs )
%
% This function aggregates per-trial bad channel information and writes it
% to a file.
%
% This is intended to be called as a "probefuncafter" function, per
% ITERFUNCS.txt. A typical implementation would be:
%
% afterfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, ...
%     beforedata, trialresults, wantmsgs ) ...
%     epIter_afterFunc_badInfoAll( ...
%       [ destfolder filesep '%s-%s-badinfo.mat' ], ...
%       want_force_badinfo, sessionmeta, probemeta, trialdefmeta, ...
%       trialresults, bad_config_struct_all, wantmsgs );
%
% "outfilepat" is a sprintf pattern used to generate the output file name
%   for saving per-probe bad channel information. This needs two '%s' tokens,
%   for the session label and probe label (in that order).
% "wantforce" is true to redo processing even if the output file already
%   exists, and false to skip processing if the output file is present.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "trialresults" is a cell array indexed by trial row number that contains
%   the data variables returned by epIter_trialFunc_badInfoAll().
% "configall" is a configuration structure for bad channel analysis. Each
%   field corresponds to an algorithm and contains a configuration structure,
%   per BADCHANCONFIG.txt:
%   "log" contains configuration information for hand-annotated log entries.
%   "spect" contains configuration information for spectral analysis.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% No return value.


% Output file only has two labels, not three.
outfile = sprintf( outfilepat, sessionmeta.sessionlabel, probemeta.label );


if (~wantforce) && exist(outfile, 'file')
  if wantmsgs
    disp('.. Bad channel analysis data is already present; not writing.');
  end
else

  badchansmeta = struct([]);
  badchanslog = struct([]);
  badchansspect = struct([]);

  trialcount = length(trialresults);

  have_log = isfield( configall, 'log' );
  have_spect = isfield( configall, 'spect' );


  for tidx = 1:trialcount

    thistrialresult = trialresults{tidx};


    % Save metadata that was extracted from trials.
    % Only copy the first instance; every instance is the same.

    if isempty(badchansmeta)
      badchansmeta = struct();
      badchansmeta.ftlabels_raw = thistrialresult.ftlabels_raw;
      badchansmeta.ftlabels_cooked = thistrialresult.ftlabels_cooked;
    end


    % Only copy the first instance of the log-based bad channel metadata;
    % every instance is the same.

    if have_log && isempty(badchanslog)
      % This includes "good" and "bad", containing channel lists.
      badchanslog = thistrialresult.log;
    end


    % Aggregate spectrum information if present.

    if have_spect
      if isempty(badchansspect)
        % This includes "freqedges", "bandpower", and "tonepower".
        badchansspect = thistrialresult.spect;
      else
        % Append to "bandpower" and "tonepower".
        badchansspect.bandpower(:,:,tidx) = thistrialresult.spect.bandpower;
        badchansspect.tonepower(:,:,tidx) = thistrialresult.spect.tonepower;
      end
    end


    % FIXME - Time-domain PCA/ICA and XC analysis results go here.

  end


  % Save the aggregated data, if we have any.

  if isempty(badchansmeta)
    if wantmsgs
      disp('###  No per-trial bad channel information found!');
    end
  else

    % Use the "-fromstruct" format in case we were called from inside parfor.
    % It also lets us easily leave out analyses that weren't performed.

    savedata = struct();

    % Metadata.

    savedata.ftlabels_raw = badchansmeta.ftlabels_raw;
    savedata.ftlabels_cooked = badchansmeta.ftlabels_cooked;
    savedata.triallabels = trialdefmeta.triallabels;
    savedata.trialnames = trialdefmeta.trialnames;
    savedata.badchandata = struct();

    % Individual algorithms' results.

    if ~isempty(badchanslog)
      savedata.badchandata.log = badchanslog;
    end

    if ~isempty(badchansspect)
      savedata.badchandata.spect = badchansspect;
    end

    save( outfile, '-fromstruct', savedata, '-v7.3' );

  end

end


% Done.
end


%
% This is the end of the file.
