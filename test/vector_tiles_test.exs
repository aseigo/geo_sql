defmodule GeoSQL.TilesTest do
  use ExUnit.Case, async: true
  @moduletag :pgsql

  use GeoSQL.Test.Helper, setup_funs: [{__MODULE__, :seed_db}], backends: ["pgsql"]
  #   use GeoSQL.Test.Helper
  use GeoSQL.PostGIS

  import Ecto.Query

  defmodule VectorTilePOI do
    use Ecto.Schema
    import Ecto.Changeset

    schema "vector_tile_pois" do
      field(:tags, :map)
      field(:geom, GeoSQL.Geometry)
    end

    def changeset(%__MODULE__{} = node, attrs) do
      node
      |> cast(attrs, [:tags, :geom])
    end
  end

  supports_vector_tiles = [GeoSQL.Test.PostGIS.Repo]

  def seed_db(context) do
    repo_info =
      Helper.repo_info(GeoSQL.Test.PostGIS.Repo, context)

    # seed the DB if there's a PostGIS repo under test
    if repo_info != nil do
      insert_pois("public")
      insert_pois("map")
    end

    :ok
  end

  def insert_pois(prefix) do
    [
      %{
        tags: %{amenity: "bench", backrest: "yes"},
        geom: %Geometry.Point{coordinates: [9.4393, 47.5130171], srid: 4326}
      },
      %{
        tags: %{amenity: prefix, access: "private"},
        geom: %Geometry.Point{coordinates: [8.5392315, 47.3774401], srid: 4326}
      },
      %{
        tags: %{amenity: "swimming_pool", access: "private"},
        geom: %Geometry.Point{coordinates: [8.5392315, 47.3774401], srid: 4326}
      }
    ]
    |> Enum.with_index()
    |> Enum.reduce(
      Ecto.Multi.new(),
      fn {attrs, index}, multi ->
        Ecto.Multi.insert(multi, index, VectorTilePOI.changeset(%VectorTilePOI{}, attrs),
          prefix: prefix
        )
      end
    )
    |> PostGISRepo.transaction(prefix: prefix, returning: true)

    from(v in VectorTilePOI)
    |> PostGISRepo.all(prefix: prefix)
  end

  for repo <- Helper.repos(), Enum.member?(supports_vector_tiles, repo) do
    test "Retrieves a vector tile" do
      layers = [
        %PostGIS.VectorTiles.Layer{
          name: "pois",
          source: "vector_tile_pois",
          columns: %{geometry: :geom, id: :id, tags: :tags}
        }
      ]

      expected_tile =
        "\x1A\x86\x01\n\x04pois\x12\x13\x12\b\0\0\x01\x01\x02\x02\x03\x03\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x12\x13\x12\b\0\0\x01\x04\x02\x02\x03\x05\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x1A\x04name\x1A\x02id\x1A\x06access\x1A\aamenity\"\x06\n\x04pois\"\x02(\x02\"\t\n\aprivate\"\b\n\x06public\"\x02(\x03\"\x0F\n\rswimming_pool(\x80 x\x02"

      z = 17
      x = 68645
      y = 45899
      tile = PostGIS.VectorTiles.generate(PostGISRepo, z, x, y, layers)
      assert(tile == expected_tile)
    end

    test "Retrieves a vector tile with a prefix" do
      layers = [
        %PostGIS.VectorTiles.Layer{
          name: "user_pois",
          source: "vector_tile_pois",
          prefix: "map",
          columns: %{geometry: :geom, id: :id, tags: :tags}
        }
      ]

      expected_tile =
        "\x1A\x8D\x01\n\tuser_pois\x12\x13\x12\b\0\0\x01\x01\x02\x02\x03\x03\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x12\x13\x12\b\0\0\x01\x04\x02\x02\x03\x05\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x1A\x04name\x1A\x02id\x1A\x06access\x1A\aamenity\"\v\n\tuser_pois\"\x02(\x02\"\t\n\aprivate\"\x05\n\x03map\"\x02(\x03\"\x0F\n\rswimming_pool(\x80 x\x02"

      z = 17
      x = 68645
      y = 45899
      tile = PostGIS.VectorTiles.generate(PostGISRepo, z, x, y, layers)
      assert(tile == expected_tile)
    end

    test "Retrieves a vector tile with two layers" do
      layers = [
        %PostGIS.VectorTiles.Layer{
          name: "pois",
          source: "vector_tile_pois",
          columns: %{geometry: :geom, id: :id, tags: :tags}
        },
        %PostGIS.VectorTiles.Layer{
          name: "user_pois",
          source: "vector_tile_pois",
          prefix: "map",
          columns: %{geometry: :geom, id: :id, tags: :tags}
        }
      ]

      expected_tile =
        "\x1A\xC9\x01\n\tuser_pois\x12\x13\x12\b\0\0\x01\x01\x02\x02\x03\x03\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x12\x13\x12\b\0\0\x01\x04\x02\x02\x03\x05\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x12\x13\x12\b\0\x06\x01\x01\x02\x02\x03\a\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x12\x13\x12\b\0\x06\x01\x04\x02\x02\x03\x05\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x1A\x04name\x1A\x02id\x1A\x06access\x1A\aamenity\"\v\n\tuser_pois\"\x02(\x02\"\t\n\aprivate\"\x05\n\x03map\"\x02(\x03\"\x0F\n\rswimming_pool\"\x06\n\x04pois\"\b\n\x06public(\x80 x\x02"

      z = 17
      x = 68645
      y = 45899
      tile = PostGIS.VectorTiles.generate(PostGISRepo, z, x, y, layers)
      assert(tile == expected_tile)
    end

    test "Retrieves a vector tile with a where clause filtering out results" do
      layers = [
        %PostGIS.VectorTiles.Layer{
          name: "user_pois",
          source: "vector_tile_pois",
          prefix: "map",
          columns: %{geometry: :geom, id: :id, tags: :tags},
          compose_query_fn: fn query -> from(q in query, where: q.id == 3) end
        }
      ]

      expected_tile =
        "\x1Am\n\tuser_pois\x12\x13\x12\b\0\0\x01\x01\x02\x02\x03\x03\x18\x01\"\x05\t\xC2\x02\xD2\x0F\x1A\x04name\x1A\x02id\x1A\x06access\x1A\aamenity\"\v\n\tuser_pois\"\x02(\x03\"\t\n\aprivate\"\x0F\n\rswimming_pool(\x80 x\x02"

      z = 17
      x = 68645
      y = 45899
      tile = PostGIS.VectorTiles.generate(PostGISRepo, z, x, y, layers)
      assert(tile == expected_tile)
    end
  end
end
