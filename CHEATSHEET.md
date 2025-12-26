# ⚡ Cyber ERP Cheatsheet

Бърз справочник с често използвани команди и patterns.

---

## 📦 База данни

### Миграции

```bash
# Създай нова миграция
mix ecto.gen.migration add_field_name_to_table

# Приложи всички чакащи миграции
mix ecto.migrate

# Rollback последната миграция
mix ecto.rollback

# Rollback N миграции
mix ecto.rollback -n 3

# Провери статус на миграциите
mix ecto.migrations

# Нулирай базата (drop, create, migrate)
mix ecto.reset

# Создай база
mix ecto.create

# Изтрий база
mix ecto.drop
```

### Seeding

```bash
# Run seed скрипт
mix run priv/repo/seeds.exs

# Seed в production
MIX_ENV=prod mix run priv/repo/seeds.exs
```

### Seed пример

```elixir
# priv/repo/seeds.exs
alias CyberCore.{Repo, Accounts}

# Създай tenant
{:ok, tenant} = Accounts.create_tenant(%{
  name: "Demo Company",
  vat_number: "BG123456789"
})

# Създай admin
{:ok, user} = Accounts.create_user(%{
  email: "admin@example.com",
  password: "password123",
  role: "admin"
})

# Свържи потребител с tenant
Accounts.add_user_to_tenant(user.id, tenant.id, role: "admin")
```

---

## 🔧 Разработка

### Старт и стоп

```bash
# Стартирай сървъра
mix phx.server

# Стартирай с debug logging
mix phx.server --log-level debug

# Interactive shell със сървър
iex -S mix phx.server

# Interactive shell
iex -S mix
```

### Компилация

```bash
# Компилирай проекта
mix compile

# Компилирай с warnings като errors
mix compile --warnings-as-errors

# Изчисти build artifacts
mix clean

# Format кода
mix format

# Format и компилирай
mix format && mix compile
```

### Code качество

```bash
# Credo linting
mix credo

# Credo със strict mode
mix credo --strict

# Credo само за променените файлове
mix credo git diff

# Dialyzer (анализ на типовете)
mix dialyzer
```

---

## 🧪 Тестове

### Run тестове

```bash
# Всички тестове
mix test

# Конкретен тестов файл
mix test test/cyber_core/accounting_test.exs

# Конкретен тест (ред)
mix test test/cyber_core/accounting_test.exs:42

# Само бавни тестове
mix test --only slow

# Изключи бавни тестове
mix test --exclude slow

# Тестове с trace
mix test --trace

# С покритие (coverage)
mix test --cover

# С HTML coverage
mix test --cover --cover-html
```

### Генериране на тестове

```bash
# Context с тестове
mix phx.gen.context Core Product products name:string

# LiveView CRUD с тестове
mix phx.gen.live Inventory Product products name:string

# JSON API с тестове
mix phx.gen.json Sales Invoice invoices invoice_no:string
```

---

## 🚀 Генериране на код

### Модули

```bash
# Контекст
mix phx.gen.context ContextName ModelName models field:type

# LiveView CRUD
mix phx.gen.live ContextName ModelName models field:type

# HTML CRUD
mix phx.gen.html ContextName ModelName models field:type

# JSON API
mix phx.gen.json ContextName ModelName models field:type

# Schema
mix phx.gen.schema ContextName ModelName models field:type
```

### Екземпляр

```bash
# Full CRUD LiveView
mix phx.gen.live Sales Invoice invoices \
  invoice_no:string \
  issue_date:date \
  total:decimal \
  status:string

# Context с модел
mix phx.gen.context Inventory Product products \
  name:string \
  sku:string \
  price:decimal \
  quantity:integer
```

---

## 🗄️ База данни - IEx Patterns

### Basic CRUD

```elixir
# Insert
{:ok, product} = %Product{}
  |> Ecto.Changeset.cast(%{name: "Лаптоп", price: 1999.99}, [:name, :price])
  |> Repo.insert()

# Get
product = Repo.get(Product, 1)

# Get by
product = Repo.get_by(Product, name: "Лаптоп")

# Update
{:ok, updated} = product
  |> Ecto.Changeset.cast(%{price: 1799.99}, [:price])
  |> Repo.update()

# Delete
{:ok, deleted} = Repo.delete(product)
```

