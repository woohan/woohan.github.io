# frozen_string_literal: true

require "minitest/autorun"
require "date"
require "digest"
require "pathname"
require "yaml"

class LabSiteTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path

  def source(path)
    full_path = ROOT.join(path)
    assert full_path.file?, "Expected #{path} to exist"
    full_path.read
  end

  def data(path)
    YAML.safe_load(source(path), permitted_classes: [Date], aliases: true)
  end

  def test_all_six_lab_routes_use_the_isolated_lab_layout
    routes = {
      "_pages/lab/index.html" => "/lab/",
      "_pages/lab/news.html" => "/lab/news/",
      "_pages/lab/team.html" => "/lab/team/",
      "_pages/lab/publication.html" => "/lab/publication/",
      "_pages/lab/opportunities.html" => "/lab/opportunities/",
      "_pages/lab/about.html" => "/lab/about/"
    }

    routes.each do |path, permalink|
      page = source(path)
      assert_includes page, "layout: lab"
      assert_includes page, "permalink: #{permalink}"
    end
  end

  def test_lab_layout_does_not_load_the_personal_masthead
    layout = source("_layouts/lab.html")

    assert_includes layout, 'class="lab-site"'
    assert_includes layout, "/assets/lab/lab.css"
    assert_includes layout, "include lab/header.html"
    refute_includes layout, "include masthead.html"
    refute_includes source("_layouts/default.html"), "/assets/lab/lab.css"
  end

  def test_homepage_uses_the_prepared_hero_and_five_item_limits
    homepage = source("_pages/lab/index.html")

    assert_includes homepage, "homepage-background-title.png"
    assert_equal 2, homepage.scan("limit: 5").length
    %w[news publications team opportunities].each do |name|
      assert_includes homepage, "site.data.lab.#{name}"
    end
  end

  def test_team_contains_han_wu_and_all_three_phd_students
    team = data("_data/lab/team.yml")

    assert_equal "Dr Han Wu", team.fetch("lead").fetch("name")
    assert_equal "/images/Han_2026.jpg", team.fetch("lead").fetch("avatar")
    assert_equal ["Shuyan Zou", "Jiawei Wang", "Hengyang Yao"],
                 team.fetch("phd_students").map { |person| person.fetch("name") }
  end

  def test_team_cards_render_student_avatars_when_available
    team = data("_data/lab/team.yml")
    team_page = source("_pages/lab/team.html")

    team.fetch("phd_students").each do |person|
      avatar = person.fetch("avatar")
      assert ROOT.join(avatar.delete_prefix("/")).file?, "Expected #{person.fetch('name')} avatar #{avatar} to exist"
    end

    assert_includes team_page, "{% if person.avatar %}"
    assert_includes team_page, '<img class="lab-avatar" src="{{ person.avatar | relative_url }}" alt="Portrait of {{ person.name }}">'
    assert_includes team_page, "{% else %}"
    assert_includes team_page, "{{ person.initials }}"
  end

  def test_team_avatars_can_link_to_people_profiles
    team = data("_data/lab/team.yml")
    team_page = source("_pages/lab/team.html")
    css = source("assets/lab/lab.css")

    assert_equal "https://hanwu.ac.cn/", team.fetch("lead").fetch("profile_url")

    student_links = team.fetch("phd_students").to_h { |person| [person.fetch("name"), person.fetch("profile_url", nil)] }
    assert_equal "https://www.linkedin.com/in/shuyanrocky/", student_links.fetch("Shuyan Zou")
    assert_equal "https://www.linkedin.com/in/jiawei-wang-8999b3389/", student_links.fetch("Jiawei Wang")

    assert_includes team_page, "{% if lead.profile_url %}"
    assert_includes team_page, 'href="{{ lead.profile_url }}"'
    assert_includes team_page, "{% if person.profile_url %}"
    assert_includes team_page, 'href="{{ person.profile_url }}"'
    assert_includes team_page, 'class="lab-avatar-link"'
    assert_match(/\.lab-site \.lab-avatar-link\s*\{[^}]*display:\s*inline-block;[^}]*border-radius:\s*50%;/m, css)
  end

  def test_all_team_avatars_are_fifty_percent_larger
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-avatar\s*\{[^}]*width:\s*198px;[^}]*height:\s*198px;/m, css)
    assert_match(/\.lab-site \.lab-avatar--initials\s*\{[^}]*flex:\s*0 0 198px;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-avatar,[^{]+\{[^}]*width:\s*177px;[^}]*height:\s*177px;[^}]*flex-basis:\s*177px;/m, css)
  end

  def test_content_is_structured_and_homepage_lists_have_enough_items
    news = data("_data/lab/news.yml")
    publications = data("_data/lab/publications.yml")
    opportunities = data("_data/lab/opportunities.yml")

    assert_operator news.length, :>=, 5
    assert_operator publications.length, :>=, 5
    assert_operator opportunities.length, :>=, 1
    assert news.all? { |item| item.key?("date") && item.key?("title") && item.key?("summary") }
    assert publications.all? { |item| item.key?("year") && item.key?("title") && item.key?("authors") && item.key?("venue") }
  end

  def test_lab_news_data_carries_full_page_text_and_venue_metadata
    news = data("_data/lab/news.yml")

    assert news.all? { |item| item.key?("month") && item.key?("venue_short") && item.key?("body_html") && item.key?("image") }
    assert_equal "Apr", news.first.fetch("month")
    assert_equal "ICML", news.first.fetch("venue_short")
    assert_includes news.first.fetch("body_html"), "SlaClip: Gradient Norm Slacks can be Indicator for Adaptive Clipping in DP-SGD"
    assert_includes news[1].fetch("body_html"), "https://doi.org/10.1109/TR.2026.3687124"
    assert news.all? { |item| !item.fetch("body_html").include?("My ") && !item.fetch("body_html").include?("I was") }

    fedevolve = news.find { |item| item.fetch("title").start_with?("FedEvolve") }
    gtv = news.find { |item| item.fetch("title").start_with?("Vertical federated learning") }
    tcsi = news.find { |item| item.fetch("title").include?("IEEE Transactions on Circuits and Systems I") }
    welcome = news.find { |item| item.fetch("title") == "Welcome to Jiawei Wang" }
    riscs = news.find { |item| item.fetch("title") == "Invited talk at the RISCS Cybersecurity event" }
    scholarship = news.find { |item| item.fetch("title").start_with?("Aniket Singh Scholarship") }
    assert_includes fedevolve.fetch("body_html"), '<a href="https://openreview.net/forum?id=ksau9IVXPj"><em>"FedEvolve: Evolutionary Tabular Data Synthesis in Vertical Federated Learning Systems"</em></a>'
    assert_includes gtv.fetch("body_html"), '<em>"GTV: Generating Tabular Data via Vertical Federated Learning"</em>'
    assert_includes tcsi.fetch("body_html"), '<em>"Impacts of Physical-Layer Information on Epidemic Spreading in Cyber-Physical Networked Systems"</em>'
    assert_equal "/assets/lab/news/TEAM_soton.png", welcome.fetch("image")
    assert_equal "cover", welcome.fetch("image_fit")
    assert_equal "/assets/lab/news/RISCS_talk.png", riscs.fetch("image")
    assert_equal "cover", riscs.fetch("image_fit")
    assert_equal "/assets/lab/news/TEAM_ECS.png", scholarship.fetch("image")
    assert_equal "cover", scholarship.fetch("image_fit")
  end

  def test_supplied_svg_icons_are_used_directly
    icons = %w[home news team publication opportunities about]
    shell_and_pages = [
      source("_includes/lab/header.html"),
      source("_pages/lab/index.html"),
      source("_pages/lab/about.html")
    ].join("\n")

    icons.each do |icon|
      assert ROOT.join("assets/lab/icons/#{icon}.svg").file?, "Expected copied #{icon}.svg"
      assert_includes shell_and_pages, "/assets/lab/icons/#{icon}.svg"
    end
  end

  def test_lab_styles_are_namespaced_and_responsive
    css = source("assets/lab/lab.css")

    assert_includes css, "body.lab-site"
    assert_includes css, ".lab-site .lab-home-grid"
    assert_match(/@media\s*\(max-width:\s*720px\)/, css)
  end

  def test_mobile_navigation_can_shrink_without_widening_the_page
    css = source("assets/lab/lab.css")
    header = source("_includes/lab/header.html")

    assert_includes header, 'class="lab-mobile-nav"'
    assert_includes header, 'class="lab-mobile-current"'
    assert_includes header, 'class="lab-mobile-menu-icon"'
    assert_equal 6, header.scan(/class="lab-mobile-nav__label"/).length
    assert_match(/\.lab-site \.lab-nav\s*\{[^}]*min-width:\s*0;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-header__inner\s*\{[^}]*flex-direction:\s*column;[^}]*align-items:\s*center;[^}]*gap:\s*0\.85rem;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-wordmark\s*\{[^}]*margin-inline:\s*auto;[^}]*text-align:\s*center;/m, css)
    assert_match(/\.lab-site \.lab-mobile-nav\s*\{[^}]*display:\s*none;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-nav\s*\{[^}]*display:\s*none;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-mobile-nav\s*\{[^}]*display:\s*block;[^}]*width:\s*100%;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-mobile-nav__summary\s*\{[^}]*display:\s*flex;[^}]*justify-content:\s*space-between;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-mobile-nav__menu\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*1fr;/m, css)
  end

  def test_lab_wordmark_uses_the_site_typeface_with_restrained_weight
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-wordmark\s*\{[^}]*color:\s*#087bd1;[^}]*font-family:\s*inherit;[^}]*font-size:\s*clamp\(1\.45rem, 2\.1vw, 2\.15rem\);[^}]*font-weight:\s*800;[^}]*letter-spacing:\s*-0\.025em;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-wordmark\s*\{[^}]*font-size:\s*1\.5rem;/m, css)
    assert_match(/\.lab-site \.lab-wordmark span\s*\{[^}]*animation:\s*lab-punk-breathe 4\.8s ease-in-out infinite;/m, css)
    assert_match(/@keyframes lab-punk-breathe\s*\{[\s\S]*?0%,\s*100%\s*\{[^}]*text-shadow:[\s\S]*?50%\s*\{[^}]*text-shadow:/m, css)
    refute_match(/\.lab-site \.lab-wordmark\s*\{[^}]*(?:Arial Narrow|Impact|Haettenschweiler)/m, css)
  end

  def test_lab_navigation_uses_session_aware_horizontal_active_transition_after_first_visit
    layout = source("_layouts/lab.html")
    css = source("assets/lab/lab.css")

    assert_includes layout, "sessionStorage.getItem('cyberpunkLabVisited')"
    assert_includes layout, "document.documentElement.classList.add('lab-has-visited')"
    assert_includes layout, "sessionStorage.setItem('cyberpunkLabVisited', '1')"
    assert_match(/html\.lab-has-visited \.lab-site \.lab-header\s*\{[^}]*animation:\s*none;/m, css)
    assert_match(/html\.lab-has-visited \.lab-site \.lab-nav a\.is-active::after\s*\{[^}]*animation:\s*lab-nav-current-slide 520ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/@keyframes lab-nav-current-slide\s*\{[\s\S]*?0%\s*\{[^}]*opacity:\s*0;[^}]*transform:\s*translate3d\(-2\.4rem, 0, 0\) scaleX\(0\.25\);/m, css)
    assert_match(/@keyframes lab-nav-current-slide\s*\{[\s\S]*?100%\s*\{[^}]*opacity:\s*1;[^}]*transform:\s*translate3d\(0, 0, 0\) scaleX\(1\);/m, css)
  end

  def test_lab_header_drops_in_once_and_stays_fixed_at_the_top
    css = source("assets/lab/lab.css")

    assert_match(/body\.lab-site\s*\{[^}]*--lab-enter-ease:\s*cubic-bezier\(0\.22, 1, 0\.36, 1\);/m, css)
    assert_match(/\.lab-site \.lab-header\s*\{[^}]*position:\s*sticky;[^}]*top:\s*0;[^}]*animation:\s*lab-header-drop 816ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/@keyframes lab-header-drop\s*\{[\s\S]*?0%\s*\{[^}]*transform:\s*translate3d\(0, -100%, 0\);[^}]*opacity:\s*0;[^}]*background-color:\s*rgba\(6, 16, 29, 0\.48\);[^}]*border-bottom-color:\s*rgba\(37, 238, 255, 0\.38\);/m, css)
    assert_match(/@keyframes lab-header-drop\s*\{[\s\S]*?55%\s*\{[^}]*background-color:\s*rgba\(6, 16, 29, 0\.48\);[^}]*box-shadow:\s*0 12px 44px rgba\(0, 204, 255, 0\.18\);/m, css)
    assert_match(/@keyframes lab-header-drop\s*\{[\s\S]*?100%\s*\{[^}]*transform:\s*translate3d\(0, 0, 0\);[^}]*opacity:\s*1;[^}]*background-color:\s*rgba\(255, 255, 255, 0\.98\);/m, css)
    assert_match(/@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.lab-site \.lab-header,\s*\.lab-site \.lab-home-stage,\s*\.lab-site \.lab-home-backdrop,\s*\.lab-site \.lab-home-panels \.lab-screen,\s*\.lab-site \.lab-subpage\s*\{[^}]*animation:\s*none !important;/m, css)
  end

  def test_non_home_lab_subpages_rise_in_once_without_repeating_home_panel_animation
    css = source("assets/lab/lab.css")
    homepage = source("_pages/lab/index.html")

    %w[news team publication opportunities about].each do |slug|
      assert_includes source("_pages/lab/#{slug}.html"), 'class="lab-subpage'
    end

    refute_includes homepage, 'class="lab-subpage'
    assert_match(/\.lab-site \.lab-subpage\s*\{[^}]*animation:\s*lab-subpage-rise 744ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/@keyframes lab-subpage-rise\s*\{[\s\S]*?0%\s*\{[^}]*transform:\s*translate3d\(0, 42px, 0\);[^}]*opacity:\s*0;[^}]*\}[\s\S]*?100%\s*\{[^}]*transform:\s*translate3d\(0, 0, 0\);[^}]*opacity:\s*1;/m, css)
    assert_match(/@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.lab-site \.lab-home-panels \.lab-screen,\s*\.lab-site \.lab-subpage\s*\{[^}]*animation:\s*none !important;/m, css)
    refute_match(/\.lab-site \.lab-subpage\s*\{[^}]*(?:filter|backdrop-filter|animation-iteration-count)/m, css)
  end

  def test_subpage_cards_enter_with_staggered_top_to_bottom_rise
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-subpage \.lab-news-row,\s*\.lab-site \.lab-subpage \.lab-person-card,\s*\.lab-site \.lab-subpage \.lab-publication-row,\s*\.lab-site \.lab-subpage \.lab-opportunity-card,\s*\.lab-site \.lab-subpage \.lab-name-meaning article,\s*\.lab-site \.lab-subpage \.lab-research-focus\s*\{[^}]*animation:\s*lab-card-rise 660ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/\.lab-site \.lab-subpage \.lab-news-row:nth-child\(1\),[\s\S]*?animation-delay:\s*90ms;/m, css)
    assert_match(/\.lab-site \.lab-subpage \.lab-news-row:nth-child\(2\),[\s\S]*?animation-delay:\s*165ms;/m, css)
    assert_match(/\.lab-site \.lab-subpage \.lab-news-row:nth-child\(3\),[\s\S]*?animation-delay:\s*240ms;/m, css)
    assert_match(/@keyframes lab-card-rise\s*\{[\s\S]*?0%\s*\{[^}]*opacity:\s*0;[^}]*transform:\s*translate3d\(0, 34px, 0\);[^}]*\}[\s\S]*?100%\s*\{[^}]*opacity:\s*1;[^}]*transform:\s*translate3d\(0, 0, 0\);/m, css)
    assert_match(/@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.lab-site \.lab-subpage \.lab-news-row,\s*\.lab-site \.lab-subpage \.lab-person-card,\s*\.lab-site \.lab-subpage \.lab-publication-row,\s*\.lab-site \.lab-subpage \.lab-opportunity-card,\s*\.lab-site \.lab-subpage \.lab-name-meaning article,\s*\.lab-site \.lab-subpage \.lab-research-focus\s*\{[^}]*animation:\s*none !important;/m, css)
    card_rise = css[/@keyframes lab-card-rise\s*\{[\s\S]*?\n\}/m]
    refute_match(/(?:filter|backdrop-filter)/, card_rise)
  end

  def test_team_panel_is_forty_percent_of_its_previous_tablet_width
    css = source("assets/lab/lab.css")
    tablet_css = css.match(/@media \(max-width: 1180px\) \{(.+?)\n\}/m).to_s

    assert_match(/\.lab-site \.lab-home-grid__side\s*\{[^}]*grid-template-columns:\s*minmax\(180px, 1fr\) minmax\(0, 4fr\);/m, tablet_css)
  end

  def test_homepage_prioritises_publications_width_and_keeps_side_panels_compact
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-home-grid\s*\{[^}]*grid-template-columns:\s*minmax\(0, 1fr\) minmax\(0, 1\.58fr\) minmax\(230px, 0\.52fr\);/m, css)
    assert_match(/\.lab-site \.lab-home-grid\s*\{[^}]*align-items:\s*start;/m, css)
    assert_match(/@media \(max-width: 1180px\)[\s\S]+?\.lab-site \.lab-home-grid\s*\{[^}]*grid-template-columns:\s*minmax\(0, 1fr\) minmax\(0, 1\.5fr\);/m, css)
    assert_match(/\.lab-site \.lab-screen__header\s*\{[^}]*min-height:\s*48px;[^}]*padding:\s*0\.4rem 0\.78rem;/m, css)
    assert_match(/\.lab-site \.lab-screen__footer\s*\{[^}]*min-height:\s*34px;[^}]*padding:\s*0\.1rem 0\.68rem 0\.42rem;/m, css)
    assert_match(/\.lab-site \.lab-home-news,[^{]+\.lab-site \.lab-home-opening\s*\{[^}]*padding:\s*0\.42rem 0\.55rem;[^}]*border:\s*1px solid rgba\(116, 149, 177, 0\.28\);[^}]*border-radius:\s*0;[^}]*box-shadow:\s*0 1px 0 rgba\(255, 255, 255, 0\.62\) inset/m, css)
    refute_match(/\.lab-site \.lab-home-news,[^{]+\.lab-site \.lab-home-opening\s*\{[^}]*border-bottom:\s*1px dashed/m, css)
  end

  def test_homepage_panel_borders_are_static_cyberpunk_screen_frames
    css = source("assets/lab/lab.css")

    screen = css.match(/\.lab-site \.lab-screen\s*\{[^}]*\}/m).to_s
    refute_includes screen, "--flicker-duration"
    refute_includes screen, "animation:"
    refute_includes css, "@keyframes lab-screen-current"
    assert_includes screen, "--screen-color: #dcefff;"
    assert_includes screen, "--screen-rgb: 220, 239, 255;"
    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*border:\s*3px solid rgba\(var\(--screen-rgb\), 0\.72\);/m, css)
    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*0 0 28px 5px rgba\(var\(--screen-rgb\), 0\.34\)[^}]*0 0 86px 18px rgba\(var\(--screen-rgb\), 0\.24\)[^}]*0 0 170px 34px rgba\(0, 172, 255, 0\.13\)/m, css)
    assert_match(/\.lab-site \.lab-screen__header\s*\{[^}]*linear-gradient\(90deg, rgba\(0, 232, 255, 0\.1\), rgba\(255, 39, 95, 0\.08\), transparent 76%\);/m, css)
  end

  def test_homepage_opportunities_panel_uses_smaller_text
    css = source("assets/lab/lab.css")
    homepage = source("_pages/lab/index.html")

    assert_match(/\.lab-site \.lab-screen--opportunities \.lab-screen__header h2\s*\{[^}]*font-size:\s*1\.05rem;/m, css)
    assert_match(/\.lab-site \.lab-screen--opportunities \.lab-home-opening strong\s*\{[^}]*font-size:\s*0\.86rem;/m, css)
    assert_match(/\.lab-site \.lab-screen--opportunities \.lab-home-opening small\s*\{[^}]*font-size:\s*0\.68rem;/m, css)
    assert_includes homepage, "{% for item in site.data.lab.opportunities limit: 1 %}"
    assert_match(/\.lab-site \.lab-home-grid__side\s*\{[^}]*grid-template-rows:\s*auto auto;[^}]*align-content:\s*start;/m, css)
  end

  def test_updated_background_runs_once_continuously_behind_hero_and_panels
    css = source("assets/lab/lab.css")
    homepage = source("_pages/lab/index.html")
    layout = source("_layouts/lab.html")
    prepared_asset = ROOT.join("plan_lab_materials/homepage_background_title.png")
    published_asset = ROOT.join("assets/lab/homepage-background-title.png")

    assert File.exist?(published_asset), "published homepage background should exist"
    if File.exist?(prepared_asset)
      assert_equal Digest::SHA256.file(prepared_asset).hexdigest,
                   Digest::SHA256.file(published_asset).hexdigest
    end
    assert_equal 1, homepage.scan("homepage-background-title.png").length
    assert_includes layout, "{% if page.lab_page == 'home' %}"
    assert_includes layout, '<link rel="preload" as="image" href="{{ \'/assets/lab/homepage-background-title.png\' | relative_url }}" fetchpriority="high">'
    assert_includes homepage, 'class="lab-home-stage"'
    assert_includes homepage, '<div class="lab-home-backdrop" aria-hidden="true"></div>'
    assert_includes homepage, "style=\"--lab-home-bg: url('{{ '/assets/lab/homepage-background-title.png' | relative_url }}')\""
    assert_match(/\.lab-site \.lab-home-stage\s*\{[^}]*--lab-header-drop-offset:\s*86px;[^}]*animation:\s*lab-stage-settle 816ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/\.lab-site \.lab-home-backdrop\s*\{[^}]*position:\s*absolute;[^}]*inset:\s*0;[^}]*z-index:\s*0;[^}]*background-image:\s*var\(--lab-home-bg\);[^}]*background-position:\s*center top;[^}]*background-size:\s*100% auto;[^}]*transform-origin:\s*top center;[^}]*animation:\s*lab-hero-zoom-out 816ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/@keyframes lab-stage-settle\s*\{[\s\S]*?0%\s*\{[^}]*transform:\s*translate3d\(0, calc\(-1 \* var\(--lab-header-drop-offset\)\), 0\);[^}]*\}[\s\S]*?100%\s*\{[^}]*transform:\s*translate3d\(0, 0, 0\);/m, css)
    assert_match(/@keyframes lab-hero-zoom-out\s*\{[\s\S]*?0%\s*\{[^}]*transform:\s*scale\(1\.08\);[^}]*\}[\s\S]*?100%\s*\{[^}]*transform:\s*scale\(1\);/m, css)
    assert_match(/\.lab-site \.lab-hero\s*\{[^}]*height:\s*clamp\(300px, 40vw, 635px\);/m, css)
    panels_css = css.match(/\.lab-site \.lab-home-panels\s*\{[^}]*\}/m).to_s
    assert_includes panels_css, "background: transparent;"
    refute_includes panels_css, "background-image"
    assert_match(/@media \(max-width: 900px\)[\s\S]+?\.lab-site \.lab-home-stage\s*\{[^}]*--lab-header-drop-offset:\s*150px;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-home-stage\s*\{[^}]*--lab-header-drop-offset:\s*165px;[^}]*\}[\s\S]+?\.lab-site \.lab-home-backdrop\s*\{[^}]*background-position:\s*left top;[^}]*background-size:\s*auto 450px;[^}]*\}[\s\S]+?\.lab-site \.lab-hero\s*\{[^}]*height:\s*290px;/m, css)
  end

  def test_homepage_background_uses_only_the_prepared_static_image_without_rain
    css = source("assets/lab/lab.css")
    stage = css.match(/\.lab-site \.lab-home-stage\s*\{[^}]*\}/m).to_s

    assert_includes stage, "position: relative;"
    assert_includes stage, "isolation: isolate;"
    assert_includes stage, "overflow: hidden;"
    assert_includes stage, "contain: paint;"
    assert_match(/\.lab-site \.lab-home-backdrop\s*\{[^}]*background-image:\s*var\(--lab-home-bg\);/m, css)
    refute_match(/\.lab-site \.lab-home-stage::before\s*\{/, css)
    refute_match(/@keyframes lab-rain-(?:fall|drift)/, css)
    refute_match(/\.lab-site \.lab-home-stage::before\s*\{[^}]*animation:/m, css)
    refute_includes css, "repeating-linear-gradient(105deg"
    assert_match(/\.lab-site \.lab-hero\s*\{[^}]*position:\s*relative;[^}]*z-index:\s*1;/m, css)
    assert_match(/\.lab-site \.lab-home-panels\s*\{[^}]*position:\s*relative;[^}]*z-index:\s*1;/m, css)
    refute_includes css, "<canvas"
  end

  def test_homepage_modules_have_muted_screen_bezels_without_a_black_ring
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*border:\s*3px solid rgba\(var\(--screen-rgb\), 0\.72\);/m, css)
    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*0 0 28px 5px rgba\(var\(--screen-rgb\), 0\.34\)/m, css)
    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*0 0 86px 18px rgba\(var\(--screen-rgb\), 0\.24\)/m, css)
    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*0 0 170px 34px rgba\(0, 172, 255, 0\.13\)/m, css)
    refute_match(/\.lab-site \.lab-screen\s*\{[^}]*border:\s*5px solid/m, css)
    refute_match(/\.lab-site \.lab-screen\s*\{[^}]*0 0 0 3px #07121f/m, css)
    refute_match(/--screen-color:\s*#(?:c76f25|b89b2e|399f5b);/m, css)
    refute_match(/--screen-rgb:\s*(?:199, 111, 37|184, 155, 46|57, 159, 91);/m, css)
    assert_match(/\.lab-site \.lab-screen__header\s*\{[^}]*border-bottom:\s*2px solid/m, css)
  end

  def test_homepage_modules_keep_static_crt_texture_clear_of_text
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*radial-gradient\(circle at 12% 0%, rgba\(0, 232, 255, 0\.14\), transparent 30%\)[^}]*radial-gradient\(circle at 100% 0%, rgba\(255, 39, 95, 0\.1\), transparent 34%\)[^}]*border-radius:\s*1\.55rem 1\.28rem 1\.7rem 1\.35rem \/ 1\.3rem 1\.55rem 1\.25rem 1\.48rem;[^}]*inset 22px 0 42px -26px rgba\(2, 8, 12, 0\.66\)/m, css)
    glass_layer = css.match(/\.lab-site \.lab-screen::before\s*\{[^}]*\}/m).to_s
    edge_layer = css.match(/\.lab-site \.lab-screen::after\s*\{[^}]*\}/m).to_s
    body_glow_layer = css.match(/\.lab-site \.lab-screen__body::before\s*\{[^}]*\}/m).to_s
    body_scan_layer = css.match(/\.lab-site \.lab-screen__body::after\s*\{[^}]*\}/m).to_s
    assert_match(/z-index:\s*0;/, glass_layer)
    assert_match(/z-index:\s*0;/, edge_layer)
    assert_includes glass_layer, "radial-gradient(ellipse at center, transparent 0%, transparent 58%, rgba(3, 10, 18, 0.16) 100%)"
    assert_includes glass_layer, "linear-gradient(135deg, rgba(255, 255, 255, 0.28)"
    assert_includes edge_layer, "inset: 7px;"
    refute_includes edge_layer, "repeating-linear-gradient(0deg"
    assert_includes edge_layer, "inset 0 0 68px rgba(0, 132, 188, 0.2)"
    assert_includes body_glow_layer, "filter: blur(10px);"
    assert_includes body_glow_layer, "radial-gradient(circle at 50% 42%, rgba(180, 232, 255, 0.42), transparent 64%)"
    assert_includes body_scan_layer, "z-index: 2;"
    assert_includes body_scan_layer, "repeating-linear-gradient(0deg"
    assert_includes body_scan_layer, "rgba(5, 18, 25, 0.043) 2px"
    assert_includes body_scan_layer, "transparent 4px, transparent 14px"
    assert_match(/\.lab-site \.lab-screen__header,[\s\S]+?\.lab-site \.lab-screen__body,[\s\S]+?\.lab-site \.lab-screen__footer\s*\{[^}]*z-index:\s*1;/m, css)
    assert_match(/\.lab-site \.lab-screen__body\s*\{[^}]*isolation:\s*isolate;/m, css)
    refute_match(/\.lab-site \.lab-screen::(?:before|after)\s*\{[^}]*animation:/m, css)
    refute_includes css, "@keyframes lab-crt-beam"
    refute_match(/rgba\(2, 7, 10, 0\.94\)/, css)
  end

  def test_homepage_crt_screens_use_a_brighter_near_white_base
    css = source("assets/lab/lab.css")
    screen = css.match(/\.lab-site \.lab-screen\s*\{[^}]*\}/m).to_s

    assert_includes screen, "linear-gradient(135deg, rgba(255, 255, 255, 0.99), rgba(237, 248, 255, 0.97) 58%, rgba(255, 247, 251, 0.95))"
    assert_includes screen, "var(--lab-paper)"
  end

  def test_homepage_panels_do_not_use_scan_or_flicker_variables
    css = source("assets/lab/lab.css")

    refute_includes css, "--scan-duration"
    refute_includes css, "--scan-delay"
    refute_includes css, "--flicker-duration"
    refute_includes css, "--flicker-delay"
    refute_includes css, "will-change: transform"
  end

  def test_homepage_module_icons_and_titles_are_larger
    homepage = source("_pages/lab/index.html")
    css = source("assets/lab/lab.css")

    assert_equal 4, homepage.scan(/<span class="lab-screen__title">/).length
    assert_match(/\.lab-site \.lab-screen__header h2\s*\{[^}]*font-size:\s*1\.3rem;/m, css)
    assert_match(/\.lab-site \.lab-screen__title::first-letter\s*\{[^}]*color:\s*#007f9e;[^}]*font-size:\s*1\.12em;[^}]*text-shadow:[^}]*0 0 10px rgba\(0, 234, 255, 0\.68\);/m, css)
    assert_match(/\.lab-site \.lab-screen__header h2 img\s*\{[^}]*width:\s*3rem;[^}]*height:\s*3rem;/m, css)
  end

  def test_homepage_module_more_links_live_in_bottom_right_footers
    homepage = source("_pages/lab/index.html")
    css = source("assets/lab/lab.css")

    assert_equal 4, homepage.scan(/<footer class="lab-screen__footer">/).length
    assert_equal 4, homepage.scan(/<footer class="lab-screen__footer">\s*<a[^>]+>More <span aria-hidden="true">→<\/span><\/a>\s*<\/footer>/m).length
    homepage.scan(/<header class="lab-screen__header">.*?<\/header>/m).each do |header|
      refute_includes header, "More"
    end
    assert_match(/\.lab-site \.lab-screen\s*\{[^}]*display:\s*flex;[^}]*flex-direction:\s*column;/m, css)
    assert_match(/\.lab-site \.lab-screen__body\s*\{[^}]*flex:\s*1 1 auto;/m, css)
    assert_match(/\.lab-site \.lab-screen__footer\s*\{[^}]*margin-top:\s*auto;[^}]*display:\s*flex;[^}]*justify-content:\s*flex-end;/m, css)
    assert_match(/\.lab-site \.lab-screen__footer a\s*\{[^}]*padding:\s*0\.46rem 0\.78rem;[^}]*border:\s*2px solid rgba\(var\(--screen-rgb\), 0\.44\);[^}]*font-size:\s*0\.82rem;/m, css)
  end

  def test_homepage_module_links_use_the_compact_more_label
    homepage = source("_pages/lab/index.html")

    assert_equal 4, homepage.scan(/>More <span aria-hidden="true">→<\/span><\/a>/).length
    refute_match(/>View (?:all|team)/, homepage)
  end

  def test_homepage_panels_rise_into_view_once_on_initial_load
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-home-panels \.lab-screen\s*\{[^}]*animation:\s*lab-panel-rise 936ms var\(--lab-enter-ease\) both;/m, css)
    assert_match(/\.lab-site \.lab-home-grid > \.lab-screen--news\s*\{[^}]*animation-delay:\s*80ms;/m, css)
    assert_match(/\.lab-site \.lab-home-grid > \.lab-screen--publications\s*\{[^}]*animation-delay:\s*170ms;/m, css)
    assert_match(/\.lab-site \.lab-home-grid__side > \.lab-screen--team\s*\{[^}]*animation-delay:\s*260ms;/m, css)
    assert_match(/\.lab-site \.lab-home-grid__side > \.lab-screen--opportunities\s*\{[^}]*animation-delay:\s*350ms;/m, css)
    assert_match(/@keyframes lab-panel-rise\s*\{[\s\S]*?0%\s*\{[^}]*opacity:\s*0;[^}]*transform:\s*translate3d\(0, 56px, 0\) scale\(0\.99\);[^}]*\}[\s\S]*?100%\s*\{[^}]*opacity:\s*1;[^}]*transform:\s*translate3d\(0, 0, 0\) scale\(1\);/m, css)
    keyframes = css.split("@keyframes lab-panel-rise", 2).last.split(".lab-site .lab-screen", 2).first
    refute_includes keyframes, "filter:"
    refute_match(/\.lab-site \.lab-hero\s*\{[^}]*(?:animation|transition):/m, css)
    assert_match(/@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.lab-site \.lab-home-panels \.lab-screen,\s*\.lab-site \.lab-subpage\s*\{[^}]*animation:\s*none !important;/m, css)
    refute_includes css, "animation-iteration-count: infinite"
  end

  def test_homepage_module_content_uses_readable_type_sizes
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-home-news strong,[^{]+\{[^}]*font-size:\s*1\.05rem;/m, css)
    assert_match(/\.lab-site \.lab-home-news small,[^{]+\{[^}]*font-size:\s*0\.86rem;/m, css)
    assert_match(/\.lab-site \.lab-home-news time,[^{]+\{[^}]*font-size:\s*0\.95rem;/m, css)
    assert_match(/\.lab-site \.lab-name-list a\s*\{[^}]*font-size:\s*0\.9rem;/m, css)
    assert_match(/\.lab-site \.lab-home-publication > a\s*\{[^}]*font-size:\s*0\.78rem;/m, css)
  end

  def test_homepage_news_panel_keeps_titles_only_and_marks_acceptances
    homepage = source("_pages/lab/index.html")
    news = data("_data/lab/news.yml")

    news_article = homepage.match(/<article class="lab-screen lab-screen--news">.*?<\/article>/m).to_s

    assert_equal "One paper accepted to ICML 2026 as Spotlight (top 2.2%)!",
                 news.first.fetch("home_title")
    assert_equal [
      "One paper accepted to ICML 2026 as Spotlight (top 2.2%)!",
      "One paper accepted by IEEE Transactions on Reliability.",
      "One paper accepted at EuroMLSys 2026.",
      "Hengyang Yao joined CyberPUNK Lab as a PhD student.",
      "One paper accepted at the RSD Workshop @ AAAI 2026."
    ], news.take(5).map { |item| item.fetch("home_title") }
    assert news.take(5).all? { |item| item.fetch("home_title").length <= 80 },
           "Homepage news titles should stay concise"
    refute_includes news_article, "<small>{{ item.summary }}</small>"
    assert_includes news_article, "{% assign news_title = item.home_title | default: item.title %}"
    assert_includes news_article, '{% if news_title contains "accepted" or news_title contains "Accepted" %}🎉 {% endif %}{{ news_title }}'
    refute_includes news_article, "{{ item.title }}</strong>"
  end

  def test_homepage_publications_render_data_driven_tags
    homepage = source("_pages/lab/index.html")
    publications = data("_data/lab/publications.yml")

    assert publications.any? { |item| item.fetch("tags").include?("Honorable Mention") }
    assert publications.first.fetch("tags").include?("Spotlight (top 2.2%)")
    assert publications.take(5).all? { |item| item.fetch("tags").any? }, "Expected homepage publications to define visible tags"
    assert_includes homepage, 'class="lab-home-tags"'
    assert_includes homepage, "{% for tag in item.tags %}"
    assert_includes homepage, 'class="lab-home-tag{% if tag contains "Honorable" or tag contains "Award" or tag contains "Spotlight" %} lab-home-tag--note{% endif %}"'
    refute_includes homepage, "<small>{{ item.venue }}</small>"
  end

  def test_homepage_news_and_publication_dates_share_the_same_badge
    css = source("assets/lab/lab.css")

    badge_rule = /\.lab-site \.lab-home-news time,\s*\.lab-site \.lab-home-publication time\s*\{[^}]+\}/m
    assert_match badge_rule, css
    badge_css = css.match(badge_rule).to_s
    assert_includes badge_css, "font-size: 0.95rem;"
    assert_includes badge_css, "color: #096c9c;"
    assert_includes badge_css, "background: #edf9ff;"
    assert_includes badge_css, "border-left: 3px solid #23b7e5;"
  end

  def test_homepage_child_cards_glow_on_hover_like_screen_controls
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-home-news,[^{]+\.lab-site \.lab-home-opening\s*\{[^}]*position:\s*relative;[^}]*z-index:\s*1;/m, css)
    assert_match(/\.lab-site \.lab-home-news:hover,[\s\S]+?\.lab-site \.lab-name-list a:focus-visible\s*\{[^}]*z-index:\s*3;[^}]*border-color:\s*rgba\(var\(--screen-rgb\), 0\.82\);[^}]*box-shadow:[^}]*0 14px 28px rgba\(2, 18, 34, 0\.18\)[^}]*0 0 24px rgba\(var\(--screen-rgb\), 0\.34\)[^}]*transform:\s*translateY\(-4px\);/m, css)
    assert_match(/\.lab-site \.lab-home-tags small\s*\{[^}]*border-radius:\s*0;[^}]*font-size:\s*0\.78rem;/m, css)
    assert_match(/\.lab-site \.lab-home-tags small\s*\{[^}]*color:\s*#0f6d47;[^}]*border:\s*1px solid rgba\(25, 151, 94, 0\.34\);/m, css)
    assert_match(/\.lab-site \.lab-home-tags \.lab-home-tag--note\s*\{[^}]*color:\s*#b81743;[^}]*border-color:\s*rgba\(255, 39, 95, 0\.42\);/m, css)
    assert_match(/\.lab-site \.lab-screen__footer a\s*\{[^}]*border-radius:\s*0;/m, css)
    assert_match(/\.lab-site \.lab-home-publication > a\s*\{[^}]*border-radius:\s*0;/m, css)
    assert_match(/\.lab-site \.lab-name-list a\s*\{[^}]*border-radius:\s*0;/m, css)
  end

  def test_homepage_team_lead_label_uses_lead_not_pi
    homepage = source("_pages/lab/index.html")

    assert_includes homepage, "{{ site.data.lab.team.lead.name }} <small>Lead</small>"
    refute_includes homepage, "<small>PI</small>"
  end

  def test_publications_define_month_level_dates_for_the_homepage
    publications = data("_data/lab/publications.yml")
    homepage = source("_pages/lab/index.html")

    publications.each do |publication|
      assert_match(/\A\d{4}-\d{2}\z/, publication.fetch("date", ""), "Expected YYYY-MM date for #{publication.fetch('title')}")
    end
    assert_includes homepage, "<time>{{ item.date }}</time>"
    refute_includes homepage, "<time>{{ item.year }}</time>"
  end

  def test_publications_include_2026_and_missing_2025_items
    publications = data("_data/lab/publications.yml")
    titles = publications.map { |publication| publication.fetch("title") }

    assert_includes titles, "SlaClip: Gradient Norm Slacks can be Indicator for Adaptive Clipping in DP-SGD"
    assert_includes titles, "An Adaptive Mini-Batching Strategy for Reliable Streaming Data Delivery in Real-Time"
    assert_includes titles, "Peeling the Layers of Privacy-Utility Onion on Tabular Data"
    assert_includes titles, "Impacts of Physical-Layer Information on Epidemic Spreading in Cyber-Physical Networked Systems"

    slaclip = publications.find { |publication| publication.fetch("title") == "SlaClip: Gradient Norm Slacks can be Indicator for Adaptive Clipping in DP-SGD" }
    reliability = publications.find { |publication| publication.fetch("title") == "An Adaptive Mini-Batching Strategy for Reliable Streaming Data Delivery in Real-Time" }
    euromlsys = publications.find { |publication| publication.fetch("title") == "Peeling the Layers of Privacy-Utility Onion on Tabular Data" }
    tcsi = publications.find { |publication| publication.fetch("title") == "Impacts of Physical-Layer Information on Epidemic Spreading in Cyber-Physical Networked Systems" }

    assert_equal 2026, slaclip.fetch("year")
    assert_equal "2026-04", slaclip.fetch("date")
    assert_includes slaclip.fetch("tags"), "ICML 2026"
    assert_includes slaclip.fetch("tags"), "Spotlight (top 2.2%)"

    assert_equal 2026, reliability.fetch("year")
    assert_equal "2026-04", reliability.fetch("date")
    assert_includes reliability.fetch("tags"), "IEEE Transactions on Reliability"
    assert_equal "https://doi.org/10.1109/TR.2026.3687124", reliability.fetch("links").fetch("doi")

    assert_equal 2026, euromlsys.fetch("year")
    assert_equal "2026-03", euromlsys.fetch("date")
    assert_includes euromlsys.fetch("tags"), "EuroMLSys Workshop 2026"
    assert_equal "https://doi.org/10.1145/3805621.3807630", euromlsys.fetch("links").fetch("doi")

    assert_equal 2025, tcsi.fetch("year")
    assert_includes tcsi.fetch("tags"), "IEEE TCSI 2025"
    assert_equal "https://doi.org/10.1109/TCSI.2025.3550386", tcsi.fetch("links").fetch("doi")
  end

  def test_recent_publications_use_full_authors_and_actionable_links
    publications = data("_data/lab/publications.yml")
    by_title = publications.to_h { |publication| [publication.fetch("title"), publication] }

    slaclip = by_title.fetch("SlaClip: Gradient Norm Slacks can be Indicator for Adaptive Clipping in DP-SGD")
    reliability = by_title.fetch("An Adaptive Mini-Batching Strategy for Reliable Streaming Data Delivery in Real-Time")
    euromlsys = by_title.fetch("Peeling the Layers of Privacy-Utility Onion on Tabular Data")
    tcsi = by_title.fetch("Impacts of Physical-Layer Information on Epidemic Spreading in Cyber-Physical Networked Systems")

    assert_equal "Shuyan Zou, Shaowei Wang, Zhanxing Zhu, Jin Li, Changyu Dong, Vladimiro Sassone, Han Wu",
                 slaclip.fetch("authors")
    assert_equal "Han Wu, Zhihao Shang, Huaming Wu, Katinka Wolter", reliability.fetch("authors")
    assert_equal "Jiawei Wang, Zilong Zhao, Leonardo Aniello, Han Wu", euromlsys.fetch("authors")
    assert_equal "Xianglai Yuan, Yichao Yao, Han Wu, Minyu Feng", tcsi.fetch("authors")

    [slaclip, reliability, euromlsys, tcsi].each do |publication|
      refute_includes publication.fetch("authors"), "et al.", "Expected full authors for #{publication.fetch('title')}"
      assert publication.fetch("links").any?, "Expected actionable links for #{publication.fetch('title')}"
    end

    assert_equal "https://openreview.net/pdf?id=48suUeYKdb", slaclip.fetch("links").fetch("pdf")
    assert_equal "https://openreview.net/forum?id=48suUeYKdb&noteId=QbtjjzaCwt",
                 slaclip.fetch("links").fetch("project")
  end

  def test_recent_publications_use_paper_figures_instead_of_venue_logos
    publications = data("_data/lab/publications.yml")
    recent_titles = [
      "SlaClip: Gradient Norm Slacks can be Indicator for Adaptive Clipping in DP-SGD",
      "An Adaptive Mini-Batching Strategy for Reliable Streaming Data Delivery in Real-Time",
      "Peeling the Layers of Privacy-Utility Onion on Tabular Data",
      "Impacts of Physical-Layer Information on Epidemic Spreading in Cyber-Physical Networked Systems"
    ]
    recent = publications.select { |publication| recent_titles.include?(publication.fetch("title")) }

    refute_empty recent
    recent.each do |publication|
      image_path = publication.fetch("image")
      refute_match(/(?:ICML_logo|IEEE-RS-Logo|euromlsys-white|circuits_and_systems_i_logo)/i,
                   image_path,
                   "Expected a paper figure rather than a venue logo for #{publication.fetch('title')}")
      assert ROOT.join(image_path.delete_prefix("/")).file?, "Expected #{image_path} to exist"
    end
  end

  def test_publication_page_renders_green_venue_tags_and_red_award_tags
    publication_page = source("_pages/lab/publication.html")
    css = source("assets/lab/lab.css")

    assert_includes publication_page, 'class="lab-publication-tags"'
    assert_includes publication_page, "{% for tag in item.tags %}"
    assert_includes publication_page, 'tag contains "Spotlight"'
    assert_includes publication_page, 'lab-publication-tag--note'
    refute_includes publication_page, 'class="lab-venue-badge">{{ item.venue }}</span>'

    assert_match(/\.lab-site \.lab-publication-tags\s*\{[^}]*display:\s*flex;/m, css)
    assert_match(/\.lab-site \.lab-publication-tag\s*\{[^}]*color:\s*#0f6d47;[^}]*border:\s*1px solid rgba\(25, 151, 94, 0\.34\);[^}]*font-size:\s*0\.86rem;/m, css)
    assert_match(/\.lab-site \.lab-publication-tag--note\s*\{[^}]*color:\s*#b81743;[^}]*border-color:\s*rgba\(255, 39, 95, 0\.42\);/m, css)
  end

  def test_publication_and_news_pages_only_render_items_from_2025_onward
    publication_page = source("_pages/lab/publication.html")
    news_page = source("_pages/lab/news.html")

    assert_includes publication_page, 'where_exp: "item", "item.year >= 2025"'
    assert_includes news_page, 'where_exp: "item", "item.date >= \'2025-01\'"'

    refute_includes publication_page, 'id="publication-year-2024"'
    refute_includes publication_page, 'id="publication-year-2023"'
    refute_includes news_page, "site.data.lab.news %}"
  end

  def test_lab_subpage_headers_keep_only_large_icon_and_description
    page_header = source("_includes/lab/page-header.html")
    css = source("assets/lab/lab.css")
    subpages = %w[
      _pages/lab/news.html
      _pages/lab/team.html
      _pages/lab/publication.html
      _pages/lab/opportunities.html
      _pages/lab/about.html
    ]

    refute_includes page_header, "<h1"
    refute_includes page_header, "lab-page-heading__eyebrow"
    refute_includes page_header, "<span>{{ include.eyebrow"
    refute_includes page_header, "lab-signal-line"
    assert_includes page_header, 'class="lab-page-heading__icon"'
    assert_includes page_header, "{% if include.description %}<p>{{ include.description }}</p>{% endif %}"
    assert_match(/\.lab-site \.lab-page-heading__icon\s*\{[^}]*width:\s*3\.25rem;[^}]*height:\s*3\.25rem;/m, css)
    assert_match(/\.lab-site \.lab-page-heading\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*3\.25rem minmax\(0, 1fr\);/m, css)

    subpages.each do |path|
      page = source(path)
      assert_includes page, "icon=\"/assets/lab/icons/"
      assert_includes page, "description="
      refute_includes page, "eyebrow="
      refute_includes page, "inline_icon=true"
      refute_includes page, "hide_eyebrow=true"
    end
  end

  def test_lab_news_page_uses_large_month_dates_full_text_and_optional_venue_column
    news_page = source("_pages/lab/news.html")
    css = source("assets/lab/lab.css")

    assert_includes news_page, "<strong>{{ item.month }}</strong>"
    assert_includes news_page, "{{ item.body_html }}"
    assert_includes news_page, "lab-news-row__media"
    assert_includes news_page, "lab-news-row__image"
    assert_includes news_page, "{{ item.image | relative_url }}"
    assert_includes news_page, "item.image_fit"
    assert_includes news_page, "{{ item.venue_short }}"
    refute_includes news_page, "Read more"
    assert_match(/\.lab-site \.lab-news-row\s*\{[^}]*grid-template-columns:\s*150px minmax\(0, 1fr\) 150px;/m, css)
    assert_match(/\.lab-site \.lab-news-row time strong\s*\{[^}]*font-size:\s*2\.35rem;/m, css)
    assert_match(/\.lab-site \.lab-news-row time span\s*\{[^}]*font-size:\s*1\.42rem;/m, css)
    assert_match(/\.lab-site \.lab-news-row__media\s*\{[^}]*width:\s*150px;[^}]*height:\s*100%;[^}]*min-height:\s*110px;[^}]*overflow:\s*hidden;/m, css)
    assert_match(/\.lab-site \.lab-news-row__image\s*\{[^}]*object-fit:\s*contain;/m, css)
    assert_match(/\.lab-site \.lab-news-row__image--cover\s*\{[^}]*max-height:\s*none;[^}]*height:\s*100%;[^}]*object-fit:\s*cover;/m, css)
    assert_match(/\.lab-site \.lab-news-row__body a\s*\{[^}]*color:\s*#075f9d;[^}]*text-decoration-thickness:\s*2px;/m, css)
  end

  def test_publication_rows_do_not_repeat_the_page_icon
    publication_page = source("_pages/lab/publication.html")
    css = source("assets/lab/lab.css")

    refute_includes publication_page, %(<img src="{{ '/assets/lab/icons/publication.svg' | relative_url }}" alt="">)
    assert_match(/\.lab-site \.lab-publication-row\s*\{[^}]*grid-template-columns:\s*minmax\(0, 1fr\) 190px auto;/m, css)
    refute_match(/grid-template-columns:\s*(?:42|34)px minmax\(0, 1fr\)/, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+\.lab-site \.lab-publication-row\s*\{[^}]*grid-template-columns:\s*1fr;/m, css)
  end

  def test_publication_links_stack_without_changing_row_column_balance
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-publication-row\s*\{[^}]*grid-template-columns:\s*minmax\(0, 1fr\) 190px auto;/m, css)
    assert_match(/\.lab-site \.lab-publication-links\s*\{[^}]*display:\s*flex;[^}]*flex-direction:\s*column;[^}]*align-items:\s*stretch;/m, css)
    assert_match(/\.lab-site \.lab-publication-links a\s*\{[^}]*width:\s*68px;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-publication-links\s*\{[^}]*flex-direction:\s*row;/m, css)
  end

  def test_each_publication_has_a_cropped_representative_figure
    publications = data("_data/lab/publications.yml")
    publication_page = source("_pages/lab/publication.html")
    css = source("assets/lab/lab.css")

    publications.each do |publication|
      assert publication.key?("image"), "Expected #{publication.fetch('title')} to define an image"
      next unless publication.key?("image")

      image_path = publication.fetch("image")
      assert ROOT.join(image_path.delete_prefix("/")).file?, "Expected #{image_path} to exist"
    end
    assert_includes publication_page, 'class="lab-publication-thumb"'
    assert_match(/\.lab-site \.lab-publication-thumb\s*\{[^}]*object-fit:\s*cover;/m, css)
  end

  def test_lab_navigation_font_is_reduced_thirty_percent_at_each_breakpoint
    css = source("assets/lab/lab.css")

    assert_match(/\.lab-site \.lab-nav a\s*\{[^}]*font-size:\s*1\.092rem;/m, css)
    assert_match(/@media \(max-width: 1180px\)[\s\S]+?\.lab-site \.lab-nav a\s*\{[^}]*font-size:\s*0\.98rem;/m, css)
    assert_match(/@media \(max-width: 720px\)[\s\S]+?\.lab-site \.lab-mobile-nav__menu a\s*\{[^}]*font-size:\s*0\.896rem;/m, css)
  end

  def test_active_and_hovered_navigation_items_light_up_as_cyan_neon
    css = source("assets/lab/lab.css")
    header = source("_includes/lab/header.html")

    assert_equal 6, header.scan(/<span class="lab-nav__label">/).length
    assert_match(/\.lab-site \.lab-nav a\s*\{[^}]*color:\s*#171923;[^}]*text-shadow:\s*none;/m, css)
    assert_match(/\.lab-site \.lab-nav__label::first-letter\s*\{[^}]*color:\s*#007f9e;[^}]*font-size:\s*1\.18em;[^}]*text-shadow:[^}]*0 0 8px rgba\(0, 234, 255, 0\.55\);/m, css)
    assert_match(/\.lab-site \.lab-nav a\.is-active,\s*\.lab-site \.lab-nav a:not\(\.is-active\):hover,\s*\.lab-site \.lab-nav a:not\(\.is-active\):focus-visible\s*\{[^}]*color:\s*#007f9e;[^}]*font-size:\s*1\.18rem;[^}]*font-weight:\s*850;[^}]*animation:\s*lab-nav-glitch 2\.2s steps\(1, end\) infinite;[^}]*0 0 4px #00eaff[^}]*0 0 24px rgba\(0, 123, 255, 0\.62\);/m, css)
    assert_match(/\.lab-site \.lab-nav a::after\s*\{[^}]*background:\s*#37eeff;[^}]*box-shadow:[^}]*0 0 14px rgba\(0, 203, 238, 0\.9\);/m, css)
    assert_match(/@keyframes lab-nav-glitch\s*\{[\s\S]*?0%,\s*88%,\s*100%\s*\{[^}]*transform:\s*translate3d\(0, 0, 0\);[\s\S]*?84%\s*\{[^}]*transform:\s*translate3d\(1px, -1px, 0\);[\s\S]*?86%\s*\{[^}]*transform:\s*translate3d\(-1px, 1px, 0\);/m, css)
    assert_match(/@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.lab-site \.lab-nav a\.is-active,\s*\.lab-site \.lab-nav a:not\(\.is-active\):hover,\s*\.lab-site \.lab-nav a:not\(\.is-active\):focus-visible\s*\{[^}]*animation:\s*none !important;[^}]*transform:\s*none !important;/m, css)
    refute_match(/\.lab-site \.lab-nav a\.is-active,[^{]+\{[^}]*-webkit-text-stroke:\s*0\.6px/m, css)
    refute_match(/\.lab-site \.lab-nav a\.is-active\s*\{[^}]*#ff2fa3/m, css)
  end

  def test_about_identity_terms_are_red_and_glowing
    about = source("_pages/lab/about.html")
    css = source("assets/lab/lab.css")

    assert_includes about, '<strong class="lab-punk-term">Cyber</strong>security'
    assert_includes about, '<strong class="lab-punk-term">P</strong>rivacy'
    assert_includes about, '<strong class="lab-punk-term">UNK</strong>nown'
    assert_match(/\.lab-site \.lab-punk-term\s*\{[^}]*color:\s*var\(--lab-red\);[^}]*font-weight:\s*900;[^}]*text-shadow:[^}]*0 0 10px rgba\(255, 31, 49, 0\.55\);/m, css)
  end
end
