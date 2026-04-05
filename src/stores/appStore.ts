import { create } from 'zustand'
import { AppSettings } from '../types'

type Page = 'dashboard' | 'compose' | 'accounts' | 'history' | 'settings'

interface AppState {
  currentPage: Page
  setPage: (page: Page) => void
  sidebarCollapsed: boolean
  toggleSidebar: () => void
  settings: AppSettings
  updateSettings: (updates: Partial<AppSettings>) => void
  isPosting: boolean
  setIsPosting: (v: boolean) => void
}

const defaultSettings: AppSettings = {
  theme: 'dark',
  autoRetry: true,
  retryCount: 2,
  postDelay: 3000,
  defaultPlatforms: [],
  language: 'en'
}

export const useAppStore = create<AppState>((set) => ({
  currentPage: 'dashboard',
  setPage: (page) => set({ currentPage: page }),

  sidebarCollapsed: false,
  toggleSidebar: () => set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),

  settings: defaultSettings,
  updateSettings: (updates) =>
    set((state) => ({
      settings: { ...state.settings, ...updates }
    })),

  isPosting: false,
  setIsPosting: (v) => set({ isPosting: v })
}))
