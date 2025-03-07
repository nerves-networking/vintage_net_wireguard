# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetWireguardTest do
  use ExUnit.Case
  doctest VintageNetWireguard

  @peer %{endpoint: "somewhere", public_key: "pubkey"}

  @config %{
    private_key: "key",
    addresses: [],
    peers: [@peer],
    fwmark: 1234,
    listen_port: 5678,
    type: VintageNetWireguard
  }

  describe "normalize/1" do
    test "requires :private_key" do
      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(Map.delete(@config, :private_key))
      end

      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(%{@config | private_key: ""})
      end
    end

    test "requires :addresses" do
      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(Map.delete(@config, :addresses))
      end

      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(%{@config | addresses: nil})
      end

      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(%{@config | addresses: "10.0.0.1"})
      end
    end

    test "requires :peers" do
      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(Map.delete(@config, :peers))
      end

      assert_raise ArgumentError, fn -> VintageNetWireguard.normalize(%{@config | peers: nil}) end

      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(%{@config | peers: "10.0.0.1"})
      end
    end

    test "peer requires endpoint" do
      assert_raise ArgumentError, fn ->
        bad = Map.delete(@peer, :endpoint)
        VintageNetWireguard.normalize(%{@config | peers: [bad]})
      end

      assert_raise ArgumentError, fn ->
        bad = %{@peer | endpoint: ""}
        VintageNetWireguard.normalize(%{@config | peers: [bad]})
      end

      assert_raise ArgumentError, fn ->
        bad = %{@peer | endpoint: nil}
        VintageNetWireguard.normalize(%{@config | peers: [bad]})
      end
    end

    test "peer requires public_key" do
      assert_raise ArgumentError, fn ->
        bad = Map.delete(@peer, :public_key)
        VintageNetWireguard.normalize(%{@config | peers: [bad]})
      end

      assert_raise ArgumentError, fn ->
        bad = %{@peer | public_key: ""}
        VintageNetWireguard.normalize(%{@config | peers: [bad]})
      end

      assert_raise ArgumentError, fn ->
        bad = %{@peer | public_key: nil}
        VintageNetWireguard.normalize(%{@config | peers: [bad]})
      end
    end

    test "valid addresses" do
      ipv4 = {{172, 31, 78, 149}, 32}
      ipv6 = {{65152, 0, 0, 0, 50397, 60671, 65200, 26324}, 128}

      addrs = [
        "172.31.78.149",
        "172.31.78.149/32",
        {172, 31, 78, 149},
        ipv4,
        "fe80::c4dd:ecff:feb0:66d4/128",
        "fe80::c4dd:ecff:feb0:66d4",
        {65152, 0, 0, 0, 50397, 60671, 65200, 26324},
        ipv6
      ]

      expected = [
        ipv4,
        ipv4,
        ipv4,
        ipv4,
        ipv6,
        ipv6,
        ipv6,
        ipv6
      ]

      assert %{addresses: ^expected} =
               VintageNetWireguard.normalize(%{@config | addresses: addrs})
    end

    test "valid fwmark" do
      fwmark = @config.fwmark
      assert %{fwmark: ^fwmark} = VintageNetWireguard.normalize(@config)
    end

    test "ignores invalid fwmark" do
      invalid = [nil, [], "foo", "1234", "0x1234"]

      for bad <- invalid do
        config = VintageNetWireguard.normalize(%{@config | fwmark: bad})
        refute Map.has_key?(config, :fwmark)
      end
    end

    test "valid listen_port" do
      listen_port = @config.listen_port
      assert %{listen_port: ^listen_port} = VintageNetWireguard.normalize(@config)
    end

    test "ignores invalid listen_port" do
      invalid = [nil, [], "foo", "1234", "0x1234"]

      for bad <- invalid do
        config = VintageNetWireguard.normalize(%{@config | listen_port: bad})
        refute Map.has_key?(config, :listen_port)
      end
    end

    test "ignores invalid :dns field" do
      config = VintageNetWireguard.normalize(Map.put(@config, :dns, "foo"))
      config2 = VintageNetWireguard.normalize(Map.put(@config, :dns, nil))

      refute Map.has_key?(config, :dns)
      refute Map.has_key?(config2, :dns)
    end

    test "fails with invalid DNS entries" do
      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(Map.put(@config, :dns, ["foo"]))
      end

      assert_raise ArgumentError, fn ->
        VintageNetWireguard.normalize(Map.put(@config, :dns, [nil]))
      end
    end

    test "valid :dns" do
      ipv4 = {172, 31, 78, 149}
      ipv6 = {65152, 0, 0, 0, 50397, 60671, 65200, 26324}

      dns = [
        "172.31.78.149",
        ipv4,
        "fe80::c4dd:ecff:feb0:66d4",
        ipv6
      ]

      expected = [
        ipv4,
        ipv4,
        ipv6,
        ipv6
      ]

      assert %{dns: ^expected} = VintageNetWireguard.normalize(Map.put(@config, :dns, dns))
    end

    test "valid peer preshared key" do
      p = Map.put(@peer, :preshared_key, "key")

      assert %{peers: [%{preshared_key: "key"}]} =
               VintageNetWireguard.normalize(%{@config | peers: [p]})
    end

    test "ignores invalid peer preshared key" do
      invalid = [nil, [], 123_445]

      for bad <- invalid do
        p = Map.put(@peer, :preshared_key, bad)
        %{peers: [updated]} = VintageNetWireguard.normalize(%{@config | peers: [p]})
        refute Map.has_key?(updated, :preshared_key)
      end
    end

    test "valid peer persistent_keepalive" do
      p = Map.put(@peer, :persistent_keepalive, 1234)

      assert %{peers: [%{persistent_keepalive: 1234}]} =
               VintageNetWireguard.normalize(%{@config | peers: [p]})
    end

    test "ignores invalid peer persistent_keepalive" do
      invalid = [nil, [], "123445", :bad]

      for bad <- invalid do
        p = Map.put(@peer, :persistent_keepalive, bad)
        %{peers: [updated]} = VintageNetWireguard.normalize(%{@config | peers: [p]})
        refute Map.has_key?(updated, :persistent_keepalive)
      end
    end
  end
end
