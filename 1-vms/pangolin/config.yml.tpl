gerbil:
  base_endpoint: "${DOMAIN}"
  start_port: 51820

app:
  dashboard_url: "https://${DOMAIN}"
  log_level: "info"
  telemetry:
    anonymous_usage: true

domains:
  default:
    base_domain: "${DOMAIN}"
    cert_resolver: "letsencrypt"

server:
  secret: "${SERVER_SECRET}"
  cors:
    origins: ["https://${DOMAIN}"]
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH"]
    allowed_headers: ["X-CSRF-Token", "Content-Type"]
    credentials: false

flags:
  require_email_verification: false
  disable_signup_without_invite: true
  disable_user_create_org: true
  allow_raw_resources: true
