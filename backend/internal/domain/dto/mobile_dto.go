package dto

type MobileVersionResponse struct {
	Version           string `json:"version"`
	APKUrl            string `json:"apk_url"`
	ForceUpdate       bool   `json:"force_update"`
	UpdateDescription string `json:"update_description,omitempty"`
}
