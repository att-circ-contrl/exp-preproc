function trialresult = epIter_trialFunc_sigclean( ...
  outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
  trialdefmeta, tidx, passes, artfunc, notchfreqs, notchbw, wantmsgs )

% function trialresult = epIter_trialFunc_sigclean( ...
%   outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
%   trialdefmeta, tidx, passes, artfunc, notchfreqs, notchbw, wantmsgs )
%
% This function reads per-trial raw ephys data and performs notch filtering
% and artifact removal. Clean trials are saved to disk in Field Trip format
% (per PREPROCFILES.txt).
%
% This accepts an arbitrary artifact rejection function. This function may
% remove curve-fit artifacts and/or may replace artifact regions with NaN.
%
% This is intended to be called as a "trialfunc" function, per ITERFUNCS.txt.
% A typical implementation would be:
%
% trialfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, tidx, beforedata, wantmsgs) ...
%     epIter_trialFunc_sigclean( ...
%       [ destfolder filesep '%s-%s-%s-ephysclean.mat' ], ...
%       [ srcfolder filesep '%s-%s-%s-ephysraw.mat' ], want_force_clean, ...
%       sessionmeta, probemeta, trialdefmeta, tidx, ...
%       clean_passes, artifact_func, notch_freqs, notch_bw, wantmsgs );
%
% "outfilepat" is a sprintf pattern used to generate the output file name
%   for saving Field Trip data. This needs three '%s' tokens, for the
%   session label, probe label, and trial label (in that order). The output
%   file will contain "ftdata_clean" and "ftlabels_cooked", per
%   PREPROCFILES.txt.
% "infilepat" is a sprintf pattern used to generate the input file name
%   for reading raw trials in Field Trip format. This needs three '%s'
%   tokens, as with "outfilepat". The input file should contain "ftdata_raw"
%   and "ftlabels_cooked", per PREPROCFILES.txt.
% "wantforce" is true to redo processing even if the output file already
%   exists, and false to skip processing if the output file is present.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "tidx" is the row index of the present trial within trial metadata tables.
% "passes" is the number of processing passes to make (typically 2). More
%   passes reduces the amount of tone filter ringing around artifacts.
% "artfunc" is a function handle to call for artifact removal. This has the
%   form:   newtrial = artfunc( fttime, fttrial )
%   ...where "fttime" is a 1xNsamples vector and "fttrial" and "newtrial" are
%   Nchans*Nxamples matrices. If "artfunc" is NaN, no function call is made.
% "notchfreqs" is a vector with notch filter frequencies, or [] to disable.
% "notchbw" is the notch filter bandwidth in Hz, or NaN to disable filtering.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "trialresult" is always NaN (unused).


% Set the return value.
trialresult = NaN;


%
% Unpack various pieces of metadata we'll need.

outfile = sprintf( outfilepat, sessionmeta.sessionlabel, ...
  probemeta.label, trialdefmeta.triallabels{tidx} );

infile = sprintf( infilepat, sessionmeta.sessionlabel, ...
  probemeta.label, trialdefmeta.triallabels{tidx} );

have_artfunc = isa(artfunc, 'function_handle');

% There's no point in doing multiple passes without artifact rejection.
if ~have_artfunc
  passes = min(passes, 1);
end




if (~wantforce) && exist(outfile, 'file')
  if wantmsgs
    disp('.. Conditioned ephys data is already present; skipping trial.');
  end
elseif ~exist(infile, 'file')
  if wantmsgs
    disp([ '###  Input file "' infile '" does not exist!' ]);
  end
else

  if wantmsgs
    disp('.. Performing artifact rejection and signal conditioning.');
    trialtime = tic;
  end


  % Load the raw data.
  % This gives us ftdata_raw and ftlabels_cooked.

  load(infile);


  % Artifact and tone removal.

  % Removing artifacts when we have narrow-band noise causes poor fits.
  % Removing narrow-band noise when we have artifacts causes ringing.

  % We're proceeding in several stages, trying to measure the artifact
  % signal and the narrow-band tone signal so that each can be subtracted
  % from the raw signal and the estimate of the other component refined.


  % NOTE - Handle multiple trials, in case of nonstandard input.
  trialcount = length(ftdata_raw.time);

  ftdata_clean = ftdata_raw;

  for tidx = 1:trialcount
    thistime = ftdata_raw.time{tidx};
    thisdata = ftdata_raw.trial{tidx};

    samprate = round( 1 / median(diff(thistime)) );

    % Initialize artifact and tone signal estimates.
    artsignal = zeros(size(thisdata));
    tonesignal = zeros(size(thisdata));
    nanmask = false(size(thisdata));

    for pidx = 1:passes

      % Get an estimate of the artifact signal (subtracting the tones).
      % Also make note of any NaN-squashing the artifact function did.

      if have_artfunc
        scratch = thisdata - tonesignal;
        residue = artfunc(thistime, scratch);

        nanmask = isnan(residue);
        residue = nlProc_fillNaNRows(residue);

        artsignal = scratch - residue;
      end


      % Get an estimate of the tone signal (subtracting the artifacts).

      if (~isempty(notchfreqs)) && (~isnan(notchbw))
        scratch = thisdata - artsignal;
        residue = euFT_doBrickNotchRemovalTrial( ...
          scratch, samprate, notchfreqs, notchbw );

        tonesignal = scratch - residue;
      end
    end

    % Subtract the tone and artifact signals and re-apply NaN squashing.

    thisdata = thisdata - (artsignal + tonesignal);
    thisdata(nanmask) = NaN;

    % Finished with this trial.
    ftdata_clean.trial{tidx} = thisdata;


    % Diagnostic information.
    if wantmsgs
      scratch = ftdata_raw.trial{tidx};
      origpower = sum( scratch .* scratch, 'all' );
      residuepower = sum( thisdata .* thisdata, 'all' );
      artpower = sum( artsignal .* artsignal, 'all' );
      tonepower = sum( tonesignal .* tonesignal, 'all' );

      disp(sprintf( ...
        '.. Signal / Artifact / Tone power:  %.1f %%   %.1f %%   %.1f %%', ...
        100 * residuepower / origpower, 100 * artpower / origpower, ...
        100 * tonepower / origpower ));
    end
  end


  % Save the modified FT data.

  % We have to use "-fromstruct" format inside parfor.
  savedata = struct();
  savedata.ftdata_clean = ftdata_clean;
  savedata.ftlabels_cooked = ftlabels_cooked;
  save( outfile, '-fromstruct', savedata, '-v7.3' );


  if wantmsgs
    durstring = nlUtil_makePrettyTime( toc(trialtime) );
    disp([ '.. Finished cleaning signals (' durstring ').' ]);
  end


% Done.
end


%
% This is the end of the file.
