const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// Triggered when a new message is created in Firestore
exports.sendMessageNotification = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversationId = message.conversationId;
    const senderId = message.senderId;
    const text = message.text || '📷 Image';
    const messageId = context.params.messageId;

    console.log(`New message ${messageId} in conversation ${conversationId}`);

    try {
      // Get conversation participants
      const convSnap = await db
        .collection('conversations')
        .doc(conversationId)
        .get();

      if (!convSnap.exists) {
        console.log('Conversation not found');
        return null;
      }

      const conversation = convSnap.data();
      const participants = conversation.participants || [];

      // Find the recipient (the one who is NOT the sender)
      const recipientId = participants.find((id) => id !== senderId);

      if (!recipientId) {
        console.log('No recipient found');
        return null;
      }

      // Get sender info for display name
      const senderSnap = await db.collection('users').doc(senderId).get();
      const senderData = senderSnap.data();
      const senderName = senderData?.displayName || senderData?.username || 'Partner';

      // Get recipient's FCM tokens
      const recipientSnap = await db.collection('users').doc(recipientId).get();
      const recipientData = recipientSnap.data();
      const tokens = [
        ...(recipientData?.fcmTokens || []),
        recipientData?.fcmToken,
      ].filter(Boolean);
      const fcmTokens = [...new Set(tokens)];

      if (fcmTokens.length === 0) {
        console.log('Recipient has no FCM token');
        return null;
      }

      const messagePayload = {
        notification: {
          title: senderName,
          body: text,
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          senderId: senderId,
          type: 'new_message',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'lovelink_messages',
            priority: 'high',
            sound: 'default',
            icon: '@mipmap/ic_launcher',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'content-available': 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast({
        ...messagePayload,
        tokens: fcmTokens,
      });
      console.log(
        `Notifications sent: ${response.successCount}, failed: ${response.failureCount}`,
      );

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        const code = result.error?.code;
        if (
          code === 'messaging/invalid-argument' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(fcmTokens[index]);
        }
      });

      if (invalidTokens.length > 0) {
        await recipientSnap.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
      }

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Triggered when a user's online status changes
exports.updateUserPresence = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // If user goes offline, update lastSeen
    if (before.isOnline === true && after.isOnline === false) {
      await change.after.ref.update({
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });
