function varargout = MarkerTracker_ModelDefiner(varargin)
% MARKERTRACKER_MODELDEFINER MATLAB code for MarkerTracker_ModelDefiner.fig
%      MARKERTRACKER_MODELDEFINER, by itself, creates a new MARKERTRACKER_MODELDEFINER or raises the existing
%      singleton*.
%
%      H = MARKERTRACKER_MODELDEFINER returns the handle to a new MARKERTRACKER_MODELDEFINER or the handle to
%      the existing singleton*.
%
%      MARKERTRACKER_MODELDEFINER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARKERTRACKER_MODELDEFINER.M with the given input arguments.
%
%      MARKERTRACKER_MODELDEFINER('Property','Value',...) creates a new MARKERTRACKER_MODELDEFINER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MarkerTracker_ModelDefiner_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MarkerTracker_ModelDefiner_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MarkerTracker_ModelDefiner

% Last Modified by GUIDE v2.5 26-Sep-2018 23:10:07

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MarkerTracker_ModelDefiner_OpeningFcn, ...
                   'gui_OutputFcn',  @MarkerTracker_ModelDefiner_OutputFcn, ...
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


% --- Executes just before MarkerTracker_ModelDefiner is made visible.
function MarkerTracker_ModelDefiner_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MarkerTracker_ModelDefiner (see VARARGIN)

% Choose default command line output for MarkerTracker_ModelDefiner
handles.output = hObject;

% handle inputs (should be UserData from the main GUI)
if nargin<4 || ~isstruct(varargin{1})
    warndlg('Must input UserData struct to this GUI!');
else
    handles.UserData=varargin{1};
end

% initialize listboxes
handles.MarkerList.String={handles.UserData.markersInfo.name}';
handles=changeSelectedMarker(handles,1);

handles.ExternFilesList.String=handles.UserData.kinModel.externFileNames;

% set figure callbacks (scroll wheel use, and left and right buttons)
set(gcf,'windowscrollWheelFcn', {@ScrollWheel_Callback,hObject});

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MarkerTracker_ModelDefiner wait for user response (see UIRESUME)
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
function varargout = MarkerTracker_ModelDefiner_OutputFcn(hObject, eventdata, handles) 
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
    handles.AnchorList.Value=min(handles.AnchorList.Value+1,length(handles.AnchorList.String));
else
    handles.AnchorList.Value=max(handles.AnchorList.Value-1,1);
end

guidata(hObject, handles);


function handles=changeSelectedMarker(handles,listInd)
% when selected marker is changed, need to update the anchors and model
% anchors lists

% set value
if listInd<0 || listInd>length(handles.MarkerList.String)
    return
end
handles.MarkerList.Value=listInd;

% set the angle tolerance
handles.AngleTolInput.String=num2str(handles.UserData.markersInfo(listInd).kinModelAngleTol);

% set the model anchors for the selected marker
handles.ModelAnchorsList.String=handles.UserData.markersInfo(listInd).kinModelAnchors;
handles.ModelAnchorsList.Value=1;

% finally, all the anchors (get all anchors, then remove any that were
% in the model anchors list)
remainingNames=setdiff(string(handles.UserData.kinModel.allPossibleAnchors),...
    [string(handles.ModelAnchorsList.String); string(handles.MarkerList.String(listInd))],'stable');
if isempty(remainingNames)
    handles.AnchorList.String={};
else
    handles.AnchorList.String=cellstr(remainingNames);
end
handles.AnchorList.Value=1;


% --- Executes on selection change in MarkerList.
function MarkerList_Callback(hObject, eventdata, handles)
% hObject    handle to MarkerList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns MarkerList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from MarkerList
handles=guidata(hObject);

handles=changeSelectedMarker(handles,hObject.Value);

guidata(hObject,handles)



% --- Executes during object creation, after setting all properties.
function MarkerList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MarkerList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ModelAnchorsList.
function ModelAnchorsList_Callback(hObject, eventdata, handles)
% hObject    handle to ModelAnchorsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ModelAnchorsList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ModelAnchorsList


% --- Executes during object creation, after setting all properties.
function ModelAnchorsList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ModelAnchorsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in AnchorList.
function AnchorList_Callback(hObject, eventdata, handles)
% hObject    handle to AnchorList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns AnchorList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from AnchorList


% --- Executes during object creation, after setting all properties.
function AnchorList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to AnchorList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in MovePairUpButton.
function MovePairUpButton_Callback(hObject, eventdata, handles)
% hObject    handle to MovePairUpButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% move the selected anchor up on the list
if handles.ModelAnchorsList.Value>1
    %the display list
    switchInds=[handles.ModelAnchorsList.Value-1 handles.ModelAnchorsList.Value];
    handles.ModelAnchorsList.String(switchInds)=handles.ModelAnchorsList.String(fliplr(switchInds));
    
    %and the actual model anchors list
    handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors(switchInds)=...
        handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors(fliplr(switchInds));
    
    handles.ModelAnchorsList.Value=handles.ModelAnchorsList.Value-1;
