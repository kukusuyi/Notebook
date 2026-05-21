package openapi

const DocsHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>题迹 Notebook API Docs</title>
  <style>
    :root {
      --bg: #f4efe6;
      --panel: #fffaf1;
      --ink: #1f2937;
      --muted: #6b7280;
      --line: #e5dccf;
      --accent: #0f766e;
      --accent-soft: #d9f0ec;
      --method-get: #14532d;
      --method-post: #92400e;
      --method-put: #1d4ed8;
      --method-delete: #991b1b;
      --shadow: 0 18px 50px rgba(60, 47, 30, 0.08);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top right, rgba(15,118,110,0.12), transparent 28%),
        linear-gradient(180deg, #f8f3eb 0%, var(--bg) 100%);
    }
    .layout {
      display: grid;
      grid-template-columns: 280px minmax(0, 1fr);
      min-height: 100vh;
    }
    .sidebar {
      position: sticky;
      top: 0;
      height: 100vh;
      overflow: auto;
      padding: 28px 22px;
      border-right: 1px solid var(--line);
      background: rgba(255,250,241,0.86);
      backdrop-filter: blur(10px);
    }
    .brand {
      margin-bottom: 20px;
    }
    .brand h1 {
      margin: 0 0 8px;
      font-size: 22px;
    }
    .brand p {
      margin: 0;
      color: var(--muted);
      line-height: 1.6;
      font-size: 14px;
    }
    .side-link {
      display: block;
      color: var(--ink);
      text-decoration: none;
      padding: 8px 10px;
      border-radius: 10px;
      margin-bottom: 4px;
      font-size: 14px;
    }
    .side-link:hover {
      background: var(--accent-soft);
    }
    .content {
      padding: 36px;
    }
    .hero {
      background: linear-gradient(135deg, #fffef9, #f4fff8);
      border: 1px solid var(--line);
      border-radius: 24px;
      box-shadow: var(--shadow);
      padding: 28px;
      margin-bottom: 28px;
    }
    .hero h2 {
      margin: 0 0 10px;
      font-size: 30px;
    }
    .hero p {
      margin: 0;
      line-height: 1.7;
      color: var(--muted);
      max-width: 900px;
    }
    .toolbar {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      margin-top: 18px;
    }
    .toolbar a {
      text-decoration: none;
      color: #083344;
      background: var(--accent-soft);
      border: 1px solid #b8dfd8;
      border-radius: 999px;
      padding: 10px 14px;
      font-size: 14px;
    }
    .tag-block {
      margin-bottom: 28px;
    }
    .tag-title {
      margin: 0 0 14px;
      font-size: 20px;
    }
    .tag-desc {
      margin: 0 0 16px;
      color: var(--muted);
    }
    .card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 20px;
      box-shadow: var(--shadow);
      padding: 20px;
      margin-bottom: 16px;
    }
    .endpoint-head {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
      margin-bottom: 10px;
    }
    .method {
      min-width: 72px;
      text-align: center;
      padding: 6px 10px;
      border-radius: 999px;
      color: white;
      font-weight: 700;
      font-size: 12px;
      letter-spacing: 0.04em;
    }
    .method.get { background: var(--method-get); }
    .method.post { background: var(--method-post); }
    .method.put { background: var(--method-put); }
    .method.delete { background: var(--method-delete); }
    .path {
      font-family: Consolas, "Courier New", monospace;
      font-size: 14px;
      word-break: break-all;
    }
    .summary {
      font-size: 18px;
      margin: 0 0 8px;
    }
    .desc {
      color: var(--muted);
      margin: 0 0 14px;
      line-height: 1.7;
    }
    .section-title {
      margin: 16px 0 8px;
      font-size: 14px;
      color: #374151;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid var(--line);
      overflow: hidden;
      border-radius: 12px;
      background: white;
    }
    th, td {
      padding: 10px 12px;
      border-bottom: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
      font-size: 14px;
    }
    th {
      width: 150px;
      background: #faf5ed;
    }
    pre {
      margin: 0;
      padding: 14px;
      border-radius: 14px;
      background: #17212b;
      color: #e5eef8;
      overflow: auto;
      font-size: 13px;
      line-height: 1.6;
    }
    .loading, .error {
      padding: 20px;
      border-radius: 16px;
      background: white;
      border: 1px solid var(--line);
    }
    @media (max-width: 960px) {
      .layout { grid-template-columns: 1fr; }
      .sidebar {
        position: relative;
        height: auto;
        border-right: none;
        border-bottom: 1px solid var(--line);
      }
      .content { padding: 20px; }
      .hero h2 { font-size: 24px; }
    }
  </style>
