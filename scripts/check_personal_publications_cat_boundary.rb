#!/usr/bin/env ruby
# frozen_string_literal: true

project_root = File.expand_path("..", __dir__)
personal_page = File.join(project_root, "_site", "publications", "index.html")
lab_page = File.join(project_root, "_site", "lab", "publication", "index.html")
cat_marker = ["data-publications", "cat"].join("-")

missing_pages = [personal_page, lab_page].reject { |path| File.file?(path) }
unless missing_pages.empty?
  warn "Build the site before running this check. Missing: #{missing_pages.join(', ')}"
  exit 1
end

personal_html = File.binread(personal_page)
lab_html = File.binread(lab_page)

if personal_html.include?(cat_marker)
  warn "Decorative cat markup leaked into the personal publications page."
  exit 1
end

unless lab_html.include?(cat_marker)
  warn "The Lab publications page no longer contains its intended decorative cat."
  exit 1
end

puts "Personal publications omit the cat; Lab publications retain it."
