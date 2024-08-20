% Preprocessing pipeline demo scripts - Configuration.


%
% Behavior Switches


% Whether to skip or force-renegerate output files that are already present.
want_force_redo = true;

% Whether to auto-detect bad channels (the alternative is to use a list).
want_detect_badchans = true;

% Whether to emit messages to the console.
want_messages = true;

% Which derived ephys signals to generate.
derived_wanted = { 'wb', 'hp', 'lfp', 'mua' };

% Which signals to generate epoched data for.
epoch_sigs_wanted = { 'mua', 'lfp' };

% Whether to use the Parallel Computing Toolbox.
want_parallel = false;


% Which plots to make for bad channel detection.

badplotconfigall = struct();
badplotconfigall.spect = struct();
badplotconfigall.spect.plot_only_average = true;
% Also available: 'powerbychan', 'tonebychan'.
% Set this to {} to suppress plots.
badplotconfigall.spect.plots_wanted = ...
  { 'powerheatmap', 'toneheatmap', 'powerheatband', 'toneheatband', ...
    'powerheatdual', 'toneheatdual' };


% The specific session to use (we'll discard the other sessions for the
% demo).
%debug_specific_sessions = {};
debug_specific_sessions = { 'FrProbe0322071300201' };

% Reduced trial count, to keep demo time and output size reasonable.
debug_few_trials = true;



%
% Folders


% Output folders.

plotdir = 'plots';
sessiondir = 'data-sessions';
trialdir = 'data-trials';
epochdir = 'data-epoched';


% Sample input. This is from the Frey/Wotan FLToken dataset.

% These are lists; multiple paths and file expressions can be given.
fltoken_rawdirs = { [ 'datasets' filesep '2022-frey-token-03' ] };
fltoken_louielogs = { [ 'datasets' filesep '*token*' filesep '*m' ] };

fltoken_desiredmeta = euMeta_getDesiredSessions_FLToken_2022_2023;
fltoken_conditionlut = euMeta_getBlockConditions_FLToken_2022_2023;

fltoken_mapmethod = 'fromsequence';



%
% Trial definition parameters and metadata.


% Number of seconds to pad around trial start/end codes.
trial_pad_secs = 1;

% Method for pruning non-incremented ("bad") trials. "keep", "strict", or
% "forgiving". "strict" discards end-of-list trials, "forgiving" doesn't.

trial_prune_method = 'strict';

% Trial event code to align t=0 on.
% Chalie used 'FixCentralCueStart'.

trial_align_evcode = 'FixCentralCueStart';



%
% Epoch parameters.

% This should be one of the metadata fields in "metabytrial" from
% "XXX-trialmeta.mat". Typical fields are 'lastfixationstart',
% 'lastfixationend', 'tokentime', 'correcttime', and 'rewardtime'.
% Metadata was extracted from evcodes by "euMeta_getTrialMetadataFromCodes".

epoch_align_feature = 'lastfixationstart';

% The ROI is -0.75 sec to +1.5 sec. We're padding a bit.
epoch_timespan_sec = [ -1 2 ];



%
% Filtering and resampling parameters.


% Signal conditioning.

notch_filter_freqs = [ 60, 120, 180 ];
notch_filter_bandwidth = 2.0;

% FIXME - Not doing artifact removal.
% This data had no stimulation, but there will still be licking artifacts.
artifact_passes = 2;
artifact_func = NaN;


% Derived signals.

% NOTE - This should be 10x-20x the highest frequency in the signal, to
% avoid aliasing. The anti-aliasing filter is far from perfect.
downsampled_rate = 2000;

derived_config = struct();

% Typical LFP features are 2-200 Hz.
% Charlie used a 300 Hz corner and 1 ksps.
% If the filter corner frequency is too high, we'll get leakage from MUA.
derived_config.lfp_maxfreq = 300;
derived_config.lfp_samprate = downsampled_rate;

% Spikes are typically on a ms timescale but have broad tails, so
% low-frequency components matter.
% Charlie used a 100 Hz corner.
% If the filter corner frequency is too low, we'll get leakage from the LFP.
derived_config.highpass_minfreq = 100;

% For MUA, we don't care about spike tail shapes, so we can set the lower
% corner higher.
% Charlie used 750 Hz - 5 Hz, a 300 Hz low-pass corner, and 1 ksps.
% Thilo says 200 Hz low-pass is standard.
derived_config.mua_band = [ 1000 5000 ];
derived_config.mua_lowpass = 200;
derived_config.mua_samprate = downsampled_rate;


% FIXME - Gaze NYI.

% We're resampling gaze as a continuous signal.
% The raw data is nonuniformly sampled; we're interpolating.
% As long as this sampling rate is higher than the device rate (300/600 Hz),
% the exact rate shouldn't be critical.
gaze_samprate = downsampled_rate;



%
% Bad channel detection configuration.


% Hand-annotated good and bad channel lists.

badconfiglog = struct( 'annotated_are_cooked', true );


% Manual override bad channel lists.

badconfigforce = struct( 'annotated_are_cooked', true );


% Spectral detection via nlProc_getBandPower().

% If the frequency bins are wider than an octave, low frequencies will
% dominate, since the LFP is somewhere between pink and red noise.
% At higher-than-LFP frequencies, we can pretend it's white noise.

badconfigspect = struct();

% Low-frequency bin midpoints are 10, 20, 40, and 80 Hz.
badconfigspect.freqedges = [ 7 14 30 60 120 240 500 1000 3000 ];

% Z-scored acceptance ranges for in-band power and tone power.
% A value of NaN is replaced with a default. [] is read as [ nan nan ].
% The number of rows (in either of these) is the desired number of passes.
% (Defalt power range is [-2 inf], default tone range is [-inf 2].)

% NOTE - Different probes / brain regions have different suitable thresholds.
% Semi-automated user-assisted inspection is probably the way to go.

badconfigspect.bandrange = [ -1.5 inf ];
badconfigspect.tonerange = [ -inf 1.5 ];


% Top-level metadata config for bad channel detection.
% Any method with a config gets called.

badconfigall = struct();
badconfigall.log = badconfiglog;
badconfigall.force = badconfigforce;
badconfigall.spect = badconfigspect;



%
% This is the end of the file.
