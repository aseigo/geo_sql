defmodule GeoSQL.MM2Functions.Test do
  use ExUnit.Case, async: true
  import Ecto.Query
  use GeoSQL.MM2
  use GeoSQL.Test.Helper

  alias GeoSQL.Test.Schema.Location

  def geom(which \\ :default)

  def geom(which), do: Geometry.from_ewkb!(Fixtures.multipoint_ewkb(which))

  setup do
    for repo <- Helper.repos() do
      repo.insert(%Location{name: "Smallville", geom: geom()})
    end

    :ok
  end

  describe "SQL/MM2 Queries" do
    test "simple equality with as_text and without" do
      full_decoding = [GeoSQL.Test.SQLite.Repo]
      partial_decoding = [GeoSQL.Test.PostGIS.Repo]

      for repo <- Helper.repos(), Enum.member?(full_decoding, repo) do
        results =
          from(location in Location,
            limit: 1,
            select: %{
              different: MM2.as_text(location.geom) == MM2.as_text(^geom(:comparison)),
              same: MM2.as_text(location.geom) == MM2.as_text(^geom()),
              raw_different: location.geom == ^geom(:comparison),
              raw_same: location.geom == ^geom()
            }
          )
          |> repo.one()

        assert match?(
                 %{same: true, raw_same: true, different: false, raw_different: false},
                 results
               ),
               "#{repo} failed"
      end

      for repo <- Helper.repos(), Enum.member?(partial_decoding, repo) do
        results =
          from(location in Location,
            limit: 1,
            select: %{
              raw_different: location.geom == ^geom(:comparison),
              raw_same: location.geom == ^geom()
            }
          )
          |> repo.one()

        assert match?(%{raw_same: true, raw_different: false}, results), "#{repo} failed"
      end
    end

    test "area" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.area(location.geom))
        results = repo.all(query)

        assert is_number(hd(results)), "#{repo} failed"
      end
    end

    test "as_binary" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.as_binary(location.geom))

        results = repo.all(query)

        expected = [
          <<1, 6, 0, 0, 0, 1, 0, 0, 0, 1, 3, 0, 0, 0, 1, 0, 0, 0, 15, 0, 0, 0, 145, 161, 239, 117,
            5, 213, 33, 192, 244, 173, 97, 130, 228, 129, 66, 64, 114, 179, 206, 146, 254, 212,
            33, 192, 29, 72, 60, 218, 226, 129, 66, 64, 133, 24, 79, 174, 247, 212, 33, 192, 203,
            21, 145, 17, 225, 129, 66, 64, 225, 235, 215, 251, 248, 212, 33, 192, 212, 33, 247,
            200, 223, 129, 66, 64, 173, 17, 19, 21, 255, 212, 33, 192, 254, 31, 33, 192, 222, 129,
            66, 64, 130, 160, 102, 153, 8, 213, 33, 192, 80, 7, 17, 24, 222, 129, 66, 64, 129, 60,
            94, 112, 15, 213, 33, 192, 149, 78, 239, 151, 222, 129, 66, 64, 220, 136, 159, 168,
            21, 213, 33, 192, 179, 56, 33, 130, 224, 129, 66, 64, 1, 72, 168, 24, 23, 213, 33,
            192, 230, 32, 210, 43, 226, 129, 66, 64, 241, 233, 91, 222, 25, 213, 33, 192, 139,
            213, 56, 82, 227, 129, 66, 64, 248, 22, 153, 226, 23, 213, 33, 192, 91, 53, 215, 220,
            228, 129, 66, 64, 178, 135, 200, 215, 21, 213, 33, 192, 51, 99, 56, 254, 228, 129, 66,
            64, 133, 136, 47, 185, 15, 213, 33, 192, 254, 246, 84, 132, 229, 129, 66, 64, 165, 62,
            30, 70, 10, 213, 33, 192, 154, 14, 162, 134, 229, 129, 66, 64, 145, 161, 239, 117, 5,
            213, 33, 192, 244, 173, 97, 130, 228, 129, 66, 64>>
        ]

        assert results === expected, "#{repo} failed"
      end
    end

    test "as_text" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.as_text(location.geom))

        results = repo.all(query)

        # PostGIS manages to capture the full precision, SQLite is slightly less .. precise.
        expected = [
          [
            "MULTIPOLYGON(((-8.91605728674111 37.014786050505705,-8.916004741413165 37.01473548835222,-8.915952155261275 37.014681049196575,-8.915962095363229 37.014641876859656,-8.916008623674168 37.01461030595236,-8.916081231858929 37.01459027129624,-8.91613341474863 37.01460551438246,-8.91618086764759 37.0146639501776,-8.916191835920474 37.01471469650441,-8.91621298667903 37.01474979186158,-8.916197854221068 37.01479683407043,-8.916182273129241 37.01480081322952,-8.916135584881212 37.01481680058167,-8.916094008628827 37.01481707489911,-8.91605728674111 37.014786050505705)))"
          ],
          [
            "MULTIPOLYGON(((-8.916057 37.014786, -8.916005 37.014735, -8.915952 37.014681, -8.915962 37.014642, -8.916009 37.01461, -8.916081 37.01459, -8.916133 37.014606, -8.916181 37.014664, -8.916192 37.014715, -8.916213 37.01475, -8.916198 37.014797, -8.916182 37.014801, -8.916136 37.014817, -8.916094 37.014817, -8.916057 37.014786)))"
          ]
        ]

        assert Enum.member?(expected, results), "#{repo} failed"
      end
    end

    test "boundary" do
      for repo <- Helper.repos() do
        query = from(location in Location, limit: 1, select: MM2.boundary(location.geom))

        [result] =
          repo.all(query)
          |> GeoSQL.decode_geometry(repo)

        assert Helper.is_a(result, [Geometry.LineString, Geometry.MultiLineString]),
               "#{repo} failed"

        case result do
          %Geometry.LineString{coordinates: coordinates} ->
            assert is_list(coordinates), "#{repo} failed"

          %Geometry.MultiLineString{line_strings: line_strings} ->
            assert is_list(line_strings), "#{repo} failed"

          %x{} ->
            flunk("Got #{x}, #{repo} failed")
        end
      end
    end

    test "buffer" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.buffer(location.geom, 0))

        [result | _] =
          repo.all(query)
          |> GeoSQL.decode_geometry(repo)

        assert(
          match?(
            %Geometry.Polygon{rings: _coordinates, srid: 4326},
            result
          ),
          "#{repo} failed first match"
        )

        assert is_list(result.rings),
               "#{repo} failed to return a coordinations list (first)"

        query = from(location in Location, select: MM2.buffer(location.geom, 0, 8))

        [result | _] =
          repo.all(query)
          |> GeoSQL.decode_geometry(repo)

        assert(
          match?(
            %Geometry.Polygon{srid: 4326, rings: _coordinates},
            result
          ),
          "#{repo} failed second match"
        )

        assert is_list(result.rings),
               "#{repo} failed to return a coordinations list (first)"
      end
    end

    test "centroid" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.centroid(location.geom))
        results = repo.one(query) |> GeoSQL.decode_geometry(repo)
        assert match?(%Geometry.Point{}, results), "#{repo} failed"
      end
    end

    test "contains" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.centroid(location.geom))
        results = repo.one(query) |> GeoSQL.decode_geometry(repo)
        assert match?(%Geometry.Point{}, results), "#{repo} failed"
      end
    end

    test "convex_hull" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.convex_hull(location.geom))
        results = repo.one(query) |> GeoSQL.decode_geometry(repo)
        assert match?(%Geometry.Polygon{}, results), "#{repo} failed"
      end
    end

    test "crosses" do
      for repo <- Helper.repos() do
        point = %Geometry.Point{coordinates: [8, 10], srid: 4326}
        query = from(location in Location, select: MM2.crosses(location.geom, ^point))
        results = repo.one(query)
        assert results == false or results == 0, "#{repo} failed"
      end
    end

    test "difference" do
      for repo <- Helper.repos() do
        query =
          from(location in Location, select: MM2.difference(location.geom, ^geom(:comparison)))

        results =
          repo.one(query)
          |> GeoSQL.decode_geometry(repo)

        assert match?(%Geometry.Polygon{}, results), "#{repo} failed"
      end
    end

    test "dimension" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.dimension(location.geom))
        results = repo.one(query)
        assert 2 = results, "#{repo} failed"
      end
    end

    test "disjoint" do
      for repo <- Helper.repos() do
        query =
          from(location in Location, select: MM2.disjoint(location.geom, ^geom(:comparison)))

        results = repo.one(query)
        assert results == false or results == 0, "#{repo} failed"
      end
    end

    test "distance" do
      for repo <- Helper.repos() do
        query = from(location in Location, select: MM2.distance(location.geom, ^geom()))
        results = repo.one(query)
        assert results == 0, "#{repo} failed"
      end
    end

    test "transform" do
      for repo <- Helper.repos() do
        query = from(location in Location, limit: 1, select: MM2.transform(location.geom, 3452))
        results = repo.one(query) |> GeoSQL.decode_geometry(repo)

        assert results.srid == 3452, "#{repo} failed"
      end
    end

    test "example" do
      defmodule Example do
        import Ecto.Query
        require GeoSQL.MM2
        alias GeoSQL.MM2

        def example_query(geom) do
          from(location in Location, select: MM2.distance(location.geom, ^geom))
        end
      end

      for repo <- Helper.repos() do
        query =
          Fixtures.multipoint_ewkb()
          |> Geometry.from_ewkb!()
          |> Example.example_query()

        results = repo.one(query)
        assert results == 0, "#{repo} failed"
      end
    end
  end
end
