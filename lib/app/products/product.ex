defmodule App.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Utils.ReservedWords

  @required_fields ~w(name slug price)a
  @optional_fields ~w(is_live description)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :name, :string
    field :slug, :string
    field :price, :integer, default: 0
    field :description, :string
    field :is_live, :boolean, default: false

    belongs_to :user, App.Users.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_slug()
  end

  def create_changeset(product, attrs) do
    product
    |> changeset(attrs)
    |> validate_user(attrs)
  end

  defp validate_slug(changeset) do
    changeset
    |> validate_length(:slug, min: 3, max: 150)
    |> validate_format(:slug, ~r/^[a-zA-Z0-9_\-]+$/)
    |> validate_reserved_words(:slug)
    |> unsafe_validate_unique(:slug, App.Repo)
    |> unique_constraint(:slug)
  end

  defp validate_user(changeset, attrs) do
    case Map.get(attrs, "user") do
      nil -> add_error(changeset, :user, "can't be blank")
      user -> put_assoc(changeset, :user, user)
    end
  end

  defp validate_reserved_words(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      if ReservedWords.is_reserved?(value) do
        [{field, "is reserved"}]
      else
        []
      end
    end)
  end
end