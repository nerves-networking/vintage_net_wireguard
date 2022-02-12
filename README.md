# VintageNetWireguard

**Experimental**

An attempt to support Wireguard VPN peer connections on Nerves devices. See
https://wireguard.com for more info

## Goals/Ideas

- [ ] Setup `wg*` network interfaces
  * Should we support creating more than one `wg*` interface to
  support multiple peer configs?
- [ ] Notes/cookbook for setting up Wireguard server
  - [ ] fly.io
  - [ ] Another service?
- [ ] Parse wireguard peer configs
- [ ] Potentially support authentication via other routes (i.e. NervesKey)
- [ ] Mechanism for registering a new peer with remote server
