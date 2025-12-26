defmodule CyberCore.Vat do
  @moduledoc """
  This module provides functions for generating Bulgarian VAT declaration files.
  """

  alias CyberCore.Vat.Generator

  def generate_vat_declaration(tenant_id, year, month) do
    prodagbi_content = Generator.generate_prodagbi_txt(tenant_id, year, month)
    pokupki_content = Generator.generate_pokupki_txt(tenant_id, year, month)

    deklar_content =
      CyberCore.Vat.Deklar.generate_deklar_txt(
        tenant_id,
        year,
        month,
        prodagbi_content,
        pokupki_content
      )

    %{
      "PRODAGBI.TXT" => prodagbi_content,
      "POKUPKI.TXT" => pokupki_content,
      "DEKLAR.TXT" => deklar_content
    }
  end
end
