{ pkgs, lib ? pkgs.lib, config ? null, ... }:

let
  # Default configuration for local development
  defaultConfig = {
    port = 3001;
    url = "http://localhost:3001";
    database = {
      host = "twenty-db-1";
      port = 5432;
      user = "postgres";
      password = "postgres";
      passwordFile = null;
      database = "outline";
    };
    redis = {
      host = "twenty-redis-1";
      port = 6379;
    };
    secretKey = "replace_me_with_a_random_string";
    secretKeyFile = null;
    utilsSecret = "replace_me_with_another_random_string";
    utilsSecretFile = null;
    auth = {
      google = {
        enabled = false;
        clientIdFile = null;
        clientSecretFile = null;
      };
    };
    smtp = {
      enabled = false;
      host = "smtp.gmail.com";
      port = 587;
      user = "";
      passwordFile = null;
      fromEmail = "";
      replyEmail = "";
    };
  };

  # Use provided config or fallback to defaults
  cfg = lib.recursiveUpdate defaultConfig (if config != null then config else {});

  # Non-secret environment variables always included
  baseEnv = {
    NODE_ENV = "production";
    URL = cfg.url;
    PORT = toString cfg.port;
    
    # Redis configuration (non-secret)
    REDIS_URL = "redis://${cfg.redis.host}:${toString cfg.redis.port}";
    
    # Required settings
    FORCE_HTTPS = "false";
    ENABLE_UPDATES = "false";
    PGSSLMODE = "disable";
    
    # File storage configuration (use local storage instead of S3)
    FILE_STORAGE = "local";
    FILE_STORAGE_LOCAL_ROOT_DIR = "/var/lib/outline/data";
    
    # SMTP configuration
  } // lib.optionalAttrs cfg.smtp.enabled {
    SMTP_HOST = cfg.smtp.host;
    SMTP_PORT = toString cfg.smtp.port;
    SMTP_USERNAME = cfg.smtp.user;
    SMTP_FROM_EMAIL = cfg.smtp.fromEmail;
    SMTP_REPLY_EMAIL = cfg.smtp.replyEmail;
    SMTP_SECURE = "true";
  } // lib.optionalAttrs cfg.slack.enabled {
    # Slack configuration
    SLACK_APP_ID = cfg.slack.appId;
    SLACK_MESSAGE_ACTIONS = toString cfg.slack.messageActions;
  };
  
  # Environment variables for container
  # When using secret files, only include baseEnv
  # All secrets will be provided via the env file created by systemd preStart
  environment = baseEnv;
  
  # Environment file for containers when using secrets
  envFile = lib.optionals (cfg.database.passwordFile != null || cfg.secretKeyFile != null || cfg.utilsSecretFile != null) [
    "/run/outline/env"
  ];
  
  # Volume mounts for secrets
  secretVolumes = lib.optionals (cfg.database.passwordFile != null || cfg.secretKeyFile != null || cfg.utilsSecretFile != null) [
    "/run/agenix:/secrets:ro"
  ];
in
{
  project.name = "outline";
  
  # Network configuration to connect with Twenty's containers
  networks.default.external = false;
  networks.twenty = {
    external = true;
  };

  services = {
    # Outline application
    outline = {
      service = {
        image = "docker.getoutline.com/outlinewiki/outline:latest";
        ports = [ "${toString cfg.port}:${toString cfg.port}" ];
        
        volumes = [
          "outline-data:/var/lib/outline/data"
        ] ++ secretVolumes;
        
        environment = environment;
        
        env_file = envFile;
        
        networks = [ "default" "twenty" ];
        
        restart = "always";
        
        # Start the application (migrations handled separately)
        command = [ "yarn" "start" ];
      };
    };
  };

  # Docker volumes
  docker-compose.volumes = {
    outline-data = {};
  };
}