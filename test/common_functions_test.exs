defmodule GeoSQL.CommonFunctions.Test do
  use ExUnit.Case, async: true
  import Ecto.Query
  use GeoSQL.MM2
  use GeoSQL.MM3
  use GeoSQL.PostGIS
  use GeoSQL.Common
  use GeoSQL.Test.Helper
  alias GeoSQL.Test.Helper

  alias GeoSQL.Test.Schema.{Location, LocationMulti, GeoType}

  for repo <- Helper.repos() do
    describe "add_point (#{repo})" do
      test "adds a point to a line" do
        line = Fixtures.linestring()
        point = Fixtures.point()

        unquote(repo).insert(%GeoType{t: "hello", linestring: line, point: point})

        query =
          from(location in GeoType, select: Common.add_point(location.linestring, location.point))

        assert [%Geometry.LineString{coordinates: coordinates}] =
                 unquote(repo).all(query)
                 |> GeoSQL.decode_geometry(unquote(repo))

        assert length(coordinates) == Enum.count(line.coordinates) + 1
      end

      test "-1 adds a point to the end of a line" do
        line = Fixtures.linestring()
        point = Fixtures.point()

        unquote(repo).insert(%GeoType{t: "hello", linestring: line, point: point})

        query =
          from(location in GeoType, select: Common.add_point(location.linestring, location.point))

        assert [%Geometry.LineString{coordinates: coordinates}] =
                 unquote(repo).all(query)
                 |> GeoSQL.decode_geometry(unquote(repo))

        assert length(coordinates) == Enum.count(line.coordinates) + 1
        assert Enum.at(coordinates, 2) == point.coordinates
      end

      test "0 prepends a point to the line" do
        line = Fixtures.linestring()
        point = Fixtures.point()

        unquote(repo).insert(%GeoType{t: "hello", linestring: line, point: point})

        query =
          from(location in GeoType, select: Common.add_point(location.linestring, location.point))

        assert [%Geometry.LineString{coordinates: coordinates}] =
                 unquote(repo).all(query)
                 |> GeoSQL.decode_geometry(unquote(repo))

        assert length(coordinates) == Enum.count(line.coordinates) + 1
        assert Enum.at(coordinates, 0) == point.coordinates
      end
    end

    describe "extent (#{repo})" do
      test "extent" do
        geom = Geometry.from_ewkb!(Fixtures.multipoint_ewkb())

        unquote(repo).insert(%Location{name: "hello", geom: geom})

        query = from(location in Location, select: Common.extent(location.geom, unquote(repo)))

        assert [%Geometry.Polygon{rings: [coordinates]}] =
                 unquote(repo).all(query)
                 |> GeoSQL.decode_geometry(unquote(repo))

        assert length(coordinates) == 5
      end
    end

    describe "node (#{repo})" do
      supports_self_intersection = [GeoSQL.Test.PostGIS.Repo]

      test "nodes from a linestring" do
        coordinates = [[0, 0, 0], [1, 1, 1], [2, 2, 2]]

        # Create a self-intersecting linestring (crossing at point [1, 1, 1])
        linestring = %Geometry.LineStringZ{
          coordinates: coordinates,
          srid: 4326
        }

        unquote(repo).insert(%LocationMulti{name: "intersecting lines", geom: linestring})

        query =
          from(
            location in LocationMulti,
            select: Common.node(location.geom)
          )

        result =
          unquote(repo).one(query)
          |> GeoSQL.decode_geometry(unquote(repo))

        assert %Geometry.LineStringZ{} = result

        assert result.coordinates == coordinates
      end

      if Enum.member?(supports_self_intersection, repo) do
        test "self-intersecting linestring" do
          coordinates = [[0, 0, 0], [2, 2, 2], [0, 2, 0], [2, 0, 2]]
          cross_point = [1, 1, 1]

          # Create a self-intersecting linestring (crossing at point [1, 1, 1])
          linestring = %Geometry.LineStringZ{
            coordinates: coordinates,
            srid: 4326
          }

          unquote(repo).insert(%LocationMulti{name: "intersecting lines", geom: linestring})

          query =
            from(
              location in LocationMulti,
              select: Common.node(location.geom)
            )

          result = unquote(repo).one(query) |> GeoSQL.decode_geometry(unquote(repo))

          assert %Geometry.MultiLineStringZ{} = result

          assert result.line_strings == [
                   [Enum.at(coordinates, 0), cross_point],
                   [cross_point, Enum.at(coordinates, 1), Enum.at(coordinates, 2), cross_point],
                   [cross_point, Enum.at(coordinates, 3)]
                 ]
        end

        test "intersecting multilinestring" do
          coordinates1 = [[0, 0, 0], [2, 2, 2]]
          coordinates2 = [[0, 2, 0], [2, 0, 2]]
          cross_point = [1, 1, 1]

          # Create a multilinestring that intersects (crossing at point [1, 1, 1])
          linestring = %Geometry.MultiLineStringZ{
            line_strings: [
              coordinates1,
              coordinates2
            ],
            srid: 4326
          }

          unquote(repo).insert(%LocationMulti{name: "intersecting lines", geom: linestring})

          query =
            from(
              location in LocationMulti,
              select: Common.node(location.geom)
            )

          result = unquote(repo).one(query)

          assert %Geometry.MultiLineStringZ{} = result

          assert result.line_strings == [
                   [Enum.at(coordinates1, 0), cross_point],
                   [Enum.at(coordinates2, 0), cross_point],
                   [cross_point, Enum.at(coordinates1, 1)],
                   [cross_point, Enum.at(coordinates2, 1)]
                 ]
        end
      end
    end

    describe "line_merge/2 (#{repo})" do
      supports_directed_merges = [GeoSQL.Test.PostGIS.Repo]

      if Enum.member?(supports_directed_merges, repo) do
        test "lines with opposite directions not merged if directed is true" do
          multiline = %Geometry.MultiLineString{
            line_strings: [
              [[60, 30], [10, 70]],
              [[120, 50], [60, 30]],
              [[120, 50], [180, 30]]
            ],
            srid: 4326
          }

          unquote(repo).insert(%LocationMulti{name: "lines with direction", geom: multiline})

          query =
            from(
              location in LocationMulti,
              where: location.name == "lines with direction",
              select: Common.line_merge(location.geom, true, unquote(repo))
            )

          result = unquote(repo).one(query) |> GeoSQL.decode_geometry(unquote(repo))

          # Verify the result is still a MultiLineString with only 2 lines merged

          assert %Geometry.MultiLineString{} = result

          assert length(result.line_strings) == 2

          expected_linestrings = [
            [[120, 50], [60, 30], [10, 70]],
            [[120, 50], [180, 30]]
          ]

          sorted_result = Enum.sort_by(result.line_strings, fn linestring -> hd(linestring) end)

          sorted_expected =
            Enum.sort_by(expected_linestrings, fn linestring -> hd(linestring) end)

          assert sorted_result == sorted_expected
        end
      end

      test "lines with opposite directions merged if directed is false" do
        multiline = %Geometry.MultiLineString{
          line_strings: [
            [[60, 30], [10, 70]],
            [[120, 50], [60, 30]],
            [[120, 50], [180, 30]]
          ],
          srid: 4326
        }

        unquote(repo).insert(%LocationMulti{name: "lines with direction", geom: multiline})

        query =
          from(
            location in LocationMulti,
            where: location.name == "lines with direction",
            select: Common.line_merge(location.geom, false)
          )

        result =
          unquote(repo).one(query)
          |> GeoSQL.decode_geometry(unquote(repo))

        assert %Geometry.LineString{} = result

        assert result.coordinates == [
                 [180, 30],
                 [120, 50],
                 [60, 30],
                 [10, 70]
               ]
      end
    end
  end
end
