#!/usr/bin/env bash
# Creates a self-signed code-signing identity in the login keychain, once per Mac.
# build-app.sh signs with it so the app's designated requirement (and with it the
# Input Monitoring grant) stays the same across rebuilds; ad-hoc signatures change every build.
set -euo pipefail

identity="GK61 Local Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"

main() {
    if has_identity; then
        echo "\"$identity\" already exists"
        return
    fi
    # Global, not local: the EXIT trap runs after main returns.
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT
    create_certificate "$workdir"
    import_into_keychain "$workdir"
    echo "Created \"$identity\""
}

has_identity() {
    security find-certificate -c "$identity" "$keychain" >/dev/null 2>&1
}

create_certificate() {
    local workdir="$1"
    cat >"$workdir/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = codesign
prompt = no
[dn]
CN = $identity
[codesign]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -config "$workdir/cert.cnf" -keyout "$workdir/key.pem" -out "$workdir/cert.pem" 2>/dev/null
}

# The .p12 password only protects the file in transit to the keychain; it never leaves the temp dir.
import_into_keychain() {
    local workdir="$1"
    local transfer_password
    transfer_password="$(openssl rand -hex 16)"
    openssl pkcs12 -export -inkey "$workdir/key.pem" -in "$workdir/cert.pem" \
        -name "$identity" -passout "pass:$transfer_password" -out "$workdir/identity.p12"
    # -T lets codesign use the private key without a keychain prompt on every build.
    security import "$workdir/identity.p12" -k "$keychain" -P "$transfer_password" -T /usr/bin/codesign
}

main "$@"
