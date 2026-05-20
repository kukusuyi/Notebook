package v1

import (
	"html/template"
	"net/http"
	"strconv"
	"strings"
	"time"

	"mathnotebook/backend/internal/domain/dto"
)

const (
	exportModeWithAnswers   = "with_answers"
	exportModeQuestionsOnly = "questions_only"
)

type questionExportPageData struct {
	GeneratedAt      string
	PageTitle        string
	PageDescription  string
	ShowAnswerBlocks bool
	ShowTagBlocks    bool
	ShowMetaHeader   bool
	ShowImageBlocks  bool
	Questions        []questionExportView
}

type questionExportView struct {
	Index            int
	QuestionID       int64
	Subject          string
	Chapter          string
	MasteryStatus    string
	DifficultyLevel  int
	CreatedAt        string
	UpdatedAt        string
	SourceType       string
	SourceImageURL   string
	QuestionCore     string
	StandardSolution string
	WrongSolution    string
	SemanticSummary  string
	MistakeSummary   string
	TagGroups        []questionExportTagGroup
}

type questionExportTagGroup struct {
	Label string
	Items []string
}

func renderQuestionExportHTML(w http.ResponseWriter, items []dto.QuestionExportItem, exportMode string) error {
	pageTitle := "错题导出打印页"
	pageDescription := "共 {{count}} 道错题，生成时间 {{generatedAt}}。建议在打印对话框中选择“另存为 PDF”。"
	showAnswerBlocks := true
	showTagBlocks := true
	showMetaHeader := true
	showImageBlocks := true

	if exportMode == exportModeQuestionsOnly {
		pageTitle = "仅题目导出打印页"
		pageDescription = "当前为仅题目导出模式，适合组卷。生成时间 {{generatedAt}}。"
		showAnswerBlocks = false
		showTagBlocks = false
		showMetaHeader = false
		showImageBlocks = false
	}

	data := questionExportPageData{
		GeneratedAt:      time.Now().Format("2006-01-02 15:04:05"),
		PageTitle:        pageTitle,
		ShowAnswerBlocks: showAnswerBlocks,
		ShowTagBlocks:    showTagBlocks,
		ShowMetaHeader:   showMetaHeader,
		ShowImageBlocks:  showImageBlocks,
		Questions:        make([]questionExportView, 0, len(items)),
	}
	data.PageDescription = strings.NewReplacer(
		"{{count}}", strconv.Itoa(len(items)),
		"{{generatedAt}}", data.GeneratedAt,
	).Replace(pageDescription)

	for index, item := range items {
		data.Questions = append(data.Questions, questionExportView{
			Index:            index + 1,
			QuestionID:       item.QuestionID,
			Subject:          item.Subject,
			Chapter:          item.Chapter,
			MasteryStatus:    item.MasteryStatus,
			DifficultyLevel:  item.DifficultyLevel,
			CreatedAt:        item.CreatedAt,
			UpdatedAt:        item.UpdatedAt,
			SourceType:       item.SourceType,
			SourceImageURL:   item.SourceImageURL,
			QuestionCore:     item.QuestionCore,
			StandardSolution: item.StandardSolution,
			WrongSolution:    item.WrongSolution,
			SemanticSummary:  item.SemanticSummary,
			MistakeSummary:   item.MistakeSummary,
			TagGroups:        buildExportTagGroups(item.Tags),
		})
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	return questionExportTemplate.Execute(w, data)
}

func buildExportTagGroups(tags dto.TagGroups) []questionExportTagGroup {
	type pair struct {
		label string
		items []string
	}

	pairs := []pair{
		{label: "知识点", items: tags.KnowledgePoints},
		{label: "题型", items: tags.ProblemType},
		{label: "方法", items: tags.Method},
		{label: "错因", items: tags.MistakeReason},
	}

	result := make([]questionExportTagGroup, 0, len(pairs))
	for _, pair := range pairs {
		cleaned := compactStrings(pair.items)
		if len(cleaned) == 0 {
			continue
		}
		result = append(result, questionExportTagGroup{
			Label: pair.label,
			Items: cleaned,
		})
	}

	return result
}

func compactStrings(values []string) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		result = append(result, value)
	}
	return result
}

