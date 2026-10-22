"""Aiuto comune dei test: Tabby è divisa in più file (tabby.lua + cartella tabby/)."""
import os, re

def carica(base):
    """Comando Lua che carica Tabby come fa Hammerspoon (dal file tabby.lua)."""
    return 'dofile([[' + base + '/tabby.lua]])'

def codice(base):
    """Tutto il testo del codice di Tabby, nell'ordine di caricamento."""
    entry = open(base + '/tabby.lua').read()
    m = re.search(r'local FILES = \{(.*?)\}', entry, re.S)
    nomi = re.findall(r'"(\w+)"', m.group(1))
    return entry + "\n".join(open(base + '/tabby/' + n + '.lua').read() for n in nomi)
