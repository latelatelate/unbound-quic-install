# Unbound-QUIC-Install

This will install Unbound 1.22.0 with support for DNS over QUIC.

## Features:
- DNS over QUIC
- DNSSEC
- QNAME minimisation
- Prefetching
- Stale caching
- Minimal responses

**NOTE:** A valid SSL certificate is required in order to perform DNS over QUIC queries.

**Unbound built with:**
```
Version 1.22.0

Configure line: --build=x86_64-linux-gnu --prefix=/usr --includedir=/include --mandir=/share/man --infodir=/share/info --sysconfdir=/etc --localstatedir=/var --disable-option-checking --disable-silent-rules --libdir=/lib/x86_64-linux-gnu --runstatedir=/run --disable-maintainer-mode --disable-dependency-tracking --with-pythonmodule --with-pyunbound --enable-subnet --enable-dnstap --enable-systemd --with-libnghttp2 --with-chroot-dir= --with-dnstap-socket-path=/run/dnstap.sock --with-pidfile=/run/unbound.pid --with-libevent --enable-tfo-client --with-rootkey-file=/usr/share/dns/root.key --enable-tfo-server --with-ssl=/usr/local/openssl-quic --with-libngtcp2=/usr/local/openssl-quic LDFLAGS=-Wl,-rpath -Wl,/usr/local/openssl-quic/lib

Linked libs: libevent 2.1.12-stable (it uses epoll), OpenSSL 1.1.1o+quic  3 May 2022

Linked modules: dns64 python subnetcache respip validator iterator

TCP Fastopen feature available

BSD licensed, see LICENSE in source package for details.
Report bugs to unbound-bugs@nlnetlabs.nl or https://github.com/NLnetLabs/unbound/issues
```

## Install

```
  sudo apt update
  sudo apt install -y git

  git clone https://github.com/latelatelate/unbound-quic-install
  cd unbound-quic-install
  
  sudo ./unbound-quic-install.sh
```

## Testing 

Install a utility like [kdig](https://www.knot-dns.cz/docs/latest/html/man_kdig.html) to perform test queries:

```
  sudo apt update
  sudo apt install knot-dnsutils
```

Run a QUIC test query:

```
  # ipv4
  kdig +quic @127.0.0.1 -p 2853 example.com AA

  # ipv6
  kdig +quic @127.0.0.1 -p 2853 example.com AAAA
```

Answer query should show `status: NOERROR` with output like:

```
  ;; QUIC session (QUICv1)-(TLS1.3)-(ECDHE-SECP256R1)-(ECDSA-SECP256R1-SHA256)-(AES-256-GCM)
  ;; ->>HEADER<<- opcode: QUERY; status: NOERROR; id: 0
  ;; Flags: qr rd ra ad; QUERY: 1; ANSWER: 1; AUTHORITY: 0; ADDITIONAL: 1

  ;; EDNS PSEUDOSECTION:
  ;; Version: 0; flags: ; UDP size: 1232 B; ext-rcode: NOERROR

  ;; QUESTION SECTION:
  ;; example.com.                 IN      AAAA

  ;; ANSWER SECTION:
  example.com.            3600    IN      AAAA    2606:2800:21f:cb07:6820:80da:af6b:8b2c

  ;; Received 68 B
  ;; Time 2025-01-11 02:19:59 UTC
  ;; From 127.0.0.1@2853(UDP) in 96.6 ms
```