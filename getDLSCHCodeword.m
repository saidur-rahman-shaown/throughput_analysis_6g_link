function codedTrBlocks = getDLSCHCodeword(encodeDLSCH,trBlkSizes,Modulation,NumLayers,G,harqEntity)
% Get DL-SCH codeword

    % HARQ processing
    for cwIdx = 1:length(G)
        % If new data for current process and codeword then create a new DL-SCH transport block
        if harqEntity.NewData(cwIdx) 
            trBlk = randi([0 1],trBlkSizes(cwIdx),1);
            setTransportBlock(encodeDLSCH,trBlk,cwIdx-1,harqEntity.HARQProcessID);
        end
    end

    % Encode the DL-SCH transport blocks
    if ~any(Modulation == "4096QAM") 
        codedTrBlocks = encodeDLSCH(Modulation,NumLayers,G,harqEntity.RedundancyVersion,harqEntity.HARQProcessID);
    else
        codedTrBlocks = encodeDLSCH('64QAM',NumLayers,G,harqEntity.RedundancyVersion,harqEntity.HARQProcessID);
        dlschInfo = nrDLSCHInfo(trBlkSizes,encodeDLSCH.TargetCodeRate);            
        codedTrBlocks = encodeReshape(codedTrBlocks,dlschInfo.C,Modulation,NumLayers);
    end

end