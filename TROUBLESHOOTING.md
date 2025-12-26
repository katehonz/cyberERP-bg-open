# 🔧 Ръководство за отстраняване на проблеми

Това ръководство съдържа решения за често срещани проблеми при работа с Cyber ERP.

---

## 📋 Съдържание

- [Инсталация и Setup](#инсталация-и-setup)
- [База данни](#база-данни)
- [Стартиране на сървъра](#стартиране-на-сървъра)
- [Frontend проблеми](#frontend-проблеми)
- [Тестове](#тестове)
- [Deployment](#deployment)
- [Производителност](#производителност)

---

## 📦 Инсталация и Setup

### ❌ Грешка: `mix deps.get` се проваля

#### Симптом
```
Could not find dependency...
```

#### Решения

**1. Изчисти кеша на dependencies:**
```bash
mix deps.clean --all
mix deps.get
```

**2. Използвай локалния hex:**
```bash
mix local.hex --force
mix local.rebar --force
mix deps.get
```

**3. Провери Elixir версията:**
```bash
elixir --version
# Трябва да е 1.16+
```

### ❌ Грешка: `npm install` се проваля

#### Симптом
```bash
cd apps/cyber_web/assets && npm install
npm ERR! ...
```

#### Решения

**1. Изчисти node_modules:**
```bash
cd apps/cyber_web/assets
rm -rf node_modules package-lock.json
npm install
```

**2. Използвай npm cache clean:**
```bash
npm cache clean --force
npm install
```

**3. Провери Node.js версията:**
```bash
node --version
# Трябва да е 18+
```

---

## 🗄️ База данни

### ❌ Грешка: Database connection refused

#### Симптом
```
Postgrex.Error - connection refused
```

#### Решения

**1. Провери дали PostgreSQL работи:**
```bash
sudo systemctl status postgresql
```

**2. Рестартирай PostgreSQL:**
```bash
sudo systemctl restart postgresql
```

**3. Провери config:**
```elixir
# config/dev.exs
config :cyber_core, CyberCore.Repo,
  username: "postgres",
  password: "postgres",  # Провери паролата
  hostname: "localhost",
  database: "cyber_erp_dev"
```

**4. Ако използваш docker postgres:**
```bash
docker ps | grep postgres
docker logs <container-id>
```

### ❌ Грешка: Database does not exist

#### Симптом
```
FATAL: database "cyber_erp_dev" does not exist
```

#### Решение
```bash
mix ecto.create
```

Ако се провали:
```bash
psql -U postgres
CREATE DATABASE cyber_erp_dev;
CREATE DATABASE cyber_erp_test;
\q
```

### ❌ Грешка: Migration already applied

#### Симптом
```
ERROR: relation "some_table" already exists
```

#### Решения

**1. Провери статуса на миграциите:**
```bash
mix ecto.migrations
```

**2. Нулирай базата:**
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

**3. Или rollback и migrate отново:**
```bash
mix ecto.rollback -n 1
mix ecto.migrate
```

### ❌ Грешка: Unique constraint violation

#### Симптом
```
Ecto.ConstraintError - constraint error when inserting
```

#### Решения

**1. Провери дали записът вече съществува:**
```elixir
CyberCore.Accounts.get_user_by_email("test@example.com")
```

**2. Изтрий дубликатите:**
```elixir
CyberCore.Repo.delete_all(
  from u in CyberCore.Accounts.User,
  where: u.email == "test@example.com"
)
```

**3. Или промени уникалния constraint:**
```elixir
# В changeset-а
unique_constraint([:tenant_id, :email])
```

---

## 🚀 Стартиране на сървъра

### ❌ Грешка: Port 4000 already in use

#### Симптом
```
http_port 4000 is already in use
```

#### Решения

**1. Намери и убий процеса:**
```bash
lsof -ti:4000 | xargs kill -9
```

**2. Или стартирай на друг порт:**
```bash
PORT=4001 mix phx.server
```

**3. Или промени config/dev.exs:**
```elixir
config :cyber_web, CyberWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001]
```

### ❌ Грешка: Compilation error

#### Симптом
```
== Compilation error ==
** (CompileError) ...
```

#### Решения

**1. Изчисти build artifacts:**
```bash
mix clean
mix compile
```

**2. Изчисти dependencies:**
```bash
rm -rf deps _build
mix deps.get
mix compile
```

**3. Провери за syntax errors:**
```bash
mix compile --verbose
```

**4. Провери за недостигащи dependencies:**
```bash
mix deps.check
mix deps.get
```

### ❌ Грешка: LiveView connection lost

#### Симптом
```
LiveView socket disconnected
```

#### Решения

**1. Провери logs:**
```bash
tail -f _build/dev/log/cyber_web.log
```

**2. Рестартирай сървъра:**
```bash
# Ctrl+C и отново
mix phx.server
```

**3. Провери phoenix_live_view зависимостта:**
```bash
grep phoenix_live_view mix.exs
```

---

## 🎨 Frontend проблеми

### ❌ Грешка: Assets not compiling

#### Симптом
```
Failed to compile "./assets/js/app.js"
```

#### Решения

**1. Рекомпилирай assets:**
```bash
cd apps/cyber_web
mix assets.deploy
cd ..
```

**2. Или използвай watcher:**
```bash
cd apps/cyber_web/assets
npm run dev
```

**3. Провери package.json:**
```bash
cd apps/cyber_web/assets
cat package.json
```

### ❌ Грешка: Tailwind classes not working

#### Симптом
Tailwind класовете не се прилагат в браузъра.

#### Решения

**1. Провери assets/css/app.css:**
```css
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";
```

**2. Рекомпилирай tailwind:**
```bash
cd apps/cyber_web/assets
npx tailwindcss -i ./css/app.css -o ../priv/static/assets/app.css
```

**3. Провери tailwind.config.js:**
```javascript
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/cyber_web/**/*.ex'
  ],
  // ...
}
```

---

## 🧪 Тестове

### ❌ Грешка: Tests failing due to database state

#### Симптом
```
** (Ecto.ConstraintError) ...
```

#### Решения

**1. Използвай sandbox:**
```elixir
# test/support/data_case.ex
use ExUnit.Case
use Ecto.SQL.Sandbox, mode: :manual

setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(CyberCore.Repo)
end
```

**2. Рестартирай test базата:**
```bash
MIX_ENV=test mix ecto.reset
```

**3. Изчисти sandbox след всеки тест:**
```elixir
setup tags do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(CyberCore.Repo)

  unless tags[:async] do
    Ecto.Adapters.SQL.Sandbox.mode(CyberCore.Repo, {:shared, self()})
  end

  :ok
end
```

### ❌ Грешка: Tests are slow

#### Симптом
Тестовете отнемат твърде много време.

#### Решения

**1. Използвай async тестване:**
```elixir
@tag :async
test "something" do
  # ...
end
```

**2. Избягвай database операции в setup:**
```elixir
# Вместо:
setup do
  Factory.insert(:product)
end

# Използвай:
test "something" do
  product = Factory.insert(:product)
  # ...
end
```

**3. Използвай factories вместо manual inserts:**
```elixir
# test/support/factory.ex
def product_factory do
  %CyberCore.Inventory.Product{
    name: sequence(:name, &"Product #{&1}"),
    price: Decimal.new("100.00"),
    tenant_id: 1
  }
end
```

---

## 🚢 Deployment

### ❌ Грешка: Production build fails

#### Симптом
```
** (Mix.Error) ...
```

#### Решения

**1. Изчисти всичко:**
```bash
MIX_ENV=prod mix clean
MIX_ENV=prod mix deps.clean --all
MIX_ENV=prod mix deps.get
```

**2. Compile в prod mode:**
```bash
export MIX_ENV=prod
mix compile
```

**3. Build assets:**
```bash
cd apps/cyber_web/assets
NODE_ENV=production npm run deploy
cd ../..
mix assets.deploy
```

### ❌ Грешка: Database migrations in production

#### Симптом
```
RuntimeError - database is not yet migrated
```

#### Решение
```bash
MIX_ENV=prod mix ecto.migrate
```

### ❌ Грешка: SSL certificate error

#### Симптом
```
:certifi - ssl certificate error
```

#### Решения

**1. Изчисти Certifi cache:**
```bash
mix hex.info certifi
# Или реинсталирай certifi
```

**2. Провери SSL в prod.exs:**
```elixir
config :cyber_web, CyberWeb.Endpoint,
  url: [host: "yourdomain.com", port: 443],
  https: [
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]
```

---

## ⚡ Производителност

### ❌ Проблем: Бавни database queries

#### Симптом
SQL queries отнемат твърде дълго.

#### Решения

**1. Добави индекси:**
```elixir
# В миграция
create index(:invoices, [:tenant_id, :invoice_no])
create index(:invoices, [:tenant_id, :issue_date])
```

**2. Използвай preload:**
```elixir
# Вместо:
invoice = Repo.get(Invoice, id)
lines = Repo.all(from l in InvoiceLine, where: l.invoice_id == ^id)

# Използвай:
invoice = Repo.get(Invoice, id) |> Repo.preload(:invoice_lines)
```

**3. Избягвай N+1 queries:**
```elixir
# ❌ Лошо
invoices = Repo.all(Invoice)
Enum.each(invoices, fn invoice ->
  Repo.get(Contact, invoice.contact_id)  # N+1 queries!
end)

# ✅ Добре
invoices =
  Invoice
  |> Repo.all()
  |> Repo.preload(:contact)
```

### ❌ Проблем: Memory leaks

#### Симптом
Приложението консумира все повече памет.

#### Решения

**1. Провери за ненужни процеси:**
```bash
# В IEx
:erlang.system_info(:process_count)
:recon.proc_count(10)
```

**2. Избягвай глобални променливи:**
```elixir
# ❌ Лошо
defmodule MyApp.Global do
  use Agent
  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  # ...
end

# ✅ Добре - използвайETS cache
defmodule MyApp.Cache do
  use GenServer
  # ...
end
```

**3. Ограничи размера на кеша:**
```elixir
# ЗаETS cache
:ets.new(:my_cache, [:named_table, :public, read_concurrency: true, max_size: 1000])
```

---

## 📞 Други проблеми

### Проблем: Не мога да вляза в системата

#### Решения

**1. Провери дали съществува потребител:**
```elixir
iex -S mix
> CyberCore.Accounts.get_user_by_email("admin@example.com")
```

**2. Създай нов admin:**
```elixir
# В iex
CyberCore.Accounts.create_user(%{
  email: "admin@example.com",
  password: "password123",
  role: "admin"
})
```

**3. Провери auth log:**
```bash
tail -f _build/dev/log/cyber_web.log | grep -i auth
```

### Проблем: Real-time updates не работят

#### Решения

**1. Провери PubSub:**
```elixir
# config/config.exs
config :cyber_web, CyberWeb.Endpoint,
  pubsub_server: CyberWeb.PubSub
```

**2. Провери channels:**
```elixir
# apps/cyber_web/lib/cyber_web/channels/user_socket.ex
defmodule CyberWeb.UserSocket do
  use Phoenix.Socket

  channel "users:*", CyberWeb.UserChannel
  # ...
end
```

**3. Провери LiveView subscribe:**
```elixir
handle_info({:invoice_updated, invoice}, socket) do
  {:noreply, assign(socket, :invoice, invoice)}
end
```

---

## 🔍 Debug Tips

### Използвай IEx за debug

```elixir
# Стартирай IEx с приложение
iex -S mix

# Debug mode
IEx.pry

# Trace изпълнението
: dbg.tracer()
:dbg.p(:all, :c)
:dbg.tp(MyModule, :my_function, :x)
```

### Log queries

```elixir
# config/dev.exs
config :cyber_core, CyberCore.Repo,
  loggers: [Ecto.LogEntry]  # или [Ecto.LogJSONEntry]
```

### Monitor процеси

```bash
# В IEx
:observer.start()
# Това стартира GUI monitor
```

---

## 💡 Добри практики

1. **Винаги четете error messages** - те съдържат полезна информация
2. **Проверявайте logs** - `_build/dev/log/cyber_web.log`
3. **Използвайте Git** - rollback-вайте ако нещо се счупи
4. **Тествайте локално** - преди deployment
5. **Backup базата** - преди големи промени

---

## 📚 Допълнителни ресурси

- [Elixir Troubleshooting](https://elixir-lang.org/getting-started/debugging.html)
- [Phoenix Debugging](https://hexdocs.pm/phoenix/debugging.html)
- [Ecto Troubleshooting](https://hexdocs.pm/ecto/Ecto.html#module-debugging)
- [Erlang Debug Tools](https://erlang.org/doc/apps/debugger/debugger_chapter.html)

---

Ако проблемът не е тук, моля отворете [GitHub issue](https://github.com/...) с подробности.

---

**Happy coding!** 🚀
