function varargout = MarkerTracker_PropertiesBox(varargin)
% MARKERTRACKER_PROPERTIESBOX MATLAB code for MarkerTracker_PropertiesBox.fig
%      MARKERTRACKER_PROPERTIESBOX, by itself, creates a new MARKERTRACKER_PROPERTIESBOX or raises the existing
%      singleton*.
%
%      H = MARKERTRACKER_PROPERTIESBOX returns the handle to a new MARKERTRACKER_PROPERTIESBOX or the handle to
%      the existing singleton*.
%
%      MARKERTRACKER_PROPERTIESBOX('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARKERTRACKER_PROPERTIESBOX.M with the given input arguments.
%
%      MARKERTRACKER_PROPERTIESBOX('Property','Value',...) creates a new MARKERTRACKER_PROPERTIESBOX or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MarkerTracker_PropertiesBox_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MarkerTracker_PropertiesBox_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MarkerTracker_PropertiesBox

% Last Modified by GUIDE v2.5 03-Sep-2018 16:42:50

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MarkerTracker_PropertiesBox_OpeningFcn, ...
                   'gui_OutputFcn',  @MarkerTracker_PropertiesBox_OutputFcn, ...
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


% --- Executes just before MarkerTracker_PropertiesBox is made visible.
function MarkerTracker_PropertiesBox_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MarkerTracker_PropertiesBox (see VARARGIN)

% Choose default command line output for MarkerTracker_PropertiesBox
handles.output = hObject;

% handle inputs (should be UserData from the main GUI
if nargin<4 || ~isstruct(varargin{1})
    warndlg('Must input UserData struct to this GUI!');
else
    handles.UserData=varargin{1};
end

% initialize listbox of color channels 
handles.ColorChannelsList.String=handles.UserData.channelNames;

handles.PropBoxUserData.maskAlpha=0.2;
handles.PropBoxUserData.maskColor=[0 0.3 1];


% get marker image
center=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessLocation;
size=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).guessSize;
handles.PropBoxUserData.dispImage=handles.UserData.currentFrame(...
    round(center(2)-size(2)/2):round(center(2)+size(2)/2),...
    round(center(1)-size(1)/2):round(center(1)+size(1)/2),:);

% Set up gui elements with passed in data
handles.MarkerNameText.String=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).name;

handles=changeSelectedChannel(handles,1);

% set min area and max aspect ratio
handles=changeMaxAspectRatio(handles,handles.UserData.markersInfo(...
    handles.UserData.currentMarkerInds(1)).searchProperties.maxAspectRatio);
handles=changeMinArea(handles,handles.UserData.markersInfo(...
    handles.UserData.currentMarkerInds(1)).searchProperties.minArea);

% set figure callbacks (scroll wheel use, and left and right buttons)
set(gcf,'windowscrollWheelFcn', {@ScrollWheel_Callback,hObject});

% add listener for slider value changes
addlistener(handles.LowerThresholdSlider,'ContinuousValueChange',@(src,event) LowerThresholdSlider_Callback(src,event,handles));
addlistener(handles.UpperThresholdSlider,'ContinuousValueChange',@(src,event) UpperThresholdSlider_Callback(src,event,handles));
addlistener(handles.MaxAspectRatioSlider,'ContinuousValueChange',@(src,event) MaxAspectRatioSlider_Callback(src,event,handles));
addlistener(handles.MinAreaSlider,'ContinuousValueChange',@(src,event) MinAreaSlider_Callback(src,event,handles));

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MarkerTracker_PropertiesBox wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure

uiresume(hObject)
guidata(hObject,handles);


% --- Outputs from this function are returned to the command line.
function varargout = MarkerTracker_PropertiesBox_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.UserData;
delete(hObject);


function ScrollWheel_Callback(src,callbackdata,hObject)
% go up or down on the selected channel list
handles=guidata(hObject);

if callbackdata.VerticalScrollCount>0
    newChannelInd=min(handles.UserData.nColorChannels,...
        handles.PropBoxUserData.currentChannelInd+1);
else
    newChannelInd=max(1,handles.PropBoxUserData.currentChannelInd-1);
end

handles=changeSelectedChannel(handles,newChannelInd);

guidata(hObject, handles);


function handles=changeSelectedChannel(handles,selectedChannelInd)
% update the ind in handles
handles.PropBoxUserData.currentChannelInd=selectedChannelInd;

% redraw maker display
drawMarkerImage(handles)

