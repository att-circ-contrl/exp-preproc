function epIter_badListPlotAll( ...
  outprefixpat, infilepat, badlists, ...
  sessionmeta, probemeta, trialdefmeta, plotconfig, wantmsgs )

% function epIter_badListPlotAll( ...
%   outprefixpat, infilepat, badlists, ...
%   sessionmeta, probemeta, trialdefmeta, plotconfig, wantmsgs )
%
% This function plots bad channel analysis data.
%
% This is intended to be called as a "probefuncafter" function, per
% ITERFUNCS.txt. A typical implementation would be:
%
% afterfunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, ...
%     beforedata, trialresults, wantmsgs ) ...
%     epIter_afterFunc_badListPlotAll( ...
%       [ plotfolder filesep '%s-%s-badchans' ], ...
%       [ srcfolder filesep '%s-%s-badinfo.mat' ], ...
%       bad_chan_list_struct, sessionmeta, probemeta, trialdefmeta, ...
%       bad_chan_plot_config, wantmsgs );
%
% "outprefixpat" is a sprintf pattern used to generate prefixes for output
%   filenames (such as plots, lists, and CSV data tables). This needs two
%   '%s' tokens, for the session label and probe label (in that order).
%   Generating names that include subfolders is fine.
% "infilepat" is a sprintf pattern used to generate the input file name
%   for reading per-probe bad channel analysis output. This needs two '%s'
%   tokens, for the session label and probe label (in that order).
% "badlists" is a structure containing the per-probe bad channel list
%   variables described in PREPROCFILES.txt. This is the same structure
%   returned by epIter_beforeFunc_badListMergeInfo().
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "plotconfig" is a structure describing the desired plots. Each field
%   corresponds to an algorithm and contains a structure with plot
%   configuration for that algorithm, per BADCHANPLOTS.txt:
%   "spect" contains configuration for spectral analysis plots.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% No return value.


% Extract metadata for convenience.

sessionlabel = sessionmeta.sessionlabel;
sessiontitle = sessionmeta.sessiontitle;

probelabel = probemeta.label;
probetitle = probemeta.title;

triallabels = trialdefmeta.triallabels;
trialnames = trialdefmeta.trialnames;

ftlabels_raw = badlists.ftlabels_raw;
ftlabels_cooked = badlists.ftlabels_cooked;



% Build filenames and prefixes.

outprefix = sprintf( outprefixpat, sessionlabel, probelabel );
infile = sprintf( infilepat, sessionlabel, probelabel );

% Checking the prefix rather than the full filenames is fine.
nlUtil_makeSureFolderExists(outprefix);


if ~exist(infile, 'file')
  if wantmsgs
    disp([ '###  Input file "' infile '" does not exist!' ]);
  end
else

  % Load the raw analysis output into a structure, so we can test fields.
  badinfo = load(infile);



  % Text lists of good and bad channels.

  % Global.

  scratch = nlUtil_sprintfCellArray( '%s\n', badlists.badraw );
  scratch = [ scratch{:} ];
  nlIO_writeTextFile( [ outprefix '-bad-all-raw.txt' ], scratch );

  scratch = nlUtil_sprintfCellArray( '%s\n', badlists.badcooked );
  scratch = [ scratch{:} ];
  nlIO_writeTextFile( [ outprefix '-bad-all-cooked.txt' ], scratch );

  scratch = nlUtil_sprintfCellArray( '%s\n', badlists.goodraw );
  scratch = [ scratch{:} ];
  nlIO_writeTextFile( [ outprefix '-good-all-raw.txt' ], scratch );

  scratch = nlUtil_sprintfCellArray( '%s\n', badlists.goodcooked );
  scratch = [ scratch{:} ];
  nlIO_writeTextFile( [ outprefix '-good-all-cooked.txt' ], scratch );

  % By method.

  methodlist = fieldnames(badlists.badrawbymethod);
  for midx = 1:length(methodlist)
    thismethod = methodlist{midx};
    scratch = badlists.badrawbymethod.(thismethod);
    scratch = nlUtil_sprintfCellArray( '%s\n', scratch );
    scratch = [ scratch{:} ];
    nlIO_writeTextFile([ outprefix '-bad-' thismethod '-raw.txt' ], scratch);
  end

  methodlist = fieldnames(badlists.goodrawbymethod);
  for midx = 1:length(methodlist)
    thismethod = methodlist{midx};
    scratch = badlists.goodrawbymethod.(thismethod);
    scratch = nlUtil_sprintfCellArray( '%s\n', scratch );
    scratch = [ scratch{:} ];
    nlIO_writeTextFile([ outprefix '-good-' thismethod '-raw.txt' ], scratch);
  end



  % Spectrum analysis plots.

  if isfield( badinfo.badchandata, 'spect' ) && isfield( plotconfig, 'spect' )
    thisconfig = plotconfig.spect;
    thisinfo = badinfo.badchandata.spect;

    if ~isempty(thisconfig.plots_wanted)
      if wantmsgs
        disp('.. Making spectrum analysis plots.');
      end

      % Copy the data, since we may collapse trials.
      bandpower = thisinfo.bandpower;
      tonepower = thisinfo.tonepower;

      % Figure out how many trials we actually have, since this may have
      % been cropped for testing.
      trialcount = size( bandpower, 3 );
      thistriallist = trialnames(1:trialcount);


      % Collapse into a single trial if requested.

      if thisconfig.plot_only_average
        bandpower = mean(bandpower,3);
        tonepower = mean(tonepower,3);
        thistriallist = {};
      end


      % Render the plots.
      % This handles normalization.

      annotated_chans = badlists.badcooked;

      euPlot_hlevPlotBandPower( bandpower, tonepower, 'twosided', ...
        thisinfo.freqedges, ftlabels_cooked, thistriallist, ...
        [], [], thisconfig.plots_wanted, ...
        [ sessiontitle ' - ' probetitle ], outprefix, annotated_chans );
    end
  end


  if wantmsgs
    disp('.. Finished making plots.');
  end

end


% Done.
end


%
% This is the end of the file.
