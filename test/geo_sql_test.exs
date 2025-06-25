defmodule GeoSQL.Test do
  use ExUnit.Case, async: true
  use GeoSQL.Test.Helper

  def decode({:ok, %{rows: result}}, repo, fields) do
    GeoSQL.decode_geometry(result, repo, fields)
  end

  for repo <- Helper.repos() do
    test "insert point (#{repo})" do
      geo = %Geometry.Point{coordinates: [30, -90], srid: 4326}

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, point) VALUES ($1, $2)",
          [
            42,
            geo
          ]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, point FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end

    test "insert with text column (#{repo})" do
      geo = %Geometry.Point{coordinates: [30, -90], srid: 4326}

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, t, point) VALUES ($1, $2, $3)",
          [
            42,
            "test",
            geo
          ]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, t, point FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [2])

      assert(result == [[42, "test", geo]])
    end

    test "insert pointz (#{repo})" do
      geo = %Geometry.PointZ{coordinates: [30, -90, 70], srid: 4326}

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, pointz) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, pointz FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end

    test "insert linestring (#{repo})" do
      geo = %Geometry.LineString{srid: 4326, coordinates: [[30, 10], [10, 30], [40, 40]]}

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, linestring) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, linestring FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end

    test "insert LineStringZ (#{repo})" do
      geo = %Geometry.LineStringZ{
        srid: 4326,
        coordinates: [[30, 10, 20], [10, 30, 2], [40, 40, 50]]
      }

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, linestringz) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, linestringz FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert result == [[42, geo]]
    end

    test "insert LineStringZM (#{repo})" do
      geo = %Geometry.LineStringZM{
        srid: 4326,
        coordinates: [[30, 10, 20, 40], [10, 30, 2, -10], [40, 40, 50, 100]]
      }

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, linestringzm) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, linestringzm FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert result == [[42, geo]]
    end

    test "insert polygon (#{repo})" do
      geo = %Geometry.Polygon{
        rings: [
          [[35, 10], [45, 45], [15, 40], [10, 20], [35, 10]],
          [[20, 30], [35, 35], [30, 20], [20, 30]]
        ],
        srid: 4326
      }

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, polygon) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, polygon FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end

    test "insert multipoint (#{repo})" do
      geo = %Geometry.MultiPoint{coordinates: [[0, 0], [20, 20], [60, 60]], srid: 4326}

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, multipoint) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, multipoint FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end

    test "insert multilinestring (#{repo})" do
      geo = %Geometry.MultiLineString{
        line_strings: [[[10, 10], [20, 20], [10, 40]], [[40, 40], [30, 30], [40, 20], [30, 10]]],
        srid: 4326
      }

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, multilinestring) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, multilinestring FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end

    test "insert multipolygon (#{repo})" do
      geo = %Geometry.MultiPolygon{
        polygons: [
          [[[40, 40], [20, 45], [45, 30], [40, 40]]],
          [
            [[20, 35], [10, 30], [10, 10], [30, 5], [45, 20], [20, 35]],
            [[30, 20], [20, 15], [20, 25], [30, 20]]
          ]
        ],
        srid: 4326
      }

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "INSERT INTO specified_columns (id, multipolygon) VALUES ($1, $2)",
          [42, geo]
        )

      result =
        Ecto.Adapters.SQL.query(
          unquote(repo).get_dynamic_repo(),
          "SELECT id, multipolygon FROM specified_columns",
          []
        )
        |> decode(unquote(repo), [1])

      assert(result == [[42, geo]])
    end
  end
end
