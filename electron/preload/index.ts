import { contextBridge, ipcRenderer } from 'electron'
import { electronAPI } from '@electron-toolkit/preload'

const api = {
  // Window controls
  minimizeWindow: (): void => ipcRenderer.send('window:minimize'),
  maximizeWindow: (): void => ipcRenderer.send('window:maximize'),
  closeWindow: (): void => ipcRenderer.send('window:close'),
  isMaximized: (): Promise<boolean> => ipcRenderer.invoke('window:isMaximized'),

  // Persistent store
  storeGet: (key: string): Promise<unknown> => ipcRenderer.invoke('store:get', key),
  storeSet: (key: string, value: unknown): Promise<void> =>
    ipcRenderer.invoke('store:set', key, value),
  storeDelete: (key: string): Promise<void> => ipcRenderer.invoke('store:delete', key),

  // Cookie management
  getCookies: (filter: object): Promise<unknown[]> => ipcRenderer.invoke('cookies:get', filter),
  setCookie: (cookie: object): Promise<void> => ipcRenderer.invoke('cookies:set', cookie),
  removeCookie: (url: string, name: string): Promise<void> =>
    ipcRenderer.invoke('cookies:remove', url, name),

  // Platform login
  platformLogin: (
    url: string,
    platformId: string
  ): Promise<{ success: boolean; cookies: object[] }> =>
    ipcRenderer.invoke('platform:login', url, platformId),

  // Post automation
  executePost: (
    platformIds: string[],
    payload: { text: string; imagePaths: string[]; videoPath?: string },
    delayMs: number
  ): Promise<Record<string, { success: boolean; postUrl?: string; error?: string }>> =>
    ipcRenderer.invoke('post:execute', platformIds, payload, delayMs),

  onPostStatus: (
    callback: (data: { platformId: string; status: string; progress: number }) => void
  ): (() => void) => {
    const handler = (_event: unknown, data: { platformId: string; status: string; progress: number }): void =>
      callback(data)
    ipcRenderer.on('post:status', handler)
    return () => ipcRenderer.removeListener('post:status', handler)
  },

  onPostResult: (
    callback: (data: { platformId: string; result: { success: boolean; postUrl?: string; error?: string } }) => void
  ): (() => void) => {
    const handler = (
      _event: unknown,
      data: { platformId: string; result: { success: boolean; postUrl?: string; error?: string } }
    ): void => callback(data)
    ipcRenderer.on('post:result', handler)
    return () => ipcRenderer.removeListener('post:result', handler)
  },

  // Auto updater
  checkForUpdates: (): Promise<void> => ipcRenderer.invoke('updater:check'),
  installUpdate: (): Promise<void> => ipcRenderer.invoke('updater:install'),
  onUpdaterStatus: (callback: (data: unknown) => void): (() => void) => {
    const handler = (_event: unknown, data: unknown): void => callback(data)
    ipcRenderer.on('updater:status', handler)
    return () => ipcRenderer.removeListener('updater:status', handler)
  }
}

if (process.contextIsolated) {
  try {
    contextBridge.exposeInMainWorld('electron', electronAPI)
    contextBridge.exposeInMainWorld('api', api)
  } catch (error) {
    console.error(error)
  }
} else {
  // @ts-ignore
  window.electron = electronAPI
  // @ts-ignore
  window.api = api
}
