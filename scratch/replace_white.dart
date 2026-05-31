import 'dart:io';

void main() {
  final files = [
    r'c:\Users\itsme\Documents\Chilli\chilli\lib\screens\onboard_screen.dart',
    r'c:\Users\itsme\Documents\Chilli\chilli\lib\screens\wallet_screen.dart',
    r'c:\Users\itsme\Documents\Chilli\chilli\lib\screens\lang_screen.dart',
  ];

  for (var path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;
    
    String content = file.readAsStringSync();
    
    // Safe replacements for overlays and borders
    content = content.replaceAll('Colors.white.withOpacity(0.1)', 'Palette.textPrimary.withOpacity(0.1)');
    content = content.replaceAll('Colors.white.withOpacity(0.05)', 'Palette.textPrimary.withOpacity(0.05)');
    content = content.replaceAll('Colors.white.withOpacity(0.2)', 'Palette.textPrimary.withOpacity(0.2)');
    content = content.replaceAll('Colors.white.withOpacity(0.3)', 'Palette.textPrimary.withOpacity(0.3)');
    content = content.replaceAll('Colors.white.withOpacity(0.4)', 'Palette.textPrimary.withOpacity(0.4)');
    content = content.replaceAll('Colors.white.withOpacity(0.5)', 'Palette.textSecondary');
    content = content.replaceAll('Colors.white.withOpacity(0.6)', 'Palette.textSecondary');
    content = content.replaceAll('Colors.white.withOpacity(0.7)', 'Palette.textPrimary.withOpacity(0.7)');
    content = content.replaceAll('Colors.white.withOpacity(0.8)', 'Palette.textPrimary.withOpacity(0.8)');
    content = content.replaceAll('Colors.white.withOpacity(0.9)', 'Palette.textPrimary.withOpacity(0.9)');
    
    // Replace text color styles carefully
    content = content.replaceAll('textColor: Colors.white,', 'textColor: Palette.textPrimary,');
    content = content.replaceAll('color: Colors.white,', 'color: Palette.textPrimary,');
    content = content.replaceAll('color: Colors.white)', 'color: Palette.textPrimary)');
    
    // Revert inside known buttons (rough heuristics)
    content = content.replaceAll('CircularProgressIndicator(color: Palette.textPrimary', 'CircularProgressIndicator(color: Colors.white');
    content = content.replaceAll('foregroundColor: Palette.textPrimary', 'foregroundColor: Colors.white');
    content = content.replaceAll('Color(0xFF06B6D4) : Palette.textPrimary.withOpacity(0.1)', 'Color(0xFF06B6D4) : Colors.white.withOpacity(0.1)'); // Revert if needed? No, wait, if background is white, inactive should be dark overlay.
    
    file.writeAsStringSync(content);
    print('Processed \$path');
  }
}
