defmodule CyberCore.IntrastatTest do
  use CyberCore.DataCase, async: true

  alias CyberCore.Intrastat
  alias CyberCore.Intrastat.IntrastatDeclaration
  alias Cyber.Fixtures

  setup do
    tenant = Fixtures.tenant_fixture()
    %{tenant: tenant}
  end

  describe "get_or_create_declaration/4" do
    test "creates a new declaration if one does not exist", %{tenant: tenant} do
      assert {:ok, %IntrastatDeclaration{id: declaration_id, year: 2025, month: 12, flow: "arrivals"}} =
               Intrastat.get_or_create_declaration(tenant.id, 2025, 12, "arrivals")

      declaration = Repo.get!(IntrastatDeclaration, declaration_id)
      assert declaration.year == 2025
      assert declaration.month == 12
      assert declaration.flow == "arrivals"
    end

    test "returns an existing declaration if one exists", %{tenant: tenant} do
      {:ok, declaration} = Intrastat.get_or_create_declaration(tenant.id, 2025, 12, "arrivals")
      {:ok, existing_declaration} = Intrastat.get_or_create_declaration(tenant.id, 2025, 12, "arrivals")
      assert declaration.id == existing_declaration.id
    end
  end

  describe "list_declaration_lines/1" do
    test "returns an empty list for a new declaration", %{tenant: tenant} do
      {:ok, declaration} = Intrastat.get_or_create_declaration(tenant.id, 2025, 12, "arrivals")
      assert Intrastat.list_declaration_lines(declaration.id) == []
    end
  end
end
