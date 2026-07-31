self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()))

self.addEventListener('fetch', e => {
  const request = e.request
  if (request.cache == 'only-if-cached' && request.mode != 'same-origin') return

  e.respondWith(fetch(request).then(response => {
    if (response.status == 0) return response

    const headers = new Headers(response.headers)
    headers.set('Cross-Origin-Opener-Policy', 'same-origin')
    headers.set('Cross-Origin-Embedder-Policy', 'require-corp')

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    })
  }))
})
