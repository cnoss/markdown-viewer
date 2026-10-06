// Wird von Swift per callAsyncJavaScript aufgerufen.
window.renderMarkdown = function (md, baseHref, opts) {
  const root = document.documentElement;
  root.style.fontSize = (opts.fontSize || 17) + "px";
  document.body.classList.toggle("serif", opts.fontStyle === "serif");
  document.body.dataset.width = opts.width || "narrow";
  document.getElementById("custom-theme").textContent = opts.customCSS || "";

  const scrollY = opts.keepScroll ? window.scrollY : 0;
  document.getElementById("base").setAttribute("href", baseHref);

  const { body, meta } = splitFrontMatter(md);
  const html = marked.parse(body, { gfm: true, breaks: false });
  const clean = DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });

  const article = document.getElementById("content");
  article.innerHTML = (meta ? renderMeta(meta) : "") + clean;

  article.querySelectorAll("pre code").forEach((el) => {
    try { hljs.highlightElement(el); } catch (_) {}
  });
  addHeadingIds(article);
  article.querySelectorAll("input[type=checkbox]").forEach((el) => (el.disabled = true));

  window.scrollTo(0, scrollY);
  return article.querySelector("h1")?.textContent ?? null;
};

function splitFrontMatter(md) {
  const m = md.match(/^---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?/);
  if (!m) return { body: md, meta: null };
  return { body: md.slice(m[0].length), meta: m[1] };
}

// Einfache key: value-Zeilen der Front Matter als dezente Metazeile.
function renderMeta(yaml) {
  const rows = yaml
    .split(/\r?\n/)
    .map((l) => l.match(/^([A-Za-z0-9_-]+):\s*(.+)$/))
    .filter(Boolean)
    .slice(0, 8);
  if (!rows.length) return "";
  const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const items = rows
    .map(([, k, v]) => `<div><dt>${esc(k)}</dt><dd>${esc(v.replace(/^["']|["']$/g, ""))}</dd></div>`)
    .join("");
  return `<dl class="front-matter">${items}</dl>`;
}

function addHeadingIds(article) {
  const used = new Set();
  article.querySelectorAll("h1,h2,h3,h4,h5,h6").forEach((h) => {
    if (h.id) return;
    let slug = h.textContent.trim().toLowerCase()
      .replace(/[^\p{L}\p{N}\s-]/gu, "").replace(/\s+/g, "-");
    let id = slug, n = 1;
    while (used.has(id)) id = `${slug}-${n++}`;
    used.add(id);
    h.id = id;
  });
}

// Anker-Links nicht über <base> auflösen lassen, sondern im Dokument scrollen.
document.addEventListener("click", (e) => {
  const a = e.target.closest("a[href^='#']");
  if (!a) return;
  e.preventDefault();
  const id = decodeURIComponent(a.getAttribute("href").slice(1));
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
});
