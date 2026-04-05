import { create } from 'zustand'
import { PlatformAccount, PlatformId, ConnectionStatus } from '../types'

interface PlatformState {
  accounts: PlatformAccount[]
  setAccounts: (accounts: PlatformAccount[]) => void
  addAccount: (account: PlatformAccount) => void
  updateAccount: (platformId: PlatformId, updates: Partial<PlatformAccount>) => void
  removeAccount: (platformId: PlatformId) => void
  getAccount: (platformId: PlatformId) => PlatformAccount | undefined
  getConnectedPlatforms: () => PlatformAccount[]
  updateConnectionStatus: (platformId: PlatformId, status: ConnectionStatus) => void
}

export const usePlatformStore = create<PlatformState>((set, get) => ({
  accounts: [],

  setAccounts: (accounts) => set({ accounts }),

  addAccount: (account) =>
    set((state) => ({
      accounts: [...state.accounts.filter((a) => a.platformId !== account.platformId), account]
    })),

  updateAccount: (platformId, updates) =>
    set((state) => ({
      accounts: state.accounts.map((a) =>
        a.platformId === platformId ? { ...a, ...updates } : a
      )
    })),

  removeAccount: (platformId) =>
    set((state) => ({
      accounts: state.accounts.filter((a) => a.platformId !== platformId)
    })),

  getAccount: (platformId) => get().accounts.find((a) => a.platformId === platformId),

  getConnectedPlatforms: () =>
    get().accounts.filter((a) => a.connectionStatus === 'connected'),

  updateConnectionStatus: (platformId, status) =>
    set((state) => ({
      accounts: state.accounts.map((a) =>
        a.platformId === platformId ? { ...a, connectionStatus: status } : a
      )
    }))
}))
