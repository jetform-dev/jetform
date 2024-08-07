defmodule AppWeb.AdminLive.Product.Components.VisitorsSalesChart do
  use AppWeb, :live_component
  use AppWeb, :html

  alias App.Orders
  alias App.Umami

  @impl true
  def render(assigns) do
    ~H"""
    <div id="VisitorsSalesChart" phx-hook="VisitorsSalesChart" data-buckets={@buckets}></div>
    """
  end

  @impl true
  def update(%{product: product, start_time: start_time} = assigns, socket) do
    # Ensure start_time is not before the product was inserted
    start_time =
      case Timex.compare(product.inserted_at, start_time) do
        -1 -> start_time
        _ -> product.inserted_at
      end

    end_time = Timex.now()

    # get the data from the database, format and convert it to a map
    sales = sales_buckets(product, start_time)
    pageviews = cached_pageviews_buckets(product)

    # create the buckets and fill it with the data
    buckets =
      Timex.Interval.new(
        from: start_time,
        until: end_time,
        steps: [days: 1]
      )
      |> Enum.to_list()
      |> Enum.map(fn date ->
        date_str = Timex.format!(date, "%Y-%m-%d", :strftime)
        %{x: date, y1: Map.get(pageviews, date_str, 0), y2: Map.get(sales, date_str, 0)}
      end)

    socket =
      socket
      |> assign(assigns)
      |> assign(:buckets, Jason.encode!(buckets))

    {:ok, socket}
  end

  defp sales_buckets(product, start_time) do
    Orders.daily_counts_by_product(product, start_time)
    |> Enum.map(fn {date, _free_count, paid_count} ->
      {Timex.format!(date, "%Y-%m-%d", :strftime), paid_count}
    end)
    |> Enum.into(%{})
  end

  defp cached_pageviews_buckets(product) do
    url = App.Products.public_path(product)
    cache_key = "products:#{product.id}:pageviews:#{url}"

    # always pull pageviews from the last 30 days so we can cache it and avoid calling the API too often.
    end_time = Timex.now()
    start_time = Timex.shift(end_time, days: -30)

    Cachex.fetch(
      :cache,
      cache_key,
      fn _key ->
        {:commit, pageviews_buckets(url, start_time, end_time), ttl: :timer.hours(1)}
      end
    )
    |> case do
      {:ok, pageviews} -> pageviews
      {_, pageviews, _} -> pageviews
    end
  end

  defp pageviews_buckets(url, start_time, end_time) do
    pageviews =
      Umami.Params.new(url)
      |> Map.put(:startAt, to_unix_ms(start_time))
      |> Map.put(:endAt, to_unix_ms(end_time))
      |> Map.put(:unit, :day)
      |> Umami.pageviews()

    case pageviews do
      {:ok, %{"pageviews" => pageviews}} ->
        pageviews
        |> Enum.map(fn %{"x" => date, "y" => count} ->
          {date, count}
        end)
        |> Enum.into(%{})

      _ ->
        %{}
    end
  end

  defp to_unix_ms(ts) do
    Timex.to_unix(ts) * 1000
  end
end