</head>
<body>
  <div class="layout">
    <aside class="sidebar">
      <div class="brand">
        <h1>API Docs</h1>
        <p>错题本后端接口文档，直接读取服务内置的 OpenAPI 规范。</p>
      </div>
      <nav id="nav"></nav>
    </aside>
    <main class="content">
      <section class="hero">
        <h2>题迹 Notebook Backend</h2>
        <p id="description">正在加载接口文档...</p>
        <div class="toolbar">
          <a href="/docs/openapi.json" target="_blank" rel="noreferrer">查看 OpenAPI JSON</a>
          <a href="/healthz" target="_blank" rel="noreferrer">健康检查</a>
        </div>
      </section>
      <div id="app" class="loading">正在加载文档内容...</div>
    </main>
  </div>
  <script>
    async function boot() {
      const app = document.getElementById("app");
      const nav = document.getElementById("nav");
      try {
        const res = await fetch("/docs/openapi.json");
        const spec = await res.json();
        document.getElementById("description").textContent = spec.info.description || "";
        renderNav(nav, spec);
        renderContent(app, spec);
      } catch (error) {
        app.className = "error";
        app.textContent = "文档加载失败：" + error.message;
      }
    }

    function renderNav(nav, spec) {
      const tags = new Map();
      for (const [path, methods] of Object.entries(spec.paths || {})) {
        for (const [method, operation] of Object.entries(methods)) {
          const tag = (operation.tags || ["Other"])[0];
          if (!tags.has(tag)) tags.set(tag, []);
          tags.get(tag).push({ path, method, operation });
        }
      }
      nav.innerHTML = "";
      for (const [tag, entries] of tags.entries()) {
        const title = document.createElement("a");
        title.className = "side-link";
        title.href = "#tag-" + slug(tag);
        title.textContent = tag + " (" + entries.length + ")";
        nav.appendChild(title);
      }
    }

    function renderContent(app, spec) {
      const schemas = spec.components?.schemas || {};
      const tags = new Map();
      for (const [path, methods] of Object.entries(spec.paths || {})) {
        for (const [method, operation] of Object.entries(methods)) {
          const tag = (operation.tags || ["Other"])[0];
          if (!tags.has(tag)) tags.set(tag, []);
          tags.get(tag).push({ path, method, operation });
        }
      }

      app.className = "";
      app.innerHTML = "";

      for (const [tag, entries] of tags.entries()) {
        const block = document.createElement("section");
        block.className = "tag-block";
        block.id = "tag-" + slug(tag);

        const title = document.createElement("h3");
        title.className = "tag-title";
        title.textContent = tag;
        block.appendChild(title);

        const tagMeta = (spec.tags || []).find(item => item.name === tag);
        if (tagMeta?.description) {
          const desc = document.createElement("p");
          desc.className = "tag-desc";
          desc.textContent = tagMeta.description;
          block.appendChild(desc);
        }

        entries.forEach(entry => block.appendChild(renderCard(entry, schemas)));
        app.appendChild(block);
      }
    }

    function renderCard(entry, schemas) {
      const card = document.createElement("article");
      card.className = "card";

      const head = document.createElement("div");
      head.className = "endpoint-head";

      const method = document.createElement("span");
      method.className = "method " + entry.method.toLowerCase();
      method.textContent = entry.method.toUpperCase();
      head.appendChild(method);

      const path = document.createElement("span");
      path.className = "path";
      path.textContent = entry.path;
      head.appendChild(path);

      card.appendChild(head);

      const summary = document.createElement("h4");
      summary.className = "summary";
      summary.textContent = entry.operation.summary || entry.operation.operationId || entry.path;
      card.appendChild(summary);

      if (entry.operation.description) {
        const desc = document.createElement("p");
        desc.className = "desc";
        desc.textContent = entry.operation.description;
        card.appendChild(desc);
      }

      if ((entry.operation.parameters || []).length) {
        card.appendChild(sectionTitle("参数"));
        card.appendChild(renderParams(entry.operation.parameters));
      }

      if (entry.operation.requestBody) {
        card.appendChild(sectionTitle("请求体"));
        const schema = pickSchema(entry.operation.requestBody, schemas);
        card.appendChild(renderSchema(schema, schemas));
      }

      const success = entry.operation.responses?.["200"];
      if (success) {
        card.appendChild(sectionTitle("成功响应"));
        const schema = pickResponseSchema(success, schemas);
        card.appendChild(renderSchema(schema, schemas));
      }

      return card;
    }

    function sectionTitle(text) {
      const el = document.createElement("div");
      el.className = "section-title";
      el.textContent = text;
      return el;
    }

    function renderParams(params) {
      const table = document.createElement("table");
      table.innerHTML = "<thead><tr><th>名称</th><th>位置</th><th>必填</th><th>说明</th></tr></thead>";
      const tbody = document.createElement("tbody");
      params.forEach(param => {
        const tr = document.createElement("tr");
        tr.innerHTML = "<td>" + escapeHTML(param.name) + "</td><td>" + escapeHTML(param.in || "") + "</td><td>" + (param.required ? "是" : "否") + "</td><td>" + escapeHTML(param.description || "") + "</td>";
        tbody.appendChild(tr);
      });
      table.appendChild(tbody);
      return table;
    }

    function renderSchema(schema, schemas) {
      const pre = document.createElement("pre");
      pre.textContent = JSON.stringify(expandSchema(schema, schemas), null, 2);
      return pre;
    }

    function pickSchema(requestBody, schemas) {
      const content = requestBody.content || {};
      const mediaType = content["application/json"] || content["multipart/form-data"] || Object.values(content)[0];
      return deref(mediaType?.schema, schemas);
    }

    function pickResponseSchema(response, schemas) {
      const content = response.content || {};
      const mediaType = content["application/json"] || content["text/plain"] || content["text/html"] || Object.values(content)[0];
      return deref(mediaType?.schema, schemas) || mediaType?.example || {};
    }

    function deref(schema, schemas) {
      if (!schema) return {};
      if (schema.$ref) {
        const key = schema.$ref.split("/").pop();
        return schemas[key] || {};
      }
      return schema;
    }

    function expandSchema(schema, schemas, seen = new Set()) {
      const resolved = deref(schema, schemas);
      if (!resolved || typeof resolved !== "object") return resolved;
      if (resolved.$ref) return expandSchema(deref(resolved, schemas), schemas, seen);
      if (seen.has(resolved)) return "[Circular]";
      seen.add(resolved);

      if (resolved.type === "object" || resolved.properties) {
        const result = {};
        for (const [key, value] of Object.entries(resolved.properties || {})) {
          result[key] = expandSchema(value, schemas, seen);
        }
        seen.delete(resolved);
        return result;
      }

      if (resolved.type === "array") {
        seen.delete(resolved);
        return [expandSchema(resolved.items, schemas, seen)];
      }

      if (Object.prototype.hasOwnProperty.call(resolved, "example")) {
        seen.delete(resolved);
        return resolved.example;
      }

      seen.delete(resolved);
      return resolved.type || resolved;
    }

    function slug(text) {
      return String(text).toLowerCase().replace(/[^a-z0-9]+/g, "-");
    }

    function escapeHTML(text) {
      return String(text)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;");
    }

    boot();
  </script>
</body>
</html>`
