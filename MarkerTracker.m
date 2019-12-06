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

% Last Modified by GUIDE v2.5 26-Sep-2018 18:41:23

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
handles.UserData.VersionNumber='1.0';

handles.UserData.bufferSize=30;
handles.UserData.autosaveIntervalMin=3;
handles.UserData.plotMarkerSize=8;
handles.UserData.plotMarkerEstSize=9;
handles.UserData.plotMarkerWidth=2;
handles.UserData.plotMarkerColor='y';
handles.UserData.plotMarkerEstColor='m';
handles.UserData.plotSegmentWidth=0.7;
handles.UserData.plotSegmentColor='r';
handles.UserData.plotCurrentMarkerSize=10;
handles.UserData.plotCurrentMarkerColor='w';
handles.UserData.epochPatchColor1=[0.000,  0.447,  0.741];
handles.UserData.epochPatchColor2=[0.929,  0.694,  0.125];
handles.UserData.contrastEnhancementLevel=0.01;
handles.UserData.defaultMarkerSize=[30 30];
handles.UserData.channelNames={... %make sure to define these in findMarkerPos function!
    'Green','Red','Red/Green','Blue','Hue','Saturation','Value','Grey'};
handles.UserData.nColorChannels=length(handles.UserData.channelNames);

handles.UserData.predictiveModelNames={... %make sure to define these in trainModelbutton and autoincrement functions!
    'Spline'};

handles.UserData.splineNPoints=5; %for spline trajectory prediction, number of points to fit
handles.UserData.splineMAOrder=3; %for spline trajectory prediction, number of points for the pre-fit MA filter

handles.UserData.kinModel.minInputs=3; %for kinematic model estimation with kNN, the min number of input features to the kNN
handles.UserData.kinModel.classifierK=5; %for kinematic model estimation, the number of kNN points
handles.UserData.kinModel.defaultAngleTol=20; %the maximum standard deviation of the kNN point outputs, in degrees

handles.UserData.minMarkerDist=5; %the minimum number of pixels two markers can be within each other
handles.UserData.autorunDispInterval=10; %number of frames to track before updating display during autorun
handles.UserData.minConvex=0.8; %minimun ratio of area to convext area of blobs before trying to separate into two blobs

handles.UserData.lengthOutlierMult=1.3; %multiplier to determine the maximum length between pairs in kin model
handles.UserData.maxJumpMult=2; %multiplier to determine the maximum allowable jumps

% Some developer options
handles.GUIOptions.plotPredLocs=false;
handles.GUIOptions.kinModelNoNans=false;

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
handles.UserData.kinModelDefined=false;
handles.UserData.kinModelTrained=false;
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
        ~strcmp(callbackdata.Key,'uparrow') && ~strcmp(callbackdata.Key,'downarrow')
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
    
    %update markers that are set to 'auto'
    if handles.UserData.dataInitialized
        handles=autoIncrementMarkers(handles);
    end
    
    handles=drawMarkersAndSegments(handles);
    
    %FOR SOME REASON IF I DON'T PUT A PAUSE HERE IT WILL CONTINUE READING
    %KEY STROKES AND QUEUING THEM EVEN THOUGH I SET BUSYACTION TO CANCEL
    %RATHER THAN QUEUE
%     pause(0.01)
    
elseif strcmp(callbackdata.Key,'leftarrow')
    %previous frame (if not beginning of video)
    if handles.UserData.currentFrameInd==1
        setappdata(handles.figure1,'evaluatingKeyPress',false)
        return;
    end
    handles=changeFrame(handles,handles.UserData.currentFrameInd-1,true);
    
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
point=floor(eventdata.IntersectionPoint(1:2)+0.5); %image sets edges=0.5, I want them to be 1
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
handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=markerPos;
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=boxSize;

% redraw
drawFrame(handles);
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
    while handles.UserData.videoReader.CurrentTime~=(frameNumber-1)/handles.UserData.frameRate
        frame=handles.UserData.videoReader.readFrame;
        
        if handles.UserData.videoReader.CurrentTime>(frameNumber-1)/handles.UserData.frameRate
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
    handles.UserData.globalContrast, handles.UserData.globalDecorr);

% show frame (or zoomed in frame)
if displayNewFrame
    drawFrame(handles)
    handles=drawMarkersAndSegments(handles);
end

% update slider
handles.FrameSlider.Value=handles.UserData.currentFrameInd;

% update frame number
handles.FrameNumberBox.String=num2str(frameNumber);

