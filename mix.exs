defmodule VintageNetWireguard.MixProject do
  use Mix.Project

  def project do
    [
      app: :vintage_net_wireguard,
      version: "0.1.0",
      elixir: "~> 1.13",
      compilers: [:elixir_make | Mix.compilers()],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:vintage_net, "~> 0.11"},
      {:temp, "~> 0.4"},
      {:net_address, "~> 0.3"},
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end
end
