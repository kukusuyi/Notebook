package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	App            AppConfig            `yaml:"app"`
	Auth           AuthConfig           `yaml:"auth"`
	DB             DBConfig             `yaml:"db"`
	DefaultUser    DefaultUserConfig    `yaml:"default_user"`
	File           FileConfig           `yaml:"file"`
	Vector         VectorConfig         `yaml:"vector"`
	EmbeddingModel EmbeddingModelConfig `yaml:"embedding_model"`
	JWT            JWTConfig            `yaml:"jwt"`
	ImageOcr       ImageOcrConfig       `yaml:"imageOcr"`
	Models         []AIModelConfig      `yaml:"models"`
	MobileVersion  MobileVersionConfig  `yaml:"mobile_version"`
}

type AppConfig struct {
	Name string `yaml:"name"`
	Host string `yaml:"host"`
	Port int    `yaml:"port"`
	Env  string `yaml:"env"`
}

type AuthConfig struct {
	EnableRegistration bool `yaml:"enable_registration"`
}

type DBConfig struct {
	Host     string `yaml:"host"`
	Port     int    `yaml:"port"`
	User     string `yaml:"user"`
	Password string `yaml:"password"`
	Name     string `yaml:"name"`
}

func (c DBConfig) DSN() string {
	return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci",
		c.User, c.Password, c.Host, c.Port, c.Name)
}

type DefaultUserConfig struct {
	ID       int64  `yaml:"id"`
	Username string `yaml:"username"`
	Email    string `yaml:"email"`
}

type FileConfig struct {
	BaseURL         string         `yaml:"base_url"`
	DefaultBucket   string         `yaml:"bucket"`
	StorageProvider string         `yaml:"provider"`
	MinIO           MinIOConfig    `yaml:"minio"`
	LightCOS        LightCOSConfig `yaml:"lightcos"`
}

type MinIOConfig struct {
	Endpoint         string `yaml:"endpoint"`
	AccessKey        string `yaml:"access_key"`
	SecretKey        string `yaml:"secret_key"`
	UseSSL           bool   `yaml:"use_ssl"`
	Region           string `yaml:"region"`
	PublicBaseURL    string `yaml:"public_base_url"`
	AutoCreateBucket bool   `yaml:"auto_create_bucket"`
	PublicRead       bool   `yaml:"public_read"`
}

type LightCOSConfig struct {
	BucketURL     string `yaml:"bucket_url"`
	SecretID      string `yaml:"secret_id"`
	SecretKey     string `yaml:"secret_key"`
	PublicBaseURL string `yaml:"public_base_url"`
}

type VectorConfig struct {
	CollectionName string `yaml:"collection_name"`
	QdrantURL      string `yaml:"qdrant_url"`
	APIKey         string `yaml:"api_key"`
	Distance       string `yaml:"distance"`
	TimeoutSeconds int    `yaml:"timeout_seconds"`
}

type EmbeddingModelConfig struct {
	ProviderType string `yaml:"provider_type"`
	BaseURL      string `yaml:"base_url"`
	Model        string `yaml:"model"`
	APIKey       string `yaml:"api_key"`
}

type ImageOcrConfig struct {
	Name   string `yaml:"name"`
	Model  string `yaml:"model"`
	APIKey string `yaml:"api_key"`
}

type AIModelConfig struct {
	Name         string `yaml:"name"`
	ProviderType string `yaml:"provider_type"`
	BaseURL      string `yaml:"base_url"`
	Model        string `yaml:"model"`
	APIKey       string `yaml:"api_key"`
}

type JWTConfig struct {
	Secret          string `yaml:"secret"`
	ExpirationHours int    `yaml:"expiration_hours"`
}

type MobileVersionConfig struct {
	Version           string `yaml:"version"`
	APKFilename       string `yaml:"apk_filename"`
	ForceUpdate       bool   `yaml:"force_update"`
	UpdateDescription string `yaml:"update_description"`
}

const configPath = "configs/config.yaml"

func Load() Config {
	cfg := defaults()

	path := configPath
	if v, ok := os.LookupEnv("CONFIG_PATH"); ok && v != "" {
		path = v
	}

	data, err := os.ReadFile(path)
	if err == nil {
		if err := yaml.Unmarshal(data, &cfg); err == nil {
		}
	}

	mergeEnv(&cfg)

	return cfg
}

