package v1

import (
	"html/template"
	"net/http"

	"github.com/kukusuyi/Questrace/backend/internal/domain/dto"
)

// Keep accepting legacy mode values; all PDF exports now use question-only A4 sheets.
const (
	exportModeWithAnswers   = "with_answers"
	exportModeQuestionsOnly = "questions_only"
)

type printQuestion struct {
	Index       int
	Core, Image string
}
type printSheet struct{ Questions []printQuestion }

func renderQuestionExportHTML(w http.ResponseWriter, items []dto.QuestionExportItem, _ string) error {
	sheets := make([]printSheet, 0, (len(items)+1)/2)
	for i, item := range items {
		if i%2 == 0 {
			sheets = append(sheets, printSheet{})
		}
		n := len(sheets) - 1
		sheets[n].Questions = append(sheets[n].Questions, printQuestion{Index: i + 1, Core: item.QuestionCore, Image: item.SourceImageURL})
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	return questionExportTemplate.Execute(w, sheets)
}

var questionExportTemplate = template.Must(template.New("question-export").Parse(`<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>题目导出 · A4 每页两题</title>
<link rel="stylesheet" href="/print-katex/katex.min.css">
<style>
@page { size:A4 portrait; margin:12mm; }
* { box-sizing:border-box; }
:root { color-scheme:light; }
body { margin:0; color:#000; background:#eee; font:16px/1.6 "PingFang SC","Microsoft YaHei",sans-serif; }
.toolbar { padding:12px 20px; background:#fff; display:flex; flex-wrap:wrap; gap:12px; align-items:center; }
button { font:inherit; padding:8px 16px; cursor:pointer; }
.sheet { width:186mm; height:272mm; margin:24px auto; background:white; display:grid; grid-template-rows:136mm 136mm; break-after:page; page-break-after:always; }
.sheet:last-child { break-after:auto; page-break-after:auto; }
.question { min-width:0; min-height:0; padding:8mm 0; break-inside:avoid; }
.question-content { transform-origin:top left; }
.number { float:left; margin-right:8px; }
.math-content { white-space:pre-wrap; overflow-wrap:anywhere; }
.katex-display { margin:8px 0; }
.image { display:block; max-width:100%; max-height:110mm; object-fit:contain; }
@media screen and (max-width:740px) { body { overflow-x:auto; }.toolbar { position:sticky;left:0;width:100vw; }.sheet { margin:16px; } }
@media print { body { background:#fff; }.toolbar { display:none; }.sheet { margin:0; } }
</style></head><body>
<div class="toolbar"><button id="print" disabled onclick="window.print()">打印 / 保存 PDF</button><span id="status">正在准备公式…</span></div>
<main>{{range .}}<section class="sheet">{{range .Questions}}<article class="question"><div class="question-content"><span class="number">{{.Index}}.</span>{{if .Core}}<div class="math-content">{{.Core}}</div>{{else if .Image}}<img class="image" src="{{.Image}}" alt="题目图片">{{end}}</div></article>{{end}}</section>{{end}}</main>
<script defer src="/print-katex/katex.min.js"></script><script defer src="/print-katex/auto-render.min.js"></script>
<script>
function fitQuestions() {
 let small=false;
 document.querySelectorAll('.question').forEach(function(slot) {
  const content=slot.querySelector('.question-content');content.style.transform='';
  const style=getComputedStyle(slot),height=slot.clientHeight-parseFloat(style.paddingTop)-parseFloat(style.paddingBottom);
  const scale=Math.min(1,height/Math.max(1,content.scrollHeight),slot.clientWidth/Math.max(1,content.scrollWidth));
  if(scale<1)content.style.transform='scale('+scale+')';
  if(scale<0.65)small=true;
 });
 return small;
}
window.addEventListener('beforeprint',fitQuestions);
window.addEventListener('load',async function(){
 const status=document.getElementById('status');
 if(!window.renderMathInElement){status.textContent='公式资源加载失败，请刷新后重试。';return;}
 document.querySelectorAll('.math-content').forEach(function(el){renderMathInElement(el,{delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false},{left:'\\(',right:'\\)',display:false},{left:'\\[',right:'\\]',display:true}],throwOnError:false,strict:'ignore'});});
 await document.fonts.ready;
 const missing=Array.from(document.images).some(function(i){return !i.naturalWidth;});
 if(missing){status.textContent='题目图片加载失败，请刷新后重试。';return;}
 const small=fitQuestions();
 status.textContent=small?'部分题目较长，已缩小以适应半页，请检查字号。':'A4 纵向 · 每页两题。打印时关闭浏览器页眉和页脚，缩放选 100%。';
 document.getElementById('print').disabled=false;
});
</script></body></html>`))
