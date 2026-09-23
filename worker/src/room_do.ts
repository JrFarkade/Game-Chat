import { Env, SignalingClientMessage, SignalingServerMessage, UserPeer, WebSocketAttachment } from './types';

export class RoomDurableObject {
  private ctx: DurableObjectState;
  private env: Env;
  private roomCode: string = '';
  private hostId: string | null = null;
  private createdAt: number = Date.now();

  constructor(ctx: DurableObjectState, env: Env) {
    this.ctx = ctx;
    this.env = env;
  }

  private sanitizeUsername(name?: string): string {
    if (!name || typeof name !== 'string') return 'Gamer';
    const clean = name.replace(/[^\w\s\u00C0-\u024F\u1E00-\u1EFF-]/gi, '').trim();
    return clean.length > 0 ? clean.substring(0, 20) : 'Gamer';
  }

  private getAllUsers(): UserPeer[] {
    const sockets = this.ctx.getWebSockets();
    const users: UserPeer[] = [];
    for (const ws of sockets) {
      const data = ws.deserializeAttachment() as WebSocketAttachment | null;
      if (data && data.id) {
        users.push({
          id: data.id,
          username: data.username,
          isHost: data.id === this.hostId,
          isMuted: data.isMuted,
          isDeafened: data.isDeafened,
          isSpeaking: data.isSpeaking,
          joinedAt: data.joinedAt,
          callsSessionId: data.callsSessionId,
          callsAudioTrackName: data.callsAudioTrackName,
        });
      }
    }
    return users;
  }

