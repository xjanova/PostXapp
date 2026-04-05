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
}

declare global {
  interface Window {
    electron: ElectronAPI
    api: PostXAPI
  }
}
