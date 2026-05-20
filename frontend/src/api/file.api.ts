import { httpPost } from './http'

import type { UploadedImage } from '@/types/file'

export function uploadImage(file: File) {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('usage', 'wrong_question')

  return httpPost<UploadedImage>('/api/v1/files/images', formData)
}
