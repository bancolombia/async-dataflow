import Config

config :channel_sender_ex,
  config_file: "/app/config/config.yaml"

config :ex_aws,
  region: "us-east-1",
  access_key_id: [
    {:system, "AWS_ACCESS_KEY_ID"},
    {:awscli, "default", 30},
    :instance_role
  ],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, "default", 30},
    :instance_role
  ],
  security_token: {:system, "AWS_SESSION_TOKEN"},
  awscli_auth_adapter: ExAws.STS.AuthCache.AssumeRoleCredentialsAdapter
