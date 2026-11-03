import { writable, type Writable } from 'svelte/store';
import type { User, ServerConfig } from './types';
import { api } from './api';
import { analytics } from './analytics';
import { sentryService } from './sentry';

// URL preservation for post-login redirects
const REDIRECT_URL_KEY = 'auth_redirect_url';

export const user: Writable<User | null> = writable(null);
export const githubUser: Writable<{ avatar_url?: string; username: string } | null> = writable(null);
export const isAuthenticated: Writable<boolean> = writable(false);
export const isLoading: Writable<boolean> = writable(true);
export const authError: Writable<string | null> = writable(null);

// Always use relative URLs - nginx will handle proxying in development
const API_BASE = '';

// URL preservation utilities for post-login redirects
export function storeIntendedUrl(url?: string): void {
  try {
    let urlToStore = url || window.location.hash;
    
    // Include query parameters if present (for things like run search filters)
    if (!url && window.location.search) {
      urlToStore += window.location.search;
    }

    // Only store if it's not the login page, root, or auth callback
    // Check the base URL without query parameters
    const baseUrl = urlToStore.split('?')[0];
    if (urlToStore && 
        baseUrl !== '#/login' && 
        baseUrl !== '#/' && 
        baseUrl !== '' &&
        !baseUrl.startsWith('#/auth/callback')) {
      sessionStorage.setItem(REDIRECT_URL_KEY, urlToStore);
    } else {
      // Clear any existing stored URL if we're at login/root/callback
      sessionStorage.removeItem(REDIRECT_URL_KEY);
    }
  } catch (e) {
    console.warn('Could not store intended URL:', e);
  }
}

function getStoredIntendedUrl(): string | null {
  try {
    const storedUrl = sessionStorage.getItem(REDIRECT_URL_KEY);
    if (storedUrl) {
      return storedUrl;
    }
  } catch (e) {
    console.warn('Could not retrieve stored intended URL:', e);
  }
  return null;
}

function clearStoredIntendedUrl(): void {
  try {
    sessionStorage.removeItem(REDIRECT_URL_KEY);
  } catch (e) {
    console.warn('Could not clear stored intended URL:', e);
  }
}

export function redirectToIntendedUrl(): boolean {
  const intendedUrl = getStoredIntendedUrl();
  if (intendedUrl) {
    clearStoredIntendedUrl();
    window.location.hash = intendedUrl;
    return true;
  }
  return false;
}

export async function getServerConfig(): Promise<ServerConfig> {
  try {
    const response = await fetch(`${API_BASE}/api/v1/server/config`);
    
    if (!response.ok) {
      const text = await response.text();
      console.error(`Server config error response:`, text.substring(0, 500));
      throw new Error(`Failed to get server config: ${response.status} ${response.statusText}`);
    }
    
    const text = await response.text();
    
    // Try to parse as JSON regardless of content-type header
    try {
      const config = JSON.parse(text);
      
      // Validate using our schema
      const { validateServerConfig } = await import('./types');
      const validatedConfig = validateServerConfig(config);
      
      return validatedConfig;
    } catch (parseError) {
      console.error('Failed to parse/validate server config:', parseError);
      console.error('Raw response:', text.substring(0, 500));
      throw new Error('Server config response is not valid JSON or failed validation');
    }
  } catch (error) {
    console.error('Error fetching server config:', error);
    throw error;
  }
}

