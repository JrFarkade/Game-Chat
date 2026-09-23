export interface Env {
  ROOM_DO: DurableObjectNamespace;
  CALLS_APP_ID?: string;
  CALLS_APP_SECRET?: string;
  ENVIRONMENT?: string;
  APK_BUCKET?: R2Bucket;
  ASSETS?: Fetcher;
}

export interface UserPeer {
  id: string; // client connection id
  username: string;
  isHost: boolean;
  isMuted: boolean;
  isDeafened: boolean;
  isSpeaking: boolean;
  joinedAt: number;
  callsSessionId?: string;
  callsAudioTrackName?: string;
}

export interface WebSocketAttachment {
  id: string;
  username: string;
  isHost: boolean;
  isMuted: boolean;
  isDeafened: boolean;
  isSpeaking: boolean;
  joinedAt: number;
  callsSessionId?: string;
  callsAudioTrackName?: string;
}

export type SignalingClientMessage =
  | { type: 'join-room'; roomCode: string; username: string; callsSessionId?: string; callsAudioTrackName?: string }
  | { type: 'offer'; targetUserId: string; sdp: any }
  | { type: 'answer'; targetUserId: string; sdp: any }
  | { type: 'ice-candidate'; targetUserId: string; candidate: any }
  | { type: 'state-change'; isMuted: boolean; isDeafened: boolean }
  | { type: 'speaking-change'; isSpeaking: boolean }
  | { type: 'soundboard-play'; soundId: string; soundName: string; audioData?: string; audioFormat?: string }
  | { type: 'soundboard-sync'; soundId: string; soundName: string; audioData?: string; audioFormat?: string }
  | { type: 'calls-track-published'; callsSessionId: string; callsAudioTrackName: string }
  | { type: 'kick-user'; targetUserId: string }
  | { type: 'leave-room' }
  | { type: 'ping' };

export type SignalingServerMessage =
  | { type: 'room-joined'; user: UserPeer; roomCode: string; isHost: boolean; existingPeers: UserPeer[] }
  | { type: 'user-joined'; user: UserPeer; allUsers: UserPeer[] }
  | { type: 'user-left'; userId: string; username: string; newHost?: UserPeer | null; remainingUsers: UserPeer[] }
  | { type: 'offer'; senderSocketId: string; sdp: any }
  | { type: 'answer'; senderSocketId: string; sdp: any }
  | { type: 'ice-candidate'; senderSocketId: string; candidate: any }
  | { type: 'user-state-changed'; userId: string; isMuted: boolean; isDeafened: boolean }
  | { type: 'user-speaking-changed'; userId: string; isSpeaking: boolean }
  | { type: 'soundboard-played'; senderId: string; senderName: string; soundId: string; soundName: string; audioData?: string; audioFormat?: string; timestamp: number }
  | { type: 'soundboard-synced'; senderId: string; senderName: string; soundId: string; soundName: string; audioData?: string; audioFormat?: string; timestamp: number }
  | { type: 'calls-track-updated'; userId: string; callsSessionId: string; callsAudioTrackName: string }
  | { type: 'kicked-from-room'; reason: string }
  | { type: 'error'; message: string }
  | { type: 'pong' };
