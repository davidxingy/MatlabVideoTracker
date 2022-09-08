function plotMarkerTrakerPhysData(markerTrakerHandle, physData, physDataType, physSampleRate, videoPhysSync, varargin)
% function plotMarkerTrakerPhysData(markerTrakerHandle, physData, physDataType, physSampleRate,
%                                               videoPhysSync, [plotRange], [physDataLabels], [plotFunctionHandle])
% 
% This function plots external physiology data that may have been collected
% simultaneously with video recordings that is displayed in the
% MarkerTracker GUI. Will update the data plotted to be synchronized with
% the frame 
% 
% Inputs:
% markerTrakerHandle -  Handle to the marker tracker gui
% 
% physData -            Data to be plotted. Can be a NxM array of data,
%                       where N is the number of channels, and M is the
%                       number of samples, or a 1xN cell array of timestamps
%                       for raster plots where each cell corresponds to a
%                       neuron. For plotting multiple types of data, can be
%                       a cell array of NxM data or 1xN timestamps data
%                       in which case the data in each cell will be
%                       plotted next to each other.
% 
% videoPhysSync -       Sync indices for each frame of the video. If
%                       physData is an array, then videoPhysSync is an 1xF
%                       array where F is the number of frames in the video.
%                       videoPhysSync should contain the sample index which
%                       corresponds to each frame in the video. If physData
%                       is a cell array, videoPhysSync should also be a
%                       cell array which each cell correpsonding to each
%                       physData array.
% 
% physDataType -        String or string array. "time series" indicates
%                       that the data corresponds to sequentially recorded
%                       data. "time stamps" indicates that the data
%                       corresponds to the timestamps of events occuring
%                       (e.g. neural spike times)
% 
% physSampleRate -      The sample rate in Hz for each of the datasets in
%                       physData.
% 
% plotRange -           Optional input. 1x2 array with the first number
%                       being the number of ms to plot before the frame
%                       timepoint and the second number being the number of
%                       ms of data to plot after the frame timepoint.
%                       Default [200 500];
% 
% physDataLabels -      Optional input. Cell array of strings indicating
%                       label name for each of the channels in the datasets
%                       of physData. Default will just be Ch1, Ch2, ect.
% 
% plotFunctionHandle -  Optional input. Default will just plot each channel
%                       of physData vertically spaced. If there is a custom
%                       way of plotting the data implemented in a function,
%                       can use this variable to input the function handle
%                       to those functions and the data will be plotted
%                       with those functions instead.
% 
% David Xing, last updated 6/6/2022


% if user only inputted one dataset, still put it into a single cell array
% for consistency
if ~iscell(physData)
    
    physData = {physData};
    physDataType = {physDataType};
    videoPhysSync = {videoPhysSync};
    
end

