function varargout = MarkerTracker(varargin)
% MARKERTRACKER MATLAB code for MarkerTracker.fig
%      MARKERTRACKER, by itself, creates a new MARKERTRACKER or raises the existing
%      singleton*.
%
%      H = MARKERTRACKER returns the handle to a new MARKERTRACKER or the handle to
%      the existing singleton*.
%
%      MARKERTRACKER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARKERTRACKER.M with the given input arguments.
%
%      MARKERTRACKER('Property','Value',...) creates a new MARKERTRACKER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MarkerTracker_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MarkerTracker_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MarkerTracker

% Last Modified by GUIDE v2.5 06-Mar-2020 00:01:42

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MarkerTracker_OpeningFcn, ...
                   'gui_OutputFcn',  @MarkerTracker_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


%------------------------------
%-----------Notes--------------
%------------------------------
% - When using image(), it treats the top and left edges to be the values 0.5
% 
% - Since I'm defining zoomRect as the index of the pixel, when adjusting by the
% zoomRect, always offset by zoomRect-1 since Matlab is index at 1
% 
% - Matlab's video reader implementation is shit and won't let me jump to
% frames directly. Instead I have to jump to the time of the frame but this
% doesn't accomodate variable frame rates. I think what's happening is
% Simi's videos, while trying to be synched to a set frame rate, actually
% has some very small jitter in between frames and when I try to jump to
% the time in the video reader, sometimes matlab doesn't read the correct
% frame (and sometimes it doesn't even update the CurrentTime after reading
% a frame!). So I have to jump a couple of frames into the past and just
% read and throw aways some frames to get to the correct frame which is
% inefficient.
% 
% - For writing to Simi .p files, Simi will add each pair of columns as the
% X and Y data for a marker (if there's an odd number of columns, it'll
% just ignore the last column). It uses the point IDs as the main
% identifier rather than the name. The second column of each column pair is
% just a repeat of the joint name and ID. The first column is the
% horizontal data, the second column is the vertical data. 0 corresponds to
% the top and left edge, 1 corresponds to the bottom and right edge. If
% there are IDs that it doesn't recognize, it can let the user
% automatically import these new names/ids as markers in its
% specifications (note that even if there is a marker with the same name,
% as long as the IDs are different, Simi won't recognize it). If there are
% more data columns than IDs/names it will create a new marker with a newly
% generated ID and for the name, will just repeat the name that was in the
% last column


% --- Executes just before MarkerTracker is made visible.
function MarkerTracker_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MarkerTracker (see VARARGIN)

% Choose default command line output for MarkerTracker
handles.output = hObject;

% GUI general settings
handles.UserData.VersionNumber = '4.1';

handles.UserData.bufferSize = 30;
handles.UserData.autosaveIntervalMin = 3;
handles.UserData.lostMarkerStopAutorun = false;
handles.UserData.plotMarkerSize = 4;
handles.UserData.plotMarkerEstSize = 9;
handles.UserData.plotMarkerWidth = 2;
handles.UserData.plotMarkerColor = 'y';
handles.UserData.plotMarkerEstColor = 'm';
handles.UserData.plotSegmentWidth = 0.7;
handles.UserData.plotSegmentColor = 'r';
handles.UserData.plotCurrentMarkerSize = 10;
handles.UserData.plotCurrentMarkerColor = 'w';
handles.UserData.epochPatchColor1 = [0.000,  0.447,  0.741];
handles.UserData.epochPatchColor2 = [0.929,  0.694,  0.125];
handles.UserData.contrastEnhancementLevel = 0.01;
handles.UserData.defaultMarkerSize = [30 30];
handles.UserData.channelNames = {... %make sure to define these in findMarkerPos function!
    'Green','Red','Red/Green','Blue','Hue','Saturation','Value','Grey'};
handles.UserData.nColorChannels = length(handles.UserData.channelNames);

handles.UserData.predictiveModelNames = {... %make sure to define these in trainModelbutton and autoincrement functions!
    'Spline'};

handles.UserData.splineNPoints = 5; %for spline trajectory prediction, number of points to fit
handles.UserData.splineMAOrder = 3; %for spline trajectory prediction, number of points for the pre-fit MA filter

handles.UserData.kinModel.minInputs = 3; %for kinematic model estimation with kNN, the min number of input features to the kNN
handles.UserData.kinModel.classifierK = 5; %for kinematic model estimation, the number of kNN points
handles.UserData.kinModel.defaultAngleTol = 20; %the maximum standard deviation of the kNN point outputs, in degrees

handles.UserData.minMarkerDist = 5; %the minimum number of pixels two markers can be within each other
handles.UserData.autorunDispInterval = 10; %number of frames to track before updating display during autorun
handles.UserData.minConvex = 0.8; %minimun ratio of area to convext area of blobs before trying to separate into two blobs

handles.UserData.lengthOutlierMult = 1.3; %multiplier to determine the maximum length between pairs in kin model
handles.UserData.maxJumpMult = 2; %multiplier to determine the maximum allowable jumps

handles.UserData.vidTimeTolerance = 1e-5; %Sometimes there's precision errors when getting current time from the vid reader,
                                          %set tolerance for the error here

% Some developer options
handles.GUIOptions.plotPredLocs = false;
handles.GUIOptions.kinModelNoNans = false;

% initialize properties
handles.UserData.markersInfo=struct([]);
handles.UserData.segments=[];
handles.UserData.videoLoaded=false;
handles.UserData.dataLoaded=false;
handles.UserData.currentFrameInd=NaN;
handles.UserData.currentMarkerInds=NaN;
handles.UserData.keypressCallbackRunning=false;
handles.UserData.zoomRect=NaN;
handles.UserData.dataInitialized=false;
handles.UserData.deleteRange=[str2double(handles.DeleteStartInput.String),...
    str2double(handles.DeleteEndInput.String)];
handles.UserData.drawStickFigure=handles.ShowStickFigureCheckBox.Value;
handles.UserData.showMarkerEsts=handles.ShowEstimatesCheckBox.Value;
handles.UserData.stick_h=[];
handles.UserData.epochPositionLine_h=[];
handles.UserData.globalContrast=0;
handles.UserData.globalBrightness=0;
handles.UserData.globalDecorr=false;
handles.UserData.modelType=handles.UserData.predictiveModelNames{handles.KinematicModelSelect.Value};
handles.KinematicModelSelect.String=handles.UserData.predictiveModelNames;
% handles.UserData.kinModelParams=[];
% handles.UserData.kinModelJointInds=[];
handles.UserData.kinModel.trainingDataAngles=[];
handles.UserData.kinModel.trainingDataLengths=[];
handles.UserData.kinModel.anchorNames1=string([]);
handles.UserData.kinModel.anchorNames2=string([]);
handles.UserData.kinModel.nExterns=0;
handles.UserData.kinModel.externFileNames={};
handles.UserData.kinModel.externData={};
handles.UserData.kinModel.externMarkerNames={};
handles.UserData.epochs=[];
handles.UserData.currentEpoch = [];
handles.UserData.exclusionZones={};
handles.UserData.exclusionMask=[];
handles.UserData.kinModelDefined=false;
handles.UserData.kinModelTrained=false;
handles.UserData.dataBackup.trackedData = {};
handles.UserData.dataBackup.boxSizes = {};
handles.UserData.dataBackup.frameInds = {};
handles.UserData.dataBackup.markerInds = [];
handles.UserData.frameJumpAmount = 10;
handles.UserData.image_h = [];
handles.UserData.currentMarkers_h = [];
handles.UserData.estimatedMarkers_h = [];
handles.UserData.selection_h = [];
handles.UserData.markerBoxImage_h = [];
handles.UserData.markerBoxCenter_h = [];
handles.UserData.currentEpochBox_h = [];
timeInfo=clock;
handles.UserData.lastSavedTime=timeInfo(4)*60+timeInfo(5);


% set figure callbacks (scroll wheel use, and left and right buttons)
set(gcf,'windowscrollWheelFcn', {@ScrollWheel_Callback,hObject});
set(gcf,'WindowKeyPressFcn', {@Keypress_Callback,hObject});
set(gcf,'Interruptible', 'off');
set(gcf,'BusyAction', 'cancel');
setappdata(handles.figure1,'evaluatingKeyPress',false)

% set autorun button callback to be interruptable
setappdata(handles.figure1,'autorunEnabled',false);
set(handles.AutorunButton,'Interruptible','on');

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MarkerTracker wait for user response (see UIRESUME)
% uiwait(handles.figure1);


function marker = setMarkerDefaults(markerName, markerInd, handles)
% default parameters for markers

marker.name = markerName;
marker.UIListInd = markerInd;
marker.trackType = 'manual';
marker.usePredModel = false;
marker.useKinModel = false;
marker.freezeSeg = false;
marker.freezeSegAnchor = [];
marker.searchRadius = 10;
marker.guessSize = handles.UserData.defaultMarkerSize;
marker.modelParams = [];

marker.searchProperties.useChannels = zeros(handles.UserData.nColorChannels,1);
marker.searchProperties.thresholds = [zeros(handles.UserData.nColorChannels,1),...
    ones(handles.UserData.nColorChannels,1)*255];
marker.searchProperties.useContrastEnhancement = zeros(handles.UserData.nColorChannels,1);
marker.searchProperties.blobSizes = [];
marker.searchProperties.maxAspectRatio = 5;
marker.searchProperties.minArea = 0;

marker.kinModelAnchors = {};
marker.kinModelAngleTol = handles.UserData.kinModel.defaultAngleTol;



function ScrollWheel_Callback(src,callbackdata,hObject)
% go up or down on the selected marker list
handles=guidata(hObject);

% markers not loaded, don't do anything
if ~handles.UserData.dataLoaded
    return
end

if callbackdata.VerticalScrollCount>0
    %go down one
    newMarkerInd=min(handles.UserData.nMarkers,...
        handles.UserData.currentMarkerInds(end)+1);
else
    %go up one
    newMarkerInd=max(1,handles.UserData.currentMarkerInds(1)-1);
end

% update
handles=changeSelectedMarkers(handles,newMarkerInd);

guidata(hObject, handles);


function Keypress_Callback(src,callbackdata,hObject)
% go to next or previous frame
handles=guidata(hObject);
if ~handles.UserData.videoLoaded
    return
end

if ~strcmp(callbackdata.Key,'rightarrow') && ~strcmp(callbackdata.Key,'leftarrow') &&...
        ~strcmp(callbackdata.Key,'uparrow') && ~strcmp(callbackdata.Key,'downarrow') &&...
        ~strcmp(callbackdata.Key,'p') && ~strcmp(callbackdata.Key,'o')
    return
end

% if getappdata(handles.figure1,'evaluatingKeyPress')
%     disp('ignored')
%     return
% else
%     %     disp(handles.UserData.keypressCallbackRunning)
%     setappdata(handles.figure1,'evaluatingKeyPress',true)
% end

if strcmp(callbackdata.Key,'rightarrow')
    %next frame (if not end of video)
    if handles.UserData.currentFrameInd==handles.UserData.nFrames
%         setappdata(handles.figure1,'evaluatingKeyPress',false)
        return;
    end
    handles=changeFrame(handles,handles.UserData.currentFrameInd+1,true);
    
    if handles.UserData.dataInitialized
        
        %update markers that are set to 'auto'
        handles=autoIncrementMarkers(handles);
        
        %if the selected marker is set to freeze, set the est position for that
        %marker
        if handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).freezeSeg
            handles = setFreezePos(handles, 1);
        end
        
        handles=drawMarkersAndSegments(handles);
        
    end
    
    %FOR SOME REASON IF I DON'T PUT A PAUSE HERE IT WILL CONTINUE READING
    %KEY STROKES AND QUEUING THEM EVEN THOUGH I SET BUSYACTION TO CANCEL
    %RATHER THAN QUEUE
%     pause(0.04)
    
elseif strcmp(callbackdata.Key,'leftarrow')
    %previous frame (if not beginning of video)
    if handles.UserData.currentFrameInd==1
        setappdata(handles.figure1,'evaluatingKeyPress',false)
        return;
    end
    handles=changeFrame(handles,handles.UserData.currentFrameInd-1,true);
    
    %if the selected marker is set to freeze, set the est position for that
    %marker
    if handles.UserData.dataInitialized
        if handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).freezeSeg
            handles = setFreezePos(handles, -1);
            handles=drawMarkersAndSegments(handles);
        end
    end
    
elseif strcmp(callbackdata.Key,'uparrow')
    %go to marker one up on the list
    tmpCallbackData.VerticalScrollCount=-1;
    ScrollWheel_Callback([],tmpCallbackData,hObject)
    setappdata(handles.figure1,'evaluatingKeyPress',false)
    return %return now since the callback already updated handles
    
elseif strcmp(callbackdata.Key,'downarrow')
    %go to marker one up on the list
    tmpCallbackData.VerticalScrollCount=1;
    ScrollWheel_Callback([],tmpCallbackData,hObject)
    setappdata(handles.figure1,'evaluatingKeyPress',false)
    return %return now since the callback already updated handles
    
elseif strcmp(callbackdata.Key,'p')
    %jump forward some number of frames
    handles=changeFrame(handles,min([handles.UserData.currentFrameInd+...
        handles.UserData.frameJumpAmount, handles.UserData.nFrames]),true);
    
elseif strcmp(callbackdata.Key,'o')
    %jump back some number of frames
    if handles.UserData.currentFrameInd==1
        setappdata(handles.figure1,'evaluatingKeyPress',false)
        return;
    end
    handles=changeFrame(handles,max([handles.UserData.currentFrameInd-...
        handles.UserData.frameJumpAmount, 1]),true);
    
end

% handles.UserData.keypressCallbackRunning=false;
% setappdata(handles.figure1,'evaluatingKeyPress',false)

guidata(hObject, handles);



% --- Executes on mouse press over axes background.
function FrameButtonDown_Callback(hObject,eventdata)
% hObject    handle to FrameAxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% no data strucutre, don't do anything
if ~handles.UserData.dataInitialized
    return
end

% get the clicked point
point=eventdata.IntersectionPoint(1:2);
if ~isnan(handles.UserData.zoomRect)
    point=point+handles.UserData.zoomRect(1:2)-1;
end

% find the actual marker location using the selected point as estimate
handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation=point;

% if there is already a box size in this frame, use that, otherwise use
% previous frame's box size
if ~isnan(handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,1))...
        || handles.UserData.currentFrameInd==1 %don't get previous frame if first frame
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize=...
        squeeze(handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds(1),...
        handles.UserData.currentFrameInd,:));
else
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize=...
        squeeze(handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds(1),...
        handles.UserData.currentFrameInd-1,:));
end

% if still no box size, use default box size
if isnan(handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize)
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize=...
        handles.UserData.defaultMarkerSize;
end

%set properties to include contrast enhancement and track type
markerProperties=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties;
markerProperties.contrastEnhancementLevel=handles.UserData.contrastEnhancementLevel;
markerProperties.trackType=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).trackType;

% call marker search function
[markerPos, boxSize]=TrackerFunctions.findMarkerPosInFrame(handles.UserData.currentFrame,...
    handles.UserData.channelNames,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize,...
    markerProperties,point,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchRadius,...
    handles.UserData.minConvex);

% save marker location to data array
% first store overwritten data to backup for Undo button
handles.UserData.dataBackup.trackedData = ...
    mat2cell(handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:), 1, 1, 2);
handles.UserData.dataBackup.boxSizes = ...
    mat2cell(handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:), 1, 1, 2);
handles.UserData.dataBackup.markerInds = handles.UserData.currentMarkerInds(1);
handles.UserData.dataBackup.frameInds = {handles.UserData.currentFrameInd};


handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=markerPos;
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=boxSize;

% redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(handles.figure1,handles)



% --- Executes on mouse press over axes background.
function EpochAxes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to EpochAxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles=guidata(hObject);

% get the clicked point
point=eventdata.IntersectionPoint(1);

% see if the point is in an epoch
currentEpoch=[];
for iEpoch=1:size(handles.UserData.epochs,1)
    if point >= handles.UserData.epochs(iEpoch,1) && point <= handles.UserData.epochs(iEpoch,2)
        currentEpoch=iEpoch;
    end
end

% if we are, see which edge of the epoch we clicked closest to
if ~isempty(currentEpoch)
    if abs(handles.UserData.epochs(currentEpoch,1)-point) <= abs(handles.UserData.epochs(currentEpoch,2)-point)
        %move to the beginning of the epoch
        handles=changeFrame(handles,handles.UserData.epochs(currentEpoch,1),true);
    else
        %move to end of the epoch
        handles=changeFrame(handles,handles.UserData.epochs(currentEpoch,2),true);
    end
end

guidata(hObject,handles)


