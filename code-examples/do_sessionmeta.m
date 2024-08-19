% Preprocessing pipeline demo scripts - Session extraction.
% Written by Christopher Thomas.


%
% Setup and configuration.

do_setup_stuff;



%
% Get dataset metadata.


% Get a list of all sessions present.

sessionlist = ...
  euMeta_getLouieFoldersAndLogs( fltoken_rawdirs, fltoken_louielogs );



% Prune this based on the manual list of good sessions.

if isempty(fltoken_desiredmeta)
  disp('###  No desired metadata specified. Reverse-engineering.');
  fltoken_desiredmeta = euMeta_getDesiredSessions_guessLouie( sessionlist );
end

if isempty(fltoken_desiredmeta)
  disp('###  Couldn''t figure out probe groups. Bailing out.');
  sessionlist = struct([]);
  exit;
end

scratch = length(sessionlist);
sessionlist = euMeta_pruneLouieSessionList( sessionlist, fltoken_desiredmeta );

% Debug tattle.
disp(sprintf( '--  %d sessions before pruning, %d sessions after:', ...
  scratch, length(sessionlist) ));
disp(transpose( { sessionlist.sessionid } ));



% If we want only a few specific sessions, filter the list.
% If we only want one session, crop the list.

if ~isempty(debug_specific_sessions)

  sessionmask = ...
    ismember( { sessionlist.sessionlabel }, debug_specific_sessions );
  sessionlist = sessionlist(sessionmask);

  disp(sprintf( 'xx  Selected %d of %d sessions by name:', ...
    sum(sessionmask), length(sessionmask) ));
  disp(transpose( { sessionlist.sessionid } ));

end



% Sanity check.

if isempty(sessionlist)
  disp('###  No sessions in list! Bailing out.');
  exit;
end



% Get an aggregated list of probes.
% FIXME - We don't actually use this for anything. It's mostly for the
% user's benefit.

[ probelabels probetitles ] = ...
  euMeta_getAllProbeNames( { sessionlist.probedefs } );

disp('-- Probes detected:');
scratch = [ transpose(probelabels), transpose(probetitles) ];
disp(scratch);



% Other global metadata.

% This specifies which SynchBox signals correspond to which TTL inputs.
ttldefs = euMeta_getTTLSignals_FLToken_2022_2023;



% Write global metadata to disk.

disp('-- Writing dataset metadata to disk.');
save( [ sessiondir filesep 'dataset-meta.mat' ], ...
  'sessionlist', 'ttldefs', 'probelabels', 'probetitles', '-v7.3' );



%
% Walk through the sessions, getting session metadata and trialdefs.

sessioncount = length(sessionlist);

