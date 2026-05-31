import os
import re

SCREENS_DIR = r"c:\Users\itsme\Documents\Chilli\chilli\lib\screens"

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Generic replaces for dark theme hardcodings
    content = content.replace("Color(0xFF0F172A)", "Palette.background")
    content = content.replace("Color(0xFF1E293B)", "Palette.surface")
    
    # Text colors
    # We replace colors.white with Palette.textPrimary ONLY where it's for text or general icons
    # It's tricky to do blindly, so we'll do selective replaces.
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Processed {filepath}")

def main():
    for filename in os.listdir(SCREENS_DIR):
        if filename.endswith(".dart"):
            process_file(os.path.join(SCREENS_DIR, filename))

if __name__ == "__main__":
    main()
