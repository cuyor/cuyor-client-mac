#!/usr/bin/env python3
"""
Generate Sparkle appcast entries from GitHub releases.
This script is used by GitHub Actions to automatically generate appcast.xml entries
when a new release is published.
"""

import os
import sys
import json
import urllib.request
import urllib.error
from datetime import datetime
from xml.etree import ElementTree as ET

def get_release_info(owner: str, repo: str, tag: str) -> dict:
    """Fetch release information from GitHub API."""
    url = f"https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Cuyor-Sparkle-CI"
    }
    
    if token := os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"token {token}"
    
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except urllib.error.URLError as e:
        print(f"Error fetching release info: {e}")
        sys.exit(1)

def update_appcast(
    release_tag: str,
    version: str,
    short_version: str,
    download_url: str,
    file_size: int,
    release_notes_url: str = None,
    appcast_path: str = "appcast.xml"
) -> None:
    """
    Update appcast.xml with a new release entry.
    """
    
    # Parse existing appcast or create new one
    try:
        tree = ET.parse(appcast_path)
        root = tree.getroot()
    except FileNotFoundError:
        # Create new appcast structure
        root = ET.Element("rss", version="2.0")
        root.set("xmlns:sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "Cuyor"
        ET.SubElement(channel, "link").text = "https://github.com/cuyor/cuyor-client-mac"
        ET.SubElement(channel, "description").text = "Auto-update feed for Cuyor"
        ET.SubElement(channel, "language").text = "en"
        tree = ET.ElementTree(root)
    
    # Get channel element
    channel = root.find("channel")
    
    # Create new item element
    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"Cuyor {short_version}"
    
    # Add description with release notes
    description = ET.SubElement(item, "description")
    release_notes = f"<![CDATA[<h2>Version {short_version}</h2><p>"
    if release_notes_url:
        release_notes += f'See <a href="{release_notes_url}">release notes on GitHub</a>'
    else:
        release_notes += "See GitHub for release notes"
    release_notes += "</p>]]>"
    description.text = release_notes
    
    # Publication date (RFC 2822 format)
    pub_date = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S +0000")
    ET.SubElement(item, "pubDate").text = pub_date
    
    # Sparkle version tags
    sparkle_version = ET.SubElement(item, "sparkle:version")
    sparkle_version.set("sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
    sparkle_version.text = version
    
    ET.SubElement(item, "sparkle:shortVersionString").text = short_version
    
    if release_notes_url:
        sparkle_release_notes = ET.SubElement(item, "sparkle:releaseNotesLink")
        sparkle_release_notes.text = release_notes_url
    
    # Enclosure (download link)
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", download_url)
    enclosure.set("sparkle:version", version)
    enclosure.set("sparkle:shortVersionString", short_version)
    enclosure.set("length", str(file_size))
    enclosure.set("type", "application/zip")
    
    # Note: EdDSA signature can be added later when code signing is implemented
    # enclosure.set("sparkle:edSignature", "SIGNATURE_HERE")
    
    # Insert new item at the beginning (after channel metadata)
    channel_children = list(channel)
    metadata_count = len([el for el in channel_children if el.tag in ["title", "link", "description", "language"]])
    channel.insert(metadata_count, item)
    
    # Write updated appcast
    tree.write(appcast_path, encoding="utf-8", xml_declaration=True)
    print(f"Updated appcast.xml with version {short_version}")

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: generate_appcast.py <release_tag> <version> <short_version> <download_url> [file_size] [release_notes_url]")
        sys.exit(1)
    
    release_tag = sys.argv[1]
    version = sys.argv[2]
    short_version = sys.argv[3]
    download_url = sys.argv[4]
    file_size = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    release_notes_url = sys.argv[6] if len(sys.argv) > 6 else None
    
    update_appcast(
        release_tag=release_tag,
        version=version,
        short_version=short_version,
        download_url=download_url,
        file_size=file_size,
        release_notes_url=release_notes_url
    )
