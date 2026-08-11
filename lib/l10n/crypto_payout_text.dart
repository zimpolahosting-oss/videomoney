import 'package:flutter/widgets.dart';

class CryptoPayoutText {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Payout to your BTC wallet address',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle': 'Payout to your USDC Polygon wallet address',
      'bitcoinAddressLabel': 'BTC wallet address',
      'usdcPolygonAddressLabel': 'USDC Polygon wallet address',
      'pasteBitcoinAddress': 'Copy and paste your BTC address here',
      'pasteUsdcPolygonAddress':
          'Copy and paste your USDC Polygon address here',
      'enterBitcoinAddress': 'Enter your BTC address',
      'enterUsdcPolygonAddress': 'Enter your USDC Polygon address',
    },
    'nl': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Uitbetaling naar je BTC-walletadres',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Uitbetaling naar je USDC Polygon-walletadres',
      'bitcoinAddressLabel': 'BTC-walletadres',
      'usdcPolygonAddressLabel': 'USDC Polygon-walletadres',
      'pasteBitcoinAddress': 'Kopieer en plak hier je BTC-adres',
      'pasteUsdcPolygonAddress':
          'Kopieer en plak hier je USDC Polygon-adres',
      'enterBitcoinAddress': 'Voer je BTC-adres in',
      'enterUsdcPolygonAddress': 'Voer je USDC Polygon-adres in',
    },
    'hi': {
      'bitcoinTitle': 'बिटकॉइन',
      'bitcoinSubtitle': 'अपना BTC वॉलेट पता देकर भुगतान पाएं',
      'usdcPolygonTitle': 'USDC पॉलीगॉन',
      'usdcPolygonSubtitle': 'अपने USDC पॉलीगॉन वॉलेट पते पर भुगतान पाएं',
      'bitcoinAddressLabel': 'BTC वॉलेट पता',
      'usdcPolygonAddressLabel': 'USDC पॉलीगॉन वॉलेट पता',
      'pasteBitcoinAddress': 'अपना BTC पता यहाँ कॉपी और पेस्ट करें',
      'pasteUsdcPolygonAddress':
          'अपना USDC पॉलीगॉन पता यहाँ कॉपी और पेस्ट करें',
      'enterBitcoinAddress': 'अपना BTC पता दर्ज करें',
      'enterUsdcPolygonAddress': 'अपना USDC पॉलीगॉन पता दर्ज करें',
    },
    'de': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Auszahlung an deine BTC-Wallet-Adresse',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Auszahlung an deine USDC-Polygon-Wallet-Adresse',
      'bitcoinAddressLabel': 'BTC-Wallet-Adresse',
      'usdcPolygonAddressLabel': 'USDC-Polygon-Wallet-Adresse',
      'pasteBitcoinAddress': 'Kopiere deine BTC-Adresse hier hinein',
      'pasteUsdcPolygonAddress':
          'Kopiere deine USDC-Polygon-Adresse hier hinein',
      'enterBitcoinAddress': 'Gib deine BTC-Adresse ein',
      'enterUsdcPolygonAddress': 'Gib deine USDC-Polygon-Adresse ein',
    },
    'es': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Pago a tu dirección de billetera BTC',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Pago a tu dirección de billetera USDC Polygon',
      'bitcoinAddressLabel': 'Dirección de billetera BTC',
      'usdcPolygonAddressLabel': 'Dirección de billetera USDC Polygon',
      'pasteBitcoinAddress': 'Copia y pega aquí tu dirección BTC',
      'pasteUsdcPolygonAddress':
          'Copia y pega aquí tu dirección USDC Polygon',
      'enterBitcoinAddress': 'Introduce tu dirección BTC',
      'enterUsdcPolygonAddress': 'Introduce tu dirección USDC Polygon',
    },
    'fr': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Paiement vers votre adresse de portefeuille BTC',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Paiement vers votre adresse de portefeuille USDC Polygon',
      'bitcoinAddressLabel': 'Adresse de portefeuille BTC',
      'usdcPolygonAddressLabel': 'Adresse de portefeuille USDC Polygon',
      'pasteBitcoinAddress': 'Copiez et collez votre adresse BTC ici',
      'pasteUsdcPolygonAddress':
          'Copiez et collez votre adresse USDC Polygon ici',
      'enterBitcoinAddress': 'Saisissez votre adresse BTC',
      'enterUsdcPolygonAddress': 'Saisissez votre adresse USDC Polygon',
    },
    'ru': {
      'bitcoinTitle': 'Биткоин',
      'bitcoinSubtitle': 'Выплата на ваш BTC-кошелёк',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle': 'Выплата на ваш кошелёк USDC Polygon',
      'bitcoinAddressLabel': 'Адрес BTC-кошелька',
      'usdcPolygonAddressLabel': 'Адрес кошелька USDC Polygon',
      'pasteBitcoinAddress': 'Скопируйте и вставьте сюда ваш BTC-адрес',
      'pasteUsdcPolygonAddress':
          'Скопируйте и вставьте сюда ваш адрес USDC Polygon',
      'enterBitcoinAddress': 'Введите ваш BTC-адрес',
      'enterUsdcPolygonAddress': 'Введите ваш адрес USDC Polygon',
    },
    'el': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Πληρωμή στη διεύθυνση πορτοφολιού BTC',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Πληρωμή στη διεύθυνση πορτοφολιού USDC Polygon',
      'bitcoinAddressLabel': 'Διεύθυνση πορτοφολιού BTC',
      'usdcPolygonAddressLabel': 'Διεύθυνση πορτοφολιού USDC Polygon',
      'pasteBitcoinAddress': 'Αντιγράψτε και επικολλήστε εδώ τη διεύθυνση BTC',
      'pasteUsdcPolygonAddress':
          'Αντιγράψτε και επικολλήστε εδώ τη διεύθυνση USDC Polygon',
      'enterBitcoinAddress': 'Εισαγάγετε τη διεύθυνση BTC σας',
      'enterUsdcPolygonAddress':
          'Εισαγάγετε τη διεύθυνση USDC Polygon σας',
    },
    'pt': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Pagamento para o seu endereço de carteira BTC',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Pagamento para o seu endereço de carteira USDC Polygon',
      'bitcoinAddressLabel': 'Endereço da carteira BTC',
      'usdcPolygonAddressLabel': 'Endereço da carteira USDC Polygon',
      'pasteBitcoinAddress': 'Copie e cole aqui o seu endereço BTC',
      'pasteUsdcPolygonAddress':
          'Copie e cole aqui o seu endereço USDC Polygon',
      'enterBitcoinAddress': 'Introduza o seu endereço BTC',
      'enterUsdcPolygonAddress': 'Introduza o seu endereço USDC Polygon',
    },
    'it': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Pagamento al tuo indirizzo wallet BTC',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Pagamento al tuo indirizzo wallet USDC Polygon',
      'bitcoinAddressLabel': 'Indirizzo wallet BTC',
      'usdcPolygonAddressLabel': 'Indirizzo wallet USDC Polygon',
      'pasteBitcoinAddress': 'Copia e incolla qui il tuo indirizzo BTC',
      'pasteUsdcPolygonAddress':
          'Copia e incolla qui il tuo indirizzo USDC Polygon',
      'enterBitcoinAddress': 'Inserisci il tuo indirizzo BTC',
      'enterUsdcPolygonAddress': 'Inserisci il tuo indirizzo USDC Polygon',
    },
    'tr': {
      'bitcoinTitle': 'Bitcoin',
      'bitcoinSubtitle': 'Ödeme BTC cüzdan adresinize yapılır',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'Ödeme USDC Polygon cüzdan adresinize yapılır',
      'bitcoinAddressLabel': 'BTC cüzdan adresi',
      'usdcPolygonAddressLabel': 'USDC Polygon cüzdan adresi',
      'pasteBitcoinAddress': 'BTC adresinizi buraya kopyalayıp yapıştırın',
      'pasteUsdcPolygonAddress':
          'USDC Polygon adresinizi buraya kopyalayıp yapıştırın',
      'enterBitcoinAddress': 'BTC adresinizi girin',
      'enterUsdcPolygonAddress': 'USDC Polygon adresinizi girin',
    },
    'ar': {
      'bitcoinTitle': 'بيتكوين',
      'bitcoinSubtitle': 'الدفع إلى عنوان محفظة BTC الخاصة بك',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle': 'الدفع إلى عنوان محفظة USDC Polygon الخاصة بك',
      'bitcoinAddressLabel': 'عنوان محفظة BTC',
      'usdcPolygonAddressLabel': 'عنوان محفظة USDC Polygon',
      'pasteBitcoinAddress': 'انسخ والصق عنوان BTC هنا',
      'pasteUsdcPolygonAddress': 'انسخ والصق عنوان USDC Polygon هنا',
      'enterBitcoinAddress': 'أدخل عنوان BTC الخاص بك',
      'enterUsdcPolygonAddress': 'أدخل عنوان USDC Polygon الخاص بك',
    },
    'bn': {
      'bitcoinTitle': 'বিটকয়েন',
      'bitcoinSubtitle': 'আপনার BTC ওয়ালেট ঠিকানায় পেআউট',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle': 'আপনার USDC Polygon ওয়ালেট ঠিকানায় পেআউট',
      'bitcoinAddressLabel': 'BTC ওয়ালেট ঠিকানা',
      'usdcPolygonAddressLabel': 'USDC Polygon ওয়ালেট ঠিকানা',
      'pasteBitcoinAddress': 'এখানে আপনার BTC ঠিকানা কপি-পেস্ট করুন',
      'pasteUsdcPolygonAddress':
          'এখানে আপনার USDC Polygon ঠিকানা কপি-পেস্ট করুন',
      'enterBitcoinAddress': 'আপনার BTC ঠিকানা লিখুন',
      'enterUsdcPolygonAddress': 'আপনার USDC Polygon ঠিকানা লিখুন',
    },
    'ta': {
      'bitcoinTitle': 'பிட்காயின்',
      'bitcoinSubtitle': 'உங்கள் BTC வாலெட் முகவரிக்கு பணம் அனுப்பப்படும்',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle':
          'உங்கள் USDC Polygon வாலெட் முகவரிக்கு பணம் அனுப்பப்படும்',
      'bitcoinAddressLabel': 'BTC வாலெட் முகவரி',
      'usdcPolygonAddressLabel': 'USDC Polygon வாலெட் முகவரி',
      'pasteBitcoinAddress': 'உங்கள் BTC முகவரியை இங்கு நகலெடுத்து ஒட்டவும்',
      'pasteUsdcPolygonAddress':
          'உங்கள் USDC Polygon முகவரியை இங்கு நகலெடுத்து ஒட்டவும்',
      'enterBitcoinAddress': 'உங்கள் BTC முகவரியை உள்ளிடவும்',
      'enterUsdcPolygonAddress':
          'உங்கள் USDC Polygon முகவரியை உள்ளிடவும்',
    },
    'te': {
      'bitcoinTitle': 'బిట్‌కాయిన్',
      'bitcoinSubtitle': 'మీ BTC వాలెట్ చిరునామాకు చెల్లింపు',
      'usdcPolygonTitle': 'USDC Polygon',
      'usdcPolygonSubtitle': 'మీ USDC Polygon వాలెట్ చిరునామాకు చెల్లింపు',
      'bitcoinAddressLabel': 'BTC వాలెట్ చిరునామా',
      'usdcPolygonAddressLabel': 'USDC Polygon వాలెట్ చిరునామా',
      'pasteBitcoinAddress': 'మీ BTC చిరునామాను ఇక్కడ కాపీ చేసి పేస్ట్ చేయండి',
      'pasteUsdcPolygonAddress':
          'మీ USDC Polygon చిరునామాను ఇక్కడ కాపీ చేసి పేస్ట్ చేయండి',
      'enterBitcoinAddress': 'మీ BTC చిరునామాను నమోదు చేయండి',
      'enterUsdcPolygonAddress':
          'మీ USDC Polygon చిరునామాను నమోదు చేయండి',
    },
  };

  static String _text(BuildContext context, String key) {
    final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();
    return _values[languageCode]?[key] ?? _values['en']![key]!;
  }

  static String bitcoinTitle(BuildContext context) =>
      _text(context, 'bitcoinTitle');
  static String bitcoinSubtitle(BuildContext context) =>
      _text(context, 'bitcoinSubtitle');
  static String usdcPolygonTitle(BuildContext context) =>
      _text(context, 'usdcPolygonTitle');
  static String usdcPolygonSubtitle(BuildContext context) =>
      _text(context, 'usdcPolygonSubtitle');
  static String bitcoinAddressLabel(BuildContext context) =>
      _text(context, 'bitcoinAddressLabel');
  static String usdcPolygonAddressLabel(BuildContext context) =>
      _text(context, 'usdcPolygonAddressLabel');
  static String pasteBitcoinAddress(BuildContext context) =>
      _text(context, 'pasteBitcoinAddress');
  static String pasteUsdcPolygonAddress(BuildContext context) =>
      _text(context, 'pasteUsdcPolygonAddress');
  static String enterBitcoinAddress(BuildContext context) =>
      _text(context, 'enterBitcoinAddress');
  static String enterUsdcPolygonAddress(BuildContext context) =>
      _text(context, 'enterUsdcPolygonAddress');
}