function handles=updateVidDisplayInfo(handles)
% function to initialize gui when video is loaded in (either during setting
% up, or when loading in from a previous saved session (used in
% LoadVidButton callback and LoadDataButton callback)

% set frame slider values according to the video
handles.FrameSlider.Min=1;
handles.FrameSlider.Max=handles.UserData.nFrames;
handles.FrameSlider.SliderStep=[1/handles.UserData.nFrames 10/handles.UserData.nFrames];

% set filename and fps display
% handles.
[~,vidFileName,vidFileExt]=fileparts(handles.UserData.videoFile);
handles.FileNameText.String=[vidFileName, vidFileExt];
handles.FPSText.String=[num2str(handles.UserData.frameRate) ' fps'];



function handles=displayMessage(handles, message, textColor)
% function to display a warning or status message to the user in the GUI
% the function will not update hObject, so be sure to call guidata in the
% calling function!

% set display textbox string to the message
if isa(message, 'char') || isa(message, 'string')
    handles.MessageTextBox.String = message;
else
    handles.MessageTextBox.String = 'Unable to display message!';
end

% set display message to the color if specified
if (nargin == 3) && all(size(textColor) == [1 3]) &&...
        all([0 0 0] <= textColor) && all(textColor <= [1 1 1])
    handles.MessageTextBox.ForegroundColor = textColor;
else
    handles.MessageTextBox.ForegroundColor = [0 0 0];
end
    



function handles=changeFrame(handles,frameNumber,displayNewFrame)
% function to change current frame. *frame 1 is time 0.00
% note that this function will update the currentFrameInd variable in 
% handles, so the calling function shouldn't do that! Also make sure that 
% the calling function updates the handles structure with guidata()!!

% don't do anything if video hasn't been loaded
if ~handles.UserData.videoLoaded
    return
end

previousFrameNumber=handles.UserData.currentFrameInd;
handles.UserData.currentFrameInd=frameNumber;

if frameNumber-previousFrameNumber==1
    try
        frame=handles.UserData.videoReader.readFrame;
    catch ME
        handles.UserData.currentFrameInd=previousFrameNumber;
        setappdata(handles.figure1,'evaluatingKeyPress',false)
        return
    end
else
    %read frame multiple times due to some weird precision errors and 
    %variable frame rates which sometimes results in wrong frame read 
    %if I just try to jump directly to a frame with CurrentTime.
    handles.UserData.videoReader.CurrentTime=max((frameNumber-2)/handles.UserData.frameRate,0);
    while abs(handles.UserData.videoReader.CurrentTime-(frameNumber-1)/handles.UserData.frameRate) > ...
            handles.UserData.vidTimeTolerance
        
        frame=handles.UserData.videoReader.readFrame;
        
        if (handles.UserData.videoReader.CurrentTime-(frameNumber-1)/handles.UserData.frameRate) > ...
                handles.UserData.vidTimeTolerance
            
            setappdata(handles.figure1,'evaluatingKeyPress',false)
            disp(['Failed to move to frame ' num2str(frameNumber)])
            return;
            
        end
        
    end
    frame=handles.UserData.videoReader.readFrame;
end
handles.UserData.currentFrame=frame;
handles.UserData.currentFrameUnprocessed=frame;

% now add to buffer
% if the frame number jumped, empty the buffer
% if isnan(previousFrameNumber) || abs(previousFrameNumber-frameNumber)>1
%     handles.UserData.frameBuffer.framesInBuffer=1;
%     handles.UserData.frameBuffer.currentBufferInd=1;
%     handles.UserData.frameBuffer.newestFrameInd=1;
    
    %jump to frame and read frame
%     handles.UserData.videoReader.CurrentTime=(frameNumber-1)/handles.UserData.frameRate;
%     frame=handles.UserData.videoReader.readFrame;
%     handles.UserData.currentFrame=frame;
%     handles.UserData.currentFrameUnprocessed=frame;
%     handles.UserData.frameBuffer.data{1}=frame;

% elseif previousFrameNumber-frameNumber==-1
% %incremented
% 
%     %incremented outside of buffer (i.e. we're at the newest frame),
%     %need to read in new frame
%     if handles.UserData.frameBuffer.currentBufferInd==...
%             handles.UserData.frameBuffer.newestFrameInd
%         
%         %jump to frame and read it
%         if (handles.UserData.videoReader.CurrentTime~=(frameNumber-1)/handles.UserData.frameRate)
%             handles.UserData.videoReader.CurrentTime=...
%                 (frameNumber-1)/handles.UserData.frameRate;
%         end
%         frame=handles.UserData.videoReader.readFrame;
%         handles.UserData.currentFrameUnprocessed=frame;
%         handles.UserData.currentFrame=frame;
% 
%         %add to buffer
%         handles.UserData.frameBuffer.currentBufferInd=...
%             handles.UserData.frameBuffer.currentBufferInd+1;
%         
%         %check if index looped around
%         if(handles.UserData.frameBuffer.currentBufferInd>handles.UserData.bufferSize)
%             handles.UserData.frameBuffer.currentBufferInd=...
%                 mod(handles.UserData.frameBuffer.currentBufferInd,...
%                 handles.UserData.bufferSize);
%         end
%         
%         %add frame data
%         handles.UserData.frameBuffer.data{...
%             handles.UserData.frameBuffer.currentBufferInd}=frame;
%         
%         %update the newestFrameInd to this ind
%         handles.UserData.frameBuffer.newestFrameInd=...
%             handles.UserData.frameBuffer.currentBufferInd;
%         
%         %finally check if we have made the buffer full with this latest
%         %frame
%         if ~handles.UserData.frameBuffer.isFull
%             handles.UserData.frameBuffer.framesInBuffer=...
%                 handles.UserData.frameBuffer.framesInBuffer+1;
%             if handles.UserData.frameBuffer.framesInBuffer==handles.UserData.bufferSize
%                 handles.UserData.frameBuffer.isFull=true;
%             end
%         end
%         
%     else
%     %otherwise just get frame from buffer
%         handles.UserData.frameBuffer.currentBufferInd=...
%             handles.UserData.frameBuffer.currentBufferInd+1;
%         
%         %check if index looped around
%         if(handles.UserData.frameBuffer.currentBufferInd>handles.UserData.bufferSize)
%             handles.UserData.frameBuffer.currentBufferInd=...
%                 mod(handles.UserData.frameBuffer.currentBufferInd,...
%                 handles.UserData.bufferSize);
%         end
%         
%         handles.UserData.currentFrame=handles.UserData.frameBuffer.data{...
%             handles.UserData.frameBuffer.currentBufferInd};
%         
%     end
%     
% elseif previousFrameNumber-frameNumber==1
%     %decremented
%     
%     oldestFrameInd=handles.UserData.frameBuffer.newestFrameInd-...
%         handles.UserData.frameBuffer.framesInBuffer+1;
%     %check if index looped around
%     if oldestFrameInd<=0
%         oldestFrameInd=mod(oldestFrameInd-1,handles.UserData.bufferSize)+1;
%     end
%     
%     %decremented outside of buffer (i.e. we're currently at the oldest
%     %frame), need to read in new frame
%     if handles.UserData.frameBuffer.currentBufferInd==oldestFrameInd
%         %jump to correct frame and then get it
%         if (handles.UserData.videoReader.CurrentTime~=(frameNumber-1)/handles.UserData.frameRate)
%             handles.UserData.videoReader.CurrentTime=...
%                 (frameNumber-1)/handles.UserData.frameRate;
%         end
%         frame=handles.UserData.videoReader.readFrame;
%         handles.UserData.currentFrame=frame;
%         handles.UserData.currentFrameUnprocessed=frame;
%     
%         %add to buffer
%         handles.UserData.frameBuffer.currentBufferInd=...
%             handles.UserData.frameBuffer.currentBufferInd-1;
%         %check if index looped around
%         if handles.UserData.frameBuffer.currentBufferInd<=0
%             handles.UserData.frameBuffer.currentBufferInd=...
%                 mod(handles.UserData.frameBuffer.currentBufferInd-1,...
%                 handles.UserData.bufferSize)+1;
%         end
%         
%         %add frame data
%         handles.UserData.frameBuffer.data{...
%             handles.UserData.frameBuffer.currentBufferInd}=frame;
%         
%         %update the newestFrameInd if the buffer was full (since I
%         %overwrote the newest frame with this frame)
%         if handles.UserData.frameBuffer.isFull
%             handles.UserData.frameBuffer.newestFrameInd=...
%                 handles.UserData.frameBuffer.newestFrameInd-1;
%             %check if index looped around
%             if handles.UserData.frameBuffer.newestFrameInd<=0
%                 handles.UserData.frameBuffer.newestFrameInd=...
%                     mod(handles.UserData.frameBuffer.newestFrameInd-1,...
%                     handles.UserData.bufferSize)+1;
%             end
%         end
%         
%         %finally check if we have made the buffer full with this latest
%         %frame
%         if ~handles.UserData.frameBuffer.isFull
%             handles.UserData.frameBuffer.framesInBuffer=...
%                 handles.UserData.frameBuffer.framesInBuffer+1;
%             if handles.UserData.frameBuffer.framesInBuffer==handles.UserData.bufferSize
%                 handles.UserData.frameBuffer.isFull=true;
%             end
%         end
%         
%     else
%     %otherwise just get the frame from the buffer
%         handles.UserData.frameBuffer.currentBufferInd=...
%             handles.UserData.frameBuffer.currentBufferInd-1;
%         
%         %check if index looped around
%         if(handles.UserData.frameBuffer.currentBufferInd<=0)
%             handles.UserData.frameBuffer.currentBufferInd=...
%                 mod(handles.UserData.frameBuffer.currentBufferInd-1,...
%                 handles.UserData.bufferSize)+1;
%         end
%         
%         handles.UserData.currentFrame=handles.UserData.frameBuffer.data{...
%             handles.UserData.frameBuffer.currentBufferInd};
% 
%     end
%     
% elseif previousFrameNumber==frameNumber
%     return
% else
%     %this should never happen, frame should've either been a increment by
%     %1, a decreent by 1, or a jump
%     warndlg('Something wrong with code, debug here!')
% end

% apply image processing
handles.UserData.currentFrame=TrackerFunctions.applyImageProcessing(...
    handles.UserData.currentFrameUnprocessed, handles.UserData.globalBrightness,...
    handles.UserData.globalContrast, handles.UserData.globalDecorr, handles.UserData.exclusionMask);

% show frame (or zoomed in frame)
if displayNewFrame
    handles = drawFrame(handles);
    handles=drawMarkersAndSegments(handles);
end

% update slider
handles.FrameSlider.Value=handles.UserData.currentFrameInd;

% update frame number
handles.FrameNumberBox.String=num2str(frameNumber);

% update epoch bar
handles=drawEpochBar(handles, false);


function handles = drawFrame(handles, varargin)

narginchk(1,2);
if nargin==2
    callImshow = varargin{1};
else
    callImshow = false;
end

% for the first time showing the frame, use imshow, unless we're directed
% otherwise (e.g. zoom functions need to call imshow again)
if isempty(handles.UserData.image_h) || callImshow
    
    figure(handles.figure1)
    axes(handles.FrameAxes);

    % get zoom box and then display
    if isnan(handles.UserData.zoomRect)
        handles.UserData.image_h = imshow(handles.UserData.currentFrame);
    else
        zoomRect=handles.UserData.zoomRect;
        handles.UserData.image_h = imshow(handles.UserData.currentFrame(zoomRect(2):zoomRect(2)+zoomRect(4)-1,...
            zoomRect(1):zoomRect(1)+zoomRect(3)-1,:));
    end
    % set callback for new axes
    handles.UserData.image_h.ButtonDownFcn=@FrameButtonDown_Callback;
    axis off

else

    % if not first time showing frame, just updated the CData of the image
    % rather than calling imshow again which is slow.
    % get zoom box and then update display
    if isnan(handles.UserData.zoomRect)
        handles.UserData.image_h.CData = handles.UserData.currentFrame;
    else
        zoomRect=handles.UserData.zoomRect;
        handles.UserData.image_h.CData = handles.UserData.currentFrame(zoomRect(2):zoomRect(2)+zoomRect(4)-1,...
            zoomRect(1):zoomRect(1)+zoomRect(3)-1,:);
        handles.UserData.image_h.XData = [1 size(handles.UserData.image_h.CData,2)];
        handles.UserData.image_h.YData = [1 size(handles.UserData.image_h.CData,1)];
    end

end


function handles=drawMarkersAndSegments(handles, varargin)
% function to draw the markers and stick figure

narginchk(1,2);
if nargin==2
    callPlotFunctions = varargin{1};
else
    callPlotFunctions = false;
end

if ~handles.UserData.dataInitialized
    return
end

% get marker data
markersPos=squeeze(handles.UserData.trackedData(:,handles.UserData.currentFrameInd,:));
markerBoxSize=round(squeeze(handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:))/2);
if any(isnan(markerBoxSize))
    markerBoxSize = handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize/2;
end
markersPosEst=squeeze(handles.UserData.modelEstData(:,handles.UserData.currentFrameInd,:));

% for zoomed in frames
if ~isnan(handles.UserData.zoomRect)
    markersPosZoom(:,1)=markersPos(:,1)-(handles.UserData.zoomRect(1)-1);
    markersPosZoom(:,2)=markersPos(:,2)-(handles.UserData.zoomRect(2)-1);
    markersPosEstZoom(:,1)=markersPosEst(:,1)-(handles.UserData.zoomRect(1)-1);
    markersPosEstZoom(:,2)=markersPosEst(:,2)-(handles.UserData.zoomRect(2)-1);
else
    markersPosZoom=markersPos;
    markersPosEstZoom=markersPosEst;
end

% draw current marker selection cursor if it's tracked or if there's an
% estimate for it from the kinematic model
if ~isnan(markersPos(handles.UserData.currentMarkerInds(1),1)) 
        
    %selection cursor is the tracked location
    currentMarkersXData = markersPosZoom(handles.UserData.currentMarkerInds(1),1);
    currentMarkersYData = markersPosZoom(handles.UserData.currentMarkerInds(1),2);
    currentMarkersPos = markersPos(handles.UserData.currentMarkerInds(1),:);
    markerExists = true;

elseif ~isnan(markersPosEst(handles.UserData.currentMarkerInds(1),1))
    
    %selection cursor is the estimated location
    currentMarkersXData = markersPosEstZoom(handles.UserData.currentMarkerInds(1),1);
    currentMarkersYData = markersPosEstZoom(handles.UserData.currentMarkerInds(1),2);
    currentMarkersPos = markersPosEst(handles.UserData.currentMarkerInds(1),:);
    markerExists = true;
    
else
    
    %no marker data, don't show selection cursor
    currentMarkersXData = nan;
    currentMarkersYData = nan;
    markerExists = false;
    
end

% plot makers on frame
% get the pixel data for all tracked markers
allMarkersXData = markersPosZoom(:,1);
allMarkersYData = markersPosZoom(:,2);

% and for all estimated markers
estMarkersXData = markersPosEstZoom(:,1);
estMarkersYData = markersPosEstZoom(:,2);

% don't plot estimated markers if the marker is tracked
estMarkersXData(find(~isnan(allMarkersXData))) = nan;
estMarkersYData(find(~isnan(allMarkersYData))) = nan;

% don't plot estimates if told not to
if handles.UserData.showMarkerEsts
    plotEsts = 'On';
else
    plotEsts = 'Off';
end

% now for the marker box
if markerExists
    
    startY = max(1, floor(currentMarkersPos(2)-markerBoxSize(2)));
    offsetY = max(1, currentMarkersPos(2)-markerBoxSize(2)) - startY;
    endY = min(ceil(currentMarkersPos(2)+markerBoxSize(2)), ...
        handles.UserData.frameSize(2));
    
    startX = max(1,floor(currentMarkersPos(1)-markerBoxSize(1)));
    offsetX = max(1, currentMarkersPos(1)-markerBoxSize(1)) - startX;
    endX = min(ceil(currentMarkersPos(1)+markerBoxSize(1)),...
        handles.UserData.frameSize(1));
    
    markerBoxImage = handles.UserData.currentFrame(startY:endY,startX:endX,:);
    markerBoxXLim = [offsetX+0.5 endX-startX+offsetX];
    markerBoxYLim = [offsetY+0.5 endY-startY+offsetY];
    markerBoxCenterX = markerBoxSize(1)+1+offsetX;
    markerBoxCenterY = markerBoxSize(2)+1+offsetY;
    
else
   
    markerBoxImage = 0;
    markerBoxXLim = [0 1];
    markerBoxYLim = [0 1];
    markerBoxCenterX = nan;
    markerBoxCenterY = nan;
    
end
    
% do the actual plotting
if isempty(handles.UserData.currentMarkers_h) || callPlotFunctions
    
    % we haven't done the first plot yet, so use plot/image ect which is
    % slow and save the handles
    
    axes(handles.FrameAxes)
    hold on
    
    %delete old plots
    delete(handles.UserData.currentMarkers_h);
    delete(handles.UserData.estimatedMarkers_h);
    delete(handles.UserData.selection_h);
    
    %plot the tracked points
    handles.UserData.currentMarkers_h = plot(allMarkersXData, ...
        allMarkersYData, 'o', ...
        'MarkerSize',handles.UserData.plotMarkerSize,...
        'MarkerEdgeColor','k',...
        'MarkerFaceColor',handles.UserData.plotMarkerColor,...
        'PickableParts','none');
    
    %plot the estimated points
    handles.UserData.estimatedMarkers_h = plot(estMarkersXData, ...
        estMarkersYData, 'x', ...
        'MarkerSize',handles.UserData.plotMarkerEstSize,...
        'MarkerEdgeColor','k',...
        'MarkerFaceColor',handles.UserData.plotMarkerEstColor,...
        'Visible', plotEsts,...
        'PickableParts','none');

    %put current marker selection cursor
    handles.UserData.selection_h = plot(currentMarkersXData, ...
        currentMarkersYData, 'o', ...
        'MarkerSize',handles.UserData.plotCurrentMarkerSize,...
        'Color',handles.UserData.plotCurrentMarkerColor,...
        'PickableParts','none');
    hold off
    
    %show marker box        
    axes(handles.MarkerAxes);
    handles.UserData.markerBoxImage_h = image(markerBoxImage);
    xlim(markerBoxXLim)
    ylim(markerBoxYLim)
    
    hold on
    handles.UserData.markerBoxCenter_h = plot(markerBoxCenterX,markerBoxCenterY,'+w');
    hold off
    axis off

else
    
    %plotting has been done in the past, just updated the data on the
    %handles rather then calling plot/image again which is slow
    handles.UserData.currentMarkers_h.XData = allMarkersXData;
    handles.UserData.currentMarkers_h.YData = allMarkersYData;
    
    handles.UserData.estimatedMarkers_h.XData = estMarkersXData;
    handles.UserData.estimatedMarkers_h.YData = estMarkersYData;
    handles.UserData.estimatedMarkers_h.Visible = plotEsts;
    
    handles.UserData.selection_h.XData = currentMarkersXData;
    handles.UserData.selection_h.YData = currentMarkersYData;

    %marker box
    handles.MarkerAxes.XLim = markerBoxXLim;
    handles.MarkerAxes.YLim = markerBoxYLim;
    handles.UserData.markerBoxImage_h.CData = markerBoxImage;
    
    handles.UserData.markerBoxCenter_h.XData = markerBoxCenterX;
    handles.UserData.markerBoxCenter_h.YData = markerBoxCenterY;
    
end

% now draw line segments if desired
if handles.UserData.drawStickFigure
    
    if ~isempty(handles.UserData.segments)
        
        %draw segments to estimated data or not
        if handles.UserData.showMarkerEsts
            markersPosZoom(isnan(markersPosZoom(:,1)),:)=markersPosEstZoom(isnan(markersPosZoom(:,1)),:);
        end
        segmentXs=[markersPosZoom(handles.UserData.segments(:,1),1)'; markersPosZoom(handles.UserData.segments(:,2),1)'];
        segmentYs=[markersPosZoom(handles.UserData.segments(:,1),2)'; markersPosZoom(handles.UserData.segments(:,2),2)'];
        
        if isempty(handles.UserData.stick_h) || callPlotFunctions
            %stick plot handle hasn't been defined yet, use line()
            
            axes(handles.FrameAxes)
            
            %delete old line segments
            for iLine=1:length(handles.UserData.stick_h)
                delete(handles.UserData.stick_h(iLine));
            end
            
            %draw line segments
            hold on
            
            handles.UserData.stick_h=line(segmentXs,segmentYs,'linewidth',handles.UserData.plotSegmentWidth,...
                'color',handles.UserData.plotSegmentColor,'PickableParts','none');
            
            hold off;
            
        else
            %have already used line(), just updated it's data instead of
            %re-calling line() which is slow
            
            for iLine=1:length(handles.UserData.stick_h)
                handles.UserData.stick_h(iLine).Visible = 'on';
                handles.UserData.stick_h(iLine).XData = segmentXs(:, iLine);
                handles.UserData.stick_h(iLine).YData = segmentYs(:, iLine);
            end
            
        end
        
    end

else
    
    %don't want to show lines, make them invisible (if lines have been
    %drawn)
    if ~isempty(handles.UserData.stick_h)
        for iLine=1:length(handles.UserData.stick_h)
            handles.UserData.stick_h(iLine).Visible = 'off';
        end
    end
    