% update epoch bar
handles=drawEpochBar(handles);



function drawFrame(handles)
figure(handles.figure1)
axes(handles.FrameAxes);

% get zoom box and display
if isnan(handles.UserData.zoomRect)
    frame_h=image(handles.UserData.currentFrame);
else
    zoomRect=handles.UserData.zoomRect;
    frame_h=imshow(handles.UserData.currentFrame(zoomRect(2):zoomRect(2)+zoomRect(4)-1,...
        zoomRect(1):zoomRect(1)+zoomRect(3)-1,:));
end

% set callback for new axes
frame_h.ButtonDownFcn=@FrameButtonDown_Callback;
axis off


function handles=drawMarkersAndSegments(handles)
% function to draw the markers and stick figure

if ~handles.UserData.dataInitialized
    return
end

% draw current marker
markersPos=squeeze(handles.UserData.trackedData(:,handles.UserData.currentFrameInd,:));
markerBoxSize=round(squeeze(handles.UserData.trackedBoxSizes(...
        handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:))/2);
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

% draw marker if it's tracked
markerExists=true;
if ~isnan(markersPos(handles.UserData.currentMarkerInds(1),1))
    markerType='.';
    markerColor=handles.UserData.plotMarkerColor;
    markerSize=handles.UserData.plotMarkerSize;
    currentMarkerPosZoom=markersPosZoom(handles.UserData.currentMarkerInds(1),:);
elseif ~isnan(markersPosEst(handles.UserData.currentMarkerInds(1),1))
    %or if there's an estimate for it from the kinematic model
    markerType='x';
    markerColor=handles.UserData.plotMarkerEstColor;
    markerSize=handles.UserData.plotMarkerEstSize;
    currentMarkerPosZoom=markersPosEstZoom(handles.UserData.currentMarkerInds(1),:);
else
    markerExists=false;
end

% plot on frame
if markerExists
    axes(handles.FrameAxes)
    hold on
    plot(currentMarkerPosZoom(1),...
        currentMarkerPosZoom(2),...
        markerType,'MarkerSize',markerSize,...
        'Color',markerColor,...
        'PickableParts','none');
    
    %put current marker selection cursor
    plot(currentMarkerPosZoom(1),...
        currentMarkerPosZoom(2),...
        'o','MarkerSize',handles.UserData.plotCurrentMarkerSize,...
        'Color',handles.UserData.plotCurrentMarkerColor,...
        'PickableParts','none');
    hold off
end

%show marker box
if ~isnan(markersPos(handles.UserData.currentMarkerInds(1),1))
    axes(handles.MarkerAxes);
    startY=max(1,round(markersPos(handles.UserData.currentMarkerInds(1),2)-markerBoxSize(2)));
    endY=min(round(markersPos(handles.UserData.currentMarkerInds(1),2)+markerBoxSize(2)),...
        handles.UserData.frameSize(2));
    startX=max(1,round(markersPos(handles.UserData.currentMarkerInds(1),1)-markerBoxSize(1)));
    endX=min(round(markersPos(handles.UserData.currentMarkerInds(1),1)+markerBoxSize(1)),...
        handles.UserData.frameSize(1));
    
    image(handles.UserData.currentFrame(startY:endY,startX:endX,:));
    
    hold on
    plot(markerBoxSize(1)+1,markerBoxSize(2)+1,'+w');
    hold off
    axis off
else
    axes(handles.MarkerAxes);
    image(0);
    axis off
end

% now draw other markers and segments if desired
if handles.UserData.drawStickFigure
    axes(handles.FrameAxes)
    hold on
    %tracked markers
    plot(markersPosZoom(:,1),markersPosZoom(:,2),'.','MarkerSize',handles.UserData.plotMarkerSize,...
        'Color',handles.UserData.plotMarkerColor,'PickableParts','none');
    
    %model estimated markers
    plot(markersPosEstZoom(isnan(markersPosZoom(:,1)),1),markersPosEstZoom(isnan(markersPosZoom(:,1)),2),...
        'x','MarkerSize',handles.UserData.plotMarkerSize,...
        'Color',handles.UserData.plotMarkerEstColor,'PickableParts','none');
    
    %draw line segments
    if ~isempty(handles.UserData.segments)
        markersPosZoom(isnan(markersPosZoom(:,1)),:)=markersPosEstZoom(isnan(markersPosZoom(:,1)),:);
        segmentXs=[markersPosZoom(handles.UserData.segments(:,1),1)'; markersPosZoom(handles.UserData.segments(:,2),1)'];
        segmentYs=[markersPosZoom(handles.UserData.segments(:,1),2)'; markersPosZoom(handles.UserData.segments(:,2),2)'];
        
        handles.UserData.stick_h=line(segmentXs,segmentYs,'linewidth',handles.UserData.plotSegmentWidth,...
            'color',handles.UserData.plotSegmentColor,'PickableParts','none');
    end
    
    hold off;

