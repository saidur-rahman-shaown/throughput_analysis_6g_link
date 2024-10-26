%hpre6GPDSCH Physical downlink shared channel
%   SYM = hpre6GPDSCH(CARRIER,PDSCH,CWS) returns a complex matrix SYM
%   containing the physical downlink shared channel modulation symbols as
%   defined in TS 38.211 Sections 7.3.1.1 - 7.3.1.3, given the extended
%   carrier configuration CARRIER, extended downlink shared channel
%   configuration PDSCH, and DL-SCH codeword(s) CWS.
%
%   CARRIER is an extended carrier configuration object as described in
%   <a href="matlab:help('pre6GCarrierConfig')"
%   >pre6GCarrierConfig</a> with the following properties:
%      NCellID - Physical layer cell identity (0...1007) (default 1)
%
%   PDSCH is the extended physical downlink shared channel configuration
%   object as described in <a href="matlab:help('pre6GPDSCHConfig')"
%   >pre6GPDSCHConfig</a> with the following properties:
%      Modulation - Modulation scheme(s) of codeword(s)
%                   ('QPSK' (default), '16QAM', '64QAM', '256QAM', 
%                   '1024QAM', '4096QAM')
%      NumLayers  - Number of transmission layers (1...8) (default 1)
%      NID        - PDSCH scrambling identity (0...1023) (default []). Use
%                   empty ([]) to set the value to NCellID
%      RNTI       - Radio network temporary identifier (0...65535)
%                   (default 1)
%
%   CWS represents one or two DL-SCH codewords as described in TS 38.212
%   Section 7.2.6. CWS can be a column vector (representing one codeword)
%   or a cell array of one or two column vectors (representing one or two
%   codewords).
%
%   Example:
%   % Generate PDSCH symbols for a single codeword of 8000 bits, using
%   % 256QAM modulation and 4 layers
%
%   carrier = pre6GCarrierConfig;
%   carrier.NCellID = 42;
%   pdsch = pre6GPDSCHConfig;
%   pdsch.Modulation = '256QAM';
%   pdsch.NumLayers = 4;
%   pdsch.RNTI = 6143;
%   data = randi([0 1],8000,1);
%   txsym = hpre6GPDSCH(carrier,pdsch,data);
%
%   See also hpre6GPDSCHDecode, pre6GCarrierConfig, pre6GPDSCHConfig.

%   Copyright 2023-2024 The MathWorks, Inc.

function sym = hpre6GPDSCH(carrier,pdsch,cws)

    narginchk(3,3);

    % Validate carrier input
    mustBeA(carrier,'pre6GCarrierConfig');

    % Validate PDSCH input
    mustBeA(pdsch,'pre6GPDSCHConfig');

    % Perform PDSCH modulation
    if any(strcmp(pdsch.Modulation, "4096QAM")) 
        sym = pre6GPDSCH(carrier,pdsch,cws,'single');
    else
        sym = nrPDSCH(carrier,pdsch,cws,OutputDataType='single');
    end

end

function sym = pre6GPDSCH(carrier,pdsch,cws,OutputDataType)

    nlayers = pdsch.NumLayers;        % Number of layers
    ncw = pdsch.NumCodewords;         % Number of codewords
    if isempty(pdsch.NID)
        % If PDSCH scrambling identity is empty, use physical layer
        % cell identity
        nid = carrier.NCellID;
    else
        nid = pdsch.NID(1);
    end

    rnti = pdsch.RNTI; % Radio network temporary identifier

    % Validate number of data codewords
    if ~iscell(cws)
        cellcws = {cws};
    else
        if ncw==1 && numel(cws)==2 && isempty(cws{2})
            % The input looks like 2 codewords but the second codeword is
            % empty so treat it as a single codeword
            cellcws = cws(1);
        else
            cellcws = cws;
        end
    end
    coder.internal.errorIf(ncw~=numel(cellcws), ...
    'nr5g:nrPXSCH:InvalidDataNCW',nlayers,numel(cellcws),ncw);

    scrambled = cell(1,ncw);
    modulated = cell(1,ncw);
    modlist = {'pi/2-BPSK','BPSK','QPSK','16QAM','64QAM','256QAM','1024QAM','4096QAM'};
    bpsList = [1 1 2 4 6 8 10 12];

    for q = 1:ncw

        % Scrambling, TS 38.211 Section 7.3.1.1
        c = nrPDSCHPRBS(nid,rnti,q-1,length(cellcws{q}));
        scrambled{q} = xor(cellcws{q},c);

        % Input codeword validation for datatype, size and value check
        validateattributes(scrambled{q},{'double','int8','logical'},{'real','binary'}, ...
            'nrSymbolModulate','IN');
        coder.internal.errorIf(~(iscolumn(scrambled{q}) || isempty(scrambled{q})), ...
            'nr5g:nrSymbolModDemod:InvalidInputDim');

        if ncw == 2
            ind = strcmpi(modlist,pdsch.Modulation(q));
        else
            ind = strcmpi(modlist,pdsch.Modulation);
        end

        tmp = bpsList(ind);
        bps = tmp(1);
        modOrder = 2^bps;

        % Input vector length check
        coder.internal.errorIf(mod(numel(scrambled{q}),bps) ~= 0, ...
            'nr5g:nrSymbolModDemod:InvalidInputLength',numel(scrambled{q}),bps);

        % Input codeword processing
        if isempty(scrambled{q})
            modulated{q} = cast(zeros(size(scrambled{q}),'like',scrambled{q}),OutputDataType);
            break;
        end

        intmp = cast(scrambled{q},'single');

        if modOrder == 4096 %if 4096QAM

            % Compute symbol mapping indices for 4096QAM:
            in = dec2bin(0:2^12-1) == '1';
            symINorm = 1/sqrt(2730) * (1 - 2*in(:,1)) .* (32 - (1 - 2*in(:,3)) .* (16 - (1 - 2*in(:,5)) .* (8 - (1 - 2*in(:,7)) .* (4 - (1 - 2*in(:,9)) .* (2 - (1 - 2*in(:,11)))))));
            symQNorm = 1/sqrt(2730) * (1 - 2*in(:,2)) .* (32 - (1 - 2*in(:,4)) .* (16 - (1 - 2*in(:,6)) .* (8 - (1 - 2*in(:,8)) .* (4 - (1 - 2*in(:,10)) .* (2 - (1 - 2*in(:,12)))))));
            
            % Sort constellation vectorizing from top left corner
            [~, symbolMap] = sort( (symINorm - 1) * 64 - symQNorm );
            symbolOrdVector = symbolMap - 1; % Range 0 to 4095

        else
            % Compute symbol mapping indices
            symbolOrdVector = nr5g.internal.generateSymbolOrderVector(bps);
        end
        % Modulate the bits
        modulated{q} = comm.internal.qam.modulate(intmp,modOrder,'custom',symbolOrdVector,1,1,[]);
    end

    % Layer mapping, TS 38.211 Section 7.3.1.3
    sym = nrLayerMap(modulated,nlayers);

end