### Query

```elixir
import Ecto.Query

# Всички записи
products = Repo.all(Product)

# С where клауза
products = Repo.all(from p in Product, where: p.price > 1000)

# С multiple conditions
products = Repo.all(from p in Product,
  where: p.price > 1000,
  where: p.category == "electronics",
  order_by: [desc: p.inserted_at],
  limit: 10
)

# С join
query = from i in Invoice,
  join: c in assoc(i, :contact),
  where: c.name == "Ivan Petrov",
  preload: [:contact]

invoices = Repo.all(query)

# С aggregate
count = Repo.aggregate(from(p in Product), :count, :id)
sum = Repo.aggregate(from(p in Product), :sum, :price)
```

### Транзакции

```elixir
# Проста транзакция
Repo.transaction(fn ->
  {:ok, invoice} = create_invoice(attrs)
  {:ok, payment} = record_payment(invoice)
  {:ok, journal} = create_journal_entry(invoice, payment)
  invoice
end)

# С rollback
Repo.transaction(fn ->
  case create_invoice(attrs) do
    {:ok, invoice} ->
      case record_payment(invoice) do
        {:ok, _} -> invoice
        {:error, reason} -> Repo.rollback(reason)
      end
    {:error, reason} ->
      Repo.rollback(reason)
  end
end)
```

---

## 🎨 LiveView Patterns

### Handle Events

```elixir
def handle_event("save", %{"product" => params}, socket) do
  case Inventory.create_product(params) do
    {:ok, product} ->
      {:noreply,
        socket
        |> put_flash(:info, "Продуктът е създаден!")
        |> push_navigate(to: ~p"/products/#{product}")
      }

    {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
  end
end

def handle_event("delete", %{"id" => id}, socket) do
  product = Inventory.get_product!(id)
  {:ok, _} = Inventory.delete_product(product)

  {:noreply,
    socket
    |> put_flash(:info, "Продуктът е изтрит!")
    |> assign(:products, list_products())
  }
end
```

### Handle Info

```elixir
def handle_info({:product_updated, product}, socket) do
  {:noreply, assign(socket, :product, product)}
end

# Subscribe в mount
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(CyberWeb.PubSub, "products")
  end

  {:ok, assign(socket, :products, list_products())}
end
```

---

## 🔄 GenServer Patterns

### Basic GenServer

```elixir
defmodule MyApp.Counter do
  use GenServer

  # Client API
  def start_link(initial_value \\ 0) do
    GenServer.start_link(__MODULE__, initial_value, name: __MODULE__)
  end

  def increment do
    GenServer.call(__MODULE__, :increment)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  # Server Callbacks
  @impl true
  def init(count) do
    {:ok, count}
  end

  @impl true
  def handle_call(:increment, _from, count) do
    {:reply, :ok, count + 1}
  end

  @impl true
  def handle_call(:get, _from, count) do
    {:reply, count, count}
  end
end
```

---

## 📊 Changeset Patterns

### Basic Changeset

```elixir
defmodule CyberCore.Inventory.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :price, :decimal
    field :quantity, :integer

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :price, :quantity])
    |> validate_required([:name, :price])
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end
end
```

### Custom Validations

```elixir
def changeset(product, attrs) do
  product
  |> cast(attrs, [:name, :price])
  |> validate_required([:name, :price])
  |> validate_price()
  |> validate_name()
end

defp validate_price(changeset) do
  price = get_field(changeset, :price)

  if price && Decimal.lt?(price, Decimal.new("0.01")) do
    add_error(changeset, :price, "цената трябва да е поне 0.01")
  else
    changeset
  end
end

defp validate_name(changeset) do
  name = get_field(changeset, :name)

  if name && String.length(name) < 3 do
    add_error(changeset, :name, "името трябва да е поне 3 символа")
  else
    changeset
  end
end
```

