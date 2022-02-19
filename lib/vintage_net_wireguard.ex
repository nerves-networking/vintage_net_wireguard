defmodule VintageNetWireguard do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @impl VintageNet.Technology
  def normalize(%{type: __MODULE__} = config) do
    config
  end

  @impl VintageNet.Technology
  def to_raw_config(ifname, %{type: __MODULE__} = config, _opts) do
    normalized = normalize(config)

    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalized,
      required_ifnames: [ifname],
      up_cmds: up_cmds(ifname, normalized),
      down_cmds: []
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
    set_cmd =
      {:run, wg(),
       [
         "set",
         ifname,
         "private-key",
         "<(echo #{config.private_key})",
         "peer",
         config.public_key,
         "endpoint",
         config.endpoint,
         "allowed-ips",
         Enum.join(config.allowed_ips, " "),
         "persistent-keepalive",
         "#{config.persisten_keepalive}"
       ]}

    # mtu_cmd = {:run, "ip", ["link", "set", "mtu", "1420", "up", "dev", ifname]}
    addrs =
      for addr <- config.addresses do
        # TODO: Add routes to addrs
        {:run, "ip", ["addr", "add", addr, "dev", ifname]}
      end

    [set_cmd | addrs]
  end
end
