defmodule AppWeb.AdminLive.Product.Components.VisitorsMetricsChart do
  use AppWeb, :live_component
  use AppWeb, :html

  alias App.Umami

  @default_metric "referrer"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <ul
        class="text-sm font-normal text-center text-gray-500 divide-x divide-gray-200 rounded-md sm:flex dark:divide-gray-600 dark:text-gray-400"
        role="tablist"
      >
        <li class="w-full">
          <button
            phx-click={
              JS.push("change_tab", value: %{tab: "referrer"}, target: @myself, page_loading: true)
            }
            type="button"
            role="tab"
            class={[
              "inline-block w-full p-3 rounded-tl-lg hover:bg-gray-100 focus:outline-none dark:bg-gray-700 dark:hover:bg-gray-600",
              if(@tab == "referrer", do: "bg-white", else: "bg-gray-50")
            ]}
          >
            Referrer
          </button>
        </li>
        <li class="w-full">
          <button
            phx-click={
              JS.push("change_tab", value: %{tab: "query"}, target: @myself, page_loading: true)
            }
            type="button"
            role="tab"
            class={[
              "inline-block w-full p-3 rounded-tl-lg hover:bg-gray-100 focus:outline-none dark:bg-gray-700 dark:hover:bg-gray-600",
              if(@tab == "query", do: "bg-white", else: "bg-gray-50")
            ]}
          >
            UTM Params
          </button>
        </li>
      </ul>

      <div class="relative overflow-x-auto">
        <table class="w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400">
          <tbody>
            <tr
              :for={metric <- @metrics}
              class="bg-white border-b dark:bg-gray-800 dark:border-gray-700"
            >
              <th
                scope="row"
                class="px-6 py-2 font-medium text-gray-900 whitespace-nowrap dark:text-white"
              >
                <%= if metric["x"], do: metric["x"], else: "(None)" %>
              </th>
              <td class="px-6 py-2">
                <%= metric["y"] %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{product: product, start_time: start_time} = assigns, socket) do
    time_range = time_range(product, start_time)
    metrics = fetch_metrics(product, time_range, @default_metric)

    socket =
      socket
      |> assign(assigns)
      |> assign(:tab, @default_metric)
      |> assign(:time_range, time_range)
      |> assign(:metrics, metrics)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    metrics = fetch_metrics(socket.assigns.product, socket.assigns.time_range, tab)

    {:noreply, assign(socket, tab: tab, metrics: metrics)}
  end

  defp fetch_metrics(product, {start_time, end_time}, type) do
    # get date from start_time to be use for the cache key
    date = Timex.format!(start_time, "%Y-%m-%d", :strftime)
    url = App.Products.public_path(product)
    cache_key = "products:#{product.id}:metrics:#{url}:#{type}:#{date}"

    Cachex.fetch(
      :cache,
      cache_key,
      fn _key ->
        Umami.Params.new(url)
        |> Map.put(:startAt, Timex.to_unix(start_time) * 1000)
        |> Map.put(:endAt, Timex.to_unix(end_time) * 1000)
        |> Map.put(:type, type)
        |> Umami.metrics()
        |> case do
          {:ok, m} -> {:commit, m, ttl: :timer.hours(1)}
          {:error, _} -> {:commit, [], ttl: :timer.hours(1)}
        end
      end
    )
    |> case do
      {:ok, metrics} -> metrics
      {_, metrics, _} -> metrics
    end
  end

  defp time_range(product, start_time) do
    # Ensure start_time is not before the product was inserted
    start_time =
      case Timex.compare(product.inserted_at, start_time) do
        -1 -> start_time
        _ -> product.inserted_at
      end

    end_time = Timex.now()
    {start_time, end_time}
  end
end
