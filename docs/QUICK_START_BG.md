# Бърз старт - Cyber ERP

## Инсталация

### Изисквания

```bash
# Elixir & Erlang
asdf install elixir 1.16.3
asdf install erlang 26.2.5

# PostgreSQL
sudo apt install postgresql-14

# Node.js (за assets)
asdf install nodejs 20.12.0
```

### Първоначално настройване

```bash
# Клониране на проекта
cd /home/dvg/z-nim-proloq/cyber_ERP/cyber_erp

# Инсталиране на зависимости
mix deps.get

# Създаване на база данни
mix ecto.create

# Прилагане на миграции
mix ecto.migrate

# (Опционално) Seed с примерни данни
mix run priv/repo/seeds.exs

# Инсталиране на Node пакети
cd apps/cyber_web/assets && npm install && cd ../../..

# Стартиране на сървъра
mix phx.server
```

Отвори: **http://localhost:4000**

## Команди

### База данни

```bash
# Създаване на миграция
mix ecto.gen.migration add_new_table

# Прилагане на миграции
mix ecto.migrate

# Rollback последна миграция
mix ecto.rollback

# Rollback N миграции
mix ecto.rollback -n 3

# Reset на базата (drop, create, migrate)
mix ecto.reset

# Проверка на статус на миграциите
mix ecto.migrations
```

### Генериране на код

```bash
# Генериране на контекст
mix phx.gen.context Inventory Product products \
  name:string sku:string price:decimal quantity:integer

# Генериране на LiveView CRUD
mix phx.gen.live Inventory Product products \
  name:string sku:string price:decimal

# Генериране на JSON API
mix phx.gen.json Sales Invoice invoices \
  invoice_no:string issue_date:date total:decimal
```

### Тестване

```bash
# Всички тестове
mix test

# Конкретен файл
mix test test/cyber_core/inventory_test.exs

# Конкретен тест
mix test test/cyber_core/inventory_test.exs:15

# С покритие
mix test --cover

# С trace за по-детайлни съобщения
mix test --trace
```

### Разработка

```bash
# Интерактивна конзола
iex -S mix

# С Phoenix сървър
iex -S mix phx.server

# Компилиране
mix compile

# Форматиране на код
mix format

# Проверка на код качество
mix credo

# Проверка на зависимости
mix deps.unlock --check-unused
```

## Работа с IEx (Interactive Elixir)

```elixir
# Стартирай IEx
iex -S mix

# Зареди модул
alias CyberCore.{Repo, Inventory}
alias CyberCore.Inventory.Product

# Създай запис
{:ok, product} = Inventory.create_product(%{
  tenant_id: 1,
  name: "Лаптоп",
  sku: "LAP001",
  price: Decimal.new("1999.99"),
  category: "electronics"
})

# Извличане
products = Inventory.list_products(1)
product = Inventory.get_product!(1, product.id)

# Обновяване
{:ok, updated} = Inventory.update_product(product, %{price: Decimal.new("1899.99")})

# Изтриване
{:ok, _deleted} = Inventory.delete_product(product)

# Ecto заявки
import Ecto.Query

# Проста заявка
Repo.all(from p in Product, where: p.tenant_id == 1)

# Сложна заявка
query = from p in Product,
  where: p.tenant_id == 1,
  where: p.category == "electronics",
  order_by: [desc: p.inserted_at],
  limit: 10

Repo.all(query)

# Reload на модули при промени
r CyberCore.Inventory
```

## Структура на нов модул

### 1. Създаване на schema

```elixir
# apps/cyber_core/lib/cyber_core/inventory/category.ex
defmodule CyberCore.Inventory.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :tenant_id, :integer
    field :name, :string
    field :description, :string
    field :parent_id, :integer

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:tenant_id, :name, :description, :parent_id])
    |> validate_required([:tenant_id, :name])
    |> unique_constraint([:tenant_id, :name])
  end
end
```

### 2. Добавяне към контекст

```elixir
# apps/cyber_core/lib/cyber_core/inventory.ex
defmodule CyberCore.Inventory do
  alias CyberCore.Inventory.Category

  def list_categories(tenant_id) do
    Repo.all(from c in Category, where: c.tenant_id == ^tenant_id)
  end

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end
end
```

