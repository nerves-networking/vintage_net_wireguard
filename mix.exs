defmodule VintageNetWireguard.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/nerves-networking/vintage_net_wireguard"

  def project() do
    [
      app: :vintage_net_wireguard,
      version: @version,
      elixir: "~> 1.11",
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["mix_clean"],
      make_error_message: "",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [
        docs: :docs,
        "hex.build": :docs,
        "hex.publish": :docs
      ]
    ]
  end

  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps() do
    [
      {:vintage_net, "~> 0.11"},
      {:temp, "~> 0.4"},
      {:net_address, "~> 0.3"},
      {:elixir_make, "~> 0.6", runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :docs, runtime: false}
    ]
  end

  defp description() do
    "Wireguard VPN support for VintageNet"
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
    ]
  end

  defp docs() do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp package() do
    %{
      files: [
        "CHANGELOG.md",
        "lib",
        "LICENSES/*",
        "mix.exs",
        "Makefile",
        "NOTICE",
        "README.md",
        "REUSE.toml"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "REUSE Compliance" =>
          "https://api.reuse.software/info/github.com/nerves-networking/vintage_net_wireguard"
      }
    }
  end
end
