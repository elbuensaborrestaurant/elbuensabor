const state = { token: sessionStorage.getItem("restaurant-token"), user: null, page: "inicio", categories: [], establishment: null, version: "" };
const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value = "") => String(value).replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);

async function api(path, options = {}) {
  const headers = new Headers(options.headers || {});
  headers.set("Accept", "application/json");
  if (state.token) headers.set("Authorization", `Bearer ${state.token}`);
  if (options.body) headers.set("Content-Type", "application/json");
  const response = await fetch(path, { ...options, headers });
  if (response.status === 204) return null;
  const envelope = await response.json();
  if (!response.ok || envelope.success === false) throw new Error(envelope.error?.message || `Respuesta HTTP ${response.status}.`);
  return envelope.data;
}

function notify(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("visible");
  setTimeout(() => toast.classList.remove("visible"), 2800);
}

function showLogin(message = "") {
  $("#app-screen").hidden = true;
  $("#login-screen").hidden = false;
  $("#login-message").textContent = message;
  $("#password").value = "";
}

function showWorkspace() {
  $("#login-screen").hidden = true;
  $("#app-screen").hidden = false;
  $("#user-name").textContent = `${state.user.nombre} ${state.user.apellido || ""}`.trim();
  $("#user-role").textContent = state.user.rol.nombre;
  visit(state.page);
}

async function refreshData() {
  const [categories, establishment, version] = await Promise.all([
    api("/api/v1/menu/categorias"),
    api("/api/v1/config/establecimiento"),
    api("/api/v1/version"),
  ]);
  state.categories = categories;
  state.establishment = establishment;
  state.version = version.version;
  $("#api-status").textContent = `API Restaurant · v${escapeHtml(state.version)}`;
}

async function visit(page) {
  state.page = page;
  document.querySelectorAll(".nav-link[data-page]").forEach((item) => item.classList.toggle("active", item.dataset.page === page));
  const titles = { inicio: "Centro de mando", categorias: "Catálogo de menú", establecimiento: "Datos del local" };
  $("#page-title").textContent = titles[page];
  $("#breadcrumb").textContent = titles[page].toLocaleUpperCase("es");
  $("#content").innerHTML = '<div class="empty-state">Cargando datos del restaurante…</div>';
  try {
    await refreshData();
    if (page === "inicio") renderHome();
    else if (page === "categorias") renderCategories();
    else renderEstablishment();
  } catch (error) {
    $("#api-status").textContent = "API desconectada";
    $("#content").innerHTML = `<section class="panel"><h2>No se pudo conectar al sistema</h2><p class="muted">${escapeHtml(error.message)}</p><button class="button secondary" id="retry">Reintentar</button></section>`;
    $("#retry").addEventListener("click", () => visit(page));
  }
}

function renderHome() {
  const restaurant = state.establishment;
  $("#content").innerHTML = `
    <section class="welcome"><div><p class="eyebrow">OPERACIÓN / VISIÓN GENERAL</p><h2>Bienvenido, ${escapeHtml(state.user.nombre)}</h2><p>Información en tiempo real de la API Restaurant.</p></div><span class="welcome-tag">${escapeHtml(restaurant.moneda)} · ${escapeHtml(restaurant.timezone)}</span></section>
    <section class="stat-grid">
      <article class="stat-card"><div class="stat-bar"></div><small>Menú disponible</small><strong>${state.categories.length}</strong><span>Categorías activas</span></article>
      <article class="stat-card"><div class="stat-bar"></div><small>Establecimiento</small><strong>${escapeHtml(restaurant.nombre)}</strong><span>Configuración conectada</span></article>
      <article class="stat-card"><div class="stat-bar"></div><small>Servicios del sistema</small><strong>Operativos</strong><span>API Restaurant v${escapeHtml(state.version)}</span></article>
    </section>
    <section class="panel"><div class="panel-heading"><div><p class="eyebrow">CARTA ACTUAL</p><h2>Categorías del menú</h2><p>Accede rápidamente a la organización de la carta.</p></div><button class="button secondary" data-go="categorias">Abrir catálogo ↗</button></div>
    ${state.categories.length ? `<div class="category-list">${state.categories.slice(0, 6).map((category) => `<article class="category-card"><div class="category-color">${escapeHtml(category.icono || "✦")}</div><div><strong>${escapeHtml(category.nombre)}</strong><p>${escapeHtml(category.descripcion || "Sin descripción registrada")}</p></div></article>`).join("")}</div>` : '<div class="empty-state">No hay categorías activas en el catálogo.</div>'}</section>`;
}

function renderCategories() {
  const body = state.categories.map((category) => `<tr><td><strong>${escapeHtml(category.nombre)}</strong></td><td>${escapeHtml(category.descripcion || "—")}</td><td>${Number(category.orden) || 0}</td><td><span class="status-badge">PUBLICADA</span></td><td class="table-actions"><button class="text-button" data-edit="${escapeHtml(category.id)}">Editar</button><button class="text-button danger" data-delete="${escapeHtml(category.id)}">Retirar</button></td></tr>`).join("");
  $("#content").innerHTML = `<section class="section-heading"><div><p class="eyebrow">MENÚ / ORGANIZACIÓN</p><h2>Administrar categorías</h2><p>Controla el orden y la disponibilidad de la carta.</p></div><button id="new-category" class="button primary">＋ Nueva categoría</button></section>
    <div class="table-wrap">${state.categories.length ? `<table><thead><tr><th>CATEGORÍA</th><th>DESCRIPCIÓN</th><th>ORDEN</th><th>ESTADO</th><th>ACCIONES</th></tr></thead><tbody>${body}</tbody></table>` : '<div class="empty-state">El menú está vacío. Agrega una categoría para comenzar.</div>'}</div>`;
  $("#new-category").addEventListener("click", () => openCategoryDialog());
  document.querySelectorAll("[data-edit]").forEach((button) => button.addEventListener("click", () => editCategory(button.dataset.edit)));
  document.querySelectorAll("[data-delete]").forEach((button) => button.addEventListener("click", () => deleteCategory(button.dataset.delete)));
}

