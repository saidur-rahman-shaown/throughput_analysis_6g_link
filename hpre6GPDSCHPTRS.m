%hpre6GPDSCHPTRS Physical downlink shared channel phase tracking reference signal
%   SYM = hpre6GPDSCHPTRS(CARRIER,PDSCH) returns the phase tracking
%   reference signal (PT-RS) symbols, SYM, of physical downlink shared
%   channel for the given extended carrier configuration object CARRIER and
%   extended channel transmission configuration object PDSCH according to
%   TS 38.211 Section 7.4.1.2.1.
%
%   CARRIER is an extended carrier configuration object as described in
%   <a href="matlab:help('pre6GCarrierConfig')"
%   >pre6GCarrierConfig</a> with the following properties:
%
%   NCellID           - Physical layer cell identity (0...1007) (default 1)
%   SubcarrierSpacing - Subcarrier spacing in kHz (default 15)
%   CyclicPrefix      - Cyclic prefix ('normal' (default), 'extended')
%   NSizeGrid         - Number of resource blocks in carrier resource grid
%                       (default 52)
%   NStartGrid        - Start of carrier resource grid relative to CRB 0
%                       (default 0)
%
%   PDSCH is the extended physical downlink shared channel configuration
%   object as described in <a href="matlab:help('pre6GPDSCHConfig')"
%   >pre6GPDSCHConfig</a> with the following properties:
%
%   NSizeBWP              - Size of the bandwidth part (BWP) in
%                           physical resource blocks (PRBs)
%                           (default [])
%   NStartBWP             - Starting PRB index of BWP relative to
%                           common resource block 0 (CRB 0) (default [])
%   ReservedPRB           - Cell array of object(s) containing the reserved
%                           physical resource blocks and OFDM symbols
%                           pattern, as described in <a href="matlab:help('nrPDSCHReservedConfig')">nrPDSCHReservedConfig</a>
%                           with properties:
%       PRBSet    - Reserved PRB indices in BWP (0-based) (default [])
%       SymbolSet - OFDM symbols associated with reserved PRBs over one or
%                   more slots (default [])
%       Period    - Total number of slots in the pattern period (default [])
%   ReservedRE            - Reserved resource element (RE) indices
%                           within BWP (0-based) (default [])
%   NumLayers             - Number of transmission layers (1...8)
%                           (default 1)
%   MappingType           - Mapping type of physical downlink shared
%                           channel ('A' (default), 'B')
%   SymbolAllocation      - Symbol allocation of physical downlink shared
%                           channel (default [0 14]). This property is a
%                           two-element vector. First element represents
%                           the start of OFDM symbol in a slot. Second
%                           element represents the number of contiguous
%                           OFDM symbols
%   PRBSet                - Resource block allocation (VRB or PRB indices)
%                           (default 0:51)
%   PRBSetType            - Type of indices used in the PRBSet property
%                           ('VRB' (default), 'PRB')
%   RNTI                  - Radio network temporary identifier (0...65535)
%                           (default 1)
%   DMRS                  - PDSCH-specific DM-RS configuration object, as
%                           described in <a href="matlab:help('nrPDSCHDMRSConfig')">nrPDSCHDMRSConfig</a> with properties:
%       DMRSConfigurationType  - DM-RS configuration type (1 (default), 2)
%       DMRSReferencePoint     - The reference point for the DM-RS
%                                sequence to subcarrier resource mapping
%                                ('CRB0' (default), 'PRB0'). Use 'CRB0', if
%                                the subcarrier reference point for DM-RS
%                                sequence mapping is subcarrier 0 of common
%                                resource block 0 (CRB 0). Use 'PRB0', if
%                                the reference point is subcarrier 0 of the
%                                first PRB of the BWP (PRB 0). The latter
%                                should be used when the PDSCH is signaled
%                                via CORESET 0. In this case the BWP
%                                parameters should also be aligned with
%                                this CORESET
%       DMRSTypeAPosition      - Position of first DM-RS OFDM symbol in a
%                                slot (2 (default), 3)
%       DMRSLength             - Number of consecutive DM-RS OFDM symbols
%                                (1 (default), 2)
%       DMRSAdditionalPosition - Maximum number of DM-RS additional
%                                positions (0...3) (default 0)
%       CustomSymbolSet        - Custom DM-RS symbol locations (0-based)
%                                (default []). This property is used to
%                                override the standard defined DM-RS symbol
%                                locations. Each entry corresponds to a
%                                single-symbol DM-RS
%       DMRSPortSet            - DM-RS antenna port set (0...11)
%                                (default []). The default value implies
%                                that the values are in the range from 0 to
%                                NumLayers-1
%       NIDNSCID               - DM-RS scrambling identity (0...65535)
%                                (default []). Use empty ([]) to set the
%                                value to NCellID
%       NSCID                  - DM-RS scrambling initialization
%                                (0 (default), 1)
%   EnablePTRS            - Enable or disable the PT-RS configuration
%                           (0 (default), 1). The value of 0 implies PT-RS
%                           is disabled and value of 1 implies PT-RS is
%                           enabled
%   PTRS                  - PDSCH-specific PT-RS configuration object, as
%                           described in <a href="matlab:help('nrPDSCHPTRSConfig')">nrPDSCHPTRSConfig</a> with properties:
%       TimeDensity      - PT-RS time density (1 (default), 2, 4)
%       FrequencyDensity - PT-RS frequency density (2 (default), 4)
%       REOffset         - PT-RS resource element offset
%                         ('00' (default), '01', '10', '11')
%       PTRSPortSet      - PT-RS antenna port set (default []). The default
%                          value implies the value is equal to the lowest
%                          DM-RS antenna port configured
%
%   Example:
%   % Generate PT-RS symbols for a carrier with 330 resource blocks
%   % and 120 kHz subcarrier spacing, consistent with a 500 MHz bandwidth.
%
%   carrier = pre6GCarrierConfig;
%   carrier.NSizeGrid = 330;
%   carrier.SubcarrierSpacing = 120;
%   pdsch = pre6GPDSCHConfig;
%   pdsch.EnablePTRS = true;
%   sym = hpre6GPDSCHPTRS(carrier,pdsch);
%
%   See also hpre6GPDSCHPTRSIndices, hpre6GPDSCHDMRS, pre6GPDSCHConfig, 
%   pre6GCarrierConfig.

%   Copyright 2023 The MathWorks, Inc.

function sym = hpre6GPDSCHPTRS(carrier,pdsch)

    narginchk(2,2);

    % Validate carrier input
    mustBeA(carrier,'pre6GCarrierConfig');

    % Validate PDSCH input
    mustBeA(pdsch,'pre6GPDSCHConfig');

    % Generate PT-RS
    sym = nrPDSCHPTRS(carrier,pdsch,OutputDataType='single');

end
