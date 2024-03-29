defmodule App.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      # pow's fields
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string
      # extra fields
      # add :username, :string, null: false
      add :role, :string, null: false
      add :timezone, :string, null: false
      add :plan, :string, null: false
      add :plan_valid_until, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    # create unique_index(:users, [:username])
  end
end
