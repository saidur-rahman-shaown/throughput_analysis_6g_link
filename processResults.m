function [throughput,throughputMbps,summaryTable] = processResults(simParameters,results)
% Process multi-worker and multi-SNR results

    numSNRPts = size(results,2);
    
    totalSimulatedSlots = sum(reshape([results(:).NumSlots].',[],numSNRPts),1);
    totalSimulatedBits = sum(reshape([results(:).NumBits].',[],numSNRPts),1);
    totalCorrectBits = sum(reshape([results(:).NumCorrectBits].',[],numSNRPts),1);
    totalSimulatedFrames = totalSimulatedSlots/simParameters.Carrier.SlotsPerFrame;
    
    % Throughput results calculation
    throughput = 100*(totalCorrectBits./totalSimulatedBits);
    throughputMbps = 1e-6*totalCorrectBits/(simParameters.NFrames*10e-3);
    summaryTable = table(simParameters.SNRdB.',totalSimulatedBits.',totalSimulatedSlots.', ...
        totalSimulatedFrames.',throughput.',throughputMbps.');
    summaryTable.Properties.VariableNames = ["SNR" "Simulated bits" "Number of Tr Blocks" ...
        "Number of frames" "Throughput (%)" "Throughput (Mbps)"];

end