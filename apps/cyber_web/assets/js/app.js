// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Alpine.js for lightweight interactivity
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()

// Import hooks
import { TenantSelector } from "./hooks/tenant_selector"

// LiveView Hooks for React integration
let Hooks = {}
Hooks.TenantSelector = TenantSelector

// React Chart Hook - for dashboard charts
Hooks.ReactChart = {
  mounted() {
    // Will be populated when we add React components
    this.el.innerHTML = '<div class="text-gray-500">Chart component will be loaded here</div>'
  }
}

// React Table Hook - for complex data tables
Hooks.ReactTable = {
  mounted() {
    this.el.innerHTML = '<div class="text-gray-500">Table component will be loaded here</div>'
  }
}

Hooks.PdfDownloader = {
  mounted() {
    this.handleEvent("download-pdf", ({data, filename}) => {
      const byteCharacters = atob(data);
      const byteNumbers = new Array(byteCharacters.length);
      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], {type: 'application/pdf'});

      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    });
  }
}

// Download hook for SAF-T XML files and other downloads
Hooks.Download = {
  mounted() {
    this.handleEvent("download", ({content, filename, content_type, base64}) => {
      let blob;
      if (base64) {
        // Decode base64 content
        const decodedContent = atob(content);
        blob = new Blob([decodedContent], {type: content_type || 'application/xml'});
      } else {
        // Plain text content (UTF-8)
        blob = new Blob([content], {type: content_type || 'application/xml; charset=utf-8'});
      }
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(link.href);
    });
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => {
    // Чете tenant_id от localStorage и го изпраща към сървъра
    const tenantId = localStorage.getItem("currentTenantId")
    return {
      _csrf_token: csrfToken,
      tenant_id: tenantId
    }
  },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle set-active-tenant event from Settings page
window.addEventListener("phx:set-active-tenant", (e) => {
  const tenantId = e.detail.tenant_id
  localStorage.setItem("currentTenantId", tenantId)
  window.location.reload()
})

// Global download event handler for XML and other files
window.addEventListener("phx:download", (e) => {
  const {content, filename, content_type, base64} = e.detail;
  let blob;
  if (base64) {
    const decodedContent = atob(content);
    blob = new Blob([decodedContent], {type: content_type || 'application/xml'});
  } else {
    blob = new Blob([content], {type: content_type || 'application/xml; charset=utf-8'});
  }
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(link.href);
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