for sidx = 1:sessioncount

  sessionmeta = sessionlist(sidx);

  sessiontitle = sessionmeta.sessiontitle;
  sessionlabel = sessionmeta.sessionlabel;

  sessionfileprefix = [ sessiondir filesep sessionlabel ];

  foldersession = sessionmeta.folder_session;

  foldergame = '';
  if ~isempty(sessionmeta.folders_game)
    foldergame = sessionmeta.folders_game{1};
  end

  folderopenephys = '';
  if ~isempty(sessionmeta.folders_openephys)
    folderopenephys = sessionmeta.folders_openephys{1};
  end

  folderintanrec = '';
  if ~isempty(sessionmeta.folders_intanrec)
    folderintanrec = sessionmeta.folders_intanrec{1};
  end

  folderintanstim = '';
  if ~isempty(sessionmeta.folders_intanstim)
    folderintanstim = sessionmeta.folders_intanstim{1};
  end


  % Banner.

  disp(sprintf( '== Processing "%s" (%d/%d) (%s).', ...
    sessiontitle, sidx, sessioncount, sessionmeta.monkey ));



  %
  % Read event data, frame data, and eye-tracker data only once per session.


  % TTL events.

  outfile = [ sessionfileprefix '-events-raw.mat' ];

  tic;

  disp('-- Reading raw TTL events.');

  [ boxevents gameevents evcodedefs gamereftime ...
    deveventsraw deveventscooked devnames ] = ...
    euHLev_readAllTTLEvents( ttldefs, ...
      foldergame, folderopenephys, folderintanrec, folderintanstim );

  disp('.. Writing raw TTL events to disk.');
  save( outfile, 'boxevents', 'gameevents', 'evcodedefs', ...
    'gamereftime', 'deveventsraw', 'deveventscooked', 'devnames', ...
    '-v7.3' );

  durstring = nlUtil_makePrettyTime(toc);
  disp([ '-- Finished reading TTL events (' durstring ').' ]);

  reportmsg = euHLev_reportTTLEvents( boxevents, gameevents, evcodedefs, ...
    deveventsraw, deveventscooked, devnames );

  nlIO_writeTextFile( [ plotdir filesep sessionlabel '-eventreport.txt' ], ...
    reportmsg );


  % Frame data.

  outfile = [ sessionfileprefix '-framedata-raw.mat' ];

  tic;

  disp('-- Reading frame data.');

  gameframedata = euUSE_readRawFrameData( foldergame, gamereftime );

  disp('.. Writing frame data to disk.');
  save( outfile, 'gameframedata', '-v7.3' );

  durstring = nlUtil_makePrettyTime(toc);
  disp([ '-- Finished reading frame data (' durstring ').' ]);


  % Gaze data.

  outfile = [ sessionfileprefix '-gazedata-raw.mat' ];

  tic;

  disp('-- Reading gaze data.');

  gamegazedata = euUSE_readRawGazeData(foldergame);

  disp('.. Writing gaze data to disk.');
  save( outfile, 'gamegazedata', '-v7.3' );

  durstring = nlUtil_makePrettyTime(toc);
  disp([ '-- Finished reading gaze data (' durstring ').' ]);



  %
  % Do time alignment.

  outfile = [ sessionfileprefix '-align.mat' ];

  tic;

  disp('-- Performing time alignment.');

  timetables = euHLev_alignAllDevices( ...
    boxevents, gameevents, deveventscooked, gameframedata );

  disp('.. Writing time alignment tables to disk.');
  save( outfile, 'timetables', '-v7.3' );

  [ boxevents gameevents deveventscooked gameframedata gamegazedata ] = ...
    euHLev_propagateAlignedTimestamps( timetables, boxevents, gameevents, ...
      deveventscooked, gameframedata, gamegazedata );

  durstring = nlUtil_makePrettyTime(toc);
  disp([ '-- Finished performing time alignment (' durstring ').' ]);



  %
  % Clean up event lists.

  % If any ephys machines are missing event tables, this copies them.
  % Device event code tables also get augmented with TTL reward/synch events.

  % NOTE - This needs the folders so that it can read FT headers to get
  % sampling rates. Folders given as '' are skipped.

  % FIXME - There's a note that I might want to augment game codes too.
  % Skipping this, since the game emits event codes saying that it asserted
  % the reward and stim lines.

  disp('-- Propagating events.');

  scratch = deveventscooked;

  % We don't want to propagate these; USE's reward indicators are enough.
  want_add_ttl_to_evcodes = false;

  deveventscooked = euHLev_augmentEphysEvents( ...
    deveventscooked, boxevents, want_add_ttl_to_evcodes, ...
    folderopenephys, folderintanrec, folderintanstim );

  disp('-- Finished propagating events.');



  %
  % Get the channel map.

  disp('.. Reading channel map.');

  % FIXME - We know we're using Open Ephys, and we know the channel map is
  % saved in a subfolder of the session folder.

  [ chanlabels_raw chanlabels_cooked ] = euMeta_getLabelChannelMap_OEv5( ...
    foldersession, folderopenephys, fltoken_mapmethod );


  % Save this.
  disp('.. Writing channel map to disk.');
  save( [ sessiondir filesep sessionlabel '-chanmap.mat' ], ...
    'chanlabels_raw', 'chanlabels_cooked', '-v7.3' );



  %
  % Get the trial definitions.

  disp('.. Getting full-trial trial definitions.');

  % FIXME - Just getting these for the recorder for now (no stimulator).

  % FIXME - Assume Open Ephys.
  [ codesbytrial trialdefs trialdeftable ] = euHLev_getTrialDefsWide( ...
    folderopenephys, deveventscooked.openephys.cookedcodes, ...
    'recTime', trial_pad_secs, trial_align_evcode, trial_prune_method );

  % Diagnostics.
  disp(sprintf( '.. Found %d trials (and %d event code lists).', ...
    height(trialdeftable), length(codesbytrial) ));


  % If we want to only process a subset of trials, crop the lists here.

  oldtrialcount = length(codesbytrial);

  if debug_few_trials
    trialcount = round( oldtrialcount / 40 );
    trialcount = max(trialcount, 1);

    % Only prune the list if we reduced the number of trials.
    % Since "trialcount" is at least 1, this handles the "no trials" case.

    if trialcount < oldtrialcount
      codesbytrial = codesbytrial(1:trialcount);
      trialdefs = trialdefs(1:trialcount,:);
      trialdeftable = trialdeftable(1:trialcount,:);

      disp(sprintf( 'xx  Keeping %d of %d trials.', ...
        trialcount, oldtrialcount ));
    end
  end


  % Follow Charlie's convention, and make trial labels based on the USE
  % "trial index", which is insensitive to how we do good/bad trial weeding.

  trialindices = trialdeftable.trialindex;
  triallabels = nlUtil_sprintfCellArray( 'tridx%04d', trialindices );
  trialnames = nlUtil_sprintfCellArray( 'TrIdx %04d', trialindices );


  % Build additional per-trial metadata.

  metabytrial = euMeta_getTrialMetadataFromCodes( ...
    codesbytrial, fltoken_conditionlut, 'recTime' );

  if isempty(gameframedata)
    disp('###  Warning: No frame data to augment trial metadata with!');
  end
  metabytrial = ...
    euMeta_addFrameDataToTrialMetadata( metabytrial, gameframedata );


  % Save trial definitions and other trial metadata.
  % NOTE - The event code list is pretty big.

  disp('-- Writing trial definitions and trial metadata to disk.');
  save( [ sessiondir filesep sessionlabel '-trialmeta.mat' ], ...
    'codesbytrial', 'metabytrial', ...
    'trialdefs', 'trialdeftable', 'trial_align_evcode', ...
    'trialindices', 'triallabels', 'trialnames', ...
    'sessionlabel', 'sessiontitle', '-v7.3' );

end  % Session iteration.


disp('== Finished processing raw session data.');



%
% This is the end of the file.
