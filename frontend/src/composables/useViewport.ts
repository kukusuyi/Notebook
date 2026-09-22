import { ref, onMounted, onUnmounted } from 'vue'
export function useViewport(query='(max-width: 767px)') {
 const media=matchMedia(query),matches=ref(media.matches)
 const update=()=>matches.value=media.matches
 onMounted(()=>media.addEventListener('change',update));onUnmounted(()=>media.removeEventListener('change',update))
 return matches
}
