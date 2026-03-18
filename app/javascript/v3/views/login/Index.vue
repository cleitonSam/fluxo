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
  <main
    class="relative isolate flex min-h-screen w-full items-center justify-center overflow-hidden bg-gradient-to-br from-slate-950 via-blue-950 to-slate-950 px-4 py-10 sm:px-6 lg:px-8"
  >
    <div
      class="pointer-events-none absolute inset-x-0 top-0 -z-10 flex justify-center"
    >
      <div class="h-96 w-96 rounded-full bg-cyan-400/25 blur-3xl" />
    </div>
    <div
      class="pointer-events-none absolute left-0 top-1/4 -z-10 h-96 w-96 rounded-full bg-blue-500/30 blur-3xl"
    />
    <div
      class="pointer-events-none absolute bottom-0 right-0 -z-10 h-[28rem] w-[28rem] rounded-full bg-sky-400/20 blur-3xl"
    />

    <!-- MFA Verification Section -->
    <section
      v-if="mfaRequired"
      class="w-full max-w-lg rounded-[28px] border border-cyan-400/20 bg-slate-900/90 p-8 shadow-2xl shadow-cyan-500/20 backdrop-blur-xl sm:p-10"
    >
      <MfaVerification
        :mfa-token="mfaToken"
        @verified="handleMfaVerified"
        @cancel="handleMfaCancel"
      />
    </section>

    <!-- Regular Login Section -->
    <section
      v-else
      class="grid w-full max-w-6xl gap-6 rounded-[32px] border border-white/10 bg-slate-950/55 p-4 shadow-2xl shadow-blue-950/50 backdrop-blur-xl lg:grid-cols-[1.05fr,0.95fr] lg:p-6"
      :class="{
        'animate-wiggle': loginApi.hasErrored,
      }"
    >
      <div
        class="hidden rounded-[28px] border border-cyan-400/10 bg-gradient-to-br from-cyan-400/10 via-blue-500/10 to-slate-950 p-10 lg:flex lg:flex-col lg:justify-between"
      >
        <div>
          <div
            class="mb-8 flex h-20 w-20 items-center justify-center rounded-3xl border border-cyan-400/20 bg-slate-950/80 shadow-lg shadow-cyan-500/20"
          >
            <img
              :src="globalConfig.logo"
              :alt="globalConfig.installationName"
              class="block h-10 w-auto dark:hidden"
            />
            <img
              v-if="globalConfig.logoDark"
              :src="globalConfig.logoDark"
              :alt="globalConfig.installationName"
              class="hidden h-10 w-auto dark:block"
            />
          </div>
          <p class="text-sm uppercase tracking-[0.3em] text-cyan-300">
            {{ globalConfig.installationName }}
          </p>
          <h2 class="mt-4 text-4xl font-semibold leading-tight text-white">
            {{ replaceInstallationName($t('LOGIN.TITLE')) }}
          </h2>
        </div>
        <p v-if="showSignupLink" class="text-sm text-slate-300">
          {{ $t('COMMON.OR') }}
          <router-link
            to="auth/signup"
            class="text-link lowercase text-cyan-300 hover:text-cyan-200"
          >
            {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
          </router-link>
        </p>
      </div>

      <div
        v-if="!email"
        class="rounded-[28px] border border-cyan-400/20 bg-slate-900/90 p-8 shadow-2xl shadow-cyan-500/20 sm:p-11"
      >
        <div class="mb-8 flex flex-col items-center text-center lg:hidden">
          <div
            class="mb-5 flex h-20 w-20 items-center justify-center rounded-3xl border border-cyan-400/20 bg-slate-950/80 shadow-lg shadow-cyan-500/20"
          >
            <img
              :src="globalConfig.logo"
              :alt="globalConfig.installationName"
              class="block h-10 w-auto dark:hidden"
            />
            <img
              v-if="globalConfig.logoDark"
              :src="globalConfig.logoDark"
              :alt="globalConfig.installationName"
              class="hidden h-10 w-auto dark:block"
            />
          </div>
          <h2 class="text-3xl font-semibold text-white">
            {{ replaceInstallationName($t('LOGIN.TITLE')) }}
          </h2>
          <p
            v-if="showSignupLink"
            class="mt-3 text-center text-sm text-slate-300"
          >
            {{ $t('COMMON.OR') }}
            <router-link
              to="auth/signup"
              class="text-link lowercase text-cyan-300 hover:text-cyan-200"
            >
              {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
            </router-link>
          </p>
        </div>

        <div class="flex flex-col gap-4">
          <GoogleOAuthButton v-if="showGoogleOAuth" />
          <div v-if="showSamlLogin" class="text-center">
            <router-link
              to="/app/login/sso"
              class="inline-flex w-full items-center justify-center rounded-xl border border-cyan-400/20 bg-slate-950/70 px-4 py-3 shadow-lg shadow-cyan-500/5 ring-1 ring-inset ring-cyan-300/10 transition hover:border-cyan-300/40 hover:bg-slate-900 focus:outline-offset-0"
            >
              <Icon icon="i-lucide-lock-keyhole" class="size-5 text-cyan-300" />
              <span class="ml-2 text-base font-medium text-slate-100">
                {{ $t('LOGIN.SAML.LABEL') }}
              </span>
            </router-link>
          </div>
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
                class="text-link text-sm text-cyan-300 hover:text-cyan-200"
                tabindex="4"
              >
                {{ $t('LOGIN.FORGOT_PASSWORD') }}
              </router-link>
            </p>
          </FormInput>
          <NextButton
            lg
            type="submit"
            data-testid="submit_button"
            class="w-full shadow-lg shadow-cyan-500/20 ring-1 ring-cyan-300/20"
            :tabindex="3"
            :label="$t('LOGIN.SUBMIT')"
            :disabled="loginApi.showLoading"
            :is-loading="loginApi.showLoading"
          />
        </form>
      </div>
      <div
        v-else
        class="rounded-[28px] border border-cyan-400/20 bg-slate-900/90 p-8 shadow-2xl shadow-cyan-500/20 sm:p-11"
      >
        <Spinner color-scheme="primary" size="" />
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
