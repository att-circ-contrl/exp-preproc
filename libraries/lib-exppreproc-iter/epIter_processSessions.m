function epIter_processSessions( sessionlist, trialmetafilepat, ...
  probefuncbefore, probefuncafter, trialfunc, want_parallel, want_messages )

% function epIter_processSessions( sessionlist, trialmetafilepat, ...
%   probefuncbefore, probefuncafter, trialfunc, want_parallel, want_messages )
%
% This iterates through sessions, probes, and trials, calling processing
% functions.
%
% The intention is that processing functions read input data from per-trial
% files and write output data to per-trial files, in most cases.
%
% This uses "parfor", which executes in parallel if the Parallel Computing
% Toolbox is installed and falls back to single-threaded operation if not.
%
% "sessionlist" is a struct array with session metadata, per SESSIONMETA.txt.
% "trialmetafilepat" is a sprintf pattern used when building per-session
%   trial metadata filenames. The pattern should have the form
%   'prefix-%s-suffix.mat', where '%s' is replaced with the session label.
%   This is typically '(folder)/%s-trialmeta.mat'.
% "probefuncbefore" is a function handle that's called during probe iteration,
%   before trial iteration. The function template is per ITERFUNCS.txt.
%   Passing NaN omits the call to this function.
% "probefuncafter" is a function handle that's called during probe iteration,
%   after trial iteration. The function template is per ITERFUNCS.txt.
%   Passing NaN omits the call to this function.
% "trialfunc" is a function handle that's called during trial iteration.
%   The function template is per ITERFUNCS.txt. Passing NaN omits the call
%   to this function (it actually omits trial iteration entirely).
% "want_parallel" is true to use Parallel Computing Toolbox multithreading
%   for trial iteration, and false not to.
% "want_messages" is true to emit progress messages and false not to.
%
% No return value.


have_beforefunc = isa(probefuncbefore, 'function_handle');
have_afterfunc = isa(probefuncafter, 'function_handle');
have_trialfunc = isa(trialfunc, 'function_handle');


sessioncount = length(sessionlist);

for sidx = 1:sessioncount

  % Metadata.
  sessionmeta = sessionlist(sidx);
  sessiontitle = sessionmeta.sessiontitle;
  sessionlabel = sessionmeta.sessionlabel;

  % Banner.
  if want_messages
    disp(sprintf( '== Session "%s" (%d/%d) (%s).', ...
      sessiontitle, sidx, sessioncount, sessionmeta.monkey ));
  end


  % Read this session's trial definition metadata.

  thisfname = sprintf( trialmetafilepat, sessionlabel );
  if ~exist(thisfname, 'file')
    if want_messages
      disp([ ...
        '###  Can''t find trial metadata for session "' sessiontitle '".' ]);
    end
    continue;
  end

  % We're storing this in a structure so that it can be passed to helper
  % functions.
  % See PREPROCFILES.txt for full contents list.
  trialdefmeta = load(thisfname);


  %
  % Iterate probes.

  probecount = length(sessionmeta.probedefs);
  trialcount = length(trialdefmeta.trialnames);

  for pidx = 1:probecount

    probemeta = sessionmeta.probedefs(pidx);
    probetitle = probemeta.title;
    probelabel = probemeta.label;

    if want_messages
      disp([ '-- Probe "' probetitle '".' ]);
      probetime = tic;
    end


    % Before-trial processing.
    beforedata = struct();
    if have_beforefunc
      beforedata = probefuncbefore( sessionmeta, probemeta, trialdefmeta, ...
        want_messages );
    end


    %
    % Iterate trials.

    trialresults = {};

    if have_trialfunc

      if want_parallel
        parfor tidx = 1:trialcount
          % Suppress console messages.
          nlFT_initFTQuietly;
          warning('off');

          % Call the helper function.
          % Suppress messages from worker threads.
          trialresults{tidx} = trialfunc( sessionmeta, probemeta, ...
            trialdefmeta, tidx, beforedata, false );
        end
      else
        for tidx = 1:trialcount
          % Call the helper function.
          trialresults{tidx} = trialfunc( sessionmeta, probemeta, ...
            trialdefmeta, tidx, beforedata, want_messages );
        end % Trial iteration.
      end

    end


    % After-trial processing.
    if have_afterfunc
      probefuncafter( sessionmeta, probemeta, trialdefmeta, ...
        beforedata, trialresults, want_messages );
    end


    if want_messages
      durstring = nlUtil_makePrettyTime( toc(probetime) );
      disp([ '-- Finished probe "' probetitle '" (' durstring ').' ]);
    end

  end  % Probe iteration.

end  % Session iteration.

% Banner.
if want_messages
  disp('== Finished.');
end


% Done.
end


%
% This is the end of the file.
