function im = elf_imread(fullfilename, ignoreCompressed)
% ELF_IMREAD reads image files of several different types
%   Currently works for tif, jpg, and dng, and should be ok for most other
%   non-raw formats. For raw formats, linearisation and demosaicing are
%   performed, but no white balance correction or colour space conversion.
%
% Inputs: 
% fullfilename  - has to include the full path to the image file
% 
% Outputs:
% im            - output image array
%
% See also elf_imfinfo, elf_io_loaddng.

if nargin < 2, ignoreCompressed = false; end % throw an error if compressed DNGs are present

[~,~,ext] = fileparts(fullfilename); % using info.Format does not work for raw files, as they are usually tif format
switch lower(ext(2:end))
    case {'tif', 'tiff', 'jpg', 'jpeg', 'bmp', 'gif', 'png', 'ppm'}
        im = imread(fullfilename);
    case 'dng'
        try
            im = elf_io_loaddng(fullfilename);
        catch err
            if strcmp(err.identifier, 'ELF:io:dngCompressed')
                [~, datasetName] = fileparts(fileparts(fullfilename));
                if ignoreCompressed
                    errormsg = sprintf('A file in dataset \\bf\\it %s \\rm appears to be a compressed DNG. Please consult the manual on how to properly convert images to DNG using "Adobe DNG Converter"', elf_support_removeTex(datasetName));
                    uiwait(errordlg(errormsg, 'Compressed DNG', struct('Interpreter', 'tex', 'WindowStyle', 'modal')));
                    im = imread(fullfile('static', 'no_img.jpg'));
                else
                    errormsg = sprintf('A file in dataset %s appears to be a compressed DNG. Please consult the manual on how to properly convert images to DNG using "Adobe DNG Converter"', datasetName);
                    error('ELF:io:dngCompressed', errormsg); %#ok<SPERR>
                end
            else
                rethrow(err);
            end
        end
    case 'nef'
        im = zeros(3, 3, 3); % just something to display a black image in ELF maingui
    case {'cr2', 'crw', 'kdc', 'arw', 'srf', 'sr2', 'bay', 'dcs', 'dcr', 'drf', 'k25', 'nrw', 'orf', 'pef', 'ptx', 'raw', 'rw2', 'rwl'}
        % these are the most common raw formats for Canon/Nikon/Casio/Sony/Kodak/Olympus/Pentax/Panasonic/Minolta cameras
        error('ELF currently does not process %s files, but it should be possible using dcraw. Create an entry in elf_imread.m');
    otherwise
        fprintf('Unknown extension %s. Attempting to read with Matlab''s imread function.\nTo disable this message, create an entry for this file type in elf_imread.m\n', ext);
        im = imread(fullfilename);
end



end %main

