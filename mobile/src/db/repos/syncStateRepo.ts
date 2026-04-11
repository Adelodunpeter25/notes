import { getDb } from '../client';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { v4 as uuidv4 } from 'uuid';
import * as Device from 'expo-device';

const DEVICE_ID_KEY = 'notes_device_id';

let cachedDeviceId: string | null = null;

/**
 * Get or generate a stable device ID that persists across app reinstalls
 * (stored in AsyncStorage as a fallback identifier)
 */
async function getDeviceId(): Promise<string> {
  if (cachedDeviceId) return cachedDeviceId;

  // Try to retrieve existing device ID
  const stored = await AsyncStorage.getItem(DEVICE_ID_KEY);
  if (stored) {
    cachedDeviceId = stored;
    return stored;
  }

  // Generate new device ID based on device info + UUID
  const modelName = Device.modelName || 'unknown';
  const deviceId = `${modelName}_${uuidv4()}`;
  
  await AsyncStorage.setItem(DEVICE_ID_KEY, deviceId);
  cachedDeviceId = deviceId;
  
  return deviceId;
}

/**
 * Get the last sync cursor from the database
 */
export async function getSyncCursor(): Promise<string | null> {
  try {
    const db = getDb();
    const deviceId = await getDeviceId();

    const result = await db.getFirstAsync<{ last_cursor: string | null }>(
      'SELECT last_cursor FROM sync_state WHERE device_id = ? LIMIT 1',
      [deviceId]
    );

    return result?.last_cursor ?? null;
  } catch (error) {
    console.error('[syncStateRepo] Failed to get sync cursor:', error);
    return null;
  }
}

/**
 * Save the sync cursor to the database
 */
export async function saveSyncCursor(cursor: string, userId: string): Promise<void> {
  try {
    const db = getDb();
    const deviceId = await getDeviceId();
    const now = new Date().toISOString();

    await db.runAsync(
      `INSERT INTO sync_state (id, user_id, device_id, last_cursor, last_sync_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(device_id) DO UPDATE SET
         last_cursor = excluded.last_cursor,
         last_sync_at = excluded.last_sync_at,
         updated_at = excluded.updated_at`,
      [uuidv4(), userId, deviceId, cursor, now, now]
    );
  } catch (error) {
    console.error('[syncStateRepo] Failed to save sync cursor:', error);
    throw error;
  }
}

/**
 * Clear the sync cursor (useful for force resync)
 */
export async function clearSyncCursor(): Promise<void> {
  try {
    const db = getDb();
    const deviceId = await getDeviceId();

    await db.runAsync('DELETE FROM sync_state WHERE device_id = ?', [deviceId]);
  } catch (error) {
    console.error('[syncStateRepo] Failed to clear sync cursor:', error);
    throw error;
  }
}

/**
 * Get the device ID (exposed for debugging/logging)
 */
export async function getDeviceIdentifier(): Promise<string> {
  return getDeviceId();
}