end



function handles=drawEpochBar(handles, updateEpochs)
% function to update the epoch bar with the location of the defined epochs,
% and also draw a line to indicate the current frame position
if ~handles.UserData.videoLoaded
    return
end

% if we want to update epochs (i.e. epochs have changed)
if updateEpochs
    
    axes(handles.EpochAxes)
    
    % remove old rectangles
    htoDelete=[];
    for iHandle=1:length(handles.EpochAxes.Children)
        if strcmpi(class(handles.EpochAxes.Children(iHandle)),...
                'matlab.graphics.primitive.Patch')
            htoDelete=[htoDelete iHandle];
        end
    end
    delete(handles.EpochAxes.Children(htoDelete));
    
    % draw rectangles for each epoch
    color1=true;
    currentEpoch=[];
    for iEpoch=1:size(handles.UserData.epochs,1)
        
        epochStart=handles.UserData.epochs(iEpoch,1);
        epochEnd=handles.UserData.epochs(iEpoch,2);
        
        if handles.UserData.currentFrameInd>=epochStart && handles.UserData.currentFrameInd<=epochEnd
            currentEpoch=iEpoch;
        end
        patchEdgeColor=handles.UserData.epochPatchColor1*color1+handles.UserData.epochPatchColor2*(~color1);
        patchEdgeWidth=0.1;
        
        patch_h = patch([epochStart epochStart epochEnd epochEnd],[1 0 0 1],...
            handles.UserData.epochPatchColor1*color1+handles.UserData.epochPatchColor2*(~color1),...
            'EdgeColor',patchEdgeColor,'LineWidth',patchEdgeWidth,'HitTest','off');
        
        color1=~color1;
    end
    
    if ~isempty(currentEpoch)
        uistack(handles.EpochAxes.Children(currentEpoch),'top'); %bring current epoch patch to top
    end
    
end

