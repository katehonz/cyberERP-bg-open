defmodule CyberCore.Bank.BankConnection do
  @moduledoc """
  Salt Edge bank connection.

  Съхранява информация за връзка към банка през Salt Edge API.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "bank_connections" do
    field :saltedge_connection_id, :string
    field :saltedge_customer_id, :string
    field :provider_code, :string
    field :provider_name, :string
    field :status, :string, default: "active"
    field :consent_expires_at, :utc_datetime
    field :last_success_at, :utc_datetime
    field :last_attempt_at, :utc_datetime
    field :last_error, :string
    field :metadata, :map

    # Associations
    belongs_to :tenant, CyberCore.Accounts.Tenant
    belongs_to :bank_profile, CyberCore.Bank.BankProfile
    belongs_to :created_by, CyberCore.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [
      :tenant_id,
      :bank_profile_id,
      :saltedge_connection_id,
      :saltedge_customer_id,
      :provider_code,
      :provider_name,
      :status,
      :consent_expires_at,
      :last_success_at,
      :last_attempt_at,
      :last_error,
      :metadata,
      :created_by_id
    ])
    |> validate_required([
      :tenant_id,
      :saltedge_connection_id,
      :saltedge_customer_id,
      :status
    ])
    |> validate_inclusion(:status, ["active", "inactive", "reconnect_required"])
    |> unique_constraint(:saltedge_connection_id)
  end

  @doc """
  Проверява дали връзката е активна и валидна.
  """
  def active?(%__MODULE__{status: "active", consent_expires_at: expires_at}) do
    if expires_at do
      DateTime.compare(expires_at, DateTime.utc_now()) == :gt
    else
      true
    end
  end

  def active?(_), do: false

  @doc """
  Маркира връзката като неуспешна.
  """
  def mark_failed(connection, error_message) do
    connection
    |> changeset(%{
      last_attempt_at: DateTime.utc_now(),
      last_error: error_message
    })
  end

  @doc """
  Маркира връзката като успешна.
  """
  def mark_success(connection) do
    connection
    |> changeset(%{
      last_success_at: DateTime.utc_now(),
      last_attempt_at: DateTime.utc_now(),
      last_error: nil
    })
  end
end
