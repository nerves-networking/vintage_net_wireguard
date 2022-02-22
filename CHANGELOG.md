# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.0] - 2022-02-22

Initial release with support for starting a Wireguard client connection

See the [README.md](README.md) for more information on configuration

### Added

* `VintageNetWireguard.ConfigFile.parse/1` for parsing a Wireguard `*.conf` file
  into the expected format for configuring with VintageNet
* Compilation of [`wg(8)`](https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8)
  utility

[v0.1.0]: https://github.com/nerves-networking/vintage_net_wireguard/releases/tag/v1.0.0
