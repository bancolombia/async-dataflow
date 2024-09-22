defmodule AwsConfigTest do
  alias StreamsSecretManager.AwsConfig
  use ExUnit.Case, async: false

  test "Should obtain configure env" do
    cfg = %{
      :aws => %{
        "region" => "us-east-1",
        "secretsmanager" => %{}
      },
    }
    AwsConfig.setup_aws_config(cfg)
  end

  test "Should obtain configure with env keys" do
    cfg = %{
      :aws => %{
        "region" => "us-east-1",
        "creds" => %{
          "access_key_id" => ["SYSTEM:xxxx"],
          "secret_access_key" => ["SYSTEM:xxxx"]
        }
      },
    }
    AwsConfig.setup_aws_config(cfg)
  end

  test "Should obtain configure with instance role" do
    cfg = %{
      :aws => %{
        "region" => "us-east-1",
        "creds" => %{
          "access_key_id" => ["xxxx"],
          "secret_access_key" => ["xxxx"]
        }
      },
    }
    AwsConfig.setup_aws_config(cfg)
  end
end
