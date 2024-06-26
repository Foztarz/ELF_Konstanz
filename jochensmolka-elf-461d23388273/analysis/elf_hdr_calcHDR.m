function im_HDR = elf_hdr_calcHDR(im_cal, conf, hdrmethod, confmult, confsat)
% ELF_HDR_CALCHDR calculates an HDR image from a stack of calibrated images.
%
%   im_HDR = elf_hdr_calcHDR(im_cal, conf, hdrmethod, confmult, confsat)
%
% Inputs:
%   im_cal    - N x M x C x I double, calibrated image stack
%   conf      - N x M x C x I double, raw (dark-corrected) image stack, used for confidence/saturation calculation
%   hdrmethod - 'overwrite'/'overwrite2'/'validranges'/'allvalid'/'allvalid2'(current default)/'noise', see below for details of methods
%   confmult  - the multiplier that was used to convert raw image pixels in conf to flux values in im_cal, obtained from elf_calib_abssens
%   confsat   - C x I double, the saturation values for each channel/image, obtained from elf_calib_abssens
%
% Outputs:
%   im_HDR   - N x M x C double, calibrated HDR image

if size(im_cal, 4) == 1
    % if only one exposure was taken, no HDR image needs to be calculated
    im_HDR = im_cal;
    return;
end

switch hdrmethod
    case 'overwrite'
        %% Starting with the lowest exposure, overwrite all pixels that are not saturated
        im_HDR = cell(size(im_cal, 3), 1);

        for ch = 1:size(im_cal, 3)
            ul                  = confsat(ch, :);
            ul(1)               = Inf;
            im_HDR{ch}          = nan(size(im_cal, 1), size(im_cal, 2)); % pre-allocate

            for ii = 1:size(im_cal, 4)  % for each image, starting at the darkest image
                thisimch        = im_cal(:, :, ch, ii); % extract THIS row for THIS channel for THIS image
                thisconf        = conf(:, :, ch, ii);
                im_HDR{ch}(thisconf<ul(ii)) = thisimch(thisconf<ul(ii));
            end
        end

        im_HDR = cat(3, im_HDR{:});
        
    case 'overwrite2'
        %% same, but more vectorised, so maybe slightly faster
        nch = size(im_cal, 3);
        ul  = confsat;
        ul(:, 1) = Inf;

        im_HDR          = nan(size(im_cal, 1), size(im_cal, 2), nch); % pre-allocate
        
        for ii = 1:size(im_cal, 4)  % for each image, starting at the darkest image
            ulfull                  = repmat(reshape(ul(:, ii), [1 1 nch]), size(im_cal, 1), size(im_cal, 2));
            thisim                  = im_cal(:, :, :, ii);
            thisconf                = conf(:, :, :, ii);
            im_HDR(thisconf<ulfull) = thisim(thisconf<ulfull);
        end
        
    case 'validranges'
        %% Same way as histograms (this image shows what would be included in the histogram)
        % Calculates a valid range of raw counts for each exposure. This method leaves some pixels empty
        im_HDR = cell(size(im_cal, 3), 1);

        for ch = 1:size(im_cal, 3)
            ul                  = confsat(ch, :);
            ul(1)               = Inf;
            ll(1:length(ul)-1)  = ul(2:end) ./ confmult(2:end) .* confmult(1:end-1);
            ll(length(ul))      = -Inf;
            im_HDR{ch}          = nan(size(im_cal, 1), size(im_cal, 2)); % pre-allocate

            for ii = 1:size(im_cal, 4)  % for each image, starting at the lowest EV image
                thisimch      = im_cal(:, :, ch, ii); % extract THIS row for THIS channel for THIS image
                thisconf      = conf(:, :, ch, ii);
                im_HDR{ch}(thisconf>=ll(ii) & thisconf<ul(ii)) = thisimch(thisconf>=ll(ii) & thisconf<ul(ii));
            end
        end

        im_HDR = cat(3, im_HDR{:});

    case 'allvalid'
        %% always use the brightest pixel where NONE of the channels is saturated. 
        im_HDR      = nan(size(im_cal, 1), size(im_cal, 2), size(im_cal, 3)); % pre-allocate

        % choose 
        for i = 1:size(im_cal, 1)
            for j = 1:size(im_cal, 2)
                % find the highest exposure that has no saturated pixels
                bestind = find(~any(squeeze(conf(i, j, :, :))>=confsat), 1, 'last');
                if ~isempty(bestind)
                    im_HDR(i, j, :) = im_cal(i, j, :, bestind);
                else
                    % if all are saturated, use the estimate from the darkest image
                    im_HDR(i, j, :) = im_cal(i, j, :, 1);
                end
            end
        end

    case 'allvalid2' % (current defaultin elf_para)
        %% same, but  vectorised, so maybe faster
        nch = size(im_cal, 3);
        ul  = confsat;
        ul(:, 1) = Inf;
        
        im_HDR          = nan(size(im_cal, 1), size(im_cal, 2), nch); % pre-allocate
                
        for ii = 1:size(im_cal, 4)  % for each image, starting at the darkest image
            ulfull                  = repmat(reshape(ul(:, ii), [1 1 nch]), size(im_cal, 1), size(im_cal, 2));
            thisim                  = im_cal(:, :, :, ii);
            thisconf                = conf(:, :, :, ii);
            sel                     = thisconf<ulfull;
            sel2                    = repmat(all(sel, 3), [1 1 size(sel, 3)]);
            im_HDR(sel2)            = thisim(sel2);
        end
        
    case 'noise'
        %% NOISE METHOD: each pixel is the weighted average of the same pixel in different exposures.
        % Weights depend on the inverse of the modelled noise (currently: simply the square root of the raw count).
        % Saturated pixels had their confidence set to NaN in elf_calibrate_abssens.
        fullsat = zeros(size(conf));
        for ch = 1:size(confsat, 1)
            for im = 1:size(confsat, 2)
                fullsat(:, :, ch, im) = confsat(ch, im);
            end
        end
        conf(conf>=fullsat) = 0;
        conf(conf<0) = 0;
        HDRweights  = sqrt(conf);
        im_HDR      = nansum(im_cal .* HDRweights, 4) ./ nansum(HDRweights, 4);

    otherwise
        
end



