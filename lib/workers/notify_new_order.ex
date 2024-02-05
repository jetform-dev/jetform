defmodule Workers.NotifyNewOrder do
  use Oban.Worker, queue: :default, max_attempts: 3
  require Logger
  alias App.Orders

  def create(%{status: :pending} = order) do
    %{id: order.id}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def create(_order) do
    {:ok, :noop}
  end

  @impl true
  def perform(%{args: %{"id" => id}}) do
    case Orders.get_order(id) do
      nil ->
        Logger.warning("#{__MODULE__} warning: order=#{id} not found")

        :ok

      order ->
        send_email(order |> App.Repo.preload(:user))
    end
  end

  defp send_email(order) do
    base_url = AppWeb.Utils.base_url()

    buyer_text = """
    Halo #{order.customer_name},

    Anda telah melakukan pembelian berikut:
    No. Invoice: ##{order.invoice_number}
    Produk: #{Orders.product_fullname(order)}
    Total: Rp. #{order.total}
    Status: #{order.status} (Menunggu Pembayaran)

    Detail pembelian dan cara pembayaran bisa anda lihat di halaman berikut:
    #{base_url}/invoice/#{order.id}

    --
    Tim Snappy
    """

    user = order.user

    user_text = """
    Halo #{user.email},

    Terdapat pesanan baru atas produk anda:
    No. Invoice: ##{order.invoice_number}
    Produk: #{Orders.product_fullname(order)}
    Total: Rp. #{order.total}
    Status: #{order.status} (Menunggu Pembayaran)

    --
    Tim Snappy
    """

    [
      %{
        user: %{name: order.customer_name, email: order.customer_email},
        subject:
          "Detail pembelian anda ##{order.invoice_number} | #{Orders.product_fullname(order)}",
        text: buyer_text,
        html: nil
      },
      %{
        user: %{name: "", email: user.email},
        subject: "Order Pending ##{order.invoice_number} | #{Orders.product_fullname(order)}",
        text: user_text,
        html: nil
      }
    ]
    |> Enum.map(&App.Mailer.cast/1)
    |> App.Mailer.deliver_many()
  end
end
