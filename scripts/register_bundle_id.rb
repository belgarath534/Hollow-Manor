# Registers Hollow Manor's bundle ID with Apple if it isn't registered yet, so fastlane match can make its profile.
# Uses the App Store Connect key that check_asc_key.rb picked (ASC_KEY_PATH, GOOD_KEY_ID, ASC_ISSUER_ID).
require "openssl"
require "base64"
require "json"
require "net/http"

BUNDLE_ID = "com.hollowmanor.HollowManor"
NAME = "Hollow Manor"

def b64(data) = Base64.urlsafe_encode64(data, padding: false)

def token
  key = OpenSSL::PKey.read(File.read(ENV.fetch("ASC_KEY_PATH")))
  now = Time.now.to_i
  header = { alg: "ES256", kid: ENV.fetch("GOOD_KEY_ID"), typ: "JWT" }
  payload = { iss: ENV.fetch("ASC_ISSUER_ID").strip, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }
  input = "#{b64(header.to_json)}.#{b64(payload.to_json)}"
  der = key.sign(OpenSSL::Digest.new("SHA256"), input)
  r, s = OpenSSL::ASN1.decode(der).value.map { |n| n.value.to_s(2).rjust(32, "\0")[-32..] }
  "#{input}.#{b64(r + s)}"
end

def apple(method, path, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri)
  request["Authorization"] = "Bearer #{token}"
  if body
    request["Content-Type"] = "application/json"
    request.body = body.to_json
  end
  Net::HTTP.start(uri.host, 443, use_ssl: true) { |http| http.request(request) }
end

found = apple(:get, "/v1/bundleIds?filter[identifier]=#{BUNDLE_ID}&limit=5")
abort "❌ Apple said #{found.code} when looking up the bundle ID" unless found.code == "200"
if JSON.parse(found.body)["data"].any? { |b| b.dig("attributes", "identifier") == BUNDLE_ID }
  puts "✅ #{BUNDLE_ID} is already registered"
  exit
end

created = apple(:post, "/v1/bundleIds", {
  data: { type: "bundleIds", attributes: { identifier: BUNDLE_ID, name: NAME, platform: "IOS" } }
})
if created.code == "201"
  puts "✅ Registered #{BUNDLE_ID} with Apple"
else
  detail = (JSON.parse(created.body)["errors"] || []).map { |e| e["detail"] }.join("; ") rescue created.body
  abort "❌ Couldn't register #{BUNDLE_ID} (HTTP #{created.code}): #{detail}"
end
