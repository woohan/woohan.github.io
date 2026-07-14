#!/usr/bin/env ruby

require "nokogiri"
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).parent
SITE = ROOT.join("_site")
ID_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

failures = []

def read_yaml(path)
  YAML.safe_load(File.read(path), aliases: true)
end

def check_ids(records, label, failures)
  ids = records.map { |record| record["id"] }

  records.each_with_index do |record, index|
    id = record["id"]
    failures << "#{label} item #{index + 1} is missing an id" if id.to_s.empty?
    failures << "#{label} id '#{id}' is not kebab-case" if id && !ID_PATTERN.match?(id)
  end

  ids.compact.tally.each do |id, count|
    failures << "#{label} id '#{id}' is duplicated" if count > 1
  end
end

news = read_yaml(ROOT.join("_data/lab/news.yml"))
publications = read_yaml(ROOT.join("_data/lab/publications.yml"))
opportunities = read_yaml(ROOT.join("_data/lab/opportunities.yml"))
team = read_yaml(ROOT.join("_data/lab/team.yml"))
people = [team["lead"], *team.fetch("groups", {}).values.flatten].compact

check_ids(news, "News", failures)
check_ids(publications, "Publication", failures)
check_ids(opportunities, "Opportunity", failures)
check_ids(people, "Team", failures)

news.each do |item|
  home_url = item["home_url"].to_s
  failures << "News '#{item['id']}' is missing home_url" if home_url.empty?
  failures << "News '#{item['id']}' home_url must include a fragment" unless home_url.include?("#")
end

unless SITE.join("lab/index.html").exist?
  warn "Build output is missing. Run ./scripts/serve-local.sh or bundle exec jekyll build first."
  exit 1
end

home = Nokogiri::HTML(File.read(SITE.join("lab/index.html")))
link_groups = {
  ".lab-home-news" => 5,
  ".lab-home-publication > a" => 5,
  ".lab-name-list > a" => 4,
  ".lab-home-opening" => 1
}
links = link_groups.flat_map do |selector, expected_count|
  matches = home.css(selector)
  if matches.length != expected_count
    failures << "Expected #{expected_count} Lab home links matching '#{selector}', found #{matches.length}"
  end
  matches
end
documents = {}

links.each do |link|
  href = link["href"].to_s
  path, fragment = href.split("#", 2)

  if fragment.to_s.empty?
    failures << "Lab home item link '#{href}' does not target a specific item"
    next
  end

  relative_path = path.sub(%r{\A/}, "")
  target_file = if relative_path.end_with?("/")
                  SITE.join(relative_path, "index.html")
                else
                  SITE.join(relative_path)
                end

  unless target_file.exist?
    failures << "Lab home item link '#{href}' points to missing page #{target_file.relative_path_from(ROOT)}"
    next
  end

  document = documents[target_file] ||= Nokogiri::HTML(File.read(target_file))
  unless document.at_xpath("//*[@id='#{fragment}']")
    failures << "Lab home item link '#{href}' points to a missing id"
  end
end

if failures.any?
  warn failures.map { |failure| "- #{failure}" }.join("\n")
  exit 1
end

puts "Validated #{links.length} Lab home item links and all stable content ids."
