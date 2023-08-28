defmodule VintageNetWireguard do
  @moduledoc File.read!("README.md")
             |> String.split("<!--- DOC !--->")
             |> Enum.at(1)

  @behaviour VintageNet.Technology

  import IP, only: [is_ip: 1, is_ipv4: 1, is_ipv6: 1]

  alias VintageNet.Interface.RawConfig

  require Logger

  defguard is_non_empty_string(str) when is_binary(str) and str != ""

  @required_config [
    private_key: :string,
    addresses: :list,
    peers: :list
  ]

  @required_peer [
    endpoint: :string,
    public_key: :string
  ]

  @default_allowed_ips [
    # 0.0.0.0/0
    {{0, 0, 0, 0}, 0},
    # ::/0
    {{0, 0, 0, 0, 0, 0, 0, 0}, 0}
  ]

  @impl VintageNet.Technology
  def normalize(%{type: __MODULE__} = config) do
    _ = ensure_required!(config, @required_config)

    config
    |> Map.put(:addresses, Enum.map(config.addresses, &normalize_address/1))
    |> normalize_fwmark()
    |> normalize_listen_port()
    |> normalize_dns()
    |> Map.put(:peers, Enum.map(config.peers, &normalize_peer/1))
  end

  defp ensure_required!(config, schema) do
    for {key, type} <- schema do
      case {config[key], type} do
        {v, :string} when is_non_empty_string(v) -> :ok
        {v, :list} when is_list(v) -> :ok
        _ -> raise ArgumentError, ":#{key} is required"
      end
    end
  end

  defp normalize_address(addr) when is_binary(addr) do
    result =
      if addr =~ ~r/\/\d+$/ do
        IP.Subnet.config_from_string(addr)
      else
        IP.from_string(addr)
      end

    case result do
      {:ok, ip, %{bit_length: len}} ->
        {ip, len}

      {:ok, ip} ->
        normalize_address(ip)

      {:error, err} ->
        raise ArgumentError, "Unable to parse address #{addr}: #{inspect(err)}"
    end
  end

  defp normalize_address({ip, prefix_length} = addr) when is_ip(ip) and is_integer(prefix_length),
    do: addr

  defp normalize_address(ip) when is_ipv6(ip), do: {ip, 128}
  defp normalize_address(ip) when is_ipv4(ip), do: {ip, 32}

  defp normalize_address(addr) do
    raise ArgumentError, "invalid address #{inspect(addr)}"
  end

  defp normalize_fwmark(%{fwmark: fwmark} = config) when is_integer(fwmark), do: config

  defp normalize_fwmark(%{fwmark: fwmark} = config) do
    Logger.warning("[VintageNetWireguard] Ignoring invalid FwMark: #{inspect(fwmark)}")
    Map.delete(config, :fwmark)
  end

  defp normalize_fwmark(config), do: config

  defp normalize_listen_port(%{listen_port: port} = config) when is_integer(port), do: config

  defp normalize_listen_port(%{listen_port: port} = config) do
    Logger.warning("[VintageNetWireguard] Ignoring invalid ListenPort: #{inspect(port)}")
    Map.delete(config, :listen_port)
  end

  defp normalize_listen_port(config), do: config

  defp normalize_dns(%{dns: dns} = config) when is_list(dns) do
    dns = for d <- dns, {ip, _prefix_len} = normalize_address(d), do: ip
    %{config | dns: dns}
  end

  defp normalize_dns(%{dns: dns} = config) do
    Logger.warning("[VintageNetWireguard] Ignoring invalid DNS: #{inspect(dns)}")
    Map.delete(config, :dns)
  end

  defp normalize_dns(config), do: config

  defp normalize_peer(peer) do
    _ = ensure_required!(peer, @required_peer)
    aips = peer[:allowed_ips] || @default_allowed_ips

    Map.put(peer, :allowed_ips, Enum.map(aips, &normalize_address/1))
    |> normalize_keepalive()
    |> normalize_preshared_key()
  end

  defp normalize_keepalive(%{persistent_keepalive: pk} = peer) when pk in 0..65535, do: peer

  defp normalize_keepalive(%{persistent_keepalive: pk} = peer) do
    Logger.warning(
      "[VintageNetWireguard] Ignoring invalid peer PersistentKeepalive: #{inspect(pk)}"
    )

    Map.delete(peer, :persistent_keepalive)
  end

  defp normalize_keepalive(peer), do: peer

  defp normalize_preshared_key(%{preshared_key: psk} = peer) when is_non_empty_string(psk),
    do: peer

  defp normalize_preshared_key(%{preshared_key: psk} = peer) do
    Logger.warning("[VintageNetWireguard] Ignoring invalid peer PresharedKey: #{inspect(psk)}")
    Map.delete(peer, :preshared_key)
  end

  defp normalize_preshared_key(peer), do: peer

  @impl VintageNet.Technology
  def to_raw_config(ifname, %{type: __MODULE__} = config, _opts) do
    normalized = normalize(config)

    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalized,
      child_specs: [{VintageNet.Connectivity.LANChecker, ifname}],
      required_ifnames: [],
      up_cmds: up_cmds(ifname, normalized),
      up_cmd_millis: 20_000,
      down_cmds: [
        {:fun, VintageNet.RouteManager, :clear_route, [ifname]},
        {:fun, VintageNet.NameResolver, :clear, [ifname]},
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", ifname, "label", ifname]},
        {:run, "ip", ["link", "set", ifname, "down"]}
      ]
    }
  end

  @impl VintageNet.Technology
  def check_system(_opts), do: {:error, "unimplemented"}

  @impl VintageNet.Technology
  def ioctl(_ifname, _cmd, _args), do: {:error, :unsupported}

  @doc """
  Path to wg executable
  """
  @spec wg() :: Path.t()
  def wg(), do: Path.join(:code.priv_dir(:vintage_net_wireguard), "wg")

  defp up_cmds(ifname, config) do
    add_addresses =
      for addr <- config.addresses do
        {:run, "ip", ["addr", "add", addr_subnet(addr), "dev", ifname, "label", ifname]}
      end

    [
      maybe_add_interface(ifname),
      {:fun, fn -> set_wg_interface(ifname, config) end},
      {:run_ignore_errors, "ip", ["addr", "flush", "dev", ifname, "label", ifname]},
      add_addresses,
      {:run, "ip", ["link", "set", ifname, "up"]},
      Enum.map(config.peers, &peer_commands(ifname, &1)),
      maybe_add_dns(ifname, config),
      # Make MTU configurable?
      {:run, "ip", ["link", "set", "mtu", "1420", "up", "dev", ifname]}
    ]
    |> List.flatten()
  end

  defp maybe_add_interface(ifname) do
    case System.cmd("ip", ["link", "show", ifname], stderr_to_stdout: true) do
      {_, 0} -> []
      _ -> {:run_ignore_errors, "ip", ["link", "add", ifname, "type", "wireguard"]}
    end
  end

  # TODO: ensure cleanup and fix this
  # Temp specs say this should return :ok, but it actually returns
  # a list paths. Need to suppress dialyzer until Temp is fixed
  # or alternate cleanup is implemented
  @dialyzer {:nowarn_function, set_wg_interface: 2}

  defp set_wg_interface(ifname, config) do
    with {:ok, tracker} <- Temp.track(),
         if_args = Enum.reduce(config, [], &add_if_arg/2),
         {_, 0} <- System.cmd(wg(), ["set", ifname | if_args], stderr_to_stdout: true),
         [_ | _] <- Temp.cleanup(tracker) do
      :ok
    else
      err ->
        Temp.cleanup()
        {:error, "[VintageNetWireguard] Failed to set interface - #{inspect(err)}"}
    end
  end

  defp add_if_arg({:private_key, key}, acc) do
    {:ok, path} = Temp.open(%{}, &IO.write(&1, key))
    ["private-key", path | acc]
  end

  defp add_if_arg({:fwmark, v}, acc), do: ["fwmark", "#{v}" | acc]
  defp add_if_arg({:listen_port, v}, acc), do: ["listen-port", "#{v}" | acc]
  defp add_if_arg(_, acc), do: acc

  defp peer_commands(ifname, peer) do
    [
      {:fun, fn -> set_peer(ifname, peer) end},
      # TODO: Maybe use VintageNet.RouteManager when IPv6 is supported?
      # {:fun, VintageNet.RouteManager, :set_route, [ifname, peer.allowed_ips, peer.endpoint]}
      Enum.map(peer.allowed_ips, &route_ip(ifname, &1))
    ]
  end

  defp set_peer(ifname, peer) do
    with {:ok, tracker} <- Temp.track(),
         # peer arg needs to be first
         peer_args = ["peer", peer.public_key | Enum.reduce(peer, [], &add_peer_arg/2)],
         {_, 0} <- System.cmd(wg(), ["set", ifname | peer_args], stderr_to_stdout: true) do
      _ = Temp.cleanup(tracker)
      :ok
    else
      {err, s} ->
        Logger.error("""
        [VintageNetWireguard] Nonzero exit setting peer: #{s}

        #{inspect(err)}
        """)

        _ = Temp.cleanup()

        {:error, :non_zero_exit}
    end
  end

  defp add_peer_arg({:allowed_ips, v}, acc) do
    addrs = Enum.map_join(v, ",", &addr_subnet/1)
    ["allowed-ips", addrs | acc]
  end

  defp add_peer_arg({:endpoint, v}, acc), do: ["endpoint", v | acc]
  defp add_peer_arg({:persistent_keepalive, v}, acc), do: ["persistent-keepalive", "#{v}" | acc]

  defp add_peer_arg({:preshared_key, v}, acc) do
    {:ok, path} = Temp.open(%{}, &IO.write(&1, v))
    ["preshared-key", path | acc]
  end

  defp add_peer_arg(_, acc), do: acc

  defp addr_subnet({ip, prefix_len}) do
    %IP.Subnet{routing_prefix: ip, bit_length: prefix_len}
    |> IP.Subnet.to_string()
  end

  defp maybe_add_dns(ifname, %{dns: dns} = config) do
    {:fun, VintageNet.NameResolver, :setup, [ifname, config[:domain], dns]}
  end

  defp maybe_add_dns(_, _), do: []

  defp route_ip(ifname, addr) do
    {:run, "ip", ["route", "add", addr_subnet(addr), "dev", ifname]}
  end
end