% draw/move current epoch indicator box
if ~isempty(handles.UserData.epochs)
    
    newCurrentEpoch = find( handles.UserData.currentFrameInd >= handles.UserData.epochs(:,1) & ...
        handles.UserData.currentFrameInd <= handles.UserData.epochs(:,2) );
    
    if (~isempty(newCurrentEpoch) && isempty(handles.UserData.currentEpoch)) || ...
            any(newCurrentEpoch ~= handles.UserData.currentEpoch)
        
        %in this case, the current epoch has changed (either to a new epoch
        %from no epoch, or to a new epoch from a different epoch)
        
        %we'll need to change the current epoch indicator box
        currentEpochBoxStart = handles.UserData.epochs(newCurrentEpoch,1);
        currentEpochBoxEnd = handles.UserData.epochs(newCurrentEpoch,2);
        showBox = true;
        redrawBox = true;
        handles.UserData.currentEpoch = newCurrentEpoch;
        
    elseif isempty(newCurrentEpoch) && ~isempty(handles.UserData.currentEpoch)
        
        %in this case, the frame isn't in any epoch now whereas it was in an
        %epoch before
        
        %we'll need to remove the current epoch indicator box
        currentEpochBoxStart = 1; %can be whatever since we're not making it visible
        currentEpochBoxEnd = 1;
        showBox = false;
        redrawBox = true;
        handles.UserData.currentEpoch = newCurrentEpoch;
        
    else
        
        %no change (either in same epoch as before, or not in any epoch new or
        %before
        redrawBox = false;
        
    end
    
    % update the box (or make the box if it hasn't been made yet)
    if redrawBox
        
        if ~isfield(handles.UserData,'currentEpochBox_h') || isempty(handles.UserData.currentEpochBox_h) || ...
                ~isvalid(handles.UserData.currentEpochBox_h)
            
            handles.UserData.currentEpochBox_h = patch(...
                [currentEpochBoxStart currentEpochBoxStart currentEpochBoxEnd currentEpochBoxEnd],...
                [0 1 1 0],'k', 'FaceAlpha',0, 'LineWidth',1.5, 'Visible',showBox);
            
        else
            
            handles.UserData.currentEpochBox_h.XData = ...
                [currentEpochBoxStart currentEpochBoxStart currentEpochBoxEnd currentEpochBoxEnd];
            handles.UserData.currentEpochBox_h.XData = ...
                [currentEpochBoxStart currentEpochBoxStart currentEpochBoxEnd currentEpochBoxEnd];
            handles.UserData.currentEpochBox_h.Visible = showBox;
            
        end
        
    end

end

% draw/move current frame indicator line
if isempty(handles.UserData.epochPositionLine_h) || isempty(handles.UserData.epochPositionLine_h.Parent)
    
    axes(handles.EpochAxes)
    hold on
    handles.UserData.epochPositionLine_h=line(repmat(handles.UserData.currentFrameInd,1,2),...
        [0 1],'color','r');
    hold off
    
else
    handles.UserData.epochPositionLine_h.XData=repmat(handles.UserData.currentFrameInd,1,2);
end

uistack(handles.UserData.epochPositionLine_h,'top') %bring line to top



function handles=changeSelectedMarkers(handles,markerInds)

if ~handles.UserData.dataLoaded
    return
end

% function to change the currently selected markers

handles.UserData.currentMarkerInds=markerInds;

% change which markers are highlighted in list
handles.PointsList.Value=markerInds;

% change the marker tracking options in the GUI to the options of the first 
% selected marker
handles.MarkerTypeSelect.Value=find(strcmpi(handles.UserData.markersInfo(...
    markerInds(1)).trackType,handles.MarkerTypeSelect.String));

handles.UsePredictiveModelCheckBox.Value=handles.UserData.markersInfo(markerInds(1)).usePredModel;
handles.UseKinematicModelCheckBox.Value=handles.UserData.markersInfo(markerInds(1)).useKinModel;
handles.FreezeSegmentCheckBox.Value=handles.UserData.markersInfo(markerInds(1)).freezeSeg;

handles.SearchRadiusInput.String=...
    num2str(handles.UserData.markersInfo(markerInds(1)).searchRadius);

% draw marker cursor and marker box
if handles.UserData.dataInitialized
    handles = drawFrame(handles);
    handles = drawMarkersAndSegments(handles);
end



function [handles, lostMarkerInds]=autoIncrementMarkers(handles)
% if markers are set to be auto tracked, try to get the new marker
% positions by first predicting where they'd be if predictive model was
% enabled (if not it'll just use the previous marker location as the
% prediction), and then running the thresholding/blobbing. If markers
% weren't able to be found, and kinematic model for those markers were
% enabled, try to keep an estimate of where the marke would be based on the
% kinematic model.

% first do autosave
timeInfo=clock;
minsPastMidnight=timeInfo(4)*60+timeInfo(5);
if (minsPastMidnight-handles.UserData.lastSavedTime)>=handles.UserData.autosaveIntervalMin
    MARKERTRACKERGUI_UserData=handles.UserData;
    save('MARKERTRACKER_AutoSave','MARKERTRACKERGUI_UserData')
    disp('autosaving')
    handles.UserData.lastSavedTime=minsPastMidnight;
end

% go through each marker that's set to auto-track
lostMarkerInds=[];
autoTrackedInds = [];
alreadyTrackedMarkers = find(~isnan(handles.UserData.trackedData(:,handles.UserData.currentFrameInd,1)));

% keep track of which markers will have thier data overwritten for the Undo button
oldDataMarkerInds = [];
oldDataFrameInds = {};
oldData = {};
oldBoxSizes = {};

for iMarker=1:handles.UserData.nMarkers
    if strcmpi(handles.UserData.markersInfo(iMarker).trackType,'auto')
        
        %skip if marker is already tracked
        if ~isnan(handles.UserData.trackedData(iMarker,handles.UserData.currentFrameInd,1))
            continue
        end
        
        %let the record show that we are tring to auto track this marker
        autoTrackedInds(end+1) = iMarker;
        
        if handles.UserData.markersInfo(iMarker).usePredModel
            predModelFailed=false; %to keep track of whether the model was ble to predict a new position
            
            %get estimate using predictive model
            if strcmpi(handles.UserData.modelType,'Kalman')
                %need previous frame velocities for Kalman filter
                [prevPos, prevVels]=getPreviousValues(handles);
                
                %inputs are those markers who are specified to use the model
                modelMarkersInds=find([handles.UserData.markersInfo.usePredModel]);
                
                %inputs are all markers other than the current marker
                prevVels=prevVels(setdiff(modelMarkersInds,iMarker),:);
                modelInputs=prevVels';
                modelInputs=modelInputs(:);
                
                %if any points are missing, don't track
                if isnan(prevPos(iMarker,1)) || isnan(any(modelInputs))
                    continue;
                end
                
                %run model
                posEst=TrackerFunctions.predictPosKalman(prevPos(iMarker,:),...
                    handles.UserData.markersInfo(iMarker).modelParams.kalmanFilterObj,...
                    modelInputs);
                %for now for box size, juse use previous
                boxSizeEst=squeeze(handles.UserData.trackedBoxSizes(iMarker,...
                    handles.UserData.currentFrameInd-1,:));
                
            elseif strcmpi(handles.UserData.modelType,'VAR')
                %need previous frame velocities for VAR model
                [prevPos, prevVels]=getPreviousValues(handles);
                
                %inputs use all markers as inputs (including current marker)
                modelInputs=prevVels(modelMarkersInds,:)';
                modelInputs=modelInputs(:);
                
                posEst=TrackerFunctions.predictPosVAR(prevPos(iMarker,:),...
                    handles.UserData.markersInfo(iMarker).modelParams.VARCoeffs,...
                    modelInputs);
                %for now for box size, juse use previous
                boxSizeEst=squeeze(handles.UserData.trackedBoxSizes(iMarker,...
                    handles.UserData.currentFrameInd-1,:));
                
            elseif strcmpi(handles.UserData.modelType,'Spline')
                
                %get previous points of the marker for spline extrapolation
                %(also include extra history for the MA filter)
                prevData=squeeze(handles.UserData.trackedData(iMarker,...
                    (handles.UserData.currentFrameInd-handles.UserData.splineNPoints...
                    -handles.UserData.splineMAOrder+1):...
                    handles.UserData.currentFrameInd-1,:));
                prevBoxSize=squeeze(handles.UserData.trackedBoxSizes(iMarker,...
                    (handles.UserData.currentFrameInd-handles.UserData.splineNPoints...
                    -handles.UserData.splineMAOrder+1):...
                    handles.UserData.currentFrameInd-1,:));
                
                %use estimates if previous data is missing
                prevDataEst=squeeze(handles.UserData.modelEstData(iMarker,...
                    (handles.UserData.currentFrameInd-handles.UserData.splineNPoints...
                    -handles.UserData.splineMAOrder+1):...
                    handles.UserData.currentFrameInd-1,:));
                prevData(isnan(prevData(:,1)),:)=prevDataEst(isnan(prevData(:,1)),:);
                
                prevBoxSizeEst=squeeze(handles.UserData.modelEstBoxSizes(iMarker,...
                    (handles.UserData.currentFrameInd-handles.UserData.splineNPoints...
                    -handles.UserData.splineMAOrder+1):...
                    handles.UserData.currentFrameInd-1,:));
                prevBoxSize(isnan(prevBoxSize(:,1)),:)=prevBoxSizeEst(isnan(prevBoxSize(:,1)),:);
                
                posEst=TrackerFunctions.predictPosSpline(prevData,...
                    handles.UserData.splineMAOrder);
                %for now for box size, just use previous or previous est
                prevBoxSizeInd=max(find(~isnan(prevBoxSize(:,1))));
                boxSizeEst=prevBoxSize(prevBoxSizeInd,:);
                
                % show/plot the predicted locations if the user so desires
                if handles.GUIOptions.plotPredLocs
                    axes(handles.FrameAxes)
                    hold on
                    plot(posEst(1)-handles.UserData.zoomRect(1)-1,posEst(2)-handles.UserData.zoomRect(2)-1,'*y','markersize',10)
                    hold off
                end
            end
            
        else
            %no predictive model, just use previous position
            posEst=squeeze(handles.UserData.trackedData(iMarker,...
                handles.UserData.currentFrameInd-1,:));
            boxSizeEst=squeeze(handles.UserData.trackedBoxSizes(iMarker,...
                handles.UserData.currentFrameInd-1,:));
        end
        
        %if wasn't able to estimate new position, just use previous
        %position
        if isnan(posEst(1))
            predModelFailed=true;
            posEst=squeeze(handles.UserData.trackedData(iMarker,...
                handles.UserData.currentFrameInd-1,:));
            boxSizeEst=squeeze(handles.UserData.trackedBoxSizes(iMarker,...
                handles.UserData.currentFrameInd-1,:));
            
            %if previous point wasn't tracked, then use the estimate
            if isnan(posEst(1))
                posEst=squeeze(handles.UserData.modelEstData(iMarker,...
                    handles.UserData.currentFrameInd-1,:));
                boxSizeEst=squeeze(handles.UserData.modelEstBoxSizes(iMarker,...
                handles.UserData.currentFrameInd-1,:));
            end
            
            %if no estimate, nothing we can do, just don't track
            if isnan(posEst(1))
                continue
            end
        end
            
        %set guess
        handles.UserData.markersInfo(iMarker).guessLocation=posEst;
        handles.UserData.markersInfo(iMarker).guessSize=boxSizeEst;

        % find the actual marker location using the selected point as estimate
        markerProperties=handles.UserData.markersInfo(iMarker).searchProperties;
        markerProperties.contrastEnhancementLevel=handles.UserData.contrastEnhancementLevel;
        markerProperties.trackType=handles.UserData.markersInfo(iMarker).trackType;
        [markerPos, boxSize]=TrackerFunctions.findMarkerPosInFrame(handles.UserData.currentFrame,...
            handles.UserData.channelNames,...
            handles.UserData.markersInfo(iMarker).guessSize,...
            markerProperties,...
            handles.UserData.markersInfo(iMarker).guessLocation,...
            handles.UserData.markersInfo(iMarker).searchRadius,...
            handles.UserData.minConvex);
        
        % save marker location to data array
        % first save overwritten data to backup for Undo button
        oldDataMarkerInds(end+1) = iMarker;
        oldDataFrameInds(end+1) = {handles.UserData.currentFrameInd};
        oldData(end+1) = {handles.UserData.trackedData(...
            iMarker,handles.UserData.currentFrameInd,:)};
        oldBoxSizes(end+1) =  {handles.UserData.trackedBoxSizes(...
            iMarker,handles.UserData.currentFrameInd,:)};

        handles.UserData.trackedData(...
            iMarker,handles.UserData.currentFrameInd,:)=markerPos;
        handles.UserData.trackedBoxSizes(...
            iMarker,handles.UserData.currentFrameInd,:)=boxSize;
        
        if (handles.UserData.markersInfo(iMarker).usePredModel)
            if isnan(markerPos)
                %save the prediction to the estimate data array if it wasn't found
                %and only if the model was able to get a prediction
                if ~predModelFailed
                    handles.UserData.modelEstData(...
                        iMarker,handles.UserData.currentFrameInd,:)=posEst;
                    handles.UserData.modelEstBoxSizes(...
                        iMarker,handles.UserData.currentFrameInd,:)=boxSizeEst;
                end
            elseif strcmpi(handles.UserData.modelType,'Kalman')
                %if it was found, update Kalman filter with new data
                handles.UserData.markersInfo(iMarker).modelParams.kalmanFilterObj=...
                    correct(handles.UserData.markersInfo(iMarker).modelParams.kalmanFilterObj,...
                    markerPos-prevPos(iMarker,:));
            end
        end
                
    end    
end

% remove any markers that have moved too far away from the kinematic model
% get the found markers
markerLocs=squeeze(handles.UserData.trackedData(:,handles.UserData.currentFrameInd,:));
trackedLocs=markerLocs(autoTrackedInds,:);
trackedNames=string({handles.UserData.markersInfo(autoTrackedInds).name})';

if handles.UserData.kinModelTrained
    
    %now, get the indices in the pairings that have tracked data
    [trackedPairInds,inputIndMarkerInds]=TrackerFunctions.determinePairings(trackedNames,...
        [],{},[handles.UserData.kinModel.anchorNames1; handles.UserData.kinModel.anchorNames2]);
    
    %get lengths from the model and calculate limits
    trackedLengths=handles.UserData.kinModel.trainingDataLengths(:,trackedPairInds);
    lengthLimits=max(trackedLengths)*handles.UserData.lengthOutlierMult;
    
    %calculate lengths in current frame
    firstMarkerInputData=trackedLocs(inputIndMarkerInds(1,:),:);
    secondMarkerInputData=trackedLocs(inputIndMarkerInds(2,:),:);
    [~,currentLengths]=TrackerFunctions.calcAngleAndLengths(...
        firstMarkerInputData,secondMarkerInputData);

    %compare
    excededLengthPairs=currentLengths>lengthLimits';
    
    %those markers that have exceded in two or more pairs will be removed
    badMarkers=inputIndMarkerInds(:,excededLengthPairs);
    badMarkers=badMarkers(:);
    for iMarker=1:length(autoTrackedInds)
        if sum(badMarkers==iMarker)>=2
            handles.UserData.trackedData(autoTrackedInds(iMarker),handles.UserData.currentFrameInd,:)=nan;
            handles.UserData.trackedBoxSizes(autoTrackedInds(iMarker),handles.UserData.currentFrameInd,:)=nan;
            
            %remove these from the backup
            removeInds = find(autoTrackedInds(iMarker) == oldDataMarkerInds);
            oldData(removeInds) = [];
            oldBoxSizes(removeInds) = [];
            oldDataFrameInds(removeInds) = [];
            oldDataMarkerInds(removeInds) = [];
            
        end
    end
    
end

% remove any makers that made large sudden jumps
% calculate jump distance
trackedJumps=reshape(diff(handles.UserData.trackedData(...
    autoTrackedInds,handles.UserData.currentFrameInd-1:handles.UserData.currentFrameInd,:),1,2),...
    length(autoTrackedInds),2);
trackedJumps=sqrt(trackedJumps(:,1).^2+trackedJumps(:,2).^2);

% get all previous jump distances
prevTrackedJumps=diff(handles.UserData.trackedData(...
    autoTrackedInds,1:handles.UserData.currentFrameInd-1,:),1,2);
prevTrackedJumps=reshape(sqrt(prevTrackedJumps(:,:,1).^2+prevTrackedJumps(:,:,2).^2),...
    size(prevTrackedJumps,1),size(prevTrackedJumps,2));

% get tracked markers that exceed the jump limit
badMarkers=find(trackedJumps>max(prevTrackedJumps,[],2)*handles.UserData.maxJumpMult);

% remove those markers
if ~isempty(badMarkers)
    handles.UserData.trackedData(autoTrackedInds(badMarkers),handles.UserData.currentFrameInd,:)=nan;
    handles.UserData.trackedBoxSizes(autoTrackedInds(badMarkers),handles.UserData.currentFrameInd,:)=nan;
    
    %remove these from the backup
    [~, removeInds, ~] = intersect(oldDataMarkerInds, autoTrackedInds(badMarkers));
    oldData(removeInds) = [];
    oldBoxSizes(removeInds) = [];
    oldDataFrameInds(removeInds) = [];
    oldDataMarkerInds(removeInds) = [];
end

%now after all the markers have been updated, first check if there were any
%markers that were jumped to the wrong joint, and if so, remove that point

%check if two markers are within some threshold of each other

%find the distances between the tracked markers and check against the
%threshold
nOverlaps=0;
overlaps=[];

allTrackedInds = find(~isnan(handles.UserData.trackedData(:,handles.UserData.currentFrameInd,1)));
allTrackedLocs = handles.UserData.trackedData(allTrackedInds,handles.UserData.currentFrameInd,:);
allTrackedLocs = reshape(allTrackedLocs, [length(allTrackedInds), 2]);
removedOverlapMarkers = [];

for iMark1=1:size(allTrackedLocs,1)
    
    %find and threshold distances between each of the tracked positions
    for iMark2=(iMark1+1):size(allTrackedLocs,1)
        dist=norm([allTrackedLocs(iMark1,:)-allTrackedLocs(iMark2,:)]);
        if dist<handles.UserData.minMarkerDist
            nOverlaps=nOverlaps+1;
            overlaps(nOverlaps,:)=[iMark1,iMark2];
        end
    end
end

%if there's overlap, the marker that was closest to the the current position
%in the previous frame is considered the correct actual marker
if nOverlaps>0
    
    %get previous tracked locations or model estimate locations
    prevMarkerLocs=squeeze(handles.UserData.trackedData(:,handles.UserData.currentFrameInd-1,:));
    prevMarkerLocsEsts=squeeze(handles.UserData.modelEstData(:,handles.UserData.currentFrameInd-1,:));
    
    prevMarkerLocs(isnan(prevMarkerLocs(:,1)),:)=prevMarkerLocsEsts(isnan(prevMarkerLocs(:,1)),:);
    if any(isnan(prevMarkerLocs(autoTrackedInds,1)))
        warning('No previous maker location or estimate for an auto tracked markers, debug here!')
    end
    
    %go through each overlapping pair
    for iOverlap=1:nOverlaps
        
        %if both the markers were already tracked, then don't do any
        %deletion
        if any(allTrackedInds(overlaps(iOverlap,1))==alreadyTrackedMarkers) &&...
            any(allTrackedInds(overlaps(iOverlap,2))==alreadyTrackedMarkers)
            %don't delete
            removeInds=[];
            continue
            
        elseif any(allTrackedInds(overlaps(iOverlap,1))==alreadyTrackedMarkers)
            %delete second one
            handles.UserData.trackedData(allTrackedInds(overlaps(iOverlap,2)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            handles.UserData.trackedBoxSizes(allTrackedInds(overlaps(iOverlap,2)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            
            removedOverlapMarkers(end+1) = allTrackedInds(overlaps(iOverlap,2));
            
        elseif any(allTrackedInds(overlaps(iOverlap,2))==alreadyTrackedMarkers)
            %delete first one
            handles.UserData.trackedData(allTrackedInds(overlaps(iOverlap,1)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            handles.UserData.trackedBoxSizes(allTrackedInds(overlaps(iOverlap,1)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            
            removedOverlapMarkers(end+1) = allTrackedInds(overlaps(iOverlap,1));
                        
        else
            %delete the further one from the average of the two overlapping
            %locations
            
            prevPos1=prevMarkerLocs(allTrackedInds(overlaps(iOverlap,1)),:);
            prevPos2=prevMarkerLocs(allTrackedInds(overlaps(iOverlap,2)),:);
            avePos=(allTrackedLocs(overlaps(iOverlap,1),:)+allTrackedLocs(overlaps(iOverlap,2),:))/2;
            
            if norm([prevPos1 - avePos]) > norm([prevPos2 - avePos])
                %previous location of 1 is futher away, remove 1
                handles.UserData.trackedData(allTrackedInds(overlaps(iOverlap,1)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
                handles.UserData.trackedBoxSizes(allTrackedInds(overlaps(iOverlap,1)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
                
                removedOverlapMarkers(end+1) = allTrackedInds(overlaps(iOverlap,1));
                
            else
                %otherwise, remove 2
                handles.UserData.trackedData(allTrackedInds(overlaps(iOverlap,2)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
                handles.UserData.trackedBoxSizes(allTrackedInds(overlaps(iOverlap,2)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
                
                removedOverlapMarkers(end+1) = allTrackedInds(overlaps(iOverlap,2));
                
            end
        end
        
    end
     
    %also remove these markers from the backup since they're no longer
    %being overwritten
    [~, removeInds, ~] = intersect(oldDataMarkerInds, removedOverlapMarkers);
    oldData(removeInds) = [];
    oldBoxSizes(removeInds) = [];
    oldDataFrameInds(removeInds) = [];
    oldDataMarkerInds(removeInds) = [];
    
end
    
%let user know via GUI message if any markers were removed due to large
%jumps or overlaps
removedJumpMarkers = join(string({handles.UserData.markersInfo(autoTrackedInds(badMarkers)).name}), ', ');

removedOverlapMarkers = join(string(...
    {handles.UserData.markersInfo(removedOverlapMarkers).name}), ', ');

if ~isempty(removedJumpMarkers) 
    
    removedMarkersMesg = ['Markers removed due to large jump: ' removedJumpMarkers{1}];
    
    if ~isempty(removedOverlapMarkers)
        removedMarkersMesg = [removedMarkersMesg ', Markers removed due to overlap: ' removedOverlapMarkers{1}...
            ' in Frame ' num2str(handles.UserData.currentFrameInd)];
    end
        
    handles = displayMessage(handles, removedMarkersMesg, [1 0 0]);

elseif ~isempty(removedOverlapMarkers)
    
    removedMarkersMesg = ['Markers removed due to overlap: ' removedOverlapMarkers{1}...
        ' in Frame ' num2str(handles.UserData.currentFrameInd)];
    
    handles = displayMessage(handles, removedMarkersMesg, [1 0 0]);
    
end



% if there were any markers that were missing, try to get an estimate of
% where it's supposed to be using the available tracked joints and a kNN
% model that was trained.
markerEstNames=string([]);
markerEstInds=[];
for iMarker=1:handles.UserData.nMarkers
    if strcmpi(handles.UserData.markersInfo(iMarker).trackType,'auto') &&... %Marker is auto tracked
            handles.UserData.markersInfo(iMarker).useKinModel &&... %User set to use kinematic model
            isnan(handles.UserData.trackedData(iMarker,handles.UserData.currentFrameInd,1)) &&... %marker wasn't already found
            any(handles.UserData.markersInfo(iMarker).name==...
            [handles.UserData.kinModel.anchorNames1 handles.UserData.kinModel.anchorNames2]) %marker is part of the kinematic model
        
        markerEstNames(end+1)=handles.UserData.markersInfo(iMarker).name;
        markerEstInds(end+1)=iMarker;
        
    end
end

%only run model if there are markers that need estimates and if the model
%has been trained
if ~isempty(markerEstInds) && handles.UserData.kinModelTrained
    
    %determine which markers have data
    markerNames=string({handles.UserData.markersInfo.name})';
    trackedMarkerInds=~isnan(handles.UserData.trackedData(:,handles.UserData.currentFrameInd,1));
    trackedNames=markerNames(trackedMarkerInds);
    trackedData=squeeze(handles.UserData.trackedData(trackedMarkerInds,handles.UserData.currentFrameInd,:));
    if size(trackedData,2)~=2 
        %when there's only 1 tracked marker, squeeze turns into a column
        %vector rather than a row vector, so transpose it
        trackedData=trackedData';
    end
    
    %go through external files as well
    externNames={};
    externData={};
    for iExtern=1:handles.UserData.kinModel.nExterns
        
        %get markers that have tracked data at current frame
        externTrackedMarkerInds=~isnan(handles.UserData.kinModel.externData{iExtern}(...
            :,handles.UserData.currentFrameInd,1));
        
        %get names of tracked data at this frame
        externNames{iExtern}=handles.UserData.kinModel.externMarkerNames{iExtern}(externTrackedMarkerInds);
        %get tracked data at this frame
        externData{iExtern}=squeeze(handles.UserData.kinModel.externData{iExtern}(...
            externTrackedMarkerInds,handles.UserData.currentFrameInd,:));
        if size(externData{iExtern},2)~=2
            %when there's only 1 tracked marker, squeeze turns into a column
            %vector rather than a row vector, so transpose it
            externData{iExtern}=externData{iExtern}';
        end
        
    end
    
    %concatenate all names and data from current session and external files
    allTrackedNames=[trackedNames; cat(1,externNames{:})];
    allTrackedData=[trackedData; cat(1,externData{:})];
    
    %now, get the indices in the pairings to use for input and output of
    %the kinematic model
    [inputInds,inputIndMarkerInds,outputInds,outputAnchorInds]=TrackerFunctions.determinePairings(...
        allTrackedNames,markerEstNames,{handles.UserData.markersInfo(markerEstInds).kinModelAnchors},...
        [handles.UserData.kinModel.anchorNames1; handles.UserData.kinModel.anchorNames2]);
    
    if ~isempty(inputInds) && ~any(any(isnan(outputInds)))
        %if no inputs available for the kNN, don't bother using the model
        
        %use the input inds to get the data needed for the input of the kNN
        firstMarkerInputData=allTrackedData(inputIndMarkerInds(1,:),:);
        secondMarkerInputData=allTrackedData(inputIndMarkerInds(2,:),:);
        [inputAngles,inputLengths]=TrackerFunctions.calcAngleAndLengths(...
            firstMarkerInputData,secondMarkerInputData);
        inputData=[inputAngles inputLengths]';
        
        %get the anchor postions
        anchorPositions=allTrackedData(outputAnchorInds,:);
        
        %use model to estimate desired markers
        markerEsts=TrackerFunctions.kinModelEstPositions(inputData,anchorPositions,inputInds,...
            cat(3,handles.UserData.kinModel.trainingDataAngles, handles.UserData.kinModel.trainingDataLengths),...
            outputInds,handles.UserData.kinModel.minInputs,handles.UserData.kinModel.classifierK,...
            [handles.UserData.markersInfo(markerEstInds).kinModelAngleTol]);
        
        
        for iMarker=1:length(markerEstInds)
            %save the model estimates to the estimate data array
            handles.UserData.modelEstData(...
                markerEstInds(iMarker),handles.UserData.currentFrameInd,:)=...
                markerEsts(iMarker,:);
            %for box sizes, just use closest available box size for now
            ind=max(find(~isnan(handles.UserData.trackedBoxSizes(markerEstInds(iMarker),:,1))));
            handles.UserData.modelEstBoxSizes(...
                markerEstInds(iMarker),handles.UserData.currentFrameInd,:)=...
                handles.UserData.trackedBoxSizes(markerEstInds(iMarker),ind,:);
            
            
        end
    end
    
end

% finally do one last check that all markers have been tracked or estimated
for iMarker=1:handles.UserData.nMarkers
    if strcmpi(handles.UserData.markersInfo(iMarker).trackType,'auto') &&...
            isnan(handles.UserData.trackedData(iMarker,handles.UserData.currentFrameInd,1)) &&...
            isnan(handles.UserData.modelEstData(iMarker,handles.UserData.currentFrameInd,1))
        
        lostMarkerInds(end+1)=iMarker;
        
    end
end

% save the overwritten data to handles
if ~isempty(oldDataMarkerInds)
    handles.UserData.dataBackup.markerInds = oldDataMarkerInds;
    handles.UserData.dataBackup.frameInds = oldDataFrameInds;
    handles.UserData.dataBackup.trackedData = oldData;
    handles.UserData.dataBackup.boxSizes = oldBoxSizes;
end



function handles=markerLostCallback(lostMarkerInds,handles)

% stop autorun
if handles.UserData.lostMarkerStopAutorun
    setappdata(handles.figure1,'autorunEnabled',false);
end

%let user know via GUI message
lostMarkerNames = string({handles.UserData.markersInfo(lostMarkerInds).name});
handles = displayMessage(handles, ['Markers Lost: ' char(join(lostMarkerNames,', ')) ...
    ' in Frame ' num2str(handles.UserData.currentFrameInd)], [1 0 0]);



function [prevPos, prevVels]=getPreviousValues(handles)

% get the tracked and estimated position points from the previous frame
prevPos1=squeeze(handles.UserData.trackedData(:,...
    handles.UserData.currentFrameInd-1,:));
prevPosEst=squeeze(handles.UserData.modelEstData(:,...
    handles.UserData.currentFrameInd-1,:));
% replace any missing points with estimated ones
prevPos1(isnan(prevPos1(:,1)),:)=prevPosEst(isnan(prevPos1(:,1)),:);

% do the same except for two frames in the past (to find previous velocity)
prevPos2=squeeze(handles.UserData.trackedData(:,...
    handles.UserData.currentFrameInd-2,:));
prevPosEst2=squeeze(handles.UserData.modelEstData(:,...
    handles.UserData.currentFrameInd-2,:));

prevPos2(isnan(prevPos2(:,1)),:)=prevPosEst2(isnan(prevPos2(:,1)),:);

prevPos=prevPos1;
prevVels=prevPos1-prevPos2;



% perform interpolation on a range of data
function [handles success] = doInterpolation(handles, interpType)

%checks
success = true;
if handles.UserData.deleteRange(2)<handles.UserData.deleteRange(1)
    warndlg('Delete range must be increasing!');
    success = false;
    return;
elseif (handles.UserData.deleteRange(1)<1)
    warndlg('Starting frame # must be 1 or greater!');
    success = false;
    return;
elseif (handles.UserData.deleteRange(2)>handles.UserData.nFrames)
    warndlg(['Ending frame # must be ' num2str(handles.UserData.nFrames) ' or less!']);
    success = false;
    return;
elseif any(round(handles.UserData.deleteRange)~=handles.UserData.deleteRange)
    warndlg('Frame numbers must be intergers!')
    success = false;
    return;
end
    
% get the data in that range
frameRange = handles.UserData.deleteRange(1):handles.UserData.deleteRange(2);
markerData = handles.UserData.trackedData(handles.UserData.currentMarkerInds(1),frameRange,:);

markerData = reshape(permute(markerData,[3,2,1]), 2, size(markerData,2));

% get the data that's been tracked
trackedInds = find(~isnan(markerData(1,:)));
trackedData = markerData(:,trackedInds);

% the frames that we want to interpolate
untrackedInds = find(isnan(markerData(1,:)));

% if there are no tracked frames, or no missing frames, don't need to do
% anything
if isempty(trackedInds) || isempty(untrackedInds)
    success = false;
    return;
end

% save backup of overwrittendata for Undo button
handles.UserData.dataBackup.trackedData = {handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1), frameRange(untrackedInds), :)};
handles.UserData.dataBackup.boxSizes = {handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1), frameRange(untrackedInds), :)};
handles.UserData.dataBackup.markerInds = handles.UserData.currentMarkerInds(1);
handles.UserData.dataBackup.frameInds = {frameRange(untrackedInds)};

% do interpolation
for iDim = 1 : 2
    interpData = interp1(trackedInds, trackedData(iDim,:), untrackedInds, interpType);
    handles.UserData.trackedData(handles.UserData.currentMarkerInds(1),...
        frameRange(untrackedInds), iDim) = interpData;
end

% set box size to just be the same box size as the first tracked data point
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1), frameRange(untrackedInds), :) = repmat(...
    handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1), frameRange(trackedInds(1)), :), 1, ...
    length(untrackedInds), 1);



% find how many datapoints are in an area for specific markers, and delete
function [handles, pointsDeleted] = deleteMarkersInArea(handles, markerInds)

pointsDeleted = true;

% let user select the area for deletion
areaSelection = getrect(handles.FrameAxes);

%with image, it sets the top and left edge to be 0.5. I want them to be 1
%(since Matlab index by 1)
areaSelection(1:2) = areaSelection(1:2) + 0.5; 

% now if already zoomed in, then convert to rect of original frame
if ~isnan(handles.UserData.zoomRect)

    zoomRect = handles.UserData.zoomRect;
    areaSelection(1:2) = areaSelection(1:2) + zoomRect(1:2) - 1; %-1 since index start at 1

end

% convert to x/y bounds rather than height/width
areaSelection(3) = areaSelection(1) + areaSelection(3);
areaSelection(4) = areaSelection(2) + areaSelection(4);

% now go through each marker and see how many points are inside the
% selection
msg = 'The following number of points will be deleted: \n';
for iMarker = 1 : length(markerInds)
    
    foundInds{iMarker} = find( handles.UserData.trackedData(markerInds(iMarker),:,1) >= areaSelection(1) & ...
                               handles.UserData.trackedData(markerInds(iMarker),:,1) <= areaSelection(3) & ...
                               handles.UserData.trackedData(markerInds(iMarker),:,2) >= areaSelection(2) & ...
                               handles.UserData.trackedData(markerInds(iMarker),:,2) <= areaSelection(4) );
                           
	%if there are any points being deleted, add to msg telling the user
	if ~isempty(foundInds{iMarker})
        msg = [ msg handles.UserData.markersInfo(markerInds(iMarker)).name ' : ' ...
            num2str(length(foundInds{iMarker})) ' points \n' ];
    end
        
end

% if no points were found at all, don't need to do anything
if all(cellfun(@isempty, foundInds))
    handles = displayMessage(handles, 'No markers in Area', [1 0 0]);
    pointsDeleted = false;
    return
end

% if there were points, warn user before deleting
response = questdlg(sprintf(msg), 'Delete Confirmation', 'Yes', 'No', 'No');

if strcmp(response, 'Yes')
    
    %for saving backup of deleted data for Undo button
    oldData = {};
    oldBoxSizes = {};
    oldDataMarkerInds = [];
    oldDataMarkerFrames = {};
    
    %delete the points (set them to nan)
    for iMarker = 1 : length(markerInds)
        
        %first add backup of deleted data for Undo button
        oldData{end+1} = handles.UserData.trackedData(markerInds(iMarker),foundInds{iMarker},:);
        oldBoxSizes{end+1} = handles.UserData.trackedBoxSizes(markerInds(iMarker),foundInds{iMarker},:);
        oldDataMarkerInds(end+1) = markerInds(iMarker);
        oldDataMarkerFrames{end+1} = foundInds{iMarker};
        
        handles.UserData.trackedData(markerInds(iMarker),foundInds{iMarker},:) = NaN;
        handles.UserData.modelEstData(markerInds(iMarker),foundInds{iMarker},:) = NaN;
        handles.UserData.trackedBoxSizes(markerInds(iMarker),foundInds{iMarker},:) = NaN;
        handles.UserData.modelEstBoxSizes(markerInds(iMarker),foundInds{iMarker},:) = NaN;
        
    end
    
    %save to backup data to UserData
    handles.UserData.dataBackup.trackedData = oldData;
    handles.UserData.dataBackup.boxSizes = oldBoxSizes;
    handles.UserData.dataBackup.markerInds = oldDataMarkerInds;
    handles.UserData.dataBackup.frameInds = oldDataMarkerFrames;
    
else
    
    pointsDeleted
    return
    
end


function handles = setFreezePos(handles, relativeFrame)
% function to set the marker position estimate based on the angle and
% distance to an anchor point for the currently selected marker

% no anchor defined for currently selected marker
currentMarkerInd = handles.UserData.currentMarkerInds(1);
anchorInd = handles.UserData.markersInfo(currentMarkerInd).freezeSegAnchor;
if isempty(anchorInd)
    return
end

% get the data or the est data for the selected marker and the anchor
% marker from the relative frame
anchorFrame = handles.UserData.currentFrameInd - relativeFrame;
prevSelectedMarkerData = handles.UserData.trackedData(currentMarkerInd, anchorFrame, :);
if any(isnan(prevSelectedMarkerData))
    %get est data since marker isn't tracked
    prevSelectedMarkerData = handles.UserData.modelEstData(currentMarkerInd, anchorFrame, :);
end

% same for anchor marker
prevAnchorMarkerData = handles.UserData.trackedData(anchorInd, anchorFrame, :);
if any(isnan(prevAnchorMarkerData))
    %get est data since marker isn't tracked
    prevAnchorMarkerData = handles.UserData.modelEstData(anchorInd, anchorFrame, :);
end

% if either the selected or anchor marker doesn't have data or estimate in
% the relative frame, then can't freeze segment
if any(isnan(prevAnchorMarkerData)) || any(isnan(prevSelectedMarkerData))
    return
end

% get the current data of the anchor point (or the estimate)
currentAnchorData =  handles.UserData.trackedData(anchorInd, handles.UserData.currentFrameInd, :);
if any(isnan(currentAnchorData))
    %get est data since marker isn't tracked
    currentAnchorData = handles.UserData.modelEstData(anchorInd, handles.UserData.currentFrameInd, :);
end

% if anchor point doesn't have any data or estimate in the current frame,
% then we also can't freeze segment
if any(isnan(currentAnchorData))
    return
end

% calculate the offset between the anchor and selected marker in the anchor
% frame
offset = prevSelectedMarkerData - prevAnchorMarkerData;

% set the current selected marker's estimate to the same offset
handles.UserData.modelEstData(currentMarkerInd, handles.UserData.currentFrameInd, :) = ...
    currentAnchorData + offset;




% --- Outputs from this function are returned to the command line.
function varargout = MarkerTracker_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



% --- Executes on slider movement.
function FrameSlider_Callback(hObject, eventdata, handles)
% hObject    handle to FrameSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

pause(0.01)

handles=guidata(hObject);

value=round(get(hObject,'Value'));

if handles.UserData.videoLoaded
    handles=changeFrame(handles,value,true);
end

guidata(hObject, handles);



% --- Executes during object creation, after setting all properties.
function FrameSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FrameSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
set(hObject,'SliderStep',[0.001 0.01])



% --- Executes on selection change in PointsList.
function PointsList_Callback(hObject, eventdata, handles)
% hObject    handle to PointsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns PointsList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from PointsList
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return
end

selectedMarkerInds=get(hObject,'Value');
handles=changeSelectedMarkers(handles,selectedMarkerInds);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function PointsList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PointsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function FrameNumberBox_Callback(hObject, eventdata, handles)
% hObject    handle to FrameNumberBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FrameNumberBox as text
%        str2double(get(hObject,'String')) returns contents of FrameNumberBox as a double
handles=guidata(hObject);
if (~handles.UserData.videoLoaded)
    return;
end

value=str2double(get(hObject,'String'));
if isnan(value) || value<=0 || value>handles.UserData.nFrames
    warndlg(['Frame must be a number between 0 and ' num2str(handles.UserData.nFrames)]);
    hObject.String = num2str(handles.UserData.currentFrameInd);
else
    if handles.UserData.videoLoaded
        handles=changeFrame(handles,value,true);
    end
end

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function FrameNumberBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FrameNumberBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in LoadVidButton.
function LoadVidButton_Callback(hObject, eventdata, handles)
% hObject    handle to LoadVidButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Open dialog to select video file
[file,path] = uigetfile({'*.avi';'*.mp4'});

if file==0
    return;
end

% make video reader
handles.UserData.videoFile=fullfile(path,file);
try
    handles.UserData.videoReader=VideoReader(handles.UserData.videoFile);
catch
    warndlg('Unable to load video!')
    return;
end
handles.UserData.nFrames=round(handles.UserData.videoReader.Duration*handles.UserData.videoReader.FrameRate);
handles.UserData.frameRate=handles.UserData.videoReader.frameRate;
handles.UserData.frameSize=[handles.UserData.videoReader.Width handles.UserData.videoReader.Height];

% update gui
handles=updateVidDisplayInfo(handles);

% make frame buffer
% handles.UserData.frameBuffer.data=...
%     repmat({zeros(handles.UserData.videoReader.Height,handles.UserData.videoReader.Width)},...
%     1,handles.UserData.bufferSize);
% handles.UserData.frameBuffer.framesInBuffer=0;
% handles.UserData.frameBuffer.isFull=0;
% handles.UserData.frameBuffer.currentBufferInd=1;
% handles.UserData.frameBuffer.newestFrameInd=1;

% go to first frame
handles.UserData.videoLoaded=true;
handles=changeFrame(handles,1,true);

% initialize tracked data with NaNs if markers are loaded but not
% initailized
if handles.UserData.dataLoaded && ~handles.UserData.dataInitialized
    handles.UserData.trackedData=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
    handles.UserData.trackedBoxSizes=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
    handles.UserData.modelEstData=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
    handles.UserData.modelEstBoxSizes=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
    handles.UserData.dataInitialized=true;
end

% set epochs bar xlims
set(handles.EpochAxes,'xlim',[1 handles.UserData.nFrames]);
set(handles.EpochAxes,'ylim',[0 1]);

guidata(hObject, handles);


% --- Executes on button press in LoadDataButton.
function LoadDataButton_Callback(hObject, eventdata, handles)
% hObject    handle to LoadDataButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Open dialog to select datafile
[file,path,ind] = uigetfile({'*.mat';'*.p'});
if file==0
    return
end

if (ind==1)
    % if matlab file, just load in the data. Could be UserData from a
    % previous tracking session, or just a list of marker names to
    % initialize a new session
    vars=load(fullfile(path,file));
    
    if ~isfield(vars,'MARKERTRACKERGUI_UserData') && ~isfield(vars,'MARKERTRACKERGUI_MarkerNames') ...
            && ~isfield(vars,'MARKERTRACKERGUI_Segments')
        
        warndlg(['.mat file must contain MARKERTRACKERGUI_UserData, ' ...
            'MARKERTRACKERGUI_MarkerNames or MARKERTRACKERGUI_Segments variable!'])
        return;
        
    elseif isfield(vars,'MARKERTRACKERGUI_UserData')
        
        %data from a previous session, just put to UserData and do checks
        % TODO: Checks+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        %in case the save file was using an older version of the tracker,
        %and some UserData fields are missing, set them to the default
        %values here
        requiredFields = fieldnames(handles.UserData);
        addedFields = string();
        for iField = 1:length(requiredFields)
            
            if ~isfield(vars.MARKERTRACKERGUI_UserData, requiredFields{iField})
               
                addedFields(end+1) = requiredFields{iField};
                vars.MARKERTRACKERGUI_UserData.(requiredFields{iField}) = ...
                    handles.UserData.(requiredFields{iField});
                
            end
            
        end
        
        if length(addedFields)>1
            warndlg(sprintf(['Save file was from a previous version, added the following fields to UserData: ',...
                char(join(addedFields,' \r \n '))]))
        end
        
        %add fields to markersinfo
        defaultMarker = setMarkerDefaults({'default'}, 1, handles);
        markerFields = fieldnames(defaultMarker);
        
        addedFields = string();
        for iField = 1:length(markerFields)
            
            if ~isfield(vars.MARKERTRACKERGUI_UserData.markersInfo, markerFields{iField})
               
                addedFields(end+1) = markerFields{iField};
                
                for iMarker = 1:vars.MARKERTRACKERGUI_UserData.nMarkers
                    vars.MARKERTRACKERGUI_UserData.markersInfo(iMarker).(markerFields{iField}) = ...
                        defaultMarker.(markerFields{iField});
                end
                
            end
            
        end
        
        if length(addedFields)>1
            warndlg(sprintf(['Save file was from a previous version, added the following fields to markersInfo: ',...
                char(join(addedFields,' \r \n '))]))
        end
        
        %finally, once everything has been updated, save to UserData
        handles.UserData=vars.MARKERTRACKERGUI_UserData;
        
        %if path to the video file isn't correct (i.e. copied the same file
        %from a different computer), then ask user to select new video file
        try
            handles.UserData.videoReader.NumFrames;
        catch
            [videoPath videoFile] = fileparts(handles.UserData.videoFile);
            warndlg(sprintf('Video file %s not found in %s, please re-select video file', videoFile, videoPath))
            
            [file,path] = uigetfile({'*.avi';'*.mp4'});
            if file==0
                warndlg('Unable to load video!')
                return;
            end
            
            % udpate video reader
            handles.UserData.videoFile=fullfile(path,file);
            try
                handles.UserData.videoReader=VideoReader(handles.UserData.videoFile);
            catch
                warndlg('Unable to load video!')
                return;
            end
            
        end

        %set all the drawing handles (plots, image, patches, ect) to empty
        %since those have been deleted, and will force a redraw of those
        %handles
        handles.UserData.stick_h=[];
        handles.UserData.epochPositionLine_h=[];
        handles.UserData.image_h = [];
        handles.UserData.currentMarkers_h = [];
        handles.UserData.estimatedMarkers_h = [];
        handles.UserData.selection_h = [];
        handles.UserData.markerBoxImage_h = [];
        handles.UserData.markerBoxCenter_h = [];
        handles.UserData.currentEpochBox_h = [];
        
        %update gui with video info
        handles=updateVidDisplayInfo(handles);
        
        %change to the current frame and marker of the session
        loadedFrameInd=handles.UserData.currentFrameInd;
        handles.UserData.currentFrameInd=nan; %so no previous frame checks
        handles=changeFrame(handles,loadedFrameInd,true);
        handles=changeSelectedMarkers(handles,handles.UserData.currentMarkerInds);
        handles=drawEpochBar(handles, true);
        handles.FrameJumpAmountBox.String=num2str(handles.UserData.frameJumpAmount);
        handles.FrameSlider.SliderStep = [1/handles.UserData.nFrames ...
            handles.UserData.frameJumpAmount/handles.UserData.nFrames];
        
        %if for kin models, if defined and/or trained, set background of
        %the buttons to green
        if handles.UserData.kinModelDefined
            handles.DefineModelButton.BackgroundColor='g';
        end
        if handles.UserData.kinModelTrained
            handles.TrainModelButton.BackgroundColor='g';
        end
       
        %set time info
        timeInfo=clock;
        handles.UserData.lastSavedTime=timeInfo(4)*60+timeInfo(5);
        
    elseif isfield(vars,'MARKERTRACKERGUI_MarkerNames')
        
        %not data from previous session, just want to initialize markers
        handles.UserData.nMarkers=length(vars.MARKERTRACKERGUI_MarkerNames);
        
        for iMarker=1:handles.UserData.nMarkers
            
            markers(iMarker) = setMarkerDefaults(vars.MARKERTRACKERGUI_MarkerNames{iMarker}, ...
                iMarker, handles);

        end
        handles.UserData.markersInfo = markers;
        
        %set kin model possible anchors to marker names
        handles.UserData.kinModel.allPossibleAnchors={handles.UserData.markersInfo.name}';
       
        %initialize data arrays (if we know how many frames there are)
        if handles.UserData.videoLoaded
            handles.UserData.trackedData=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.trackedBoxSizes=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.modelEstData=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.modelEstBoxSizes=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.dataInitialized=true;
            
        else
            handles.UserData.dataInitialized=false;
        end
        
        %set kin model possible anchors to marker names
        handles.UserData.kinModel.allPossibleAnchors={handles.UserData.markersInfo.name}';
        
    end
     
    
    %next load in line segments (connecting line markers) if there's any
    if isfield(vars,'MARKERTRACKERGUI_Segments')
        
        %first there has to be markers already defined
        if isfield(handles.UserData, 'markersInfo') == 0 || isempty(handles.UserData.markersInfo)
            handles = displayMessage(handles, 'Cannot load in Segments when there''s no markers defined!',...
                [1 0 0]);
            return
        end
        
        %now load in segments
        %remove old segment definitions
        handles.UserData.segments = [];
        failedSegs = [];
        failedMarkers = string([]);
        for iSeg=1:size(vars.MARKERTRACKERGUI_Segments,1)
            
            segStart = find(strcmp(vars.MARKERTRACKERGUI_Segments{iSeg,1}, ...
                {handles.UserData.markersInfo.name}));
            segEnd = find(strcmp(vars.MARKERTRACKERGUI_Segments{iSeg,2}, ...
                {handles.UserData.markersInfo.name}));
            
            if isempty(segStart)
                %couldn't find the marker, don't add to segments, and warn
                %user
                failedMarkers{end+1} = vars.MARKERTRACKERGUI_Segments{iSeg,1};
                failedSegs(end+1) = iSeg;
            elseif isempty(segEnd)
                failedMarkers{end+1} = vars.MARKERTRACKERGUI_Segments{iSeg,2};
                failedSegs(end+1) = iSeg;
            else
                %found the markers, add segment
                handles.UserData.segments(end+1,:)=[segStart, segEnd];
            end
            
        end
        
        %warn users if segments couldn't be found
        if isempty(failedSegs)
            handles=displayMessage(handles, ...
                [num2str(size(vars.MARKERTRACKERGUI_Segments,1)) ' segments loaded'], [0 0 0]);
        else
            failedMarkers = join(unique(failedMarkers), ', ');
            failedSegs = unique(failedSegs);
            handles=displayMessage(handles, ['Failed to add segments: ' num2str(failedSegs) ...
                ', couldn''t find markers: ' failedMarkers{1}], [1 0 0]);
        end
        
    end
    
    
elseif (ind==2)
    % if simi .p data file
    
    %get list of defined marker names (if we've already loaded them in)
    if isempty(handles.UserData.markersInfo)
        myMarkerNames=[];
    else
        myMarkerNames=string({handles.UserData.markersInfo.name});
    end
    
    %read data
    filename=fullfile(path,file);
    [~,fileMarkerNames,~,myMarkerInds,myMarkerIndsWithData,fileData]=TrackerFunctions.readPFile(myMarkerNames,filename);

    %now in the case were we didnt have markers already defined, define
    %them now with the markers from the p file
    if isempty(myMarkerNames)
        % fill marker structure to hold info for each joint marker with default
        % values
        for iMarker=1:length(fileMarkerNames)
            
            markers(iMarker) = setMarkerDefaults(fileMarkerNames{iMarker}, ...
                iMarker, handles);

        end
        handles.UserData.markersInfo=markers;
        handles.UserData.nMarkers=length(fileMarkerNames);
        
        %set kin model possible anchors to marker names
        handles.UserData.kinModel.allPossibleAnchors={handles.UserData.markersInfo.name}';
        
        %if there is data from the file, first check to make sure that video is loaded
        if ~handles.UserData.videoLoaded
            warndlg('Video not loaded so data structs not initalized, the data from the p File will be discarded!')
        else
            %check that the loaded data doesn't exceed the number of frames
            %in the video
            if (size(fileData,1)>handles.UserData.nFrames)
                warndlg('More data values in the p file than there are frames in video!')
                return;
            end
            
            %now initailize data arrays
            handles.UserData.trackedData=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.trackedBoxSizes=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.modelEstData=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.modelEstBoxSizes=NaN(handles.UserData.nMarkers,handles.UserData.nFrames,2);
            handles.UserData.dataInitialized=true;
            
            %write the data from the file to the data arrays
            handles.UserData.trackedData(1:size(fileData,2)/2,1:size(fileData,1),1)=...
                fileData(:,1:2:end)'*handles.UserData.frameSize(1);
            handles.UserData.trackedData(1:size(fileData,2)/2,1:size(fileData,1),2)=...
                fileData(:,2:2:end)'*handles.UserData.frameSize(2);
            
            %for box sizes, just use default box size
            handles.UserData.trackedBoxSizes(1:size(fileData,2)/2,1:size(fileData,1),:)=...
                repmat(permute(handles.UserData.defaultMarkerSize,[1,3,2]),size(fileData,2)/2,size(fileData,1));
            
        end
        
    else %I already have my markers defined
        
        %get the indices where my markers have corresponding data in the
        %loaded file
        markersInFile=~isnan(myMarkerIndsWithData);
        myMarkerIndsWithData(isnan(myMarkerIndsWithData))=[];
        
        if ~isempty(myMarkerIndsWithData)
            %first save data to be overwritten for Undo button
            handles.UserData.dataBackup.trackedData = mat2cell(...
                handles.UserData.trackedData(markersInFile,1:size(fileData,1),:),...
                ones(1, length(find(markersInFile))), size(fileData,1), 2);
            
            handles.UserData.dataBackup.boxSizes = mat2cell(...
                handles.UserData.trackedBoxSizes(markersInFile,1:size(fileData,1),:),...
                ones(1, length(find(markersInFile))), size(fileData,1), 2);
            
            handles.UserData.dataBackup.markerInds = find(markersInFile);
            handles.UserData.dataBackup.frameInds= repmat({1:size(fileData,1)}, ...
                1, length(find(markersInFile)));
            
            %save the data from the file to the data arrays
            handles.UserData.trackedData(markersInFile,1:size(fileData,1),1)=...
                fileData(:,myMarkerIndsWithData*2-1)'*handles.UserData.frameSize(1)+0.5;
            handles.UserData.trackedData(markersInFile,1:size(fileData,1),2)=...
                fileData(:,myMarkerIndsWithData*2)'*handles.UserData.frameSize(2)+0.5;
            
            %for box sizes, just use default box size
            handles.UserData.trackedBoxSizes(markersInFile,1:size(fileData,1),:)=...
                repmat(permute(handles.UserData.defaultMarkerSize,[1,3,2]),length(find(markersInFile)),size(fileData,1));
            
        end
        
    end
    
    
else
    warndlg('Can only read .mat and .p files!')
    return;
end

handles.UserData.dataLoaded=true;

% initialize makers list
handles.PointsList.String={handles.UserData.markersInfo.name}';

% set marker to first
handles=changeSelectedMarkers(handles,1);

guidata(hObject, handles);




% --- Executes on button press in OpenMarkerPropertiesButton.
function OpenMarkerPropertiesButton_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMarkerPropertiesButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return
end

%set guesspoints (which are the display points for the marker properties
%gui) to the latest avaiable position
data=handles.UserData.trackedData(handles.UserData.currentMarkerInds(1),...
    1:handles.UserData.currentFrameInd,1);
latestTrackedInd=max(find(~isnan(data)));

if isempty(latestTrackedInd)
    % no tracked data, use middle point of the frame
    markerPos=round(handles.UserData.frameSize/2);
    boxSize=handles.UserData.defaultMarkerSize;
else
    markerPos=squeeze(round(handles.UserData.trackedData(handles.UserData.currentMarkerInds(1),...
    latestTrackedInd,:)));
    boxSize=squeeze(round(handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds(1),...
    latestTrackedInd,:)));
end

handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation=markerPos;
handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize=boxSize;
        
% call marker properties gui
handles.UserData=MarkerTracker_PropertiesBox(handles.UserData);

pos=handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:);
boxSize=handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:);

% refind marker with the newly updated proeprties (if marker was tracked
% before
if isnan(pos)
    %marker wasn't tracked before
    guidata(hObject,handles)
    return
end

markerProperties=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties;
markerProperties.contrastEnhancementLevel=handles.UserData.contrastEnhancementLevel;
markerProperties.trackType=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).trackType;
[markerPos, boxSize]=TrackerFunctions.findMarkerPosInFrame(handles.UserData.currentFrame,...
    handles.UserData.channelNames,boxSize,markerProperties,pos,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchRadius,...
    handles.UserData.minConvex);

% add to data array
% first save backup of overwritten data for the Undo button
handles.UserData.dataBackup.markerInds = handles.UserData.currentMarkerInds(1);
handles.UserData.dataBackup.frameInds = {handles.UserData.currentFrameInd};
handles.UserData.dataBackup.trackedData = {handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)};
handles.UserData.dataBackup.boxSizes = {handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)};

handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=markerPos;
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=boxSize;

% redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)



% --- Executes on button press in ImageProcessingButton.
function ImageProcessingButton_Callback(hObject, eventdata, handles)
% hObject    handle to ImageProcessingButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.videoLoaded
    return
end

% call image processing gui
handles.UserData=MarkerTracker_ImageProcessing(handles.UserData);

% apply image processing
handles.UserData.currentFrame=TrackerFunctions.applyImageProcessing(...
    handles.UserData.currentFrameUnprocessed, handles.UserData.globalBrightness,...
    handles.UserData.globalContrast, handles.UserData.globalDecorr, handles.UserData.exclusionMask);

% redraw frame
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles);


% --- Executes on button press in ExportButton.
function ExportButton_Callback(hObject, eventdata, handles)
% hObject    handle to ExportButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% only export if data initalized
if ~handles.UserData.dataInitialized
    return
end

% convert data values from pixel number to fraction of image
% also subtract 0.5 since simi treats pixel corner as 0 where as matlab
% treats it as 0.5
markerData=handles.UserData.trackedData;
markerData(:,:,1)=(markerData(:,:,1)-0.5)/handles.UserData.frameSize(1);
markerData(:,:,2)=(markerData(:,:,2)-0.5)/handles.UserData.frameSize(2);
markerData=permute(markerData,[2 1 3]);

% get names
markerNames=string({handles.UserData.markersInfo.name});
success=TrackerFunctions.writePFile(markerNames, markerData, handles.UserData.frameRate);

if ~success
    warndlg('Error in writing to .p file! Data not exported')
else
    msgbox('Succesfully exported data');
end

guidata(hObject,handles);


% --- Executes on button press in SaveDataButton.
function SaveDataButton_Callback(hObject, eventdata, handles)
% hObject    handle to SaveDataButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

[file, path, indx]=uiputfile('.mat');

if indx~=1
    warndlg('Must save as a .mat file!')
    return
end

MARKERTRACKERGUI_UserData=handles.UserData;
save(fullfile(path,file),'MARKERTRACKERGUI_UserData');

guidata(hObject,handles)



function DeleteStartInput_Callback(hObject, eventdata, handles)
% hObject    handle to DeleteStartInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of DeleteStartInput as text
%        str2double(get(hObject,'String')) returns contents of DeleteStartInput as a double
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return;
end

handles.UserData.deleteRange(1)=str2double(get(hObject,'String'));

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function DeleteStartInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DeleteStartInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function DeleteEndInput_Callback(hObject, eventdata, handles)
% hObject    handle to DeleteEndInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of DeleteEndInput as text
%        str2double(get(hObject,'String')) returns contents of DeleteEndInput as a double
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return;
end

handles.UserData.deleteRange(2)=str2double(get(hObject,'String'));

guidata(hObject,handles)

% --- Executes during object creation, after setting all properties.
function DeleteEndInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DeleteEndInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in MarkerTypeSelect.
function MarkerTypeSelect_Callback(hObject, eventdata, handles)
% hObject    handle to MarkerTypeSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns MarkerTypeSelect contents as cell array
%        contents{get(hObject,'Value')} returns selected item from MarkerTypeSelect
handles=guidata(hObject);

strList = cellstr(get(hObject,'String'));

for iMarker=1:length(handles.UserData.currentMarkerInds)
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(iMarker)).trackType=...
        strList{get(hObject,'Value')};
end

guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function MarkerTypeSelect_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MarkerTypeSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in DeleteRangeButton.
function DeleteRangeButton_Callback(hObject, eventdata, handles)
% hObject    handle to DeleteRangeButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return;
end

%checks
if handles.UserData.deleteRange(2)<handles.UserData.deleteRange(1)
    warndlg('Delete range must be increasing!');
    return;
elseif (handles.UserData.deleteRange(1)<1)
    warndlg('Starting frame # must be 1 or greater!');
    return;
elseif (handles.UserData.deleteRange(2)>handles.UserData.nFrames)
    warndlg(['Ending frame # must be ' num2str(handles.UserData.nFrames) ' or less!']);
    return;
elseif any(round(handles.UserData.deleteRange)~=handles.UserData.deleteRange)
    warndlg('Frame numbers must be intergers!')
    return;
end
    
%delete the points (set them to nan)
% first save backup for Undo button
handles.UserData.dataBackup.trackedData = mat2cell(...
    handles.UserData.trackedData(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:),...
    ones(1, length(handles.UserData.currentMarkerInds)),...
    diff(handles.UserData.deleteRange)+1, 2);
handles.UserData.dataBackup.boxSizes = mat2cell(...
    handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:),...
    ones(1, length(handles.UserData.currentMarkerInds)),...
    diff(handles.UserData.deleteRange)+1, 2);
handles.UserData.dataBackup.markerInds = handles.UserData.currentMarkerInds;
handles.UserData.dataBackup.frameInds = repmat({...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2)}, ...
    1, length(handles.UserData.currentMarkerInds));