else
    if ishandle(handles.UserData.stick_h)
        for iLine=1:length(handles.UserData.stick_h)
            delete(handles.UserData.stick_h(iLine));
        end
    end
end



function handles=drawEpochBar(handles)
% function to update the epoch bar with the location of the defined epochs,
% and also draw a line to indicate the current frame position
if ~handles.UserData.videoLoaded
    return
end

axes(handles.EpochAxes)
xlim([1 handles.UserData.nFrames])
ylim([0 1])
% axis off

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
        patchEdgeColor='k';
        patchEdgeWidth=1.5;
        currentEpoch=iEpoch;
    else
        patchEdgeColor=handles.UserData.epochPatchColor1*color1+handles.UserData.epochPatchColor2*(~color1);
        patchEdgeWidth=0.1;
    end
        
    patch([epochStart epochStart epochEnd epochEnd],[1 0 0 1],...
        handles.UserData.epochPatchColor1*color1+handles.UserData.epochPatchColor2*(~color1),...
        'EdgeColor',patchEdgeColor,'LineWidth',patchEdgeWidth,'HitTest','off');
    
    color1=~color1;
end

% draw/move current frame indicator line
if isempty(handles.UserData.epochPositionLine_h) || isempty(handles.UserData.epochPositionLine_h.Parent)
    hold on
    handles.UserData.epochPositionLine_h=line(repmat(handles.UserData.currentFrameInd,1,2),...
        [0 1],'color','r');
    hold off
else
    handles.UserData.epochPositionLine_h.XData=repmat(handles.UserData.currentFrameInd,1,2);
end

if ~isempty(currentEpoch)
    uistack(handles.EpochAxes.Children(currentEpoch),'top'); %bring current epoch patch to top
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

handles.SearchRadiusInput.String=...
    num2str(handles.UserData.markersInfo(markerInds(1)).searchRadius);

% draw marker cursor and marker box
if handles.UserData.dataInitialized
    drawFrame(handles);
    handles=drawMarkersAndSegments(handles);
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
alreadyTrackedMarkers=[];
lostMarkerInds=[];
for iMarker=1:handles.UserData.nMarkers
    if strcmpi(handles.UserData.markersInfo(iMarker).trackType,'auto')
        
        %skip if marker is already tracked
        if ~isnan(handles.UserData.trackedData(iMarker,handles.UserData.currentFrameInd,1))
            alreadyTrackedMarkers=[alreadyTrackedMarkers iMarker];
            continue
        end
        
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
trackedInds=find(~isnan(markerLocs(:,1)));
trackedLocs=markerLocs(trackedInds,:);
trackedNames=string({handles.UserData.markersInfo(trackedInds).name})';

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
    for iMarker=1:length(trackedInds)
        if sum(badMarkers==iMarker)>=2
            handles.UserData.trackedData(trackedInds(iMarker),handles.UserData.currentFrameInd,:)=nan;
            handles.UserData.trackedBoxSizes(trackedInds(iMarker),handles.UserData.currentFrameInd,:)=nan;
        end
    end
    
end

% remove any makers that made large sudden jumps
% calculate jump distance
trackedJumps=squeeze(diff(handles.UserData.trackedData(...
    trackedInds,handles.UserData.currentFrameInd-1:handles.UserData.currentFrameInd,:),1,2));
trackedJumps=sqrt(trackedJumps(:,1).^2+trackedJumps(:,2).^2);

% get all previous jump distances
prevTrackedJumps=diff(handles.UserData.trackedData(...
    trackedInds,1:handles.UserData.currentFrameInd-1,:),1,2);
prevTrackedJumps=squeeze(sqrt(prevTrackedJumps(:,:,1).^2+prevTrackedJumps(:,:,2).^2));

% get tracked markers that exceed the jump limit
badMarkers=find(trackedJumps>max(prevTrackedJumps,[],2)*handles.UserData.maxJumpMult);

% remove those markers
if ~isempty(badMarkers)
    handles.UserData.trackedData(trackedInds(badMarkers),handles.UserData.currentFrame,:)=nan;
    handles.UserData.trackedBoxSizes(trackedInds(badMarkers),handles.UserData.currentFrame,:)=nan;
