function trialresult = epIter_trialFunc_epoch( ...
  infilepat, sigtype, sessionmeta, probemeta, trialdefmeta, tidx, ...
  badchanmeta, newtrigtime, newtimespan, wantmsgs )

% function trialresult = epIter_trialFunc_epoch( ...
%   infilepat, sigtype, sessionmeta, probemeta, trialdefmeta, tidx, ...
%   badchanmeta, newtrigtime, newtimespan, wantmsgs )
%
% This function reads per-trial ephys data and re-aligns and crops it.
% Aligned cropped ephys data is returned as the trial result (this can get
% big if aggregating full-sample-rate data).
%
% This is intended to be called as a "trialfunc" function, per ITERFUNCS.txt.
% A typical implementation would be:
%
% trialfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
%     epIter_trialFunc_epoch( ...
%       [ srcfolder filesep '%s-%s-%s-ephys%s.mat' ], 'mua', ...
%       sessionmeta, probemeta, trialdefmeta, tidx, ...
%       beforedata, new_trig_times(tidx), new_time_span, wantmsgs );
%
% "infilepat" is a sprintf pattern used to generate the input file name
%   for reading individual trial ephys data in Field Trip format. This needs
%   four '%s' tokens, for the session label, probe label, trial label, and
%   signal type (in that order). The input file should contain "ftdata_XXX"
%   and "ftlabels_cooked", per PREPROCFILES.txt. "XXX" is the signal type.
% "sigtype" is the signal type used when reading ephys data. This is
%   typically 'mua', but may be any other type listed in PREPROCFILES.txt.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "tidx" is the row index of the present trial within trial metadata tables.
% "badchanmeta" is a structure containing all of the variables in the bad
%   channel list metadata file, per PREPROCFILES.txt.
% "newtrigtime" is the revised trigger time, using the same time baseline
%   as the trigger times listed in "trialdefmeta.trialdeftable". If no
%   suitable trigger was present, this is NaN.
% "newtimespan" [ start stop ] is the desired timestamp range in seconds for
%   the cropped trials.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "trialresult" is a structure with the following fields, or struct([]) if
%   trial data was discarded:
%   "ftdata" is a ft_datatype_raw structure with the realigned cropped trial.
%   "ftlabels_cooked" has cooked channel labels corresponding to ftdata.label.


% Set the return value.
% This defaults to "trial was discarded".

trialresult = struct([]);


% Unpack various pieces of metadata we'll need.

infile = sprintf( infilepat, sessionmeta.sessionlabel, ...
  probemeta.label, trialdefmeta.triallabels{tidx}, sigtype );

ftvarname = [ 'ftdata_' sigtype ];

badchanlist = badchanmeta.badraw;



% Process this trial.

if ~exist(infile, 'file')
  if wantmsgs
    disp([ '###  Input file "' infile '" does not exist!' ]);
  end
else
  % Read this into a structure and unpack it, since we don't know the
  % variable name a priori.

  ftfiledata = load(infile);

  if ~isfield( ftfiledata, ftvarname )
    disp([ '###  Input file does not contain variable "' ftvarname '"!' ]);
  else

    ftdata_trial = ftfiledata.(ftvarname);
    ftlabels_raw = ftdata_trial.label;
    ftlabels_cooked = ftfiledata.ftlabels_cooked;

    oldtrigtime = trialdefmeta.trialdeftable.timetrigger(tidx);

    % Test a couple of error cases.
    if isnan(oldtrigtime) || isnan(newtrigtime)
      % One of these was NaN. Skip this trial silently.
    elseif isempty(ftdata_trial.time)
      if wantmsgs
        disp([ '###  No trials in "' infile '"!' ]);
      end
    else

      if wantmsgs
        disp(sprintf( '.. Segmenting trial %d/%d (%s).', ...
          tidx, length(trialdefmeta.triallabels), ...
          trialdefmeta.trialnames{tidx} ));
      end


      % Drop bad channels.

      chanlist = setdiff( ftdata_trial.label, badchanlist );

      ftdata_trial = ft_preprocessing( ...
        struct( 'channel', {chanlist}, 'feedback', 'no' ), ftdata_trial );


      % Align the data.

      samptau = median(diff( ftdata_trial.time{1} ));
      deltatime = newtrigtime - oldtrigtime;
      deltasamps = round(deltatime / samptau);

      % We only have one trial, so give a scalar offset rather than a vector.
      % Offset is "samples relevant to current t=0".
      % But if the new trigger is later than the old one, offset is negative.
      ftdata_trial = ft_redefinetrial( ...
        struct( 'offset', - deltasamps ), ftdata_trial );


      % Crop to the desired time range.

      ftdata_trial = ft_redefinetrial( ...
        struct( 'toilim', newtimespan ), ftdata_trial );


      % If we're still okay, store the result.

      if isempty(ftdata_trial.time)
        if wantmsgs
          disp( '###  Segmented trial data has no trial!' );
        end
      else
        trialresult = struct();
        trialresult.ftdata = ftdata_trial;

        % We may be using only a subset of the channels, so don't just
        % copy the old ftlabels_cooked.
        trialresult.ftlabels_cooked = nlFT_mapChannelLabels( ...
          ftdata_trial.label, ftlabels_raw, ftlabels_cooked );
      end

    end

  end
end



% Done.
end


%
% This is the end of the file.
