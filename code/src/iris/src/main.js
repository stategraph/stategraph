import './app.css'
import { mount } from 'svelte'
import App from './App.svelte'

// Helper function to get distinct ID from URL
function getDistinctIdFromUrl() {
  if (typeof window !== 'undefined') {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('distinct_id') || urlParams.get('distinctId');
  }
  return null;
}

// Check for maintenance mode before any initialization
function checkMaintenanceMode() {
  // Check runtime config (injected by server)
  if (typeof window !== 'undefined' && window.terrateamConfig) {
    const config = window.terrateamConfig;
    if (config.maintenanceMode === true || config.maintenanceMode === 'true') {
      return true;
    }
  }
  
  return false;
}

// Exit early if in maintenance mode to prevent any API calls or initialization
const isMaintenanceMode = checkMaintenanceMode();
if (isMaintenanceMode) {
  // Start app immediately without Sentry or other initialization
  const app = mount(App, {
    target: document.getElementById('app'),
  });
} else {

// Conditionally import and initialize analytics (PostHog & Sentry)
async function initializeAnalytics() {
  // Check if analytics are enabled from runtime config
  const analyticsEnabled = window.terrateamConfig?.ui_analytics === 'enabled';
  
  if (analyticsEnabled) {
    // Initialize PostHog using the NPM package
    const posthog = await import('posthog-js');
    posthog.default.init('phc_2tp2xlYY8TujRhNizd6oga1tzVzRaLXJ1O30UnOgIOF', {
      api_host: 'https://eu.i.posthog.com',
      person_profiles: 'always',
      opt_in_site_apps: true,
      autocapture: true,
      capture_pageview: true,
      capture_pageleave: true,
      disable_session_recording: false,
      session_recording: {
        // Mask sensitive inputs but allow other form interactions
        maskAllInputs: false,
        maskInputOptions: {
          password: true,
          hidden: true,
          search: false,
          email: false,
          tel: false,
          text: false
        },
        // Block sensitive selectors
        blockSelector: '[data-sensitive]',
        // Mask text containing sensitive patterns
        maskTextSelector: '[data-mask], .password-field, .secret-field',
        maskAllText: false
      },
      // Don't mask all text, but be selective
      mask_all_text: false,
      mask_all_element_attributes: false,
      // Respect user privacy preferences
      respect_dnt: true,
      secure_cookie: true,
      cross_subdomain_cookie: true,
      capture_performance: true,
      bootstrap: {
        distinctID: getDistinctIdFromUrl() || undefined
      },
      // Disable console log capture to avoid logging sensitive debug info
      disable_external_dependency_loading: false
    });

    // Store PostHog reference globally for backward compatibility
    window.posthog = posthog.default;
    
    // Check for email parameter
    const urlParams = new URLSearchParams(window.location.search);
    const signupEmail = urlParams.get('email');
    if (signupEmail) {
      // Identify user with email from signup before OAuth
      posthog.default.identify(signupEmail, {
        signup_source: 'marketing_site',
        signup_timestamp: new Date().toISOString()
      });

      // Store email for later use after OAuth
      sessionStorage.setItem('signup_email', signupEmail);
    }

    const Sentry = await import("@sentry/svelte");
    
    Sentry.init({
      dsn: "https://d0d17714697761a74f6fe1a4123126d4@o4509570379677696.ingest.de.sentry.io/4509570441281616",
      // Basic PII but be selective
      sendDefaultPii: false,
      integrations: [
        Sentry.browserTracingIntegration(),
        Sentry.replayIntegration({
          // Mask sensitive inputs but keep useful debugging info
          maskAllText: false,
          blockAllMedia: false,
          maskAllInputs: true, // Mask form inputs by default
          // Custom masking function for selective hiding
          maskTextFn: (text) => {
            // Mask things that look like tokens, keys, passwords
            if (/(?:password|token|key|secret|auth)/i.test(text)) {
              return '[Filtered]';
            }
            return text;
          },
          // Only capture network activity for our API
          networkDetailAllowUrls: [/localhost/, /app\.terrateam\.io/],
          networkCaptureBodies: true,
          networkRequestHeaders: ['Content-Type', 'Authorization'],
          networkResponseHeaders: ['Content-Type']
        })
      ],
      // Tracing
      tracesSampleRate: 1.0,
      // Set 'tracePropagationTargets' to control for which URLs distributed tracing should be enabled
      tracePropagationTargets: ["localhost", /^https:\/\/app\.terrateam\.io\/api/],
      // Session Replay
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0,
      // Additional options for good debugging
      attachStacktrace: true,
      beforeSend(event) {
        // Filter out sensitive data from error contexts
        if (event.extra) {
          Object.keys(event.extra).forEach(key => {
            if (/(?:password|token|key|secret|auth|credential)/i.test(key)) {
              event.extra[key] = '[Filtered]';
            }
          });
        }
        
        // Filter sensitive data from breadcrumbs
        if (event.breadcrumbs) {
          event.breadcrumbs.forEach(breadcrumb => {
            if (breadcrumb.data) {
              Object.keys(breadcrumb.data).forEach(key => {
                if (/(?:password|token|key|secret|auth|credential)/i.test(key)) {
                  breadcrumb.data[key] = '[Filtered]';
                }
              });
            }
          });
        }
        
        return event;
      }
    });
    
    return Sentry;
  } else {
    // Create stub PostHog object when analytics are disabled
    window.posthog = {
      init: () => {},
      capture: () => {},
      identify: () => {},
      setPersonProperties: () => {},
      reset: () => {},
      get_distinct_id: () => 'stub-id',
      isFeatureEnabled: () => false,
      getFeatureFlag: () => undefined,
      onFeatureFlags: () => {},
      reloadFeatureFlags: () => {}
    };
    
    // Return a stub Sentry object for development
    return {
      setUser: () => {},
      setContext: () => {},
      setTag: () => {},
      addBreadcrumb: () => {},
      captureException: () => {},
      captureMessage: () => {},
      startTransaction: () => ({ finish: () => {} })
    };
  }
}

// Initialize analytics (PostHog & Sentry), then start the app
initializeAnalytics().then(async () => {
  // Also initialize the Sentry service reference
  const { initSentryReference } = await import('./lib/sentry.ts');
  await initSentryReference();
  const app = mount(App, {
    target: document.getElementById('app'),
  })

  return app;
}).catch(err => {
  console.error('Failed to initialize application:', err);
});

} // End of maintenance mode check