handles.UserData.trackedData(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;
handles.UserData.modelEstData(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;
handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;
handles.UserData.modelEstBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;

%redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)


% --- Executes on button press in ModelMovementToggle.
function ModelMovementToggle_Callback(hObject, eventdata, handles)
% hObject    handle to ModelMovementToggle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ModelMovementToggle


% --- Executes on button press in AutorunButton.
function AutorunButton_Callback(hObject, eventdata, handles)
% hObject    handle to AutorunButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Function to automatically scroll through frames and track markers

if ~handles.UserData.dataInitialized
    return
end

disp('clicked autorun button')
% toggle autorun
if getappdata(handles.figure1,'autorunEnabled')
    setappdata(handles.figure1,'autorunEnabled',false);
    disp('autorun stopped')
    hObject.BackgroundColor=[0.9400 0.9400 0.9400];
    return
else
    setappdata(handles.figure1,'autorunEnabled',true);
    disp('autorun started')
    hObject.BackgroundColor='r';
end

frameCounter=0;

%get epochs, or if no epochs defined, just set the epoch to the whole video
if isempty(handles.UserData.epochs)
    epochs = [1 handles.UserData.nFrames];
else
    epochs = handles.UserData.epochs;
end

while getappdata(handles.figure1,'autorunEnabled')
    
    %increment frame (if not end of video or last epoch)
    if handles.UserData.currentFrameInd==handles.UserData.nFrames ||...
        handles.UserData.currentFrameInd==max(epochs(:,2))
        
        setappdata(handles.figure1,'autorunEnabled',false);
        break;
    end
    
    %determine if to update display with new frame or not
    if frameCounter==handles.UserData.autorunDispInterval
        frameCounter=0;
        dispFrame=true;
    else
        frameCounter=frameCounter+1;
        dispFrame=false;
    end
    
    %go to next epoch if at the end of an epoch
    atEpochEnd = find(handles.UserData.currentFrameInd==epochs(:,2),1);
    if ~isempty(atEpochEnd)
        handles=changeFrame(handles, epochs(atEpochEnd+1,1), dispFrame);
    else
        %just go to next frame
        handles=changeFrame(handles,handles.UserData.currentFrameInd+1, dispFrame);
    end
    
    %update markers that are set to 'auto'
    [handles, lostMarkerInds]=autoIncrementMarkers(handles);
    
    %check if any markers were lost
    if ~isempty(lostMarkerInds)
        handles=markerLostCallback(lostMarkerInds,handles);
    end
    
    if dispFrame
        handles=drawMarkersAndSegments(handles);
%         handles=testfunc(handles);
    end
    
    %FOR SOME REASON IF I DON'T PUT A PAUSE HERE OR IF I MAKE THE PAUSE
    %LESS THAN 0.05s THE CALLBACK DOESN'T INTERRUPT AND I CAN'T STOP THE
    %AUTORUN
    pause(0.04)
    guidata(hObject,handles);
    
end

% draw frame an stick figure
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

setappdata(handles.figure1,'autorunEnabled',false);
hObject.BackgroundColor=[0.9400 0.9400 0.9400];

guidata(hObject,handles);



% --- Executes on button press in DeletePointButton.
function DeletePointButton_Callback(hObject, eventdata, handles)
% hObject    handle to DeletePointButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return;
end

%remove point by setting it to NaNs
% first backup overwritten data points for Undo button
handles.UserData.dataBackup.trackedData = mat2cell(...
    handles.UserData.trackedData(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:), ...
    ones(1, length(handles.UserData.currentMarkerInds)), 1, 2);

handles.UserData.dataBackup.boxSizes = mat2cell(...
    handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:), ...
    ones(1, length(handles.UserData.currentMarkerInds)), 1, 2);

