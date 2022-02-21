defmodule VintageNetWireguard.ConfigFile do
  @moduledoc """
  Helpers for dealing with a wireguard configuration file
  """

  @doc """
  Parse a Wireguard config file into a map
  """
  @spec parse(Path.t()) :: map() | {:error, File.posix()}
  def parse(path) do
    case File.read(path) do
      {:ok, file} ->
        file
        |> String.split("\n")
        |> parse_lines(%{type: VintageNetWireguard})

      err ->
        err
    end
  end

  defp parse_lines([], acc), do: acc

  defp parse_lines(["[Peer]" <> _ | rest], acc) do
    peers = acc[:peers] || []
    {peer, rem} = parse_peer_lines(rest, %{})
    parse_lines(rem, Map.put(acc, :peers, [peer | peers]))
  end

  defp parse_lines(["PrivateKey" <> bin | rest], acc) do
    parse_lines(rest, Map.put(acc, :private_key, parse_val(bin)))
  end

  defp parse_lines(["ListenPort" <> bin | rest], acc) do
    val =
      parse_val(bin)
      |> String.to_integer()

    parse_lines(rest, Map.put(acc, :listen_port, val))
  end

  defp parse_lines(["FwMark" <> bin | rest], acc) do
    parse_lines(rest, Map.put(acc, :fw_mark, parse_val(bin)))
  end

  defp parse_lines(["Address" <> bin | rest], acc) do
    val =
      parse_val(bin)
      |> comma_separated()

    parse_lines(rest, Map.put(acc, :addresses, val))
  end

  defp parse_lines(["DNS" <> bin | rest], acc) do
    val =
      parse_val(bin)
      |> comma_separated()

    parse_lines(rest, Map.put(acc, :dns, val))
  end

  defp parse_lines(["MTU" <> bin | rest], acc) do
    val =
      parse_val(bin)
      |> String.to_integer()

    parse_lines(rest, Map.put(acc, :mtu, val))
  end

  defp parse_lines(["Table" <> bin | rest], acc) do
    val = if parse_val(bin) == "off", do: :off, else: :auto
    parse_lines(rest, Map.put(acc, :table, val))
  end

  defp parse_lines(["PreUp" <> bin | rest], acc) do
    parse_lines(rest, Map.put(acc, :pre_up, parse_val(bin)))
  end

  defp parse_lines(["PostUp" <> bin | rest], acc) do
    parse_lines(rest, Map.put(acc, :post_up, parse_val(bin)))
  end

  defp parse_lines(["PreDown" <> bin | rest], acc) do
    parse_lines(rest, Map.put(acc, :pre_down, parse_val(bin)))
  end

  defp parse_lines(["PostDown" <> bin | rest], acc) do
    parse_lines(rest, Map.put(acc, :post_down, parse_val(bin)))
  end

  defp parse_lines([_ | rest], acc), do: parse_lines(rest, acc)

  defp parse_peer_lines([], acc), do: {acc, []}

  defp parse_peer_lines(["[Peer]" <> _ | _] = rest, acc) do
    {acc, rest}
  end

  defp parse_peer_lines(["AllowedIPs" <> bin | rest], acc) do
    val =
      parse_val(bin)
      |> comma_separated()

    parse_peer_lines(rest, Map.put(acc, :allowed_ips, val))
  end

  defp parse_peer_lines(["PublicKey" <> bin | rest], acc) do
    parse_peer_lines(rest, Map.put(acc, :public_key, parse_val(bin)))
  end

  defp parse_peer_lines(["PresharedKey" <> bin | rest], acc) do
    parse_peer_lines(rest, Map.put(acc, :preshared_key, parse_val(bin)))
  end

  defp parse_peer_lines(["Endpoint" <> bin | rest], acc) do
    parse_peer_lines(rest, Map.put(acc, :endpoint, parse_val(bin)))
  end

  defp parse_peer_lines(["PersistentKeepalive" <> bin | rest], acc) do
    val =
      parse_val(bin)
      |> String.to_integer()

    parse_peer_lines(rest, Map.put(acc, :persistent_keepalive, val))
  end

  defp parse_peer_lines([_ | rest], acc), do: parse_peer_lines(rest, acc)

  defp parse_val(line) do
    Regex.run(~r/^\s?=\s?(.*)/, line, capture: :all_but_first)
    |> hd()
  end

  defp comma_separated(val), do: String.split(val, ~r/\s?,\s?/)
end
