defmodule AppWeb.PublicLive.Checkout do
  use AppWeb, :live_view

  alias App.Products

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case socket.assigns.current_user do
      nil ->
        return_product(socket, Products.get_live_product_by_slug!(slug))

      user ->
        product = Products.get_product_by_slug!(slug)

        if product.is_live || product.user_id == user.id,
          do: return_product(socket, product),
          else: raise(Ecto.NoResultsError, queryable: Products.Product)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      :if={@product}
      module={AppWeb.ProductLive.Components.Preview}
      id={@product.id}
      product={@product}
    />
    """
  end

  # handle messages from Preview component

  @impl true
  def handle_info({AppWeb.ProductLive.Components.Preview, order}, socket) do
    socket =
      socket
      |> put_flash(:info, "Order telah dibuat! silahkan lanjutkan dengan pembayaran.")
      |> push_navigate(to: ~p"/invoice/#{order.id}")

    {:noreply, socket}
  end

  defp return_product(socket, product) do
    socket =
      socket
      |> assign(:page_title, product.name)
      |> assign(:product, App.Repo.preload(product, :variants))

    {:ok, socket}
  end
end