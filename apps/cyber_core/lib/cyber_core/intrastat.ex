defmodule CyberCore.Intrastat do
  @moduledoc """
  The Intrastat context.
  """

  import Ecto.Query, warn: false
  alias CyberCore.Repo

  alias CyberCore.Intrastat.IntrastatDeclaration
  alias CyberCore.Intrastat.IntrastatDeclarationLine
  alias CyberCore.Inventory.StockMovement
  alias CyberCore.Sales.Invoice
  alias CyberCore.Purchase.SupplierInvoice
  alias Decimal

  def get_declaration(tenant_id, year, month, flow) do
    Repo.get_by(IntrastatDeclaration, tenant_id: tenant_id, year: year, month: month, flow: flow)
  end

  def get_or_create_declaration(tenant_id, year, month, flow) do
    case get_declaration(tenant_id, year, month, flow) do
      %IntrastatDeclaration{} = declaration ->
        {:ok, declaration}

      nil ->
        %IntrastatDeclaration{}
        |> IntrastatDeclaration.changeset(%{
          tenant_id: tenant_id,
          year: year,
          month: month,
          flow: flow,
          country_of_consignment: "BG",
          transaction_nature: "11",
          commodity_code: "00000000",
          invoiced_amount: Decimal.new(0)
        })
        |> Repo.insert()
    end
  end

  def list_declaration_lines(declaration_id) do
    Repo.all(
      from l in IntrastatDeclarationLine,
      where: l.intrastat_declaration_id == ^declaration_id,
      order_by: [asc: :commodity_code]
    )
  end

  @doc """
  Generates Intrastat declarations for a given period and flow, based on stock movements.
  """
  def generate_declarations(tenant_id, year, month, flow) do
    # 1. Get or Create IntrastatDeclaration
    case get_or_create_declaration(tenant_id, year, month, flow) do
      {:ok, declaration} ->
        # 2. Delete existing lines (ensures idempotency)
        Repo.delete_all(
          from l in IntrastatDeclarationLine,
          where: l.intrastat_declaration_id == ^declaration.id
        )

        # 3. Define Date Range
        start_date = Date.new!(year, month, 1)
        end_date = Date.end_of_month(start_date)

        # 4. Define movement types for flow
        movement_types =
          if flow == "arrivals" do
            ["purchase", "transfer_in", "production_output"]
          else
            # dispatches
            ["sale", "transfer", "production_input", "scrap"]
          end

        # 5. Query StockMovements
        query =
          from sm in StockMovement,
            join: p in assoc(sm, :product),
            left_join: cnn in assoc(p, :cn_code),
            # Join for Sales Invoices (Dispatches)
            left_join: si in Invoice,
            on: sm.reference_id == si.id and sm.reference_type == "SalesInvoice",
            left_join: sic in assoc(si, :customer),
            # Join for Purchase Invoices (Arrivals)
            left_join: pi in SupplierInvoice,
            on: sm.reference_id == pi.id and sm.reference_type == "Purchase.SupplierInvoice",
            left_join: pic in assoc(pi, :supplier),
            where: sm.tenant_id == ^tenant_id,
            where: sm.date >= ^start_date and sm.date <= ^end_date,
            where: sm.movement_type in ^movement_types,
            select: %{
              movement: sm,
              cn_code: cnn.code,
              partner_country: coalesce(sic.country, pic.country)
            }

        movements_data = Repo.all(query)

        # 6. Group and Aggregate movements
        grouped_lines =
          Enum.group_by(movements_data, fn %{cn_code: cn_code, partner_country: partner_country} ->
            commodity_code = cn_code || "00000000" # Fallback if no CN code found
            partner_member_state = partner_country || "BG" # Default to Bulgaria
            country_of_origin = if flow == "arrivals", do: partner_country || "BG", else: "BG" # Origin is partner for arrivals
            transaction_nature = if flow == "arrivals", do: "1", else: "2" # 1 for purchase, 2 for sale (placeholder)
            mode_of_transport = "3" # Placeholder (e.g., 3 for Road)
            delivery_terms = "EXW" # Placeholder

            {commodity_code, partner_member_state, country_of_origin, transaction_nature, mode_of_transport, delivery_terms}
          end)
          |> Enum.map(fn {{commodity_code, partner_member_state, country_of_origin, transaction_nature, mode_of_transport, delivery_terms}, movements} ->
            total_invoiced_value =
              Enum.reduce(movements, Decimal.new(0), fn %{movement: sm}, acc ->
                line_value = Decimal.mult(sm.quantity || Decimal.new(0), sm.unit_price || Decimal.new(0))
                Decimal.add(acc, line_value)
              end)

            # Using quantity for net_mass and supplementary_unit as per previous logic
            total_quantity =
              Enum.reduce(movements, Decimal.new(0), fn %{movement: sm}, acc ->
                Decimal.add(acc, sm.quantity || Decimal.new(0))
              end)

            # 7. Create IntrastatDeclarationLine changeset
            %IntrastatDeclarationLine{}
            |> IntrastatDeclarationLine.changeset(%{
              intrastat_declaration_id: declaration.id,
              commodity_code: commodity_code,
              partner_member_state: partner_member_state,
              country_of_origin: country_of_origin,
              transaction_nature: transaction_nature,
              delivery_terms: delivery_terms,
              mode_of_transport: mode_of_transport,
              net_mass: total_quantity,
              supplementary_unit: total_quantity,
              invoiced_value: total_invoiced_value,
              statistical_value: total_invoiced_value # Using invoiced value as statistical value
            })
          end)
          |> Enum.filter(& &1.valid?)

        # 8. Insert new lines
        if Enum.any?(grouped_lines) do
          changesets = Enum.map(grouped_lines, & &1.changes)
          Repo.insert_all(IntrastatDeclarationLine, changesets, on_conflict: :nothing)
        end

        {:ok, declaration}

      {:error, reason} ->
        {:error, reason}
    end
  end
end