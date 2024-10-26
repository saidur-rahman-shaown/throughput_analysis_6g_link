
function [dlschLLRs,newWtx,pdschEq] = hPDSCHReceive(carrier,pdsch,pdschextra,rxWaveform,wtx,perfectEstimateInfo)

%   Copyright 2023-2024 The MathWorks, Inc.

    perfectChannelEstimator = perfectEstimateInfo.PerfectChannelEstimator;
    pathGains = perfectEstimateInfo.PathGains;
    pathFilters = perfectEstimateInfo.PathFilters;
    
    % PDSCH indices and info
    [pdschIndices,pdschIndicesInfo] = hpre6GPDSCHIndices(carrier,pdsch);
    
    % PDSCH DM-RS indices and symbols
    dmrsSymbols = hpre6GPDSCHDMRS(carrier,pdsch);
    dmrsIndices = hpre6GPDSCHDMRSIndices(carrier,pdsch);    

    % PDSCH PT-RS precoding and mapping
    ptrsSymbols = hpre6GPDSCHPTRS(carrier,pdsch);
    ptrsIndices = hpre6GPDSCHPTRSIndices(carrier,pdsch);

    % Perfect synchronization. Use information provided by the channel to
    % find the strongest multipath component
    offset = nrPerfectTimingEstimate(pathGains,pathFilters);
    
    rxWaveform = rxWaveform(1+offset:end,:);

    % OFDM demodulation
    rxGrid = hpre6GOFDMDemodulate(carrier,rxWaveform);    

    if (perfectChannelEstimator)
        % Get perfect noise estimate and sampleTimes
        noiseEst = perfectEstimateInfo.NoiseEstimate;
        sampleTimes = perfectEstimateInfo.SampleTimes;    

        % Perfect channel estimation, using the value of the path gains
        % provided by the channel. This channel estimate does not include
        % the effect of transmitter precoding
        estChannelGridAnts = hpre6GPerfectChannelEstimate(carrier,pathGains,pathFilters,offset,sampleTimes);

        % Get PDSCH resource elements from the received grid and channel
        % estimate
        [pdschRx,pdschHest,~,pdschHestIndices] = nrExtractResources(pdschIndices,rxGrid,estChannelGridAnts);

        % Apply precoding to channel estimate
        pdschHest = hpre6GPDSCHPrecode(carrier,pdschHest,pdschHestIndices,permute(wtx,[2 1 3]));
    else
        % Practical channel estimation between the received grid and each
        % transmission layer, using the PDSCH DM-RS for each layer. This
        % channel estimate includes the effect of transmitter precoding
        [estChannelGridPorts,noiseEst] = hSubbandChannelEstimate(carrier,rxGrid,dmrsIndices,dmrsSymbols,pdschextra.PRGBundleSize,'CDMLengths',pdsch.DMRS.CDMLengths);

        % Average noise estimate across PRGs and layers
        noiseEst = mean(noiseEst,'all');

        % Get PDSCH resource elements from the received grid and channel
        % estimate
        [pdschRx,pdschHest] = nrExtractResources(pdschIndices,rxGrid,estChannelGridPorts);

        % Remove precoding from estChannelGridPorts to get channel estimate
        % w.r.t. antennas
        estChannelGridAnts = precodeChannelEstimate(carrier,estChannelGridPorts,conj(wtx));
    end

    % Get precoding matrix for next slot
    newWtx = hSVDPrecoders(carrier,pdsch,estChannelGridAnts,pdschextra.PRGBundleSize);

    % Equalization
    [pdschEq,csi] = nrEqualizeMMSE(pdschRx,pdschHest,noiseEst);

    % Common phase error (CPE) compensation
    if ~isempty(ptrsIndices)
        % Initialize temporary grid to store equalized symbols
        tempGrid = hpre6GResourceGrid(carrier,pdsch.NumLayers);

        % Extract PT-RS symbols from received grid and estimated channel
        % grid
        [ptrsRx,ptrsHest,~,~,ptrsHestIndices,ptrsLayerIndices] = nrExtractResources(ptrsIndices,rxGrid,estChannelGridAnts,tempGrid);
        ptrsHest = hpre6GPDSCHPrecode(carrier,ptrsHest,ptrsHestIndices,permute(wtx,[2 1 3]));

        % Equalize PT-RS symbols and map them to tempGrid
        ptrsEq = nrEqualizeMMSE(ptrsRx,ptrsHest,noiseEst);
        tempGrid(ptrsLayerIndices) = ptrsEq;

        % Estimate the residual channel at the PT-RS locations in
        % tempGrid
        cpe = hpre6GChannelEstimate(carrier,tempGrid,ptrsIndices,ptrsSymbols);

        % Sum estimates across subcarriers, receive antennas, and layers.
        % Then, get the CPE by taking the angle of the resultant sum
        cpe = angle(sum(cpe,[1 3 4]));

        % Map the equalized PDSCH symbols to tempGrid
        tempGrid(pdschIndices) = pdschEq;

        % Correct CPE in each OFDM symbol within the range of reference
        % PT-RS OFDM symbols
        symLoc = pdschIndicesInfo.PTRSSymbolSet(1)+1:pdschIndicesInfo.PTRSSymbolSet(end)+1;
        tempGrid(:,symLoc,:) = tempGrid(:,symLoc,:).*exp(-1i*cpe(symLoc));

        % Extract PDSCH symbols
        pdschEq = tempGrid(pdschIndices);
    end

    % Decode PDSCH physical channel
    [dlschLLRs,rxSymbols] = hpre6GPDSCHDecode(carrier,pdsch,pdschEq,noiseEst);

    % Scale LLRs by CSI
    csi = nrLayerDemap(csi); % CSI layer demapping
    for cwIdx = 1:pdsch.NumCodewords
        Qm = length(dlschLLRs{cwIdx})/length(rxSymbols{cwIdx}); % bits per symbol
        csi{cwIdx} = repmat(csi{cwIdx}.',Qm,1);                 % expand by each bit per symbol
        dlschLLRs{cwIdx} = dlschLLRs{cwIdx} .* csi{cwIdx}(:);   % scale by CSI
    end

end

function estChannelGrid = precodeChannelEstimate(carrier,estChannelGrid,W)
% Apply precoding matrix W to the last dimension of the channel estimate

    [K,L,R,P] = size(estChannelGrid);
    estChannelGrid = reshape(estChannelGrid,[K*L R P]);
    estChannelGrid = hpre6GPDSCHPrecode(carrier,estChannelGrid,reshape(1:numel(estChannelGrid),[K*L R P]),W);
    estChannelGrid = reshape(estChannelGrid,K,L,R,[]);

end
