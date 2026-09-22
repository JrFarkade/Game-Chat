require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const roomManager = require('./rooms');

const app = express();
app.use(cors());
app.use(express.json({ limit: '64kb' })); // strictly limit payload size

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 30000,
  pingInterval: 10000,
  maxHttpBufferSize: 1e5, // 100 KB max buffer
});

// Default to port 3000 as requested
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Input Validation Helpers
function isValidRoomCode(code) {
  return typeof code === 'string' && /^[A-Za-z0-9]{3,10}$/.test(code.trim());
}

function sanitizeUsername(name) {
  if (typeof name !== 'string') return 'Gamer';
  const clean = name.replace(/[^\w\s\u00C0-\u024F\u1E00-\u1EFF-]/gi, '').trim();
  return clean.length > 0 ? clean.substring(0, 20) : 'Gamer';
}

function isValidSdp(sdp) {
  return sdp && typeof sdp === 'object' && typeof sdp.sdp === 'string' && typeof sdp.type === 'string';
}

// Health check endpoint for tunnel verification
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>GameChat Signaling Server</title></head>
      <body style="background:#0e1117;color:#f1f5f9;font-family:sans-serif;text-align:center;padding-top:60px;">
        <h1 style="color:#7c4dff;">🎮 GameChat Signaling Server</h1>
        <p style="color:#00e676;font-weight:bold;">🟢 STATUS: ONLINE & READY</p>
        <p>Active Voice Rooms: ${roomManager.rooms.size}</p>
        <p style="color:#94a3b8;font-size:12px;">WebSockets / WebRTC signaling active on port ${PORT}</p>
      </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    port: PORT,
    activeRooms: roomManager.rooms.size,
    timestamp: new Date().toISOString(),
  });
});

// Endpoint providing dynamic ICE server config (STUN and optional TURN from .env)
app.get('/config/ice-servers', (req, res) => {
  const iceServers = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun2.l.google.com:19302' },
  ];

  if (process.env.TURN_URL && process.env.TURN_USERNAME && process.env.TURN_CREDENTIAL) {
    iceServers.push({
      urls: process.env.TURN_URL,
      username: process.env.TURN_USERNAME,
      credential: process.env.TURN_CREDENTIAL,
    });
  }

  res.json({ iceServers });
});

