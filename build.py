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
