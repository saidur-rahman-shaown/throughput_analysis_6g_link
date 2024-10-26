function out = rateReshape(rateMode,in,C,Qm,nlayers)
   
    out = [];
    outlen = length(in);
    idx = 1;

    for r = 1:C 
        if r <= C-mod(outlen/(nlayers*Qm),C)
            E = nlayers*Qm*floor(outlen/(nlayers*Qm*C));
        else
            E = nlayers*Qm*ceil(outlen/(nlayers*Qm*C));
        end

        if rateMode == "RateRecover"
            tmpOut = bitDeinterleaving(in(idx:E+idx-1),E,Qm);
        elseif rateMode == "RateMatch"
            tmpOut = bitInterleaving(in(idx:E+idx-1),E,Qm);
        end
        out = [out;tmpOut];
        idx = idx + E;

    end
 
