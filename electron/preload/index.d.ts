import { ElectronAPI } from '@electron-toolkit/preload'

interface PostXAPI {
  minimizeWindow: () => void
  maximizeWindow: () => void
  closeWindow: () => void
  isMaximized: () => Promise<boolean>
  storeGet: (key: string) => Promise<unknown>
  storeSet: (key: string, value: unknown) => Promise<void>
  storeDelete: (key: string) => Promise<void>
  getCookies: (filter: object) => Promise<unknown[]>
  setCookie: (cookie: object) => Promise<void>
  removeCookie: (url: string, name: string) => Promise<void>
  platformLogin: (
    url: string,
    platformId: string
  ) => Promise<{ success: boolean; cookies: object[] }>
  checkForUpdates: () => Promise<void>
  installUpdate: () => Promise<void>
  onUpdaterStatus: (callback: (data: UpdaterStatus) => void) => () => void
}

interface UpdaterStatus {
  status: 'checking' | 'available' | 'up-to-date' | 'downloading' | 'downloaded' | 'error'
  version?: string
  percent?: number
  message?: string
}

declare global {
  interface Window {
    electron: ElectronAPI
    api: PostXAPI
  }
}
