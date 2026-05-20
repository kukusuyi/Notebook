<template>
    <div class="layout-root">
        <aside class="sidebar paper-card">
            <div class="brand">
                <div class="brand-mark">∫</div>
                <div>
                    <h1>Math Notebook</h1>
                    <p>把错题整理成可检索、可复盘、可联想的知识资产。</p>
                </div>
            </div>

            <nav class="nav-list">
                <RouterLink
                    v-for="item in navItems"
                    :key="item.to"
                    :to="item.to"
                    class="nav-item"
                    :class="{ active: isNavActive(item.to) }"
                >
                    <el-icon><component :is="item.icon" /></el-icon>
                    <span>{{ item.label }}</span>
                </RouterLink>
            </nav>

            <div class="sidebar-footer paper-panel">
                <div class="meta-text">当前用户</div>
                <div class="sidebar-user">
                    {{
                        userStore.profile?.username ||
                        authStore.authUser?.username ||
                        "未登录"
                    }}
                </div>
                <div class="meta-text">
                    {{
                        userStore.profile?.email ||
                        "当前使用 JWT 鉴权，业务接口默认需要登录后访问。"
                    }}
                </div>
                <el-button class="logout-btn" text @click="handleLogout"
                    >退出登录</el-button
                >
            </div>
        </aside>

        <div class="layout-main">
            <main class="content-area">
                <RouterView />
            </main>
        </div>
    </div>
</template>

<script setup lang="ts">
import {
    Collection,
    Connection,
    DataBoard,
    EditPen,
    PictureRounded,
    Setting,
} from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import { onMounted } from "vue";
import { RouterLink, RouterView, useRoute } from "vue-router";

import { useAuthStore } from "@/stores/auth.store";
import { useUserStore } from "@/stores/user.store";

const route = useRoute();
const authStore = useAuthStore();
const userStore = useUserStore();

const navItems = [
    { label: "仪表盘", to: "/dashboard", icon: DataBoard },
    { label: "错题列表", to: "/questions", icon: Collection },
    { label: "手动新增", to: "/questions/create", icon: EditPen },
    { label: "图片上传", to: "/questions/upload", icon: PictureRounded },
    { label: "标签管理", to: "/tags", icon: Connection },
    { label: "设置", to: "/settings", icon: Setting },
];

function isNavActive(to: string) {
    if (to === "/questions") {
        return (
            route.path.startsWith("/questions") &&
            !["/questions/create", "/questions/upload"].includes(route.path)
        );
    }
    return route.path === to;
}

onMounted(async () => {
    if (authStore.isAuthenticated && !userStore.profile) {
        try {
            await userStore.fetchProfile();
        } catch {
            // token 失效时由请求层统一处理 401 跳转。
        }
    }
});

function handleLogout() {
    authStore.logout();
    userStore.clearProfile();
    ElMessage.success("已退出登录");
    window.location.href = "/auth";
}
</script>

<style scoped>
.layout-root {
    display: grid;
    grid-template-columns: 320px minmax(0, 1fr);
    min-height: 100vh;
    gap: 20px;
    padding: 20px;
}

.sidebar {
    position: sticky;
    top: 20px;
    display: flex;
    flex-direction: column;
    gap: 24px;
    height: calc(100vh - 40px);
    padding: 24px;
    overflow: hidden;
}

.brand {
    display: flex;
    gap: 14px;
}

.brand-mark {
    display: grid;
    place-items: center;
    width: 52px;
    height: 52px;
    border-radius: 18px;
    background: linear-gradient(
        135deg,
        rgba(30, 77, 63, 0.95),
        rgba(192, 103, 44, 0.9)
    );
    color: #fff;
    font-size: 28px;
    box-shadow: 0 14px 30px rgba(30, 77, 63, 0.22);
}

.brand h1 {
    margin: 0;
    font-size: 22px;
}

.brand p {
    margin: 6px 0 0;
    color: var(--text-secondary);
    font-size: 13px;
}

.nav-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.nav-item {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 48px;
    padding: 0 14px;
    border-radius: 16px;
    color: var(--text-secondary);
    border: 1px solid transparent;
    transition:
        transform 0.18s ease,
        background-color 0.18s ease,
        border-color 0.18s ease,
        color 0.18s ease;
}

.nav-item:hover,
.nav-item.active {
    color: var(--primary);
    background: rgba(30, 77, 63, 0.08);
    border-color: rgba(30, 77, 63, 0.14);
    transform: translateX(3px);
}

.sidebar-footer {
    margin-top: auto;
    padding: 16px;
}

.sidebar-user {
    margin: 6px 0;
    font-weight: 700;
}

.logout-btn {
    margin-top: 10px;
    padding-left: 0;
}

.layout-main {
    display: flex;
    flex-direction: column;
    gap: 20px;
    min-width: 0;
}

.topbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
    padding: 18px 22px;
}

.topbar-title {
    margin-top: 4px;
    font-size: 18px;
    font-weight: 700;
}

.topbar-actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
}

.content-area {
    min-width: 0;
}

@media (max-width: 1100px) {
    .layout-root {
        grid-template-columns: 1fr;
    }

    .sidebar {
        position: static;
        height: auto;
    }
}

@media (max-width: 720px) {
    .layout-root {
        padding: 12px;
        gap: 12px;
    }

    .sidebar,
    .topbar {
        padding: 16px;
    }
}
</style>
