function varargout = MarkerTracker_ImageProcessing(varargin)
% MARKERTRACKER_IMAGEPROCESSING MATLAB code for MarkerTracker_ImageProcessing.fig
%      MARKERTRACKER_IMAGEPROCESSING, by itself, creates a new MARKERTRACKER_IMAGEPROCESSING or raises the existing
%      singleton*.
%
%      H = MARKERTRACKER_IMAGEPROCESSING returns the handle to a new MARKERTRACKER_IMAGEPROCESSING or the handle to
%      the existing singleton*.
%
%      MARKERTRACKER_IMAGEPROCESSING('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARKERTRACKER_IMAGEPROCESSING.M with the given input arguments.
%
%      MARKERTRACKER_IMAGEPROCESSING('Property','Value',...) creates a new MARKERTRACKER_IMAGEPROCESSING or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MarkerTracker_ImageProcessing_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MarkerTracker_ImageProcessing_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MarkerTracker_ImageProcessing

% Last Modified by GUIDE v2.5 06-Sep-2018 18:40:51

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MarkerTracker_ImageProcessing_OpeningFcn, ...
                   'gui_OutputFcn',  @MarkerTracker_ImageProcessing_OutputFcn, ...
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


% --- Executes just before MarkerTracker_ImageProcessing is made visible.
function MarkerTracker_ImageProcessing_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MarkerTracker_ImageProcessing (see VARARGIN)

% Choose default command line output for MarkerTracker_ImageProcessing
handles.output = hObject;

% handle inputs (should be UserData from the main GUI
if nargin<4 || ~isstruct(varargin{1})
    warndlg('Must input UserData struct to this GUI!');
else
    handles.UserData=varargin{1};
end

% initialize sliders and input boxes
handles=changeContrast(handles, handles.UserData.globalContrast);
handles=changeBrightness(handles, handles.UserData.globalBrightness);

handles.DecorrCheckBox.Value=handles.UserData.globalDecorr;

% add listener for slider value changes
addlistener(handles.ContrastSlider,'ContinuousValueChange',@(src,event) ContrastSlider_Callback(src,event,handles));
addlistener(handles.BrightnessSlider,'ContinuousValueChange',@(src,event) BrightnessSlider_Callback(src,event,handles));

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MarkerTracker_ImageProcessing wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure

uiresume(hObject)
guidata(hObject,handles);


function drawImage(handles)
axes(handles.ImageAxes)

frame=handles.UserData.currentFrameUnprocessed;
contrast=handles.UserData.globalContrast;
brightness=handles.UserData.globalBrightness;
decorr=handles.UserData.globalDecorr;

frame=TrackerFunctions.applyImageProcessing(frame, brightness, contrast, decorr);

% show
image(frame)
axis off


function handles=changeContrast(handles,contrast)

% check that it's between 0 and 0.99
if contrast<0 || contrast > 0.99
    %if not, revert back to previous contrast value
    contrast=handles.UserData.globalContrast;
end

handles.UserData.globalContrast=contrast;

% update slider
handles.ContrastSlider.Value=contrast;

% update text box
handles.ContrastInput.String=num2str(contrast);

% redraw image
drawImage(handles);


function handles=changeBrightness(handles,brightness)

brightness=round(brightness);

% check that it's between -200 and 200
if brightness<-200 || brightness > 200
    %if not, revert back to previous brightness value
    brightness=handles.UserData.globalBrightness;
end

handles.UserData.globalBrightness=brightness;

% update slider
handles.BrightnessSlider.Value=brightness;

% update text box
handles.BrightnessInput.String=num2str(brightness);

% redraw image
drawImage(handles);


% --- Outputs from this function are returned to the command line.
function varargout = MarkerTracker_ImageProcessing_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.UserData;
delete(hObject);


% --- Executes on slider movement.
function BrightnessSlider_Callback(hObject, eventdata, handles)
% hObject    handle to BrightnessSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles=guidata(hObject);

brightness=hObject.Value;
handles=changeBrightness(handles,brightness);

guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function BrightnessSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to BrightnessSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function ContrastSlider_Callback(hObject, eventdata, handles)
% hObject    handle to ContrastSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles=guidata(hObject);

contrast=hObject.Value;
handles=changeContrast(handles,contrast);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function ContrastSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ContrastSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function BrightnessInput_Callback(hObject, eventdata, handles)
% hObject    handle to BrightnessInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of BrightnessInput as text
%        str2double(get(hObject,'String')) returns contents of BrightnessInput as a double
handles=guidata(hObject);

brightness=str2double(hObject.String);
handles=changeBrightness(handles,brightness);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function BrightnessInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to BrightnessInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ContrastInput_Callback(hObject, eventdata, handles)
% hObject    handle to ContrastInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ContrastInput as text
%        str2double(get(hObject,'String')) returns contents of ContrastInput as a double
handles=guidata(hObject);

contrast=str2double(hObject.String);
handles=changeContrast(handles,contrast);

guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function ContrastInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ContrastInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in DecorrCheckBox.
function DecorrCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to DecorrCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of DecorrCheckBox
handles=guidata(hObject);

handles.UserData.globalDecorr=hObject.Value;
drawImage(handles)

guidata(hObject,handles)

