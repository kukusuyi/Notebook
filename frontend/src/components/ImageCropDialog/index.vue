<template>
 <el-dialog :model-value="open" title="裁剪图片" append-to-body align-center width="min(760px, 94vw)" :close-on-click-modal="false" :close-on-press-escape="!busy" :show-close="!busy" @update:model-value="!busy&&emit('cancel')">
  <p class="meta-text">拖动框选需要保留的区域，也可以使用下方滑块微调。取消不会修改原图。</p>
  <div class="crop-stage" @pointerdown="start" @pointermove="move" @pointerup="finish" @pointercancel="finish"><img ref="image" :src="src" alt="待裁剪的图片" draggable="false" @load="loaded=true" @error="loaded=false"/><div v-if="loaded" class="crop-selection" :style="{left:left+'%',top:top+'%',width:(right-left)+'%',height:(bottom-top)+'%'}"/></div>
  <p v-if="!loaded" role="status">正在读取图片；若无法显示，请重新选择 JPG、PNG 或 WebP 图片。</p>
  <div class="crop-controls"><label>左边界<input v-model.number="left" type="range" min="0" :max="right-1" :disabled="busy"/></label><label>右边界<input v-model.number="right" type="range" :min="left+1" max="100" :disabled="busy"/></label><label>上边界<input v-model.number="top" type="range" min="0" :max="bottom-1" :disabled="busy"/></label><label>下边界<input v-model.number="bottom" type="range" :min="top+1" max="100" :disabled="busy"/></label></div>
  <p v-if="error" role="alert">{{error}}</p>
  <template #footer><el-button :disabled="busy" @click="emit('cancel')">取消</el-button><el-button :disabled="busy" @click="reset">保留整张</el-button><el-button type="primary" :disabled="!loaded" :loading="busy" @click="confirm">确认裁剪并上传</el-button></template>
 </el-dialog>
</template>
<script setup lang="ts">
import {ref,watch} from 'vue'
const props=defineProps<{open:boolean;src:string;busy:boolean}>(),emit=defineEmits<{(e:'cancel'):void;(e:'confirm',file:File):void}>()
const image=ref<HTMLImageElement>(),left=ref(0),top=ref(0),right=ref(100),bottom=ref(100),loaded=ref(false),error=ref('')
let anchor:{x:number;y:number}|null=null
function reset(){left.value=top.value=0;right.value=bottom.value=100;error.value=''}
watch(()=>props.src,()=>{loaded.value=false;reset()})
function point(e:PointerEvent){const r=image.value!.getBoundingClientRect();return {x:Math.max(0,Math.min(100,(e.clientX-r.left)/r.width*100)),y:Math.max(0,Math.min(100,(e.clientY-r.top)/r.height*100))}}
function start(e:PointerEvent){if(props.busy||!loaded.value)return;anchor=point(e);(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)}
function move(e:PointerEvent){if(!anchor||props.busy)return;const p=point(e);left.value=Math.min(anchor.x,p.x);right.value=Math.max(anchor.x,p.x);top.value=Math.min(anchor.y,p.y);bottom.value=Math.max(anchor.y,p.y)}
function finish(){anchor=null;if(right.value-left.value<1||bottom.value-top.value<1)reset()}
function confirm(){if(props.busy||!image.value||!loaded.value)return;const img=image.value,canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(img.naturalWidth*(right.value-left.value)/100));canvas.height=Math.max(1,Math.round(img.naturalHeight*(bottom.value-top.value)/100));try{canvas.getContext('2d')!.drawImage(img,img.naturalWidth*left.value/100,img.naturalHeight*top.value/100,canvas.width,canvas.height,0,0,canvas.width,canvas.height);canvas.toBlob(blob=>{if(blob)emit('confirm',new File([blob],'cropped-question.png',{type:'image/png'}));else error.value='裁剪未完成，请换一张较小的图片重试。'},'image/png')}catch{error.value='无法读取图片，请重新选择本机图片。'}}
</script>
<style scoped>
.crop-stage{position:relative;width:fit-content;max-width:100%;margin:16px auto;overflow:hidden;touch-action:none;cursor:crosshair;line-height:0}.crop-stage img{display:block;max-width:100%;max-height:50vh;user-select:none}.crop-selection{position:absolute;border:2px solid var(--primary);box-shadow:0 0 0 2000px rgb(0 0 0 / .45);pointer-events:none}.crop-controls{display:grid;grid-template-columns:1fr 1fr;gap:8px 16px}.crop-controls label{display:flex;flex-direction:column;min-width:0;font-size:14px}.crop-controls input{width:100%;min-height:44px;accent-color:var(--primary)}
</style>
