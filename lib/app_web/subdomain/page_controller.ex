defmodule AppWeb.Subdomain.PageController do
  use AppWeb, :controller

  alias App.Products

  def index(conn, _params) do
    tenant = conn.assigns[:tenant]

    query = %{
      order_by: [:inserted_at],
      order_directions: [:desc],
      page_size: 50,
      filters: [
        %{field: :is_live, op: :==, value: true}
      ]
    }

    {products, _meta} = Products.list_products_by_user!(tenant, query)
    render(conn, :index, tenant: tenant, products: products)
  end

  def show(conn, %{"slug" => slug}) do
    tenant = conn.assigns[:tenant]
    product = Products.get_live_product_by_user_and_slug!(tenant, slug)
    render(conn, :show, tenant: tenant, product: product)
  end
end
