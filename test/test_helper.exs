{:ok, _} = Application.ensure_all_started(:ecto_sql)

defmodule GeoSQL.Test.PostGIS.Helper do
  def ecto_setup(_context) do
    ExUnit.Callbacks.start_supervised(GeoSQL.Test.PostGIS.Repo)
    :ok
  end

  defmacro __using__(options \\ []) do
    setup_funs = Keyword.get(options, :setup_funs, [])

    quote do
      alias GeoSQL.Test.PostGIS.Repo, as: PostGISRepo
      setup_all [{GeoSQL.Test.PostGIS.Helper, :ecto_setup}] ++ unquote(setup_funs)
      setup_all {GeoSQL.Test.PostGIS.Helper, :ecto_setup}

      setup tags do
        pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PostGISRepo, shared: not tags[:async])
        on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
        :ok
      end
    end
  end
end

ExUnit.start()
