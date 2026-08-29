#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only App Store Connect submission gate. It deliberately reports only
# field names, never credential values or reviewer contact details.

require "dotenv/load"
require "spaceship"

def present?(value)
  !value.to_s.strip.empty?
end

def read_or_mark_missing(missing, label)
  yield
rescue StandardError
  missing << label
  nil
end

required_environment = %w[
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_KEY_PATH
]
missing = required_environment.reject { |name| present?(ENV[name]) }.map { |name| "environment: #{name}" }

if missing.empty?
  token = Spaceship::ConnectAPI::Token.create(
    key_id: ENV.fetch("APP_STORE_CONNECT_KEY_ID"),
    issuer_id: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
    filepath: ENV.fetch("APP_STORE_CONNECT_KEY_PATH")
  )
  Spaceship::ConnectAPI.token = token

  app = Spaceship::ConnectAPI::App.find(ENV.fetch("APP_IDENTIFIER", "com.sendfit.app"))
  if app.nil?
    missing << "App Store Connect app record"
  else
    version = app.get_app_store_versions.find { |candidate| candidate.app_store_state == "PREPARE_FOR_SUBMISSION" }
    if version.nil?
      missing << "editable App Store version"
    else
      localization = version.get_app_store_version_localizations.find { |candidate| candidate.locale == "en-US" }
      if localization.nil?
        missing << "en-US App Store localization"
      else
        missing << "description" unless present?(localization.description)
        missing << "keywords" unless present?(localization.keywords)
        missing << "support URL" unless present?(localization.support_url)
        missing << "marketing URL" unless present?(localization.marketing_url)

        screenshot_sets = localization.get_app_screenshot_sets
        screenshot_count = screenshot_sets.sum { |set| set.app_screenshots.count }
        missing << "App Store screenshots" if screenshot_count.zero?
      end

      selected_build = read_or_mark_missing(missing, "selected App Store build") { version.get_build }
      missing << "selected App Store build" if selected_build.nil? && !missing.include?("selected App Store build")

      detail = read_or_mark_missing(missing, "App Review information") { version.fetch_app_store_review_detail }
      if detail
        missing << "review contact first name" unless present?(detail.contact_first_name)
        missing << "review contact last name" unless present?(detail.contact_last_name)
        missing << "review contact email" unless present?(detail.contact_email)
        missing << "review contact phone" unless present?(detail.contact_phone)
        missing << "review notes" unless present?(detail.notes)
      end
    end

    app_info = read_or_mark_missing(missing, "App Information") { app.fetch_edit_app_info }
    age_rating = app_info && read_or_mark_missing(missing, "age rating declaration") { app_info.fetch_age_rating_declaration }
    missing << "age rating declaration" if age_rating.nil? && !missing.include?("age rating declaration")
    missing << "content rights declaration" unless present?(app.content_rights_declaration)
  end
end

if missing.empty?
  puts "App Store submission readiness is complete."
else
  warn "App Store submission is not ready; complete:"
  missing.uniq.each { |item| warn "- #{item}" }
  exit 1
end
