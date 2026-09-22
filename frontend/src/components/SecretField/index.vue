<template><div class="secret-field"><template v-if="modelValue==='__KEEP__'"><span class="meta-text">已配置 · 密钥保存在电脑上</span><el-button @click="$emit('update:modelValue','')">替换</el-button><el-button text type="danger" @click="clear">清除</el-button></template><el-input v-else :model-value="modelValue" type="password" autocomplete="new-password" placeholder="输入新的 API Key" @update:model-value="$emit('update:modelValue',$event)"/></div></template>
<script setup lang="ts">
import {ElMessageBox} from 'element-plus'
defineProps<{modelValue:string}>();const emit=defineEmits<{(e:'update:modelValue',value:string):void}>()
async function clear(){try{await ElMessageBox.confirm('保存设置后将清除这项密钥。','清除密钥',{type:'warning'});emit('update:modelValue','')}catch{}}
</script>
<style scoped>.secret-field{display:flex;align-items:center;gap:12px;flex-wrap:wrap;width:100%}</style>
