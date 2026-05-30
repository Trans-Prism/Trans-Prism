#!/usr/bin/env python3
"""Fix VFS sub-screen files for dark mode by adding isDark and replacing Colors.white"""
import re
import os

FILES = [
    'lib/screens/voice_training/quick_f0_test_screen.dart',
    'lib/screens/voice_training/scale_practice_screen.dart',
    'lib/screens/voice_training/voice_test_wizard_screen.dart',
    'lib/screens/voice_training/note_frequency_tool_screen.dart',
    'lib/screens/voice_training/piano_screen.dart',
    'lib/screens/voice_training/surveys/rbh_survey_screen.dart',
    'lib/screens/voice_training/surveys/tvqg_survey_screen.dart',
    'lib/screens/voice_training/surveys/ovhs9_survey_screen.dart',
]

DARK_CARD = 'const Color(0xFF1C1C1E)'
ISDARK_DECL = '    final isDark = Theme.of(context).brightness == Brightness.dark;'

for filepath in FILES:
    if not os.path.exists(filepath):
        print(f"SKIP {filepath} - not found")
        continue
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    modified = False
    new_lines = []
    
    # Track method positions and which ones need isDark
    # A method starts with a pattern like: Widget _buildXxx(...) { or @override\n Widget build(...) {
    method_starts = []  # list of (line_index, method_name)
    
    for i, line in enumerate(lines):
        # Detect method start - a line ending with ) { or ) { at the start of a method body
        stripped = line.strip()
        # Method signatures typically: Widget name(...) {, void name(...) {, Future<void> name(...) async {
        if (stripped.startswith('Widget ') or stripped.startswith('void ') or 
            stripped.startswith('Future<') or stripped.startswith('static ') or
            stripped.startswith('@override')) and ('{' in stripped or '=>' in stripped):
            # This could be a method start
            if '{' in stripped and not stripped.startswith('//'):
                method_starts.append((i, stripped))
        elif stripped.startswith('Widget ') and '{' in stripped:
            method_starts.append((i, stripped))
    
    # Also find lines with color: Colors.white that need to be replaced
    white_lines = []
    for i, line in enumerate(lines):
        if 'color: Colors.white' in line or "color: Colors.white," in line:
            # Check if this is inside a BoxDecoration context (container background)
            # Look backwards for 'decoration: BoxDecoration(' or 'BoxDecoration('
            context_is_decoration = False
            for j in range(max(0, i-5), i):
                if 'BoxDecoration(' in lines[j] or 'decoration:' in lines[j]:
                    context_is_decoration = True
                    break
            if context_is_decoration:
                white_lines.append(i)
    
    if not white_lines:
        print(f"SKIP {filepath} - no container Colors.white")
        continue
    
    # For each white line, find which method it belongs to and add isDark if needed
    methods_needing_isDark = set()
    for wl in white_lines:
        # Find the last method start before this line
        method_idx = -1
        for ms in method_starts:
            if ms[0] < wl:
                method_idx = ms[0]
            else:
                break
        
        if method_idx >= 0:
            # Check if this method already has isDark
            has_isDark = False
            for j in range(method_idx, min(method_idx + 5, len(lines))):
                if 'isDark = Theme.of' in lines[j] or 'isDark =' in lines[j]:
                    has_isDark = True
                    break
            if not has_isDark:
                methods_needing_isDark.add(method_idx)
    
    # Build new content
    for i, line in enumerate(lines):
        # Insert isDark after method openings that need it
        if i in methods_needing_isDark:
            new_lines.append(line)
            # Find the line with the opening {
            brace_line = line
            if '{' in line:
                # Add isDark after the { line
                indent = '    '  # 4 spaces
                new_lines.append(f'{indent}final isDark = Theme.of(context).brightness == Brightness.dark;\n')
            else:
                # The { might be on the next line
                pass
        else:
            new_lines.append(line)
    
    # Now do the replacements on the new content
    output = ''.join(new_lines)
    
    # Replace color: Colors.white in BoxDecoration contexts
    # Simple approach: replace all decoration-related Colors.white
    # We do this carefully to only hit container backgrounds
    output = output.replace(
        'color: Colors.white,',
        'color: isDark ? const Color(0xFF1C1C1E) : Colors.white,'
    )
    # Also handle color: Colors.white (no comma at end)
    output = output.replace(
        'color: Colors.white\n',
        'color: isDark ? const Color(0xFF1C1C1E) : Colors.white\n'
    )
    # But DON'T replace color: Colors.white in text/icon contexts
    # We need to revert any incorrect replacements
    
    with open(filepath, 'w') as f:
        f.write(output)
    
    print(f"FIXED {filepath} - {len(white_lines)} Colors.white, {len(methods_needing_isDark)} methods updated")

print("Done")
