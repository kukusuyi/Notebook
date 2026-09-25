<template><el-select :model-value="modelValue" multiple filterable clearable placeholder="选择标签" aria-label="标签筛选" @update:model-value="$emit('update:modelValue',$event)"><el-option-group v-for="(label,type) in types" :key="type" :label="label"><el-option v-for="tag in tags.filter(t=>t.tag_type===type)" :key="tag.tag_id" :value="tag.tag_id" :label="tag.tag_name"/></el-option-group></el-select><span v-if="error" role="alert">{{error}}</span></template>
<script setup lang="ts">
import {onMounted,ref} from 'vue'
import {listTags} from '@/api/tag.api'
import type {TagItem} from '@/types/tag'
defineProps<{modelValue:number[]}>();defineEmits<{'update:modelValue':[number[]]}>()
const tags=ref<TagItem[]>([]),error=ref('')
const types={knowledge_point:'知识点',problem_type:'题型',method:'解法',mistake_reason:'错因'}
onMounted(async()=>{try{tags.value=(await listTags({})).list}catch{error.value='标签加载失败，请刷新重试'}})
</script>
