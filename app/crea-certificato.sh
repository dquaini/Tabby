#!/bin/zsh
# Crea il certificato «Tabby» (autofirmato, Firma codice, 10 anni) nel Portachiavi «login».
# Serve una volta per Mac: con lui macOS ricorda il permesso Accessibilità tra una versione
# di Tabby e l'altra. macOS lo segna «non fidato»: è normale, per firmare basta.
#   ./crea-certificato.sh
set -e
if security find-identity -p codesigning | grep -q '"Tabby"'; then
  echo "Il certificato «Tabby» c'è già: niente da fare."; exit 0
fi
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
cat > "$D/tabby.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Tabby
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$D/tabby.cnf" \
  -keyout "$D/tabby.key" -out "$D/tabby.crt" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$D/tabby.key" -in "$D/tabby.crt" -name Tabby \
  -out "$D/tabby.p12" -passout pass:tabby 2>/dev/null
security import "$D/tabby.p12" -k ~/Library/Keychains/login.keychain-db -P tabby -T /usr/bin/codesign
echo "Fatto: certificato «Tabby» nel Portachiavi. Alla prima costruzione macOS chiede la password:"
echo "scrivila e premi «Consenti sempre»."
