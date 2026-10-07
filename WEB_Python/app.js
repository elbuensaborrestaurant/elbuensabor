const state = { token: sessionStorage.getItem("restaurant-token"), user: null, page: "inicio", categories: [], establishment: null, apiVersion: "" };
const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value = "") => String(value).replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);

async function api(path, options = {}) {
  const headers = new Headers(options.headers || {});
  headers.set("Accept", "application/json");
  if (state.token) headers.set("Authorization", `Bearer ${state.token}`);
  if (options.body) headers.set("Content-Type", "application/json");
  const response = await fetch(path, { ...options, headers });
  if (response.status === 204) return null;
  const result = await response.json();
  if (!response.ok || result.success === false) throw new Error(result.error?.message || `La API respondió ${response.status}.`);
  return result.data;
}

function showLogin(message = "") {
  $("#app-screen").hidden = true;
  $("#login-screen").hidden = false;
  $("#login-message").textContent = message;
  $("#password").value = "";
}

function showApp() {
  $("#login-screen").hidden = true;
  $("#app-screen").hidden = false;
  $("#user-name").textContent = `${state.user.nombre} ${state.user.apellido || ""}`.trim();
  $("#user-role").textContent = state.user.rol.nombre;
  loadPage(state.page);
}

function notify(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("visible");
  window.setTimeout(() => toast.classList.remove("visible"), 2800);
}

async function loadOverview() {
  const [categories, establishment, version] = await Promise.all([
    api("/api/v1/menu/categorias"),
    api("/api/v1/config/establecimiento"),
    api("/api/v1/version"),
  ]);
  state.categories = categories;
  state.establishment = establishment;
  state.apiVersion = version.version;
  $("#api-status").textContent = `API conectada · v${escapeHtml(state.apiVersion)}`;
}

async function loadPage(page) {
  state.page = page;
  document.querySelectorAll(".nav-link[data-page]").forEach((item) => item.classList.toggle("active", item.dataset.page === page));
  const titles = { inicio: "Resumen", categorias: "Categorías del menú", establecimiento: "Establecimiento" };
  $("#page-title").textContent = titles[page];
  $("#content").innerHTML = '<div class="empty-state">Cargando información…</div>';
  try {
    await loadOverview();
    if (page === "inicio") renderHome();
    if (page === "categorias") renderCategories();
    if (page === "establecimiento") renderEstablishment();
  } catch (error) {
    $("#api-status").textContent = "Error de conexión";
    $("#content").innerHTML = `<div class="panel"><h2>No se pudo cargar la información</h2><p class="muted">${escapeHtml(error.message)}</p><button class="button secondary" id="retry">Reintentar</button></div>`;
    $("#retry").addEventListener("click", () => loadPage(page));
  }
}

function renderHome() {
  const restaurant = state.establishment;
  const activeCount = state.categories.length;
  $("#content").innerHTML = `
    <section class="welcome"><div><p class="eyebrow">PANEL DE ADMINISTRACIÓN</p><h2>Hola, ${escapeHtml(state.user.nombre)} 👋</h2><p>Consulta el estado general y administra el catálogo de tu restaurante.</p></div><span class="eyebrow pill">${escapeHtml(restaurant.moneda)} · ${escapeHtml(restaurant.timezone)}</span></section>
    <section class="stat-grid">
      <article class="stat-card"><div class="stat-icon">▦</div><strong>${activeCount}</strong><span>Categorías activas del menú</span></article>
      <article class="stat-card"><div class="stat-icon">◇</div><strong>${escapeHtml(restaurant.nombre)}</strong><span>Establecimiento conectado</span></article>
      <article class="stat-card"><div class="stat-icon">✓</div><strong>En línea</strong><span>API ${escapeHtml(state.apiVersion)} · conexión disponible</span></article>
    </section>
    <section class="panel"><div class="panel-heading"><div><h2>Menú del restaurante</h2><p>Categorías activas publicadas en el sistema</p></div><button class="button secondary" data-go="categorias">Administrar categorías</button></div>
    ${activeCount ? `<div class="category-list">${state.categories.slice(0, 6).map((category) => `<article class="category-card"><div class="category-color" style="background:${safeColor(category.color_hex)}">${escapeHtml(category.icono || "✦")}</div><div><strong>${escapeHtml(category.nombre)}</strong><p>${escapeHtml(category.descripcion || "Sin descripción")}</p></div></article>`).join("")}</div>` : '<div class="empty-state">Todavía no hay categorías activas.</div>'}</section>`;
}

function safeColor(value) {
  return /^#[0-9a-f]{6}$/i.test(value || "") ? `${value}22` : "#e9efe6";
}

