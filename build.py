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
