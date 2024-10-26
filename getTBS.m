function out = getTBS(mod,nlayers,nPRB,NREPerPRB,tcr)
    if ~any(mod == "4096QAM")
        out = nrTBS(mod,nlayers,nPRB,NREPerPRB,tcr);
    else
        out = 2*nrTBS("64QAM",nlayers,nPRB,NREPerPRB,tcr);
    end    
end