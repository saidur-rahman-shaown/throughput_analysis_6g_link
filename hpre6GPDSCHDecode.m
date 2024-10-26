%hpre6GPDSCHDecode Physical downlink shared channel decoding
%   [CWS,SYMBOLS] = hpre6GPDSCHDecode(CARRIER,PDSCH,SYM,NVAR) returns a cell
%   array CWS of soft bit vectors (codewords) and cell array SYMBOLS of
%   received constellation symbol vectors resulting from performing the
%   inverse of physical downlink shared channel processing as defined in TS
%   38.211 Sections 7.3.1.1 - 7.3.1.3, given the extended carrier
%   configuration CARRIER, extended downlink shared channel configuration
%   PDSCH, received symbols for each layer SYM, and optional noise variance
%   NVAR.
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
%      NID        - PDSCH scrambling identity (0...1023) (default []). Use
%                   empty ([]) to set the value to NCellID
%      RNTI       - Radio network temporary identifier (0...65535)
%                   (default 1)
%
%   SYM is a matrix of size NRE-by-NLAYERS, containing the received PDSCH
%   symbols for each layer. NRE is the number of QAM symbols (resource
%   elements) per layer assigned to the PDSCH. NLAYERS is the number of
%   layers.
%
%   NVAR is an optional nonnegative real scalar specifying the variance
%   of additive white Gaussian noise on the received PDSCH symbols. The
%   default value is 1e-10.
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
%   % Add noise to the PDSCH symbols and demodulate to produce soft bit 
%   % estimates
%
%   SNR = 30; % SNR in dB
%   rxsym = awgn(txsym,SNR);
%   nVar = db2pow(-SNR);
%   rxbits = hpre6GPDSCHDecode(carrier,pdsch,rxsym,nVar);
%
%   See also hpre6GPDSCH, pre6GCarrierConfig, pre6GPDSCHConfig.

%   Copyright 2023-2024 The MathWorks, Inc.

function [cws,symbols] = hpre6GPDSCHDecode(carrier,pdsch,sym,nVar)

    narginchk(4,4);

    % Validate carrier input
    mustBeA(carrier,'pre6GCarrierConfig');

    % Validate PDSCH input
    mustBeA(pdsch,'pre6GPDSCHConfig');

    % Perform PDSCH demodulation
    if any(strcmp(pdsch.Modulation, "4096QAM"))
        [cws,symbols] = pre6GPDSCHDecode(carrier,pdsch,sym,nVar);  
    else
        [cws,symbols] = nrPDSCHDecode(carrier,pdsch,sym,nVar);
    end

end

function [cws,symbols] = pre6GPDSCHDecode(carrier,pdsch,sym,nVar)

    rnti = pdsch.RNTI;               % Radio network temporary identifier

    if isempty(pdsch.NID)
        % If PDSCH scrambling identity is empty, use physical layer
        % cell identity
        nid = carrier.NCellID;
    else
        nid = pdsch.NID(1);
    end

    % Layer demapping, inverse of TS 38.211 Section 7.3.1.3
    symbols = nrLayerDemap(sym);

    % Establish number of codewords from output of layer demapping
    ncw = size(symbols,2);

    demodulated = cell(1,ncw);
    cws = cell(1,ncw);
    opts.MappingType = 'signed';
    opts.OutputDataType = 'double';
    modlist = {'pi/2-BPSK','BPSK','QPSK','16QAM','64QAM','256QAM','1024QAM','4096QAM'};
    bpsList = [1 1 2 4 6 8 10 12];

    for q = 1:ncw

        % Clip nVar to allowable value to avoid +/-Inf outputs
        if nVar < 1e-10
            nVar = 1e-10;
        end

        % Received codeword validation for data type, size and value check
        %validateattributes(in,{'double','single'},{'finite','nonnan'}, ...
        %   fcnName,'IN');
        coder.internal.errorIf(~(iscolumn(symbols{q}) || isempty(symbols{q})), ...
            'nr5g:nrSymbolModDemod:InvalidInputDim');

        if ncw == 2
            ind = strcmpi(modlist,pdsch.Modulation(q));
        else
            ind = strcmpi(modlist,pdsch.Modulation);
        end

        tmp = bpsList(ind);
        bps = tmp(1);
        modOrder = 2^bps;
     
        if modOrder == 4096

            % Compute symbol mapping indices for 4096QAM
            in = dec2bin(0:2^12-1) == '1';
            symINorm = 1/sqrt(2730) * (1 - 2*in(:,1)) .* (32 - (1 - 2*in(:,3)) .* (16 - (1 - 2*in(:,5)) .* (8 - (1 - 2*in(:,7)) .* (4 - (1 - 2*in(:,9)) .* (2 - (1 - 2*in(:,11)))))));
            symQNorm = 1/sqrt(2730) * (1 - 2*in(:,2)) .* (32 - (1 - 2*in(:,4)) .* (16 - (1 - 2*in(:,6)) .* (8 - (1 - 2*in(:,8)) .* (4 - (1 - 2*in(:,10)) .* (2 - (1 - 2*in(:,12)))))));
            
            % Sort constellation vectorizing from top left corner
            [~, symbolMap] = sort((symINorm - 1)*64 - symQNorm);
            symbolOrdVector = symbolMap - 1; % Range 0 to 4095

        else
            % Compute symbol mapping indices
            symbolOrdVector = nr5g.internal.generateSymbolOrderVector(bps);                 
        end

        % Perform demodulation
        demodulated{q} = comm.internal.qam.demodulate(symbols{q},modOrder,'custom',symbolOrdVector,1,'approxLLR',nVar,false);

        % Descrambling, inverse of TS 38.211 Section 7.3.1.1
        c = nrPDSCHPRBS(nid,rnti,q-1,length(demodulated{q}),opts);
        cws{q} = demodulated{q} .* c;

    end

end