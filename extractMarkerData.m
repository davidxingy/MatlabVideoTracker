function [markerNames trackedData] = extractMarkerData(dataFile)
% dataStruct = extractMarkerData(dataFile)
% 
% function to extract the tracked marker positions from the the saved .mat
% file from MarkerTracker
% 
% dataFile is a char/string pointing to the file to load
% 
% markerNames is the label of all the markers in a cell array
% trackedData is a cell array, which each cell corresponding to a marker,
% whos name is in markerNames. Each cell contains a Nx2 array with the
% first column being the x-position and the second column being the
% y-position in pixels, for all N frames of the video

% check that the file exists and is a valid MarkerTracker file
if ~any([ischar(dataFile) isstring(dataFile)])
    error('Input must be a char/string');
end

if isstring(dataFile)
    dataFile = dataFile{1};
end

if ~strcmp(dataFile(end-3:end),'.mat')
    error('Filename must end with ''.mat''');
end

if ~exist(dataFile)
    error([dataFile 'does not appear to exist'])
end

% load in the data
loadedVars = load(dataFile,'MARKERTRACKERGUI_UserData');

if ~isfield(loadedVars,'MARKERTRACKERGUI_UserData')
    error('The specified file does not appear to be a valid MarkerTracker save file (does not contain MARKERTRACKERGUI_UserData variable)')
end

% go through each of the markers and fill in the struct
markerNames = {loadedVars.MARKERTRACKERGUI_UserData.markersInfo.name};

% just double check that the number of marker names and the size of the
% tracked data array match
if length(markerNames) ~= size(loadedVars.MARKERTRACKERGUI_UserData.trackedData,1)
    error('Something wrong with the saved data, # of markers and size of tracked data array does not match')
end

for iMarker = 1:length(markerNames)

    trackedData{iMarker} = squeeze(loadedVars.MARKERTRACKERGUI_UserData.trackedData(iMarker,:,:));

end


% 
