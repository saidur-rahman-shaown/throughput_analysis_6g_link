
function [txWaveform,pdschSymbols] = hPDSCHTransmit(carrier,pdsch,cw,wtx)

%   Copyright 2023 The MathWorks, Inc.
            
    % Calculate the transport block sizes for the transmission in the slot
    pdschIndices = hpre6GPDSCHIndices(carrier,pdsch);
    
    % Create resource grid for a slot
    pdschGrid = hpre6GResourceGrid(carrier,size(wtx,2));
    
    % PDSCH modulation and precoding
    pdschSymbols = hpre6GPDSCH(carrier,pdsch,cw);
    [pdschAntSymbols,pdschAntIndices] = hpre6GPDSCHPrecode(carrier,pdschSymbols,pdschIndices,wtx);
    
    % PDSCH mapping in grid associated with PDSCH transmission period
    pdschGrid(pdschAntIndices) = pdschAntSymbols;
    
    % PDSCH DM-RS precoding and mapping
    dmrsSymbols = hpre6GPDSCHDMRS(carrier,pdsch);
    dmrsIndices = hpre6GPDSCHDMRSIndices(carrier,pdsch);
    [dmrsAntSymbols,dmrsAntIndices] = hpre6GPDSCHPrecode(carrier,dmrsSymbols,dmrsIndices,wtx);
    pdschGrid(dmrsAntIndices) = dmrsAntSymbols;

    % PDSCH PT-RS precoding and mapping
    ptrsSymbols = hpre6GPDSCHPTRS(carrier,pdsch);
    ptrsIndices = hpre6GPDSCHPTRSIndices(carrier,pdsch);
    [ptrsAntSymbols,ptrsAntIndices] = hpre6GPDSCHPrecode(carrier,ptrsSymbols,ptrsIndices,wtx);
    pdschGrid(ptrsAntIndices) = ptrsAntSymbols;        

    % OFDM modulation
    txWaveform = hpre6GOFDMModulate(carrier,pdschGrid);

end