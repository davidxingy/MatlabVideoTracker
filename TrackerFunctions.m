classdef TrackerFunctions
    methods (Static)
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Given an image and a set of thresholds for color channels of the
        % image, go through each color channel and find the centroid of the
        % resulting thresholded blobs. Find the average of all the
        % centroids of enabled color channels
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [markerPos, atEdge, multipleBlobs, markerArea, markerAspectRatio, allDispImages, allMasks, allCentroids]=...
                findMarkerPos(markerImage, channelNames, markerProperties, minConvex)
            
            %initialize outputs
            markerPos=[];
            atEdge=false;
            multipleBlobs=false;
            markerArea=[];
            markerAspectRatio=[];
            allDispImages={};
            allMasks={};
            allCentroids={};
            
            %get apsect ratio and marker area thresholds
            maxAspectRatio=markerProperties.maxAspectRatio;
            minArea=markerProperties.minArea;
            
            %go through each color channel
            for iChannel=1:length(channelNames)
                                    
                % get proper channel values
                switch channelNames{iChannel}
                    case 'Red'
                        dispImage=markerImage(:,:,1)-...
                            uint8(mean(markerImage(:,:,2),3));
                        dispImage(dispImage<0)=0;
                    case 'Green'
                        dispImage=markerImage(:,:,2)-...
                            markerImage(:,:,1)/3-markerImage(:,:,3)/3;
                        dispImage(dispImage<0)=0;
                    case 'Red/Green'
                        markerImageLAB=rgb2lab(markerImage);
                        dispImage=uint8(128+2*markerImageLAB(:,:,2));
                    case 'Blue'
                        dispImage=markerImage(:,:,3)-...
                            markerImage(:,:,1)/3-markerImage(:,:,2)/3;
                        dispImage(dispImage<0)=0;
                    case 'Hue'
                        markerImageHSV=rgb2hsv(markerImage)*255;
                        dispImage=uint8(markerImageHSV(:,:,1));
                    case 'Saturation'
                        markerImageHSV=rgb2hsv(markerImage)*255;
                        dispImage=uint8(markerImageHSV(:,:,2));
                    case 'Value'
                        markerImageHSV=rgb2hsv(markerImage)*255;
                        dispImage=uint8(markerImageHSV(:,:,3));
                    case 'Grey'
                        markerImageGrey=rgb2gray(markerImage);
                        dispImage=markerImageGrey;
                end
                
                
                % do contrast enhancement if selected
                useContrastEnhancement=markerProperties.useContrastEnhancement(iChannel);
                if useContrastEnhancement
                    dispImage=imadjust(dispImage,...
                        stretchlim(dispImage,markerProperties.contrastEnhancementLevel),[]);
                end
                
                
                allDispImages{iChannel}=dispImage;

                %don't do any more if not enabled
                enabled=markerProperties.useChannels(iChannel);
                if ~enabled
                    continue
                end
                    
                %get channel thresholds
                thresh=markerProperties.thresholds(iChannel,:);

                %calculate the mask and centroid, aspect ratio, and area
                [mask, centroid, multipleBlobs, aspectRatio, area]=...
                    TrackerFunctions.blobThresh(dispImage,thresh,maxAspectRatio,minArea,minConvex);
                
                %determine if the blobs are touching the edge
                maskEdges=[mask(1,:) mask(end,:) mask(:,1)' mask(:,end)'];
                if any(maskEdges)
                    atEdge=true;
                else
                    atEdge=false;
                end
                
                %add to all masks, centroids
                allMasks{iChannel}=mask;
                allCentroids{iChannel}=centroid;
                
                %add centroid, area, aspect ratio to list to be averaged at
                %the end of the for loop
                markerPos=[markerPos; centroid];
                markerAspectRatio=[markerAspectRatio aspectRatio];
                markerArea=[markerArea area];

            end
            
            %position, aspect ratio, and area will the average of all chans
            markerPos=mean(markerPos,1);
            markerAspectRatio=mean(markerAspectRatio);
            markerArea=mean(markerArea);
            
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Threshold array and find centroid of thresholded blob
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [mask, centroid, multipleBlobs, aspectRatio, area]=blobThresh(...
                image,thresholds,maxAspectRatio,minArea,minConvex)
            
            %initialize outputs
            mask=[];
            centroid=[];
            aspectRatio=[];
            area=[];
            multipleBlobs=false;
            
            % get mask
            mask=image>=thresholds(1) & image<=thresholds(2);
            
            %now separate blobs and get their stats
            regions = bwconncomp(mask);
            stats = regionprops(regions, 'Area','MajorAxisLength','MinorAxisLength','Centroid','ConvexArea');
            
            if isempty(stats)
                return
            end
                
            %calculate aspect ratio and convex area ratio
            for iBlob=1:length(stats)
                stats(iBlob).AspectRatio=stats(iBlob).MajorAxisLength/stats(iBlob).MinorAxisLength;
                stats(iBlob).ConvexRatio=stats(iBlob).Area/stats(iBlob).ConvexArea;
            end
            
            %if regions don't meet convex ratio critereon, then try to
            %separate into multiple blobs
            nMergedBlobs=0;
            for iBlob=1:length(stats)
                if stats(iBlob).ConvexRatio<minConvex
                    nMergedBlobs=nMergedBlobs+1;
                    separatedRegions(nMergedBlobs)=iBlob;
                    
                    %do watershedding
                    blobMask=ismember(labelmatrix(regions), iBlob);
                    distTransform = -bwdist(~blobMask);
                    filtDistTransform = imimposemin(distTransform,imextendedmin(distTransform,1));
                    basins = watershed(filtDistTransform);
                    blobMask(basins==0)=0;
                    
                    %get stats of the new separated blobs
                    newRegions{nMergedBlobs} = bwconncomp(blobMask);
                    newStats{nMergedBlobs} = regionprops(newRegions{nMergedBlobs}, 'Area',...
                        'MajorAxisLength','MinorAxisLength','Centroid','ConvexArea');
                    %calculate aspect ratio and convex area ratio
                    for iNewBlob=1:length(newStats{nMergedBlobs})
                        newStats{nMergedBlobs}(iNewBlob).AspectRatio=...
                            newStats{nMergedBlobs}(iNewBlob).MajorAxisLength/...
                            newStats{nMergedBlobs}(iNewBlob).MinorAxisLength;
                        newStats{nMergedBlobs}(iNewBlob).ConvexRatio=...
                            newStats{nMergedBlobs}(iNewBlob).Area/...
                            newStats{nMergedBlobs}(iNewBlob).ConvexArea;
                    end
                        
                end
            end
            
            %remove the old connected blobs and put in the separated blobs
            if nMergedBlobs>0
                stats(separatedRegions)=[];
                stats=[stats; cat(1,newStats{:})];
                regions.NumObjects=regions.NumObjects-nMergedBlobs+length(cat(1,newStats{:}));
                regions.PixelIdxList(separatedRegions)=[];
                tmp=[newRegions{:}];
                regions.PixelIdxList=[regions.PixelIdxList [tmp.PixelIdxList]];
            end
            
            %filter blobs that don't meet critereon
            regionIDs = find([stats.Area] > minArea & [stats.AspectRatio] < maxAspectRatio);
            mask = ismember(labelmatrix(regions), regionIDs);
            
            %determine if only one blob left
            if length(unique(regionIDs))>1
                multipleBlobs=true;
            else
                multipleBlobs=false;
            end
            
            if ~isempty(regionIDs)
                %now, use the blob that is closest to the original estimate
                %(center of the image)
                imageCent=size(image')/2;
                centroids=cat(1,stats(regionIDs).Centroid);
                distances=sqrt(sum((centroids-imageCent).^2,2));
                [~,finalBlobInd]=min(distances);
                
                centroid=stats(regionIDs(finalBlobInd)).Centroid;
                aspectRatio=stats(regionIDs(finalBlobInd)).AspectRatio;
                area=stats(regionIDs(finalBlobInd)).Area;
            end
            
        end
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to get marker location given some estimate and search
        % radius
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [markerPos, boxSize, multipleBlobs, markerArea, markerAspectRatio]=...
                findMarkerPosInFrame(frame,channelNames,startBoxSize,markerProperties,startPos,searchRadius,minConvex)
                switch lower(markerProperties.trackType)
                    case 'manual'
                        markerPos=startPos;
                        boxSize=startBoxSize;
                        multipleBlobs=false;
                        markerArea=[];
                        markerAspectRatio=[];
                    case 'auto'

                        %find the marker position at the guess location
                        [markerPos, atEdge, multipleBlobs, markerArea, markerAspectRatio]=...
                            TrackerFunctions.findMarkerPos(frame(...
                            round(startPos(2)-startBoxSize(2)-searchRadius):...
                            round(startPos(2)+startBoxSize(2)+searchRadius),...
                            round(startPos(1)-startBoxSize(1)-searchRadius):...
                            round(startPos(1)+startBoxSize(1)+searchRadius),:),...
                            channelNames,markerProperties,minConvex);
                        
                        
                        if isempty(markerPos)
                            %wasn't able to find the marker with these
                            %channels
                            markerPos=[nan nan];
                            boxSize=[nan nan];
                            return
                        else
                            %get the marker position relative to whole
                            %frame (not just the search box)
                            markerPos=markerPos+0.5+...
                                [round(startPos(1)-startBoxSize(1)-searchRadius)-1,...
                                round(startPos(2)-startBoxSize(2)-searchRadius)-1];
                            boxSize=startBoxSize;
                        end
                        
                        
                        %refind if mask is touching an edge
                        if atEdge
                            startPos=markerPos;
                            [markerPos, atEdge, multipleBlobs, markerArea, markerAspectRatio]=...
                                TrackerFunctions.findMarkerPos(frame(...
                                round(startPos(2)-startBoxSize(2)-searchRadius):...
                                round(startPos(2)+startBoxSize(2)+searchRadius),...
                                round(startPos(1)-startBoxSize(1)-searchRadius):...
                                round(startPos(1)+startBoxSize(1)+searchRadius),:),...
                                channelNames,markerProperties,minConvex);
                            
                            if isempty(markerPos)
                                %wasn't able to find the marker with these
                                %channels
                                markerPos=[nan nan];
                                boxSize=[nan nan];
                                return
                            else
                                %get the marker position relative to whole
                                %frame (not just the search box)
                                markerPos=markerPos+0.5+...
                                    [startPos(1)-startBoxSize(1)-searchRadius-1,...
                                    startPos(2)-startBoxSize(2)-searchRadius-1];
                                boxSize=startBoxSize;
                            end
                        end
                        
                    otherwise
                        markerPos=[nan nan];
                        boxSize=[nan nan];
                        return
                end

        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to estimate new marker location based a VAR model
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function pos=predictPosVAR(oldPos,coeffs,inputs)
            
            %just multiply inputs with coeffs to get estimated velocity
            velocityEst=modelParams.Coeffs*[modelInputs; 1];
            
            %new position is old position + velocity
            pos=oldPos+velocityEst';
                    
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to estimate new marker location based a kalman filter
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function pos=predictPosKalman(oldPos,kalmanFilterObj,inputs)
            
            %just run the filter
            velocityEst=predict(kalmanFilterObj,inputs);
            pos=oldPos+velocityEst;

        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to estimate new marker location using spline
        % extrapolation
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function pos=predictPosSpline(previousPos,nFilterPoints)
            
            %first filter the previous points to get more smooth data
            smoothedPrevPos=filtfilt(ones(1,nFilterPoints)/nFilterPoints,...
                1, previousPos);
            
            %get rid of extra points that were used for filtering
            smoothedPrevPos=smoothedPrevPos(nFilterPoints:end,:);
            
            %if not enough points, just return nans
            if sum(~isnan(smoothedPrevPos))<2
                pos=[NaN NaN];
                return
            end
            
            %now do spline extrapolation
            pos(1)=spline(1:size(smoothedPrevPos,1),...
                smoothedPrevPos(:,1),size(smoothedPrevPos,1)+1);
            
            pos(2)=spline(1:size(smoothedPrevPos,1),...
                smoothedPrevPos(:,2),size(smoothedPrevPos,1)+1);
            
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to train a predictive model
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function modelParams=trainPredModel(input,output,modelType)
            
            switch lower(modelType)
                case 'var'
                    %VAR model
                    modelParams.Coeffs=output\[input ones(size(input,1),1)];
                    
                case 'kalman'
                    %kalman filter using vision.KalmanFilter object
                    
                    Coeffs=output\input;
                    A=Coeffs(:,1:size(output,2));
                    B=Coeffs(:,size(output,2)+1:end);
                    Q=(output-input*Coeffs')'*(output-input*Coeffs')/(size(output,1)-2);
                    C=[1 0;0 1];
                    R=0;
                    
                    modelParams.kalmanFilterObj=...
                        vision.KalmanFilter(A,C,B,'ProcessNoise',Q,'MeasurementNoise',R);                    
                    
            end
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to update kalman filter object (adjust gain)
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function modelUpdated=updateModel(modelType,model,values)
            
            switch lower(modelType)
                case 'kalman'
                    %kalman filter
                    correct(model.kalmanFilterObj,values);
                    modelUpdated=model;
                    
                otherwise
                    modelUpdated=model;
            
            end
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Old function to map markers to joints for setting up the 
        % kinematic limb model I used to use
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function jointInds=defineLimbModel(markerNames,markerInds)
            
            while true
                %first specifiy if arm or leg
                resp=inputdlg('Arm or Leg Model?');
                if isempty(resp) || isempty(resp{1})
                    jointInds = [];
                    return
                end
                
                if strcmpi(resp{1}, 'arm')
                    %define arm joints
                    jointNames={'Scapula','Shoulder','Elbow','Wrist','Knuckle','Finger'};
                    break
                elseif strcmpi(resp{1}, 'leg')
                    %define leg joints
                    jointNames={'Crest','Hip','Knee','Ankle','Knuckle','Toe'};
                    break
                end
            end
            
            for iJoint=1:length(jointNames)
                                
                while true
                    %keep looping until user types in a valid marker name
                    %(or presses cancel)
                    
                    %ask user for marker name corresponding to joint
                    resp=inputdlg(['Type in marker name of ' jointNames{iJoint} ' joint: ']);
                    if isempty(resp) || isempty(resp{1})
                        jointInds = [];
                        return
                    end
                    
                    %compare input to the cell array of marker names
                    matchInds=find(cellfun(@(x) strcmpi(x,resp{1}),markerNames));
                    if isempty(matchInds)
                        %ask again
                        continue
                    elseif length(matchInds)>1
                        %very strange, shouldn't happen
                        warndlg('Two markers found with that name, aborting model setup')
                    elseif length(matchInds)==1
                        %add to list, move onto next joint
                        jointInds(iJoint)=markerInds(matchInds);
                        break
                    end
                    
                end
            end
            
        end
        
                
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to calculate the angle and distance between two points  
        % given tracked data. Used to train the kinematic model
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [angles,lengths]=calcAngleAndLengths(marker1Data,marker2Data)
            %The second marker will always be the origin
            angles=atan2d(marker1Data(:,2)-marker2Data(:,2),marker1Data(:,1)-marker2Data(:,1));
            lengths=sqrt((marker1Data(:,2)-marker2Data(:,2)).^2+(marker1Data(:,1)-marker2Data(:,1)).^2);
        end
        
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function which, given a set of markers which are tracked, and a
        % set which needs to be estimated, and the list of anchor pairs,
        % outputs the index of anchor pairs for training and index of
        % anchor pairs for outputting of the kinematic model
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [inputInds,inputMarkerInds,outputInds,outputAnchorInds]=determinePairings(...
                trackedMarkerNames,desiredMarkerNames,desiredMarkerOrders,pairings)
            
            allAnchors=string(cat(1,desiredMarkerOrders{:})); %for now, concatenate all anchors for all markers together
            anchorBoundaries=cellfun(@length,desiredMarkerOrders); %to split the anchors up again, save the boundaries
            
            %preallocate matrices
            markerFound=zeros(2,size(pairings,2),length(trackedMarkerNames));
            allAnchorsFound=false(size(allAnchors,1),1);

            for iMarker=1:length(trackedMarkerNames)
                markerFound(:,:,iMarker)=trackedMarkerNames(iMarker)==pairings;
                allAnchorsFound(trackedMarkerNames(iMarker)==allAnchors)=true;
            end
            %concatonate all markerFound together, and the columns where both top and bottom names are found are
            %the list of all possible input Inds
            allFound=sum(markerFound,3);
            inputInds=find(all(allFound));
            
            %get which tracked marker names correspond to each input
            %pair ind
            inputMarkerInds=nan(2,length(inputInds)); %preallocate
            for iInd=1:length(inputInds)
                %take the slice for the current found pair
                pairingNameInds=squeeze(markerFound(:,inputInds(iInd),:));
                %get the index of the top row (first marker)
                inputMarkerInds(1,iInd)=find(pairingNameInds(1,:));
                %get the index of the bottom row (second marker)
                inputMarkerInds(2,iInd)=find(pairingNameInds(2,:));
            end
            
            %now for the output inds            
            %split up all found Anchors to each marker
            allAnchorsFound=mat2cell(allAnchorsFound,anchorBoundaries,1)';
            outputInds=nan(length(desiredMarkerNames),2); %set all to nan for now
            outputAnchorInds = [];
            
            for iMarker=1:length(desiredMarkerNames)
                %for each desired marker, get the tracked anchor for that marker with
                %the smallest index and that will be the one used to
                %estimate the marker
                if ~isempty(allAnchorsFound{iMarker}) && ~isempty(find(allAnchorsFound{iMarker},1))
                    desiredAnchorName=desiredMarkerOrders{iMarker}(find(allAnchorsFound{iMarker},1)); %name of the anchor
                    %get the pair that has both the desired anchor name and
                    %the desired marker name (note that only one pair
                    %should have both since we removed any redundancies)
                    hasNames = pairings==desiredAnchorName | pairings==desiredMarkerNames(iMarker);
                    outputInds(iMarker,2)=find(all(hasNames)); %second column indicates which pair
                    outputInds(iMarker,1)=find(pairings(:,all(hasNames))==desiredMarkerNames(iMarker)); %first column indicates which row in pairing
                    
                    outputAnchorInds(iMarker)=find(desiredAnchorName==trackedMarkerNames); %finally, get the anchor position
                end
            end
            
        end
        
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to estimate joint positions
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function ests=kinModelEstPositions(inputData, anchorPositions, inputInds, trainingData,...
                outputInds, minNumInputs, k, kNNTol)
            
            ests=repmat([NaN NaN],size(outputInds,1),1);

            %Need at least minInput parameters to try to estimate the remaining
            %missing ones
            if length(inputInds)<minNumInputs
                return
            end
            
            %pull out the training data for pairings that have input data
            modelValues=trainingData(:,inputInds,:);
            outputEstValues=trainingData(:,outputInds(:,2),:);
            
            %remove any points that have nans in the dimension
            nanInds=unique([find(any(isnan(modelValues(:,:,1)),2)); find(any(isnan(outputEstValues(:,:,1)),2))]);
            modelValues(nanInds,:,:)=[];
            outputEstValues(nanInds,:,:)=[];
            if isempty(modelValues)
                return
            end
            
            %now use the kNN regression to find the closest k points to the
            %input vector (using euclidian norm)
            %for now, just use angles to calculated the distances
%             
%             %to avoid high dimensionaliy, do pca
%             if size(modelValues,1)>2*minNumInputs
%                 [pcaCoefs\, SCORE] = pca(squeeze(modelValues(:,:,1)));
%             end
            
            diffs=angdiff(squeeze(modelValues(:,:,1))/180*pi,repmat(inputData(1,:)/180*pi,size(modelValues,1),1))*180/pi;
            distances=zeros(size(modelValues,1),1);
            for iDim=1:size(modelValues,2)
                distances=distances+diffs(:,iDim).^2;
            end
            distances=sqrt(distances);
            
            %indices of the k nearest neighbors:
            [~, pointInds]=sort(distances);
            NNInds=pointInds(1:k);
            
            %now estimate the position of the missing markers
            for iMarker=1:size(outputInds,1)
                
                %skip if nan
                if isnan(outputInds(iMarker,1))
                    continue
                end
                
                %see if its the first or second row of anchors
                
                %estimate angle and lengths from nearest neighbors
                [angle, angleSTD]=TrackerFunctions.getCircStatsDegrees(...
                    outputEstValues(NNInds,iMarker,1));
                distance=nanmean(outputEstValues(NNInds,iMarker,2));
                
                %the spread (std) of the nearest neighbor values
                %must be within a specifiled tolerance
                if angleSTD>kNNTol(iMarker)
                    continue
                end
                
                %Since the angle is defined using the second marker as the
                %origin, if the desired marker is actually the second
                %marker, we need to switch the origin to the first marker
                %(the anchor) and to do that, add or subtract 180 degrees
                if outputInds(iMarker,1)==2
                    angle=angle-sign(angle)*180;
                end
                
                %now calculate the location based on the location of
                %the anchor, and the angle and distance between the
                %marker and anchor
                ests(iMarker,1)=anchorPositions(iMarker,1)+cosd(angle)*distance;
                ests(iMarker,2)=anchorPositions(iMarker,2)+sind(angle)*distance;
                
            end
            
        end
        
        
            
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Old Function where I was calculating joint angles and lengths for
        % leg joints back when I was using a specific leg model for the 
        % kinematic model
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function modelParams=calcLimbJointParams(jointInds,trackedData,removeNaNs)
        
            %using leg variable names, but the same model works for arm:
            %crest -> scapula
            %hip -> shoulder
            %knee -> elbow
            %ankle -> wrist
            %knuckle -> knuckle
            %finger -> toe
            
            %****Also Note that since the "positions" are actually the
            %frame indices, and the vertical frame index starts at 1 at the
            %top, and the index goes up as we move down the frame, positive
            %changes in y are actally negative!****
            
            %get the data for each joint
            crest=squeeze(trackedData(jointInds(1),:,:));
            hip=squeeze(trackedData(jointInds(2),:,:));
            knee=squeeze(trackedData(jointInds(3),:,:));
            ankle=squeeze(trackedData(jointInds(4),:,:));
            knuckle=squeeze(trackedData(jointInds(5),:,:));
            toe=squeeze(trackedData(jointInds(6),:,:));
            
            %squeeze function defaults to a column vector when theres only
            %1 dimension, but I want row vector
            if size(crest,2)==1
                crest=crest';
                hip=hip';
                knee=knee';
                ankle=ankle';
                knuckle=knuckle';
                toe=toe';
            end
            
            %only keep data values that actually have been tracked
            if removeNaNs
                trackedInds=find(all(~isnan([crest hip knee ankle knuckle toe]),2));
                modelParams.nPoints=length(trackedInds);
                
                crest=crest(trackedInds,:);
                hip=hip(trackedInds,:);
                knee=knee(trackedInds,:);
                ankle=ankle(trackedInds,:);
                knuckle=knuckle(trackedInds,:);
                toe=toe(trackedInds,:);
            end
            
            %save limb segment lengths into model
            modelParams.pelvisLength=sqrt((crest(:,1)-hip(:,1)).^2+(crest(:,2)-hip(:,2)).^2);
            modelParams.thighLength=sqrt((hip(:,1)-knee(:,1)).^2+(hip(:,2)-knee(:,2)).^2);
            modelParams.shinLength=sqrt((knee(:,1)-ankle(:,1)).^2+(knee(:,2)-ankle(:,2)).^2);
            modelParams.footLength=sqrt((ankle(:,1)-knuckle(:,1)).^2+(ankle(:,2)-knuckle(:,2)).^2);
            modelParams.digitLength=sqrt((knuckle(:,1)-toe(:,1)).^2+(knuckle(:,2)-toe(:,2)).^2);
            
            %save joint angles into model
            %use law of cosines to calculate joint angles. Since law of
            %cosines only finds angles between 0 and 180, determine if the
            %rotation angle is clockwise (positive) or counter clockwise
            %(negative), so the final angle will be between -180 to 180
            %
            %to determine counter clockwise vs clockwise, project the line
            %of one limb segment, and see if the other joint lies above or
            %below it, eg:
            %
            %
            %                      y ^         
            %                        |   O <--Crest
            %                      __|__/ 
            %                    /   | / 
            %             Hip Angle  |/
            %       -----------/-----O<--Hip-----------> x
            %                 |    /*| 
            %                 |  / * |
            %                  /  *<-|--Projection of Pelvis segment
            %       Knee --> O   *   |
            %
            % E.g. the knee lies above the projection of the pelvis so the
            % hip angle (as calculated using the law of cosines) is 
            % positive. If the knee was below the projection, the angle
            % should be negative (i.e. we'd be rotating the thigh counter 
            % clockwise relative to the pelvis instead). However, if the 
            % crest was to the left of the hip, the opposite would be true. 
            modelParams.hipAngle=acosd(((crest(:,1)-knee(:,1)).^2+(crest(:,2)-knee(:,2)).^2-...
                modelParams.pelvisLength.^2-modelParams.thighLength.^2)./...
                (-2.*modelParams.pelvisLength.*modelParams.thighLength));
            angleSign=((hip(:,2)-crest(:,2))./(crest(:,1)-hip(:,1)).*...
                (knee(:,1)-hip(:,1)))<(hip(:,2)-knee(:,2)) == (crest(:,1)>hip(:,1));
            angleSign(angleSign==inf)=knee(angleSign==inf,1)<hip(angleSign==inf,1) ==...
                crest(angleSign==inf,2)<hip(angleSign==inf,2);  %account for vertical projection lines
            angleSign(angleSign==0)=-1;
            modelParams.hipAngle=modelParams.hipAngle.*angleSign;
            
            modelParams.kneeAngle=acosd(((hip(:,1)-ankle(:,1)).^2+(hip(:,2)-ankle(:,2)).^2-...
                modelParams.thighLength.^2-modelParams.shinLength.^2)./...
                (-2.*modelParams.thighLength.*modelParams.shinLength));
            angleSign=double(((knee(:,2)-hip(:,2))./(hip(:,1)-knee(:,1)).*...
                (ankle(:,1)-knee(:,1)))<(knee(:,2)-ankle(:,2)) == (hip(:,1)>knee(:,1)));
            angleSign(angleSign==inf)=ankle(angleSign==inf,1)<knee(angleSign==inf,1) ==...
                hip(angleSign==inf,2)<knee(angleSign==inf,2);
            angleSign(angleSign==0)=-1;
            modelParams.kneeAngle=modelParams.kneeAngle.*angleSign;
            
            modelParams.ankleAngle=acosd(((knee(:,1)-knuckle(:,1)).^2+(knee(:,2)-knuckle(:,2)).^2-...
                modelParams.shinLength.^2-modelParams.footLength.^2)./...
                (-2.*modelParams.shinLength.*modelParams.footLength));
            angleSign=((ankle(:,2)-knee(:,2))./(knee(:,1)-ankle(:,1)).*...
                (knuckle(:,1)-ankle(:,1)))<(ankle(:,2)-knuckle(:,2)) == (knee(:,1)>ankle(:,1));
            angleSign(angleSign==inf)=knuckle(angleSign==inf,1)<ankle(angleSign==inf,1) ==...
                knee(angleSign==inf,2)<ankle(angleSign==inf,2);
            angleSign(angleSign==0)=-1;
            modelParams.ankleAngle=modelParams.ankleAngle.*angleSign;
            
            modelParams.knuckleAngle=acosd(((ankle(:,1)-toe(:,1)).^2+(ankle(:,2)-toe(:,2)).^2-...
                modelParams.footLength.^2-modelParams.digitLength.^2)./...
                (-2.*modelParams.footLength.*modelParams.digitLength));
            angleSign=((knuckle(:,2)-ankle(:,2))./(ankle(:,1)-knuckle(:,1)).*...
                (toe(:,1)-knuckle(:,1)))<(knuckle(:,2)-toe(:,2)) == (ankle(:,1)>knuckle(:,1));
            angleSign(angleSign==inf)=toe(angleSign==inf,1)<knuckle(angleSign==inf,1) ==...
                ankle(angleSign==inf,2)<knuckle(angleSign==inf,2);
            angleSign(angleSign==0)=-1;
            modelParams.knuckleAngle=modelParams.knuckleAngle.*angleSign;
        
            %also save the angle between each of the joints and the crest
            %using the 4 quadrant arctan (atan2d)
            modelParams.crestHipAngle=atan2d((hip(:,2)-crest(:,2)),(crest(:,1)-hip(:,1)));
            modelParams.crestKneeAngle=atan2d((knee(:,2)-crest(:,2)),(crest(:,1)-knee(:,1)));
            modelParams.crestAnkleAngle=atan2d((ankle(:,2)-crest(:,2)),(crest(:,1)-ankle(:,1)));
            modelParams.crestKnuckleAngle=atan2d((knuckle(:,2)-crest(:,2)),(crest(:,1)-knuckle(:,1)));
            modelParams.crestToeAngle=atan2d((toe(:,2)-crest(:,2)),(crest(:,1)-toe(:,1)));
            
            %as well as the distance bewteen the joints and the crest
            modelParams.crestHipLength=sqrt((crest(:,1)-hip(:,1)).^2+(crest(:,2)-hip(:,2)).^2);
            modelParams.crestKneeLength=sqrt((crest(:,1)-knee(:,1)).^2+(crest(:,2)-knee(:,2)).^2);
            modelParams.crestAnkleLength=sqrt((crest(:,1)-ankle(:,1)).^2+(crest(:,2)-ankle(:,2)).^2);
            modelParams.crestKnuckleLength=sqrt((crest(:,1)-knuckle(:,1)).^2+(crest(:,2)-knuckle(:,2)).^2);
            modelParams.crestToeLength=sqrt((crest(:,1)-toe(:,1)).^2+(crest(:,2)-toe(:,2)).^2);
            
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Old function using the old limb model to estimate joint
        % positions
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function jointEsts=limbModelEst(jointInds, jointData, modelParams, minNumInputs, k, kNNTol)
            jointEsts=repmat([NaN NaN],length(jointInds),1);

            %first, calculate the angles, lengths, ect of the data that is
            %tracked
            trackedParams=TrackerFunctions.calcLimbJointParams(jointInds,jointData,false);
            
            %now, determine which model parameters we were given
            jointNames={'Crest','Hip','Knee','Ankle','Knuckle','Toe'};
            fieldNames={'hipAngle','kneeAngle','ankleAngle','knuckleAngle','crestHipAngle',...
                'crestKneeAngle','crestAnkleAngle','crestKnuckleAngle','crestToeAngle'};
            
            trackedValues=[];
            modelValues=[];
            for iField=1:length(fieldNames)
                if ~isnan(trackedParams.(fieldNames{iField}))
                    %add to the input vector and the trained data matrix for the kNN
                    trackedValues=[trackedValues trackedParams.(fieldNames{iField})];
                    modelValues=[modelValues modelParams.(fieldNames{iField})];
                end
            end
            
            %Need at least minInput parameters to try to estimate the remaining
            %missing ones
            if length(trackedValues)<minNumInputs
                return
            end
                
            %now use the kNN regression to find the closest k points to the
            %input vector (using euclidian norm)
            diffs=modelValues-repmat(trackedValues,size(modelValues,1),1);
            distances=zeros(size(modelValues,1),1);
            for iDim=1:length(trackedValues)
                distances=distances+diffs(:,iDim).^2;
            end
            distances=sqrt(distances);
            
            %indices of the k nearest neighbors:
            [~, pointInds]=sort(distances);
            nnInds=pointInds(1:k);
            
            
            %now estimate the position of the missing joints, go down the
            %joint chain progressively
            
            %CREST:
            if isnan(jointData(jointInds(1),1,1))
                
                %for crest, we will use the crest-joint angles and lengths
                %of the first joint that is tracked
                for iJoint=2:length(jointInds)
                    if ~isnan(jointData(jointInds(iJoint),1,1))
                        joint=jointNames{iJoint};
                        
                        %estimate the crest-joint angle using kNN
                        %regression
                        [nnAngleMeans, nnAngleSTDs]=TrackerFunctions.getCircStatsDegrees(...
                            modelParams.(['crest' joint 'Angle'])(nnInds));
                            
                        %the spread (std) of the nearest neighbor values
                        %must be within a specifiled tolerance
                        if nnAngleSTDs>kNNTol
                            return
                        end
                        
                        %now calculate the crest location
                        angle=nnAngleMeans;
                        dist=mean(modelParams.(['crest' joint 'Length'])(nnInds));
                        
                        jointEsts(1,1)=jointData(jointInds(iJoint),1,1)+cosd(angle)*dist;
                        jointEsts(1,2)=jointData(jointInds(iJoint),1,2)-sind(angle)*dist;
                        
                        %no need to look at any more joints
                        break
                    end
                end
                
            else
                %if it's already there, just use the tracked value
                jointEsts(1,:)=squeeze(jointData(jointInds(1),1,:));
            end
            
            
            %HIP:
            if isnan(jointData(jointInds(2),1,1))
                %for hip, we'll use the hip-crest angle and length
                
                %get angle
                if isnan(trackedParams.crestHipAngle)
                    joint=jointNames{2};
                    %use kNN to estimate the angle
                    [angle, nnAngleSTDs]=TrackerFunctions.getCircStatsDegrees(...
                        modelParams.(['crest' joint 'Angle'])(nnInds));
                    
                    %the spread (std) of the nearest neighbor values
                    %must be within a specifiled tolerance
                    if nnAngleSTDs>kNNTol
                        return
                    end
                                        
                else
                    angle=trackedParams.hipCrestAngle;
                end
                
                %get length
                dist=mean(modelParams.crestHipLength(nnInds));
                
                %get crest position
                if ~isnan(jointData(jointInds(1),1,1))
                    %crest is already tracked, use that
                    crestPos=squeeze(jointData(jointInds(1),1,:));
                else
                    %otherwise use the estimated crest position
                    crestPos=jointEsts(1,:);
                end
                    
                %calculate hip position
                jointEsts(2,1)=crestPos(1)-cosd(angle)*dist;
                jointEsts(2,2)=crestPos(2)+sind(angle)*dist;
                
            else
                %if it's already there, just use the tracked value
                jointEsts(2,:)=squeeze(jointData(jointInds(2),1,:));
            end

            
            %KNEE, ANKLE, KNUCKLE, and TOE:
            %for the rest of the joints, use the angle of the previous
            %joint in the chain, and the limb segment length to calculate
            %the position
            
            segmentNames={[],[],'thighLength','shinLength','footLength','digitLength'};
            for iJoint=3:length(jointInds)
                if isnan(jointData(jointInds(iJoint),1,1))
                    
                    % get angle of the previous joint
                    angleName=[lower(jointNames{iJoint-1}(1)) jointNames{iJoint-1}(2:end) 'Angle'];
                    joint=jointNames{iJoint};
                    if isnan(trackedParams.(angleName))
                        %use kNN to estimate the angle
                        [prevJointAngle, nnAngleSTDs]=TrackerFunctions.getCircStatsDegrees(...
                            modelParams.(angleName)(nnInds));
                        
                        %the spread (std) of the nearest neighbor values
                        %must be within a specifiled tolerance
                        if nnAngleSTDs>kNNTol
                            return
                        end
                        
                    else
                        prevJointAngle=trackedParams.(angleName);
                    end
                    
                    %get limb length
                    dist=mean(modelParams.(segmentNames{iJoint}));
                    
                    %get previous two joints in the chain's position
                    if ~isnan(jointData(jointInds(iJoint-1),1,1))
                        %already tracked, use the tracked value
                        prevJointPos=squeeze(jointData(jointInds(iJoint-1),1,:));
                    else
                        %otherwise use the estimated joint position
                        prevJointPos=jointEsts(iJoint-1,:);
                    end
                    
                    if ~isnan(jointData(jointInds(iJoint-2),1,1))
                        %already tracked, use the tracked value
                        prev2JointPos=squeeze(jointData(jointInds(iJoint-2),1,:));
                    else
                        %otherwise use the estimated joint position
                        prev2JointPos=jointEsts(iJoint-2,:);
                    end
                    
                    %the angle between the two previous joints and
                    %horizontal (let's call it horz angle)
                    horzAngle=atan2d((prevJointPos(2)-prev2JointPos(2)),(prev2JointPos(1)-prevJointPos(1)));
                    
                    %now, the angle between the joint and the horizontal is
                    %just the sum of of the prev joint angle and the horz
                    %angle:
                    %
                    %             y ^         O  <---prev2Joint
                    %               |       '
                    %               |     '  \
                    %               |   '   horzAngle
                    %               | ' \    /
                    % prevJoint --> O--jointAngle--------------> x
                    %               |'  /
                    %               | '
                    %               |  O  <---joint
                    
                    jointHorzAngle=prevJointAngle+horzAngle;
                    jointEsts(iJoint,1)=prevJointPos(1)+cosd(jointHorzAngle)*dist;
                    jointEsts(iJoint,2)=prevJointPos(2)-sind(jointHorzAngle)*dist;
                    
                else
                    %if it's already there, just use the tracked value
                    jointEsts(iJoint,:)=squeeze(jointData(jointInds(iJoint),1,:));
                end
            end
            

        end
            
            
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Function to calculate circular mean and circular standard
        % deviation (for dealing with angles). Values should be in degrees
        % not radians, and the returned mean and std are in degrees
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [circMean, circStd]=getCircStatsDegrees(values)
            %circular mean:
            x=sum(sind(values));
            y=sum(cosd(values));
            
            circMean=atan2d(x,y);
            circStd=sqrt(-2*log(norm([x,y])/length(values)))/pi*180;
        end
        
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Apply image processing to an input image (contrast, brightness
        % adjustment, color decorrelation)
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function frameAdj=applyImageProcessing(frame, brightness, contrast, decorr, mask)

            frameAdj=frame;
            
            % adjust for brightness
            if brightness~=0
                frameAdj=frame+brightness;
            end
            
            % adjust for contrast
            if contrast~=0
                frameAdj=imadjust(frameAdj,stretchlim(frameAdj,[contrast/2 1-contrast/2]));
            end
            
            % apply colorspace decorrelation
            if decorr
                frameAdj=decorrstretch(frameAdj);
            end
            
            % apply mask
            if ~isempty(mask)
                frameAdj=frameAdj.*repmat(uint8(~mask),[1 1 3]);
            end

        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Write data to simi file
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function success=writePFile(markerNames, markerData, videoFPS)
            
            success=false;
            
            if length(markerNames)~=size(markerData,2) || isempty(markerNames)
                return
            end
            
            %first let user choose .p file to save to
            [file,path,ind] = uiputfile({'*.p'},'Select file to save to');
            
            if file==0
                return
            end
            
            %has to be p file
            if (ind~=1)
                warndlg('Can only save to .p files!')
                return
            end
            
            filename=fullfile(path,file);
            
            %See if file already exists
            fID=fopen(filename);
            
            %if it does, then ask user if they want to overwrite all data,
            %or just newly tracked data
            header = string([]);
            fileMarkerNames = string([]);
            fileMarkerIDs = string([]);
            
            if fID~=-1
                writeType=questdlg('Do you want overwrite all existing data/markers or just the tracked data in this session?',...
                    'Overwrite Type','Overwrite all','Overwrite newly tracked data','Overwrite newly tracked data');
                
                %get header, markers, marker IDs, and data from the
                %existing file
                [header, fileMarkerNames, fileMarkerIDs, myMarkerInds, myMarkerIndsWithData, existingFileData] = ...
                    TrackerFunctions.readPFile(markerNames,filename);
                
                if isempty(header) || isempty(fileMarkerNames)
                    return
                end
                
                fclose(fID);
            end
            
            %if overwrite all, or if the file doesn't exist
            if fID==-1 || strcmp(writeType, 'Overwrite all')
                fID=fopen(filename,'wt');
                
                %write header
                if isempty(header)
                    %if there wasn't a header already loaded in, use the
                    %default header format (as of Simi Motion v9.2.1):
                    header=[...
                        string(['FileType' sprintf('\t') 'RawData']);...
                        string(['Version' sprintf('\t') '150']);...
                        string(['Name' sprintf('\t') 'Raw data']);...
                        string(['Samples' sprintf('\t') num2str(size(markerData,1))]);...
                        string(['TimeOffset' sprintf('\t') '0.000000']);...
                        string(['SamplesPerSecond' sprintf('\t') num2str(videoFPS)]);...
                        string(['Count' sprintf('\t') num2str(size(markerData,2))])];
                else
                    %used the header from the old file, just update the
                    %fps, samples and Count
                    header(4) = string(['Samples' sprintf('\t') num2str(size(markerData,1))]);
                    header(6) = string(['SamplesPerSecond' sprintf('\t') num2str(videoFPS)]);
                    header(7) = string(['Count' sprintf('\t') num2str(size(markerData,2))]);
                end
                
                for iHeaderLine=1:length(header)
                    fprintf(fID,header{iHeaderLine});
                    fprintf(fID,'\n');
                end
                
                %write marker IDs
                writtenMarkerOrder = [];
                if isempty(fileMarkerIDs)
                    
                    %if there isn't already markers and marker IDs from an
                    %existing file, make our own IDs (start from 1000000)
                    fprintf(fID,'%u\t%u',1000000,1000000);
                    for iMarker=2:length(markerNames)
                        fprintf(fID,'\t');
                        fprintf(fID,'\t%u\t%u',1000000+iMarker,1000000+iMarker);
                    end
                    
                    %now write marker names
                    fprintf(fID,'\n');
                    fprintf(fID,markerNames{1});
                    fprintf(fID,'\t');
                    fprintf(fID,markerNames{1});
                    for iMarker=2:length(markerNames)
                        fprintf(fID,'\t');
                        fprintf(fID,markerNames{iMarker});
                        fprintf(fID,'\t');
                        fprintf(fID,markerNames{iMarker});
                    end
                    
                    writtenMarkerOrder = 1:length(markerNames);

                else
                    
                    %if there were existing markers in the file, get the
                    %ones that match our marker names and their
                    %corresponding IDs
                    markerIDLine = '';
                    markerNameLine = '';
                    for iMarker = 1 : length(fileMarkerNames)
                        
                        if any(iMarker == myMarkerInds)
                            %marker in the existing file is one of my
                            %markers, write the ID and marker name in
                            if ~isempty(writtenMarkerOrder)
                                markerIDLine = [markerIDLine sprintf('\t')];
                                markerNameLine = [markerNameLine sprintf('\t')];
                            end
                            markerIDLine = [markerIDLine ...
                                sprintf([fileMarkerIDs{iMarker} '\t' fileMarkerIDs{iMarker}])];
                            markerNameLine = [markerNameLine ...
                                sprintf([fileMarkerNames{iMarker} '\t' fileMarkerNames{iMarker}])];
                            
                            %add to marker order list
                            writtenMarkerOrder(end+1) = find(iMarker == myMarkerInds);
                        end
                        
                    end
                    
                    %now, the rest of my markers aren't in the existing
                    %file, will have to assign them new IDs. Start from 1
                    %more than the largest ID in the existing file
                    maxFoundIDs = max(cellfun(@str2num, fileMarkerIDs));
                    newMarkerInds = setdiff(1:length(markerNames), writtenMarkerOrder);
                    for iMarker = 1 : length(newMarkerInds)
                        if ~isempty(writtenMarkerOrder)
                            markerIDLine = [markerIDLine sprintf('\t')];
                            markerNameLine = [markerNameLine sprintf('\t')];
                        end
                        markerIDLine = [markerIDLine ...
                            sprintf([num2str(maxFoundIDs+iMarker) '\t' num2str(maxFoundIDs+iMarker)])];
                        markerNameLine = [markerNameLine ...
                            sprintf([markerNames{newMarkerInds(iMarker)} '\t'...
                            markerNames{newMarkerInds(iMarker)}])];
                        
                        %add to marker order list
                        writtenMarkerOrder(end+1) = newMarkerInds(iMarker);
                    end
                    
                    %now write the ID line and marker name line to the file
                    fprintf(fID,markerIDLine);
                    fprintf(fID,'\n');
                    fprintf(fID,markerNameLine);
                    
                end
                
                %finally, write the data
                fprintf(fID,'\n');
                for iFrame=1:size(markerData,1)
                    
                    if any(~isnan(markerData(iFrame,1,:)),3)
                        fprintf(fID,'%.6f',markerData(iFrame,writtenMarkerOrder(1),1));
                        fprintf(fID,'\t');
                        fprintf(fID,'%.6f',markerData(iFrame,writtenMarkerOrder(1),2));
                    else
                        fprintf(fID,'\t');
                    end
                    
                    for iValue=2:size(markerData,2)
                        fprintf(fID,'\t');
                        if any(~isnan(markerData(iFrame,iValue,:)),3)
                            fprintf(fID,'%.6f',markerData(iFrame,writtenMarkerOrder(iValue),1));
                            fprintf(fID,'\t');
                            fprintf(fID,'%.6f',markerData(iFrame,writtenMarkerOrder(iValue),2));
                        else
                            fprintf(fID,'\t');
                        end
                    end
                    fprintf(fID,'\n');
                end
                
                %finish
                fclose(fID);
                success=true;
                return
            else
%                 %want to only overwrite newly tracked data
%                 markerIDs=split(string(fgetl(fID)));
%                 markerNames=split(string(fgetl(fID)));
%                 
%                 fileData=importdata(filename,'\t',length(header)+2);
%                 trackedData=fileData.data;
%                 
%                 markerIDs=markerIDs(1:2:size(trackedData,2));
%                 markerNames=markerNames(1:2:size(trackedData,2));
%                 
%                 if isempty(trackedData)
%                     
%                 end                
            end
            
        end
        
        
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        % Read data from simi file
        %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        function [header,fileMarkerNames,fileMarkerIDs,myMarkerInds,myMarkerIndsWithData,data] = ...
                readPFile(myMarkerNames,filename)
            
            header=string([]);
            fileMarkerNames=string([]);
            fileMarkerIDs=[];
            myMarkerInds=[];
            data=[];

            %open file
            fID=fopen(filename);
            
            if fID==-1
                warndlg('Unable to open file')
                return
            end
            
            %read header
            header=string([]);
            while true
                header(end+1)=fgetl(fID);
                
                if isempty(header{end}) || strcmp(header{end},'-1')
                    break
                end
            end
            
            %get markers name and ids (for some reason split with '\t'
            %doesn't work, have to use char(9))
            fileMarkerIDs=split(string(fgetl(fID)));
            fileMarkerIDs=fileMarkerIDs(1:2:end);
            fileMarkerNames=split(string(fgetl(fID)),char(9));
            fileMarkerNames=fileMarkerNames(1:2:end);
            
                        
            %load the data
            fclose(fID);
            data=importdata(filename,'\t',length(header)+2);
            
            if ~isfield(data,'data')
                errordlg('Error reading in p file, cannot get data')
                header = [];
                fileMarkerNames = [];
                return;
            end
            data=data.data;
            
            %not all file markers have corresponding data
            fileMarkerNamesWithData=fileMarkerNames(1:size(data,2)/2);
            
            %make sure the file's markers names match my marker names, and
            %get the index in the loaded data
            myMarkerInds = zeros(1,length(myMarkerNames));
            myMarkerIndsWithData = zeros(1,length(myMarkerNames));
            
            for iMarker=1:length(myMarkerNames)
                definedInd = find(myMarkerNames(iMarker)==fileMarkerNames,1);
                withDataInd = find(myMarkerNames(iMarker)==fileMarkerNamesWithData,1);
                if isempty(definedInd)
                    myMarkerInds(iMarker)=NaN;
                else
                    myMarkerInds(iMarker)=definedInd;
                end
                if isempty(withDataInd)
                    myMarkerIndsWithData(iMarker)=NaN;
                else
                    myMarkerIndsWithData(iMarker)=withDataInd;
                end
            end
            
        end
        
        
    end
end


% 
