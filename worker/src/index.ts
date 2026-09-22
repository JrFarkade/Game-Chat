import { Env } from './types';
export { RoomDurableObject } from './room_do';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
    },
  });
}

function generateRoomCode(): string {
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  let code = '';
  for (let i = 0; i < 5; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // Health check & root status
    if (url.pathname === '/' || url.pathname === '/health') {
      return jsonResponse({
        status: 'online',
        service: 'GameChat Cloudflare Edge Backend',
        environment: env.ENVIRONMENT || 'production',
        callsConfigured: !!(env.CALLS_APP_ID && env.CALLS_APP_SECRET),
        timestamp: new Date().toISOString(),
      });
    }

    // ICE servers configuration (Cloudflare Realtime STUN + Google STUN)
    if (url.pathname === '/config/ice-servers') {
      return jsonResponse({
        iceServers: [
          { urls: 'stun:stun.cloudflare.com:3478' },
          { urls: 'stun:stun.l.google.com:19302' },
          { urls: 'stun:stun1.l.google.com:19302' },
          { urls: 'stun:stun2.l.google.com:19302' },
        ],
      });
    }

    // Create a new Room
    if (url.pathname === '/api/rooms' && request.method === 'POST') {
      const roomCode = generateRoomCode();
      return jsonResponse({
        success: true,
        roomCode,
      });
    }

    // Room info or WebSocket upgrade: /api/rooms/:code/*
    const roomMatch = url.pathname.match(/^\/api\/rooms\/([A-Za-z0-9]{3,10})(\/ws|\/info)?$/);
    if (roomMatch) {
      const roomCode = roomMatch[1].toUpperCase().trim();
      const action = roomMatch[2]; // undefined, '/ws', or '/info'

      const id = env.ROOM_DO.idFromName(roomCode);
      const roomObject = env.ROOM_DO.get(id);

      const doUrl = new URL(request.url);
      doUrl.searchParams.set('roomCode', roomCode);

      if (action === '/ws') {
        return roomObject.fetch(new Request(doUrl.toString(), request));
      }

      // Default GET room status
      doUrl.pathname = '/info';
      return roomObject.fetch(new Request(doUrl.toString(), request));
    }

    // =========================================================================
    // Cloudflare Realtime Calls Proxy API
    // (Secures CALLS_APP_SECRET on the server)
    // =========================================================================
    const callsBase = 'https://rtc.live.cloudflare.com/v1';

    // 1. Create a new Calls session: POST /api/calls/session/new
    if (url.pathname === '/api/calls/session/new' && request.method === 'POST') {
      if (!env.CALLS_APP_ID || !env.CALLS_APP_SECRET) {
        return jsonResponse(
          {
            error: 'Cloudflare Calls is not configured on this Worker. Set CALLS_APP_ID and CALLS_APP_SECRET.',
          },
          503
        );
      }

      const body = await request.text();
      const cfRes = await fetch(`${callsBase}/apps/${env.CALLS_APP_ID}/sessions/new`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.CALLS_APP_SECRET}`,
        },
        body: body.length > 0 ? body : JSON.stringify({}),
      });

      const data = await cfRes.json();
      return jsonResponse(data, cfRes.status);
    }

    // 2. Add or Pull tracks: POST /api/calls/session/:sessionId/tracks/new
    const tracksMatch = url.pathname.match(/^\/api\/calls\/session\/([^/]+)\/tracks\/new$/);
    if (tracksMatch && request.method === 'POST') {
      if (!env.CALLS_APP_ID || !env.CALLS_APP_SECRET) {
        return jsonResponse({ error: 'Cloudflare Calls not configured' }, 503);
      }

      const sessionId = tracksMatch[1];
      const body = await request.text();

      const cfRes = await fetch(`${callsBase}/apps/${env.CALLS_APP_ID}/sessions/${sessionId}/tracks/new`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.CALLS_APP_SECRET}`,
        },
        body,
      });

      const data = await cfRes.json();
      return jsonResponse(data, cfRes.status);
    }

    // 3. Renegotiate session: PUT /api/calls/session/:sessionId/renegotiate
    const renegotiateMatch = url.pathname.match(/^\/api\/calls\/session\/([^/]+)\/renegotiate$/);
    if (renegotiateMatch && request.method === 'PUT') {
      if (!env.CALLS_APP_ID || !env.CALLS_APP_SECRET) {
        return jsonResponse({ error: 'Cloudflare Calls not configured' }, 503);
      }

      const sessionId = renegotiateMatch[1];
      const body = await request.text();

      const cfRes = await fetch(`${callsBase}/apps/${env.CALLS_APP_ID}/sessions/${sessionId}/renegotiate`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.CALLS_APP_SECRET}`,
        },
        body,
      });

      const data = await cfRes.json();
      return jsonResponse(data, cfRes.status);
    }

    // 4. Close tracks: PUT /api/calls/session/:sessionId/tracks/close
    const closeTracksMatch = url.pathname.match(/^\/api\/calls\/session\/([^/]+)\/tracks\/close$/);
    if (closeTracksMatch && request.method === 'PUT') {
      if (!env.CALLS_APP_ID || !env.CALLS_APP_SECRET) {
        return jsonResponse({ error: 'Cloudflare Calls not configured' }, 503);
      }

      const sessionId = closeTracksMatch[1];
      const body = await request.text();

      const cfRes = await fetch(`${callsBase}/apps/${env.CALLS_APP_ID}/sessions/${sessionId}/tracks/close`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.CALLS_APP_SECRET}`,
        },
        body,
      });

      const data = await cfRes.json();
      return jsonResponse(data, cfRes.status);
    }

    return jsonResponse({ error: 'Not Found' }, 404);
  },
};
