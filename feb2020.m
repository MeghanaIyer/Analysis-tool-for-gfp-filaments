%% Compiled analysis tool
% This script is written to determine various parameters such as: 1. filament
% length - under variable name: 2. total intensity of filament- under variable
% name: 3. position occupancy of filament- under variable name: The input data
% is from two sources: an image file for analysis and the respective analysis
% file from oufti. The "mesh" data generated by oufti is utilized to segment the
% cell from the image and further analysis is carried out. Each section (demarcated
% by '%%') has a brief description of the fuctions carried out in the section.
%
% Author:- Meghana B
% Date:- 06/02/2020 (DD/MM/YY)
clear; clc; %close all;

%% set the folder path of the image and .mat analysis file
size_quad = double.empty;
quad_occupancy = double.empty;
temp_fil = zeros(size(quad_occupancy));
temp_quad = zeros(size(quad_occupancy));
value1 = uint16.empty;
value2 = uint16.empty;
intensity_vals1 = zeros(size(value1));
intensity_vals2 = zeros(size(value2));
value = 0.9; %threshold value
t=1;

%%

for z =46
    
    main_folder = '\\storage.ncbs.res.in\AB_lab\Afroze\Papers\RecN_2020\Data\AFROZE_20191225\ori_RecA_5min_swarmers\20190525\AC245_249_Z_100ms_A_400ms_\+N\xy1\crops\split\';
    path = [main_folder, 'crop_', num2str(z),'\'];
    im_file =['C2-crop_',num2str(z),'.tif']; %name of image file
    c=z+60;
    file = ['20190525_+N_S_crop_',num2str(z),'.mat']; %name of oufti analysis file
    %% variables:
    total_intensity_profile = uint16.empty; %#ok<*NASGU>
    imagesc_file = uint16.empty;
    
    %% Load the .tif file stack
    
    FileTif = [path im_file];
    InfoImage=imfinfo(FileTif);
    Image_width = InfoImage(1).Width;
    Image_height = InfoImage(1).Height;
    Number_Images = length(InfoImage);
    FinalImage=zeros(Image_height,Image_width,Number_Images,'uint16');
    for i=1:Number_Images
        FinalImage(:,:,i)=imread(FileTif, i);
    end
    
    %% Load the .mat file containing the segmentation data of the entire stack
    load([path file]);
    
    %% Generate a second .tif stack containing only segmented cell
    [~,im_data] = find(cellListN);
    quad_occupancy = double.empty(max(im_data),0);
    FinalImage_segmented = zeros(Image_height,Image_width,Number_Images,'uint16');
    for i=1:Number_Images
        cell_content = cellList.meshData(1,i);
        if length(cell_content{1,1})>0
            mesh_val = cell_content{1,1}{1,1}.mesh;
            X = [mesh_val(:,1);mesh_val(length(mesh_val):-1:1,3)];
            Y = [mesh_val(:,2);mesh_val(length(mesh_val):-1:1,4)];
            BW = roipoly(FinalImage(:,:,i),X,Y);
            FinalImage_segmented(:,:,i) = FinalImage_segmented(:,:,i) + uint16(BW).*FinalImage(:,:,i); % segmented cell image only
        end
    end
    total_intensity_profile = single.empty;
    var6 = [im_data(1), ceil(median(im_data))];
    for i = im_data(1): ceil(mean(var6))
        im = FinalImage_segmented(:,:,i);
        total_intensity_profile = [total_intensity_profile; im(:)];
    end
    [f, x] = ecdf(total_intensity_profile);
    thresh_1 = value; y = x(and(f>thresh_1,f<1));
    thresh = y(1);
    %% Generating a stack of threshold images
    FinalImage_thresholded = zeros(Image_height, Image_width, Number_Images, 'uint16');
    for i=1:Number_Images
        cell_content = cellList.meshData(1,i);
        if length(cell_content{1,1}) > 0
            im = FinalImage_segmented(:,:,i);
            im(im<thresh)=0;
            FinalImage_thresholded(:,:,i) = im; %contains only the filament
        end
    end
    %% PART 1: orienting the curved and saving the images in im3
    % This is done to ensure the filament length values are more reliable; The c-shaped
    % caulobacter cells are aligned with respect to an imaginary middle line passing
    % through the center of the cell. Final straigtened image can be viewed in 
    % part 3
    
    differences = single.empty;
    newmaskimg = uint16.empty;
    im2 = uint16.empty;
    im3 = zeros(size(im2(:,:,:)));
    val = 1; %initial coordinate value
    
    for image_num = 1:Number_Images
        if isempty(cellList.meshData{1, image_num})
            continue
        else
            x1 = cellList.meshData{1, image_num}{1, 1}.mesh(:,1); %meshes from oufti
            y1 = cellList.meshData{1, image_num}{1, 1}.mesh(:,2);
            a1 = cellList.meshData{1, image_num}{1, 1}.mesh(:,3);
            b1 = cellList.meshData{1, image_num}{1, 1}.mesh(:,4);
            
            for temp7 = 1:length(y1) %width of cell
                differences(temp7,1) = sqrt(((a1(temp7)-x1(temp7))^2)+((b1(temp7)-y1(temp7))^2));
            end
            rect_x = length(y1);
            rect_y = double(ceil(max(abs(differences)))); %max width of cell
            img = zeros(rect_y, rect_x);
            imgLogical = logical(img);
            img(ceil(rect_y/2), ceil(rect_x/2))=1;
            se1 = strel('rectangle',[rect_x rect_y]); %[rows, cols]
            im2 = imdilate(img,se1); %creates a rectangle with dimensions of cell
            im3(1:size(im2,1),1:size(im2,2),image_num) = im2;
            
            %%
            %modify the follwing to read the cell until halfway and then
            %change the orientation in which its rotated
            % maybe 2 for loops?
            
            for val = 1:(length(y1)-1) % refer comment above
                newimg = FinalImage_segmented(:,:,image_num);
                % pos = alternating x and y values;
                pos = double([x1(val) y1(val) a1(val) b1(val) a1(val+1) b1(val+1) x1(val+1) y1(val+1) x1(val) y1(val)]);
                bw = ~poly2mask(pos(1:2:end), pos(2:2:end), size(newimg, 1), size(newimg, 2));  % 2D mask
                maskimg = newimg;
                maskimg(bw) = 0;
                tempmask = maskimg>0;
                stats2 = regionprops(tempmask, 'Orientation');
                stats2 = struct2cell(stats2);
                if isempty(stats2)
                    theta = 0;
                else
                    theta = stats2{1,1};
                end
                newmaskimg = imrotate(maskimg,-(theta));
                [im_row, im_col] = find(newmaskimg);
                row_span = unique(im_row); %how many rows the image spans
                col_span = unique(im_col);
                for var4 = 1:length(col_span)
                    im3(var4, val, image_num) = max(newmaskimg(:, col_span(var4)));
                end
            end
        end
    end
    
    %% PART 2: identifying the middle line
    temp_middle = double.empty;
    middle_value = zeros(size(temp_middle(:,:,:)));
    im3 = changem(im3,0,1); %to remove the 1's
    
    for image_num = 1: max(im_data) %size(im3, 3)
        [~, col1] = find(im3(:,:,image_num));
        cell_start = min(col1);
        cell_end = max(col1);
        temp_middle = unique(col1);
        middle_value(1:size(temp_middle,1),2,image_num) = temp_middle; %column values of middle line
        
        for temp1 = cell_start:cell_end
            [row2,~] = find(im3(:,temp1, image_num));
            middle_value((temp1-cell_start)+1,1, image_num) = ceil(median(row2)); %row values of middle line
        end
    end
    %% PART 3:
    % to alter the position of pixels in the segmented image wrt the
    % middle line passing through the image
    
    im3 = uint16(im3);
    temp6 = zeros(size(im3));
    
    for image_num = 1: max(im_data)
        temp3 = im3(:,:,image_num);
        mid_val_img = middle_value(:,:,image_num);
        [~,~,row4] = find(mid_val_img(:,1)); %x coordinates of middle line
        [~,~,col4] = find(mid_val_img(:,2)); %y coordinates of middle line
        [index_c4, ~] = find(col4);% index of col4:
        rect_y = size(temp3, 1);
        for temp4 = 1: max(index_c4)
            col3 = col4(temp4);
            [row3, ~] = find(temp3(:,col3));
            for temp5 = 1 :length(row3)
                if ceil(median(1:rect_y)) >  row4(temp4) % row4(temp4) is the coordinate for the middle line; compare each columns's middle value to
                    difference = ceil(rect_y/2)-row4(temp4); %row4(1,1) = middle row of 1st column
                    temp6(row3(temp5)+difference, col3, image_num) = temp3(row3(temp5), col3);
                    
                elseif ceil(median(1:rect_y)) <  row4(temp4)
                    difference =  (row4(temp4)) - ceil(rect_y/2);
                    temp6(row3(temp5)-difference, col3, image_num) = temp3(row3(temp5), col3);
                    
                elseif ceil(median(1:rect_y)) ==  row4(temp4)
                    difference = 0;
                    temp6(row3(temp5), col3, image_num) = temp3(row3(temp5), col3);
                end
            end
        end
    end
    temp6 = uint16(temp6);
    newtemp6 = permute(temp6,[2 1 3]); %creates a stack of segmented, aligned cells
    cols = size(temp6, 1)+1;
    cols2 = size(temp6,2);
    for var5 = 1:size(im3, 3)
        newtemp6(:,cols,var5) = zeros(cols2,1); %gap between cells
    end
    
    %% Stack of thresholded images
    total_intensity_profile_2 = single.empty;
    newtemp6_thresholded = uint16.empty; %changes for every sample
    for i=im_data(1):im_data(end)
        [~, ~, v] = find(newtemp6(:,:,i));
        max_values(i,1) = max(v);
    end
    [~, max_idx] = max(max_values);
    [~, min_idx] =min(max_values);
    [ascend, frames] = sort(max_values);
    frames(1:ceil(numel(frames)/2))
    
    if min_idx < ceil(median(im_data))
        var9 = [im_data(1),ceil(median(im_data))];
        for i =  im_data(1):ceil(median(im_data)) %ceil(mean(var9)) %ceil(mean(var9)):ceil(median(im_data)) 
            im4 = newtemp6(:,:,i);
            total_intensity_profile_2 = [total_intensity_profile_2; im4(:)]; %#ok<*AGROW>
        end
        [f3, x3] = ecdf(total_intensity_profile_2);
        thresh_4 = value; y3 = x3(and(f3>thresh_4,f3<1));
        thresh3 = y3(1);
    elseif min_idx >= ceil(median(im_data))
        var9 = [ceil(median(im_data)), im_data(end)];
        for i = ceil(median(im_data)):im_data(end) %ceil(mean(var9))
            im4 = newtemp6(:,:,i);
            total_intensity_profile_2 = [total_intensity_profile_2; im4(:)]; %#ok<*AGROW>
        end
        [f3, x3] = ecdf(total_intensity_profile_2);
        thresh_4 = value; y3 = x3(and(f3>thresh_4,f3<1));
        thresh3 = y3(1);
    end
    for i=1:max(im_data)%size(im3, 3)
        cell_content = cellList.meshData(1,i);
        if length(cell_content{1,1}) > 0
            im4 = newtemp6(:,:,i); %segmented straight image
            im4(im4<thresh3)=0;
            newtemp6_thresholded(:,:,i) = im4; %thresholded image
        end
    end
    
    
%     if max_idx < ceil(median(im_data))
%         var9 = [ceil(median(im_data)), im_data(end)];
%         for i = ceil(median(im_data)): ceil(mean(var9)) %im_data(1):ceil(median(im_data)) %ceil(mean(var9)): im_data(end)  %
%             im4 = newtemp6(:,:,i);
%             total_intensity_profile_2 = [total_intensity_profile_2; im4(:)]; %#ok<*AGROW>
%         end
%         [f3, x3] = ecdf(total_intensity_profile_2);
%         thresh_4 = value; y3 = x3(and(f3>thresh_4,f3<1));
%         thresh3 = y3(1);
%     elseif max_idx >= ceil(median(im_data))
%         var9 = [im_data(1), ceil(median(im_data))];
%         for i = im_data(1): ceil(mean(var9))
%             im4 = newtemp6(:,:,i);
%             total_intensity_profile_2 = [total_intensity_profile_2; im4(:)]; %#ok<*AGROW>
%         end
%         [f3, x3] = ecdf(total_intensity_profile_2);
%         thresh_4 = value; y3 = x3(and(f3>thresh_4,f3<1));
%         thresh3 = y3(1);
%     end
%     
%     for i=1:max(im_data)%size(im3, 3)
%         cell_content = cellList.meshData(1,i);
%         if length(cell_content{1,1}) > 0
%             im4 = newtemp6(:,:,i); %segmented straight image
%             im4(im4<thresh3)=0;
%             newtemp6_thresholded(:,:,i) = im4; %thresholded image
%         end
%     end
    
    %% Filament length
    cell_length = double.empty;
    filament_length = double.empty(size(newtemp6_thresholded, 3), 0);
    start_positions = double.empty(size(newtemp6_thresholded, 3), 0);
    index_f = double.empty;
    
    for image_num = 1:im_data(end)
        disp(image_num)
        output = logical.empty;
        alt_im = newtemp6_thresholded(:,:,image_num);
        sum_im = sum(alt_im, 2);
        sum_im = sum_im >0;
        M = reshape(find(diff([0; (sum_im) ;0])~=0),2,[]);
        
        if isempty(find(sum_im))
            continue
        else
            new_sum_im =  sum_im(find(sum_im>0,1):end);
            input = new_sum_im ;
            idx = input==1;
            idr = diff(find([1;diff(idx);1]));
            D = mat2cell(input,idr(:),size(input,2));
            L = cellfun(@length,D);
            L(1:2:end) = NaN ;
            
            id = L<6 ;
            [rows, ~] = find(id);
            for w = 1:length(rows)
                newp = true(length(D{rows(w),1}), 1);
                D{rows(w),1} = newp;
            end
            output = cell2mat(D);
            [I, ~] = find(output == 1); %new id's
            g = 0;
            result = [];
            for de=2:length(I)
                if (I(de)-I(de-1)) ~= 1
                    result = [result; g+1];
                    g = 0;
                else
                    g = g + 1;
                end
            end
            result = [result; g+1]; %result = filament lengths
            %           disp(result);
            for h1 = 1:length(result)
                if result(h1) ==1
                    index_f(image_num, :) = [image_num, h1];
                else
                    filament_length(image_num, h1) = result(h1); % delete zeros in each row
                end
            end
        end
        temp11  = find(sum_im);
        fg =1;
        temp11 = [0; temp11];
        start_pos=double.empty;
        
        for rt =1:length(temp11)-1
            if temp11(rt+1) - temp11(rt) >1
                start_pos(fg,1) = temp11(rt+1);
                fg = fg+1;
            end
        end
        r=1;
        var11=double.empty;
        for i= 1:length(start_pos)
            var11(i) = start_pos(i)+diff(M(:,i));
            
        end
        %         start_positions(image_num, 1) = start_pos(1);
        var11 = [0, var11];
        
        for i= 1:length(start_pos)
            R = [start_pos(i), var11(i)];
            
            if length(start_pos) ==1
                start_positions(image_num, r) = start_pos(i);
                
            elseif abs(diff(R)) >=6
                start_positions(image_num, r) = start_pos(i);
                r=r+1;
            end
        end
    end
    
    if ~isempty (index_f)
        var12 = index_f(:,2);
        [r_vals,~, id_vals]=find(var12);
        
        for image_num =1: length(r_vals)
            start_positions(r_vals(image_num),id_vals(image_num))=0;
        end
        
        for image_num =1:im_data(end) %removing the unnecessary zeros
            %start_positions
            if size(start_positions,2) ~=1 %if there are multiple localizations
                for tg = 1:size(start_positions,2)-1
                    if start_positions(image_num,tg)==0
                        start_positions(image_num, tg) = start_positions(image_num,tg+1);
                        start_positions(image_num, tg+1)=0;
                    end
                end
            else %when there's only one localization
                for tg = 1
                    if start_positions(image_num,tg)==0
                        start_positions(image_num, tg) = start_positions(image_num,tg);
                        start_positions(image_num, tg)=0;
                    end
                end
            end
            %filament_lengths
            if size(filament_length,2) ~=1 %if there are multiple localizations
                for tg = 1:size(filament_length,2)-1
                    
                    if filament_length(image_num,tg)==0
                        filament_length(image_num, tg) = filament_length(image_num,tg+1);
                        filament_length(image_num, tg+1)=0;
                    end
                end
            else
                for tg = 1
                    if filament_length(image_num,tg)==0
                        filament_length(image_num, tg) = filament_length(image_num,tg);
                        filament_length(image_num, tg)=0;
                    end
                end
            end
        end
        filament_length(:,~any(filament_length))=[];
        start_positions(:,~any(start_positions))=[];
        
    end
    for image_num=1:im_data(end)
        
        cell_im= newtemp6(:,:,image_num);
        cell_sum_im = sum(cell_im,2);
        cell_sum_im = cell_sum_im >0;
        cell_M = reshape(find(diff([0; (cell_sum_im) ;0])~=0),2,[]);
        
        if isempty(diff(cell_M))
            cell_length(image_num,1) = 0;
        else
            cell_length(image_num, 1) = diff(cell_M);
        end
        [nrows, ncols] = size(start_positions); %longest cell
        maximum_length= max(cell_length);
        size_quad(z) = ncols;
    end
    for d = 1:ncols
        for g = im_data(1):im_data(end)
            new_cell_length = cell_length(g);
            temp3 = filament_length(g,d); %length of filament wrt normalized cell length
            temp4 =  start_positions(g,d); % index of start of filament wrt normalized cell length
            b = temp3/2; % filament length divided by 2
            a2 = temp4 + b;
            a = a2 - cell_M(1);
            x = new_cell_length/8;
            f = new_cell_length*0.125;
            if a==0 % a = 0, when there's no filament
                quad_occupancy(g,d)= nan;
            elseif (a > 0) && (a <= x)
                quad_occupancy(g,d)=(f*1*0.125)/x;
            elseif (a >= x) && (a <= x*2)
                quad_occupancy(g,d)=(f*2*0.125)/x;
            elseif (a >= x*2) && (a <= x*3)
                quad_occupancy(g,d)=(f*3*0.125)/x;
            elseif (a >= x*3) && (a <= x*4)
                quad_occupancy(g,d)=(f*4*0.125)/x;
            elseif (a >= x*4) && (a <= x*5)
                quad_occupancy(g,d)=(f*5*0.125)/x;
            elseif (a >= x*5) && (a <= x*6)
                quad_occupancy(g,d)=(f*6*0.125)/x;
            elseif (a >= x*6) && (a <= x*7)
                quad_occupancy(g,d)=(f*7*0.125)/x;
            elseif (a >= x*7)
                quad_occupancy(g,d)=(f*8*0.125)/x;
            end
        end
    end
    
    %%
    
    for d = 1:ncols
        temp_quad(1:size(quad_occupancy,1),t) = quad_occupancy(:,d);
        temp_fil(1:size(quad_occupancy,1), t) = filament_length(:,d);
        t = t+1;
    end
    new_quad = temp_quad;
    new_quad(~any(quad_occupancy,2),:) = []; % has quadrant data of only those with oufti mesh data
    fil_lnt = temp_fil;
    fil_lnt(~any(filament_length,2),:) = [];
    
    %     for dd = 1:im_data(1)
    %         temp_fil(dd,tt) =nan;
    %         temp_quad(dd,tt)=nan;
    %         tt=tt+1;
    %     end
    
    %% Total intensity generated by the filaments
    
    [f2, x2] = ecdf(total_intensity_profile_2);
    thresh_2 = value; y2 = x2(and(f2>thresh_1,f2<1));
    thresh1 = y2(1);
    value1 = uint16.empty(Number_Images,0);
    value2 = uint16.empty(Number_Images,0);
    for i = 1:max(im_data) %Number_Images
        img_intensity = FinalImage_thresholded(:,:,i);
        [prow,~, intensity_vals] = find(img_intensity);
        % total intensity wrt number of pixels:
        value1(i,1) = sum(intensity_vals)/numel(prow);
        
        % total intensity wrt length of filament:
        [row_vals,~] = find(newtemp6_thresholded(:,:,i));
        length_vals(i,1) = numel(unique(row_vals)); %length of filament
        value2(i,1) = sum(intensity_vals)/length_vals(i,1);
    end
    
    intensity_vals1(:,z) = value1; %to expand upon concatenation
    intensity_vals2(:,z) = value2;
    
end

v=1:z;
n=size_quad(v);
temp2 = repelem(v,n);
temp8 = repelem(v,1);

xlFilename = strcat(main_folder, 'quadrant_occupancy_m.xls');
% xlswrite(xlFilename, temp2, 'Quadrant_Occupancy', 'A1');
% xlswrite(xlFilename, temp_quad, 'Quadrant_Occupancy', 'A2');
% xlswrite(xlFilename, temp2, 'Filament_Length', 'A1'); %filament data
% xlswrite(xlFilename, temp_fil, 'Filament_Length', 'A2');
% xlswrite(xlFilename, temp8, 'Total_Intensity', 'A1');
% % xlswrite(xlFilename, intensity_vals1, 'Total_Intensity', 'A2'); %wrt pixels
% xlswrite(xlFilename, intensity_vals2, 'Total_Intensity', 'A2'); %wrt length

%% Heatmap of all the cells placed adjacent to one another;
% change z to required sample number

var10=0;
for var13 = im_data(1):im_data(end) %representing the desired frames
    for x = 1:cols
        if var5 == 1
            imagesc_file(:, x) = newtemp6(:,x, var13);
        else
            imagesc_file(:, ((var10*cols)+x+1)) = newtemp6(:,x, var13); %joining all the aligned cells next to one another
        end
    end
    var10 = var10+1;
end
saved_file = imagesc_file;
var13=im_data(1):im_data(end); 
%figure; imagesc(saved_file); %uncomment to view heatmap

%% Filling in holes with averaged pixel values; #aesthtics
% select section and press -> ctrl+t to uncomment;
% select section and press -> ctrl+r to comment;

for var7 = 2 : size(imagesc_file,2) % goes though each column of the concatenated image file
    temp8 = imagesc_file(:,var7);
    [row_idx, ~] = find(temp8);

    for var8 = min(row_idx):max(row_idx)
        if imagesc_file(var8, var7) == 0
            up = imagesc_file(var8-1, var7);
            down = imagesc_file(var8+1, var7);
            right = imagesc_file(var8, var7+1);
            left = imagesc_file(var8, var7-1);
            A = [up, down, right, left]; % neighboring pixel values
            imagesc_file(var8, var7) = ceil(mean(nonzeros(A))); % considers only the pixels that have values
        end
    end
end
% imagesc_file((0<imagesc_file) & (saved_file<thresh))=700;
aplt = nan(size(imagesc_file)+1);
aplt(1:end-1,1:end-1) = imagesc_file;
aplt(aplt == 0) = NaN;
figure; pcolor(aplt);
colorbar;
set(gca, 'color', 'k', 'clim', [900 2000], 'ydir', 'reverse')%modify 4000 value to fit desired aesthetic
set(gca,'XTick',0:rect_y+1:((rect_y+1)*numel(var13)), 'XTickLabel', 0:1:numel(var13))
xlabel('Time points')
ylabel('Cell Length')
shading flat;
% % figure; imagesc(imagesc_file); %uncomment to view heatmap

%% Heatmap of filaments only
% saved_file1 = imagesc_file;
% total_intensity_profile = [total_intensity_profile; saved_file1(:)];
% [f, x] = ecdf(total_intensity_profile);
% thresh_1 = 0.9970; y = x(and(f>thresh_1,f<1));
% thresh = y(1);

% data_mid_align((0<data_mid_align) & (data_mid_align<thresh))=0;
% aplt = nan(size(data_mid_align)+1);
% aplt(1:end-1,1:end-1) = data_mid_align;
% aplt(aplt == 0) = -1;
% pcolor(aplt);
% colorbar;
% set(gca, 'color', 'w', 'clim', [0 2], 'ydir', 'reverse')
% shading flat;

% figure; imagesc(saved_file1)
% figure; contourf(saved_file1, [1000 10000]) %uncomment to obtain the contours of the filament




