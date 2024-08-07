defmodule AppWeb.Plugs.RequireAPIKey do
  import Plug.Conn

  alias App.Users

  def init(opts), do: opts

  def call(conn, opts) do
    token = conn |> get_req_header("authorization") |> Enum.at(0, "")

    with true <- String.contains?(token, "Bearer "),
         key <- String.replace(token, "Bearer ", ""),
         %Users.User{} = user <- Users.get_by_api_key(key) do
      if opts[:role] == :admin and user.role != :admin do
        raise AppWeb.Api.UnauthorizedRequestError
      end

      assign(conn, :current_user, user)
    else
      _ -> raise AppWeb.Api.UnauthorizedRequestError
    end
  end
end
