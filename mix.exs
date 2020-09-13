defmodule Json.MixProject do
  use Mix.Project

  def project do
    [
      app: :jsonrfc,
      version: "0.1.0",
      elixir: "~> 1.10",
      description: description(),
      package: package(),
      deps: deps(),
      source_url: "https://github.com/lygaret/ex-jsonrfc"
    ]
  end

  def application, do: []

  defp deps do
    [
      {:espec, "~> 1.8.2", only: :test},
      {:coverex, "~> 1.4.10", only: :test},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
    ]
  end

  defp description, do: String.trim """
    Implementations of JSON RFC 6901 and 6902, Pointers and Patch respectively.
    Pointer allows evaluating and transforming a JSON document at a given keypath.
    Patch encodes operations that abstract pointer transformations.
  """

  defp package() do
    [
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/lygaret/ex-jsonrfc",
        "Homepage" => "https://accidental.cc"
      }
    ]
  end

end
