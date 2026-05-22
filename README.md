# proxy-host

Proxy over CDN bootstrap

You must have a server and domain name for this.

## Usage

Clone repository and switch into it:

```sh
git clone https://github.com/x13a/proxy-host
cd proxy-host
```

Run *setup.sh* file:

```sh
./setup.sh
```

Now you have to configure DNS records.  
Caddy is set to use following subdomains:

```env
# CDN origin, direct connection, token protected
ORIGIN_SUBDOMAIN=origin
# CDN, token protected
CLOUDFLARE_SUBDOMAIN=cloudflare.cdn
# ip lookup, direct connection
IP_SUBDOMAIN=ip

# redir to your domain
# default CDN, token protected
# www
```

CDN has to set request header to be able to connect.  
*X-Auth-Token* is used for this.

## License

MIT
