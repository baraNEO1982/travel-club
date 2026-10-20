// Compatibility gateway for existing iPhone builds and old invitation links.
export default {
  async fetch(request: Request, env: { MIGRATION_MODE: string }) {
    const old = new URL(request.url);
    const target = new URL('https://marshrutclub.ru');
    target.pathname = old.pathname;
    target.search = old.search;
    if (env.MIGRATION_MODE !== 'proxy') {
      return Response.json({error: 'Переносим клуб на новый сервер. Попробуйте через несколько минут.'},
        {status: 503, headers: {'Cache-Control': 'no-store', 'Retry-After': '120'}});
    }
    if (!old.pathname.startsWith('/api/')) {
      return Response.redirect(target.href, 307);
    }
    const forwarded = new Request(target, request);
    const headers = forwarded.headers;
    // Preserve origin validation: never turn a foreign Origin into a trusted one.
    if (headers.get('Origin') === old.origin) headers.set('Origin', target.origin);
    headers.delete('Host');
    return fetch(new Request(forwarded, {redirect: 'manual'}));
  },
};
