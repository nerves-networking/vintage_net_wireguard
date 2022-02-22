# VintageNetWireguard

**Experimental**

An attempt to support Wireguard VPN peer connections on Nerves devices. See
https://wireguard.com for more info

## Configuration
<!--- DOC !--->
Wireguard needs to configure an interface and peer connections for that
interface. Below is a list of the expected configuration parameters
which are referenced from [`wg(8)`](https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8)
and [`wg-quick(8)`](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8):

### Interface

| Key | `wg` name | Required? | Description |
| --- | --- | :---: | --- |
| `:private_key` | `PrivateKey` | X | base64 private key for the interface registered with the server |
| `:addresses` | `Address` | X | list of IP addresses for the connection to use (CIDR supported) |
| `:listen_port` | `ListenPort` | | port for the connection. Randomly assigned if empty or `0` |
| `:fwmark` | `FwMark` | | 32-bit fwmark for outgoing packets |
| `:dns` | `DNS` | | list of DNS IP's |
| `:peers` | `[PEER]` | | list of peer configs (see below) |

### Peer

| Key | `wg` name | Required? | Description |
| --- | --- | :---: | --- |
| `:public_key` | `PublicKey` | X | base64 public key |
| `:endpoint` | `Endpoint` | X | endpoint to the wireguard server which the peer attempts to connect |
| `:allowed_ips` | `AllowedIps` | X | list of IP addresses for allowed incoming packets and outgoing packets directed to. Defaults to `["0.0.0.0/0", "::0"]` |
| `:persistent_keepalive` | `PersistentKeepalive` | | optional integer seconds for sending an authenticated packet as a keepalive |

## Using Wireguard Config Files

Wireguard commonly uses `*.conf` configuration files to simplify the setup
process and `VintageNetWireguard` provides a helper function to parse those
config files into the expected format:

```elixir
iex)> {:ok, config} = VintageNetWireguard.ConfigFile.parse("/path/to/wg0.conf")
iex)> VintageNet.configure("wg0", config)
```
<!--- DOC !--->
## Goals/Ideas

- [X] Setup `wg*` network interfaces
- [ ] Notes/cookbook for setting up Wireguard server
  - [ ] fly.io
  - [ ] Another service?
- [X] Parse wireguard peer configs
- [ ] Potentially support authentication via other routes (i.e. NervesKey)
- [ ] Mechanism for registering a new peer with remote server
- [ ] Prevent storing private keys on disc