func defaults() Config {
	return Config{
		App: AppConfig{
			Name: "math-notebook-backend",
			Host: "0.0.0.0",
			Port: 8080,
			Env:  "local",
		},
		Auth: AuthConfig{
			EnableRegistration: true,
		},
		DB: DBConfig{
			Host: "localhost",
			Port: 3306,
			User: "root",
			Name: "wrong_question_book",
		},
		DefaultUser: DefaultUserConfig{
			ID:       1,
			Username: "default_user",
			Email:    "default@example.com",
		},
		File: FileConfig{
			BaseURL:         "http://127.0.0.1:9000",
			DefaultBucket:   "wrong-question-images",
			StorageProvider: "oss",
			MinIO: MinIOConfig{
				Endpoint:         "127.0.0.1:9000",
				AccessKey:        "admin",
				SecretKey:        "",
				UseSSL:           false,
				PublicBaseURL:    "http://127.0.0.1:9000",
				AutoCreateBucket: true,
				PublicRead:       true,
			},
			LightCOS: LightCOSConfig{},
		},
		Vector: VectorConfig{
			CollectionName: "wrong_question_vectors",
			QdrantURL:      "http://127.0.0.1:6333",
			APIKey:         "",
			Distance:       "Cosine",
			TimeoutSeconds: 30,
		},
		EmbeddingModel: EmbeddingModelConfig{
			ProviderType: "qwen",
			BaseURL:      "https://dashscope.aliyuncs.com/compatible-mode/v1",
			Model:        "text-embedding-v4",
		},
		JWT: JWTConfig{
			Secret:          "",
			ExpirationHours: 168,
		},
	}
}

