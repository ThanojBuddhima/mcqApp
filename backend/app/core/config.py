from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "MCQ Platform"
    app_env: str = "development"
    debug: bool = True
    api_v1_prefix: str = "/api/v1"

    database_url: str = "postgresql+asyncpg://mcq:mcq_secret@localhost:5432/mcq_db"
    database_url_sync: str = "postgresql://mcq:mcq_secret@localhost:5432/mcq_db"

    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"

    jwt_secret_key: str = "change-me-to-a-long-random-secret-key"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    google_client_id: str = ""
    google_client_secret: str = ""

    s3_endpoint: str = "http://localhost:9000"
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
    s3_bucket: str = "mcq-uploads"
    s3_region: str = "us-east-1"
    s3_use_ssl: bool = False

    gemini_api_key: str = ""
    openai_api_key: str = ""

    payhere_merchant_id: str = ""
    payhere_merchant_secret: str = ""
    payhere_sandbox: bool = True

    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    cors_allow_localhost_regex: bool = True

    max_upload_size_mb: int = 25

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def is_development(self) -> bool:
        return self.app_env.lower() in ("development", "dev", "local")


settings = Settings()
