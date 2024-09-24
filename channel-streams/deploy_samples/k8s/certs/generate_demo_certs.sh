# Create a root certificate and private key to sign the certificates for your services
if ! [ -f ./example.com.key ]; then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
        -subj '/O=example Inc./CN=example.com' \
        -keyout ./example.com.key \
        -out ./example.com.crt
fi

# Generate a certificate and a private key for adfstreams.example.com:
openssl req \
    -out ./adfstreams.example.com.csr -newkey rsa:2048 -nodes \
    -keyout ./adfstreams.example.com.key \
    -subj "/CN=adfstreams.example.com/O=adf organization"

openssl x509 -req -sha256 -days 365 \
    -CA ./example.com.crt \
    -CAkey ./example.com.key -set_serial 0 \
    -in ./adfstreams.example.com.csr \
    -out ./adfstreams.example.com.crt

# upload cert and key to k8s
kubectl create -n istio-system secret tls adfstreams-credential \
  --key=./adfstreams.example.com.key \
  --cert=./adfstreams.example.com.crt

# clean up
rm ./adfstreams.example.com.csr