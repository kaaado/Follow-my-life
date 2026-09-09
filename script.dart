import 'dart:io';

void main() {
  final file = File('w:/Document/Follow_My_Life/lib/core/localization/app_localizations.dart');
  var content = file.readAsStringSync();

  final additionsEn = '''      \\'cat_food\\': \\'Food\\',
      \\'cat_transport\\': \\'Transport\\',
      \\'cat_housing\\': \\'Housing\\',
      \\'cat_bills\\': \\'Bills\\',
      \\'cat_shopping\\': \\'Shopping\\',
      \\'cat_health\\': \\'Health\\',
      \\'cat_education\\': \\'Education\\',
      \\'cat_entertainment\\': \\'Entertainment\\',
      \\'cat_family\\': \\'Family\\',
      \\'cat_savings\\': \\'Savings\\',
      \\'cat_emergency\\': \\'Emergency\\',
      \\'cat_other\\': \\'Other\\',''';

  final additionsFr = '''      \\'cat_food\\': \\'Alimentation\\',
      \\'cat_transport\\': \\'Transport\\',
      \\'cat_housing\\': \\'Logement\\',
      \\'cat_bills\\': \\'Factures\\',
      \\'cat_shopping\\': \\'Shopping\\',
      \\'cat_health\\': \\'Santé\\',
      \\'cat_education\\': \\'Éducation\\',
      \\'cat_entertainment\\': \\'Divertissement\\',
      \\'cat_family\\': \\'Famille\\',
      \\'cat_savings\\': \\'Épargne\\',
      \\'cat_emergency\\': \\'Urgence\\',
      \\'cat_other\\': \\'Autre\\',''';

  final additionsAr = '''      \\'cat_food\\': \\'طعام\\',
      \\'cat_transport\\': \\'نقل\\',
      \\'cat_housing\\': \\'سكن\\',
      \\'cat_bills\\': \\'فواتير\\',
      \\'cat_shopping\\': \\'تسوق\\',
      \\'cat_health\\': \\'صحة\\',
      \\'cat_education\\': \\'تعليم\\',
      \\'cat_entertainment\\': \\'ترفيه\\',
      \\'cat_family\\': \\'عائلة\\',
      \\'cat_savings\\': \\'مدخرات\\',
      \\'cat_emergency\\': \\'طوارئ\\',
      \\'cat_other\\': \\'أخرى\\',''';

  content = content.replaceFirst('\\'en\\': {', '\\'en\\': {\\n\');
  content = content.replaceFirst('\\'fr\\': {', '\\'fr\\': {\\n\');
  content = content.replaceFirst('\\'ar\\': {', '\\'ar\\': {\\n\');

  file.writeAsStringSync(content);
  print('Done');
}
