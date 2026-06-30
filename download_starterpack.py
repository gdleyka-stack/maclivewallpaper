import os
import urllib.request

categories = {
    "Nature": [
        "https://upload.wikimedia.org/wikipedia/commons/4/4d/A_River_in_a_Forest.mp4",
        "https://upload.wikimedia.org/wikipedia/commons/b/b5/Rain_Drops_Falling_in_Slow_Motion.mp4"
    ],
    "Space": [
        "https://upload.wikimedia.org/wikipedia/commons/7/7b/Earth_Zoom_In.mp4"
    ],
    "City": [
        "https://upload.wikimedia.org/wikipedia/commons/0/05/Sunrise_over_the_city.mp4"
    ]
}

base_dir = "/Users/artem/Desktop/MY/projects/livewallpaper/starterpack"
os.makedirs(base_dir, exist_ok=True)

for category, urls in categories.items():
    cat_dir = os.path.join(base_dir, category)
    os.makedirs(cat_dir, exist_ok=True)
    for idx, url in enumerate(urls):
        filename = f"video_{idx + 1}.mp4"
        filepath = os.path.join(cat_dir, filename)
        if not os.path.exists(filepath) or os.path.getsize(filepath) < 1000:
            print(f"Downloading {category}/{filename} from {url}...")
            try:
                # add user agent to avoid 403
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req) as response, open(filepath, 'wb') as out_file:
                    out_file.write(response.read())
                print(f"Saved to {filepath}")
            except Exception as e:
                print(f"Error downloading {url}: {e}")
        else:
            print(f"{category}/{filename} already exists.")

print("Starter pack populated.")