end

%now after all the markers have been updated, first check if there were any
%markers that were jumped to the wrong joint, and if so, remove that point

%check if two markers are within some threshold of each other

%find the distances between the tracked markers and check against the
%threshold
nOverlaps=0;
overlaps=[];
for iMark1=1:length(trackedLocs)
    for iMark2=(iMark1+1):size(trackedLocs,1)
        dist=norm([trackedLocs(iMark1,:)-trackedLocs(iMark2,:)]);
        if dist<handles.UserData.minMarkerDist
            nOverlaps=nOverlaps+1;
            overlaps(nOverlaps,:)=[iMark1,iMark2];
        end
    end
end

%if they are, the marker that was closest to the the current position
%in the previous frame is considered the correct actual marker
if nOverlaps>0
    
    %get previous tracked locations or model estimate locations
    prevMarkerLocs=squeeze(handles.UserData.trackedData(:,handles.UserData.currentFrameInd-1,:));
    prevMarkerLocsEsts=squeeze(handles.UserData.modelEstData(:,handles.UserData.currentFrameInd-1,:));
    
    prevMarkerLocs(isnan(prevMarkerLocs(:,1)),:)=prevMarkerLocsEsts(isnan(prevMarkerLocs(:,1)),:);
    if any(isnan(prevMarkerLocs(trackedInds,1)))
        warning('No previous maker location or estimate for an auto tracked markers, debug here!')
    end
    
    %go through each overlapping pair
    for iOverlap=1:nOverlaps
        
        %if both the markers were already tracked, then don't do any
        %deletion
        if any(trackedInds(overlaps(iOverlap,1))==alreadyTrackedMarkers) &&...
            any(trackedInds(overlaps(iOverlap,2))==alreadyTrackedMarkers)
            %don't delete
            continue
            
        elseif any(trackedInds(overlaps(iOverlap,1))==alreadyTrackedMarkers)
            %delete second one
            handles.UserData.trackedData(trackedInds(overlaps(iOverlap,2)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            handles.UserData.trackedBoxSizes(trackedInds(overlaps(iOverlap,2)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            
        elseif any(trackedInds(overlaps(iOverlap,2))==alreadyTrackedMarkers)
            %delete first one
            handles.UserData.trackedData(trackedInds(overlaps(iOverlap,1)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            handles.UserData.trackedBoxSizes(trackedInds(overlaps(iOverlap,1)),...
                handles.UserData.currentFrameInd,:)=[NaN NaN];
            
        else
            %delete the further one from the average of the two overlapping
            %locations
            
            prevPos1=prevMarkerLocs(trackedInds(overlaps(iOverlap,1)),:);
            prevPos2=prevMarkerLocs(trackedInds(overlaps(iOverlap,2)),:);
            avePos=(trackedLocs(overlaps(iOverlap,1),:)+trackedLocs(overlaps(iOverlap,2),:))/2;
            
            if norm([prevPos1 - avePos]) > norm([prevPos2 - avePos])
                %previous location of 1 is futher away, remove 1
                handles.UserData.trackedData(trackedInds(overlaps(iOverlap,1)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
                handles.UserData.trackedBoxSizes(trackedInds(overlaps(iOverlap,1)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
            else
                %otherwise, remove 2
                handles.UserData.trackedData(trackedInds(overlaps(iOverlap,2)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
                handles.UserData.trackedBoxSizes(trackedInds(overlaps(iOverlap,2)),...
                    handles.UserData.currentFrameInd,:)=[NaN NaN];
            end
        end
        
    end
    
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
    
    if ~isempty(inputInds)
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


function handles=markerLostCallback(lostMarkerInds,handles)

% stop autorun
setappdata(handles.figure1,'autorunEnabled',false);

% warn user
lostMarkerNames=string({handles.UserData.markersInfo(lostMarkerInds).name});
warndlg(['Markers Lost: ' char(join(lostMarkerNames,', '))])



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

% Oepn dialog to select video file
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
handles.UserData.nFrames=handles.UserData.videoReader.Duration*handles.UserData.videoReader.FrameRate;
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
    
    if ~isfield(vars,'MARKERTRACKERGUI_UserData') && ~isfield(vars,'MARKERTRACKERGUI_MarkerNames')
        
        warndlg('.mat file must contain MARKERTRACKERGUI_UserData or MARKERTRACKERGUI_MarkerNames variable!')
        return;
        
    elseif ~isfield(vars,'MARKERTRACKERGUI_UserData')
        %no data from previous session, just want to initialize markers
        handles.UserData.nMarkers=length(vars.MARKERTRACKERGUI_MarkerNames);
        
        for iMarker=1:handles.UserData.nMarkers
            markers(iMarker).name=vars.MARKERTRACKERGUI_MarkerNames{iMarker};
            markers(iMarker).UIListInd=iMarker;
            markers(iMarker).trackType='manual';
            markers(iMarker).usePredModel=false;
            markers(iMarker).useKinModel=false;
            markers(iMarker).searchRadius=10;
            markers(iMarker).guessSize=handles.UserData.defaultMarkerSize;
            markers(iMarker).modelParams=[];
            
            markers(iMarker).searchProperties.useChannels=zeros(handles.UserData.nColorChannels,1);
            markers(iMarker).searchProperties.thresholds=[zeros(handles.UserData.nColorChannels,1),...
            ones(handles.UserData.nColorChannels,1)*255];
            markers(iMarker).searchProperties.useContrastEnhancement=zeros(handles.UserData.nColorChannels,1);
            markers(iMarker).searchProperties.blobSizes=[];
            markers(iMarker).searchProperties.maxAspectRatio=5;
            markers(iMarker).searchProperties.minArea=0;
            
            markers(iMarker).kinModelAnchors={};
            markers(iMarker).kinModelAngleTol=handles.UserData.kinModel.defaultAngleTol;
        end
        handles.UserData.markersInfo=markers;
        
        %set kin model possible anchors to marker names
        handles.UserData.kinModel.allPossibleAnchors={handles.UserData.markersInfo.name}';
        
        %next load in line segments (connecting line markers) if there's any
        if isfield(vars,'MARKERTRACKERGUI_Segments')
            for iSeg=1:size(vars.MARKERTRACKERGUI_Segments,1)
                handles.UserData.segments(iSeg,:)=[find(strcmp(vars.MARKERTRACKERGUI_Segments{iSeg,1},{markers.name})),...
                    find(strcmp(vars.MARKERTRACKERGUI_Segments{iSeg,2},{markers.name}))];
            end
        end
        
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
        
    else
        %data from a previous session, just put to UserData and do checks
        % TODO: Checks+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        handles.UserData=vars.MARKERTRACKERGUI_UserData;
        
        %update gui with video info
        handles=updateVidDisplayInfo(handles);
        
        %change to the current frame and marker of the session
        loadedFrameInd=handles.UserData.currentFrameInd;
        handles.UserData.currentFrameInd=nan; %so no previous frame checks
        handles=changeFrame(handles,loadedFrameInd,true);
        handles=changeSelectedMarkers(handles,handles.UserData.currentMarkerInds);
        
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
    [~,fileMarkerNames,~,myMarkerInds,fileData]=TrackerFunctions.readPFile(myMarkerNames,filename);

    %now in the case were we didnt have markers already defined, define
    %them now with the markers from the p file
    if isempty(myMarkerNames)
        % fill marker structure to hold info for each joint marker with default
        % values
        for iMarker=1:length(fileMarkerNames)
            markers(iMarker).name=fileMarkerNames{iMarker};
            markers(iMarker).UIListInd=iMarker;
            markers(iMarker).trackType='manual';
            markers(iMarker).usePredModel=false;
            markers(iMarker).useKinModel=false;
            markers(iMarker).searchRadius=10;
            markers(iMarker).guessSize=handles.UserData.defaultMarkerSize;
            markers(iMarker).modelParams=[];
            
            markers(iMarker).searchProperties.useChannels=zeros(handles.UserData.nColorChannels,1);
            markers(iMarker).searchProperties.thresholds=[zeros(handles.UserData.nColorChannels,1),...
                ones(handles.UserData.nColorChannels,1)*255];
            markers(iMarker).searchProperties.useContrastEnhancement=zeros(handles.UserData.nColorChannels,1);
            markers(iMarker).searchProperties.blobSizes=[];
            markers(iMarker).searchProperties.maxAspectRatio=5;
            markers(iMarker).searchProperties.minArea=0;
            
            markers(iMarker).kinModelAnchors={};
            markers(iMarker).kinModelAngleTol=handles.UserData.kinModel.defaultAngleTol;
            
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
        markersInFile=~isnan(myMarkerInds);
        myMarkerInds(isnan(myMarkerInds))=[];
        
        %save the data from the file to the data arrays        
        handles.UserData.trackedData(markersInFile,1:size(fileData,1),1)=...
            fileData(:,myMarkerInds*2-1)'*handles.UserData.frameSize(1);
        handles.UserData.trackedData(markersInFile,1:size(fileData,1),2)=...
            fileData(:,myMarkerInds*2)'*handles.UserData.frameSize(2);
        
         %for box sizes, just use default box size
            handles.UserData.trackedBoxSizes(markersInFile,1:size(fileData,1),:)=...
                repmat(permute(handles.UserData.defaultMarkerSize,[1,3,2]),length(find(markersInFile)),size(fileData,1));
        
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
handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=markerPos;
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=boxSize;

% redraw
drawFrame(handles);
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
    handles.UserData.globalContrast, handles.UserData.globalDecorr);

% redraw frame
drawFrame(handles)
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
markerData=handles.UserData.trackedData;
markerData(:,:,1)=markerData(:,:,1)/handles.UserData.frameSize(1);
markerData(:,:,2)=markerData(:,:,2)/handles.UserData.frameSize(2);
markerData=permute(markerData,[2 1 3]);

% get names
markerNames=string({handles.UserData.markersInfo.name});
success=TrackerFunctions.writePFile(markerNames, markerData);

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
handles.UserData.trackedData(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;
handles.UserData.modelEstData(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;
handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;
handles.UserData.modelEstBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.deleteRange(1):handles.UserData.deleteRange(2),:)=NaN;

%redraw
drawFrame(handles)
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
while getappdata(handles.figure1,'autorunEnabled')
    
    %increment frame (if not end of video or last epoch)
    if handles.UserData.currentFrameInd==handles.UserData.nFrames ||...
        handles.UserData.currentFrameInd==max(handles.UserData.epochs(:,2))
        
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
    atEpochEnd=find(handles.UserData.currentFrameInd==handles.UserData.epochs(:,2),1);
    if ~isempty(atEpochEnd)
        handles=changeFrame(handles,handles.UserData.epochs(atEpochEnd,1), dispFrame);
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
    %LESS THAN 0.02s THE CALLBACK DOESN'T INTERRUPT AND I CAN'T STOP THE
    %AUTORUN
    pause(0.02)
    guidata(hObject,handles);
    
end

% draw frame an stick figure
drawFrame(handles);
handles=drawMarkersAndSegments(handles);

setappdata(handles.figure1,'autorunEnabled',false);
hObject.BackgroundColor=[0.9400 0.9400 0.9400];

guidata(hObject,handles);

function handles=testfunc(handles)
axes(handles.FrameAxes)
% hold on
% plot(500,500,'*')
% hold off
% pause(1)


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
handles.UserData.trackedData(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;
handles.UserData.modelEstData(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;
handles.UserData.trackedBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;
handles.UserData.modelEstBoxSizes(handles.UserData.currentMarkerInds,...
    handles.UserData.currentFrameInd,:)=NaN;

%redraw frame
drawFrame(handles);
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

handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessBox=...
    selection(3:4);

% call marker properties gui
handles.UserData=MarkerTracker_PropertiesBox(handles.UserData);

% find the actual marker location using the selected point as estimate
markerProperties=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties;
markerProperties.contrastEnhancementLevel=handles.UserData.contrastEnhancementLevel;
markerProperties.trackType=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).trackType;
[markerPos, boxSize]=TrackerFunctions.findMarkerPosInFrame(handles.UserData.currentFrame,...
    handles.UserData.channelNames,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessBox,...
    markerProperties,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation,...
    handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchRadius,...
    handles.UserData.minConvex);

% add to data array
handles.UserData.trackedData(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=markerPos;
handles.UserData.trackedBoxSizes(...
    handles.UserData.currentMarkerInds(1),handles.UserData.currentFrameInd,:)=selection(3:4);

% redraw
drawFrame(handles);
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
% handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessbox=...
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
handles.UserData.zoomRect=zoomRect;

% redraw frame
drawFrame(handles);
handles=drawMarkersAndSegments(handles);

guidata(hObject,handles);

% --- Executes on button press in ZoomOrigButton.
function ZoomOrigButton_Callback(hObject, eventdata, handles)
% hObject    handle to ZoomOrigButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.UserData.zoomRect=NaN;

drawFrame(handles);
handles=drawMarkersAndSegments(handles);

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
handles=drawEpochBar(handles);

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
handles=drawEpochBar(handles);

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
handles=drawEpochBar(handles);

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




% 