function renderCategories() {
  const rows = state.categories.map((category) => `<tr><td><strong>${escapeHtml(category.nombre)}</strong></td><td>${escapeHtml(category.descripcion || "—")}</td><td>${Number(category.orden) || 0}</td><td><span class="status-badge">Activa</span></td><td class="table-actions"><button class="text-button" data-edit="${escapeHtml(category.id)}">Editar</button><button class="text-button danger" data-delete="${escapeHtml(category.id)}">Eliminar</button></td></tr>`).join("");
  $("#content").innerHTML = `<section class="section-heading"><div><p class="eyebrow">CATÁLOGO</p><h2>Organiza la carta</h2><p>Consulta, crea, edita o retira categorías del menú.</p></div><button id="new-category" class="button primary">＋ Nueva categoría</button></section>
    <div class="table-wrap">${state.categories.length ? `<table><thead><tr><th>NOMBRE</th><th>DESCRIPCIÓN</th><th>ORDEN</th><th>ESTADO</th><th>ACCIONES</th></tr></thead><tbody>${rows}</tbody></table>` : '<div class="empty-state">No hay categorías activas. Crea la primera para empezar.</div>'}</div>`;
  $("#new-category").addEventListener("click", () => openCategoryDialog());
  document.querySelectorAll("[data-edit]").forEach((button) => button.addEventListener("click", () => editCategory(button.dataset.edit)));
  document.querySelectorAll("[data-delete]").forEach((button) => button.addEventListener("click", () => deleteCategory(button.dataset.delete)));
}

function renderEstablishment() {
  const item = state.establishment;
  const details = [
    ["Nombre", item.nombre], ["Dirección", item.direccion], ["Teléfono", item.telefono],
    ["Correo electrónico", item.email], ["Moneda", item.moneda], ["Zona horaria", item.timezone],
    ["Impuesto (IVA)", `${item.porcentaje_iva}%`], ["Mensaje en ticket", item.mensaje_ticket],
  ];
  $("#content").innerHTML = `<section class="section-heading"><div><p class="eyebrow">CONFIGURACIÓN</p><h2>Datos del establecimiento</h2><p>Información consultada desde la configuración de la API.</p></div><span class="status-badge">Solo lectura</span></section>
    <div class="panel"><div class="panel-heading"><div><h2>${escapeHtml(item.nombre)}</h2><p>${escapeHtml(item.slogan || "Información general del restaurante")}</p></div></div><div class="info-grid">${details.map(([label, value]) => `<div class="info-item"><small>${escapeHtml(label)}</small><strong>${escapeHtml(value || "No especificado")}</strong></div>`).join("")}</div></div>`;
}

function openCategoryDialog(category = null) {
  const form = $("#category-form");
  form.reset();
  form.elements.id.value = category?.id || "";
  form.elements.nombre.value = category?.nombre || "";
  form.elements.descripcion.value = category?.descripcion || "";
  form.elements.color_hex.value = /^#[0-9a-f]{6}$/i.test(category?.color_hex || "") ? category.color_hex : "#507a52";
  form.elements.orden.value = category?.orden ?? 0;
  form.elements.icono.value = category?.icono || "";
  $("#dialog-title").textContent = category ? "Editar categoría" : "Nueva categoría";
  $("#category-message").textContent = "";
  $("#category-dialog").showModal();
}

async function editCategory(id) {
  try {
    const category = await api(`/api/v1/menu/categorias/${encodeURIComponent(id)}`);
    openCategoryDialog(category);
  } catch (error) {
    notify(error.message);
  }
}

async function deleteCategory(id) {
  const category = state.categories.find((item) => item.id === id);
  if (!window.confirm(`¿Retirar la categoría “${category?.nombre || "seleccionada"}” del menú?`)) return;
  try {
    await api(`/api/v1/menu/categorias/${encodeURIComponent(id)}`, { method: "DELETE" });
    notify("Categoría retirada correctamente.");
    await loadPage("categorias");
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
    showApp();
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
    notify(id ? "Categoría actualizada." : "Categoría creada.");
    await loadPage("categorias");
  } catch (error) {
    $("#category-message").textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

document.querySelectorAll(".nav-link[data-page]").forEach((button) => button.addEventListener("click", () => loadPage(button.dataset.page)));
$("#content").addEventListener("click", (event) => {
  const button = event.target.closest("[data-go]");
  if (button) loadPage(button.dataset.go);
});
$("#close-dialog").addEventListener("click", () => $("#category-dialog").close());
$("#cancel-dialog").addEventListener("click", () => $("#category-dialog").close());
$("#logout-button").addEventListener("click", async () => {
  try {
    await api("/api/v1/auth/logout", { method: "POST" });
  } catch (error) {
    notify(`No se pudo cerrar la sesión en el servidor: ${error.message}`);
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
    showApp();
  }).catch(() => {
    sessionStorage.removeItem("restaurant-token");
    state.token = null;
    showLogin("Tu sesión venció. Inicia sesión de nuevo.");
  });
}
