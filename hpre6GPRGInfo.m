%hpre6GPRGInfo Precoding resource block group (PRG)-related information
%   INFO = hpre6GPRGInfo(CARRIER,PRGSIZE) provides information related to
%   precoding resource block group (PRG) bundling, defined in TS 38.214
%   Section 5.1.2.3.
%
%   CARRIER is an extended carrier configuration object, <a
%   href="matlab:help('pre6GCarrierConfig')"
%   >pre6GCarrierConfig</a>.
%   Only these object properties are relevant for this function:
%   NSizeGrid  - Number of resource blocks in carrier resource grid
%                (default 52)
%   NStartGrid - Start of carrier resource grid relative to CRB 0
%                (default 0)
%
%   PRGSIZE is the PRG bundle size (positive power of 2, or [] to indicate
%   'wideband').
%
%   INFO is a structure containing the fields:
%   NPRG       - Number of PRGs in common resource blocks 0...NCRB-1
%   PRGSet     - Column vector of 1-based PRG indices for each RB in the 
%                carrier grid, size CARRIER.NSizeGrid-by-1
%
%   The values of NPRG corresponding to values of PRGSIZE are as follows:
%   PRGSIZE =  N: NPRG = ceil(NCRB / N)
%   PRGSIZE = []: NPRG = 1 ('wideband')
%
%   Example:
%   % Get the PRG information for a carrier configuration with 330 
%   % resource blocks and a PRG bundle size of 16. The carrier has 21 PRGs,
%   % with the first twenty PRGs containing 16 PRBs, and the last PRG 
%   % containing 10 PRBs.
%
%   carrier = pre6GCarrierConfig;
%   carrier.NSizeGrid = 330;
%   carrier.SubcarrierSpacing = 120;
%   prgSize = 16;
%
%   prgInfo = hpre6GPRGInfo(carrier,prgSize);
%
%   See also pre6GCarrierConfig, hpre6GPDSCHPrecode.

%   Copyright 2023-2024 The MathWorks, Inc.

function info = hpre6GPRGInfo(carrier,prgsize)

    arguments
        carrier {mustBeA(carrier,'pre6GCarrierConfig')};
        prgsize {mustBeScalarOrEmpty, mustBeNumeric, ...
            mustBeInteger, mustBePositive};
    end

    % Calculate the number of carrier resource blocks (CRB) spanning the
    % carrier grid including the starting CRB offset
    NCRB = carrier.NStartGrid + carrier.NSizeGrid;

    % Handle the case of empty PRG size, which configures a single fullband
    % PRG
    prgsize = double(prgsize);
    if (isempty(prgsize))
        Pd_BWP = NCRB;
    else
        % Validate that PRG size is a positive power of two and is less
        % than NCRB. Allow PRG size 2 or 4 for any NCRB, for consistency
        % with nrPRGInfo
        valid = 2.^(1:max(2,floor(log2(NCRB))));
        if (~any(prgsize==valid))
            prgSizeError(prgsize);
        end
        Pd_BWP = prgsize;
    end

    % Calculate the number of precoding resource block groups
    NPRG = ceil(NCRB / Pd_BWP);

    % Calculate the 1-based PRG indices for each RB in the carrier grid
    prgset = ...
        nr5g.internal.prgSet(carrier.NSizeGrid,carrier.NStartGrid,NPRG);

    % Create the info output
    info.NPRG = NPRG;
    info.PRGSet = prgset;

end

function prgSizeError(prgsize)

    msg = ['The PRG bundle size (%d) must be a positive power of 2, '...
        'or use empty ([]) to indicate "wideband".'];
    error('nrx5g:hpre6GPRGInfo:InvalidPRGSize',msg,prgsize);

end
