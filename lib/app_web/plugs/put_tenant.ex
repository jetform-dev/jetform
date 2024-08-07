defmodule AppWeb.Plugs.PutTenant do
  import Plug.Conn

  alias App.Users

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant = Users.get_by_username!(conn.assigns.subdomain)
    assign(conn, :tenant, tenant)
  end
end
