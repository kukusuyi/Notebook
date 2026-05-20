<template>
    <div class="auth-shell">
        <div class="auth-backdrop"></div>

        <div class="auth-grid">
            <section class="auth-story">
                <div class="story-mark">∫</div>
                <h1>Math Notebook</h1>

                <div class="story-points">
                    <article class="paper-card point-card">
                        <strong>高效错题本</strong>
                        <span>全自动整理错题</span>
                    </article>
                    <article class="paper-card point-card">
                        <strong>标签整理</strong>
                        <span>全流程标签打理，精准提取同类错题</span>
                    </article>
                    <article class="paper-card point-card">
                        <strong>懒人必备</strong>
                        <span>没错我就是太懒了懒得抄错题</span>
                    </article>
                </div>
            </section>

            <section class="auth-card paper-card">
                <div class="auth-header">
                    <div>
                        <h2>
                            {{
                                activeTab === "login" ? "登录账号" : "注册账号"
                            }}
                        </h2>
                    </div>
                </div>

                <el-tabs v-model="activeTab" stretch>
                    <el-tab-pane label="登录" name="login">
                        <el-form label-position="top" @submit.prevent>
                            <el-form-item label="用户名">
                                <el-input
                                    v-model="loginForm.username"
                                    placeholder="请输入用户名"
                                />
                            </el-form-item>
                            <el-form-item label="密码">
                                <el-input
                                    v-model="loginForm.password"
                                    type="password"
                                    show-password
                                    placeholder="请输入密码"
                                    @keyup.enter="submitLogin"
                                />
                            </el-form-item>
                            <el-button
                                type="primary"
                                class="submit-btn"
                                :loading="submitting"
                                @click="submitLogin"
                            >
                                登录并进入系统
                            </el-button>
                        </el-form>
                    </el-tab-pane>

                    <el-tab-pane label="注册" name="register">
                        <el-form label-position="top" @submit.prevent>
                            <el-form-item label="用户名">
                                <el-input
                                    v-model="registerForm.username"
                                    placeholder="至少便于识别的用户名"
                                />
                            </el-form-item>
                            <el-form-item label="邮箱">
                                <el-input
                                    v-model="registerForm.email"
                                    placeholder="例如 name@example.com"
                                />
                            </el-form-item>
                            <el-form-item label="密码">
                                <el-input
                                    v-model="registerForm.password"
                                    type="password"
                                    show-password
                                    placeholder="至少 6 位"
                                    @keyup.enter="submitRegister"
                                />
                            </el-form-item>
                            <el-button
                                type="primary"
                                class="submit-btn"
                                :loading="submitting"
                                @click="submitRegister"
                            >
                                注册并直接登录
                            </el-button>
                        </el-form>
                    </el-tab-pane>
                </el-tabs>
            </section>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ElMessage } from "element-plus";
import { computed, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";

import { useAuthStore } from "@/stores/auth.store";
import { getErrorMessage } from "@/utils/error";

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const activeTab = ref<"login" | "register">("login");
const submitting = computed(() => authStore.loading);

const loginForm = reactive({
    username: "",
    password: "",
});

const registerForm = reactive({
    username: "",
    email: "",
    password: "",
});

function resolveNextPath() {
    const redirect = route.query.redirect;
    return typeof redirect === "string" && redirect.startsWith("/")
        ? redirect
        : "/dashboard";
}

async function submitLogin() {
    if (!loginForm.username.trim() || !loginForm.password) {
        ElMessage.warning("请输入用户名和密码");
        return;
    }

    try {
        await authStore.loginWithPassword(loginForm);
        ElMessage.success("登录成功");
        router.push(resolveNextPath());
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "登录失败"));
    }
}

async function submitRegister() {
    if (
        !registerForm.username.trim() ||
        !registerForm.email.trim() ||
        !registerForm.password
    ) {
        ElMessage.warning("请完整填写用户名、邮箱和密码");
        return;
    }

    if (registerForm.password.length < 6) {
        ElMessage.warning("密码长度不能少于 6 位");
        return;
    }

    try {
        await authStore.registerAccount(registerForm);
        ElMessage.success("注册成功，已自动登录");
        router.push(resolveNextPath());
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "注册失败"));
    }
}
</script>

<style scoped>
.auth-shell {
    position: relative;
    min-height: 100vh;
    overflow: hidden;
    background:
        radial-gradient(
            circle at top left,
            rgba(30, 77, 63, 0.18),
            transparent 28%
        ),
        radial-gradient(
            circle at bottom right,
            rgba(192, 103, 44, 0.16),
            transparent 34%
        ),
        linear-gradient(180deg, #f2ede2 0%, #ece4d7 100%);
}

.auth-backdrop {
    position: absolute;
    inset: 0;
    background:
        linear-gradient(90deg, rgba(31, 41, 55, 0.03) 1px, transparent 1px) 0
            0 / 26px 26px,
        linear-gradient(rgba(31, 41, 55, 0.02) 1px, transparent 1px) 0 0 / 26px
            26px;
    pointer-events: none;
}

.auth-grid {
    position: relative;
    z-index: 1;
    display: grid;
    grid-template-columns: minmax(0, 1fr) 460px;
    gap: 28px;
    min-height: 100vh;
    align-items: center;
    padding: 32px;
}

.auth-story {
    max-width: 720px;
}

.story-mark {
    display: grid;
    place-items: center;
    width: 72px;
    height: 72px;
    border-radius: 24px;
    background: linear-gradient(135deg, var(--primary), var(--accent));
    color: #fff;
    font-size: 40px;
    box-shadow: 0 18px 42px rgba(30, 77, 63, 0.24);
}

.auth-story h1 {
    margin: 18px 0 12px;
    font-size: 52px;
    line-height: 1;
    letter-spacing: -0.04em;
}

.auth-story p {
    margin: 0;
    max-width: 640px;
    color: var(--text-secondary);
    font-size: 18px;
    line-height: 1.8;
}

.story-points {
    display: grid;
    gap: 14px;
    margin-top: 28px;
}

.point-card {
    display: grid;
    gap: 8px;
    padding: 18px;
}

.point-card strong {
    font-size: 18px;
}

.point-card span {
    color: var(--text-secondary);
    line-height: 1.7;
}

.auth-card {
    padding: 24px;
}

.auth-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 10px;
}

.auth-header h2 {
    margin: 6px 0 0;
    font-size: 28px;
}

.submit-btn {
    width: 100%;
    margin-top: 8px;
}

@media (max-width: 980px) {
    .auth-grid {
        grid-template-columns: 1fr;
        align-items: start;
    }

    .auth-story h1 {
        font-size: 40px;
    }
}

@media (max-width: 640px) {
    .auth-grid {
        padding: 16px;
    }
}
</style>
