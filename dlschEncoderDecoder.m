function [encodeDLSCH,decodeDLSCH] = dlschEncoderDecoder(PDSCHExtension)
% Create and parameterize the DL-SCH encoder and decoder objects
    
    % Create DL-SCH encoder object
    encodeDLSCH = nrDLSCH;
    encodeDLSCH.MultipleHARQProcesses = true;
    encodeDLSCH.TargetCodeRate = PDSCHExtension.TargetCodeRate;
    
    % Create DL-SCH decoder object
    decodeDLSCH = nrDLSCHDecoder;
    decodeDLSCH.MultipleHARQProcesses = true;
    decodeDLSCH.TargetCodeRate = PDSCHExtension.TargetCodeRate;
    decodeDLSCH.LDPCDecodingAlgorithm = PDSCHExtension.LDPCDecodingAlgorithm;
    decodeDLSCH.MaximumLDPCIterationCount = PDSCHExtension.MaximumLDPCIterationCount;
end
