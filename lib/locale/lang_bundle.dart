import 'package:flutter/material.dart';

class LangBundle {
  final Locale locale;

  LangBundle(this.locale);

  static LangBundle? of(BuildContext context) {
    return Localizations.of<LangBundle>(context, LangBundle);
  }

  static const LocalizationsDelegate<LangBundle> delegate = _LangBundleDelegate();

  static final Map<String, Map<String, String>> _strings = {
    'en': {
      'welcome_back': 'Welcome Back',
      'enter_phone': 'Enter your phone number to continue',
      'phone_number': 'Phone Number',
      'send_otp': 'Send OTP',
      'verification': 'Verification',
      'code_sent_to': 'We sent a code to',
      'verify': 'Verify',
      'resend_code': 'Resend Code',
      'home': 'Home',
      'chats': 'Chats',
      'wallet': 'Wallet',
      'account': 'Account',
      'find_match': 'Find Your Match',
      'connect_instantly': 'Connect with people nearby instantly',
      'coins': 'Coins',
      'language_name': 'English',
      'tagline': 'Spice Up Your Connections.',
    },
    'hi': {
      'welcome_back': 'वापसी पर स्वागत है',
      'enter_phone': 'जारी रखने के लिए अपना फोन नंबर दर्ज करें',
      'phone_number': 'फोन नंबर',
      'send_otp': 'OTP भेजें',
      'verification': 'सत्यापन',
      'code_sent_to': 'हमने कोड भेजा है',
      'verify': 'सत्यापित करें',
      'resend_code': 'कोड फिर से भेजें',
      'home': 'होम',
      'chats': 'चैट',
      'wallet': 'वॉलेट',
      'account': 'खाता',
      'find_match': 'अपना मैच खोजें',
      'connect_instantly': 'आस-पास के लोगों से तुरंत जुड़ें',
      'coins': 'सिक्के',
      'language_name': 'हिंदी',
      'tagline': 'अपने कनेक्शन को और भी मजेदार बनाएं।',
    },
    'ta': {
      'welcome_back': 'மீண்டும் வரவேற்கிறோம்',
      'enter_phone': 'தொடர உங்கள் தொலைபேசி எண்ணை உள்ளிடவும்',
      'phone_number': 'தொலைபேசி எண்',
      'send_otp': 'OTP அனுப்பு',
      'verification': 'சரிபார்ப்பு',
      'code_sent_to': 'நாங்கள் குறியீட்டை அனுப்பியுள்ளோம்',
      'verify': 'சரிபார்க்கவும்',
      'resend_code': 'குறியீட்டை மீண்டும் அனுப்பு',
      'home': 'முகப்பு',
      'chats': 'அரட்டைகள்',
      'wallet': 'பணப்பை',
      'account': 'கணக்கு',
      'find_match': 'உங்கள் பொருத்தத்தை கண்டறியவும்',
      'connect_instantly': 'அருகிலுள்ளவர்களுடன் உடனடியாக இணைக்கவும்',
      'coins': 'நாணயங்கள்',
      'language_name': 'தமிழ்',
    },
    'te': {
      'welcome_back': 'తిరిగి స్వాగతం',
      'enter_phone': 'కొనసాగించడానికి మీ ఫోన్ నంబర్‌ను నమోదు చేయండి',
      'phone_number': 'ఫోన్ నంబర్',
      'send_otp': 'OTP పంపండి',
      'verification': 'ధృవీకరణ',
      'code_sent_to': 'మేము కోడ్ పంపాము',
      'verify': 'ధృవీకరించండి',
      'resend_code': 'కోడ్‌ను మళ్లీ పంపండి',
      'home': 'హోమ్',
      'chats': 'చాట్‌లు',
      'wallet': 'వాలెట్',
      'account': 'ఖాతా',
      'find_match': 'మీ మ్యాచ్‌ను కనుగొనండి',
      'connect_instantly': 'సమీపంలోని వ్యక్తులతో తక్షణమే కనెక్ట్ అవ్వండి',
      'coins': 'నాణేలు',
      'language_name': 'తెలుగు',
      'tagline': 'మీ కనెక్షన్లను మసాలా చేయండి.',
    },
    'mr': {
      'welcome_back': 'परत स्वागत आहे',
      'enter_phone': 'सुरू ठेवण्यासाठी तुमचा फोन नंबर प्रविष्ट करा',
      'phone_number': 'फोन नंबर',
      'send_otp': 'OTP पाठवा',
      'verification': 'पडताळणी',
      'code_sent_to': 'आम्ही कोड पाठवला आहे',
      'verify': 'सत्यापित करा',
      'resend_code': 'कोड पुन्हा पाठवा',
      'home': 'होम',
      'chats': 'चॅट',
      'wallet': 'वॉलेट',
      'account': 'खाते',
      'find_match': 'तुमचा जुळणी शोधा',
      'connect_instantly': 'जवळच्या लोकांशी त्वरित कनेक्ट व्हा',
      'coins': 'नाणी',
      'language_name': 'मराठी',
    },
    'bn': {
      'welcome_back': 'ফিরে আসার স্বাগতম',
      'enter_phone': 'চালিয়ে যেতে আপনার ফোন নম্বর লিখুন',
      'phone_number': 'ফোন নম্বর',
      'send_otp': 'OTP পাঠান',
      'verification': 'যাচাইকরণ',
      'code_sent_to': 'আমরা কোড পাঠিয়েছি',
      'verify': 'যাচাই করুন',
      'resend_code': 'কোড আবার পাঠান',
      'home': 'হোম',
      'chats': 'চ্যাট',
      'wallet': 'ওয়ালেট',
      'account': 'অ্যাকাউন্ট',
      'find_match': 'আপনার ম্যাচ খুঁজুন',
      'connect_instantly': 'কাছাকাছি মানুষদের সাথে তাৎক্ষণিক সংযোগ করুন',
      'coins': 'কয়েন',
      'language_name': 'বাংলা',
    },
    'gu': {
      'welcome_back': 'પાછા સ્વાગત છે',
      'enter_phone': 'ચાલુ રાખવા માટે તમારો ફોન નંબર દાખલ કરો',
      'phone_number': 'ફોન નંબર',
      'send_otp': 'OTP મોકલો',
      'verification': 'ચકાસણી',
      'code_sent_to': 'અમે કોડ મોકલ્યો છે',
      'verify': 'ચકાસો',
      'resend_code': 'કોડ ફરીથી મોકલો',
      'home': 'હોમ',
      'chats': 'ચેટ',
      'wallet': 'વૉલેટ',
      'account': 'ખાતું',
      'find_match': 'તમારી મેચ શોધો',
      'connect_instantly': 'નજીકના લોકો સાથે તરત જ કનેક્ટ થાઓ',
      'coins': 'સિક્કા',
      'language_name': 'ગુજરાતી',
    },
    'kn': {
      'welcome_back': 'ಮರಳಿ ಸ್ವಾಗತ',
      'enter_phone': 'ಮುಂದುವರಿಸಲು ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
      'phone_number': 'ಫೋನ್ ಸಂಖ್ಯೆ',
      'send_otp': 'OTP ಕಳುಹಿಸಿ',
      'verification': 'ಪರಿಶೀಲನೆ',
      'code_sent_to': 'ನಾವು ಕೋಡ್ ಕಳುಹಿಸಿದ್ದೇವೆ',
      'verify': 'ಪರಿಶೀಲಿಸಿ',
      'resend_code': 'ಕೋಡ್ ಮರು ಕಳುಹಿಸಿ',
      'home': 'ಮುಖಪুಟ',
      'chats': 'ಚಾಟ್‌ಗಳು',
      'wallet': 'ವಾಲೆಟ್',
      'account': 'ಖಾತೆ',
      'find_match': 'ನಿಮ್ಮ ಹೊಂದಾಣಿಕೆಯನ್ನು ಹುಡುಕಿ',
      'connect_instantly': 'ಹತ್ತಿರದ ಜನರೊಂದಿಗೆ ತಕ್ಷಣ ಸಂಪರ್ಕಿಸಿ',
      'coins': 'ನಾಣ್ಯಗಳು',
      'language_name': 'ಕನ್ನಡ',
    },
    'ml': {
      'welcome_back': 'തിരിച്ചുവരവിനെ സ്വാഗതം',
      'enter_phone': 'തുടരാൻ നിങ്ങളുടെ ഫോൺ നമ്പർ നൽകുക',
      'phone_number': 'ഫോൺ നമ്പർ',
      'send_otp': 'OTP അയയ്ക്കുക',
      'verification': 'പരിശോധന',
      'code_sent_to': 'ഞങ്ങൾ കോഡ് അയച്ചു',
      'verify': 'പരിശോധിക്കുക',
      'resend_code': 'കോഡ് വീണ്ടും അയയ്ക്കുക',
      'home': 'ഹോം',
      'chats': 'ചാറ്റുകൾ',
      'wallet': 'വാലറ്റ്',
      'account': 'അക്കൗണ്ട്',
      'find_match': 'നിങ്ങളുടെ പൊരുത്തം കണ്ടെത്തുക',
      'connect_instantly': 'സമീപത്തുള്ള ആളുകളുമായി ഉടൻ ബന്ധപ്പെടുക',
      'coins': 'നാണയങ്ങൾ',
      'language_name': 'മലയാളം',
    },
    'pa': {
      'welcome_back': 'ਵਾਪਸ ਜੀ ਆਇਆਂ ਨੂੰ',
      'enter_phone': 'ਜਾਰੀ ਰੱਖਣ ਲਈ ਆਪਣਾ ਫ਼ੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ',
      'phone_number': 'ਫ਼ੋਨ ਨੰਬਰ',
      'send_otp': 'OTP ਭੇਜੋ',
      'verification': 'ਤਸਦੀਕ',
      'code_sent_to': 'ਅਸੀਂ ਕੋਡ ਭੇਜਿਆ ਹੈ',
      'verify': 'ਤਸਦੀਕ ਕਰੋ',
      'resend_code': 'ਕੋਡ ਦੁਬਾਰਾ ਭੇਜੋ',
      'home': 'ਹੋਮ',
      'chats': 'ਚੈਟਸ',
      'wallet': 'ਵਾਲਿਟ',
      'account': 'ਖਾਤਾ',
      'find_match': 'ਆਪਣਾ ਮੈਚ ਲੱਭੋ',
      'connect_instantly': 'ਨੇੜਲੇ ਲੋਕਾਂ ਨਾਲ ਤੁਰੰਤ ਜੁੜੋ',
      'coins': 'ਸਿੱਕੇ',
      'language_name': 'ਪੰਜਾਬੀ',
    },
    'or': {
      'welcome_back': 'ପୁନର୍ବାର ସ୍ୱାଗତ',
      'enter_phone': 'ଜାରି ରଖିବାକୁ ଆପଣଙ୍କ ଫୋନ୍ ନମ୍ବର ପ୍ରବେଶ କରନ୍ତୁ',
      'phone_number': 'ଫୋନ୍ ନମ୍ବର',
      'send_otp': 'OTP ପଠାନ୍ତୁ',
      'verification': 'ଯାଞ୍ଚ',
      'code_sent_to': 'ଆମେ କୋଡ୍ ପଠାଇଛୁ',
      'verify': 'ଯାଞ୍ଚ କରନ୍ତୁ',
      'resend_code': 'କୋଡ୍ ପୁନଃ ପଠାନ୍ତୁ',
      'home': 'ହୋମ୍',
      'chats': 'ଚାଟ୍',
      'wallet': 'ୱାଲେଟ୍',
      'account': 'ଖାତା',
      'find_match': 'ଆପଣଙ୍କ ମ୍ୟାଚ୍ ଖୋଜନ୍ତୁ',
      'connect_instantly': 'ନିକଟସ୍ଥ ଲୋକଙ୍କ ସହିତ ତୁରନ୍ତ ସଂଯୋଗ କରନ୍ତୁ',
      'coins': 'ମୁଦ୍ରା',
      'language_name': 'ଓଡ଼ିଆ',
    },
    'as': {
      'welcome_back': 'পুনৰ স্বাগতম',
      'enter_phone': 'অব্যাহত ৰাখিবলৈ আপোনাৰ ফোন নম্বৰ দিয়ক',
      'phone_number': 'ফোন নম্বৰ',
      'send_otp': 'OTP পঠিয়াওক',
      'verification': 'সত্যাপন',
      'code_sent_to': 'আমি কড পঠিয়াইছো',
      'verify': 'সত্যাপন কৰক',
      'resend_code': 'কড পুনৰ পঠিয়াওক',
      'home': 'হোম',
      'chats': 'চেট',
      'wallet': 'ৱালেট',
      'account': 'একাউণ্ট',
      'find_match': 'আপোনাৰ মিল বিচাৰক',
      'connect_instantly': 'ওচৰৰ মানুহৰ সৈতে তৎক্ষণাত সংযোগ কৰক',
      'coins': 'মুদ্ৰা',
      'language_name': 'অসমীয়া',
    },
  };

  String t(String key) {
    return _strings[locale.languageCode]?[key] ?? key;
  }

  String get welcomeBack => t('welcome_back');
  String get enterPhone => t('enter_phone');
  String get phoneNumber => t('phone_number');
  String get sendOtp => t('send_otp');
  String get verification => t('verification');
  String get codeSentTo => t('code_sent_to');
  String get verify => t('verify');
  String get resendCode => t('resend_code');
  String get home => t('home');
  String get chats => t('chats');
  String get wallet => t('wallet');
  String get account => t('account');
  String get findMatch => t('find_match');
  String get connectInstantly => t('connect_instantly');
  String get coins => t('coins');
  String get languageName => t('language_name');
  String get tagline => t('tagline');
}

class _LangBundleDelegate extends LocalizationsDelegate<LangBundle> {
  const _LangBundleDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi', 'ta', 'te', 'mr', 'bn', 'gu', 'kn', 'ml', 'pa', 'or', 'as']
        .contains(locale.languageCode);
  }

  @override
  Future<LangBundle> load(Locale locale) async {
    return LangBundle(locale);
  }

  @override
  bool shouldReload(_LangBundleDelegate old) => false;
}
