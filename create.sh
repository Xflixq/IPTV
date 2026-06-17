mkdir -p .github/workflows

cat > channels.json << 'EOF'
{
  "BBC One": ["BBC One London","BBC One NW","BBC One HD"],
  "BBC Two": ["BBC Two HD"],
  "ITV1": ["ITV1 Granada","ITV1 London","ITV1 HD"],
  "Channel 4": ["Channel 4 HD"],
  "Channel 5": ["5","Channel 5 HD"],
  "ITV2": ["ITV2 HD"],
  "BBC Three": ["BBC Three HD"],
  "BBC Four": ["BBC Four HD"],
  "ITV3": ["ITV3 HD"],
  "ITV4": ["ITV4 HD"],
  "E4": ["E4 HD"],
  "More4": ["More4 HD"],
  "Film4": ["Film4 HD"],
  "BBC News": ["BBC News HD"],
  "Sky News": ["Sky News"]
}
EOF

cat > build.py << 'EOF'
import requests
import json

SOURCE = "https://iptv-org.github.io/iptv/countries/uk.m3u"

with open("channels.json", encoding="utf-8") as f:
    mapping = json.load(f)

def normalize(name):
    return name.strip().lower()

wanted = {}
for new_name, aliases in mapping.items():
    wanted[new_name] = set(normalize(alias) for alias in [new_name] + aliases)

playlist = requests.get(SOURCE, timeout=30).text.splitlines()

entries = []
i = 0

while i < len(playlist):
    if playlist[i].startswith("#EXTINF"):
        name = playlist[i].split(",")[-1].strip()

        if i + 1 < len(playlist):
            url = playlist[i + 1]
            entries.append({
                "name": name,
                "normalized_name": normalize(name),
                "extinf": playlist[i],
                "url": url
            })
    i += 1

out = ["#EXTM3U"]

channel_no = 1

for target in mapping:
    for entry in entries:
        if entry["normalized_name"] in wanted[target]:

            extinf = entry["extinf"]
            extinf = extinf[:extinf.rfind(",")] + "," + target

            if 'tvg-chno="' not in extinf:
                extinf = extinf.replace(
                    "#EXTINF:-1",
                    f'#EXTINF:-1 tvg-chno="{channel_no}"'
                )

            out.append(extinf)
            out.append(entry["url"])
            out.append("")

            channel_no += 1
            break

with open("iptv.m3u", "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print("Generated iptv.m3u")
EOF

cat > .github/workflows/update.yml << 'EOF'
name: Update Freeview Playlist

on:
  workflow_dispatch:

  schedule:
    - cron: "0 3 * * *"

jobs:
  update:
    runs-on: ubuntu-latest

    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - run: pip install requests

      - run: python build.py

      - name: Commit changes
        run: |
          git config user.name "github-actions"
          git config user.email "actions@github.com"

          git add freeview.m3u

          git diff --cached --quiet || git commit -m "Update playlist"

          git push
EOF

cat > README.md << 'EOF'
# Freeview IPTV Playlist

Automatically generated from IPTV-org UK playlist.

Playlist URL:

https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/freeview.m3u
EOF

pip install requests
python build.py

echo "Project created successfully."