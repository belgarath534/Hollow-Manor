# Tries every App Store Connect API key the workflow collected and keeps the first one Apple accepts.
# Talks to Apple directly (no fastlane). Prints only Key IDs, status codes and Apple's error messages.
require "openssl"
require "base64"
require "json"
require "net/http"

def b64(data) = Base64.urlsafe_encode64(data, padding: false)

def make_jwt(key, kid, issuer)
  now = Time.now.to_i
  header = { alg: "ES256", kid: kid, typ: "JWT" }
  payload = { iss: issuer, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }
  signing_input = "#{b64(header.to_json)}.#{b64(payload.to_json)}"
  der = key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
  r, s = OpenSSL::ASN1.decode(der).value.map { |n| n.value.to_s(2).rjust(32, "\0")[-32..] }
  "#{signing_input}.#{b64(r + s)}"
end

def apple_get(token, path)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{token}"
  Net::HTTP.start(uri.host, 443, use_ssl: true, read_timeout: 30) { |http| http.request(request) }
end

# Apple sometimes answers 500 "UNEXPECTED_ERROR" for a while. That's Apple's problem, not a bad key, so retry,
# and try a second address too. 401 and 403 mean the key really is refused.
def apple_status(key, kid, issuer)
  last = nil
  4.times do |attempt|
    ["/v1/bundleIds?limit=1", "/v1/apps?limit=1"].each do |path|
      last = apple_get(make_jwt(key, kid, issuer), path)
      return last if last.code == "200" || %w[401 403].include?(last.code)
    end
    puts "   Apple had a problem (HTTP #{last.code}), trying again (#{attempt + 1} of 4)…"
    sleep 10 * (attempt + 1)
  end
  last
end

issuer = (ENV["ASC_ISSUER_ID_PUBLIC"] || ENV.fetch("ASC_ISSUER_ID")).strip
files = Dir[File.join(Dir.home, ".asc", "candidates", "*.p8")].sort
abort "❌ No .p8 keys found. Upload your AuthKey_XXXXXXXXXX.p8 to the ios-certificates repo." if files.empty?

winner = nil
maybe = nil # a key Apple didn't refuse, only failed on
files.each do |path|
  name = File.basename(path)
  kid = name[/\A(?:AuthKey_|secret_)([A-Za-z0-9]+)\.p8\z/, 1]
  unless kid
    puts "⚠️ Skipping #{name}: can't tell its Key ID (name it AuthKey_<KEYID>.p8)"
    next
  end
  begin
    key = OpenSSL::PKey.read(File.read(path))
  rescue OpenSSL::PKey::PKeyError
    puts "❌ #{kid}: the file isn't a valid private key"
    next
  end
  response = apple_status(key, kid, issuer)
  if response.code == "200"
    puts "✅ #{kid}: Apple accepts this key"
    winner = [path, kid]
    break
  else
    detail = ((JSON.parse(response.body)["errors"] || []).first || {})["code"] rescue nil
    if response.code.start_with?("5")
      puts "⚠️ #{kid}: Apple kept failing (HTTP #{response.code} #{detail}), but didn't refuse the key"
      maybe ||= [path, kid]
    else
      puts "❌ #{kid}: Apple rejects it (HTTP #{response.code} #{detail})"
    end
  end
end

if winner.nil? && maybe
  puts "⚠️ Going ahead with #{maybe[1]}: Apple's API is having trouble, but this key wasn't refused."
  winner = maybe
end
abort "❌ Apple rejected every key. Create a new Team key and upload its .p8 to ios-certificates." unless winner

if ENV["GITHUB_ENV"]
  File.write(ENV["GITHUB_ENV"], "ASC_KEY_PATH=#{winner[0]}\nGOOD_KEY_ID=#{winner[1]}\n", mode: "a")
end
