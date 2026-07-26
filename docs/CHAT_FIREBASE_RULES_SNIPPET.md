# Chat Firebase rules — applied additively

Chat rules were **appended** to existing `firestore.rules` and `storage.rules`.
Existing appointment / patient / finance rules were **not** rewritten.

Deploy (when ready):

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Do **not** include hosting unless you intend to publish a web build.

## Message updates (reactions)

Participants may update only `reactions` / `readBy` on messages (WhatsApp-style reactions).
Senders and moderators may still update their own / any messages as before.

## Indexes

- `conversations`: `participantIds` CONTAINS + `lastMessageAt` DESC

## Cloud Functions (additive)

- `onChatMessageCreated` — FCM to other participants (respects quiet hours in `app_settings/chat`)
- `cleanupExpiredChatMessages` — daily retention cleanup when `retentionDays > 0`

Existing appointment functions are unchanged.
