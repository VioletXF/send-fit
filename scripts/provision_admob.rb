#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates/reuses an unlisted iOS AdMob app and SendFit's banner/interstitial
# units, then persists their integration IDs into the ignored .env file.

require "base64"
require "digest"
require "json"
require "net/http"
require "securerandom"
require "uri"
require "webrick"

ROOT = File.expand_path("..", __dir__)
ENV_FILE = File.join(ROOT, ".env")
API_ROOT = "https://admob.googleapis.com/v1beta"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPES = ["https://www.googleapis.com/auth/admob.monetization", "https://www.googleapis.com/auth/admob.readonly"].freeze

def load_dotenv
  return unless File.exist?(ENV_FILE)

  File.foreach(ENV_FILE) do |line|
    next if line.lstrip.start_with?("#") || !line.include?("=")

    key, value = line.strip.split("=", 2)
    ENV[key] = value.to_s.sub(/\A["']/, "").sub(/["']\z/, "") unless key.empty? || ENV.key?(key)
  end
end

def fail_with(message)
  warn "error: #{message}"
  exit 1
end

def required_env(key)
  value = ENV[key]
  fail_with("#{key} is required; add it to .env") if value.to_s.strip.empty?

  value
end

def configured_name(key, fallback)
  value = ENV[key].to_s.strip
  value.empty? ? fallback : value
end

def app_name
  configured_name("ADMOB_APP_DISPLAY_NAME", "SendFit")
end

def banner_name
  configured_name("ADMOB_BANNER_DISPLAY_NAME", "SendFit Compression Banner")
end

def interstitial_name
  configured_name("ADMOB_INTERSTITIAL_DISPLAY_NAME", "SendFit Result Interstitial")
end

def save_env(values)
  lines = File.exist?(ENV_FILE) ? File.readlines(ENV_FILE, chomp: true) : []
  values.each do |key, value|
    index = lines.index { |line| line.match?(/\A#{Regexp.escape(key)}=/) }
    line = "#{key}=#{value}"
    index ? lines[index] = line : lines << line
  end
  File.write(ENV_FILE, "#{lines.join("\n")}\n", perm: 0o600)
end

def json_request(method, url, headers: {}, body: nil)
  uri = URI(url)
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  headers.each { |key, value| request[key] = value }
  request.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  payload = JSON.parse(response.body) unless response.body.to_s.empty?
  return payload if response.is_a?(Net::HTTPSuccess)

  detail = payload&.dig("error", "message") || response.body
  fail_with("#{method.upcase} #{uri.path} returned HTTP #{response.code}: #{detail}")
end

def oauth_client
  { client_id: required_env("ADMOB_OAUTH_CLIENT_ID"), client_secret: required_env("ADMOB_OAUTH_CLIENT_SECRET") }
end

def access_token
  client = oauth_client
  refresh_token = required_env("ADMOB_OAUTH_REFRESH_TOKEN")
  uri = URI(TOKEN_URL)
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(
    "client_id" => client[:client_id], "client_secret" => client[:client_secret],
    "refresh_token" => refresh_token, "grant_type" => "refresh_token"
  )
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  payload = JSON.parse(response.body)
  fail_with(payload["error_description"] || payload["error"] || "OAuth refresh failed") unless response.is_a?(Net::HTTPSuccess)

  payload.fetch("access_token")
end

def headers(token)
  { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
end

def list_all(path, key, token)
  values, page_token = [], nil
  loop do
    query = { "pageSize" => 100 }
    query["pageToken"] = page_token if page_token
    payload = json_request("get", "#{API_ROOT}/#{path}?#{URI.encode_www_form(query)}", headers: headers(token))
    values.concat(payload.fetch(key, []))
    page_token = payload["nextPageToken"]
    break if page_token.to_s.empty?
  end
  values
end

def publisher_account(token)
  requested = ENV["ADMOB_PUBLISHER_ACCOUNT"].to_s.strip
  accounts = list_all("accounts", "account", token)
  fail_with("no AdMob publisher accounts were returned by this OAuth grant") if accounts.empty?
  return requested if !requested.empty? && accounts.any? { |account| account["name"] == requested }
  return accounts.first.fetch("name") if accounts.one?

  names = accounts.filter_map { |account| account["name"] }
  fail_with("multiple AdMob accounts are available; set ADMOB_PUBLISHER_ACCOUNT to one of: #{names.join(", ")}")
end

def find_or_create_app(account, token)
  existing = list_all("#{account}/apps", "apps", token).find do |app|
    app["platform"] == "IOS" && app.dig("manualAppInfo", "displayName") == app_name
  end
  return existing if existing

  json_request(
    "post", "#{API_ROOT}/#{account}/apps", headers: headers(token),
    body: { "platform" => "IOS", "manualAppInfo" => { "displayName" => app_name } }
  )
end

def find_or_create_unit(account, app_id, name, format, ad_types, token)
  existing = list_all("#{account}/adUnits", "adUnits", token).find do |unit|
    unit["appId"] == app_id && unit["displayName"] == name && unit["adFormat"] == format
  end
  return existing if existing

  json_request(
    "post", "#{API_ROOT}/#{account}/adUnits", headers: headers(token),
    body: { "appId" => app_id, "displayName" => name, "adFormat" => format, "adTypes" => ad_types }
  )
end

def authorize
  client = oauth_client
  state = SecureRandom.hex(24)
  verifier = SecureRandom.urlsafe_base64(64)
  challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
  code = nil
  server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: 0, Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
  port = server.listeners.first.addr[1]
  redirect_uri = "http://127.0.0.1:#{port}/oauth2/callback"
  server.mount_proc("/oauth2/callback") do |request, response|
    if request.query["state"] == state && request.query["code"]
      code = request.query["code"]
      response.body = "Authorization complete. You may close this tab and return to Terminal."
      Thread.new { sleep 0.2; server.shutdown }
    else
      response.status = 400
      response.body = "Authorization response did not match this request."
    end
  end
  query = URI.encode_www_form(
    "client_id" => client[:client_id], "redirect_uri" => redirect_uri, "response_type" => "code",
    "scope" => SCOPES.join(" "), "access_type" => "offline", "prompt" => "consent",
    "state" => state, "code_challenge" => challenge, "code_challenge_method" => "S256"
  )
  url = "#{AUTH_URL}?#{query}"
  puts "Opening Google authorization in your browser…"
  system("open", url) || fail_with("could not open a browser; visit this URL:\n#{url}")
  server.start
  fail_with("Google did not return an authorization code") unless code

  uri = URI(TOKEN_URL)
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(
    "client_id" => client[:client_id], "client_secret" => client[:client_secret], "code" => code,
    "code_verifier" => verifier, "redirect_uri" => redirect_uri, "grant_type" => "authorization_code"
  )
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  payload = JSON.parse(response.body)
  fail_with(payload["error_description"] || payload["error"] || "OAuth token exchange failed") unless response.is_a?(Net::HTTPSuccess)
  token = payload["refresh_token"] || fail_with("Google did not return a refresh token; revoke prior access and rerun authorize")
  save_env("ADMOB_OAUTH_REFRESH_TOKEN" => token)
  puts "Saved ADMOB_OAUTH_REFRESH_TOKEN to .env."
end

def provision
  token = access_token
  account = publisher_account(token)
  app = find_or_create_app(account, token)
  app_id = app.fetch("appId")
  banner = find_or_create_unit(account, app_id, banner_name, "BANNER", ["RICH_MEDIA"], token)
  interstitial = find_or_create_unit(account, app_id, interstitial_name, "INTERSTITIAL", ["RICH_MEDIA", "VIDEO"], token)
  save_env(
    "ADMOB_PUBLISHER_ACCOUNT" => account,
    "ADMOB_APP_ID" => app_id,
    "ADMOB_BANNER_AD_UNIT_ID" => banner.fetch("adUnitId"),
    "ADMOB_INTERSTITIAL_AD_UNIT_ID" => interstitial.fetch("adUnitId")
  )
  puts "AdMob provisioning complete for #{app_id}. IDs were saved to .env."
end

load_dotenv
case ARGV.first
when "authorize" then authorize
when "provision" then provision
else
  warn "Usage: bundle exec ruby scripts/provision_admob.rb authorize|provision"
  exit 64
end
