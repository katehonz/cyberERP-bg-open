/**
 * Tenant Selector Hook
 *
 * Записва избраната фирма в localStorage и прави reload на страницата.
 * Подход като rs-ac-bg-main за persistent storage.
 */

export const TenantSelector = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      const tenantId = e.target.value;

      // Запази в localStorage
      localStorage.setItem("currentTenantId", tenantId);

      // Reload страницата за да се приложи промяната
      window.location.reload();
    });
  }
};
