#!/usr/bin/env bash
# Create a self-signed code-signing identity named "garminy-local" in your login
# keychain, once. scripts/bundle-mac.sh signs with it so that macOS keeps the
# companion's Bluetooth and Location permissions across rebuilds.
# macOS asks for your password to trust the certificate for code signing.
set -euo pipefail
NAME=garminy-local
if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "$NAME already exists."; exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cfg" <<CFG
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cfg" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
  -out "$TMP/id.p12" -passout pass:garminy 2>/dev/null
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P garminy -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k "$HOME/Library/Keychains/login.keychain-db" "$TMP/cert.pem"
echo "Created $NAME. Rebuild with scripts/bundle-mac.sh."
