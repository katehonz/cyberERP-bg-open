defmodule CyberCore.Sales.Quotation do
  @moduledoc """
  Оферти за клиенти.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft sent accepted rejected expired)

  schema "quotations" do
    field :tenant_id, :integer

    # Номериране
    field :quotation_no, :string
    field :status, :string, default: "draft"

    # Дати
    field :issue_date, :date
    field :valid_until, :date

    # Връзки
    belongs_to :contact, CyberCore.Contacts.Contact
    field :contact_name, :string
    field :contact_email, :string
    field :contact_phone, :string

    # Финансови данни
    field :subtotal, :decimal, default: Decimal.new(0)
    field :tax_amount, :decimal, default: Decimal.new(0)
    field :total_amount, :decimal, default: Decimal.new(0)
    field :currency, :string, default: "BGN"

    # Допълнителна информация
    field :notes, :string
    field :terms_and_conditions, :string

    # Връзка към фактура (ако е приета)
    field :invoice_id, :integer

    # Редове на офертата
    has_many :quotation_lines, CyberCore.Sales.QuotationLine

    timestamps()
  end

  @doc false
  def changeset(quotation, attrs) do
    quotation
    |> cast(attrs, [
      :tenant_id,
      :quotation_no,
      :status,
      :issue_date,
      :valid_until,
      :contact_id,
      :contact_name,
      :contact_email,
      :contact_phone,
      :subtotal,
      :tax_amount,
      :total_amount,
      :currency,
      :notes,
      :terms_and_conditions,
      :invoice_id
    ])
    |> validate_required([
      :tenant_id,
      :quotation_no,
      :issue_date,
      :valid_until,
      :contact_id,
      :contact_name
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:quotation_no, max: 50)
    |> validate_length(:currency, is: 3)
    |> unique_constraint([:tenant_id, :quotation_no])
    |> foreign_key_constraint(:contact_id)
    |> validate_dates()
  end

  defp validate_dates(changeset) do
    issue_date = get_field(changeset, :issue_date)
    valid_until = get_field(changeset, :valid_until)

    if issue_date && valid_until && Date.compare(issue_date, valid_until) == :gt do
      add_error(changeset, :valid_until, "трябва да е след датата на издаване")
    else
      changeset
    end
  end
end
