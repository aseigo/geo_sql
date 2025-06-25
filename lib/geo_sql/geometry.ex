defmodule GeoSQL.Geometry do
  @moduledoc """
  Geometry types for use with ecto. Supported types include:

    * GeoSQL.Geometry, a catch-all type
    * GeoSQL.Geometry.Point
    * GeoSQLGeometry.PointZ
    * GeoSQLGeometry.PointM
    * GeoSQLGeometry.PointZM
    * GeoSQLGeometry.LineString
    * GeoSQLGeometry.LineStringZ
    * GeoSQLGeometry.LineStringZM
    * GeoSQLGeometry.Polygon
    * GeoSQLGeometry.PolygonZ
    * GeoSQLGeometry.MultiPoint
    * GeoSQLGeometry.MultiPointZ
    * GeoSQLGeometry.MultiLineString
    * GeoSQLGeometry.MultiLineStringZ
    * GeoSQLGeometry.MultiLineStringZM
    * GeoSQLGeometry.MultiPolygon
    * GeoSQLGeometry.MultiPolygonZ
    * GeoSQLGeometry.GeometryCollection

  Example:

      defmodule MyApp.GeoTable do
        use Ecto.Schema

        schema "specified_columns" do
          field(:name, :string)
          field(:geometry, GeoSQL.Geometry) # will match any Geo type
          field(:point, GeoSQL.Geometry.Point) # will reject any non-Point data
          field(:linestring, GeoSQL.Geometry.LineStringZ) # will reject any non-LineStringZ data
        end
      end
  """

  alias Geometry.{
    Point,
    PointZ,
    PointM,
    PointZM,
    LineString,
    LineStringZ,
    LineStringM,
    LineStringZM,
    Polygon,
    PolygonZ,
    PolygonM,
    PolygonZM,
    MultiPoint,
    MultiPointZ,
    MultiPointM,
    MultiPointZM,
    MultiLineString,
    MultiLineStringZ,
    MultiLineStringM,
    MultiLineStringZM,
    MultiPolygon,
    MultiPolygonZ,
    MultiPolygonM,
    MultiPolygonZM,
    GeometryCollection,
    GeometryCollectionZ,
    GeometryCollectionM,
    GeometryCollectionZM
  }

  @types [
    "Point",
    "PointZ",
    "PointM",
    "PointZM",
    "LineString",
    "LineStringZ",
    "LineStringM",
    "LineStringZM",
    "Polygon",
    "PolygonZ",
    "PolygonM",
    "PolygonZM",
    "MultiPoint",
    "MultiPointZ",
    "MultiPointM",
    "MultiPointZM",
    "MultiLineString",
    "MultiLineStringZ",
    "MultiLineStringM",
    "MultiLineStringZM",
    "MultiPolygon",
    "MultiPolygonZ",
    "MultiPolygonM",
    "MultiPolygonZM"
  ]

  @geometries [
    Point,
    PointZ,
    PointM,
    PointZM,
    LineString,
    LineStringZ,
    LineStringM,
    LineStringZM,
    Polygon,
    PolygonZ,
    PolygonM,
    PolygonZM,
    MultiPoint,
    MultiPointZ,
    MultiPointM,
    MultiPointZM,
    MultiLineString,
    MultiLineStringZ,
    MultiLineStringM,
    MultiLineStringZM,
    MultiPolygon,
    MultiPolygonZ,
    MultiPolygonM,
    MultiPolygonZM,
    GeometryCollection,
    GeometryCollectionZ,
    GeometryCollectionM,
    GeometryCollectionZM
  ]

  @type t :: Geometry.t()

  use Ecto.Type

  @doc false
  def geometry_modules do
    Enum.map(
      @geometries,
      fn type -> GeoSQL.Geometry.create_geometry_module_name(type) end
    )
  end

  @doc false
  def all_types, do: @geometries

  @doc false
  def type, do: :geometry

  @doc false
  def blank?(_), do: false

  @doc false
  def load(%struct{} = geom) when struct in @geometries, do: {:ok, geom}

  def load(_data) do
    :error
  end

  @doc false
  def dump(%struct{} = geom) when struct in @geometries, do: {:ok, geom}

  def dump(_data) do
    :error
  end

  @doc false
  def cast({:ok, value}), do: cast(value)

  def cast(%struct{} = geom) when struct in @geometries, do: {:ok, geom}

  def cast(%{"type" => type, "coordinates" => _} = geom) when type in @types do
    do_cast(geom)
  end

  def cast(%{"type" => "GeometryCollection", "geometries" => _} = geom) do
    do_cast(geom)
  end

  def cast(%{type: type, coordinates: _} = geom) when type in @types do
    string_keys(geom)
    |> do_cast()
  end

  def cast(%{type: "GeometryCollection", geometries: _} = geom) do
    string_keys(geom)
    |> do_cast()
  end

  def cast(geom) when is_binary(geom) do
    do_cast(geom)
  end

  def cast(_data) do
    :error
  end

  @doc false
  def string_keys(input_map) when is_map(input_map) do
    Map.new(input_map, fn {key, val} -> {to_string(key), string_keys(val)} end)
  end

  def string_keys(input_list) when is_list(input_list) do
    Enum.map(input_list, &string_keys(&1))
  end

  def string_keys(other), do: other

  @doc false
  def embed_as(_), do: :self

  @doc false
  def equal?(a, b), do: a == b

  @doc false
  def create_geometry_module_name(type) do
    ["Geometry", subtype] = Module.split(type)
    Module.concat(GeoSQL.Geometry, subtype)
  end

  defp do_cast(geom) when is_binary(geom) do
    try do
      geom
      |> :json.decode()
      |> do_cast()
    rescue
      error in ErlangError ->
        {:error, [message: "Failed to decode JSON", reason: error.original]}
    end
  end

  defp do_cast(geom) do
    case Geometry.from_geo_json(geom) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, [message: "Failed to decode GeoJSON", reason: reason]}
    end
  end
end

for type <- GeoSQL.Geometry.all_types() do
  module_name = GeoSQL.Geometry.create_geometry_module_name(type)

  # e.g. GeoSQL.Geometry.Point or GeoSQL.Geometry.LinestringZM
  defmodule module_name do
    @moduledoc false
    @type t :: %unquote(type){}
    use Ecto.Type

    def type, do: unquote(String.to_atom("geo_#{type}"))

    def blank?(_), do: false

    def load(%unquote(type){} = geom), do: {:ok, geom}
    def load(_data), do: :error

    def dump(%unquote(type){} = geom), do: {:ok, geom}
    def dump(_data), do: :error

    def cast({:ok, value}), do: cast(value)
    def cast(%unquote(type){} = geom), do: {:ok, geom}

    def embed_as(_), do: :self

    def equal?(a, b), do: a == b
  end
end
