function out = decodeReshape(in,C,Modulation,NumLayers)
    % Do rate recovery for 4096QAM
    in = in{:};
    in = rateReshape("RateRecover",in,C,nr5g.internal.getQm(Modulation),NumLayers);

    % Undo rate recovery for 64QAM
    out = rateReshape("RateMatch",in,C,nr5g.internal.getQm('64QAM'),NumLayers);
    out = {out};
end