defmodule GeoSQL do
  @moduledoc """
  GeoSQL provides access to GIS functions in SQL databases via Ecto. PostGIS 3.x and Spatialite are
  currently supported.

  SQL functions are sorted into modules by their appearance in standards (e.g. SQL/MM2 vs SQL/MM3),
  category or topic (such as topological and 3D functions), as well as their availability in
  specific implementations. This includes the following modules:

    * `GeoSQL.MM2`: functions from the SQL/MM v2 standard
    * `GeoSQL.MM3`: functions from the SQL/MM v3 standard
    * `GeoSQL.Common`: non-standard functions that are widely available
    * `GeoSQL.PostGIS`: functions only found in PostGIS

  This makes usage of feature sets self-documenting in the code, allowing developers to adopt or avoid
  functions that are not available in the databases the application uses.

  Where there are subtle differences between implementations of the same functions, GeoSQL strives to
  hide those differences behind single function calls.

  The `GeoSQL.Geometry` module provides access to geometric types in Ecto schemas.
  """

  @type fragment :: term
  @type geometry_input :: GeoSQL.Geometry.t() | fragment
  @type init_option :: {:json, atom} | {:decode_binary, :copy | :reference}
  @type init_options :: [init_option]

  @spec init(Ecto.Repo.t(), init_options) :: :ok
  def init(repo, opts \\ [json: Jason, decode_binary: :copy]) when is_atom(repo) do
    repo.__adapter__()
    |> register_types(repo, opts)
    |> init_spatial_capabilities(repo, opts)

    :ok
  end

  @doc """
  When returning a single geometry in an Ecto query `select` clause, geometries may
  be returned as raw binaries in some backends.

  To get `Geo` structs from such queries, pass the results of the query to `decode_geometry/2`
  to guarantee corectly decoded geometries regardless of the backend being used.

  ```elixir
        from(location in Location, select: MM2.boundary(location.geom))
        |> Repo.all()
        |> GeoSQL.decode_geometry(Repo)
  ```
  """
  def decode_geometry(%{} = geometry, _repo), do: geometry
  def decode_geometry(nil, _repo), do: nil
  def decode_geometry([], _repo), do: []

  def decode_geometry(query_result, repo) when is_binary(query_result) do
    case repo.__adapter__() do
      Ecto.Adapters.Postgres -> query_result
      Ecto.Adapters.SQLite3 -> decode_one(GeoSQL.SpatialLite.TypeExtension, query_result)
    end
  end

  def decode_geometry(query_results, repo) when is_list(query_results) do
    case repo.__adapter__() do
      Ecto.Adapters.Postgres ->
        query_results

      Ecto.Adapters.SQLite3 ->
        Enum.map(
          query_results,
          fn query_result -> decode_one(GeoSQL.SpatialLite.TypeExtension, query_result) end
        )
    end
  end

  @doc """
  When returning geometries as part of a map or list Ecto query `select` clause (as opposed to
  returning an `Ecto.Schema` struct, where geometries are automatically decoded), geometries may
  be returned as raw binaries in some backends.

  To get `Geo` structs from these queries, pass the results of the query to `decode_geometry/3`.

  The third `fields_to_decode` parameter is a list of the fields to decode. When the query
  results are lists, the `fields_to_decode` must be a list of integers that are the indexes
  of the elements to decode:

  ```elixir
        from(location in Location, select: [location.name, MM2.boundary(location.geom)])
        |> Repo.all()
        |> GeoSQL.decode_geometry(Repo, [1])
  ```

  When returning a map, `fields_to_decode` must be a list of field names:


  ```elixir
        from(location in Location, select: %{name: location.name, boundary: MM2.boundary(location.geom)]})
        |> Repo.all()
        |> GeoSQL.decode_geometry(Repo, ["boundary])
  ```
  """
  def decode_geometry(nil, _repo, _fields_to_decode), do: nil
  def decode_geometry([], _repo, _fields_to_decode), do: []

  def decode_geometry(query_results, repo, fields_to_decode) do
    case repo.__adapter__() do
      Ecto.Adapters.Postgres ->
        query_results

      Ecto.Adapters.SQLite3 ->
        decode_all(query_results, GeoSQL.SpatialLite.TypeExtension, fields_to_decode)
    end
  end

  defp decode_all(%{} = query_results, type_extension, fields_to_decode) do
    Enum.reduce(fields_to_decode, query_results, fn field, query_result ->
      encoded_field = Map.get(query_result, field)

      if encoded_field == nil do
        query_result
      else
        Map.put(query_result, field, decode_one(type_extension, encoded_field))
      end
    end)
  end

  defp decode_all([head | _] = query_results, type_extension, fields_to_decode)
       when is_list(head) or is_map(head) do
    Enum.map(query_results, fn query_result ->
      decode_all(query_result, type_extension, fields_to_decode)
    end)
  end

  defp decode_all(query_result, type_extension, fields_to_decode)
       when is_list(query_result) do
    query_result
    |> Enum.with_index(fn encoded_field, index ->
      if Enum.member?(fields_to_decode, index) do
        decode_one(type_extension, encoded_field)
      else
        encoded_field
      end
    end)
  end

  defp decode_one(type_extension, encoded_field) do
    case type_extension.decode_geometry(encoded_field) do
      {:ok, successfully_decoded_field} -> successfully_decoded_field
      :error -> encoded_field
      {:error, _} -> encoded_field
    end
  end

  defp init_spatial_capabilities(Ecto.Adapters.SQLite3 = adapter, repo, _opts) do
    run_query(repo, "SELECT InitSpatialMetadata()")
    adapter
  end

  defp init_spatial_capabilities(adapter, _repo, _opts) do
    adapter
  end

  defp register_types(Ecto.Adapters.Postgres = adapter, repo, opts) do
    types_module =
      repo.config()
      |> Keyword.get_lazy(:types, fn ->
        [app | _] = Module.split(repo)
        Module.concat(app, PostgresTypes)
      end)

    if not Code.ensure_loaded?(types_module) do
      Postgrex.Types.define(
        types_module,
        GeoSQL.PostGIS.Extension.extensions() ++ Ecto.Adapters.Postgres.extensions(),
        opts
      )
    end

    adapter
  end

  defp register_types(adapter, _repo, _opts), do: adapter

  defp run_query(repo, sql) do
    try do
      Ecto.Adapters.SQL.query!(repo.get_dynamic_repo(), sql)
      :ok
    rescue
      _ -> :error
    end
  end
end