var questionExportTemplate = template.Must(template.New("question-export").Parse(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{{.PageTitle}}</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.css" />
  <style>
    :root {
      color-scheme: light;
      --paper: #ffffff;
      --surface: #f6f1e8;
      --ink: #1f2937;
      --muted: #607086;
      --line: rgba(31, 41, 55, 0.14);
      --accent: #1e4d3f;
      --accent-soft: rgba(30, 77, 63, 0.08);
      --tag-bg: rgba(192, 103, 44, 0.12);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
      color: var(--ink);
      background: var(--surface);
    }
    .toolbar {
      position: sticky;
      top: 0;
      z-index: 10;
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: center;
      padding: 16px 24px;
      border-bottom: 1px solid var(--line);
      background: rgba(255, 251, 245, 0.94);
      backdrop-filter: blur(16px);
    }
    .toolbar h1 {
      margin: 0;
      font-size: 20px;
    }
    .toolbar p {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 13px;
    }
    .toolbar-actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
    }
    .button {
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 10px 16px;
      background: white;
      color: var(--ink);
      cursor: pointer;
      font: inherit;
    }
    .button.primary {
      background: var(--accent);
      color: white;
      border-color: var(--accent);
    }
    .container {
      width: min(1080px, calc(100vw - 32px));
      margin: 24px auto 48px;
      display: grid;
      gap: 24px;
    }
    .question {
      border: 1px solid var(--line);
      border-radius: 24px;
      background: var(--paper);
      padding: 24px;
      page-break-inside: avoid;
      break-inside: avoid;
      box-shadow: 0 16px 40px rgba(31, 41, 55, 0.08);
    }
    .question + .question {
      page-break-before: always;
    }
    .question-header {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      margin-bottom: 20px;
    }
    .question-header h2 {
      margin: 0;
      font-size: 22px;
    }
    .question-header.simple-header {
      margin-bottom: 12px;
    }
    .meta {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.8;
      text-align: right;
    }
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 16px;
      margin-bottom: 20px;
    }
    .panel {
      border: 1px solid var(--line);
      border-radius: 18px;
      overflow: hidden;
      background: #fffdf9;
    }
    .panel-title {
      padding: 12px 16px;
      font-size: 13px;
      font-weight: 700;
      color: var(--muted);
      border-bottom: 1px solid var(--line);
      background: var(--accent-soft);
    }
    .panel-body {
      padding: 16px;
    }
    .rich-text {
      white-space: pre-wrap;
      word-break: break-word;
      line-height: 1.85;
    }
    .image {
      width: 100%;
      max-height: 420px;
      object-fit: contain;
      border-radius: 14px;
      background: #f5f5f5;
      color: transparent;
      font-size: 0;
    }
    .tag-groups {
      display: grid;
      gap: 12px;
    }
    .tag-group-row {
      display: flex;
      gap: 10px;
      align-items: flex-start;
      flex-wrap: wrap;
    }
    .tag-label {
      min-width: 56px;
      color: var(--muted);
      font-weight: 700;
      padding-top: 3px;
    }
    .tag-list {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }
    .tag {
      display: inline-flex;
      align-items: center;
      min-height: 30px;
      padding: 0 12px;
      border-radius: 999px;
      background: var(--tag-bg);
      font-size: 12px;
      font-weight: 700;
    }
    .empty {
      color: var(--muted);
    }
    @media (max-width: 860px) {
      .question-header,
      .summary-grid {
        grid-template-columns: 1fr;
        display: grid;
      }
      .meta {
        text-align: left;
      }
      .toolbar {
        flex-direction: column;
        align-items: flex-start;
      }
    }
    @media print {
      body {
        background: white;
      }
      .toolbar {
        display: none;
      }
      .container {
        width: 100%;
        margin: 0;
        gap: 0;
      }
      .question {
        border: none;
        border-radius: 0;
        box-shadow: none;
        padding: 0;
      }
      .question + .question {
        margin-top: 0;
      }
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <div>
      <h1>{{.PageTitle}}</h1>
      <p>{{.PageDescription}}</p>
    </div>
    <div class="toolbar-actions">
      <button class="button" type="button" onclick="window.location.reload()">重新渲染</button>
      <button class="button primary" type="button" onclick="window.print()">打印 / 保存为 PDF</button>
    </div>
  </div>

  <main class="container">
    {{range .Questions}}
      <article class="question">
        <header class="question-header">
          <div>
            <h2>{{if $.ShowAnswerBlocks}}错题 #{{.QuestionID}}{{else}}题目 {{.Index}}{{end}}</h2>
            {{if $.ShowMetaHeader}}
              <div class="meta">{{.Subject}}{{if .Chapter}} · {{.Chapter}}{{end}}</div>
            {{end}}
          </div>
          {{if $.ShowMetaHeader}}
            <div class="meta">
              <div>掌握状态：{{.MasteryStatus}}</div>
              <div>难度：{{.DifficultyLevel}}</div>
              <div>来源：{{.SourceType}}</div>
              <div>创建：{{.CreatedAt}}</div>
              <div>更新：{{.UpdatedAt}}</div>
            </div>
          {{end}}
        </header>

        {{if and $.ShowImageBlocks .SourceImageURL}}
          <section class="panel" style="margin-bottom: 16px;" data-image-panel>
            <div class="panel-title">原图</div>
            <div class="panel-body">
              <img
                class="image"
                src="{{.SourceImageURL}}"
                alt=""
                referrerpolicy="no-referrer"
                onerror="this.closest('[data-image-panel]').remove()"
              />
            </div>
          </section>
        {{end}}

        <section class="panel" style="margin-bottom: 16px;">
          <div class="panel-title">题目主干</div>
          <div class="panel-body rich-text math-content">{{.QuestionCore}}</div>
        </section>

        {{if $.ShowAnswerBlocks}}
          <section class="summary-grid">
            <section class="panel">
              <div class="panel-title">标准解法</div>
              <div class="panel-body rich-text math-content">{{if .StandardSolution}}{{.StandardSolution}}{{else}}暂无标准解法{{end}}</div>
            </section>
            <section class="panel">
              <div class="panel-title">错误解法 / 错误思路</div>
              <div class="panel-body rich-text math-content">{{if .WrongSolution}}{{.WrongSolution}}{{else}}暂无错误解法{{end}}</div>
            </section>
          </section>

          <section class="summary-grid">
            <section class="panel">
              <div class="panel-title">语义摘要</div>
              <div class="panel-body rich-text">{{if .SemanticSummary}}{{.SemanticSummary}}{{else}}暂无语义摘要{{end}}</div>
            </section>
            <section class="panel">
              <div class="panel-title">错因摘要</div>
              <div class="panel-body rich-text">{{if .MistakeSummary}}{{.MistakeSummary}}{{else}}暂无错因摘要{{end}}</div>
            </section>
          </section>
        {{end}}

        {{if $.ShowTagBlocks}}
          <section class="panel">
            <div class="panel-title">标签</div>
            <div class="panel-body">
              {{if .TagGroups}}
                <div class="tag-groups">
                  {{range .TagGroups}}
                    <div class="tag-group-row">
                      <div class="tag-label">{{.Label}}</div>
                      <div class="tag-list">
                        {{range .Items}}
                          <span class="tag">{{.}}</span>
                        {{end}}
                      </div>
                    </div>
                  {{end}}
                </div>
              {{else}}
                <div class="empty">暂无标签</div>
              {{end}}
            </div>
          </section>
        {{end}}
      </article>
    {{end}}
  </main>

  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/contrib/auto-render.min.js"></script>
  <script>
    window.addEventListener('load', function () {
      if (window.renderMathInElement) {
        document.querySelectorAll('.math-content').forEach(function (element) {
          try {
            window.renderMathInElement(element, {
              delimiters: [
                { left: '$$', right: '$$', display: true },
                { left: '$', right: '$', display: false },
                { left: '\\\\(', right: '\\\\)', display: false },
                { left: '\\\\[', right: '\\\\]', display: true }
              ],
              throwOnError: false,
              strict: 'ignore'
            })
          } catch (error) {
            console.warn('render math failed', error)
          }
        })
      }

      window.setTimeout(function () {
        window.print()
      }, 350)
    })
  </script>
</body>
</html>
`))
