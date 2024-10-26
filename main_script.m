clearvars;
close all;
clc;
%%

simParameters = struct();       % Simulation parameters structure
simParameters.NFrames = 2;      % Number of 10 ms frames
simParameters.SNRdB = -10:2:-6; % SNR range (dB)
simParameters.PerfectChannelEstimator = false;
simParameters.DisplaySimulationInformation = true;
simParameters.DisplayDiagnostics = false;
%% For paralell computation

simParameters.enableParallelism = true;

%% Carrier , pdsch and propagation channel configuration

% Set carrier parameters
simParameters.Carrier = pre6GCarrierConfig;                       % Carrier resource grid configuration
simParameters.Carrier.NSizeGrid = 330;                            % Bandwidth in number of resource blocks
simParameters.Carrier.SubcarrierSpacing = 120;                    % Subcarrier spacing

% Set PDSCH parameters
simParameters.PDSCH = pre6GPDSCHConfig;                           % PDSCH definition for all PDSCH transmissions in the BLER simulation

% Define PDSCH time-frequency resource allocation per slot to be full grid (single full grid BWP) and number of layers
simParameters.PDSCH.PRBSet = 0:simParameters.Carrier.NSizeGrid-1;                % PDSCH PRB allocation
simParameters.PDSCH.SymbolAllocation = [0,simParameters.Carrier.SymbolsPerSlot]; % Starting symbol and number of symbols of each PDSCH allocation
simParameters.PDSCH.NumLayers = 1;                                               % Number of PDSCH transmission layers

% This structure is to hold additional simulation parameters for the DL-SCH and PDSCH
simParameters.PDSCHExtension = struct();             

% Define codeword modulation and target coding rate
% The number of codewords is directly dependent on the number of layers so ensure that layers are set first before getting the codeword number
if simParameters.PDSCH.NumCodewords > 1                           % Multicodeword transmission (when number of layers is > 4)
    simParameters.PDSCH.Modulation = {'16QAM','16QAM'};           % 'QPSK', '16QAM', '64QAM', '256QAM', '1024QAM'
    simParameters.PDSCHExtension.TargetCodeRate = [490 490]/1024; % Code rate used to calculate transport block sizes
else
    simParameters.PDSCH.Modulation = '16QAM';                     % 'QPSK', '16QAM', '64QAM', '256QAM', '1024QAM', '4096QAM'
    simParameters.PDSCHExtension.TargetCodeRate = 490/1024;       % Code rate used to calculate transport block sizes
end

% Disable PT-RS
simParameters.PDSCH.EnablePTRS = false;

% PDSCH PRB bundling (TS 38.214 Section 5.1.2.3)
simParameters.PDSCHExtension.PRGBundleSize = [];                  % Any positive power of 2, or [] to signify "wideband"

% HARQ process parameters
simParameters.PDSCHExtension.NHARQProcesses = 16;                 % Number of parallel HARQ processes to use
simParameters.PDSCHExtension.EnableHARQ = true;                   % Enable retransmissions for each process, using RV sequence [0,2,3,1]

% LDPC decoder parameters
simParameters.PDSCHExtension.LDPCDecodingAlgorithm = 'Normalized min-sum';
simParameters.PDSCHExtension.MaximumLDPCIterationCount = 20;

% Number of antennas
simParameters.NTxAnts = 32;                                       % Number of antennas (1,2,4,8,16,32,64,128,256,512,1024) >= NumLayers
simParameters.NRxAnts = 2;

% Define the general CDL propagation channel parameters
simParameters.DelayProfile = 'CDL-A';   
simParameters.DelaySpread = 10e-9;
simParameters.MaximumDopplerShift = 70;

% Cross-check the PDSCH configuration parameters against the channel geometry 
validateParameters(simParameters);
%% Paralell Computing Configuration
if (simParameters.enableParallelism && canUseParallelPool)
    pool = gcp; % create parallel pool, requires PCT
    numWorkers = pool.NumWorkers;
    maxNumWorkers = pool.NumWorkers;
else
    if (~canUseParallelPool && simParameters.enableParallelism)
        warning("Ignoring the value of enableParallelism ("+simParameters.enableParallelism+")"+newline+ ...
            "The simulation will run using serial execution."+newline+"You need a license of Parallel Computing Toolbox to use parallelism.")
    end
    numWorkers = 1;    % No parallelism
    maxNumWorkers = 0; % Used to convert the parfor-loop into a for-loop
end

str1 = RandStream('Threefry','Seed',1);
constantStream = parallel.pool.Constant(str1);
numSlotsPerWorker = ceil((simParameters.NFrames*simParameters.Carrier.SlotsPerFrame)/numWorkers);
disp("Parallelism: "+simParameters.enableParallelism)
disp("Number of workers: "+numWorkers)
disp("Number of slots per worker: "+numSlotsPerWorker)
disp("Total number of frames: "+(numSlotsPerWorker*numWorkers)/simParameters.Carrier.SlotsPerFrame)
%% pdsch link level simulation
% Results storage
result = struct(NumSlots=0,NumBits=0,NumCorrectBits=0);
results = repmat(result,numWorkers,numel(simParameters.SNRdB));

% Parallel processing, worker parfor-loop
parfor (pforIdx = 1:numWorkers,maxNumWorkers)     
    % Set random streams to ensure repeatability
    % Use substreams in the generator so each worker uses mutually independent streams
    stream = constantStream.Value;      % Extract the stream from the Constant
    stream.Substream = pforIdx;         % Set substream value = parfor index
    RandStream.setGlobalStream(stream); % Set global stream per worker

    % Per worker processing
    results(pforIdx,:) = pdschLink(simParameters,numSlotsPerWorker,pforIdx);
end

[throughput,throughputMbps,summaryTable] = processResults(simParameters,results);
disp(summaryTable)

figure;
plot(simParameters.SNRdB,throughput,'o-.')
xlabel('SNR (dB)'); ylabel('Throughput (%)'); grid on;
title(sprintf('%s (%dx%d) / NRB=%d / SCS=%dkHz', ...
              simParameters.DelayProfile,simParameters.NTxAnts,simParameters.NRxAnts, ...
              simParameters.Carrier.NSizeGrid,simParameters.Carrier.SubcarrierSpacing));

