function badliststruct = epIter_beforeFunc_badListMergeInfo( ...
  outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
  configall, wantmsgs )

% function badliststruct = epIter_beforeFunc_badListMergeInfo( ...
%   outfilepat, infilepat, wantforce, sessionmeta, probemeta, ...
%   configall, wantmsgs )
%
% This function builds bad channel lists based on precomputed analyses of
% channel badness metrics.
%
% This is intended to be called as a "probefuncbefore" function, per
% ITERFUNCS.txt. A typical implementation would be:
%
% beforefunc = ...
%   @(sessionmeta, probemeta, trialdefmeta, wantmsgs) ...
%     epIter_beforeFunc_badListMergeInfo( ...
%       [ destfolder filesep '%s-%s-badlist.mat' ], ...
%       [ srcfolder filesep '%s-%s-badinfo.mat' ], ...
%       want_force_badlist, sessionmeta, probemeta, ...
%       bad_config_struct_all, wantmsgs );
%
% "outfilepat" is a sprintf pattern used to generate the output file name
%   for saving per-probe bad channel lists. This needs two '%s' tokens,
%   for the session label and probe label (in that order).
% "infilepat" is a sprintf pattern used to generate the input file name
%   for reading per-probe bad channel analysis output. This needs two '%s'
%   tokens, for the session label and probe label (in that order).
% "wantforce" is true to redo processing even if the output file already
%   exists, and false to skip processing if the output file is present.
% "sessionmeta" is a single session metadata structure, per SESSIONMETA.txt.
% "probemeta" is a probe definition structure, per PROBEDEFS.txt.
% "configall" is a configuration structure for bad channel analysis. Each
%   field corresponds to an algorithm and contains a configuration structure,
%   per BADCHANCONFIG.txt:
%   "log" contains configuration for hand-annotated log entries.
%   "spect" contains configuration information for spectral analysis.
% "wantmsgs" is true to emit console messages and false otherwise.
%
% "badliststruct" is a structure with the following fields (corresponding
%   to variables written to the output file, per PREPROCFILES.txt):
%   "goodraw" (raw FT labels of channels highlighted as "good")
%   "badraw" (raw FT labels of channels highlighted as "bad")
%   "goodcooked" (cooked versions of "goodraw" labels)
%   "badcooked" (cooked versions of "badraw" labels)
%   "ftlabels_raw" (raw FT labels in data order, for channel mapping)
%   "ftlabels_cooked" (cooked FT labels in data order, for channel mapping)
%   "goodrawbymethod" (structure with per-algorithm lists of good channels)
%   "badrawbymethod" (structure with per-algorithm lists of bad channels)


% This should never be used, but set it anyways.
badliststruct = struct([]);


% Input and output files only have two labels, not three.

outfile = sprintf( outfilepat, sessionmeta.sessionlabel, probemeta.label );
infile = sprintf( infilepat, sessionmeta.sessionlabel, probemeta.label );



if (~wantforce) && exist(outfile, 'file')
  if wantmsgs
    disp('.. Bad channel list is already present; not writing.');
  end

  % Read the output file, so that we have valid return data.
  badliststruct = load(outfile);
elseif ~exist(infile, 'file')
  if wantmsgs
    disp([ '###  Input file "' infile '" does not exist!' ]);
  end
else

  % Load the raw analysis output into a structure, so we can test fields.
  badinfo = load(infile);

  % Copy selected metadata for convenience.
  ftlabels_raw = badinfo.ftlabels_raw;
  ftlabels_cooked = badinfo.ftlabels_cooked;
  methodlist = fieldnames(badinfo.badchandata);


  % Aggregate bad-channel info.

  goodrawbymethod = struct();
  badrawbymethod = struct();


  % Copy the hand-annotated channels.

  if ismember('log', methodlist)
    goodrawbymethod.log = badinfo.badchandata.log.good;
    badrawbymethod.log = badinfo.badchandata.log.bad;
  end


  % Copy the forced-override channels.

  if ismember('force', methodlist)
    badrawbymethod.force = badinfo.badchandata.force.bad;
  end


  % Evaluate spectrum analysis results.

  if ismember('spect', methodlist)
    % This averages across trials for us, so no need to do it ourselves.
    badmask = euHLev_guessBadChansFromBandPower( ...
      badinfo.badchandata.spect.bandpower, ...
      badinfo.badchandata.spect.tonepower, ...
      configall.spect.bandrange, configall.spect.tonerange );

    % We're only flagging bad channels this way, not good ones.
    badrawbymethod.spect = ftlabels_raw(badmask);
  end


  % FIXME - Time-domain PCA/ICA and XC analysis interpretation goes here.



  % Post-processing: Sanity-check, sort,  and merge the lists.

  goodraw = {};
  badraw = {};

  methodlist = fieldnames(goodrawbymethod);
  for midx = 1:length(methodlist)
    thismethod = methodlist{midx};
    thislist = goodrawbymethod.(thismethod);
    % We should already only have probe-specific labels, but make sure anyways.
    thislist = sort( intersect( ftlabels_raw, thislist ) );
    goodrawbymethod.(thismethod) = thislist;
    goodraw = [ goodraw ; reshape( thislist, [], 1 ) ];
  end

  methodlist = fieldnames(badrawbymethod);
  for midx = 1:length(methodlist)
    thismethod = methodlist{midx};
    thislist = badrawbymethod.(thismethod);
    % We should already only have probe-specific labels, but make sure anyways.
    thislist = sort( intersect( ftlabels_raw, thislist ) );
    badrawbymethod.(thismethod) = thislist;
    badraw = [ badraw ; reshape( thislist, [], 1 ) ];
  end

  % NOTE - Special-case the "force override" method.
  if isfield( badrawbymethod, 'force' )
    badraw = badrawbymethod.force;
  end

  goodraw = unique(goodraw);
  badraw = unique(badraw);

  % Force these to be columns.
  goodraw = reshape( goodraw, [], 1 );
  badraw = reshape( badraw, [], 1 );



  % Build and save the output structure.

  badliststruct = struct();

  badliststruct.goodraw = goodraw;
  badliststruct.badraw = badraw;

  badliststruct.goodcooked = ...
    sort( nlFT_mapChannelLabels( goodraw, ftlabels_raw, ftlabels_cooked ) );
  badliststruct.badcooked = ...
    sort( nlFT_mapChannelLabels( badraw, ftlabels_raw, ftlabels_cooked ) );

  badliststruct.ftlabels_raw = ftlabels_raw;
  badliststruct.ftlabels_cooked = ftlabels_cooked;

  badliststruct.goodrawbymethod = goodrawbymethod;
  badliststruct.badrawbymethod = badrawbymethod;

  % Use the "-fromstruct" format in case we were called from inside parfor.
  % This conveniently lets us use our existing output structure.
  save( outfile, '-fromstruct', badliststruct, '-v7.3' );

end


% Done.
end


%
% This is the end of the file.
