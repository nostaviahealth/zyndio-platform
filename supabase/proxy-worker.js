/**
 * Supabase Reverse Proxy Worker
 * Bypasses DNS blocks in India by proxying requests through Cloudflare.
 * 
 * Instructions:
 * 1. Create a new Worker in Cloudflare dashboard.
 * 2. Paste this code into the Worker editor.
 * 3. Update SUPABASE_URL below with your project URL if different.
 * 4. Deploy and use the Worker's URL in your app.
 */

// Set SUPABASE_URL as a Worker environment variable (Zyndio dev project).
const SUPABASE_URL = globalThis.SUPABASE_URL ?? 'https://YOUR-PROJECT-REF.supabase.co';

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);

        // Construct the destination URL
        const destinationUrl = new URL(SUPABASE_URL);
        destinationUrl.pathname = url.pathname;
        destinationUrl.search = url.search;

        // Clone the request with the new URL
        const modifiedRequest = new Request(destinationUrl, {
            method: request.method,
            headers: new Headers(request.headers),
            body: request.body,
            redirect: 'follow'
        });

        // Add necessary headers if needed, or just forward
        // Ensure Host header is correct for Supabase
        modifiedRequest.headers.set('Host', new URL(SUPABASE_URL).host);

        try {
            const response = await fetch(modifiedRequest);

            // Clone response to add CORS headers if necessary
            const newResponse = new Response(response.body, response);

            return newResponse;
        } catch (err) {
            return new Response(`Proxy Error: ${err.message}`, { status: 502 });
        }
    },
};