io.on('connection', (socket) => {
  console.log(`[USER] Connected: socket ${socket.id}`);

  // 1. Join / Create Room
  socket.on('join-room', ({ roomCode, username }, callback) => {
    if (!isValidRoomCode(roomCode)) {
      if (typeof callback === 'function') callback({ error: 'Invalid room code (3-10 alphanumeric characters required)' });
      return;
    }

    const cleanCode = roomCode.toUpperCase().trim();
    const cleanUsername = sanitizeUsername(username);

    socket.join(cleanCode);

    const isFirstInRoom = !roomManager.rooms.has(cleanCode);
    const { room, user } = roomManager.joinRoom(cleanCode, socket.id, cleanUsername);

    if (isFirstInRoom) {
      console.log(`[ROOM] ${cleanCode} created by ${cleanUsername} (${socket.id})`);
    } else {
      console.log(`[USER] ${cleanUsername} joined ${cleanCode} (${room.users.size} members in room)`);
    }

    // Notify other peers in this room
    socket.to(cleanCode).emit('user-joined', {
      user,
      allUsers: Array.from(room.users.values()),
    });

    const existingPeers = Array.from(room.users.values()).filter(u => u.socketId !== socket.id);
    if (typeof callback === 'function') {
      callback({
        success: true,
        user,
        roomCode: cleanCode,
        isHost: user.isHost,
        existingPeers,
      });
    }
  });

  // 2. WebRTC SDP Offer Relay
  socket.on('offer', ({ targetSocketId, sdp }) => {
    if (!targetSocketId || !isValidSdp(sdp)) return;
    console.log(`[WEBRTC] Offer relayed from ${socket.id} -> ${targetSocketId}`);
    io.to(targetSocketId).emit('offer', {
      senderSocketId: socket.id,
      sdp,
    });
  });

  // 3. WebRTC SDP Answer Relay
  socket.on('answer', ({ targetSocketId, sdp }) => {
    if (!targetSocketId || !isValidSdp(sdp)) return;
    console.log(`[WEBRTC] Answer relayed from ${socket.id} -> ${targetSocketId}`);
    io.to(targetSocketId).emit('answer', {
      senderSocketId: socket.id,
      sdp,
    });
  });

  // 4. WebRTC ICE Candidate Relay
  socket.on('ice-candidate', ({ targetSocketId, candidate }) => {
    if (!targetSocketId || !candidate) return;
    io.to(targetSocketId).emit('ice-candidate', {
      senderSocketId: socket.id,
      candidate,
    });
  });

  // 5. Microphone Mute / Deafen State Change
  socket.on('state-change', ({ isMuted, isDeafened }) => {
    const updated = roomManager.updateUserState(socket.id, { isMuted: !!isMuted, isDeafened: !!isDeafened });
    if (updated) {
      io.to(updated.roomCode).emit('user-state-changed', {
        socketId: socket.id,
        isMuted: updated.user.isMuted,
        isDeafened: updated.user.isDeafened,
      });
    }
  });

  // 6. Voice Activity Indicator (Speaking status)
  socket.on('speaking-change', ({ isSpeaking }) => {
    const updated = roomManager.updateUserState(socket.id, { isSpeaking: !!isSpeaking });
    if (updated) {
      socket.to(updated.roomCode).emit('user-speaking-changed', {
        socketId: socket.id,
        isSpeaking: updated.user.isSpeaking,
      });
    }
  });

  // 7. Soundboard Play Broadcast
  socket.on('soundboard-play', ({ soundId, soundName }) => {
    if (!soundId || typeof soundId !== 'string') return;
    for (const [code, room] of roomManager.rooms.entries()) {
      if (room.users.has(socket.id)) {
        const sender = room.users.get(socket.id);
        console.log(`[SOUNDBOARD] ${sender.username} played '${soundName || soundId}' in room ${code}`);
        io.to(code).emit('soundboard-played', {
          senderSocketId: socket.id,
          senderName: sender.username,
          soundId,
          soundName,
          timestamp: Date.now(),
        });
        break;
      }
    }
  });

  // 8. Kick User (Host Only)
  socket.on('kick-user', ({ targetSocketId }, callback) => {
    for (const [code, room] of roomManager.rooms.entries()) {
      if (room.users.has(socket.id) && room.hostSocketId === socket.id) {
        if (room.users.has(targetSocketId)) {
          const kickedUser = room.users.get(targetSocketId);
          console.log(`[HOST] ${room.users.get(socket.id).username} kicked ${kickedUser.username} from room ${code}`);
          io.to(targetSocketId).emit('kicked-from-room', {
            reason: 'You were removed by the room host',
          });

          const targetSocket = io.sockets.sockets.get(targetSocketId);
          if (targetSocket) {
            targetSocket.leave(code);
          }

          const result = roomManager.leaveUser(targetSocketId);
          io.to(code).emit('user-left', {
            socketId: targetSocketId,
            username: kickedUser.username,
            remainingUsers: result ? result.remainingUsers : [],
          });

          if (typeof callback === 'function') callback({ success: true });
          return;
        }
      }
    }
    if (typeof callback === 'function') callback({ error: 'Permission denied or user not found' });
  });

  // 9. Leave Room
  socket.on('leave-room', () => {
    const result = roomManager.leaveUser(socket.id);
    if (result) {
      socket.leave(result.roomCode);
      io.to(result.roomCode).emit('user-left', {
        socketId: socket.id,
        username: result.user.username,
        newHost: result.newHost,
        remainingUsers: result.remainingUsers,
      });
      console.log(`[USER] ${result.user.username} left room ${result.roomCode}`);
    }
  });

  // 10. Disconnect Cleanup
  socket.on('disconnect', (reason) => {
    const result = roomManager.leaveUser(socket.id);
    if (result) {
      io.to(result.roomCode).emit('user-left', {
        socketId: socket.id,
        username: result.user.username,
        newHost: result.newHost,
        remainingUsers: result.remainingUsers,
      });
      console.log(`[USER] ${result.user.username} disconnected (${reason})`);
    } else {
      console.log(`[USER] Disconnected: socket ${socket.id} (${reason})`);
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log(`========================================================`);
  console.log(`[SERVER] Started on port ${PORT} (http://${HOST}:${PORT})`);
  console.log(`[TUNNEL] Run 'cloudflared tunnel --url http://localhost:${PORT}' to expose`);
  console.log(`========================================================`);
});
