defmodule AppWeb.Plugs.Subdomain do
  import Plug.Conn

  def init(_opts) do
    %{
      router: AppWeb.SubdomainRouter,
      root_host: Application.get_env(:app, AppWeb.Endpoint)[:url][:host]
    }
  end

  def call(%{host: host} = conn, %{root_host: root_host, router: router} = _opts) do
    case extract_subdomain(host, root_host) do
      subdomain when byte_size(subdomain) > 0 ->
        assign(conn, :subdomain, subdomain)
        |> router.call(router.init({}))
        |> halt()

      _ ->
        conn
    end
  end

  defp extract_subdomain(host, root_host) do
    String.replace(host, ~r/.?#{root_host}/, "")
  end
end
