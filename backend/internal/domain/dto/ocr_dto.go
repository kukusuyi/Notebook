package dto

type OCRWrongQuestionRequest struct {
	ImageURL string `json:"image_url"`
	ImageID  int64  `json:"image_id"`
}

type OCRContext struct {
	OCRConfidence  string   `json:"ocr_confidence"`
	UncertainParts []string `json:"uncertain_parts"`
}

type OCRWrongQuestionResponse struct {
	QuestionCore     string   `json:"question_core"`
	StandardSolution string   `json:"standard_solution"`
	WrongSolution    string   `json:"wrong_solution"`
	OCRConfidence    string   `json:"ocr_confidence"`
	UncertainParts   []string `json:"uncertain_parts"`
}