### 3. Създаване на миграция

```bash
mix ecto.gen.migration create_categories
```

```elixir
# priv/repo/migrations/20241011_create_categories.exs
defmodule CyberCore.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :tenant_id, :integer, null: false
      add :name, :string, null: false
      add :description, :text
      add :parent_id, references(:categories, on_delete: :nilify_all)

      timestamps()
    end

    create index(:categories, [:tenant_id])
    create unique_index(:categories, [:tenant_id, :name])
  end
end
```

### 4. API контролер

```elixir
# apps/cyber_web/lib/cyber_web/controllers/category_controller.ex
defmodule CyberWeb.CategoryController do
  use CyberWeb, :controller

  alias CyberCore.Inventory

  def index(conn, _params) do
    tenant_id = conn.assigns.current_tenant.id
    categories = Inventory.list_categories(tenant_id)
    render(conn, "index.json", categories: categories)
  end

  def create(conn, %{"category" => category_params}) do
    tenant_id = conn.assigns.current_tenant.id
    attrs = Map.put(category_params, "tenant_id", tenant_id)

    case Inventory.create_category(attrs) do
      {:ok, category} ->
        conn
        |> put_status(:created)
        |> render("show.json", category: category)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end
end
```

## Често използвани patterns

### Pattern 1: Транзакция с множество операции

```elixir
def create_invoice_with_lines(invoice_attrs, lines_attrs) do
  Repo.transaction(fn ->
    with {:ok, invoice} <- create_invoice(invoice_attrs),
         {:ok, _lines} <- create_lines(invoice, lines_attrs),
         {:ok, _} <- update_stock(invoice) do
      Repo.preload(invoice, :invoice_lines)
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end)
end
```

### Pattern 2: Динамични филтри

```elixir
def list_products(tenant_id, opts \\ []) do
  base_query = from p in Product, where: p.tenant_id == ^tenant_id

  base_query
  |> apply_filters(opts)
  |> Repo.all()
end

defp apply_filters(query, opts) do
  Enum.reduce(opts, query, fn
    {:category, category}, q when category != nil ->
      from p in q, where: p.category == ^category

    {:search, term}, q when is_binary(term) and term != "" ->
      pattern = "%#{term}%"
      from p in q, where: ilike(p.name, ^pattern)

    _, q ->
      q
  end)
end
```

### Pattern 3: Изчисления в changeset

```elixir
def changeset(line, attrs) do
  line
  |> cast(attrs, [:quantity, :unit_price, :tax_rate])
  |> validate_required([:quantity, :unit_price])
  |> calculate_totals()
end

defp calculate_totals(changeset) do
  qty = get_field(changeset, :quantity)
  price = get_field(changeset, :unit_price)
  tax_rate = get_field(changeset, :tax_rate) || Decimal.new("20")

  if qty && price do
    subtotal = Decimal.mult(qty, price)
    tax = Decimal.mult(subtotal, Decimal.div(tax_rate, 100))
    total = Decimal.add(subtotal, tax)

    changeset
    |> put_change(:subtotal, subtotal)
    |> put_change(:tax_amount, tax)
    |> put_change(:total_amount, total)
  else
    changeset
  end
end
```

## Полезни ресурси

- [Phoenix Docs](https://hexdocs.pm/phoenix)
- [Ecto Docs](https://hexdocs.pm/ecto)
- [Elixir School](https://elixirschool.com/bg)
- [Elixir Forum](https://elixirforum.com)

## Troubleshooting

### База данни не може да се създаде

```bash
# Проверка дали PostgreSQL работи
sudo systemctl status postgresql

# Рестарт
sudo systemctl restart postgresql

# Ръчно създаване
psql -U postgres
CREATE DATABASE cyber_erp_dev;
```

### Port 4000 е зает

```bash
# Намери процес
lsof -i :4000

# Убий процес
kill -9 <PID>

# Или стартирай на друг порт
PORT=4001 mix phx.server
```

### Компилационни грешки

```bash
# Изчисти build artifacts
mix clean

# Изчисти зависимости
rm -rf deps _build

# Инсталирай отново
mix deps.get
mix compile
```
