#!/bin/bash

set -e

echo "Creating IPTV project..."

mkdir -p .github/workflows

cat > channels.json << 'EOF'
{
  "1": ["BBC One"],
  "2": ["BBC Two"],
  "3": ["ITV1"],
  "4": ["Channel 4"],
  "5": ["Channel 5"],
  "6": ["ITV2"],
  "7": ["BBC Three"],
  "9": ["BBC Four"],
  "10": ["ITV3"],
  "11": ["Sky Mix"],
  "12": ["U&Dave"],
  "13": ["E4"],
  "14": ["Film4"],
  "15": ["Channel 4+1"],
  "16": ["More4"],
  "17": ["5STAR"],
  "18": ["U&W"],
  "19": ["U&Drama"],
  "20": ["U&Yesterday"],
  "21": ["5USA"],
  "22": ["Really"],
  "23": ["DMAX"],
  "24": ["PBS America"],
  "25": ["Together TV"],
  "26": ["That's TV"]
}
EOF

cat > requirements.txt << 'EOF'
requests
EOF

cat > build.py << 'EOF'
import json
import re
import requests

SOURCE = "https://iptv-org.github.io/iptv/countries/uk.m3u"
OUTPUT = "iptv.m3u"

with open("channels.json", "r", encoding="utf-8") as f:
    CHANNELS = json.load(f)

def normalise(name):
    name = re.sub(r"\s*\(.*?\)", "", name)
    return name.strip().lower()

print("Downloading playlist...")
data = requests.get(SOURCE, timeout=60).text.splitlines()

entries = []

i = 0
while i < len(data):

    line = data[i]

    if line.startswith("#EXTINF") and i + 1 < len(data):

        url = data[i + 1]

        if url.startswith("http"):

            name = line.split(",")[-1].strip()

            entries.append({
                "name": name,
                "extinf": line,
                "url": url
            })

    i += 1

output = ["#EXTM3U"]

for chno in sorted(CHANNELS.keys(), key=int):

    aliases = CHANNELS[chno]

    found = None

    for wanted in aliases:

        wanted_norm = normalise(wanted)

        for entry in entries:

            source_norm = normalise(entry["name"])

            if (
                source_norm == wanted_norm
                or source_norm.startswith(wanted_norm)
                or wanted_norm in source_norm
            ):
                found = entry
                break

        if found:
            break

    if not found:
        print(f"Missing: {aliases[0]}")
        continue

    extinf = found["extinf"]

    extinf = re.sub(
        r'tvg-chno="[^"]*"',
        '',
        extinf
    )

    extinf = re.sub(
        r",.*$",
        f",{aliases[0]}",
        extinf
    )

    extinf = extinf.replace(
        "#EXTINF:-1",
        f'#EXTINF:-1 tvg-chno="{chno}"'
    )

    output.append(extinf)
    output.append(found["url"])
    output.append("")

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write("\n".join(output))

print(f"Generated {OUTPUT}")
EOF

cat > .github/workflows/update.yml << 'EOF'
name: Update IPTV Playlist

on:
  workflow_dispatch:

  schedule:
    - cron: '0 3 * * *'

jobs:
  update:

    runs-on: ubuntu-latest

    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - run: pip install -r requirements.txt

      - run: python build.py

      - name: Commit changes
        run: |
          git config user.name "github-actions"
          git config user.email "actions@github.com"

          git add iptv.m3u

          git diff --cached --quiet || git commit -m "Update IPTV playlist"

          git push
EOF

python3 -m pip install -r requirements.txt

python3 build.py

echo ""
echo "Done."
echo "Playlist generated: iptv.m3u"