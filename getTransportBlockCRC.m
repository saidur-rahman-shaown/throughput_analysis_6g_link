function out = getTransportBlockCRC(decodeDLSCH,dlschLLRs,pdsch,harqEntity)

    mod = pdsch.Modulation;
    nlayers = pdsch.NumLayers;
    rv = harqEntity.RedundancyVersion;
    harqID = harqEntity.HARQProcessID;

    if ~any(mod == "4096QAM")
        [~,out] = decodeDLSCH(dlschLLRs,mod,nlayers,rv,harqID);
    else
        dlschInfo = nrDLSCHInfo(decodeDLSCH.TransportBlockLength,decodeDLSCH.TargetCodeRate);
        dlschLLRs = decodeReshape(dlschLLRs,dlschInfo.C,mod,nlayers);
        [~,out] = decodeDLSCH(dlschLLRs,"64QAM",nlayers,rv,harqID);
    end

end