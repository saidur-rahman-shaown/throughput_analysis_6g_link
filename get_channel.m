function [channel, simParameters] = get_channel(simParameters)

channel = nrCDLChannel;
channel.DelayProfile = 'Custom';
channel.PathDelays = simParameters.pathToAs;
channel.AveragePathGains = simParameters.avgPathGains;
channel.AnglesAoD = simParameters.pathAoDs(1, :);       % azimuth of departure
channel.AnglesZoD = 90 - simParameters.pathAoDs(2, :);  % channel uses zenith angle, rays use elevation
channel.AnglesAoA = simParameters.pathAoAs(1, :);       % azimuth of arrival
channel.AnglesZoA = 90 - simParameters.pathAoAs(2, :);  % channel uses zenith angle, rays use elevation
channel.HasLOSCluster = simParameters.isLOS;
channel.CarrierFrequency = simParameters.fc;
channel.NormalizeChannelOutputs = false;                % do not normalize by the number of receive antennas
channel.NormalizePathGains = false;                     % retain the path gains


% Calculate wavelength based on carrier frequency
lambda = physconst('LightSpeed') / simParameters.fc;

% UE array (single panel)
ueArray = phased.NRRectangularPanelArray('Size', [simParameters.ueAntSize(1:2) 1 1], ...
                                         'Spacing', [0.5 * lambda * [1 1] 1 1]);
ueArray.ElementSet = {phased.IsotropicAntennaElement};  % isotropic antenna element
channel.ReceiveAntennaArray = ueArray;
channel.ReceiveArrayOrientation = [simParameters.ueArrayOrientation(1); ...
                                  (-1) * simParameters.ueArrayOrientation(2); 0];  % convert elevation to downtilt

% Base station array (single panel)
bsArray = phased.NRRectangularPanelArray('Size', [simParameters.bsAntSize(1:2) 1 1], ...
                                         'Spacing', [0.5 * lambda * [1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement('PolarizationAngle', -45), ...
                      phased.NRAntennaElement('PolarizationAngle', 45)};  % cross-polarized elements
channel.TransmitAntennaArray = bsArray;
channel.TransmitArrayOrientation = [simParameters.bsArrayOrientation(1); ...
                                   (-1) * simParameters.bsArrayOrientation(2); 0];  % convert elevation to downtilt

ofdmInfo = hpre6GOFDMInfo(simParameters.Carrier);

channel.SampleRate = ofdmInfo.SampleRate;

channel.ChannelFiltering = false;
[simParameters.pathGains,simParameters.sampleTimes] = channel();

pg=permute(simParameters.pathGains,[2 1 3 4]); % first dimension is the number of paths
if simParameters.isLOS
    % in LOS cases sum the first to paths, they correspond to the LOS ray
    pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)];
end
simParameters.pg = abs(pg).^2;
end