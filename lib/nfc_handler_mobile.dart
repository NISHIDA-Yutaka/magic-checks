import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:uuid/uuid.dart';

// NFC読み取りセッションを開始する
void startNfcSession(BuildContext context) {
  NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
    try {
      final identifier = getNfcIdentifier(tag);
      if (identifier == 'unknown' || !context.mounted) {
        return;
      }
      final linkDoc = await FirebaseFirestore.instance
          .collection('nfc_links')
          .doc(identifier)
          .get();
      if (linkDoc.exists && context.mounted) {
        final data = linkDoc.data();
        if (data != null && data.containsKey('checklistId')) {
          final checklistId = data['checklistId'];
          context.go('/lists/$checklistId');
        }
      }
    } catch (e) {
      print('NFC read error: $e');
    }
  });
}

// NFCタグの固有IDを取得する
String getNfcIdentifier(NfcTag tag) {
  String identifier = 'unknown';
  final nfcA = NfcA.from(tag);
  if (nfcA != null) {
    return nfcA.identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
  }
  final isoDep = IsoDep.from(tag);
  if (isoDep != null) {
    return isoDep.identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
  }
  return identifier;
}

// NFCタグとリストを紐付ける
Future<void> linkNfcTag(BuildContext context, String checklistId, {required bool write}) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('お使いの端末はNFCに対応していません。')));
      return;
    }

    if (!context.mounted) return;
    scaffoldMessenger.showSnackBar(const SnackBar(
      content: Text('NFCタグをスマートフォンに近づけてください…'),
      duration: Duration(seconds: 10),
    ));

    await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      try {
        final identifier = getNfcIdentifier(tag);
        if (identifier == 'unknown') {
          if (!context.mounted) return;
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('このタグの固有IDを読み取れませんでした。')));
          await NfcManager.instance.stopSession(errorMessage: 'ID not found');
          return;
        }

        if (write) {
          final ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            if (!context.mounted) return;
            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('このタグは書き込みに対応していません。')));
            await NfcManager.instance.stopSession(errorMessage: 'Not writable');
            return;
          }
          final newId = const Uuid().v4();
          await ndef.write(NdefMessage([NdefRecord.createText(newId)]));
        }

        await FirebaseFirestore.instance.collection('nfc_links').doc(identifier).set({
          'userId': user.uid,
          'checklistId': checklistId,
        });

        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('NFCタグとの紐付けが完了しました！')));
        await NfcManager.instance.stopSession();
      } catch (e) {
        await NfcManager.instance.stopSession(errorMessage: 'Link error: $e');
      }
    });
  } catch (e) {
    print('NFC Session start error: $e');
  }
}
