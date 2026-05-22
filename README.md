# setup-proxy

Proxy bootstrap

You must have a server and domain name for this.

## Usage

Clone repository and switch into it:

```sh
git clone https://github.com/x13a/setup-proxy
cd setup-proxy
```

Run *setup.sh* file:

```sh
./setup.sh
```

Now you have to configure DNS records.  
Caddy is set to use following subdomains:

```env
IP_SUBDOMAIN=ip

# redir to your domain
# www
```

## License

MIT