  private broadcast(message: SignalingServerMessage, excludeWs?: WebSocket) {
    const msgStr = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      if (excludeWs && ws === excludeWs) continue;
      try {
        ws.send(msgStr);
      } catch (err) {
        console.error('[DO] Error broadcasting to ws:', err);
      }
    }
  }

  private sendToUser(targetUserId: string, message: SignalingServerMessage) {
    const msgStr = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      const data = ws.deserializeAttachment() as WebSocketAttachment | null;
      if (data && data.id === targetUserId) {
        try {
          ws.send(msgStr);
        } catch (err) {
          console.error('[DO] Error sending to user:', err);
        }
        break;
      }
    }
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    // Extract roomCode if present in query or path
    const roomParam = url.searchParams.get('roomCode');
    if (roomParam) {
      this.roomCode = roomParam.toUpperCase().trim();
    }

    if (request.headers.get('Upgrade')?.toLowerCase() === 'websocket') {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      // Accept the server WebSocket for hibernation
      this.ctx.acceptWebSocket(server);

      return new Response(null, {
        status: 101,
        webSocket: client,
      });
    }

    if (url.pathname.endsWith('/info')) {
      const users = this.getAllUsers();
      return new Response(
        JSON.stringify({
          roomCode: this.roomCode,
          hostId: this.hostId,
          createdAt: this.createdAt,
          userCount: users.length,
          users,
        }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    return new Response('Not found', { status: 404 });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    if (typeof message !== 'string') return;

    let payload: SignalingClientMessage;
    try {
      payload = JSON.parse(message);
    } catch {
      ws.send(JSON.stringify({ type: 'error', message: 'Malformed JSON' }));
      return;
    }

    const currentData = ws.deserializeAttachment() as WebSocketAttachment | null;

    switch (payload.type) {
      case 'ping': {
        ws.send(JSON.stringify({ type: 'pong' }));
        break;
      }

      case 'join-room': {
        const cleanCode = (payload.roomCode || this.roomCode).toUpperCase().trim();
        this.roomCode = cleanCode;
        const cleanUsername = this.sanitizeUsername(payload.username);
        const socketId = currentData?.id || crypto.randomUUID();

        const sockets = this.ctx.getWebSockets();
        const isFirst = this.hostId === null || sockets.length <= 1;
        if (isFirst) {
          this.hostId = socketId;
        }

        const user: UserPeer = {
          id: socketId,
          username: cleanUsername,
          isHost: socketId === this.hostId,
          isMuted: false,
          isDeafened: false,
          isSpeaking: false,
          joinedAt: Date.now(),
          callsSessionId: payload.callsSessionId,
          callsAudioTrackName: payload.callsAudioTrackName,
        };

        ws.serializeAttachment({ ...user });

        const existingPeers = this.getAllUsers().filter((u) => u.id !== socketId);

        // Ack back to joining user
        ws.send(
          JSON.stringify({
            type: 'room-joined',
            user,
            roomCode: this.roomCode,
            isHost: user.isHost,
            existingPeers,
          } as SignalingServerMessage)
        );

        // Notify other room participants
        this.broadcast(
          {
            type: 'user-joined',
            user,
            allUsers: this.getAllUsers(),
          },
          ws
        );
        break;
      }

      case 'offer': {
        if (!currentData || !payload.targetUserId) return;
        this.sendToUser(payload.targetUserId, {
          type: 'offer',
          senderSocketId: currentData.id,
          sdp: payload.sdp,
        });
        break;
      }

      case 'answer': {
        if (!currentData || !payload.targetUserId) return;
        this.sendToUser(payload.targetUserId, {
          type: 'answer',
          senderSocketId: currentData.id,
          sdp: payload.sdp,
        });
        break;
      }

      case 'ice-candidate': {
        if (!currentData || !payload.targetUserId) return;
        this.sendToUser(payload.targetUserId, {
          type: 'ice-candidate',
          senderSocketId: currentData.id,
          candidate: payload.candidate,
        });
        break;
      }

      case 'state-change': {
        if (!currentData) return;
        currentData.isMuted = !!payload.isMuted;
        currentData.isDeafened = !!payload.isDeafened;
        ws.serializeAttachment(currentData);

        this.broadcast({
          type: 'user-state-changed',
          userId: currentData.id,
          isMuted: currentData.isMuted,
          isDeafened: currentData.isDeafened,
        });
        break;
      }

      case 'speaking-change': {
        if (!currentData) return;
        currentData.isSpeaking = !!payload.isSpeaking;
        ws.serializeAttachment(currentData);

        this.broadcast(
          {
            type: 'user-speaking-changed',
            userId: currentData.id,
            isSpeaking: currentData.isSpeaking,
          },
          ws
        );
        break;
      }

      case 'soundboard-play': {
        if (!currentData || !payload.soundId) return;
        this.broadcast({
          type: 'soundboard-played',
          senderId: currentData.id,
          senderName: currentData.username,
          soundId: payload.soundId,
          soundName: payload.soundName || payload.soundId,
          audioData: (payload as any).audioData,
          audioFormat: (payload as any).audioFormat,
          timestamp: Date.now(),
        });
        break;
      }

      case 'soundboard-sync': {
        if (!currentData || !payload.soundId) return;
        this.broadcast(
          {
            type: 'soundboard-synced',
            senderId: currentData.id,
            senderName: currentData.username,
            soundId: payload.soundId,
            soundName: payload.soundName || payload.soundId,
            audioData: (payload as any).audioData,
            audioFormat: (payload as any).audioFormat,
            timestamp: Date.now(),
          },
          ws
        );
        break;
      }

      case 'calls-track-published': {
        if (!currentData) return;
        currentData.callsSessionId = payload.callsSessionId;
        currentData.callsAudioTrackName = payload.callsAudioTrackName;
        ws.serializeAttachment(currentData);

        this.broadcast(
          {
            type: 'calls-track-updated',
            userId: currentData.id,
            callsSessionId: payload.callsSessionId,
            callsAudioTrackName: payload.callsAudioTrackName,
          },
          ws
        );
        break;
      }

      case 'kick-user': {
        if (!currentData || currentData.id !== this.hostId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Permission denied: Only host can kick' }));
          return;
        }

        const targetId = payload.targetUserId;
        for (const otherWs of this.ctx.getWebSockets()) {
          const data = otherWs.deserializeAttachment() as WebSocketAttachment | null;
          if (data && data.id === targetId) {
            try {
              otherWs.send(JSON.stringify({ type: 'kicked-from-room', reason: 'You were removed by the host' }));
              otherWs.close(1000, 'Kicked by host');
            } catch {}
            break;
          }
        }
        break;
      }

      case 'leave-room': {
        this.handleUserLeave(ws);
        ws.close(1000, 'Left room');
        break;
      }
    }
  }

  private handleUserLeave(ws: WebSocket) {
    const data = ws.deserializeAttachment() as WebSocketAttachment | null;
    if (!data) return;

    // Remove user attachment
    ws.serializeAttachment(null);

    const remaining = this.getAllUsers().filter((u) => u.id !== data.id);
    let newHost: UserPeer | null = null;

    if (this.hostId === data.id) {
      if (remaining.length > 0) {
        newHost = remaining[0];
        newHost.isHost = true;
        this.hostId = newHost.id;

        // Update the new host's ws attachment
        for (const sock of this.ctx.getWebSockets()) {
          const sockData = sock.deserializeAttachment() as WebSocketAttachment | null;
          if (sockData && sockData.id === this.hostId) {
            sockData.isHost = true;
            sock.serializeAttachment(sockData);
            break;
          }
        }
      } else {
        this.hostId = null;
      }
    }

    this.broadcast({
      type: 'user-left',
      userId: data.id,
      username: data.username,
      newHost,
      remainingUsers: remaining,
    });
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) {
    this.handleUserLeave(ws);
  }

  async webSocketError(ws: WebSocket, error: unknown) {
    this.handleUserLeave(ws);
  }
}
