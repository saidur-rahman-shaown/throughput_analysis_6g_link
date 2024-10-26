%hpre6GPDSCHPrecode Precoding for PDSCH PRG bundling
%   [ANTSYM,ANTIND] = hpre6GPDSCHPrecode(CARRIER,PORTSYM,PORTIND,W)
%   performs the precoding for the PDSCH precoding resource block group
%   (PRG) bundling, as defined in TS 38.214 Section 5.1.2.3.
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
%   PORTSYM is a matrix of symbols to be precoded of size NRE-by-NLAYERS,
%   where NLAYERS is the number of layers.
% 
%   PORTIND is a matrix of the same size as PORTSYM, NRE-by-NLAYERS,
%   containing the 1-based linear indices of the symbols in PORTSYM. The
%   indices address a K-by-L-by-NLAYERS resource array. K is the number of
%   subcarriers, equal to CARRIER.NSizeGrid * 12. L is the number of OFDM
%   symbols in one slot, equal to CARRIER.SymbolsPerSlot. The precoding
%   performed by this function assumes that TS 38.211 Section 7.3.1.4 maps
%   layers to ports, that is, layers 0...NLAYERS-1 correspond to ports
%   0...NLAYERS-1.
%
%   W is an array of size NLAYERS-by-P-by-NPRG, where NPRG is the number of
%   PRGs in the carrier resource grid (see <a 
%   href="matlab:help('hpre6GPRGInfo')">hpre6GPRGInfo</a>). W defines a
%   separate precoding matrix of size NLAYERS-by-P for each PRG. Note that
%   W must contain precoding matrices for all PRGs between point A and the
%   last CRB of the carrier resource grid, inclusive.
%
%   ANTSYM is a matrix containing precoded PDSCH symbols. ANTSYM is of
%   size NRE-by-P, where NRE is number of PDSCH resource elements, and P is
%   the number of transmit antennas. 
%
%   ANTIND is a matrix containing the PDSCH antenna indices corresponding
%   to ANTSYM and is also of size NRE-by-P.
%
%   Optionally, PORTSYM and PORTIND can be of size NRE-by-R-by-P, where R
%   is the number of receive antennas. In this case, PORTSYM and PORTIND
%   define the symbols and indices of a PDSCH channel estimate. W must be
%   of size P-by-NLAYERS-by-NPRG. The channel estimate is precoded using
%   the P-by-NLAYERS matrices for each PRG bundle (the transpose of the
%   transmit precoding matrices). The outputs ANTSYM and ANTIND are of size
%   NRE-by-R-by-NLAYERS and provide the "effective channel" between receive
%   antennas and transmit layers. You can use this option to apply
%   precoding to a PDSCH allocation that you extract from the
%   antenna-oriented channel estimate returned by the
%   <a href="matlab:help('hpre6GPerfectChannelEstimate')"
%   >hpre6GPerfectChannelEstimate</a> function.
%   
%   Example:
%   % Perform PDSCH precoding using a PRG bundle size of 16 PRBs.
%   
%   % Configuration
%   carrier = pre6GCarrierConfig;
%   carrier.NSizeGrid = 330;
%   carrier.SubcarrierSpacing = 120;
%   pdsch = pre6GPDSCHConfig;
%   prgsize = 16;
%   prginfo = hpre6GPRGInfo(carrier,prgsize);
%
%   % Create PDSCH symbols
%   [portind,indinfo] = hpre6GPDSCHIndices(carrier,pdsch);
%   cw = randi([0 1],indinfo.G,1);
%   portsym = hpre6GPDSCH(carrier,pdsch,cw);
%
%   % Create random precoding matrix of correct size
%   nlayers = pdsch.NumLayers;
%   P = 4;
%   NPRG = prginfo.NPRG;
%   W = complex(randn([nlayers P NPRG]),randn([nlayers P NPRG]));
%
%   % Perform PDSCH precoding
%   [antsym,antind] = hpre6GPDSCHPrecode(carrier,portsym,portind,W);
%
%   See also hpre6GPRGInfo, hpre6GPDSCH, hpre6GPDSCHIndices.

%   Copyright 2023-2024 The MathWorks, Inc.

function [antsym,antind] = hpre6GPDSCHPrecode(carrier,portsym,portind,W)

    narginchk(4,4);

    % Validate carrier input
    mustBeA(carrier,'pre6GCarrierConfig');

    % Perform precoding to produce antenna symbols and antenna indices
    [antsym,antind] = nrPDSCHPrecode(carrier,portsym,portind,W);

end
