/**
 * In-memory room and peer management for GameChat.
 * Handles room lifecycle, host tracking, user state (mic muted, deafened, speaking),
 * and disconnect cleanup.
 */

class RoomManager {
  constructor() {
    // Map<roomCode, { hostSocketId: string, createdAt: number, users: Map<socketId, UserInfo> }>
    this.rooms = new Map();
  }

  /**
   * Create or join a room.
   */
  joinRoom(roomCode, socketId, username) {
    const cleanCode = roomCode.toUpperCase().trim();
    if (!this.rooms.has(cleanCode)) {
      this.rooms.set(cleanCode, {
        code: cleanCode,
        hostSocketId: socketId,
        createdAt: Date.now(),
        users: new Map(),
      });
    }

    const room = this.rooms.get(cleanCode);
    const isHost = room.hostSocketId === socketId || room.users.size === 0;
    if (isHost) {
      room.hostSocketId = socketId;
    }

    const user = {
      socketId,
      username: username || `Gamer_${socketId.substring(0, 4)}`,
      isHost,
      isMuted: false,
      isDeafened: false,
      isSpeaking: false,
      joinedAt: Date.now(),
    };

    room.users.set(socketId, user);
    return { room, user };
  }

  /**
   * Remove a user from their room on leave or socket disconnect.
   */
  leaveUser(socketId) {
    for (const [code, room] of this.rooms.entries()) {
      if (room.users.has(socketId)) {
        const user = room.users.get(socketId);
        room.users.delete(socketId);

        let newHost = null;
        if (room.users.size === 0) {
          // Room is empty, clean it up
          this.rooms.delete(code);
        } else if (room.hostSocketId === socketId) {
          // Host left, assign next oldest user as new host
          const nextUser = room.users.values().next().value;
          nextUser.isHost = true;
          room.hostSocketId = nextUser.socketId;
          newHost = nextUser;
        }

        return { roomCode: code, user, newHost, remainingUsers: Array.from(room.users.values()) };
      }
    }
    return null;
  }

  /**
   * Update a user's microphone or speaking state.
   */
  updateUserState(socketId, updates = {}) {
    for (const [code, room] of this.rooms.entries()) {
      if (room.users.has(socketId)) {
        const user = room.users.get(socketId);
        if (updates.isMuted !== undefined) user.isMuted = updates.isMuted;
        if (updates.isDeafened !== undefined) user.isDeafened = updates.isDeafened;
        if (updates.isSpeaking !== undefined) user.isSpeaking = updates.isSpeaking;
        return { roomCode: code, user };
      }
    }
    return null;
  }

  /**
   * Get room info by code.
   */
  getRoom(roomCode) {
    const cleanCode = roomCode.toUpperCase().trim();
    const room = this.rooms.get(cleanCode);
    if (!room) return null;
    return {
      code: room.code,
      hostSocketId: room.hostSocketId,
      users: Array.from(room.users.values()),
    };
  }

  /**
   * Check if a specific socket is the host of the room they are in.
   */
  isHost(roomCode, socketId) {
    const room = this.rooms.get(roomCode.toUpperCase().trim());
    return room && room.hostSocketId === socketId;
  }
}

module.exports = new RoomManager();
