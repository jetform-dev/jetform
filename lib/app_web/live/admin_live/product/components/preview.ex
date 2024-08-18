defmodule AppWeb.AdminLive.Product.Components.Preview do
  use AppWeb, :live_component
  use AppWeb, :html

  require Integer
  alias App.{Products, Orders}
  alias App.Orders.Order
  alias App.Captcha

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- preview --%>
    <div class="p-1 md:p-6">
      <.product_detail product={@product} />
      <.checkout_form
        product={@product}
        changeset={@checkout_changeset}
        total_price={@total_price}
        product_variants={@product_variants}
        has_variants={@has_variants}
        selected_variant={@selected_variant}
        submit_event={if @preview, do: "fake_order", else: "create_order"}
        submit_target={@myself}
        enable_captcha={@enable_captcha}
        error={@error}
      />

      <p class="text-center p-3 text-sm text-gray-400">
        <.link href={AppWeb.Utils.marketing_site()} target="_blank">
          Powered by JetForm
        </.link>
      </p>
    </div>
    <%!-- end preview --%>
    """
  end

  attr :product, :map, required: true
  def product_detail(assigns) do
    ~H"""
      <div class="mx-auto max-w-xl rounded-md bg-white shadow-md mb-6">
        <img src={Products.cover_url(@product, :standard)} class="rounded-t-md" />
        <hr />
        <div class="p-6 pb-10">
          <h2 class="text-2xl font-semibold" id="preview" phx-update="replace">
            <%= @product.name %>
          </h2>
          <div class="mt-4 trix-content preview text-gray-600">
            <%= raw(@product.description) %>
          </div>

          <div :if={Products.has_details?(@product)} class="relative overflow-x-auto rounded-md mt-6">
            <table class="w-full text-sm text-left rtl:text-right text-gray-700 dark:text-gray-700">
              <tbody>
                <tr
                  :for={{item, index} <- Enum.with_index(@product.details["items"])}
                  class={if Integer.is_even(index), do: "bg-primary-100", else: "bg-primary-50"}
                >
                  <td
                    scope="row"
                    class="p-2 font-medium text-gray-700 whitespace-nowrap dark:text-gray-700"
                  >
                    <%= item["key"] %>
                  </td>
                  <td
                    scope="row"
                    class="p-2 font-medium text-gray-700 whitespace-nowrap dark:text-gray-700"
                  >
                    <.icon name="hero-chevron-right me-2 w-3 h-3" /> <%= item["value"] %>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    """
  end

  attr :product, :map, required: true
  attr :changeset, :map, required: true
  attr :total_price, :integer, required: true
  attr :submit_event, :string, required: true
  attr :submit_target, :any, required: true
  attr :product_variants, :list, default: []
  attr :has_variants, :boolean, default: false
  attr :selected_variant, :map, default: nil
  attr :enable_captcha, :boolean, default: true
  attr :error, :string, default: nil

  def checkout_form(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl rounded-md bg-slate-50 shadow-md overflow-hidden">
      <div :if={@has_variants} class="grid gap-3 p-6 bg-white">
        <div :for={variant <- @product_variants} class="relative bg-primary-50 shadow-md">
          <input
            class="peer hidden"
            id={"radio_" <> variant.id}
            type="radio"
            name="radio"
            phx-click={JS.push("select_variant", value: %{"id" => variant.id}, target: @submit_target)}
            checked={@selected_variant && variant.id == @selected_variant.id}
          />
          <span class="peer-checked:border-primary-700 absolute right-4 top-7 box-content block h-3 w-3 -translate-y-1/2 rounded-full border-8 border-gray-300 bg-white">
          </span>
          <label
            class="peer-checked:border-2 peer-checked:border-primary-700 peer-checked:bg-primary-50 flex cursor-pointer select-none rounded-md border border-gray-300 p-4"
            for={"radio_" <> variant.id}
          >
            <div class="w-full">
              <div class="font-semibold flex pr-12">
                <span class="flex-1 text-primary-600 font-bold"><%= variant.name %></span>
                <.price value={variant.price} />
              </div>
              <p class="text-slate-600 text-sm mt-1 pr-10">
                <%= variant.description %>
              </p>
            </div>
          </label>
        </div>
      </div>

      <%!-- fixed price and variant price total --%>
      <div
        :if={!@has_variants && @product.price_type == :fixed}
        class="p-6 flex items-center justify-between bg-white"
      >
        <p class="text-2xl font-medium text-slate-900">Total</p>
        <p class="text-2xl font-bold text-slate-600">
          <.price value={@total_price} />
        </p>
      </div>

      <hr/>
      <%!--  FORM --%>
      <div class="space-y-4">
        <.simple_form
          :let={f}
          for={@changeset}
          as={:order}
          phx-update="replace"
          phx-submit={@submit_event}
          phx-target={@submit_target}
        >
          <div
            :if={!@has_variants && @product.price_type == :flexible}
            class="mb-2 p-6 md:flex items-center justify-between bg-white border-b"
          >
            <div class="text-lg font-medium text-gray-900">
              Bayar suka-suka
              <div class="text-xs text-gray-400">Minimal <.price value={@product.price} /></div>
            </div>
            <div class="flex items-center text-2xl font-semibold text-gray-900">
              <.input field={f[:custom_price]} type="number" wrapper_class="w-full" placeholder={"Min. #{@product.price}"} required />
            </div>
          </div>

          <div class="space-y-6 pt-4 px-6">
            <.input field={f[:customer_name]} type="text" label="Nama *" required />
            <div class="md:flex gap-4">
              <.input
                field={f[:customer_email]}
                type="email"
                label="Alamat email *"
                required
                wrapper_class="flex-1"
              />
              <.input
                field={f[:customer_phone]}
                type="text"
                label="No. HP / WhatsApp"
                wrapper_class="flex-1 mt-4 md:mt-0"
              />
            </div>

            <div :if={@enable_captcha} id="cf-turnstile" phx-hook="RenderCaptcha" />

            <%!-- <label class="flex items-center">
              <.input field={f[:confirm]} type="checkbox" required />
              <span class="text-sm text-slate-500 ml-2">
                Saya menyatakan data di atas sudah benar.
              </span>
            </label> --%>

            <div
              :if={@error}
              class="p-4 mb-4 text-sm font-medium text-red-800 rounded-md bg-red-50 dark:bg-gray-800 dark:text-red-400 border border-dashed border-red-800"
              role="alert"
            >
              <.icon name="hero-exclamation-triangle" /> <%= @error %>
            </div>
          </div>

          <:actions>
          <div class="px-6 pb-8">
            <button
              type="submit"
              class="mt-6 w-full items-center justify-center rounded-md bg-primary-600 p-4 text-lg font-semibold text-white transition-all duration-200 ease-in-out focus:shadow hover:bg-primary-700"
            >
              <%= if Products.cta_custom?(@product.cta) do %>
                <%= @product.cta_text %>
              <% else %>
                <%= Products.cta_text(@product.cta) %>
              <% end %>
            </button>
          </div>
          </:actions>
        </.simple_form>
      </div>
      <%!-- END FORM --%>

      <%!-- <div class="text-center pt-4 mt-6">
        <p class="text-sm text-slate-400 items-center">
          Produk ini disediakan oleh
          <span class="font-semibold text-primary-500">UpKoding</span>
          <.icon
            name="hero-arrow-top-right-on-square"
            class="w-4 h-4 inline-block text-primary-500"
          />
        </p>
      </div> --%>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      case Map.get(assigns, :changeset) do
        nil ->
          product = assigns.product
          variants = App.Products.list_variants_by_product(product, true)

          socket
          |> assign(assigns)
          |> assign(:product, product)
          |> assign(:preview, false)
          |> assign(:enable_captcha, true)
          |> assign(:has_variants, Products.has_variants?(product, true))
          |> assign(:product_variants, variants)
          |> assign(:total_price, product.price)
          |> maybe_select_default_variant(variants)

        changeset ->
          product = Ecto.Changeset.apply_changes(changeset)
          variants = App.Products.list_variants_by_product(product, true)

          socket
          |> assign(:product, product)
          |> assign(:preview, true)
          |> assign(:enable_captcha, false)
          |> assign(:has_variants, Products.has_variants?(product, true))
          |> assign(:product_variants, variants)
          |> assign(:total_price, product.price)
          |> maybe_select_default_variant(variants)
      end
      |> assign(:error, nil)
      |> assign(:checkout_changeset, Orders.change_order(%Orders.Order{}))

    {:ok, socket}
  end

  @impl true
  def handle_event("select_variant", %{"id" => id}, socket) do
    variant = Enum.find(socket.assigns.product_variants, fn v -> v.id == id end)
    {:noreply, select_variant(socket, variant)}
  end

  @impl true
  def handle_event(
        "fake_order",
        %{"order" => order_params},
        socket
      ) do
    order_params =
      order_params
      |> Map.put("product", socket.assigns.product)
      |> Map.put("product_variant", socket.assigns.selected_variant)
      |> Map.put("invoice_number", Orders.generate_invoice_number())
      |> Map.put("valid_until", Orders.valid_until_hours(1))

    changeset = Order.create_changeset(%Order{}, order_params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, order} ->
        send(self(), {__MODULE__, order})
        {:noreply, assign(socket, :checkout_changeset, changeset)}

      {:error, changeset} ->
        {:noreply, assign(socket, :checkout_changeset, changeset)}
    end
  end

  @impl true
  def handle_event(
        "create_order",
        _params,
        %{assigns: %{product: %{is_live: false}}} = socket
      ) do
    {:noreply, assign(socket, :error, "Produk ini belum aktif.")}
  end

  @impl true
  def handle_event(
        "create_order",
        %{"order" => order_params, "cf-turnstile-response" => captcha_token},
        socket
      ) do
    # verify captcha token
    :ok = Captcha.verify_token(captcha_token)

    order_params =
      order_params
      |> Map.put("product", socket.assigns.product)
      |> Map.put("product_variant", socket.assigns[:selected_variant])
      |> Map.put("invoice_number", Orders.generate_invoice_number())
      |> Map.put(
        "valid_until",
        Orders.valid_until_hours(Application.fetch_env!(:app, :order_validity_hours))
      )

    case Orders.create_order(order_params) do
      {:ok, order} ->
        send(self(), {__MODULE__, order})
        {:noreply, assign(socket, :checkout_changeset, Orders.change_order(order, %{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :checkout_changeset, changeset)}
    end
  end

  defp select_variant(socket, variant) do
    socket
    |> assign(:selected_variant, variant)
    |> assign(:total_price, variant.price)
    |> assign(:error, nil)
  end

  defp maybe_select_default_variant(socket, variants) do
    cond do
      Enum.empty?(variants) ->
        assign(socket, :selected_variant, nil)

      true ->
        select_variant(socket, Enum.at(variants, 0))
    end
  end
end
