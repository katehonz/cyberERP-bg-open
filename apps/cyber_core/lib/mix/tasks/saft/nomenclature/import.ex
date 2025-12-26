defmodule Mix.Tasks.Saft.Nomenclature.Import do
  use Mix.Task

  @shortdoc "Imports SAF-T nomenclatures from CSV files."
  def run(args) do
    # You might want to get tenant_id dynamically or pass it as an argument
    tenant_id = 1 # Assuming a default tenant_id for now

    Mix.shell().info("Importing NC8 TARIC codes for tenant #{tenant_id}...")
    case CyberCore.SAFT.Nomenclatures.import_nc8_taric_codes(tenant_id) do
      {:ok, msg} ->
        Mix.shell().info(msg)
      {:error, reason} ->
        Mix.shell().error("Error importing NC8 TARIC codes: #{inspect(reason)}")
    end

    # Other nomenclature imports can go here
  end
end