end

guidata(hObject,handles);


% --- Executes on button press in MovePairDownButton.
function MovePairDownButton_Callback(hObject, eventdata, handles)
% hObject    handle to MovePairDownButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% move the selected anchor down on the list
if handles.ModelAnchorsList.Value<length(handles.ModelAnchorsList.String)
    %the display list
    switchInds=[handles.ModelAnchorsList.Value handles.ModelAnchorsList.Value+1];
    handles.ModelAnchorsList.String(switchInds)=handles.ModelAnchorsList.String(fliplr(switchInds));
    
    %and the actual model anchors list
    handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors(switchInds)=...
        handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors(fliplr(switchInds));
    
    handles.ModelAnchorsList.Value=handles.ModelAnchorsList.Value+1;
end

guidata(hObject,handles);



% --- Executes on button press in LoadMarkersButton.
function LoadMarkersButton_Callback(hObject, eventdata, handles)
% hObject    handle to LoadMarkersButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% get marker names of a different tracking session

% Open dialog to select datafile
[file,path,ind] = uigetfile({'*.mat'});
if file==0
    return
end

if (ind==1)
    
    %load data
    vars=load(fullfile(path,file));
    
    %Checks:
    if ~isfield(vars,'MARKERTRACKERGUI_UserData')
        warndlg('.mat file must contain MARKERTRACKERGUI_UserData variable!')
        return;
        
%     elseif ~isfield(vars.MARKERTRACKERGUI_UserData,'VersionNumber') || ...
%             vars.MARKERTRACKERGUI_UserData.VersionNumber~=handles.UserData.VersionNumber
%         warndlg('Loaded session must be from same GUI version!')
%         return;

    elseif any(cellfun(@(x) strcmpi(fullfile(path,file),x),handles.UserData.kinModel.externFileNames))
        warndlg('That file has already been loaded')
        return;
        
    elseif ~isfield(vars.MARKERTRACKERGUI_UserData,'nMarkers') || ...
            ~isfield(vars.MARKERTRACKERGUI_UserData,'markersInfo')
        warndlg('MARKERTRACKERGUI_UserData needs to have a nMarkers and markersInfo field!')
        return;
        
    elseif vars.MARKERTRACKERGUI_UserData.nMarkers==0
        warndlg('Session has no markers defined!')
        return;
        
    end
    
    %get all the names
    externMarkerNames={vars.MARKERTRACKERGUI_UserData.markersInfo.name}';
    
    %save external file info
    handles.UserData.kinModel.nExterns=handles.UserData.kinModel.nExterns+1;
    handles.UserData.kinModel.externFileNames(end+1)={fullfile(path,file)};
    
    %add 'Extern' to the front of marker names
    externMarkerNames=cellfun(@(x)...
        ['Extern' num2str(handles.UserData.kinModel.nExterns) ' - ' x],externMarkerNames,'UniformOutput',0);
    
    %add to all possible anchors
    handles.UserData.kinModel.allPossibleAnchors=...
        [handles.UserData.kinModel.allPossibleAnchors; externMarkerNames];
    
    %Update anchors list
    handles=changeSelectedMarker(handles,handles.MarkerList.Value);
    
    %update extern files list
    handles.ExternFilesList.String{end+1,1}=fullfile(path,file);
    
else
    warndlg('Can only read .mat files!')
    return;
end

guidata(hObject,handles)


% --- Executes on button press in AddAnchorButton.
function AddAnchorButton_Callback(hObject, eventdata, handles)
% hObject    handle to AddAnchorButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% don't do anything if nothing in anchors list
if isempty(handles.AnchorList.String)
    return
end

% move from all anchors list to model anchors list
handles.ModelAnchorsList.String(end+1)=handles.AnchorList.String(handles.AnchorList.Value);
handles.ModelAnchorsList.Value=length(handles.ModelAnchorsList.String);

handles.AnchorList.String(handles.AnchorList.Value)=[];
handles.AnchorList.Value=min(handles.AnchorList.Value,length(handles.AnchorList.String));
handles.AnchorList.Value=max(handles.AnchorList.Value,1);

% add the selected anchor to the list in the marker properties
handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors(end+1,1)=...
    handles.ModelAnchorsList.String(end);

guidata(hObject,handles);



% --- Executes on button press in RemoveAnchorButton.
function RemoveAnchorButton_Callback(hObject, eventdata, handles)
% hObject    handle to RemoveAnchorButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% don't do anything if nothing in model anchors list
if isempty(handles.ModelAnchorsList.String)
    return
end

% remove the selected anchor in the list in the marker properties
handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors(...
    handles.ModelAnchorsList.Value)=[];
if isempty(handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors)
    handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAnchors={};
end

