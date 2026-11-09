#!/bin/zsh
# Costruisce Tabby.app in app/build/ e la firma.
#   ./costruisci.sh          → costruisce (versione veloce, "release")
#   ./costruisci.sh prova    → prima esegue i test
# Firma: col certificato «Tabby» se c'è nel Portachiavi (così macOS ricorda il permesso
# Accessibilità tra una versione e l'altra); altrimenti firma "provvisoria" (ad-hoc), e il
# permesso va ridato dopo ogni costruzione.
set -e
cd "${0:A:h}"

if [[ "$1" == "prova" ]]; then swift test; fi

swift build -c release
APP=build/Tabby.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Tabby "$APP/Contents/MacOS/Tabby"
cp Info.plist "$APP/Contents/Info.plist"
cp ../assets/gatto-spento.png ../assets/gatto-acceso.png ../assets/gatto-intero-*-spento.png ../assets/gatto-intero-*-acceso.png "$APP/Contents/Resources/"

if security find-identity -p codesigning | grep -q '"Tabby"'; then   # autofirmato: macOS lo dice «non fidato», ma per firmare basta
  codesign --force --options runtime --entitlements Tabby.entitlements --sign "Tabby" "$APP"
  echo "Firmata col certificato Tabby."
else
  codesign --force --sign - "$APP"
  echo "Firmata in modo provvisorio (manca il certificato «Tabby»)."
fi
echo "Pronta: $(pwd)/$APP"
