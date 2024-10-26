function perfEstInfo = perfectEstimatorConfig(pathGains,sampleTimes,pathFilters,noiseEst,perfChEst)
% Perfect channel estimator configuration

    perfEstInfo.PathGains = pathGains;
    perfEstInfo.PathFilters = pathFilters;
    perfEstInfo.SampleTimes = sampleTimes;
    perfEstInfo.NoiseEstimate = noiseEst;
    perfEstInfo.PerfectChannelEstimator = perfChEst;

end