handles.UserData.dataBackup.markerInds = handles.UserData.currentMarkerInds;
handles.UserData.dataBackup.frameInds = repmat({handles.UserData.currentFrameInd}, ...
    1, length(handles.UserData.currentMarkerInds));

handles.UserData.trackedData(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;
handles.UserData.modelEstData(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;
handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;
handles.UserData.modelEstBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;

%redraw frame
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)


% --- Executes on button press in UsePredictiveModelCheckBox.
function UsePredictiveModelCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to UsePredictiveModelCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of UsePredictiveModelCheckBox
handles=guidata(hObject);

for iMarker=1:length(handles.UserData.currentMarkerInds)
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(iMarker)).usePredModel=...
        get(hObject,'Value');
end

guidata(hObject,handles);



% --- Executes on button press in TimePlotButton.
function TimePlotButton_Callback(hObject, eventdata, handles)
% hObject    handle to TimePlotButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% make figure
timePlot_h=figure;

% get tracked data
data=squeeze(handles.UserData.trackedData(handles.UserData.currentMarkerInds(1),:,:));
fps=handles.UserData.frameRate;

% plot data with time x-axis (put axis on top)
plot((1:handles.UserData.nFrames)/fps,data(:,1),'.-','markersize',2.5);
timePlotax1=gca;
timePlotax1.XAxisLocation='top';
xlabel('Time (s)')
timePlotax1.YTick=[];

% add another plot with the frame number as x-axis (axis on bottom)
timePlotax2=axes('Position',timePlotax1.Position);
horizontal_h=plot(1:handles.UserData.nFrames,data(:,1),'.-','markersize',2.5);
hold on
vertical_h=plot(1:handles.UserData.nFrames,data(:,2),'.-','markersize',2.5);
xlabel('Frame')
ylabel('Pixel')

legend([horizontal_h, vertical_h],{'Horizontal','Vertical'});

% add line to indicate where in the GUI the current frame is at
locationLine_h=line(repmat(handles.UserData.currentFrameInd,1,2),timePlotax2.YLim,'color','r');

% add listener for alt button press for moving current frame
set(timePlot_h,'WindowKeyPressFcn', {@timePlotKeyPress_Callback,hObject,timePlotax2,locationLine_h});
set(timePlot_h,'WindowKeyReleaseFcn', {@timePlotKeyRelease_Callback,hObject,timePlotax2});

% add listeners so that any zooming or paning updates both time and frame
% axes of the plot
xLimListener = addlistener( timePlotax2, 'XLim', 'PostSet',...
    @(src,evt) timePlotAxisChangedCallback(src,evt,timePlotax1,locationLine_h,fps));
yLimListener = addlistener( timePlotax2, 'YLim', 'PostSet',...
    @(src,evt) timePlotAxisChangedCallback(src,evt,timePlotax1,locationLine_h,fps));



% listener function to lock time and frame axes, and update line
function timePlotAxisChangedCallback(src,evt,timePlotax1,locationLine_h,fps)
    
timePlotax1.XLim=evt.AffectedObject.XLim/fps;
timePlotax1.YLim=evt.AffectedObject.YLim;
locationLine_h.YData=evt.AffectedObject.YLim;



% keypress callback for alt to let user click on plot to move frame to
% clicked location
function timePlotKeyPress_Callback(src,callbackdata,hObject,timePlotax2,locationLine_h)

handles=guidata(hObject);
if ~handles.UserData.videoLoaded
    return
end

if strcmpi(callbackdata.Key,'alt')
    timePlotax2.ButtonDownFcn={@timePlotClick_Callback,locationLine_h,hObject};
end

% keyrelease callback for alt to no longer change frames when user clicks
% if alt isn't pressed
function timePlotKeyRelease_Callback(src,callbackdata,hObject,timePlotax2)

handles=guidata(hObject);
if ~handles.UserData.videoLoaded
    return
end

if strcmpi(callbackdata.Key,'alt')
    timePlotax2.ButtonDownFcn=[];
end

