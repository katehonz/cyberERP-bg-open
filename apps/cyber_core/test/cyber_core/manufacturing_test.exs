defmodule CyberCore.ManufacturingTest do
  use CyberCore.DataCase

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Inventory
  alias CyberCore.Manufacturing
  alias CyberCore.Repo
  alias Decimal, as: D

  describe "recipes" do
    test "create_recipe_with_items/2 creates recipe and items" do
      tenant = insert_tenant()
      product = insert_product(tenant, "Готов продукт")
      material = insert_product(tenant, "Суровина")

      attrs = %{
        tenant_id: tenant.id,
        code: "REC-#{System.unique_integer([:positive])}",
        name: "Тестова рецепта",
        output_product_id: product.id,
        output_quantity: "10",
        unit: "кг"
      }

      lines = [
        %{
          line_no: 1,
          product_id: material.id,
          description: material.name,
          quantity: "2.5",
          unit: "кг",
          wastage_percent: "3"
        }
      ]

      {:ok, recipe} = Manufacturing.create_recipe_with_items(attrs, lines)
      recipe = Repo.preload(recipe, :recipe_items)
      assert recipe.code =~ "REC"
      assert length(recipe.recipe_items) == 1

      [item] = recipe.recipe_items
      assert item.product_id == material.id
      assert D.eq?(item.quantity, D.new("2.5"))
    end

    test "update_recipe_with_items/3 replaces ingredients" do
      tenant = insert_tenant()
      product = insert_product(tenant, "Готов продукт")
      material1 = insert_product(tenant, "Материал 1")
      material2 = insert_product(tenant, "Материал 2")

      {:ok, recipe} =
        Manufacturing.create_recipe_with_items(
          %{
            tenant_id: tenant.id,
            code: "REC-#{System.unique_integer([:positive])}",
            name: "Първа рецепта",
            output_product_id: product.id,
            output_quantity: "5",
            unit: "бр."
          },
          [
            %{
              line_no: 1,
              product_id: material1.id,
              description: material1.name,
              quantity: "1",
              unit: "бр."
            }
          ]
        )

      recipe = Repo.preload(recipe, :recipe_items)

      {:ok, updated} =
        Manufacturing.update_recipe_with_items(recipe, %{name: "Актуализирана"}, [
          %{
            line_no: 1,
            product_id: material2.id,
            description: material2.name,
            quantity: "3",
            unit: "бр."
          }
        ])

      [item] = updated.recipe_items
      assert item.product_id == material2.id
      assert updated.name == "Актуализирана"
    end
  end

  defp insert_tenant do
    %Tenant{}
    |> Tenant.changeset(%{
      name: "Производство",
      slug: "tenant-#{System.unique_integer([:positive])}"
    })
    |> Repo.insert!()
  end

  defp insert_product(tenant, name) do
    category = if name == "Готов продукт", do: "produced", else: "materials"

    {:ok, product} =
      Inventory.create_product(%{
        tenant_id: tenant.id,
        name: name,
        sku: "SKU-#{System.unique_integer([:positive])}",
        category: category,
        unit: "бр.",
        price: D.new("5.00")
      })

    product
  end
end