% make default channel label names
for iPlot = 1:length(physData)
    switch physDataType{iPlot}
        case 'time series'
            defaultLabels{iPlot} = join([repmat("ch",1,size(physData{iPlot},1))' ...
                string(1:size(physData{iPlot},1))'],'');
        case 'time stamps'
            defaultLabels{iPlot} = join([repmat("ch",1,length(physData{iPlot}))' ...
                string(1:length(physData{iPlot}))'],'');
        otherwise
            defaultLabels{iPlot} = {};
    end
end


% parse inputs
narginchk(5,8)

if nargin==5
    %default don't use any custom plotting function, and use default window
    %and channel labels
    plotFunctionHandle = repmat({[]},1,length(physData));
    plotRange = [200 500];
    physDataLabels = defaultLabels;
elseif nargin == 6
    plotFunctionHandle = repmat({[]},1,length(physData));
    physDataLabels = defaultLabels;
    plotRange = varargin{1};
elseif nargin == 7
    plotFunctionHandle = repmat({[]},1,length(physData));
    plotRange = varargin{1};
    physDataLabels = varargin{2};
else    
    plotRange = varargin{1};
    physDataLabels = varargin{2};
    plotFunctionHandle = varargin{3};
end

if isempty(plotRange)
    plotRange = [200 500];
end

if isempty(physDataLabels)
    physDataLabels = defaultLabels;
end

if ~iscell(physDataLabels)
    physDataLabels = {physDataLabels};
end


% make sure the same number of parameters is inputted as the number of
% inputted data sets
if length(physData) ~= length(physDataType) || length(physData) ~= length(videoPhysSync) || ...
        length(physData) ~= length(physSampleRate) || length(physData) ~= length(plotFunctionHandle)

    error(['The number of physData datasets must match the number of physDataType, physSampleRate, '...
        'videoPhysSync, and plotFunctionHandle inputs!'])
    
end

% figure out how many time-series and time-stamp datasets there are
timeSeriesInds = find(strcmpi(physDataType,'time series'));
nTimeSeriesData = length(timeSeriesInds);

timeStampsInds = find(strcmpi(physDataType,'time stamps'));
nTimeStampsData = length(timeStampsInds);

if(nTimeStampsData + nTimeSeriesData ~= length(physData))
%     error('Must use either ''time series'' or ''time stamps'' for physDataType!')
end

nDataSets = length(physData);
% make figure
figureH = figure('Color','w');

tileHandle = tiledlayout(nDataSets,1);
tileHandle.TileSpacing = 'compact';
tileHandle.Padding = 'compact';

for iPlot = 1:nDataSets
    
    %get the scale of the data for y-axis offsetting
    switch physDataType{iPlot}
        case 'time series'
            offsets(iPlot) = max(prctile(physData{iPlot},99.99,2)-prctile(physData{iPlot},0.01,2));
            yAxLims(iPlot,:) = [min([0 prctile(physData{iPlot}(1,:),0.01)]) ...
                prctile(physData{iPlot}(end,:),99.99)+offsets(iPlot)*(size(physData{iPlot},1)-1)];
        case 'time stamps'
            offsets(iPlot) = nan;
            yAxLims(iPlot,:) = [0 length(physData{iPlot})];
    end
    
    nexttile
    
    if ~strcmpi(physDataType{iPlot},'custom')
        switch physDataType{iPlot}
            case 'time series'
                %just use blank plots as placeholders for now
                for iChan = 1:size(physData{iPlot},1)
                    plotHs{iPlot}(iChan) = plot(nan,'LineWidth',2);
                    hold on
                end

            case 'time stamps'
                %just use blank plots as placeholders for now
                plotHs{iPlot} = scatter(nan,nan,'.k','sizedata', 50);

        end
        line([0 0],yAxLims(iPlot,:),'color','r','linestyle','--')
        hold off

        axesHs(iPlot) = gca;
        box off

        %set channel labels
        set(gca,'YLim',yAxLims(iPlot,:));
        set(gca,'YTick',offsets(iPlot)*(0:(size(physData{iPlot},1)-1)));
        set(gca,'YTickLabel',physDataLabels{iPlot})
        set(gca,'XLim',[-1*plotRange(1) plotRange(2)]);
        set(gca,'LineWidth',2)
        set(gca,'FontSize',15)

    else

        [plotHs{iPlot} customPlotVars{iPlot}] = plotFunctionHandle{iPlot}([],true);
        axesHs(iPlot) = gca;

    end
    
end

% assign listener to the markertraker frame number box
vidListener = addlistener(markerTrakerHandle.Children(46),'String','PostSet',@updatePlot);


    %callback function for when the frame is changed, updated the plots
    function updatePlot(src,evnt)
        
        currentFrame = str2double(evnt.AffectedObject.String);
        
        for iPlot = 1:nDataSets

%             axes(plotHs(iPlot));
                        
            switch physDataType{iPlot}
                case 'time series'
                    
                    %get the sample and window corresponding to the current frame
                    currentSample = videoPhysSync{iPlot}(currentFrame);

                    %get section of data corresponding to this frame
                    windowInds = [max([1 currentSample-physSampleRate(iPlot)*plotRange(1)/1000]) ...
                        min([size(physData{iPlot},2) currentSample+physSampleRate(iPlot)/1000*plotRange(2)])];
                    dataWindow = physData{iPlot}(:,windowInds(1):windowInds(2));

                    %offset each of the channels so they don't overlap on
                    %top of each other
                    dataWindow = dataWindow + repmat((0:(size(dataWindow,1)-1))'*offsets(iPlot),1,size(dataWindow,2));
                    
                    %plot
                    for iChan = 1:size(physData{iPlot},1)
                        set(plotHs{iPlot}(iChan),'XData',(1:size(dataWindow,2))/physSampleRate(iPlot)*1000-plotRange(1));
                        set(plotHs{iPlot}(iChan),'YData',dataWindow(iChan,:));
                    end
                    

                case 'time stamps'
                    
                    %get the sample and window corresponding to the current frame
                    currentSample = videoPhysSync{iPlot}(currentFrame);

                    %get data range
                    windowInds = [max([1 currentSample-physSampleRate(iPlot)*plotRange(1)/1000]) ...
                        min([max(cat(1,physData{iPlot}{:})) currentSample+physSampleRate(iPlot)/1000*plotRange(2)])];
                        
                    %do raster plot
                    scatterX = [];
                    for iChan = 1:length(physData{iPlot})

                        timestampsWindow{iChan} = (physData{iPlot}{iChan}(...
                            physData{iPlot}{iChan} >= windowInds(1) & physData{iPlot}{iChan} <= windowInds(2))-currentSample)/...
                            physSampleRate(iPlot)*1000;
                        
                        chanHeights{iChan} = repmat(iChan,1,length(timestampsWindow{iChan}));
                        
                    end
                    
                    scatterX = cat(1,timestampsWindow{:});
                    scatterY = [chanHeights{:}]';
                    set(plotHs{iPlot},'XData',scatterX);
                    set(plotHs{iPlot},'YData',scatterY);
                                                              
                case 'custom'
                    plotFunctionHandle{iPlot}(currentFrame,false,customPlotVars{iPlot})

            end
            
            
            
        end
        
    end


end


% 

