defmodule GeoSQL.PostGISFunctions.Test do
  use ExUnit.Case, async: true
  @moduletag :pgsql

  import Ecto.Query
  use GeoSQL.PostGIS
  use GeoSQL.Common
  use GeoSQL.Test.Helper

  alias GeoSQL.Test.Schema.{Location, LocationMulti}

  test "query sphere distance" do
    geom = Geometry.from_ewkb!(Fixtures.multipoint_ewkb())

    PostGISRepo.insert(%Location{name: "hello", geom: geom})

    query =
      from(location in Location, limit: 5, select: PostGIS.distance_sphere(location.geom, ^geom))

    results = PostGISRepo.one(query)

    assert results == 0
  end

  describe "is_collection/1" do
    test "returns true for a geometry collection" do
      collection = %Geometry.GeometryCollection{
        geometries: [
          %Geometry.Point{coordinates: [0, 0], srid: 4326},
          %Geometry.LineString{coordinates: [[0, 0], [1, 1]], srid: 4326}
        ],
        srid: 4326
      }

      PostGISRepo.insert(%LocationMulti{name: "collection", geom: collection})

      query =
        from(l in LocationMulti,
          where: l.name == "collection",
          select: PostGIS.is_collection(Common.make_valid(l.geom))
        )

      result = PostGISRepo.one(query)
      assert result == true
    end

    test "returns true for a multi-geometry" do
      multi_point = %Geometry.MultiPoint{
        coordinates: [[0, 0], [1, 1], [2, 2]],
        srid: 4326
      }

      PostGISRepo.insert(%LocationMulti{name: "multi_point", geom: multi_point})

      query =
        from(l in LocationMulti,
          where: l.name == "multi_point",
          select: PostGIS.is_collection(Common.make_valid(l.geom))
        )

      result = PostGISRepo.one(query)
      assert result == true
    end

    test "returns false for a simple geometry" do
      point = %Geometry.Point{coordinates: [0, 0], srid: 4326}
      PostGISRepo.insert(%LocationMulti{name: "point", geom: point})

      query =
        from(l in LocationMulti,
          where: l.name == "point",
          select: PostGIS.is_collection(l.geom)
        )

      result = PostGISRepo.one(query)
      assert result == false
    end
  end

  describe "PostGIS.points/1" do
    test "returns multipoint from a linestring" do
      line_coords = [[0.0, 0.0], [1.0, 1.0], [2.0, 2.0]]

      line = %Geometry.LineString{
        coordinates: line_coords,
        srid: 4326
      }

      PostGISRepo.insert(%LocationMulti{name: "line_for_points", geom: line})

      query =
        from(l in LocationMulti,
          where: l.name == "line_for_points",
          select: PostGIS.points(l.geom)
        )

      result = PostGISRepo.one(query)

      assert %Geometry.MultiPoint{} = result

      assert length(result.coordinates) == 3

      assert MapSet.new(line_coords) == MapSet.new(result.coordinates)
    end

    test "returns multipoint from a polygon" do
      polygon_coords = [[0.0, 0.0], [0.0, 2.0], [2.0, 2.0], [2.0, 0.0], [0.0, 0.0]]

      polygon = %Geometry.Polygon{
        rings: [polygon_coords],
        srid: 4326
      }

      PostGISRepo.insert(%LocationMulti{name: "polygon_for_points", geom: polygon})

      query =
        from(l in LocationMulti,
          where: l.name == "polygon_for_points",
          select: PostGIS.points(l.geom)
        )

      result = PostGISRepo.one(query)
      assert %Geometry.MultiPoint{} = result

      # 5 coordinates expected including the equivalent overlapping start/end points
      assert length(result.coordinates) == 5
      [overlapping_vertex | _rest] = polygon_coords

      assert Enum.count(result.coordinates, fn coord -> coord == overlapping_vertex end) == 2
      assert MapSet.new(polygon_coords) == MapSet.new(result.coordinates)
    end
  end

  describe "PostGIS.dump" do
    test "atomic geometry is returned directly" do
      point = %Geometry.Point{
        coordinates: [0.0, 0.0],
        srid: 4326
      }

      PostGISRepo.insert(%LocationMulti{name: "point", geom: point})

      query =
        from(location in LocationMulti,
          where: location.name == "point",
          select: PostGIS.dump(location.geom)
        )

      result = PostGISRepo.one(query)

      assert result == {[], point}
    end

    test "breaks a multipolygon into its constituent polygons" do
      polygon1 = %Geometry.Polygon{
        rings: [[[0.0, 0.0], [0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]]],
        srid: 4326
      }

      polygon2 = %Geometry.Polygon{
        rings: [[[2.0, 2.0], [2.0, 3.0], [3.0, 3.0], [3.0, 2.0], [2.0, 2.0]]],
        srid: 4326
      }

      PostGISRepo.insert(%LocationMulti{name: "polygon1", geom: polygon1})
      PostGISRepo.insert(%LocationMulti{name: "polygon2", geom: polygon2})

      query =
        from(
          location in LocationMulti,
          where: location.name in ["polygon1", "polygon2"],
          select: PostGIS.dump(Common.collect(location.geom))
        )

      results = PostGISRepo.all(query)
      assert length(results) == 2

      Enum.each(results, fn {_path, geom} ->
        assert %Geometry.Polygon{} = geom
      end)

      expected_polygons = MapSet.new([polygon1, polygon2])
      actual_polygons = MapSet.new(Enum.map(results, fn {_path, geom} -> geom end))

      assert MapSet.equal?(expected_polygons, actual_polygons)
    end
  end
end
