const http = require("http"), fs = require("fs"), path = require("path");
const types = { ".html": "text/html", ".woff2": "font/woff2", ".woff": "font/woff", ".ttf": "font/ttf", ".otf": "font/opentype" };
http.createServer((q, s) => {
  let p = decodeURIComponent(q.url.split("?")[0]);
  if (p === "/") p = "/index.html";
  fs.readFile(path.join(process.cwd(), p), (e, d) => {
    if (e) { s.writeHead(404); s.end(); return; }
    s.writeHead(200, { "Content-Type": types[path.extname(p).toLowerCase()] || "application/octet-stream" });
    s.end(d);
  });
}).listen(8765, () => console.log("Font viewer running at http://localhost:8765/index.html"));