---

## 🔐 Auth Patterns

### Guardian Auth

```elixir
# Sign in
def sign_in(email, password) do
  with {:ok, user} <- get_user_by_email(email),
       true <- validate_password(user, password),
       {:ok, token, _claims} <- encode_and_sign(user) do
    {:ok, token, user}
  else
    _ -> {:error, :unauthorized}
  end
end

# Verify token
def verify_token(token) do
  case decode_and_verify(token) do
    {:ok, claims} -> {:ok, claims}
    {:error, reason} -> {:error, reason}
  end
end
```

### Plug Auth

```elixir
# Ensure authenticated
defmodule CyberWeb.Plugs.EnsureAuthenticated do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> put_flash(:error, "Моля, влезте в системата")
        |> redirect(to: ~p"/login")
        |> halt()

      user_id ->
        assign(conn, :current_user, get_user(user_id))
    end
  end
end
```

---

## 📈 Performance Tips

### Database

```elixir
# ❌ Лошо - N+1 queries
invoices = Repo.all(Invoice)
Enum.each(invoices, fn invoice ->
  lines = Repo.all(from l in InvoiceLine, where: l.invoice_id == ^invoice.id)
end)

# ✅ Добре - Preload
invoices = Repo.all(Invoice) |> Repo.preload(:invoice_lines)
```

```elixir
# ❌ Лошо - Multiple queries
products = Repo.all(Product)
electronics = Enum.filter(products, &(&1.category == "electronics"))

# ✅ Добре - Single query
electronics = Repo.all(from p in Product, where: p.category == "electronics")
```

### Cache

```elixir
# ETS Cache
:ets.new(:products_cache, [:named_table, :public, read_concurrency: true])

# Set
:ets.insert(:products_cache, {:all, products})

# Get
case :ets.lookup(:products_cache, :all) do
  [{:all, products}] -> products
  [] -> # Cache miss
end
```

---

## 🔍 Debugging

### IEx Debugging

```elixir
# Insert breakpoint
require IEx; IEx.pry()

# Debug function
:dbg.tracer()
:dbg.p(:all, :c)
:dbg.tp(MyModule, :my_function, :x)

# Stop debugging
:dbg.stop_clear()
```

### Logger

```elixir
require Logger

Logger.debug("Debug message: #{inspect(some_var)}")
Logger.info("Info message")
Logger.warning("Warning message")
Logger.error("Error message")
```

---

## 📦 Deployment

### Production Build

```bash
# Set env
export MIX_ENV=prod

# Get dependencies
mix deps.get --only prod

# Compile
mix compile

# Build assets
cd apps/cyber_web/assets
NODE_ENV=production npm run deploy
cd ../..
mix assets.deploy

# Create release
mix release

# Run release
_build/prod/rel/cyber_erp/bin/cyber_erp start
```

### Migrations в Production

```bash
MIX_ENV=prod mix ecto.migrate
```

---

## ⌨️ Keyboard Shortcuts (IEx)

| Команда | Описание |
|---------|----------|
| `Ctrl+C, Ctrl+A` | Abort |
| `Ctrl+C, Ctrl+C` | Exit |
| `Ctrl+G` | Job control |
| `h()` | Help |
| `c("file.ex")` | Compile file |
| `r(Module)` | Reload module |
| `v()` | Last value |
| `i(term)` | Info about term |

---

## 🎯 Common Snippets

### Проверка дали е число

```elixir
def is_number?(value) when is_number(value), do: true
def is_number?(value) when is_binary(value) do
  case Float.parse(value) do
    {_, ""} -> true
    _ -> false
  end
end
def is_number?(_), do: false
```

### Format пари

```elixir
def format_money(amount) do
  amount
  |> Decimal.round(2)
  |> Decimal.to_string()
end
```

### Генериране на slug

```elixir
def slugify(text) do
  text
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9\s-]/, "")
  |> String.replace(~r/[\s-]+/, "-")
  |> String.trim("-")
end
```

---

**Happy coding!** 🚀