% callback function to change frame to clicked location
function timePlotClick_Callback(hObject, eventdata, locationLine_h, GUI_h)
handles=guidata(GUI_h);

% get the clicked point x pos, will be new frame
frame=round(eventdata.IntersectionPoint(1));
if frame < 1
    frame=1;
elseif frame > handles.UserData.nFrames
    frame=handles.UserData.nFrames;
end

% change frame
handles=changeFrame(handles,frame,true);
locationLine_h.XData=[frame frame];
figure(hObject.Parent)

guidata(GUI_h,handles)



% --- Executes on button press in PositionPlotButton.
function PositionPlotButton_Callback(hObject, eventdata, handles)
% hObject    handle to PositionPlotButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% get tracked data
data=squeeze(handles.UserData.trackedData(handles.UserData.currentMarkerInds(1),:,:));

% plot data
figure;
plot(data(:,1),handles.UserData.frameSize(2)-data(:,2))


% --- Executes on button press in InitializeButton.
function InitializeButton_Callback(hObject, eventdata, handles)
% hObject    handle to InitializeButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return
end

selection=getrect(handles.FrameAxes)+0.5; %add 0.5 since image treats top and left edge as 0.5
if ~isnan(handles.UserData.zoomRect)
    selection(1)=selection(1)+handles.UserData.zoomRect(1)-1;
    selection(2)=selection(2)+handles.UserData.zoomRect(2)-1;
end
handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation=...
    [selection(1)+selection(3)/2, selection(2)+selection(4)/2];

handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize=...
    selection(3:4);

% call marker properties gui
handles.UserData=MarkerTracker_PropertiesBox(handles.UserData);

% find the actual marker location using the selected point as estimate
markerProperties=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties;
markerProperties.contrastEnhancementLevel=handles.UserData.contrastEnhancementLevel;
markerProperties.trackType=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).trackType;
[markerPos, boxSize]=TrackerFunctions.findMarkerPosInFrame(handles.UserData.currentFrame,...
    handles.UserData.channelNames,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize,...
    markerProperties,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchRadius,...
    handles.UserData.minConvex);

% add to data array
% first save backup of overwritten data for Undo button
handles.UserData.dataBackup.markerInds = handles.UserData.currentMarkerInds(1);
handles.UserData.dataBackup.frameInds = {handles.UserData.currentFrameInd};
handles.UserData.dataBackup.trackedData = {handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)};
handles.UserData.dataBackup.boxSizes = {handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)};

handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=markerPos;
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=selection(3:4);
handles.UserData.modelEstBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=selection(3:4);

% redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)

% %Commented out code to do square-only selection
% 
% tmpPoint_h=impoint(handles.FrameAxes);
% selectedInds=getPosition(tmpPoint_h);
% delete(tmpPoint_h);
% 
% axes(handles.FrameAxes)
% hold on
% box_h{5}=plot(selectedInds(1),selectedInds(2),'.y','markersize',10);
% 
% for iEdge=1:4
%     box_h{iEdge}=line('XData',repmat(selectedInds(1),1,2),'YData',repmat(selectedInds(2),1,2),...
%         'LineStyle','--','color','w','LineWidth',0.5);
% end
% 
% set(gcf,'WindowButtonMotionFcn',{@initializeDrawRectCallback,hObject,selectedInds,box_h})
% set(gcf,'WindowButtonUpFcn',{@initializeReleaseRectCallback,hObject,selectedInds,box_h})


% function initializeDrawRectCallback(src,callbackdata,hObject,centerPoint,box_h)
% handles=guidata(hObject);
% cursor = handles.FrameAxes.CurrentPoint;
% Xdist=abs(cursor(1,1)-centerPoint(1));
% Ydist=abs(cursor(1,2)-centerPoint(2));
% 
% boxSize=max([Xdist Ydist]);
% 
% % top edge
% box_h{1}.XData=[centerPoint(1)-boxSize, centerPoint(1)+boxSize];
% box_h{1}.YData=[centerPoint(2)+boxSize, centerPoint(2)+boxSize];
% % right edge
% box_h{2}.XData=[centerPoint(1)+boxSize, centerPoint(1)+boxSize];
% box_h{2}.YData=[centerPoint(2)-boxSize, centerPoint(2)+boxSize];
% % bottom edge
% box_h{3}.XData=[centerPoint(1)-boxSize, centerPoint(1)+boxSize];
% box_h{3}.YData=[centerPoint(2)-boxSize, centerPoint(2)-boxSize];
% % left edge
% box_h{4}.XData=[centerPoint(1)-boxSize, centerPoint(1)-boxSize];
% box_h{4}.YData=[centerPoint(2)-boxSize, centerPoint(2)+boxSize];
% 
% drawnow
% 
% 
% function initializeReleaseRectCallback(src,callbackdata,hObject,centerPoint,box_h)
% handles=guidata(hObject);
% handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation=...
%     centerPoint;
% 
% handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize=...
%     diff(box_h{1}.XData);
% 
% last_seltype = src.SelectionType;
% if strcmp(last_seltype,'alt')
%     for iEdge=1:length(box_h)
%         delete(box_h{iEdge})
%     end
%     src.WindowButtonMotionFcn = '';
%     src.WindowButtonUpFcn = '';
% end
% 
% guidata(hObject,handles);



% --- Executes on button press in ZoomInButton.
function ZoomInButton_Callback(hObject, eventdata, handles)
% hObject    handle to ZoomInButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~handles.UserData.videoLoaded
    return
end

% let user choose window to zoom in on
handles=guidata(hObject);
zoomRect=getrect(handles.FrameAxes);
%with image, it sets the top and left edge to be 0.5. I want them to be 1
%(since Matlab index by 1)
zoomRect(1:2)=zoomRect(1:2)+0.5; 

% now if already zoomed in, then convert to rect of original frame
if ~isnan(handles.UserData.zoomRect)
    oldZoomRect=handles.UserData.zoomRect;
    xScale=oldZoomRect(3)/size(handles.UserData.currentFrame,2);
    yScale=oldZoomRect(4)/size(handles.UserData.currentFrame,1);
    zoomRect(1:2)=round(zoomRect(1:2)+oldZoomRect(1:2))-1; %-1 since index start at 1
    zoomRect(3:4)=round(zoomRect(3:4));
else
    zoomRect=round(zoomRect);
end

% anchor corner has to be within the image (bigger than (1,1))
if zoomRect(1) < 1 || zoomRect(2) < 1
    handles = displayMessage(handles, 'Please select within the frame', [1 0 0]);
    return
end

% also, if the zoom box is outside of frame limits, set them to frame
% limits
if zoomRect(1) + zoomRect(3) > handles.UserData.frameSize(1)
    zoomRect(3) = handles.UserData.frameSize(1) - zoomRect(1);
end
if zoomRect(2) + zoomRect(4) > handles.UserData.frameSize(2)
    zoomRect(4) = handles.UserData.frameSize(2) - zoomRect(2);
end
handles.UserData.zoomRect=zoomRect;

% redraw frame
handles = drawFrame(handles, true);
handles=drawMarkersAndSegments(handles, true);

guidata(hObject,handles);



% --- Executes on button press in ZoomOrigButton.
function ZoomOrigButton_Callback(hObject, eventdata, handles)
% hObject    handle to ZoomOrigButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.UserData.zoomRect=NaN;

handles = drawFrame(handles, true);
handles=drawMarkersAndSegments(handles, true);

guidata(hObject,handles)



function SearchRadiusInput_Callback(hObject, eventdata, handles)
% hObject    handle to SearchRadiusInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of SearchRadiusInput as text
%        str2double(get(hObject,'String')) returns contents of SearchRadiusInput as a double
handles=guidata(hObject);

for iMarker=1:length(handles.UserData.currentMarkerInds)
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(iMarker)).searchRadius=...
        str2double(get(hObject,'String'));
end

guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function SearchRadiusInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to SearchRadiusInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function MarkerAxes_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MarkerAxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
axis off
% Hint: place code in OpeningFcn to populate MarkerAxes



% --- Executes on button press in EpochStartButton.
function EpochStartButton_Callback(hObject, eventdata, handles)
% hObject    handle to EpochStartButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.videoLoaded
    return
end

%see which epoch we're currently in (if we're in one)
if isempty(handles.UserData.epochs)
    inEpoch=[];
else
    inEpoch = find(all(handles.UserData.currentFrameInd>=handles.UserData.epochs(:,1) &...
        handles.UserData.currentFrameInd<=handles.UserData.epochs(:,2),2));
end

%if currently in an epoch, set the start of that epoch to now
if ~isempty(inEpoch)
    handles.UserData.epochs(inEpoch,1)=handles.UserData.currentFrameInd;
else
    %if not in an already defined epoch, make a new one with the start as
    %the current frame and end of the new epoch should be the frame before \
    %the start of the next epoch
    if isempty(handles.UserData.epochs)
        nearestEpoch=[];
    else
        nearestEpoch=min(find(handles.UserData.epochs(:,1)>handles.UserData.currentFrameInd));
    end
    
    %if there is no next epoch, then end is just the last frame of the
    %video
    if isempty(nearestEpoch)
        handles.UserData.epochs(end+1, 2)=handles.UserData.nFrames;
    else
        handles.UserData.epochs(end+1, 2)=handles.UserData.epochs(nearestEpoch,1)-1;
    end
    
    handles.UserData.epochs(end, 1)=handles.UserData.currentFrameInd;
end

%sort to keep it organized
handles.UserData.epochs=sortrows(handles.UserData.epochs);

%replot epoch bar
handles=drawEpochBar(handles, true);

guidata(hObject,handles)



% --- Executes on button press in EpochEndButton.
function EpochEndButton_Callback(hObject, eventdata, handles)
% hObject    handle to EpochEndButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.videoLoaded
    return
end

%see which epoch we're currently in (if we're in one)
if isempty(handles.UserData.epochs)
    inEpoch=[];
else
    inEpoch = find(all(handles.UserData.currentFrameInd>=handles.UserData.epochs(:,1) &...
        handles.UserData.currentFrameInd<=handles.UserData.epochs(:,2),2));
end

%if currently in an epoch, set the end of that epoch to now
if ~isempty(inEpoch)
    handles.UserData.epochs(inEpoch,2)=handles.UserData.currentFrameInd;
else
    %if not in an already defined epoch, make a new one with the end as
    %the current frame
    
    %start of the new epoch should be the frame after the end of the
    %previous epoch
    if isempty(handles.UserData.epochs)
        nearestEpoch=[];
    else
        nearestEpoch=max(find(handles.UserData.epochs(:,2)<handles.UserData.currentFrameInd));
    end
    
    %if there is no next epoch, then end is just the first frame
    if isempty(nearestEpoch)
        handles.UserData.epochs(end+1, 1)=1;
    else
        handles.UserData.epochs(end+1, 1)=handles.UserData.epochs(nearestEpoch,2)+1;
    end
    
    handles.UserData.epochs(end, 2)=handles.UserData.currentFrameInd;
    
end

%sort to keep it organized
handles.UserData.epochs=sortrows(handles.UserData.epochs);

%replot epoch bar
handles=drawEpochBar(handles, true);

guidata(hObject,handles)



% --- Executes on button press in EpochDeleteButton.
function EpochDeleteButton_Callback(hObject, eventdata, handles)
% hObject    handle to EpochDeleteButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if isempty(handles.UserData.epochs)
    return
end

% check to see if we're inside an epoch
currentEpoch=[];
for iEpoch=1:size(handles.UserData.epochs,1)
    if handles.UserData.currentFrameInd>=handles.UserData.epochs(iEpoch,1) &&...
            handles.UserData.currentFrameInd<=handles.UserData.epochs(iEpoch,2)

        currentEpoch=iEpoch;
        
    end
end

%if we are, then delete that epoch
handles.UserData.epochs(currentEpoch,:)=[];

%replot epoch bar
handles=drawEpochBar(handles, true);

guidata(hObject,handles)



% --- Executes on button press in ShowStickFigureCheckBox.
function ShowStickFigureCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to ShowStickFigureCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ShowStickFigureCheckBox
handles=guidata(hObject);

handles.UserData.drawStickFigure=hObject.Value;
handles=drawMarkersAndSegments(handles);

guidata(hObject, handles);



function handles=trainOldPredModels(handles)
%Legacy function to hold my old code when I was trying to implement Kalman
%and VAR filters for the predictive model.


%get velocities
velocities=cell(1,handles.UserData.nMarkers);
velocitiesHist=cell(1,handles.UserData.nMarkers);
nanInds=[];
usePredModel=false;
for iMarker=1:handles.UserData.nMarkers
    if handles.UserData.markersInfo(iMarker).usePredModel &&...
            strcmpi(handles.UserData.markersInfo(iMarker).trackType,'auto')
        
        usePredModel=true;
        %get data
        data=squeeze(handles.UserData.trackedData(iMarker,:,:));
        
        %calculate velocities and velocity history
        velocities{iMarker}=diff(data);
        velocitiesHist{iMarker}=[[NaN NaN]; velocities{iMarker}(1:end-1,:)];
        
        % find nans for removal
        nanInds=[nanInds; find(isnan(velocities{iMarker}(:,1)));...
            find(isnan(velocitiesHist{iMarker}(:,1)))];
        
    end
end

if usePredModel
    
    % remove nans
    nanInds=unique(nanInds);
    for iMarker=1:handles.UserData.nMarkers
        if ~isempty(velocities{iMarker})
            velocities{iMarker}(nanInds,:)=[];
            velocitiesHist{iMarker}(nanInds,:)=[];
            nTrainPoints=size(velocities{iMarker},1);
        end
    end
    
    if nTrainPoints==0
        warndlg('No training points for model!')
        return
    elseif nTrainPoints<100
        warndlg('Warning: less than 100 training points for model!')
    end
    
    
    switch handles.UserData.modelType
        
        case 'VAR'
            %output is the marker velocities
            %input is the previous velocities of all the markers
            for iMarker=1:handles.UserData.nMarkers
                if ~isempty(velocities{iMarker})
                    output=velocities{iMarker};
                    input=cat(2,velocitiesHist{:});
                    
                    modelParams=TrackerFunctions.trainPredModel(input,output,'VAR');
                    handles.UserData.markersInfo(iMarker).modelParams=modelParams;
                end
            end
            
        case 'Kalman'
            %output is the marker velocities
            %input is the previous velocities of all the markers
            %but need to put current marker previous velocity in the front
            for iMarker=1:handles.UserData.nMarkers
                if ~isempty(velocities{iMarker})
                    output=velocities{iMarker};
                    input=velocitiesHist{iMarker};
                    input=[input cat(2,velocitiesHist{setdiff(1:length(velocitiesHist),iMarker)})];
                    
                    modelParams=TrackerFunctions.trainPredModel(input,output,'Kalman');
                    
                    %set initial kalman filter state
                    values=diff(squeeze(handles.UserData.trackedData(...
                        iMarker,handles.UserData.currentFrameInd-1:handles.UserData.currentFrameInd-1,:)));
                    if isnan(values)
                        values=[0; 0];
                    end
                    
                    modelParams.kalmanFilterObj.State=values;
                    handles.UserData.markersInfo(iMarker).modelParams=modelParams;
                    
                end
            end
            
    end
    
end



% --- Executes on button press in TrainModelButton.
function TrainModelButton_Callback(hObject, eventdata, handles)
% hObject    handle to TrainModelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% make sure a model is defined first
if ~handles.UserData.kinModelDefined
    warndlg('Model not yet defined!')
    return
end

% clear any old training data
handles.UserData.kinModel.trainingDataAngles=[];
handles.UserData.kinModel.trainingDataLengths=[];
handles.UserData.kinModelTrained=false;
handles.TrainModelButton.BackgroundColor=[0.94 0.94 0.94];

