# User Roles and Permissions

This document outlines the user roles and permissions system in Cyber ERP.

## Roles

The system has four main roles:

- **superadmin**: System-level administrator with full access to all tenants and system settings. This role is intended for developers and system maintainers.
- **admin**: Tenant owner. An admin has full control over a specific tenant (company), including managing users and their permissions within that tenant.
- **user**: A standard user, such as an accountant. This role has permissions to perform daily tasks like creating invoices and managing products, but cannot perform destructive actions like deleting certain records or managing users.
- **observer**: A read-only user. This role is for users who need to view reports and data without being able to make any changes.

## Permissions

The permission system is granular and allows for fine-grained control over what users can do. Permissions are defined in the `seeds.exs` file and are tied to roles.

Each permission has a unique name, following a `module.action` convention (e.g., `invoices.create`).

### Adding New Permissions

To add a new permission:

1.  Open `apps/cyber_core/priv/repo/seeds.exs`.
2.  Add the new permission to the `permissions` list:

    ```elixir
    %{name: "warehouses.read", description: "Read warehouses"}
    ```

3.  Grant the permission to one or more roles:

    ```elixir
    Guardian.grant("admin", "warehouses.read")
    Guardian.grant("user", "warehouses.read")
    Guardian.grant("observer", "warehouses.read")
    ```

4.  Run the seeds to update the database:
    ```bash
    mix run apps/cyber_core/priv/repo/seeds.exs
    ```

## Protecting Routes

Routes are protected using the `CyberWeb.Plugs.Authorize` plug.

To protect a route:

1.  Open `apps/cyber_web/lib/cyber_web/router.ex`.
2.  Create a new pipeline for the permission check:

    ```elixir
    pipeline :require_warehouses_read do
      plug CyberWeb.Plugs.Authorize, "warehouses.read"
    end
    ```

3.  Apply this pipeline to the desired route. Remember to also use the `:api` pipeline to ensure the user is authenticated.

    ```elixir
    scope "/api", CyberWeb do
      pipe_through :api

      # ...

      get "/warehouses", WarehouseController, :index, pipe_through: [:api, :require_warehouses_read]
      # ...
    end
    ```

## Frontend Management

A user with the `superadmin` role can manage permissions for the `admin`, `user`, and `observer` roles from the frontend.

1.  Log in as a `superadmin`.
2.  Navigate to the "Система" (System) section in the sidebar.
3.  Click on "Права" (Permissions).

On this page, you can grant or revoke permissions for each role by checking or unchecking the corresponding checkboxes. The changes are saved automatically.
