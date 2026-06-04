import re
import sys

def parse_g_kt(filepath):
    data_classes = {}
    current_class = None
    with open(filepath, 'r') as f:
        lines = f.readlines()
        for line in lines:
            line = line.strip()
            match = re.match(r'^data class (Tl[A-Za-z0-Config]+)\s*\(', line)
            if match:
                current_class = match.group(1)
                data_classes[current_class] = []
                continue
            if current_class:
                if line.startswith('val '):
                    # e.g., val desiredAccuracy: TlDesiredAccuracy,
                    field_match = re.match(r'^val\s+([a-zA-Z0-9_]+)\s*:', line)
                    if field_match:
                        data_classes[current_class].append(field_match.group(1))
                if line.startswith(')'):
                    current_class = None
    return data_classes

def parse_host_api(filepath):
    mappings = {}
    current_section = None
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Very rudimentary parsing
    # look for put("section", buildMap { ... })
    
    for section_match in re.finditer(r'put\("([a-zA-Z0-9_]+)", buildMap \{(.*?)\}\)', content, re.DOTALL):
        section = section_match.group(1)
        body = section_match.group(2)
        fields = []
        for put_match in re.finditer(r'put\("([a-zA-Z0-9_]+)"', body):
            fields.append(put_match.group(1))
        mappings[section] = fields
        
    return mappings

g_kt_path = "/Users/admin/Documents/Tracelet/packages/tracelet_android/android/src/main/kotlin/com/ikolvi/tracelet/TraceletApi.g.kt"
host_api_path = "/Users/admin/Documents/Tracelet/packages/tracelet_android/android/src/main/kotlin/com/ikolvi/tracelet/flutter/TraceletHostApiImpl.kt"

data_classes = parse_g_kt(g_kt_path)
mappings = parse_host_api(host_api_path)

# Manual mapping of Tl*Config to section names
config_to_section = {
    'TlGeoConfig': 'geo',
    'TlAppConfig': 'app',
    'TlAndroidConfig': 'android',
    'TlIosConfig': 'ios',
    'TlHttpConfig': 'http',
    'TlLoggerConfig': 'logger',
    'TlMotionConfig': 'motion',
    'TlGeofenceConfig': 'geofence',
    'TlPersistenceConfig': 'persistence',
    'TlAuditConfig': 'audit',
    'TlPrivacyZoneConfig': 'privacyZone',
    'TlSecurityConfig': 'security',
    'TlAttestationConfig': 'attestation'
}

missing_any = False

for tl_class, section in config_to_section.items():
    if section not in mappings:
        if tl_class == 'TlIosConfig':
            continue # iOS is obviously not in Android's mapping
        print(f"Section {section} not found in mappings!")
        continue
    
    fields = data_classes.get(tl_class, [])
    mapped_fields = mappings[section]
    
    missing = [f for f in fields if f not in mapped_fields]
    # Special cases handling
    missing_filtered = []
    for m in missing:
        if m in mapped_fields:
            continue
        missing_filtered.append(m)
        
    if missing_filtered:
        print(f"Missing in {tl_class} (mapped to '{section}'): {missing_filtered}")
        missing_any = True

if not missing_any:
    print("All fields correctly mapped!")

