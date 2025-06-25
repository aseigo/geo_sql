defmodule GeoSQL.PostGIS.Extension do
  @moduledoc """
  A type extension for PostGIS data in PostgreSQL databases.
  """
  @behaviour Postgrex.Extension

  def extensions do
    unquote(
      Enum.reduce(
        GeoSQL.Geometry.all_types(),
        [__MODULE__],
        fn type, acc ->
          [Module.concat(__MODULE__, type) | acc]
        end
      )
    )
  end

  @doc false
  def init(_opts), do: nil

  @doc false
  def matching(_), do: [type: "geometry", type: "geography"]

  @doc false
  def format(_), do: :binary

  @doc false
  def encode(_opts) do
    all_types = unquote(GeoSQL.Geometry.all_types())

    quote location: :keep do
      %x{} = geom when x in unquote(all_types) ->
        data = Geometry.to_ewkb(geom)
        [<<IO.iodata_length(data)::integer-size(32)>> | data]
    end
  end

  @doc false
  def decode(_opts) do
    quote location: :keep do
      <<len::integer-size(32), wkb::binary-size(len)>> ->
        {:ok, decoded} = Geometry.from_ewkb(wkb)
        decoded
    end
  end
end

for type <- GeoSQL.Geometry.all_types() do
  defmodule Module.concat(GeoSQL.PostGIS.Extension, type) do
    @moduledoc false
    def init(_), do: nil

    def matching(_),
      do: [
        type:
          unquote(Module.split(type) |> Enum.intersperse("_") |> to_string() |> String.downcase())
      ]

    def format(_), do: :binary

    def encode(_) do
      type = unquote(type)

      quote location: :keep do
        %x{} = geom when x == unquote(type) ->
          data = Geometry.to_ewkb(geom)
          [<<IO.iodata_length(data)::integer-size(32)>> | data]
      end
    end

    def decode(_opts) do
      type = unquote(type)

      quote location: :keep do
        <<len::integer-size(32), wkb::binary-size(len)>> ->
          {:ok, %x{} = decoded} = Geometry.from_ewkb(wkb)

          if x != unquote(type), do: nil, else: decoded
      end
    end
  end
end
