import 'dart:io';

void main() {
  final dir = Directory(r'c:\Users\itsme\Documents\Chilli\chilli\lib\screens');
  
  if (!dir.existsSync()) {
    print('Directory not found');
    return;
  }
  
  for (var file in dir.listSync()) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      
      bool changed = false;
      if (content.contains('Color(0xFF0F172A)')) {
        content = content.replaceAll('Color(0xFF0F172A)', 'Color(0xFFFFFFFF)');
        changed = true;
      }
      if (content.contains('Color(0xFF1E293B)')) {
        content = content.replaceAll('Color(0xFF1E293B)', 'Color(0xFFF8FAFC)');
        changed = true;
      }
      
      if (changed) {
        file.writeAsStringSync(content);
        print('Processed \${file.path}');
      }
    }
  }
}
