function im = elf_calibrate_spectral(im, info, method)
% ELF_CALIBRATE_SPECTRAL performs colour correction on an otherwise calibrated image
% 
% im = elf_calibrate_spectral(im, info, method)
%
% Inputs:
%   im          - M x N x 3 double, calibrated digital image (as obtained from elf_calibrate_abssens)
%   info        - 1 x 1 struct, info structure, containing the exif information of the raw image file (created by elf_info_collect or elf_imfinfo)
%   method      - 'col' (default) - each channel of the output image represents the weighted mean over that pixels sensitivity function, assuming a flat spectrum over its full range
%                 'colmat'        - solves the linear equation of all three channels to calculate a spectrum that is flat between 400-500/500-600/600-700nm and would create the same camera output
%                                   This method theoretically creates the most interesting result, but is extremely sensitive to saturation in individual channels and can not be recommended for
%                                   general use outside of laboratory situations
%                 'wb'            - simply applies the normal white balance suggested by the camera
%       
% Outputs:
%   im          - M x N x 3 double, calibrated digital image (in photons/nm/s/sr/m^2)
%
% Call sequence: elf -> elf_main1_HdrAndInt -> elf_calibrate_spectral
%
% See also: elf_main1_HdrAndInt, elf_imfinfo, elf_io_loaddng, elf_calibrate_darkandreadout, elf_calibrate_abssens

if nargin<3, method = 'col'; end
if nargin<2 || isempty(info) 
    warning('Using standard D810 colour matrix'); 
    wb_multipliers = [1.9531 1.0000 1.3359];
    camstring      = 'nikon d810';
else
    wb_multipliers  = (info.AsShotNeutral).^-1;
    wb_multipliers  = wb_multipliers/wb_multipliers(2); % normalise to green channel
    camstring       = info.Model;
end

switch method
    case 'colmat'
        colmat  = sub_getColMat(camstring);

        % correct for spectral and absolute sensitivity
        imsize = size(im);
        im     = reshape(im, [imsize(1)*imsize(2) imsize(3)]);  % Reshape image to allow all pixels to be accessed simultaneously in matrix division
        im     = colmat \ im';                                  % Solve equation system assuming constant photon radiance in each of the three spectral bins (see elf_calib_2016full_spectral1)
        im     = reshape(im', imsize);                          % Reshape to original matrix shape

        % Finally, apply a correction factor based on wide-spectrum bright lights
        im     = im / 0.868081924302272;
    case 'col'
        col  = sub_getCol(camstring);
        im(:, :, 1) = im(:, :, 1) / col(1);
        im(:, :, 2) = im(:, :, 2) / col(2);
        im(:, :, 3) = im(:, :, 3) / col(3);

        % Finally, apply a correction factor based on wide-spectrum bright lights
        im     = im / 0.871378457487805;
    case 'wb'
        % Apply the "As shot" white balance to correct for sensitivity differences in R, G and B pixels
        im(:, :, 1)     = im(:, :, 1) * wb_multipliers(1);
        im(:, :, 2)     = im(:, :, 2) * wb_multipliers(2);
        im(:, :, 3)     = im(:, :, 3) * wb_multipliers(3);
        %im = im / 5.58173957386454e-14;% 6.9304e-14;
end
end

function colmat = sub_getColMat(camstring)
    % load or calculate color correction matrix for this image camera type
    % Saving to a file and loading when needed has been tested and takes longer than recalculating on ELFPC (0.8s v 0.2s)
    
    persistent storedColMat;
    persistent storedColMatName;
        
    if strcmp(camstring, storedColMatName) && ~isempty(storedColMat)
        colmat  = storedColMat;
    else % load from file
        para    = elf_para;
        TEMP    = load(fullfile(para.paths.calibfolder, lower(camstring), 'rgb_calib.mat'), 'colmat');            
        colmat  = TEMP.colmat;

        storedColMat     = colmat;
        storedColMatName = camstring;
    end
end

function col = sub_getCol(camstring)
    % load or calculate color correction vector for this image camera type
    % Saving to a file and loading when needed has been tested and takes longer than recalculating on ELFPC (0.8s v 0.2s)
    
    persistent storedCol;
    persistent storedColName;
        
    if strcmp(camstring, storedColName) && ~isempty(storedCol)
        col     = storedCol;
    else % load from file
        para    = elf_para;
        TEMP    = load(fullfile(para.paths.calibfolder, lower(camstring), 'rgb_calib.mat'), 'col');            
        col     = TEMP.col;
        
        storedCol     = col;
        storedColName = camstring;
    end
end

%         %%% 1: oldest correct way
%         col(:, :, 1)  = sum(TEMP.r(:, 2)*0.5);   % counts/exp/ISO/ap / (ph/s/sr/m^2)
%         col(:, :, 2)  = sum(TEMP.g(:, 2)*0.5);   % counts/exp/ISO/ap / (ph/s/sr/m^2)
%         col(:, :, 3)  = sum(TEMP.b(:, 2)*0.5);   % counts/exp/ISO/ap / (ph/s/sr/m^2)
%         
%         %%% 3: HACK 170629
%         col(:, :, 1) = 4.796e-14;
%         col(:, :, 2) = 5.526e-14;    
%         col(:, :, 3) = 7.594e-14;
%         
%         %%% Alternative: Old calibration (for Dan)
%         col(:, :, :) = 6.9304e-14;