export async function getCurrentUser(): Promise<User | null> {
  isLoading.set(true);
  authError.set(null);
  
  try {
    const response = await fetch(`${API_BASE}/api/v1/whoami`, {
      credentials: 'include',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    });

    if (response.status === 403) {
      user.set(null);
      githubUser.set(null);
      isAuthenticated.set(false);
      return null;
    }
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('Auth error response:', errorText);
      throw new Error(`Authentication failed: ${response.status} ${response.statusText}`);
    }
    
    let userData: User;
    try {
      const text = await response.text();
      userData = JSON.parse(text) as User;
    } catch (parseError) {
      console.error('Failed to parse user data:', parseError);
      throw new Error('Invalid user data format');
    }
    
    user.set(userData);
    isAuthenticated.set(true);
    
    // Determine which VCS provider the user logged in with
    let provider: 'github' | 'gitlab' = 'github'; // default
    if (userData.vcs && userData.vcs.length > 0) {
      // User's vcs array contains the providers they've authenticated with
      if (userData.vcs.includes('gitlab')) {
        provider = 'gitlab';
      } else if (userData.vcs.includes('github')) {
        provider = 'github';
      }
    }
    
    // Update the current VCS provider
    const { setVCSProvider } = await import('./stores');
    setVCSProvider(provider);
    
    // Fetch VCS user information for display purposes
    let vcsUserData = null;
    try {
      vcsUserData = await api.getVCSUser(provider);
      githubUser.set(vcsUserData); // Still using githubUser store for compatibility
    } catch (vcsError) {
      console.warn('Failed to fetch VCS user info:', vcsError);
      // Don't fail authentication if VCS user info fails
      githubUser.set(null);
    }
    
    // Identify user in analytics with useful but not excessive data
    try {
      const analyticsProps: Record<string, unknown> = {
        user_id: userData.id,
        vcs: userData.vcs?.join(',') // Convert array to string for easier analysis
      };
      
      if (vcsUserData) {
        analyticsProps.vcs_username = vcsUserData.username;
        analyticsProps.vcs_provider = provider;
        // Don't store avatar URL as it's not needed for analytics
      }
      
      analytics.identify(userData.id.toString(), analyticsProps);
    } catch (analyticsError) {
      console.warn('Analytics identification failed:', analyticsError);
    }
    
    // Set user context in Sentry for debugging
    try {
      // Set user through our service (which handles Sentry being available or not)
      sentryService.setUser(userData);
      sentryService.addBreadcrumb('User authenticated', 'auth', 'info', {
        userId: userData.id,
        hasVcsData: !!vcsUserData,
        vcsCount: userData.vcs?.length || 0
      });
    } catch (sentryError) {
      console.warn('Sentry user context failed:', sentryError);
    }
    
    return userData;
    
  } catch (error) {
    console.error('Error getting current user:', error);
    authError.set(error instanceof Error ? error.message : 'Unknown authentication error');
    user.set(null);
    githubUser.set(null);
    isAuthenticated.set(false);
    
    // Log authentication error to Sentry
    if (error instanceof Error) {
      sentryService.captureError(error, {
        context: 'getCurrentUser',
        endpoint: '/api/v1/whoami'
      });
    }
    
    return null;
  } finally {
    isLoading.set(false);
  }
}

export async function logout(): Promise<void> {
  try {
    const response = await fetch(`${API_BASE}/api/v1/logout`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      console.warn('Logout request failed, but continuing with client-side logout');
    }
    
    // Clear client state regardless of server response
    user.set(null);
    githubUser.set(null);
    isAuthenticated.set(false);
    authError.set(null);
    
    // Reset analytics
    try {
      analytics.reset();
    } catch (analyticsError) {
      console.warn('Analytics reset failed:', analyticsError);
    }
    
    // Clear Sentry user context
    try {
      sentryService.setUser(null);
      sentryService.addBreadcrumb('User logged out', 'auth', 'info');
    } catch (sentryError) {
      console.warn('Sentry reset failed:', sentryError);
    }
    
    // Redirect to login
    window.location.hash = '#/login';
    
  } catch (error) {
    console.error('Error during logout:', error);
    // Still clear client state even if server request fails
    user.set(null);
    githubUser.set(null);
    isAuthenticated.set(false);
    
    // Reset analytics
    try {
      analytics.reset();
    } catch (analyticsError) {
      console.warn('Analytics reset failed:', analyticsError);
    }
    
    // Clear Sentry user context
    try {
      sentryService.setUser(null);
      sentryService.addBreadcrumb('User logged out', 'auth', 'info');
    } catch (sentryError) {
      console.warn('Sentry reset failed:', sentryError);
    }
    
    window.location.hash = '#/login';
  }
}

export function initializeGitHubLogin(web_base_url: string, clientId: string): void {
  
  // Don't overwrite existing stored URL if we're on the login page
  // (the intended URL was already stored when redirecting to login)
  const existingUrl = getStoredIntendedUrl();
  if (!existingUrl) {
    storeIntendedUrl();
  } else {
  }
  
  // Redirect directly to GitHub OAuth
  const githubOAuthUrl = `${web_base_url}/login/oauth/authorize?client_id=${clientId}`;
  window.location.href = githubOAuthUrl;
}

export async function handleAuthCallback(): Promise<void> {
  
  // The production Terrateam backend handles the OAuth flow and sets authentication cookies
  // We just need to check if the user is now authenticated
  
  // Check if user is authenticated after the OAuth callback
  const userData = await getCurrentUser();
  
  if (userData) {
    // First priority: Check for stored intended URL
    if (redirectToIntendedUrl()) {
      return;
    }
    
    // Fallback: Always redirect to root and let App.svelte handle routing logic
    // This prevents the flash by ensuring we only make one routing decision
    window.location.hash = '#/';
  } else {
    authError.set('GitHub authentication failed');
    // Redirect back to login
    window.location.hash = '#/login';
  }
}
