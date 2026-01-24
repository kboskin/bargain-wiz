import json

file_path = 'assets/config/remote_config_defaults.json'

with open(file_path, 'r') as f:
    data = json.load(f)

screens = json.loads(data['onboarding_screens'])

# Find the warmup screen
for screen in screens:
    if screen.get('type') == 'warmup':
        if 'metadata' not in screen or screen['metadata'] is None:
            screen['metadata'] = {}
            
        # Add the side text
        screen['metadata']['side_text'] = {
            "en": "Potential settings found!",
            "es": "¡Configuraciones potenciales encontradas!"
        }
        
        # Adjust size to fit side-by-side
        screen['metadata']['width'] = 200
        screen['metadata']['height'] = 200
        break

data['onboarding_screens'] = json.dumps(screens)

with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)

print("Successfully added side text to warmup screen.")