% remove from model anchors list
handles.ModelAnchorsList.String(handles.ModelAnchorsList.Value)=[];
handles.ModelAnchorsList.Value=min(handles.ModelAnchorsList.Value,...
    length(handles.ModelAnchorsList.String));
handles.ModelAnchorsList.Value=max(handles.ModelAnchorsList.Value,1);

% redraw anchor list
remainingNames=setdiff(string(handles.UserData.kinModel.allPossibleAnchors),...
    [string(handles.ModelAnchorsList.String);...
    string(handles.MarkerList.String(handles.MarkerList.Value))],'stable');
handles.AnchorList.String=cellstr(remainingNames);

guidata(hObject,handles);



function AngleTolInput_Callback(hObject, eventdata, handles)
% hObject    handle to AngleTolInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of AngleTolInput as text
%        str2double(get(hObject,'String')) returns contents of AngleTolInput as a double
handles=guidata(hObject);

% inputted string has to be a number bigger than 0. If not, change back
if isnan(str2double(hObject.String)) || str2double(hObject.String)<0
    hObject.String=num2str(handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAngleTol);
end

% set marker model angle tolerance to the inputted value
handles.UserData.markersInfo(handles.MarkerList.Value).kinModelAngleTol=str2double(hObject.String);

guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function AngleTolInput_CreateFcn(hObject, eventdata, handles)
% hObject    handle to AngleTolInput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on selection change in ExternFilesList.
function ExternFilesList_Callback(hObject, eventdata, handles)
% hObject    handle to ExternFilesList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ExternFilesList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ExternFilesList


% --- Executes during object creation, after setting all properties.
function ExternFilesList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ExternFilesList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in DeleteMarkersButton.
function DeleteMarkersButton_Callback(hObject, eventdata, handles)
% hObject    handle to DeleteMarkersButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);

% if no extern files, do nothing
if handles.UserData.kinModel.nExterns==0
    return
end

selectedExtern=handles.ExternFilesList.Value;

% now remove all of the names with the selected extern number
% from all anchors list
handles.UserData.kinModel.allPossibleAnchors=changeExternNumbers(...
    handles.UserData.kinModel.allPossibleAnchors,selectedExtern,[]);
% and from all the markers' individual anchors lists
for iMarker=1:handles.UserData.nMarkers
    handles.UserData.markersInfo(iMarker).kinModelAnchors=changeExternNumbers(...
        handles.UserData.markersInfo(iMarker).kinModelAnchors,selectedExtern,[]);
end
    
% shift all extern numbers that are bigger than the extern we're removing
% down one
for iExtern=selectedExtern+1:handles.UserData.kinModel.nExterns
    %change all anchors list
    handles.UserData.kinModel.allPossibleAnchors=changeExternNumbers(...
        handles.UserData.kinModel.allPossibleAnchors,iExtern,iExtern-1);
    %and all markers' individual anchors lists
    
    for iMarker=1:handles.UserData.nMarkers
        handles.UserData.markersInfo(iMarker).kinModelAnchors=changeExternNumbers(...
            handles.UserData.markersInfo(iMarker).kinModelAnchors,iExtern,iExtern-1);
    end
    
end

% now redraw the lists
handles=changeSelectedMarker(handles,handles.MarkerList.Value);

% remove the currently selected extern file
handles.UserData.kinModel.externFileNames(selectedExtern)=[];
handles.UserData.kinModel.nExterns=handles.UserData.kinModel.nExterns-1;

% update list
handles.ExternFilesList.String(selectedExtern)=[];
handles.ExternFilesList.Value=min(...
    handles.UserData.kinModel.nExterns,handles.ExternFilesList.Value);
handles.ExternFilesList.Value=max(handles.ExternFilesList.Value,1);

guidata(hObject,handles)


function changedNames=changeExternNumbers(markerNames,number,newNumber)
% given a list of marker names, some of which may be extern marked, change
% the extern number to a new number (or delete those marker names if
% newNumber is set to an empty array)

if isempty(newNumber)
    namesToDelete=[];
end

% set output
changedNames=markerNames;

% get all the variables with the desired extern number
for iName=1:length(markerNames)
    
    %parse out name to see if its an extern
    parts=split(markerNames{iName});
        
    %if it is, it should have more than 1 part, and the first part should
    %have at least 6 letters
    if length(parts)==1 || length(parts{1})<=6
        continue
    end
    
    %get the number following the extern
    if strcmpi(parts{1}(1:6),'extern')
        externNumber=str2double(parts{1}(7:end));
        
        %if it matches our desired number, change, or mark for deletion
        if externNumber==number
            
            if isempty(newNumber)
                namesToDelete(end+1)=iName;
            else
                parts{1}=['Extern' num2str(newNumber)];
                changedNames(iName)=join(parts);
            end
            
        end
    end
    
end

% finally, delete if that's what we want to do
if isempty(newNumber)
    changedNames(namesToDelete)=[];    
end


% 
