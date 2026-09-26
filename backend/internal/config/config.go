package config

type Config struct {
	DeviceID       string               `json:"device_id,omitempty"`
	DataDir        string               `json:"-"`
	SetupToken     string               `json:"setup_token"`
	App            AppConfig            `json:"app"`
	Auth           AuthConfig           `json:"auth"`
	File           FileConfig           `json:"-"`
	EmbeddingModel EmbeddingModelConfig `json:"embedding_model"`
	JWT            JWTConfig            `json:"jwt"`
	ImageOcr       ImageOcrConfig       `json:"ocr"`
	Models         []AIModelConfig      `json:"models"`
	MobileVersion  MobileVersionConfig  `json:"mobile_version"`
}
type FileConfig struct {
	Root            string
	StorageProvider string
	DefaultBucket   string
}

type AppConfig struct {
	Name string `json:"name"`
	Host string `json:"host"`
	Port int    `json:"port"`
	Env  string `json:"env"`
}

type AuthConfig struct {
	EnableRegistration bool `json:"enable_registration"`
}

type EmbeddingModelConfig struct {
	ProviderType string `json:"provider_type"`
	BaseURL      string `json:"base_url"`
	Model        string `json:"model"`
	APIKey       string `json:"api_key"`
}

type ImageOcrConfig struct {
	Name   string `json:"name"`
	Model  string `json:"model"`
	APIKey string `json:"api_key"`
}

type AIModelConfig struct {
	SavedName    string `json:"saved_name,omitempty"`
	Name         string `json:"name"`
	ProviderType string `json:"provider_type"`
	BaseURL      string `json:"base_url"`
	Model        string `json:"model"`
	APIKey       string `json:"api_key"`
}

type JWTConfig struct {
	Secret          string `json:"secret"`
	ExpirationHours int    `json:"expiration_hours"`
}

type MobileVersionConfig struct {
	DownloadURL string

	Version           string `json:"version"`
	ForceUpdate       bool   `json:"force_update"`
	UpdateDescription string `json:"update_description"`
}

func defaults() Config {
	return Config{
		App:            AppConfig{Name: "Questrace", Host: "0.0.0.0", Port: 8080, Env: "local"},
		File:           FileConfig{StorageProvider: "local", DefaultBucket: "images"},
		JWT:            JWTConfig{ExpirationHours: 168},
		ImageOcr:       ImageOcrConfig{Name: "qwen", Model: "qwen3.8-flash"},
		EmbeddingModel: EmbeddingModelConfig{ProviderType: "openai_compatible", BaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", Model: "text-embedding-v4"},
		MobileVersion:  MobileVersionConfig{Version: "2.0.0"},
	}
}
