defmodule CyberCore.Bank.BankProfile do
  @moduledoc """
  Конфигурация на банкова сметка.

  Поддържа:
  - Ръчен импорт на файлове (MT940, CAMT053, CSV, XML)
  - Автоматична синхронизация през Salt Edge API
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "bank_profiles" do
    field :name, :string
    field :iban, :string
    field :bic, :string
    field :bank_name, :string
    field :currency_code, :string, default: "BGN"
    field :import_format, :string
    field :is_active, :boolean, default: true

    # Salt Edge integration
    field :saltedge_connection_id, :string
    field :saltedge_account_id, :string
    field :auto_sync_enabled, :boolean, default: false
    field :last_synced_at, :utc_datetime

    # Settings
    field :settings, :map

    # Associations
    belongs_to :tenant, CyberCore.Accounts.Tenant
    belongs_to :bank_account, CyberCore.Accounting.Account
    belongs_to :buffer_account, CyberCore.Accounting.Account
    belongs_to :created_by, CyberCore.Accounts.User

    has_many :bank_imports, CyberCore.Bank.BankImport
    has_one :bank_connection, CyberCore.Bank.BankConnection

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bank_profile, attrs) do
    bank_profile
    |> cast(attrs, [
      :tenant_id,
      :name,
      :iban,
      :bic,
      :bank_name,
      :bank_account_id,
      :buffer_account_id,
      :currency_code,
      :import_format,
      :is_active,
      :saltedge_connection_id,
      :saltedge_account_id,
      :auto_sync_enabled,
      :last_synced_at,
      :settings,
      :created_by_id
    ])
    |> validate_required([:tenant_id, :name, :bank_account_id, :buffer_account_id, :currency_code])
    |> validate_length(:currency_code, is: 3)
    |> validate_inclusion(:import_format, [
      "mt940",
      "camt053_wise",
      "camt053_revolut",
      "camt053_paysera",
      "ccb_csv",
      "postbank_xml",
      "obb_xml"
    ])
    |> validate_iban(:iban)
    |> unique_constraint([:tenant_id, :iban])
  end

  defp validate_iban(changeset, field) do
    validate_change(changeset, field, fn ^field, iban ->
      if iban && String.length(iban) > 0 do
        case CyberCore.Validators.IBAN.validate(iban) do
          {:ok, _} -> []
          {:error, reason} -> [{field, "invalid IBAN: #{reason}"}]
        end
      else
        []
      end
    end)
  end

  @doc """
  Проверява дали профилът има активна Salt Edge връзка.
  """
  def has_saltedge_connection?(%__MODULE__{} = profile) do
    not is_nil(profile.saltedge_connection_id)
  end

  @doc """
  Проверява дали профилът поддържа ръчен импорт на файлове.
  """
  def supports_file_import?(%__MODULE__{} = profile) do
    not is_nil(profile.import_format)
  end
end
