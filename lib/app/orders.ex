defmodule App.Orders do
  @moduledoc """
  The Orders context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias App.Repo
  alias App.Orders.{Order, Payment}
  alias App.Contents
  alias App.Credits
  alias App.PaymentGateway.CreateTransactionResult

  # ------------- ORDERS -------------

  defdelegate time_before_expired(order), to: Order

  def generate_invoice_number() do
    month = Timex.now() |> Timex.format!("%y%m%d", :strftime)
    random = :crypto.strong_rand_bytes(2) |> :crypto.bytes_to_integer()
    "#{month}-#{random}"
  end

  def product_fullname(%Order{} = order) do
    case order.product_variant_name do
      nil -> order.product_name
      variant_name -> "#{order.product_name} (#{variant_name})"
    end
  end

  def stats_by_user_and_time(user, start_at \\ nil) do
    start_at = start_at || user.email_confirmed_at

    from(o in Order,
      select: {
        fragment("sum(case when status = 'free' then 1 else 0 end) as free_count"),
        fragment("sum(case when status = 'paid' then 1 else 0 end) as paid_count"),
        fragment("sum(case when status = 'expired' then 1 else 0 end) as expired_count"),
        fragment("sum(case when status = 'paid' then total else 0 end) as gross_revenue"),
        fragment("sum(case when status = 'paid' then service_fee else 0 end) as service_fee"),
        fragment("sum(case when status = 'paid' then gateway_fee else 0 end) as gateway_fee")
      },
      where: o.user_id == ^user.id,
      where: o.inserted_at >= ^start_at
    )
    |> Repo.one()
    |> then(fn {free_count, paid_count, expired_count, gross_revenue, service_fee, gateway_fee} ->
      %{
        free_count: free_count || 0,
        paid_count: paid_count || 0,
        expired_count: expired_count || 0,
        gross_revenue: gross_revenue || 0,
        service_fee: service_fee || 0,
        gateway_fee: gateway_fee || 0
      }
    end)
  end

  def stats_by_product_and_time(product, start_at \\ nil) do
    start_at = start_at || product.inserted_at

    from(o in Order,
      select: {
        fragment("sum(case when status = 'free' then 1 else 0 end) as free_count"),
        fragment("sum(case when status = 'paid' then 1 else 0 end) as paid_count"),
        fragment("sum(case when status = 'expired' then 1 else 0 end) as expired_count"),
        fragment("sum(case when status = 'paid' then total else 0 end) as gross_revenue"),
        fragment("sum(case when status = 'paid' then service_fee else 0 end) as service_fee"),
        fragment("sum(case when status = 'paid' then gateway_fee else 0 end) as gateway_fee")
      },
      where: o.product_id == ^product.id,
      where: o.inserted_at >= ^start_at
    )
    |> Repo.one()
    |> then(fn {free_count, paid_count, expired_count, gross_revenue, service_fee, gateway_fee} ->
      %{
        free_count: free_count || 0,
        paid_count: paid_count || 0,
        expired_count: expired_count || 0,
        gross_revenue: gross_revenue || 0,
        service_fee: service_fee || 0,
        gateway_fee: gateway_fee || 0
      }
    end)
  end

  def daily_counts_by_user(user, start_at \\ nil) do
    start_at = start_at || user.email_confirmed_at

    from(o in Order,
      select: {
        fragment("date_trunc('day', inserted_at) as date"),
        fragment("sum(case when status = 'free' then 1 else 0 end) as free_count"),
        fragment("sum(case when status = 'paid' then 1 else 0 end) as paid_count")
      },
      where: o.user_id == ^user.id,
      where: o.inserted_at >= ^start_at,
      group_by: fragment("date")
    )
    |> Repo.all()
  end

  def daily_counts_by_product(product, start_at \\ nil) do
    start_at = start_at || product.inserted_at

    from(o in Order,
      select: {
        fragment("date_trunc('day', inserted_at) as date"),
        fragment("sum(case when status = 'free' then 1 else 0 end) as free_count"),
        fragment("sum(case when status = 'paid' then 1 else 0 end) as paid_count")
      },
      where: o.product_id == ^product.id,
      where: o.inserted_at >= ^start_at,
      group_by: fragment("date")
    )
    |> Repo.all()
  end

  def top_products(user, start_at \\ nil) do
    start_at = start_at || user.email_confirmed_at

    from(o in Order,
      select: [
        o.product_id,
        o.product_variant_id,
        fragment("MIN(?)", o.product_name),
        fragment("MIN(?)", o.product_variant_name),
        count(o.id)
      ],
      where: o.user_id == ^user.id,
      where: o.inserted_at >= ^start_at,
      group_by: [o.product_id, o.product_variant_id],
      order_by: [desc: count(o.id)],
      limit: 5
    )
    |> Repo.all()
    |> Enum.map(fn [product_id, product_variant_id, product_name, product_variant_name, count] ->
      %{
        product_id: product_id,
        product_variant_id: product_variant_id,
        product_name: product_name,
        product_variant_name: product_variant_name,
        count: count
      }
    end)
  end

  @doc """
  Returns the list of orders.

  ## Examples

      iex> list_orders()
      [%Order{}, ...]

  """
  def list_orders do
    Repo.all(Order)
  end

  @doc """
  Returns the list of orders for a given user.
  """
  def list_orders!(user, query) do
    from(
      o in Order,
      where: not is_nil(o.product_id)
    )
    |> list_orders_by_user_scope(user)
    |> Flop.validate_and_run!(query)
  end

  def list_orders_by_user_scope(q, %{role: :admin}), do: q

  def list_orders_by_user_scope(q, user) do
    where(q, [o], o.user_id == ^user.id)
  end

  @doc """
  Gets a single order.

  Raises `Ecto.NoResultsError` if the Order does not exist.

  ## Examples

      iex> get_order!(123)
      %Order{}

      iex> get_order!(456)
      ** (Ecto.NoResultsError)

  """
  def get_order!(id), do: Repo.get!(Order, id)
  def get_order(id), do: Repo.get(Order, id)

  @doc """
  Creates a order.

  ## Examples

      iex> create_order(%{field: value})
      {:ok, %Order{}}

      iex> create_order(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_order(attrs \\ %{}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:order, Order.create_changeset(%Order{}, attrs))
    |> Ecto.Multi.run(:contents, fn repo, %{order: order} ->
      # get contents for order
      order = repo.preload(order, :product_variant)

      case order.product_variant do
        nil ->
          {:ok, Contents.list_contents_by_product(order.product)}

        variant ->
          {:ok, Contents.list_contents_by_variant(variant)}
      end
    end)
    |> Ecto.Multi.update(:order_with_contents, fn %{order: order, contents: contents} ->
      # put contents to order
      Repo.preload(order, :contents)
      |> Order.changeset(%{})
      |> Order.put_contents(contents)
    end)
    |> Ecto.Multi.run(:access, fn _repo, %{order: order} ->
      # If order is free, create content access for buyer
      case order.status do
        :free ->
          Contents.create_changeset_for_order(order) |> Contents.create_access()

        _ ->
          {:ok, nil}
      end
    end)
    |> Ecto.Multi.run(:workers, fn _repo, %{order: order, access: access} ->
      # - (if: pending) schedule a job to invalidate the order after it expires
      # - (always) notify buyer about the order
      # - (if: paid) notify buyer about their access to the product
      with {:ok, _} <- Workers.InvalidateOrder.create(order),
           {:ok, _} <- Workers.NotifyNewOrder.create(order),
           {:ok, _} <- Workers.NotifyNewAccess.create(access) do
        {:ok, true}
      else
        err -> err
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order_with_contents: order}} ->
        {:ok, order}

      {:error, op, value, changeset} ->
        Logger.error("create_order/1 error: op=#{inspect(op)}, value=#{inspect(value)}")
        {:error, changeset}
    end
  end

  @doc """
  Updates a order.

  ## Examples

      iex> update_order(order, %{field: new_value})
      {:ok, %Order{}}

      iex> update_order(order, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, order} ->
        # notify all subscribers (e.g. invoice page) that this order has been updated.
        Phoenix.PubSub.broadcast(
          App.PubSub,
          "order:#{order.id}",
          "order:updated"
        )

        {:ok, order}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a order.

  ## Examples

      iex> delete_order(order)
      {:ok, %Order{}}

      iex> delete_order(order)
      {:error, %Ecto.Changeset{}}

  """
  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking order changes.

  ## Examples

      iex> change_order(order)
      %Ecto.Changeset{data: %Order{}}

  """
  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.changeset(order, attrs)
  end

  def valid_until_hours(value \\ 1) do
    DateTime.utc_now() |> DateTime.add(value, :hour)
  end

  def total_fee(%Order{} = order) do
    order.service_fee + order.gateway_fee
  end

  def net_amount(%Order{} = order) do
    order.total - total_fee(order)
  end

  # ------------- PAYMENTS -------------

  def get_payment(id), do: Repo.get(Payment, id)
  def get_payment!(id), do: Repo.get!(Payment, id)

  def get_empty_payment(order) do
    from(
      p in Payment,
      where: p.order_id == ^order.id,
      where: is_nil(p.trx_status)
    )
    |> Repo.one()
  end

  def fetch_pending_payments(order) do
    from(
      p in Payment,
      where: p.order_id == ^order.id,
      where: p.trx_status == "pending"
    )
    |> Repo.all()
  end

  def change_payment(%Payment{} = payment, attrs \\ %{}) do
    Payment.changeset(payment, attrs)
  end

  @doc """
  Create a payment for an order and generate payment URL.
    0. cancel all pending payments for this order before creating new one
    1. calculate the expiry time in minutes
    2. create payment record
    3. create transaction and get `redirect_url`
    4. update payment record with `redirect_url`
  """
  def create_payment(%Order{} = order, minimum_expiry_minutes \\ 5) do
    fetch_pending_payments(order)
    |> Task.async_stream(&cancel_payment/1)
    |> Stream.run()

    Ecto.Multi.new()
    |> Ecto.Multi.run(:expiry_in_minutes, fn _repo, _ ->
      # calculate the expiry time in minutes
      expiry_min = Integer.floor_div(time_before_expired(order), 60)

      cond do
        expiry_min <= minimum_expiry_minutes -> {:error, :expire_soon}
        true -> {:ok, expiry_min}
      end
    end)
    |> Ecto.Multi.insert(:new_payment, Payment.create_changeset(%Payment{}, %{"order" => order}))
    |> Ecto.Multi.run(:redirect_url, fn _repo,
                                        %{
                                          expiry_in_minutes: expiry,
                                          new_payment: payment
                                        } ->
      payload =
        App.payment_provider().create_transaction_payload(order, payment,
          expiry_in_minutes: expiry
        )

      case App.payment_provider().create_transaction(payload) do
        {:ok, %CreateTransactionResult{} = result} ->
          {:ok, result.redirect_url}

        {:error, err} ->
          Logger.error("#{App.payment_provider()}.create_transaction/1 error: #{inspect(err)}")
          {:error, :payment_gateway_error}
      end
    end)
    |> Ecto.Multi.update(:updated_payment, fn %{new_payment: payment, redirect_url: redirect_url} ->
      Payment.changeset(payment, %{"redirect_url" => redirect_url})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_payment: payment}} ->
        {:ok, payment}

      {:error, _op, value, changeset} ->
        {:error, value, changeset}
    end
  end

  defguard is_paid(transaction_status) when transaction_status == "paid"

  def update_payment(%Payment{trx_status: old_status} = payment, _trx) when is_paid(old_status) do
    # alread paid, do nothing
    {:ok, payment}
  end

  def update_payment(
        %{trx_status: old_status} = payment,
        %{trx_status: new_status} = trx
      )
      when not is_paid(old_status) and is_paid(new_status) do
    payment = Repo.preload(payment, :order)
    # payment successfull:
    # - update payment status
    # - update order status
    # - create credit for seller
    # - create content access for buyer
    # - broadcast order:updated event
    # - create Oban job to deliver (create content access, send email to buyer) content
    Ecto.Multi.new()
    |> Ecto.Multi.update(:payment, Payment.changeset(payment, trx))
    |> Ecto.Multi.update(
      :order,
      fn %{payment: payment} ->
        change_order(payment.order, %{
          "status" => "paid",
          "payment_type" => payment.type,
          "gateway_fee" => payment.fee,
          "paid_at" => Timex.now()
        })
      end
    )
    |> Ecto.Multi.insert(:credit, fn %{order: order} ->
      Credits.create_changeset_for_order(order)
    end)
    |> Ecto.Multi.insert(:access, fn %{order: order} ->
      Contents.create_changeset_for_order(order)
    end)
    |> Ecto.Multi.run(:workers, fn _repo, %{order: order, access: access} ->
      # - notify product owner and buyer about paid order
      # - create a job to deliver (create content access, send email to buyer) content
      with {:ok, _} <- Workers.NotifyPaidOrder.create(order),
           {:ok, _} <- Workers.NotifyNewAccess.create(access) do
        {:ok, true}
      else
        err -> err
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{payment: payment, order: order}} ->
        # notify all subscribers (e.g. invoice page) that this order has been updated.
        Phoenix.PubSub.broadcast(
          App.PubSub,
          "order:#{order.id}",
          "order:updated"
        )

        {:ok, %{payment | order: order}}

      {:error, _op, value, changeset} ->
        {:error, value, changeset}
    end
  end

  def update_payment(%Payment{} = payment, %{} = trx) do
    # other status, just update payment status
    Payment.changeset(payment, trx) |> Repo.update()
  end

  def refresh_payment(%Payment{} = payment) do
    with {:ok, trx} <- App.payment_provider().get_transaction(payment.id),
         {:ok, payment} <- update_payment(payment, Map.from_struct(trx)) do
      {:ok, payment}
    else
      err -> err
    end
  end

  def cancel_payment(%Payment{} = payment) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:payment, change_payment(payment, %{"trx_status" => "cancel"}))
    |> Ecto.Multi.run(:cancel, fn _repo, %{payment: payment} ->
      App.payment_provider().cancel_transaction(payment.id)
    end)
    |> Repo.transaction()
  end
end
