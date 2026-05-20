package errors

type AppError struct {
	Status  int
	Code    int
	Message string
}

func (e *AppError) Error() string {
	return e.Message
}

func New(status, code int, message string) *AppError {
	return &AppError{
		Status:  status,
		Code:    code,
		Message: message,
	}
}
