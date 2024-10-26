function e = bitInterleaving(e,E,Qm)
    e = reshape(e,E/Qm,Qm);
    e = e.';
    e = e(:);
end 