function renderEstablishment() {
  const item = state.establishment;
  const details = [["Dirección", item.direccion], ["Teléfono", item.telefono], ["Correo electrónico", item.email], ["Moneda", item.moneda], ["Zona horaria", item.timezone], ["IVA", `${item.porcentaje_iva}%`], ["Mensaje de ticket", item.mensaje_ticket]];
  $("#content").innerHTML = `<section class="section-heading"><div><p class="eyebrow">CONFIGURACIÓN / LOCAL</p><h2>Información del restaurante</h2><p>Datos obtenidos desde la configuración de la API Restaurant.</p></div><span class="status-badge">CONSULTA</span></section>
    <div class="panel"><div class="panel-heading"><div><p class="eyebrow">IDENTIDAD COMERCIAL</p><h2>${escapeHtml(item.nombre)}</h2><p>${escapeHtml(item.slogan || "Establecimiento conectado")}</p></div></div><div class="info-grid">${details.map(([label, value]) => `<div class="info-item"><small>${escapeHtml(label)}</small><strong>${escapeHtml(value || "No especificado")}</strong></div>`).join("")}</div></div>`;
}

function openCategoryDialog(category = null) {
  const form = $("#category-form");
  form.reset();
  form.elements.id.value = category?.id || "";
  form.elements.nombre.value = category?.nombre || "";
  form.elements.descripcion.value = category?.descripcion || "";
  form.elements.color_hex.value = /^#[0-9a-f]{6}$/i.test(category?.color_hex || "") ? category.color_hex : "#bc8b45";
  form.elements.orden.value = category?.orden ?? 0;
  form.elements.icono.value = category?.icono || "";
  $("#dialog-title").textContent = category ? "Modificar categoría" : "Agregar categoría";
  $("#category-message").textContent = "";
  $("#category-dialog").showModal();
}

async function editCategory(id) {
  try {
    openCategoryDialog(await api(`/api/v1/menu/categorias/${encodeURIComponent(id)}`));
  } catch (error) {
    notify(error.message);
  }
}

async function deleteCategory(id) {
  const item = state.categories.find((category) => category.id === id);
  if (!confirm(`¿Retirar “${item?.nombre || "esta categoría"}” del menú?`)) return;
  try {
    await api(`/api/v1/menu/categorias/${encodeURIComponent(id)}`, { method: "DELETE" });
    notify("La categoría se retiró correctamente.");
    await visit("categorias");
  } catch (error) {
    notify(error.message);
  }
}

$("#login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = event.currentTarget.querySelector("button");
  button.disabled = true;
  $("#login-message").textContent = "";
  try {
    const session = await api("/api/v1/auth/login", { method: "POST", body: JSON.stringify({ username: $("#username").value, password: $("#password").value }) });
    state.token = session.token;
    sessionStorage.setItem("restaurant-token", state.token);
    state.user = session.usuario;
    $("#password").value = "";
    showWorkspace();
  } catch (error) {
    $("#login-message").textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

$("#category-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const id = form.elements.id.value;
  const payload = {
    nombre: form.elements.nombre.value.trim(),
    descripcion: form.elements.descripcion.value.trim() || null,
    color_hex: form.elements.color_hex.value,
    orden: Number(form.elements.orden.value),
    icono: form.elements.icono.value.trim() || null,
  };
  const button = form.querySelector('[type="submit"]');
  button.disabled = true;
  $("#category-message").textContent = "";
  try {
    await api(id ? `/api/v1/menu/categorias/${encodeURIComponent(id)}` : "/api/v1/menu/categorias", { method: id ? "PUT" : "POST", body: JSON.stringify(payload) });
    $("#category-dialog").close();
    notify(id ? "Los cambios se guardaron." : "Categoría creada.");
    await visit("categorias");
  } catch (error) {
    $("#category-message").textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

document.querySelectorAll(".nav-link[data-page]").forEach((button) => button.addEventListener("click", () => visit(button.dataset.page)));
$("#content").addEventListener("click", (event) => {
  const button = event.target.closest("[data-go]");
  if (button) visit(button.dataset.go);
});
$("#close-dialog").addEventListener("click", () => $("#category-dialog").close());
$("#cancel-dialog").addEventListener("click", () => $("#category-dialog").close());
$("#logout-button").addEventListener("click", async () => {
  try {
    await api("/api/v1/auth/logout", { method: "POST" });
  } catch (error) {
    notify(`No se pudo cerrar la sesión: ${error.message}`);
    return;
  }
  sessionStorage.removeItem("restaurant-token");
  state.token = null;
  state.user = null;
  showLogin("Sesión cerrada.");
});

if (state.token) {
  api("/api/v1/auth/me").then((user) => {
    state.user = user;
    showWorkspace();
  }).catch(() => {
    sessionStorage.removeItem("restaurant-token");
    state.token = null;
    showLogin("La sesión expiró; vuelve a ingresar.");
  });
}
