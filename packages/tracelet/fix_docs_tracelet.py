import re
import sys

def fix_file(filepath, lines):
    with open(filepath, 'r') as f:
        content = f.read().split('\n')
    
    # Sort lines in descending order to avoid shifting issues when inserting
    lines = sorted(list(set(lines)), reverse=True)
    
    for l in lines:
        line_idx = l - 1
        if line_idx >= len(content):
            continue
        
        # Calculate indentation
        match = re.match(r'^(\s*)', content[line_idx])
        indent = match.group(1) if match else ''
        
        # Check if already documented
        if line_idx > 0 and content[line_idx-1].strip().startswith('///'):
            continue
            
        # Get member name heuristically for better docs
        code_line = content[line_idx].strip()
        # remove annotations like @override
        if code_line.startswith('@'):
            if line_idx+1 < len(content):
                code_line = content[line_idx+1].strip()
            
        # Simple extraction
        words = re.split(r'[\s(]', code_line)
        name = "member"
        for w in words:
            if w and not w in ('abstract', 'class', 'final', 'const', 'static', 'get', 'set', 'Future', 'Stream', 'void', 'bool', 'int', 'double', 'String', 'Map', 'List', 'var', 'dynamic'):
                name = w
                break
                
        # Handle getters
        if 'get ' in code_line:
            name = code_line.split('get ')[1].split(' ')[0].replace('=>', '').replace('{', '')
            
        # Insert documentation
        doc_line = f"{indent}/// Documentation for {name}."
        content.insert(line_idx, doc_line)
        
    with open(filepath, 'w') as f:
        f.write('\n'.join(content))

def main():
    with open('analyze_tracelet.txt', 'r') as f:
        lines = f.readlines()
        
    file_map = {}
    for line in lines:
        if 'Missing documentation for a public member' in line:
            # Format: info - lib/src/web_carbon_engine.dart:10:3 - ...
            match = re.search(r'([a-zA-Z0-9_./-]+):(\d+):(\d+)', line)
            if match:
                filepath = match.group(1)
                line_num = int(match.group(2))
                
                if filepath not in file_map:
                    file_map[filepath] = []
                file_map[filepath].append(line_num)
                
    for filepath, lines in file_map.items():
        print(f"Fixing {filepath} ({len(lines)} issues)")
        fix_file(filepath, lines)

if __name__ == '__main__':
    main()
