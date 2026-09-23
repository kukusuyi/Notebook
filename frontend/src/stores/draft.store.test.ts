import { beforeEach, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { nextTick } from 'vue'
import { useDraftStore } from './draft.store'
import type { AnalyzeWrongQuestionResponse } from '@/types/ai'
beforeEach(()=>{sessionStorage.clear();setActivePinia(createPinia())})
it('restores original content when analysis is rejected, including after reload',async()=>{let store=useDraftStore();const original=store.ensureDraft();original.question_json.question_core='手动整理的内容';original.chapter='原章节';store.applyAnalysis({chapter:'AI章节',tags:original.tags,semantic_summary:'AI总结',mistake_summary:'AI错因'} as AnalyzeWrongQuestionResponse);await nextTick();expect(store.currentDraft?.chapter).toBe('AI章节');setActivePinia(createPinia());store=useDraftStore();store.discardAnalysis();expect(store.currentDraft?.chapter).toBe('原章节');expect(store.currentDraft?.question_json.question_core).toBe('手动整理的内容');store.resetDraft();expect(sessionStorage.getItem('math-notebook:draft:before-analysis')).toBeNull()})
it('does not discard a draft when choosing another entry point',()=>{const store=useDraftStore();store.ensureDraft().question_json.question_core='待整理';store.ensureDraft('upload');expect(store.currentDraft?.question_json.question_core).toBe('待整理')})
it('deleting a resumed draft remains deleted after reload', async()=>{
 let store=useDraftStore();store.ensureDraft().question_json.question_core='未完成';await nextTick();
 setActivePinia(createPinia());store=useDraftStore();expect(store.currentDraft).not.toBeNull();
 store.resetDraft();await nextTick();setActivePinia(createPinia());expect(useDraftStore().currentDraft).toBeNull();
})
