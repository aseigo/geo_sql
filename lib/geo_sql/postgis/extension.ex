defmodule GeoSQL.PostGIS.Extension do
  @moduledoc false
  @behaviour Postgrex.Extension

  @geo_types [
    Geo.GeometryCollection,
    Geo.LineString,
    Geo.LineStringZ,
    Geo.LineStringZM,
    Geo.MultiLineString,
    Geo.MultiLineStringZ,
    Geo.MultiLineStringZM,
    Geo.MultiPoint,
    Geo.MultiPointZ,
    Geo.MultiPolygon,
    Geo.MultiPolygonZ,
    Geo.Point,
    Geo.PointZ,
    Geo.PointM,
    Geo.PointZM,
    Geo.Polygon,
    Geo.PolygonZ
  ]

  def init(_opts), do: nil

  def matching(_) do
    Enum.reduce(
      @geo_types,
      [
        type: "geometry",
        type: "geography"
      ],
      fn struct_name, acc ->
        type =
          struct_name
          |> to_string()
          |> String.downcase()
          |> String.replace(".", "_")

        [{:type, type} | acc]
      end
    )
  end

  def format(_) do
    :binary
  end

  def encode(_opts) do
    quote location: :keep do
      %x{} = geom when x in unquote(@geo_types) ->
        data = Geo.WKB.encode_to_iodata(geom)
        [<<IO.iodata_length(data)::integer-size(32)>> | data]
    end
  end

  def decode(_opts) do
    quote location: :keep do
      <<len::integer-size(32), wkb::binary-size(len)>> ->
        Geo.WKB.decode!(wkb)
    end
  end
end
