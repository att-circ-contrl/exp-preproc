function [ newtrialmeta origfrommasked maskedfromorig ] = ...
  epIter_helper_prunteTrialMetadata( trialdefmeta, trialmask )

% function [ newtrialmeta origfrommasked maskedfromorig ] = ...
%   epIter_helper_pruneTrialMetadata( trialdefmeta, trialmask )
%
% This function copies a subset of trial definition metadata into a new
% metadata structure.
%
% "trialdefmeta" is a structure containing all of the variables in the trial
%   definition metadata file, per PREPROCFILES.txt.
% "trialmask" is a boolean vector that's true for trials that are to be kept
%   and false for trials that are to be discarded.
%
% "newmeta" is a copy of "trialdefmeta" with unwanted trials removed.
% "origfrommasked" is a vector with old trial indices, indexed by new.
% "maskedfromorig" is a vector with new trial indices, indexed by old.


% Build a filtered trial metadata struture.
% Since only three fields _aren't_ masked, rebuild instead of copying.

newtrialmeta = struct();

newtrialmeta = struct( ...
  'codesbytrial', { trialdefmeta.codesbytrial(trialmask) }, ...
  'metabytrial', trialdefmeta.metabytrial(trialmask), ...
  'trialdefs', trialdefmeta.trialdefs(trialmask,:), ...
  'trialdeftable', trialdefmeta.trialdeftable(trialmask,:), ...
  'trial_align_evcode', trialdefmeta.trial_align_evcode, ...
  'trialindices', trialdefmeta.trialindices(trialmask), ...
  'triallabels', { trialdefmeta.triallabels(trialmask) }, ...
  'trialnames', { trialdefmeta.trialnames(trialmask) }, ...
  'sessionlabel', trialdefmeta.sessionlabel, ...
  'sessiontitle', trialdefmeta.sessiontitle );


% Build indexing lookup tables.

origfrommasked = find(trialmask);

maskedfromorig = nan(size(trialmask));
maskedfromorig(origfrommasked) = ...
  1:length(origfrommasked);


% Done.
end


%
% This is the end of the file.
