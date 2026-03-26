# Future Features

This document outlines planned features for the Notes app.

## 1. Voice Notes

**Description:** Allow users to record audio notes directly within the app.

**Platforms:** Mobile and Desktop

**Key Requirements:**
- Record audio using device microphone
- Play back recorded audio
- Store audio files (local and server)
- Display audio notes in note list with duration indicator
- Waveform visualization during playback
- Pause/resume recording
- Delete audio recordings
- Sync audio files across devices

**Technical Considerations:**
- Mobile: Use Expo Audio API or react-native-audio-recorder
- Desktop: Use Tauri audio plugin or Web Audio API
- Storage: Store audio files as blobs in database or file system
- Format: Use compressed format (MP3/AAC) to save space
- Server: Add audio file upload/download endpoints
- Database: Add audio_url field to notes table or create separate voice_notes table

---

## 2. Task Reminders with Notifications

**Description:** Set reminders on tasks and receive notifications at the specified time.

**Platforms:** Mobile and Desktop

**Key Requirements:**
- Add reminder time field to tasks
- Schedule local notifications for task reminders
- Show notification when reminder time is reached
- Notification should include task title and description
- Snooze functionality (5 min, 15 min, 1 hour)
- Mark task as complete from notification
- Support multiple reminders per task
- Recurring reminders (daily, weekly, monthly)
- Notification sound/vibration settings

**Technical Considerations:**
- Mobile: Use expo-notifications for local notifications
- Desktop: Use Tauri notification plugin
- Database: Add reminder_time field to tasks table
- Background processing: Schedule notifications even when app is closed
- Timezone handling: Store reminders in UTC, display in local time
- Permission handling: Request notification permissions on first use
- Notification actions: Add quick actions (complete, snooze, dismiss)
- Sync: Ensure reminders sync across devices

---

## Implementation Priority

1. **Task Reminders with Notifications** - Higher priority as it enhances existing task functionality
2. **Voice Notes** - Requires more infrastructure (audio storage, playback UI)

## Notes

- Both features require careful consideration of permissions (microphone, notifications)
- Both features need robust sync implementation to work across devices
- Consider battery impact of background notification scheduling
- Consider storage impact of audio files
