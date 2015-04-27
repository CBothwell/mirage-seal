## mirage-seal

Use this tool to seal the contents of a directory into a static unikernel,
serving its contents over HTTPS.

### Install

```
$ opam remote add mirage-dev https://github.com/mirage/mirage-dev.git
$ opam pind add -n tcpip https//github.com/mirage/mirage-tcpip.git
$ opam pin add -y mirage-seal https://github.com/samoht/mirage-seal
```

### Use

To serve the data in `files/` using the certificates
`secrets/server.key` and `server.pem`, simply do:

```
$ mirage-seal --data=files/ --keys=secrets/ [--ip-address=<IP>]
$ xl create seal.xl -c
```

If `--ip-address` is not specified, the unikernel will use DHCP to
acquire an IP address on boot.

### Test

If you want to test `mirage-seal` locally, you can generate a self-signed
certificate using openSSL:

```
$ mkdir secrets
$ openssl genrsa -des3 -out server.key 2048
$ openssl req -new -key server.key -out server.csr -subj '/CN=<IP>'
$ openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.pem
```
