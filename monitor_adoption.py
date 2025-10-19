#!/usr/bin/env python3
"""
monitor_adoption.py

Generate an HTML dashboard showing which repos in an organization
have merged the standardized dependency workflow (.github/workflows/deps-install.yml).
"""

import os
import sys
import requests
from datetime import datetime

# Configuration
ORG = sys.argv[1] if len(sys.argv) > 1 else None
if not ORG:
    print("Usage: python3 monitor_adoption.py <ORG_NAME>")
    sys.exit(1)

GITHUB_API = "https://api.github.com"
TOKEN = os.getenv("GITHUB_TOKEN")
if not TOKEN:
    print("Error: set GITHUB_TOKEN env var with repo scope")
    sys.exit(1)

HEADERS = {
    "Authorization": f"token {TOKEN}",
    "Accept": "application/vnd.github.v3+json"
}

def list_js_repos(org):
    """List all JavaScript repos in an org or user account."""
    repos = []
    for endpoint in (f"orgs/{org}/repos", f"users/{org}/repos"):
        page = 1
        while True:
            resp = requests.get(
                f"{GITHUB_API}/{endpoint}",
                headers=HEADERS,
                params={"per_page": 100, "page": page}
            )
            if resp.status_code == 404:
                break  # try next endpoint
            resp.raise_for_status()
            data = resp.json()
            if not data:
                return repos
            for repo in data:
                language = repo.get("language")
                if language in ["JavaScript", "TypeScript"]:
                    repos.append(repo["name"])
            page += 1
    return repos

def check_workflow(repo):
    """Check if deps-install.yml exists on default branch."""
    path = ".github/workflows/deps-install.yml"
    resp = requests.get(
        f"{GITHUB_API}/repos/{ORG}/{repo}/contents/{path}",
        headers=HEADERS
    )
    return resp.status_code == 200

def main():
    repos = list_js_repos(ORG)
    total = len(repos)
    results = []
    for name in repos:
        has = check_workflow(name)
        results.append((name, has))
        status = "✓" if has else "✗"
        print(f"{status} {name}")
    # Generate HTML
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    adopted = sum(1 for _,h in results if h)
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Dependency Workflow Adoption Dashboard</title>
  <style>
    body {{ font-family: Arial,sans-serif; margin: 2rem; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th,td {{ border: 1px solid #ddd; padding: 8px; }}
    th {{ background: #f4f4f4; }}
    .yes {{ color: green; }} .no {{ color: red; }}
  </style>
</head>
<body>
  <h1>Dependency Workflow Adoption for {ORG}</h1>
  <p>Generated: {now}</p>
  <p>Adoption: {adopted}/{total} repositories</p>
  <table>
    <tr><th>Repository</th><th>Workflow Present?</th></tr>"""
    for name, has in results:
        cls = "yes" if has else "no"
        mark = "✓" if has else "✗"
        html += f"\n    <tr><td>{name}</td><td class=\"{cls}\">{mark}</td></tr>"
    html += """
  </table>
</body>
</html>"""
    with open("adoption_dashboard.html", "w") as f:
        f.write(html)
    print(f"\nDashboard written to adoption_dashboard.html")

if __name__ == "__main__":
    main()