% update gui elements
% list box
handles.ColorChannelsList.Value=selectedChannelInd;

% hist eq option
handles.UseContrastEnhancementCheckBox.Value=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1))...
    .searchProperties.useContrastEnhancement(selectedChannelInd);

% channel option
handles.UseChannelCheckBox.Value=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1))...
    .searchProperties.useChannels(selectedChannelInd);

% update thresholds
handles=changeChannelThresholds(handles,handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1))...
    .searchProperties.thresholds(selectedChannelInd,:));



function handles=changeChannelThresholds(handles,thresholds)
% update the threshold value
handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.thresholds(...
    handles.PropBoxUserData.currentChannelInd,:)=thresholds;

% redraw
drawMarkerImage(handles)

% update sliders
handles.LowerThresholdSlider.Value=thresholds(1);
handles.UpperThresholdSlider.Value=thresholds(2);

% update textboxes
handles.LowerThresholdInput.String=num2str(thresholds(1));
handles.UpperThresholdInput.String=num2str(thresholds(2));



function handles=changeMaxAspectRatio(handles,maxAspectRatio)
% update the threshold value
handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.maxAspectRatio=maxAspectRatio;

% redraw
drawMarkerImage(handles)

% update sliders
handles.MaxAspectRatioSlider.Value=maxAspectRatio;

% update textbox
handles.MaxAspectRatioInput.String=num2str(maxAspectRatio);


function handles=changeMinArea(handles,minArea)
% update the threshold value
handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.minArea=minArea;

% redraw
drawMarkerImage(handles)

% update sliders
handles.MinAreaSlider.Value=minArea;

% update textbox
handles.MinAreaInput.String=num2str(minArea);


function drawMarkerImage(handles)
% draw the marker with threshold blobs and centroids
figure(handles.figure1);
axes(handles.MarkerDisplayAxes);

% get display image, display mask, centroid, and marker position
properties=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties;
properties.contrastEnhancementLevel=handles.UserData.contrastEnhancementLevel;
[markerPos, ~, ~, ~, ~, allDispImages, allMasks, allCentroids]=TrackerFunctions.findMarkerPos(...
    handles.PropBoxUserData.dispImage, handles.ColorChannelsList.String, properties,...
    handles.UserData.minConvex);
channelInd=handles.PropBoxUserData.currentChannelInd;

% save marker position

% show image
imshow(allDispImages{channelInd});
axis off
hold on

enabled=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.useChannels(...
        handles.PropBoxUserData.currentChannelInd);
    
if enabled
    % show mask
    maskImage=repmat(reshape(handles.PropBoxUserData.maskColor,[1 1 3]),...
        size(allMasks{channelInd},1),size(allMasks{channelInd},2));
    maskImage=maskImage.*repmat(allMasks{channelInd},1,1,3);
    maskAlpha=handles.PropBoxUserData.maskAlpha*ones(size(allMasks{channelInd}));
    mask_handle=image(maskImage);
    set(mask_handle, 'AlphaData', maskAlpha);
    
    % show centroid
    if ~isempty(allCentroids{channelInd})
        plot(allCentroids{channelInd}(1),allCentroids{channelInd}(2),'.r','MarkerSize',10)
    end
end

% show marker position
if ~isnan(markerPos)
    plot(markerPos(1),markerPos(2),'*k')
end
hold off


% finally show histogram
threshs=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.thresholds(...
        handles.PropBoxUserData.currentChannelInd,:);
axes(handles.HistogramAxes)
imhist(allDispImages{channelInd});
set(gca,'YScale','log')
hold on;
line(repmat(threshs(1),1,2),[1 numel(allDispImages{channelInd})],'color','r','linewidth',2)
line(repmat(threshs(2),1,2),[1 numel(allDispImages{channelInd})],'color',[0.7 0 0],'linewidth',2)
hold off


% --- Executes on slider movement.
function LowerThresholdSlider_Callback(hObject, eventdata, handles)
% hObject    handle to LowerThresholdSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles=guidata(hObject);

thresholds=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.thresholds(...
    handles.PropBoxUserData.currentChannelInd,:);
value=round(hObject.Value);
thresholds(1)=value;
handles=changeChannelThresholds(handles,thresholds);

guidata(hObject,handles)

% --- Executes during object creation, after setting all properties.
function LowerThresholdSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to LowerThresholdSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on selection change in ColorChannelsList.
function ColorChannelsList_Callback(hObject, eventdata, handles)
% hObject    handle to ColorChannelsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ColorChannelsList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ColorChannelsList
handles=guidata(hObject);

