defmodule Workers.NotifyPaidOrder do
  use Oban.Worker, queue: :default, max_attempts: 3
  require Logger
  alias App.Orders

  def create(%{status: :paid} = order) do
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

    Pembayaran anda atas produk berikut berhasil:
    No. Invoice: ##{order.invoice_number}
    Produk: #{Orders.product_fullname(order)}
    Total: Rp. #{order.total}
    Status: #{order.status} (LUNAS)

    *** PENTING ***
    Anda akan segera menerima email tentang cara mengakses ke produk yang anda beli.
    Apabila dalam 1 jam anda belum menerima email tersebut, silahkan hubungi kami dengan membalas email ini.

    Detail pembelian bisa anda lihat di halaman berikut:
    #{base_url}/invoice/#{order.id}

    --
    Tim JetForm
    """

    user = order.user

    user_text = """
    Halo #{user.email},

    Pembelian atas produk anda telah LUNAS:
    No. Invoice: #{order.invoice_number}
    Produk: #{Orders.product_fullname(order)}
    Harga: Rp. #{order.total}
    Status: #{order.status} (LUNAS)

    Detail pembelian bisa anda lihat di halaman berikut:
    #{base_url}/invoice/#{order.id}

    --
    Tim JetForm
    """

    [
      %{
        user: %{name: "", email: user.email},
        subject: "Order Lunas ##{order.invoice_number} | #{Orders.product_fullname(order)}",
        text: user_text,
        html: nil
      },
      %{
        user: %{name: order.customer_name, email: order.customer_email},
        subject:
          "Pembayaran berhasil ##{order.invoice_number} | #{Orders.product_fullname(order)}",
        text: buyer_text,
        html: nil
      }
    ]
    |> Enum.map(&App.Mailer.cast/1)
    |> App.Mailer.deliver_many()
  end
end