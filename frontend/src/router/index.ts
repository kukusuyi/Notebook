import { createRouter, createWebHistory } from 'vue-router'

import { settingsPageEnabled } from '@/config/features'
import AuthPage from '@/pages/AuthPage.vue'
import MainLayout from '@/layouts/MainLayout.vue'
import DashboardPage from '@/pages/DashboardPage.vue'
import QuestionAiReviewPage from '@/pages/QuestionAiReviewPage.vue'
import QuestionCreatePage from '@/pages/QuestionCreatePage.vue'
import QuestionDetailPage from '@/pages/QuestionDetailPage.vue'
import QuestionEditPage from '@/pages/QuestionEditPage.vue'
import QuestionListPage from '@/pages/QuestionListPage.vue'
import QuestionUploadPage from '@/pages/QuestionUploadPage.vue'
import SettingsPage from '@/pages/SettingsPage.vue'
import SimilarQuestionPage from '@/pages/SimilarQuestionPage.vue'
import TagManagePage from '@/pages/TagManagePage.vue'

import { getAuthToken } from '@/utils/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/auth',
      name: 'auth',
      component: AuthPage,
      meta: { title: '登录 / 注册', public: true },
    },
    {
      path: '/',
      component: MainLayout,
      meta: { requiresAuth: true },
      redirect: '/dashboard',
      children: [
        {
          path: 'dashboard',
          name: 'dashboard',
          component: DashboardPage,
          meta: { title: '仪表盘' },
        },
        {
          path: 'questions',
          name: 'questions',
          component: QuestionListPage,
          meta: { title: '错题列表' },
        },
        {
          path: 'questions/create',
          name: 'question-create',
          component: QuestionCreatePage,
          meta: { title: '新增错题' },
        },
        {
          path: 'questions/upload',
          name: 'question-upload',
          component: QuestionUploadPage,
          meta: { title: '图片上传' },
        },
        {
          path: 'questions/ai-review',
          name: 'question-ai-review',
          component: QuestionAiReviewPage,
          meta: { title: 'AI 分析确认' },
        },
        {
          path: 'questions/:id',
          name: 'question-detail',
          component: QuestionDetailPage,
          meta: { title: '错题详情' },
        },
        {
          path: 'questions/:id/edit',
          name: 'question-edit',
          component: QuestionEditPage,
          meta: { title: '编辑错题' },
        },
        {
          path: 'questions/:id/similar',
          name: 'question-similar',
          component: SimilarQuestionPage,
          meta: { title: '相似题' },
        },
        {
          path: 'tags',
          name: 'tags',
          component: TagManagePage,
          meta: { title: '标签管理' },
        },
        {
          path: 'settings',
          name: 'settings',
          component: SettingsPage,
          meta: { title: '设置' },
        },
      ],
    },
  ],
})

router.beforeEach((to) => {
  const token = getAuthToken()
  const isPublic = Boolean(to.meta.public)

  if (!isPublic && !token) {
    return {
      path: '/auth',
      query: {
        redirect: to.fullPath,
      },
    }
  }

  if (to.path === '/auth' && token) {
    const redirect = typeof to.query.redirect === 'string' ? to.query.redirect : '/dashboard'
    return redirect
  }

  if (to.path === '/settings' && !settingsPageEnabled) {
    return '/dashboard'
  }

  return true
})

router.afterEach((to) => {
  document.title = `${to.meta.title ? `${String(to.meta.title)} · ` : ""}题迹 Notebook`;
});

export default router
