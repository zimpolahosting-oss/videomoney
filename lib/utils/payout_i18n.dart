import 'package:flutter/widgets.dart';

class PayoutI18n {
  static String _code(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase();

  static String updateRequiredMessage(BuildContext context, String version) {
    final code = _code(context);
    const values = {
      'en': 'Update required. Payout is only available on {version} or higher.',
      'nl': 'Update vereist. Uitbetaling is alleen beschikbaar op {version} of hoger.',
      'hi': 'अपडेट आवश्यक है। भुगतान केवल {version} या उससे ऊपर पर उपलब्ध है।',
      'de': 'Update erforderlich. Auszahlungen sind nur mit {version} oder höher verfügbar.',
      'es': 'Actualización obligatoria. El pago solo está disponible en la versión {version} o superior.',
      'fr': 'Mise à jour requise. Le paiement est disponible uniquement sur {version} ou version ultérieure.',
      'ru': 'Требуется обновление. Выплата доступна только на версии {version} или выше.',
      'el': 'Απαιτείται ενημέρωση. Η πληρωμή είναι διαθέσιμη μόνο στην έκδοση {version} ή νεότερη.',
      'pt': 'Atualização necessária. O pagamento só está disponível na versão {version} ou superior.',
      'it': 'Aggiornamento richiesto. Il pagamento è disponibile solo sulla versione {version} o superiore.',
      'tr': 'Güncelleme gerekli. Ödeme yalnızca {version} veya üzeri sürümlerde kullanılabilir.',
      'ar': 'التحديث مطلوب. السحب متاح فقط على الإصدار {version} أو أعلى.',
      'bn': 'আপডেট প্রয়োজন। পেআউট শুধু {version} বা তার উপরের ভার্সনে পাওয়া যাবে।',
      'ta': 'புதுப்பிப்பு தேவை. பணப்பரிமாற்றம் {version} அல்லது அதற்கு மேற்பட்ட பதிப்பில் மட்டுமே கிடைக்கும்.',
      'te': 'అప్‌డేట్ అవసరం. చెల్లింపు {version} లేదా అంతకంటే పై వెర్షన్‌లో మాత్రమే అందుబాటులో ఉంటుంది.',
    };
    final template = values[code] ?? values['en']!;
    return template.replaceAll('{version}', version);
  }

  static String rejectReasonCodeLabel(BuildContext context, String code) {
    final language = _code(context);
    switch (code) {
      case 'new_build_only':
        const values = {
          'en': 'New build only',
          'nl': 'Alleen nieuwe build',
          'hi': 'केवल नया बिल्ड',
          'de': 'Nur neuer Build',
          'es': 'Solo nueva build',
          'fr': 'Nouvelle build uniquement',
          'ru': 'Только новая сборка',
          'el': 'Μόνο νέα build',
          'pt': 'Apenas nova build',
          'it': 'Solo nuova build',
          'tr': 'Sadece yeni build',
          'ar': 'إصدار جديد فقط',
          'bn': 'শুধু নতুন বিল্ড',
          'ta': 'புதிய build மட்டும்',
          'te': 'కొత్త build మాత్రమే',
        };
        return values[language] ?? values['en']!;
      case 'other':
        const values = {
          'en': 'Other reason',
          'nl': 'Andere reden',
          'hi': 'अन्य कारण',
          'de': 'Anderer Grund',
          'es': 'Otro motivo',
          'fr': 'Autre raison',
          'ru': 'Другая причина',
          'el': 'Άλλος λόγος',
          'pt': 'Outro motivo',
          'it': 'Altro motivo',
          'tr': 'Diğer neden',
          'ar': 'سبب آخر',
          'bn': 'অন্য কারণ',
          'ta': 'வேறு காரணம்',
          'te': 'ఇతర కారణం',
        };
        return values[language] ?? values['en']!;
      default:
        return code;
    }
  }

  static String localizedRejectReason(
    BuildContext context, {
    required String code,
    String minimumVersion = '',
    String note = '',
  }) {
    final language = _code(context);
    String message;
    switch (code) {
      case 'new_build_only':
        const values = {
          'en': 'New build only. Please update to {version} or higher and request payout again.',
          'nl': 'Alleen nieuwe build. Update naar {version} of hoger en vraag daarna opnieuw uitbetaling aan.',
          'hi': 'केवल नया बिल्ड। कृपया {version} या उससे ऊपर अपडेट करें और फिर से भुगतान अनुरोध भेजें।',
          'de': 'Nur neuer Build. Bitte auf {version} oder höher aktualisieren und die Auszahlung erneut anfordern.',
          'es': 'Solo nueva build. Actualiza a {version} o superior y vuelve a solicitar el pago.',
          'fr': 'Nouvelle build uniquement. Mettez à jour vers {version} ou plus récent puis refaites la demande.',
          'ru': 'Только новая сборка. Обновитесь до {version} или выше и запросите выплату снова.',
          'el': 'Μόνο νέα build. Ενημερώστε στην έκδοση {version} ή νεότερη και ζητήστε ξανά πληρωμή.',
          'pt': 'Apenas nova build. Atualize para {version} ou superior e peça o pagamento novamente.',
          'it': 'Solo nuova build. Aggiorna a {version} o superiore e richiedi di nuovo il pagamento.',
          'tr': 'Sadece yeni build. Lütfen {version} veya üstüne güncelleyin ve ödemeyi tekrar isteyin.',
          'ar': 'إصدار جديد فقط. حدّث إلى {version} أو أعلى ثم اطلب السحب مرة أخرى.',
          'bn': 'শুধু নতুন বিল্ড। অনুগ্রহ করে {version} বা তার উপরে আপডেট করে আবার পেআউট অনুরোধ করুন।',
          'ta': 'புதிய build மட்டும். {version} அல்லது அதற்கு மேல் புதுப்பித்து மீண்டும் payout கேளுங்கள்.',
          'te': 'కొత్త build మాత్రమే. దయచేసి {version} లేదా అంతకంటే పై వెర్షన్‌కి అప్‌డేట్ చేసి మళ్లీ చెల్లింపు అభ్యర్థించండి.',
        };
        message = (values[language] ?? values['en']!)
            .replaceAll('{version}', minimumVersion.isEmpty ? 'latest build' : minimumVersion);
        break;
      default:
        message = note.trim();
        break;
    }
    if (note.trim().isNotEmpty && code != 'other' && note.trim() != code) {
      message = '$message\n${note.trim()}';
    }
    return message.trim();
  }

  static String rejectReasonLabel(BuildContext context) {
    final code = _code(context);
    const values = {
      'en': 'Reject reason',
      'nl': 'Afwijsreden',
      'hi': 'अस्वीकृति कारण',
      'de': 'Ablehnungsgrund',
      'es': 'Motivo del rechazo',
      'fr': 'Motif du refus',
      'ru': 'Причина отклонения',
      'el': 'Λόγος απόρριψης',
      'pt': 'Motivo da rejeição',
      'it': 'Motivo del rifiuto',
      'tr': 'Reddetme nedeni',
      'ar': 'سبب الرفض',
      'bn': 'প্রত্যাখ্যানের কারণ',
      'ta': 'நிராகரிப்பு காரணம்',
      'te': 'తిరస్కరణ కారణం',
    };
    return values[code] ?? values['en']!;
  }
}
