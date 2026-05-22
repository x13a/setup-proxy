var REG_NONE = NewRegistrar("none");
var DNS_CLOUDFLARE = NewDnsProvider("cloudflare");

var ip4 = IP("1.2.3.4");
var ip6 = "0:0:0:0:0:0:0:0";
var domain = "example.org";
var signal_subdomain = "sig-";

D(domain, REG_NONE, DnsProvider(DNS_CLOUDFLARE),
    DefaultTTL(1),
    A("ip", ip4),
    A("origin", ip4),
    A(signal_subdomain, ip4),
    A("@", ip4, CF_PROXY_ON),
    AAAA("ip", ip6),
    AAAA("origin", ip6),
    AAAA(signal_subdomain, ip6),
    AAAA("@", ip6, CF_PROXY_ON),
    CNAME("www", domain + ".", CF_PROXY_ON),
    CNAME("cloudflare.cdn", domain + ".", CF_PROXY_ON),
);
