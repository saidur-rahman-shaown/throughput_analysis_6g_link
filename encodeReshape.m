function out = encodeReshape(in,C,Modulation,NumLayers)
    % Undo rate matching for 64QAM
    out = rateReshape("RateRecover",in,C,nr5g.internal.getQm('64QAM'),NumLayers); 

    % Do rate matching for 4096QAM
    out = rateReshape("RateMatch",out,C,nr5g.internal.getQm(Modulation),NumLayers);
end

