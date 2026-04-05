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
    ipcRenderer.invoke('platform:login', url, platformId)
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