% First, load data from any external files
for iExtern=1:handles.UserData.kinModel.nExterns
    foundNames=strfind(handles.UserData.kinModel.anchorNames2,['Extern' num2str(iExtern)]);
    foundNames=unique(handles.UserData.kinModel.anchorNames2(cellfun(@(x) any(x==1),foundNames)));
    if ~isempty(foundNames)
        %there are some markers from this extern, load file
        try
            tmpVar=load(handles.UserData.kinModel.externFileNames{iExtern});
            
            %save tracked data
            handles.UserData.kinModel.externData{iExtern}=tmpVar.MARKERTRACKERGUI_UserData.trackedData;
            %and the marker names
            handles.UserData.kinModel.externMarkerNames{iExtern}=...
                join([repmat("Extern1 -",24,1),string({tmpVar.MARKERTRACKERGUI_UserData.markersInfo.name})']);

        catch
            warndlg(['Unable to load data from external file: ' handles.UserData.kinModel.externFileNames{iExtern}]);
            return
        end
        
        %check to make sure all the desired variables are in that external
        %file's markers
        for iName=1:length(foundNames)
            if ~any(foundNames(iName)==handles.UserData.kinModel.externMarkerNames{iExtern})
                parts=split(foundNames(iName));
                warndlg(['Unable to find marker, ' char(join(parts(3:end))) ', from external file: '...
                    handles.UserData.kinModel.externFileNames{iExtern}]);
            end
        end
        
        clear tmpVar;
    end
end

% now for each pair, get the angles and lengths
for iPair=1:length(handles.UserData.kinModel.anchorNames1)
    
    %find the index of where the first marker is
    markerInd1=find(string({handles.UserData.markersInfo.name})==...
        handles.UserData.kinModel.anchorNames1(iPair));
    
    %get the data for the first marker
    marker1Data=squeeze(handles.UserData.trackedData(markerInd1,:,:));
    
    %find the index of the second marker
    %find extern number if it's an extern marker
    externNumber=[];
    parts=split(handles.UserData.kinModel.anchorNames2(iPair));
    if length(parts{1})>=7 && strcmp(parts{1}(1:6),'Extern')
        externNumber=str2double(parts{1}(7:end));
        markerInd2=find(handles.UserData.kinModel.externMarkerNames{externNumber}==...
            handles.UserData.kinModel.anchorNames2(iPair));
    else
        markerInd2=find(string({handles.UserData.markersInfo.name})==...
            handles.UserData.kinModel.anchorNames2(iPair));
    end
    
    %get the data for the second marker
    if ~isempty(externNumber)
        marker2Data=squeeze(handles.UserData.kinModel.externData{iExtern}(markerInd2,:,:));
    else
        marker2Data=squeeze(handles.UserData.trackedData(markerInd2,:,:));
    end
    
    %do check that the two have the same number of frames
    if size(marker1Data,1)~=size(marker2Data,1)
        warndlg(['Makers ' char(handles.UserData.kinModel.anchorNames1(iPair)) ...
            ' and ' char(handles.UserData.kinModel.anchorNames2(iPair)) ' are different lengths!']);
        return
    end
    
    %finally, calculate the joint angles and lengths between this pair
    [angles,lengths]=TrackerFunctions.calcAngleAndLengths(marker1Data,marker2Data);
    
    %save to struct
    handles.UserData.kinModel.trainingDataAngles(:,iPair)=angles;
    handles.UserData.kinModel.trainingDataLengths(:,iPair)=lengths;
end

% remove points where it is all nan for all the pair angles or lengths
allNaNInds=find(all(isnan(handles.UserData.kinModel.trainingDataAngles),2));

handles.UserData.kinModel.trainingDataAngles(allNaNInds,:)=[];
handles.UserData.kinModel.trainingDataLengths(allNaNInds,:)=[];

% If we so desire, remove points where any of the pair angles or lengths
% are nan (in case want to save memory)
if handles.GUIOptions.kinModelNoNans
    anyNaNInds=find(any(isnan(handles.UserData.kinModel.trainingDataAngles),2));
    handles.UserData.kinModel.trainingDataAngles(anyNaNInds,:)=[];
    handles.UserData.kinModel.trainingDataLengths(anyNaNInds,:)=[];
end

% set train model button to green so we know that a model has been trained
handles.TrainModelButton.BackgroundColor='g';
handles.UserData.kinModelTrained=true;

guidata(hObject,handles)



% --- Executes on selection change in KinematicModelSelect.
function KinematicModelSelect_Callback(hObject, eventdata, handles)
% hObject    handle to KinematicModelSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns KinematicModelSelect contents as cell array
%        contents{get(hObject,'Value')} returns selected item from KinematicModelSelect
handles=guidata(hObject);

strList = cellstr(get(hObject,'String'));

handles.UserData.modelType=strList{get(hObject,'Value')};

guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function KinematicModelSelect_CreateFcn(hObject, eventdata, handles)
% hObject    handle to KinematicModelSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in UseKinematicModelCheckBox.
function UseKinematicModelCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to UseKinematicModelCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of UseKinematicModelCheckBox
handles=guidata(hObject);

for iMarker=1:length(handles.UserData.currentMarkerInds)
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(iMarker)).useKinModel=...
        get(hObject,'Value');
end

guidata(hObject,handles);


% --- Executes on button press in DefineModelButton.
function DefineModelButton_Callback(hObject, eventdata, handles)
% hObject    handle to DefineModelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return
end

% if there are no markers, can't define model
if handles.UserData.nMarkers==0
    warndlg('Can''t define model without any markers!')
    return
end

% in case a model was already defined and trained before, get a list of all
% the marker combinations of the previous model for comparison
if handles.UserData.kinModelDefined
    oldCombs=sort(join([handles.UserData.kinModel.anchorNames1',...
        handles.UserData.kinModel.anchorNames2']));
end

% call the model definer gui
handles.UserData=MarkerTracker_ModelDefiner(handles.UserData);

% Now that the anchors for each marker are defined, need to save the list
% of all combinations of points
handles.UserData.kinModel.anchorNames1=string([]);
handles.UserData.kinModel.anchorNames2=string([]);
for iMarker=1:handles.UserData.nMarkers
    
    alreadyDefinedInds=handles.UserData.kinModel.anchorNames2==...
        string(handles.UserData.markersInfo(iMarker).name);
    
    for iAnchor=1:length(handles.UserData.markersInfo(iMarker).kinModelAnchors)
        if any(handles.UserData.markersInfo(iMarker).kinModelAnchors{iAnchor}==...
                handles.UserData.kinModel.anchorNames1(alreadyDefinedInds))
            
            %already defined
            continue
        else
            
            %add to list
            handles.UserData.kinModel.anchorNames1(end+1)=handles.UserData.markersInfo(iMarker).name;
            handles.UserData.kinModel.anchorNames2(end+1)=...
                handles.UserData.markersInfo(iMarker).kinModelAnchors{iAnchor};
        end
    end
end

% if the combination of points is different from before, the training data
% is invalid, so reset the model.
if handles.UserData.kinModelDefined
    newCombs=sort(join([handles.UserData.kinModel.anchorNames1',...
        handles.UserData.kinModel.anchorNames2']));
    
    if length(newCombs)~=length(oldCombs) || any(newCombs~=oldCombs)
        
        handles.UserData.kinModelTrained=false;
        handles.UserData.TrainModelButton.BackgroundColor=[0.94 0.94 0.94];
        
    end
end

% set background to green to let user know that the model has been defined
handles.DefineModelButton.BackgroundColor='g';
handles.UserData.kinModelDefined=true;

guidata(hObject,handles);



% --- Executes on button press in AddExclusionButton.
function AddExclusionButton_Callback(hObject, eventdata, handles)
% hObject    handle to AddExclusionButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% only add if data initialized
if ~handles.UserData.dataInitialized
    return
end

% let user select region
axes(handles.FrameAxes)
[mask,selectionX,selectionY]=roipoly;

% cancelled selection, or region wasn't a polygon
if isempty(selectionX) || sum(sum(mask))==0
    return
end

% account for zooming
if ~isnan(handles.UserData.zoomRect)
    selectionX=selectionX+handles.UserData.zoomRect(1)-1;
    selectionY=selectionY+handles.UserData.zoomRect(2)-1;
end

% save region
handles.UserData.exclusionZones{end+1}=[selectionX selectionY];

% make new mask for the frame
handles.UserData.exclusionMask=zeros(handles.UserData.frameSize(2),handles.UserData.frameSize(1));
for iZone=1:length(handles.UserData.exclusionZones)
    mask=poly2mask(handles.UserData.exclusionZones{iZone}(:,1),...
        handles.UserData.exclusionZones{iZone}(:,2),...
        handles.UserData.frameSize(2),handles.UserData.frameSize(1));
    handles.UserData.exclusionMask=handles.UserData.exclusionMask | mask;
end

% update frame with the new mask, and redraw frame
handles.UserData.currentFrame=TrackerFunctions.applyImageProcessing(...
    handles.UserData.currentFrameUnprocessed, handles.UserData.globalBrightness,...
    handles.UserData.globalContrast, handles.UserData.globalDecorr,handles.UserData.exclusionMask);

% redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)



% --- Executes on button press in RemoveExclusionButton.
function RemoveExclusionButton_Callback(hObject, eventdata, handles)
% hObject    handle to RemoveExclusionButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% only do if data initialized
if ~handles.UserData.dataInitialized
    return
end

% if no regions, let user know and return
if isempty(handles.UserData.exclusionZones)
    warndlg('No exclusion zones have been defined')
    return
end

% let user select point
axes(handles.FrameAxes)
[selectionX, selectionY]=getpts;

if isempty(selectionX)
    return
elseif length(selectionX)>1
    warndlg('Please click only one point!')
    return
end

% account for zooming
if ~isnan(handles.UserData.zoomRect)
    selectionX=selectionX+handles.UserData.zoomRect(1)-1;
    selectionY=selectionY+handles.UserData.zoomRect(2)-1;
end

% go through all exclusion zones, and delete the ones that contain the
% point
zonesToDelete=[];
for iZone=1:length(handles.UserData.exclusionZones)
    mask=poly2mask(handles.UserData.exclusionZones{iZone}(:,1),...
        handles.UserData.exclusionZones{iZone}(:,2),...
        handles.UserData.frameSize(2),handles.UserData.frameSize(1));
    if(mask(round(selectionY),round(selectionX)))
        zonesToDelete(end+1)=iZone;
    end
end
handles.UserData.exclusionZones(zonesToDelete)=[];

% make new mask for the frame
handles.UserData.exclusionMask=zeros(handles.UserData.frameSize(2),handles.UserData.frameSize(1));
for iZone=1:length(handles.UserData.exclusionZones)
    mask=poly2mask(handles.UserData.exclusionZones{iZone}(:,1),...
        handles.UserData.exclusionZones{iZone}(:,2),...
        handles.UserData.frameSize(2),handles.UserData.frameSize(1));
    handles.UserData.exclusionMask=handles.UserData.exclusionMask | mask;
end

% update frame with the new mask, and redraw frame
handles.UserData.currentFrame=TrackerFunctions.applyImageProcessing(...
    handles.UserData.currentFrameUnprocessed, handles.UserData.globalBrightness,...
    handles.UserData.globalContrast, handles.UserData.globalDecorr,handles.UserData.exclusionMask);

% redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);


guidata(hObject,handles)



% --- Executes on button press in EpochInputButton.
function EpochInputButton_Callback(hObject, eventdata, handles)
% hObject    handle to EpochInputButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% only if video loaded
if ~handles.UserData.videoLoaded
    return
end

% default answer is the already defined epochs
default='[';
for iEpoch=1:size(handles.UserData.epochs,1)
    default=[default num2str(handles.UserData.epochs(iEpoch,1)), ', ',...
        num2str(handles.UserData.epochs(iEpoch,2))];
    
    if iEpoch~=size(handles.UserData.epochs,1)
        default=[default '; '];
    end
end
default(end+1)=']';

% call dialog
typedString=inputdlg('Enter Epoch Edges (using normal array input syntax)',...
    'Epoch Input',1,{default});

% if there was nothing, remove all epochs
if isempty(typedString)
    handles.UserData.epochs=[];
    return
end

% cast the typed in string
typedString=string(typedString{1});

% now try to parse in the string using str2num
epochs=str2num(typedString);

if isempty(epochs)
    warndlg('Unable to parse input!')
    return
end

% check that the parsed array is Nx2, has no nans, is all intergers, and
% the second row is always bigger than the first row. Also values must be
% between 1 and the number of frames
if size(epochs,2)~=2
    warndlg('Input matrix must be size Nx2!')
    return
elseif any(epochs(:,2)<epochs(:,1))
    warndlg('Values in the second row must be larger than the corresponding value in the first row!');
    return
elseif any(round(epochs(:))-epochs(:)>0.0001)
    warndlg('Values must be intergers!');
    return
elseif min(epochs(:))<1 || max(epochs(:))>handles.UserData.nFrames
    warndlg(['Values must be between 1 and the total number of frames ('...
        num2str(handles.UserData.nFrames) ')!']);
    return
end

% passed all the checks, save into handles
handles.UserData.epochs=sortrows(round(epochs));

%replot epoch bar
handles=drawEpochBar(handles, true);

guidata(hObject,handles)



% --- Executes on button press in SplineInterpolateButton.
function SplineInterpolateButton_Callback(hObject, eventdata, handles)
% hObject    handle to SplineInterpolateButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return;
end

% perform interpolation
[handles, success] = doInterpolation(handles, 'spline');

if ~success
    return
end

%redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)



% --- Executes on button press in LinearInterpolateButton.
function LinearInterpolateButton_Callback(hObject, eventdata, handles)
% hObject    handle to LinearInterpolateButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

if ~handles.UserData.dataInitialized
    return;
end

% perform interpolation
[handles, success] = doInterpolation(handles, 'linear');

if ~success
    return
end

%redraw
handles = drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles)



% --- Executes on button press in SetLowerRangeButton.
function SetLowerRangeButton_Callback(hObject, eventdata, handles)
% hObject    handle to SetLowerRangeButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% don't do anything if video not loaded
if ~handles.UserData.videoLoaded
    return;
end

% set current frame to the start of the range
handles.UserData.deleteRange(1) = handles.UserData.currentFrameInd;

% update display
handles.DeleteStartInput.String = num2str(handles.UserData.currentFrameInd);

guidata(hObject,handles)



% --- Executes on button press in SetUpperRangeButton.
function SetUpperRangeButton_Callback(hObject, eventdata, handles)
% hObject    handle to SetUpperRangeButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% don't do anything if video not loaded
if ~handles.UserData.videoLoaded
    return;
end

% set current frame to the end of the range
handles.UserData.deleteRange(2) = handles.UserData.currentFrameInd;

% update display
handles.DeleteEndInput.String = num2str(handles.UserData.currentFrameInd);

guidata(hObject,handles)



% --- Executes on button press in DeleteAreaButton.
function DeleteAreaButton_Callback(hObject, eventdata, handles)
% hObject    handle to DeleteAreaButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% data and video must be loaded in
if ~handles.UserData.videoLoaded || ~handles.UserData.dataLoaded
    return
end

handles = guidata(hObject);

% perform deletion
[handles, pointsDeleted] = deleteMarkersInArea(handles, 1:handles.UserData.nMarkers);

if ~pointsDeleted
    return
end

%redraw
handles = drawFrame(handles);
handles = drawMarkersAndSegments(handles);

guidata(hObject,handles)




% --- Executes on button press in DeleteAreaCurrentMarkerButton.
function DeleteAreaCurrentMarkerButton_Callback(hObject, eventdata, handles)
% hObject    handle to DeleteAreaCurrentMarkerButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% data and video must be loaded in
if ~handles.UserData.videoLoaded || ~handles.UserData.dataLoaded
    return
end

handles = guidata(hObject);

% perform deletion
[handles, pointsDeleted] = deleteMarkersInArea(handles, handles.UserData.currentMarkerInds);

if ~pointsDeleted
    return
end

%redraw
handles = drawFrame(handles);
handles = drawMarkersAndSegments(handles);

guidata(hObject,handles)



% --- Executes on button press in UndoButton.
function UndoButton_Callback(hObject, eventdata, handles)
% hObject    handle to UndoButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% if there's no saved data backup, warn user
if isempty(handles.UserData.dataBackup.markerInds)
    handles = displayMessage(handles, 'Nothing to Undo', [1 0 0]);
    guidata(hObject,handles)
    return
end

% go through each marker and overwrite with the backup data 
for iMarker = 1:length(handles.UserData.dataBackup.markerInds)
    
    % save current data in case they want to undo the undo
    currentTrackedData{iMarker} = handles.UserData.trackedData(...
        handles.UserData.dataBackup.markerInds(iMarker), ...
        handles.UserData.dataBackup.frameInds{iMarker}, :);
    currentTrackedBoxSizes{iMarker} = handles.UserData.trackedBoxSizes(...
        handles.UserData.dataBackup.markerInds(iMarker), ...
        handles.UserData.dataBackup.frameInds{iMarker}, :);


    % now overwrite the current data with the backup
    handles.UserData.trackedData(...
        handles.UserData.dataBackup.markerInds(iMarker),...
        handles.UserData.dataBackup.frameInds{iMarker}, :) = ...
        handles.UserData.dataBackup.trackedData{iMarker};
    
    handles.UserData.trackedBoxSizes(...
        handles.UserData.dataBackup.markerInds(iMarker),...
        handles.UserData.dataBackup.frameInds{iMarker}, :) = ...
        handles.UserData.dataBackup.boxSizes{iMarker};
    
end

% finally overwrite the backup with the original data
handles.UserData.dataBackup.trackedData = currentTrackedData;
handles.UserData.dataBackup.boxSizes = currentTrackedBoxSizes;

%redraw
handles = drawFrame(handles);
handles = drawMarkersAndSegments(handles);

guidata(hObject,handles)



% --- Executes on button press in FreezeSegmentCheckBox.
function FreezeSegmentCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to FreezeSegmentCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of FreezeSegmentCheckBox
handles=guidata(hObject);

for iMarker=1:length(handles.UserData.currentMarkerInds)
    
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(iMarker)).freezeSeg = ...
        get(hObject,'Value');
    
end

guidata(hObject,handles);



% --- Executes on button press in FreezeSegmentAnchorButton.
function FreezeSegmentAnchorButton_Callback(hObject, eventdata, handles)
% hObject    handle to FreezeSegmentAnchorButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% which marker is currently selected
currentMarkerInd = handles.UserData.currentMarkerInds(1);

% need to have segments defined
if isempty(handles.UserData.segments)
    warndlg('No segments loaded!');
    return
end

% markers that is connected to the current marker
connectedMarkerInds = [handles.UserData.segments(handles.UserData.segments(:,1) == currentMarkerInd, 2); ...
    handles.UserData.segments(handles.UserData.segments(:,2) == currentMarkerInd, 1)];

if isempty(connectedMarkerInds)
    warndlg('No connected markers for selected marker found!');
    return
end

listNames = {handles.UserData.markersInfo(connectedMarkerInds).name};

[selection, madeSelection] = listdlg('PromptString','Select Anchor point: ',...
                      'SelectionMode','single',...
                      'ListString',listNames);

if ~madeSelection
    return
end

handles.UserData.markersInfo(currentMarkerInd).freezeSegAnchor = connectedMarkerInds(selection);

guidata(hObject,handles);



function FrameJumpAmountBox_Callback(hObject, eventdata, handles)
% hObject    handle to FrameJumpAmountBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FrameJumpAmountBox as text
%        str2double(get(hObject,'String')) returns contents of FrameJumpAmountBox as a double
handles=guidata(hObject);
if (~handles.UserData.videoLoaded)
    return;
end

value = str2double(get(hObject,'String'));
if isnan(value) || value<=0 || value>handles.UserData.nFrames
    warndlg(['Frame jump amount must be a number between 0 and ' num2str(handles.UserData.nFrames)]);
    hObject.String = num2str(handles.UserData.frameJumpAmount);
else
    handles.UserData.frameJumpAmount = value;
    handles.FrameSlider.SliderStep = [1/handles.UserData.nFrames value/handles.UserData.nFrames];
end

guidata(hObject,handles)



% --- Executes during object creation, after setting all properties.
function FrameJumpAmountBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FrameJumpAmountBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in ShowEstimatesCheckBox.
function ShowEstimatesCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to ShowEstimatesCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ShowEstimatesCheckBox
handles=guidata(hObject);

handles.UserData.showMarkerEsts=hObject.Value;
handles=drawMarkersAndSegments(handles, true);

guidata(hObject, handles);



% 

