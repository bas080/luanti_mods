#!/usr/bin/env bash
 
set -euo pipefail



JQ_NORMALIZE_GITHUB='
{
  items: .items | map({
    hosted_on: "Github",
    full_name: .full_name,
    author: .owner.login,
    avatar_url: .owner.avatar_url,
    website: (.homepage // ""),
    repo_name: .name,
    html_url: .html_url,
    issues_url: (.html_url + "/issues"),
    open_issues: (.open_issues_count // 0),
    stars: (.stargazers_count // 0),
    forks: (.forks_count // 0),
    zip_url: ("https://github.com/" + .full_name + "/archive/refs/heads/" + (.default_branch // "main") + "/" + (.full_name | split("/")[-1]) + ".zip"),
    description: (.description // ""),
    default_branch: (.default_branch // "main"),
    updated_at: (.updated_at | sub("Z$"; "")),
    license: { name: (.license.name // "Unknown") },
    topics: (.topics // []),
    image_raw: ("https://raw.githubusercontent.com/" + .full_name + "/" + (.default_branch // "main") + "/screenshot.png"),
    readme_url: ("https://raw.githubusercontent.com/" + .full_name + "/" + (.default_branch // "main") + "/README.md")
  })
}
'

JQ_NORMALIZE_GITLAB='
{
  items: map({
    hosted_on: "Gitlab",
    full_name: .path_with_namespace,
    author: .namespace.full_path,
    avatar_url: ("https://gitlab.com" + (.avatar_url // "")),
    website: (.website_url // ""),
    repo_name: .name,
    html_url: .web_url,
    issues_url: (.web_url + "/-/issues"),
    open_issues: (.open_issues_count // 0),
    stars: (.star_count // 0),
    forks: (.forks_count // 0),
    zip_url: (.web_url + "/-/archive/" + (.default_branch // "main") + "/" + (.path_with_namespace | split("/")[-1]) + ".zip"),
    readme_url: (.web_url + "/-/raw/" + (.default_branch // "main") + "/README.md"),
    description: (.description // ""),
    default_branch: (.default_branch // "main"),
    updated_at: (.last_activity_at | sub("Z$"; "")),
    license: { name: (.license // "Unknown") },
    topics: (.tag_list // []),
    image_raw: (.web_url + "/-/raw/" + (.default_branch // "main") + "/screenshot.png")
  })
}
'

JQ_NORMALIZE_CODEBERG='
{
  items: .data | map({
    hosted_on: "Codeberg",
    full_name: .full_name,
    author: .owner.login,
    avatar_url: .owner.avatar_url,
    website: (.website // ""),
    repo_name: .name,
    html_url: .html_url,
    issues_url: (.html_url + "/issues"),
    open_issues: (.open_issues_count // 0),
    stars: (.stars_count // 0),
    forks: (.forks_count // 0),
    zip_url: (.html_url + "/archive/refs/heads/" + (.default_branch // "main") + "/" + .name + ".zip"),
    readme_url: (.html_url + "/raw/" + (.default_branch // "main") + "/README.md"),
    description: (.description // ""),
    default_branch: (.default_branch // "main"),
    updated_at: (.updated_at // ""),
    license: { name: (.license.name // "Unknown") },
    topics: (.topics // []),
    image_raw: (.html_url + "/raw/" + (.default_branch // "main") + "/screenshot.png")
  })
}
'

JQ_COMPUTE='
. + {
  now: (now | strftime("%Y-%m-%dT%H:%M:%S")),
  items: (.items | map(
    . + {
      has_stats: (((.stars // 0) + (.forks // 0) + (.open_issues // 0)) > 0)
    }
  ))
}
'

if ! command -v mache >/dev/null 2>&1; then
  mache() {
    eval "$*"
  }
fi

fetch_github() {
  mache 'gh api \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/search/repositories?q=topic:luanti-mod&sort=updated&order=desc&per_page=20"' \
    | jq "$JQ_NORMALIZE_GITHUB"
}

fetch_gitlab() {
  mache 'curl -s "https://gitlab.com/api/v4/projects?topic=Luanti&simple=true&per_page=20&order_by=last_activity_at&sort=desc"' \
    | jq "$JQ_NORMALIZE_GITLAB"
}

fetch_codeberg() {
  mache 'curl "https://codeberg.org/api/v1/repos/search?q=luanti-mod&limit=20"' \
    -H "accept: application/json" | jq "$JQ_NORMALIZE_CODEBERG"
}

fetch_all() {
  jq -s '{
    items: (.[0].items + .[1].items + .[2].items | sort_by(.updated_at) | reverse)
  }' <(fetch_github) <(fetch_gitlab) <(fetch_codeberg) | jq "$JQ_COMPUTE"
}

fetch_all | tee data.json >(mustache - feed.mustache > feed.xml) | mustache - index.mustache > index.html