func mergeEnv(cfg *Config) {
	if v, ok := os.LookupEnv("APP_NAME"); ok && v != "" {
		cfg.App.Name = v
	}
	if v, ok := os.LookupEnv("APP_HOST"); ok && v != "" {
		cfg.App.Host = v
	}
	if v := envInt("APP_PORT"); v != 0 {
		cfg.App.Port = v
	}
	if v, ok := os.LookupEnv("APP_ENV"); ok && v != "" {
		cfg.App.Env = v
	}
	if v, ok := envBool("AUTH_ENABLE_REGISTRATION"); ok {
		cfg.Auth.EnableRegistration = v
	}

	if v, ok := os.LookupEnv("DB_HOST"); ok && v != "" {
		cfg.DB.Host = v
	}
	if v := envInt("DB_PORT"); v != 0 {
		cfg.DB.Port = v
	}
	if v, ok := os.LookupEnv("DB_USER"); ok && v != "" {
		cfg.DB.User = v
	}
	if v, ok := os.LookupEnv("DB_PASSWORD"); ok && v != "" {
		cfg.DB.Password = v
	}
	if v, ok := os.LookupEnv("DB_NAME"); ok && v != "" {
		cfg.DB.Name = v
	}

	if v, ok := os.LookupEnv("JWT_SECRET"); ok && v != "" {
		cfg.JWT.Secret = v
	}
	if v := envInt("JWT_EXPIRATION_HOURS"); v != 0 {
		cfg.JWT.ExpirationHours = v
	}

	if v, ok := os.LookupEnv("FILE_PROVIDER"); ok && v != "" {
		cfg.File.StorageProvider = v
	}
	if v, ok := os.LookupEnv("FILE_BUCKET"); ok && v != "" {
		cfg.File.DefaultBucket = v
	}
	if v, ok := os.LookupEnv("FILE_BASE_URL"); ok && v != "" {
		cfg.File.BaseURL = v
	}
	if v, ok := os.LookupEnv("VECTOR_COLLECTION_NAME"); ok && v != "" {
		cfg.Vector.CollectionName = v
	}
	if v, ok := os.LookupEnv("QDRANT_URL"); ok && v != "" {
		cfg.Vector.QdrantURL = v
	}
	if v, ok := os.LookupEnv("QDRANT_API_KEY"); ok && v != "" {
		cfg.Vector.APIKey = v
	}
	if v, ok := os.LookupEnv("VECTOR_DISTANCE"); ok && v != "" {
		cfg.Vector.Distance = v
	}
	if v := envInt("VECTOR_TIMEOUT_SECONDS"); v != 0 {
		cfg.Vector.TimeoutSeconds = v
	}
	if v, ok := os.LookupEnv("MINIO_ENDPOINT"); ok && v != "" {
		cfg.File.MinIO.Endpoint = v
	}
	if v, ok := os.LookupEnv("MINIO_ACCESS_KEY"); ok && v != "" {
		cfg.File.MinIO.AccessKey = v
	}
	if v, ok := os.LookupEnv("MINIO_SECRET_KEY"); ok && v != "" {
		cfg.File.MinIO.SecretKey = v
	}
	if v, ok := os.LookupEnv("MINIO_REGION"); ok && v != "" {
		cfg.File.MinIO.Region = v
	}
	if v, ok := os.LookupEnv("MINIO_PUBLIC_BASE_URL"); ok && v != "" {
		cfg.File.MinIO.PublicBaseURL = v
	}
	if v, ok := envBool("MINIO_USE_SSL"); ok {
		cfg.File.MinIO.UseSSL = v
	}
	if v, ok := envBool("MINIO_AUTO_CREATE_BUCKET"); ok {
		cfg.File.MinIO.AutoCreateBucket = v
	}
	if v, ok := envBool("MINIO_PUBLIC_READ"); ok {
		cfg.File.MinIO.PublicRead = v
	}
	if v, ok := os.LookupEnv("LIGHTCOS_BUCKET_URL"); ok && v != "" {
		cfg.File.LightCOS.BucketURL = v
	}
	if v, ok := os.LookupEnv("LIGHTCOS_SECRET_ID"); ok && v != "" {
		cfg.File.LightCOS.SecretID = v
	}
	if v, ok := os.LookupEnv("LIGHTCOS_SECRET_KEY"); ok && v != "" {
		cfg.File.LightCOS.SecretKey = v
	}
	if v, ok := os.LookupEnv("LIGHTCOS_PUBLIC_BASE_URL"); ok && v != "" {
		cfg.File.LightCOS.PublicBaseURL = v
	}

	if v, ok := os.LookupEnv("DASHSCOPE_API_KEY"); ok && v != "" {
		cfg.ImageOcr.APIKey = v
	}
	if v, ok := os.LookupEnv("EMBEDDING_PROVIDER_TYPE"); ok && v != "" {
		cfg.EmbeddingModel.ProviderType = v
	}
	if v, ok := os.LookupEnv("EMBEDDING_BASE_URL"); ok && v != "" {
		cfg.EmbeddingModel.BaseURL = v
	}
	if v, ok := os.LookupEnv("EMBEDDING_MODEL"); ok && v != "" {
		cfg.EmbeddingModel.Model = v
	}
	if v, ok := os.LookupEnv("EMBEDDING_API_KEY"); ok && v != "" {
		cfg.EmbeddingModel.APIKey = v
	}
}

func (c AppConfig) Address() string {
	return fmt.Sprintf("%s:%d", c.Host, c.Port)
}

func (c FileConfig) PublicBaseURL() string {
	switch NormalizeStorageProvider(c.StorageProvider) {
	case "lightcos":
		if c.LightCOS.PublicBaseURL != "" {
			return c.LightCOS.PublicBaseURL
		}
	default:
		if c.MinIO.PublicBaseURL != "" {
			return c.MinIO.PublicBaseURL
		}
	}

	return c.BaseURL
}

func NormalizeStorageProvider(provider string) string {
	switch strings.ToLower(strings.TrimSpace(provider)) {
	case "cos", "lighthouse", "lighthousecos":
		return "lightcos"
	default:
		return strings.ToLower(strings.TrimSpace(provider))
	}
}

func envInt(key string) int {
	value, err := strconv.Atoi(os.Getenv(key))
	if err != nil {
		return 0
	}

	return value
}

func envBool(key string) (bool, bool) {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return false, false
	}

	value, err := strconv.ParseBool(raw)
	if err != nil {
		return false, false
	}

	return value, true
}
