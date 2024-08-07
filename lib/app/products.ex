defmodule App.Products do
  import Ecto.Query
  alias App.Repo
  alias App.Products.{Product, Variant}

  # --------------- PRODUCT ---------------
  defdelegate cta_options, to: Product
  defdelegate cta_text(cta), to: Product
  defdelegate cta_custom?(cta), to: Product
  defdelegate has_details?(product), to: Product

  def list_products_by_user!(user, query) do
    from(p in Product, join: u in assoc(p, :user), preload: [user: u])
    |> list_products_by_user_scope(user)
    |> Flop.validate_and_run!(query)
  end

  defp list_products_by_user_scope(q, %{role: :admin}), do: q

  defp list_products_by_user_scope(q, user) do
    where(q, [p], p.user_id == ^user.id)
  end

  def get_product(id) do
    Product
    |> Repo.get(id)
  end

  def get_product!(id) do
    Product
    |> Repo.get!(id)
  end

  def get_product_by_slug!(slug) do
    Repo.get_by!(Product, slug: slug)
  end

  def get_product_by_user_and_slug!(user, slug) do
    Repo.get_by!(Product, user_id: user.id, slug: slug)
  end

  def get_live_product_by_user_and_slug!(user, slug) do
    Repo.get_by!(Product, user_id: user.id, slug: slug, is_live: true)
  end

  def change_product(product, attrs) do
    Product.changeset(product, attrs)
  end

  def create_product(attrs) do
    %Product{}
    |> Product.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_product(product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def delete_product(product) do
    Repo.delete(product)
  end

  def public_path(product) do
    product = App.Repo.preload(product, :user)
    "/#{product.user.username}/#{product.slug}"
  end

  def cover_url(product, version, opts \\ []) do
    App.Products.ProductCover.url({product.cover, product}, version, opts)
  end

  def add_detail(product, %{changes: changes}) do
    # try to get details from changes, if not, get from product
    details =
      case Map.get(changes, :details) do
        nil -> product.details
        details -> details
      end

    id = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()

    details =
      Map.put(details, "items", details["items"] ++ [%{"id" => id, "key" => "", "value" => ""}])

    change_product(product, Map.put(changes, :details, details))
  end

  def delete_detail(product, %{changes: changes}, detail) do
    # try to get details from changes, if not, get from product
    details =
      case Map.get(changes, :details) do
        nil -> product.details
        details -> details
      end

    items =
      Enum.filter(details["items"], fn item ->
        item["id"] != detail["id"]
      end)

    details = Map.put(details, "items", items)
    change_product(product, Map.put(changes, :details, details))
  end

  def update_detail(product, %{changes: changes}, id, which, value) do
    # try to get details from changes, if not, get from product
    details =
      case Map.get(changes, :details) do
        nil -> product.details
        details -> details
      end

    items =
      Enum.map(details["items"], fn item ->
        if item["id"] == id do
          Map.put(item, which, value)
        else
          item
        end
      end)

    details = Map.put(details, "items", items)
    change_product(product, Map.put(changes, :details, details))
  end

  # --------------- VARIANT ---------------

  def variants_count(product) do
    from(
      v in Variant,
      where: v.product_id == ^product.id,
      select: count(v.id)
    )
    |> Repo.one()
  end

  def has_variants?(product) do
    variants_count(product) > 0
  end

  def list_variants_by_product(product) do
    from(
      v in Variant,
      where: v.product_id == ^product.id,
      order_by: [asc: v.price]
    )
    |> Repo.all()
  end

  def list_variants_price_by_product(product) do
    from(
      v in Variant,
      where: v.product_id == ^product.id,
      order_by: [asc: v.price],
      select: v.price
    )
    |> Repo.all()
  end

  def get_variant!(id) do
    Repo.get!(Variant, id)
  end

  def change_variant(variant, attrs) do
    Variant.changeset(variant, attrs)
  end

  def create_variant(attrs) do
    %Variant{}
    |> Variant.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_variant(variant, attrs) do
    variant
    |> Variant.changeset(attrs)
    |> Repo.update()
  end

  def delete_variant(variant) do
    Repo.delete(variant)
  end

  def price_display(product) do
    with true <- has_variants?(product),
         [_ | _] = prices <- list_variants_price_by_product(product) do
      min_price = Enum.min(prices) |> App.Utils.Commons.format_price()
      max_price = Enum.max(prices) |> App.Utils.Commons.delimited_number()
      min_price <> " - " <> max_price
    else
      _ -> App.Utils.Commons.format_price(product.price)
    end
  end
end
