function e = bitDeinterleaving(e,E,Qm)
    e = reshape(e,Qm,E/Qm);
    e = e.';
    e = e(:);
end