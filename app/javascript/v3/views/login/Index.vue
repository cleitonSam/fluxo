<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main class="relative flex items-center justify-center w-full min-h-screen overflow-hidden bg-[#020817] font-mono">

    <!-- Scanline overlay -->
    <div class="absolute inset-0 bg-[repeating-linear-gradient(0deg,transparent,transparent_2px,rgba(14,165,233,0.012)_2px,rgba(14,165,233,0.012)_4px)] pointer-events-none z-10" />

    <!-- Background glow orbs -->
    <div class="absolute top-0 left-1/2 -translate-x-1/2 w-[700px] h-[500px] bg-blue-600/15 rounded-full blur-3xl pointer-events-none" />
    <div class="absolute bottom-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none" />
    <div class="absolute top-1/2 right-0 w-72 h-72 bg-blue-400/10 rounded-full blur-3xl pointer-events-none" />

    <!-- Grid overlay -->
    <div class="absolute inset-0 bg-[linear-gradient(rgba(14,165,233,0.04)_1px,transparent_1px),linear-gradient(90deg,rgba(14,165,233,0.04)_1px,transparent_1px)] bg-[size:60px_60px] pointer-events-none" />

    <!-- HUD Top bar -->
    <div class="absolute top-0 left-0 right-0 flex items-center justify-between px-6 py-3 border-b border-cyan-500/10 z-20">
      <div class="flex items-center gap-2">
        <div class="w-2 h-2 rounded-full bg-cyan-400 shadow-[0_0_8px_rgba(34,211,238,0.9)]" />
        <span class="text-xs text-cyan-400/50 tracking-[0.2em] uppercase">Sistema Ativo</span>
      </div>
      <span class="text-xs text-cyan-400/30 tracking-widest">FDT-SYS // v2.0</span>
      <div class="flex items-center gap-2">
        <span class="text-xs text-cyan-400/50 tracking-[0.2em] uppercase">Conexão Segura</span>
        <div class="w-2 h-2 rounded-full bg-green-400 shadow-[0_0_8px_rgba(74,222,128,0.9)]" />
      </div>
    </div>

    <!-- Main content -->
    <div class="relative z-20 w-full max-w-md px-6 py-12">

      <!-- Logo + Title -->
      <div class="mb-8 text-center">
        <div class="relative inline-flex items-center justify-center mb-6">
          <div class="absolute w-20 h-20 rounded-full border border-cyan-500/20 animate-ping opacity-30" />
          <div class="absolute w-24 h-24 rounded-full border border-blue-500/15" />
          <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-blue-600/20 ring-1 ring-cyan-500/40 shadow-[0_0_30px_rgba(14,165,233,0.2)]">
            <img
              :src="globalConfig.logo"
              :alt="globalConfig.installationName"
              class="w-8 h-8 object-contain"
            />
          </div>
        </div>
        <h1 class="text-3xl font-bold tracking-widest text-white uppercase">
          {{ globalConfig.installationName }}
        </h1>
        <p class="mt-2 text-xs tracking-[0.4em] uppercase text-cyan-400/60">
          ── acesso ao sistema ──
        </p>
        <p v-if="showSignupLink" class="mt-3 text-xs text-cyan-400/40 tracking-wider">
          <router-link to="auth/signup" class="text-cyan-400/70 hover:text-cyan-300 transition-colors">
            {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
          </router-link>
        </p>
      </div>

      <!-- MFA -->
      <div v-if="mfaRequired">
        <MfaVerification
          :mfa-token="mfaToken"
          @verified="handleMfaVerified"
          @cancel="handleMfaCancel"
        />
      </div>

      <!-- Login card with HUD corners -->
      <div v-else class="relative" :class="{ 'animate-wiggle': loginApi.hasErrored }">
        <!-- Corner brackets -->
        <div class="absolute -top-1.5 -left-1.5 w-6 h-6 border-t-2 border-l-2 border-cyan-400/70" />
        <div class="absolute -top-1.5 -right-1.5 w-6 h-6 border-t-2 border-r-2 border-cyan-400/70" />
        <div class="absolute -bottom-1.5 -left-1.5 w-6 h-6 border-b-2 border-l-2 border-cyan-400/70" />
        <div class="absolute -bottom-1.5 -right-1.5 w-6 h-6 border-b-2 border-r-2 border-cyan-400/70" />

        <!-- Status bar -->
        <div class="flex items-center gap-2 px-4 py-2 bg-cyan-500/5 border border-b-0 border-cyan-500/15 rounded-t-lg">
          <div class="w-1.5 h-1.5 rounded-full bg-green-400 shadow-[0_0_6px_rgba(74,222,128,0.9)]" />
          <span class="text-xs tracking-[0.2em] uppercase text-cyan-400/50">Autenticação Segura</span>
          <div class="flex-1" />
          <span class="text-xs text-cyan-400/25 tracking-widest">[ CRIPTOGRAFADO ]</span>
        </div>

        <!-- Form body -->
        <div class="border border-t-0 border-cyan-500/15 bg-[#020817]/90 backdrop-blur-xl p-8 rounded-b-lg shadow-2xl shadow-cyan-500/5">
          <div v-if="!email">
            <div class="flex flex-col gap-4 mb-5">
              <GoogleOAuthButton v-if="showGoogleOAuth" />
              <div v-if="showSamlLogin" class="text-center">
                <router-link
                  to="/app/login/sso"
                  class="inline-flex justify-center w-full px-4 py-3 items-center rounded-lg bg-cyan-500/5 border border-cyan-500/20 hover:border-cyan-500/40 hover:bg-cyan-500/10 transition-all duration-200 focus:outline-none"
                >
                  <Icon icon="i-lucide-lock-keyhole" class="size-5 text-cyan-400" />
                  <span class="ml-2 text-sm font-mono tracking-widest text-cyan-300">
                    {{ $t('LOGIN.SAML.LABEL') }}
                  </span>
                </router-link>
              </div>
              <SimpleDivider
                v-if="showGoogleOAuth || showSamlLogin"
                :label="$t('COMMON.OR')"
                class="uppercase text-cyan-400/30"
              />
            </div>

            <form class="space-y-5" @submit.prevent="submitFormLogin">
              <FormInput
                v-model="credentials.email"
                name="email_address"
                type="text"
                data-testid="email_input"
                :tabindex="1"
                required
                :label="$t('LOGIN.EMAIL.LABEL')"
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                :has-error="v$.credentials.email.$error"
                @input="v$.credentials.email.$touch"
              />
              <FormInput
                v-model="credentials.password"
                type="password"
                name="password"
                data-testid="password_input"
                required
                :tabindex="2"
                :label="$t('LOGIN.PASSWORD.LABEL')"
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                :has-error="v$.credentials.password.$error"
                @input="v$.credentials.password.$touch"
              >
                <p v-if="!globalConfig.disableUserProfileUpdate">
                  <router-link
                    to="auth/reset/password"
                    class="text-xs font-mono tracking-wider text-cyan-400/60 hover:text-cyan-300 transition-colors"
                    tabindex="4"
                  >
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </p>
              </FormInput>

              <button
                type="submit"
                data-testid="submit_button"
                :tabindex="3"
                :disabled="loginApi.showLoading"
                class="relative w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-mono font-bold tracking-[0.2em] uppercase text-sm text-white bg-gradient-to-r from-blue-600 to-cyan-500 hover:from-blue-500 hover:to-cyan-400 shadow-lg shadow-blue-500/30 hover:shadow-cyan-500/40 transition-all duration-200 disabled:opacity-60 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-cyan-500/40"
              >
                <Spinner v-if="loginApi.showLoading" color-scheme="primary" size="" />
                <span>{{ $t('LOGIN.SUBMIT') }}</span>
                <Icon v-if="!loginApi.showLoading" icon="i-lucide-arrow-right" class="size-4" />
              </button>
            </form>
          </div>

          <div v-else class="flex items-center justify-center py-6">
            <Spinner color-scheme="primary" size="" />
          </div>
        </div>
      </div>

      <!-- Bottom status line -->
      <div class="mt-8 flex items-center gap-3">
        <div class="h-px flex-1 bg-gradient-to-r from-transparent to-cyan-500/20" />
        <span class="text-xs font-mono tracking-[0.3em] text-cyan-400/25 uppercase">Sistema Seguro</span>
        <div class="h-px flex-1 bg-gradient-to-l from-transparent to-cyan-500/20" />
      </div>

      <p class="mt-3 text-xs text-center font-mono tracking-widest text-cyan-400/15">
        © {{ new Date().getFullYear() }} {{ globalConfig.installationName }}
      </p>
    </div>

    <!-- HUD Bottom bar -->
    <div class="absolute bottom-0 left-0 right-0 flex items-center justify-between px-6 py-2 border-t border-cyan-500/10 z-20">
      <span class="text-xs font-mono text-cyan-400/20 tracking-[0.2em] uppercase">Fluxo Digital Tech</span>
      <span class="text-xs font-mono text-cyan-400/20 tracking-[0.2em] uppercase">Acesso Autorizado</span>
    </div>
  </main>
</template>
