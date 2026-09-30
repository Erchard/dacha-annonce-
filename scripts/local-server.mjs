import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
const mime = {'.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm', '.json':'application/json', '.css':'text/css', '.png':'image/png', '.ttf':'font/ttf'};
export async function serve(directory) {
  const root = path.resolve(directory);
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://127.0.0.1');
      const pathname = decodeURIComponent(url.pathname);
      let target = path.resolve(root, '.' + pathname);
      if (target !== root && !target.startsWith(root + path.sep)) {
        res.writeHead(403).end(); return;
      }
      if (pathname === '/' || !path.extname(pathname)) target = path.join(root, 'index.html');
      const body = await readFile(target);
      res.writeHead(200, {'Content-Type':mime[path.extname(target)] ?? 'application/octet-stream', 'Cache-Control':'no-store'}).end(body);
    } catch {res.writeHead(404).end();}
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  return {server, url:`http://127.0.0.1:${server.address().port}`};
}
