package test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"strings"
)

type apiResponse struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

func do(method, url, token string, body any) (*http.Response, []byte, error) {
	var reqBody io.Reader
	var contentType string
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, nil, fmt.Errorf("marshal body: %w", err)
		}
		reqBody = bytes.NewReader(data)
		contentType = "application/json"
	}

	return doRequest(method, url, token, contentType, reqBody)
}

func doMultipart(url, token string, fields map[string]string, fileField, fileName string, fileContent []byte) (*http.Response, []byte, error) {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	for key, val := range fields {
		_ = w.WriteField(key, val)
	}

	fw, err := w.CreateFormFile(fileField, fileName)
	if err != nil {
		return nil, nil, fmt.Errorf("create form file: %w", err)
	}
	if _, err := fw.Write(fileContent); err != nil {
		return nil, nil, fmt.Errorf("write file: %w", err)
	}
	w.Close()

	return doRequest(http.MethodPost, url, token, w.FormDataContentType(), &buf)
}

func doRequest(method, url, token, contentType string, body io.Reader) (*http.Response, []byte, error) {
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, nil, fmt.Errorf("new request: %w", err)
	}

	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("do request: %w", err)
	}

	respBody, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		return nil, nil, fmt.Errorf("read body: %w", err)
	}

	return resp, respBody, nil
}

func doGet(url, token string) (*http.Response, []byte, error) {
	return do(http.MethodGet, url, token, nil)
}

func doPost(url, token string, body any) (*http.Response, []byte, error) {
	return do(http.MethodPost, url, token, body)
}

func doPut(url, token string, body any) (*http.Response, []byte, error) {
	return do(http.MethodPut, url, token, body)
}

func doDelete(url, token string) (*http.Response, []byte, error) {
	return do(http.MethodDelete, url, token, nil)
}

func parseResponse(body []byte) (apiResponse, error) {
	var resp apiResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return resp, fmt.Errorf("unmarshal response: %w", err)
	}
	return resp, nil
}

func unmarshalData[T any](body []byte) (T, error) {
	var resp apiResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		var zero T
		return zero, fmt.Errorf("unmarshal response: %w", err)
	}
	var data T
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		var zero T
		return zero, fmt.Errorf("unmarshal data: %w", err)
	}
	return data, nil
}

func containsIgnoreCase(haystack, needle string) bool {
	return strings.Contains(strings.ToLower(haystack), strings.ToLower(needle))
}
