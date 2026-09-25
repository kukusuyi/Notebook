package v1

import (
	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
	apperrors "github.com/kukusuyi/Questrace/backend/internal/pkg/errors"
	"github.com/kukusuyi/Questrace/backend/internal/service"
	"net/http"
	"strconv"
	"strings"
)

type ReviewHandler struct{ Service service.ReviewService }

func (h ReviewHandler) Serve(w http.ResponseWriter, r *http.Request, uid int64) {
	svc := h.Service
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/reviews/")
	var out any
	var err error
	switch {
	case path == "summary" && r.Method == "GET":
		out, err = svc.Summary(uid)
	case path == "history" && r.Method == "GET":
		out, err = svc.History(uid)
	case path == "sessions" && r.Method == "POST":
		var in service.ReviewCreate
		if dto.DecodeJSON(r, &in) != nil {
			reviewFail(w, 400, "请求格式错误")
			return
		}
		out, err = svc.Create(uid, in)
	case strings.HasPrefix(path, "sessions/"):
		parts := strings.Split(path, "/")
		id, e := strconv.ParseInt(parts[1], 10, 64)
		if e != nil || id < 1 {
			reviewFail(w, 400, "练习编号无效")
			return
		}
		if len(parts) == 2 && r.Method == "GET" {
			out, err = svc.Get(uid, id)
		} else if len(parts) == 3 && parts[2] == "results" && r.Method == "POST" {
			var in service.ReviewSubmit
			if dto.DecodeJSON(r, &in) != nil {
				reviewFail(w, 400, "请求格式错误")
				return
			}
			out, err = svc.Submit(uid, id, in)
		} else {
			reviewFail(w, 405, "不支持此操作")
			return
		}
	default:
		reviewFail(w, 404, "接口不存在")
		return
	}
	if err != nil {
		dto.HandleError(w, err)
		return
	}
	dto.WriteSuccess(w, out)
}

func reviewFail(w http.ResponseWriter, status int, message string) {
	dto.HandleError(w, apperrors.New(status, status*100, message))
}
