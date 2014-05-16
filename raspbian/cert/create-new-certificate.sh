openssl genrsa -out key.pem 1024
openssl req -new -key key.pem -out site.csr  # common name == your domain
openssl x509 -req -days 365 -in site.csr -signkey key.pem -out cert.pem