newSelection=hObject.Value;
handles=changeSelectedChannel(handles,newSelection);

guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function ColorChannelsList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ColorChannelsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function UpperThresholdSlider_Callback(hObject, eventdata, handles)
% hObject    handle to UpperThresholdSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles=guidata(hObject);

thresholds=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.thresholds(...
    handles.PropBoxUserData.currentChannelInd,:);
value=round(hObject.Value);
thresholds(2)=value;
handles=changeChannelThresholds(handles,thresholds);

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function UpperThresholdSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to UpperThresholdSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in UseChannelCheckBox.
function UseChannelCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to UseChannelCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of UseChannelCheckBox
handles=guidata(hObject);

handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.useChannels(...
    handles.PropBoxUserData.currentChannelInd)=hObject.Value;

drawMarkerImage(handles)

guidata(hObject,handles);


% --- Executes on button press in UseContrastEnhancementCheckBox.
function UseContrastEnhancementCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to UseContrastEnhancementCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of UseContrastEnhancementCheckBox
handles=guidata(hObject);

handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.useContrastEnhancement(...
    handles.PropBoxUserData.currentChannelInd)=hObject.Value;

drawMarkerImage(handles)

guidata(hObject,handles);


function LowerThresholdInput_Callback(hObject, eventdata, handles)
% hObject    handle to LowerThresholdInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of LowerThresholdInput as text
%        str2double(get(hObject,'String')) returns contents of LowerThresholdInput as a double
handles=guidata(hObject);

thresholds=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.thresholds(...
    handles.PropBoxUserData.currentChannelInd,:);
value=round(str2double(hObject.String));
thresholds(1)=value;
handles=changeChannelThresholds(handles,thresholds);

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function LowerThresholdInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to LowerThresholdInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function UpperThresholdInput_Callback(hObject, eventdata, handles)
% hObject    handle to UpperThresholdInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of UpperThresholdInput as text
%        str2double(get(hObject,'String')) returns contents of UpperThresholdInput as a double
handles=guidata(hObject);

thresholds=handles.UserData.markersInfo(handles.UserData.currentMarkerInds(1)).searchProperties.thresholds(...
    handles.PropBoxUserData.currentChannelInd,:);
value=round(str2double(hObject.String));
thresholds(2)=value;
handles=changeChannelThresholds(handles,thresholds);

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function UpperThresholdInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to UpperThresholdInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function MaxAspectRatioSlider_Callback(hObject, eventdata, handles)
% hObject    handle to MaxAspectRatioSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles=guidata(hObject);

value=hObject.Value;
handles=changeMaxAspectRatio(handles,value);

guidata(hObject,handles)



% --- Executes during object creation, after setting all properties.
function MaxAspectRatioSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MaxAspectRatioSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function MinAreaSlider_Callback(hObject, eventdata, handles)
% hObject    handle to MinAreaSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles=guidata(hObject);

value=round(hObject.Value);
handles=changeMinArea(handles,value);

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function MinAreaSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MinAreaSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function MaxAspectRatioInput_Callback(hObject, eventdata, handles)
% hObject    handle to MaxAspectRatioInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MaxAspectRatioInput as text
%        str2double(get(hObject,'String')) returns contents of MaxAspectRatioInput as a double
handles=guidata(hObject);

value=str2double(hObject.String);
handles=changeMaxAspectRatio(handles,value);

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function MaxAspectRatioInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MaxAspectRatioInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function MinAreaInput_Callback(hObject, eventdata, handles)
% hObject    handle to MinAreaInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MinAreaInput as text
%        str2double(get(hObject,'String')) returns contents of MinAreaInput as a double
handles=guidata(hObject);

value=round(str2double(hObject.String));
handles=changeMinArea(handles,value);

guidata(hObject,handles)


% --- Executes during object creation, after setting all properties.
function MinAreaInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MinAreaInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in DynamicThreshCheckBox.
function DynamicThreshCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to DynamicThreshCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of DynamicThreshCheckBox


% --- Executes on button press in DynamicAspectRatioCheckBox.
function DynamicAspectRatioCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to DynamicAspectRatioCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of DynamicAspectRatioCheckBox


% --- Executes on button press in DynamicMarkerAreaCheckBox.
function DynamicMarkerAreaCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to DynamicMarkerAreaCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of DynamicMarkerAreaCheckBox


% 
