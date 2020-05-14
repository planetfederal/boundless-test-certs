#!/bin/bash

# This takes a file with the name of 'planetfederal-test_name_w-chain.p12'
# and outputs all derivations for private, public and client components

# exit on errors
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
echo "$PWD"

conda_prfx=/opt/mc3

source ${conda_prfx}/etc/profile.d/conda.sh

conda_env=${conda_prfx}/envs/openssl-pki

if [ "${CONDA_PREFIX}" != "${conda_env}" ]; then
  conda activate "${conda_env}"
fi

name=email-joe-cac

prfx="planetfederal-test"
prfx_name="${prfx}_${name}"

key_sufx="key"
pubkey_sufx="pubkey"
cert_sufx="cert"

# Standard password for all input/output
pass="password"
w_pass="w-pass"
w_chain="w-chain"

# Input PKCS#12 file
p12_w_chain="${prfx_name}_${w_chain}.p12"

# Base PKCS#12 outputs
key_pk8="${prfx_name}-${key_sufx}.pk8" # unencrypted
cert_pem="${prfx_name}-${cert_sufx}.pem"

# Converted outputs
# - for unencrypted identity bundle
p12="${prfx_name}.p12"

# - for private key
key_pk8_pass="${prfx_name}-${key_sufx}_${w_pass}.pk8"
key_rsa="${prfx_name}-${key_sufx}.pem"
key_rsa_pass="${prfx_name}-${key_sufx}_${w_pass}.pem"
key_rsa_der="${prfx_name}-${key_sufx}.der"
key_pub_rsa="${prfx_name}-${pubkey_sufx}.pem"
key_pub_rsa_der="${prfx_name}-${pubkey_sufx}.der"

# - for client cert
cert_crt="${prfx_name}-${cert_sufx}.crt" # alternative PEM ext
cert_der="${prfx_name}-${cert_sufx}.der"
cert_cer="${prfx_name}-${cert_sufx}.cer" # alternative DER ext
cert_p7b="${prfx_name}-${cert_sufx}.p7b" # PKCS#7


pushd "${SCRIPT_DIR}/certs-keys"

# First, dump out unencrypted private key to PKCS#8 PEM
[ -f ${key_pk8} ] && rm ${key_pk8}
openssl pkcs12 -passin pass:${pass} -in ${p12_w_chain} -out ${key_pk8} -nodes -nocerts
# Strip the PKCS#12 'Bag Attributes'
sed -i '' -n '/^-----BEGIN PRIVATE KEY-----/,/^-----END PRIVATE KEY-----/p' ${key_pk8}

# Second, dump out client cert to PEM
[ -f ${cert_pem} ] && rm ${cert_pem}
openssl pkcs12 -passin pass:${pass} -in ${p12_w_chain} -out ${cert_pem} -nokeys -clcerts
# Strip the PKCS#12 'Bag Attributes'
sed -i '' -n '/^-----BEGIN CERTIFICATE-----/,/^-----END CERTIFICATE-----/p' ${cert_pem}

# Create a p12 file without the CA chain
[ -f ${p12} ] && rm ${p12}
openssl pkcs12 -passout pass:${pass} -export -out ${p12} -inkey ${key_pk8} -in ${cert_pem}


# Private key outputs from PEM

# - Encrypted PKCS#8 PEM
[ -f ${key_pk8_pass} ] && rm ${key_pk8_pass}
openssl pkcs8 -passout pass:${pass} -topk8 -inform PEM -in ${key_pk8} -outform PEM -out ${key_pk8_pass}

# - Older 'OpenSSL format' RSA PKCS#1 PEM
[ -f ${key_rsa} ] && rm ${key_rsa}
openssl rsa -inform PEM -in ${key_pk8} -outform PEM -out ${key_rsa}

# - Older 'OpenSSL format' RSA PKCS#1 PEM encrypted
[ -f ${key_rsa_pass} ] && rm ${key_rsa_pass}
openssl rsa -aes256 -passout pass:${pass} -inform PEM -in ${key_pk8} -outform PEM -out ${key_rsa_pass}

# - RSA PKCS#1 DER
[ -f ${key_rsa_der} ] && rm ${key_rsa_der}
openssl rsa -inform PEM -in ${key_pk8} -outform DER -out ${key_rsa_der}


# Public key outputs from PEM

# - RSA PKCS#1 PEM
[ -f ${key_pub_rsa} ] && rm ${key_pub_rsa}
openssl rsa -pubout -inform PEM -in ${key_rsa} -outform PEM -out ${key_pub_rsa}

# - RSA PKCS#1 DER
[ -f ${key_pub_rsa_der} ] && rm ${key_pub_rsa_der}
openssl rsa -pubout -inform PEM -in ${key_rsa} -outform DER -out ${key_pub_rsa_der}


# Client cert outputs from PEM

# - DER
[ -f ${cert_der} ] && rm ${cert_der}
openssl x509 -inform PEM -in ${cert_pem} -outform DER -out ${cert_der}

# - PKCS#7
[ -f ${cert_p7b} ] && rm ${cert_p7b}
openssl crl2pkcs7 -nocrl -inform PEM -certfile ${cert_pem} -outform DER -out ${cert_p7b}


# Alternate extensions
cp -f ${cert_der} ${cert_cer}
cp -f ${cert_pem} ${cert_crt}

popd