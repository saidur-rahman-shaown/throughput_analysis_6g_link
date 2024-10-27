function resultsPerWorker = pdschLink(simParameters,totalNumSlots,workerId)
% PDSCH link simulation
    
    % Take copies of channel-level parameters to simplify subsequent parameter referencing 
    carrier = simParameters.Carrier;
    pdsch = simParameters.PDSCH;
    pdschextra = simParameters.PDSCHExtension;

    % Results storage
    result = struct(NumSlots=0,NumBits=0,NumCorrectBits=0);
    resultsPerWorker = repmat(result,1,numel(simParameters.SNRdB));

    % Create DL-SCH encoder/decoder
    [encodeDLSCH,decodeDLSCH] = dlschEncoderDecoder(pdschextra);

    % OFDM waveform information
    ofdmInfo = hpre6GOFDMInfo(carrier);
        
    % Create CDL channel
    channel = simParameters.Channel;
    % channel = hArrayGeometry(channel,simParameters.NTxAnts,simParameters.NRxAnts);
    % nTxAnts = prod(channel.TransmitAntennaArray.Size);
    % nRxAnts = prod(channel.ReceiveAntennaArray.Size);
    % channel.DelayProfile = simParameters.DelayProfile;
    % channel.DelaySpread = simParameters.DelaySpread;
    % channel.MaximumDopplerShift = simParameters.MaximumDopplerShift;
    % channel.SampleRate = ofdmInfo.SampleRate;
    % % New seed for each worker, but the same for each SNR point so they all
    % % experience the same channel realization.
    % channel.Seed = randi([0 2^32-1]);

    chInfo = info(channel);
    maxChDelay = chInfo.MaximumChannelDelay;

    % Set up redundancy version (RV) sequence for all HARQ processes
    if simParameters.PDSCHExtension.EnableHARQ        
        rvSeq = [0 2 3 1];
    else
        % HARQ disabled - single transmission with RV=0, no retransmissions
        rvSeq = 0;
    end

    % for all SNR points
    for snrIdx = 1:length(simParameters.SNRdB)

        % Noise power calculation
        SNR = 10^(simParameters.SNRdB(snrIdx)/10); % Calculate linear noise gain
        N0 = 1/sqrt(double(ofdmInfo.Nfft)*SNR*simParameters.NRxAnts);
        % Get noise power per resource element (RE) from noise power in the
        % time domain (N0^2)
        nPowerPerRE = N0^2*ofdmInfo.Nfft;

        % Reset the channel and DL-SCH decoder at the start of each SNR simulation
        reset(channel);
        reset(decodeDLSCH);        

        % Specify the fixed order in which we cycle through the HARQ process IDs
        harqSequence = 0:pdschextra.NHARQProcesses-1;

        % Initialize the state of all HARQ processes
        harqEntity = HARQEntity(harqSequence,rvSeq,pdsch.NumCodewords);

        % Obtain a precoding matrix (wtx) to be used in the transmission of the
        % first transport block
        estChannelGrid = getInitialChannelEstimate(carrier,simParameters.NTxAnts,channel);    
        wtx = hSVDPrecoders(carrier,pdsch,estChannelGrid,pdschextra.PRGBundleSize);

        %  Progress when parallel processing is enabled
        if (simParameters.enableParallelism && workerId==1)
            fprintf('Simulating SNR=%.2f dB, progress: \n0%% \n',simParameters.SNRdB(snrIdx))
        end

        % Process all the slots per worker
        for nSlot = 0:totalNumSlots-1

            % New slot number
            carrier.NSlot = nSlot;

            % Calculate the transport block sizes for the transmission in the slot
            [pdschIndices,pdschIndicesInfo] = hpre6GPDSCHIndices(carrier,pdsch);
            trBlkSizes = getTBS(pdsch.Modulation,pdsch.NumLayers,numel(pdsch.PRBSet),pdschIndicesInfo.NREPerPRB,pdschextra.TargetCodeRate);

            % Generate new data and DL-SCH encode
            codedTrBlocks = getDLSCHCodeword(encodeDLSCH,trBlkSizes,pdsch.Modulation,pdsch.NumLayers,pdschIndicesInfo.G,harqEntity);
        
            % PDSCH modulation of codeword(s), MIMO precoding and OFDM
            [txWaveform,pdschSymbols]= hPDSCHTransmit(carrier,pdsch,codedTrBlocks,wtx);

            % Pass data through channel model
            txWaveform = [txWaveform; zeros(maxChDelay,size(txWaveform,2))];
            [rxWaveform,pathGains,sampleTimes] = channel(txWaveform);

            % Add noise
            noise = N0*randn(size(rxWaveform),"like",rxWaveform);
            rxWaveform = rxWaveform + noise;

            % Synchronization, OFDM demodulation, channel estimation,
            % equalization, and PDSCH demodulation            
            pathFilters = getPathFilters(channel);
            
            perfEstConfig = perfectEstimatorConfig(pathGains,sampleTimes,pathFilters,nPowerPerRE,simParameters.PerfectChannelEstimator);
            [dlschLLRs,wtx,pdschEq] = hPDSCHReceive(carrier,pdsch,pdschextra,rxWaveform,wtx,perfEstConfig);

            % Display EVM per layer, per slot and per RB
            if (simParameters.DisplayDiagnostics)
                gridSize = [carrier.NSizeGrid*12 carrier.SymbolsPerSlot nTxAnts];
                plotLayerEVM(totalNumSlots,nSlot,pdsch,gridSize,pdschIndices,pdschSymbols,pdschEq,simParameters.SNRdB(snrIdx));
            end

            % Decode the DL-SCH transport channel

            % If new data because of previous RV sequence time out then flush decoder soft buffer explicitly
            for cwIdx = 1:pdsch.NumCodewords
                if harqEntity.NewData(cwIdx) && harqEntity.SequenceTimeout(cwIdx)
                    resetSoftBuffer(decodeDLSCH,cwIdx-1,harqEntity.HARQProcessID);
                end
            end
            decodeDLSCH.TransportBlockLength = trBlkSizes;
            blkerr = getTransportBlockCRC(decodeDLSCH,dlschLLRs,pdsch,harqEntity); 

            % Update current process with CRC error and advance to next process
            procstatus = updateAndAdvance(harqEntity,blkerr,trBlkSizes,pdschIndicesInfo.G);
            if (simParameters.DisplaySimulationInformation && ~simParameters.enableParallelism)
                fprintf('(%3.2f%%), SNR=%.2f dB, NSlot=%d, %s\n',100*(nSlot+1)/totalNumSlots,simParameters.SNRdB(snrIdx),nSlot,procstatus);
            elseif (simParameters.enableParallelism && workerId==1 && ~mod((nSlot+1),ceil((10*totalNumSlots)/100))) % Progress when parallel processing is enabled
                % Update progress with approximately 10% steps
                fprintf('%3.2f%% \n',100*(nSlot+1)/totalNumSlots)
            end

            % SNR point simulation results            
            resultsPerWorker(snrIdx).NumSlots = resultsPerWorker(snrIdx).NumSlots+1;
            resultsPerWorker(snrIdx).NumBits = resultsPerWorker(snrIdx).NumBits+sum(trBlkSizes);
            resultsPerWorker(snrIdx).NumCorrectBits = resultsPerWorker(snrIdx).NumCorrectBits+sum(~blkerr .* trBlkSizes);

        end % for nSlot = 0:totalNumSlots

    end % for all SNR points
end