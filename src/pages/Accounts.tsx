import { useState } from 'react'
import { motion } from 'framer-motion'
import {
  Shield,
  LogIn,
  LogOut,
  RefreshCw,
  CheckCircle2,
  XCircle,
  Clock,
  Globe,
  Loader2
} from 'lucide-react'
import { usePlatformStore } from '../stores/platformStore'
import PlatformIcon from '../components/PlatformIcon'
import { PLATFORMS } from '../types/platforms'
import { PlatformId } from '../types'

export default function Accounts() {
  const { accounts, addAccount, removeAccount } = usePlatformStore()
  const [loggingIn, setLoggingIn] = useState<PlatformId | null>(null)

  const handleLogin = async (platformId: PlatformId) => {
    const platform = PLATFORMS.find((p) => p.id === platformId)
    if (!platform) return

    setLoggingIn(platformId)

    try {
      if (window.api) {
        const result = await window.api.platformLogin(platform.loginUrl, platformId)
        if (result.success) {
          addAccount({
            platformId,
            username: platformId,
            displayName: `${platform.name} User`,
            connectionStatus: 'connected',
            lastLogin: new Date().toISOString(),
            cookies: result.cookies as Array<{ name: string; value: string; domain: string }>
          })
        }
      } else {
        // Demo mode - simulate login
        await new Promise((r) => setTimeout(r, 1500))
        addAccount({
          platformId,
          username: `demo_${platformId}`,
          displayName: `Demo ${platform.name}`,
          connectionStatus: 'connected',
          lastLogin: new Date().toISOString()
        })
      }
    } finally {
      setLoggingIn(null)
    }
  }

  const handleLogout = (platformId: PlatformId) => {
    removeAccount(platformId)
  }

  const connectedCount = accounts.filter((a) => a.connectionStatus === 'connected').length

  return (
    <div className="flex-1 overflow-y-auto p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-4xl mx-auto space-y-6"
      >
        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Shield size={22} className="text-brand-red" />
            Connected Accounts
          </h1>
          <p className="text-sm text-surface-400 mt-1">
            Login to your social media accounts via embedded browser. Cookies are stored locally.
          </p>
        </div>

        {/* Status Bar */}
        <div className="glass-card p-4 flex items-center gap-4">
          <div className="flex items-center gap-2">
            <Globe size={16} className="text-surface-400" />
            <span className="text-sm text-surface-300">
              <span className="font-semibold text-white">{connectedCount}</span> of{' '}
              {PLATFORMS.length} platforms connected
            </span>
          </div>
          <div className="flex-1 h-1.5 bg-surface-800 rounded-full overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${(connectedCount / PLATFORMS.length) * 100}%` }}
              transition={{ duration: 0.5, ease: 'easeOut' }}
              className="h-full bg-gradient-to-r from-brand-red to-brand-red-light rounded-full"
            />
          </div>
        </div>

        {/* Platform Cards */}
        <div className="grid grid-cols-2 gap-4">
          {PLATFORMS.map((platform, index) => {
            const account = accounts.find((a) => a.platformId === platform.id)
            const isConnected = account?.connectionStatus === 'connected'
            const isLoggingIn = loggingIn === platform.id

            return (
              <motion.div
                key={platform.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.05 }}
                className={`glass-card p-5 transition-all duration-300 ${
                  isConnected ? 'border-l-2' : ''
                }`}
                style={isConnected ? { borderLeftColor: platform.color } : {}}
              >
                <div className="flex items-start gap-4">
                  {/* Platform Icon */}
                  <div
                    className="w-12 h-12 rounded-xl flex items-center justify-center shrink-0"
                    style={{ backgroundColor: `${platform.color}15` }}
                  >
                    <PlatformIcon platformId={platform.id} size={24} />
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <h3 className="text-sm font-semibold text-white">{platform.name}</h3>
                    {isConnected ? (
                      <div className="mt-1 space-y-1">
                        <p className="text-xs text-surface-400 flex items-center gap-1">
                          <CheckCircle2 size={10} className="text-emerald-400" />
                          {account.displayName || account.username}
                        </p>
                        {account.lastLogin && (
                          <p className="text-[10px] text-surface-500 flex items-center gap-1">
                            <Clock size={9} />
                            {new Date(account.lastLogin).toLocaleDateString()}
                          </p>
                        )}
                      </div>
                    ) : (
                      <p className="text-xs text-surface-500 mt-1 flex items-center gap-1">
                        <XCircle size={10} />
                        Not connected
                      </p>
                    )}

                    {/* Supported types */}
                    <div className="flex gap-1 mt-2 flex-wrap">
                      {platform.supportedTypes.map((type) => (
                        <span
                          key={type}
                          className="text-[9px] px-1.5 py-0.5 rounded bg-surface-800/60 text-surface-400 uppercase font-medium"
                        >
                          {type}
                        </span>
                      ))}
                    </div>
                  </div>

                  {/* Action Button */}
                  <div className="shrink-0">
                    {isConnected ? (
                      <div className="flex gap-1">
                        <button
                          onClick={() => handleLogin(platform.id)}
                          className="w-8 h-8 rounded-lg bg-surface-800/60 hover:bg-surface-700 flex items-center justify-center text-surface-400 hover:text-white transition-colors"
                          title="Refresh login"
                        >
                          <RefreshCw size={12} />
                        </button>
                        <button
                          onClick={() => handleLogout(platform.id)}
                          className="w-8 h-8 rounded-lg bg-red-500/10 hover:bg-red-500/20 flex items-center justify-center text-red-400 transition-colors"
                          title="Disconnect"
                        >
                          <LogOut size={12} />
                        </button>
                      </div>
                    ) : (
                      <button
                        onClick={() => handleLogin(platform.id)}
                        disabled={isLoggingIn}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-brand-red/10 hover:bg-brand-red/20 text-brand-red text-xs font-medium transition-colors disabled:opacity-50"
                      >
                        {isLoggingIn ? (
                          <Loader2 size={12} className="animate-spin" />
                        ) : (
                          <LogIn size={12} />
                        )}
                        {isLoggingIn ? 'Connecting...' : 'Connect'}
                      </button>
                    )}
                  </div>
                </div>
              </motion.div>
            )
          })}
        </div>

        {/* Security Notice */}
        <div className="glass-card p-4 border-l-2 border-amber-500/50">
          <div className="flex items-start gap-3">
            <Shield size={16} className="text-amber-400 shrink-0 mt-0.5" />
            <div>
              <p className="text-xs font-semibold text-amber-300">Security Notice</p>
              <p className="text-[11px] text-surface-400 mt-0.5 leading-relaxed">
                Login sessions are stored locally on your device only. PostX uses an embedded
                browser to authenticate — your credentials are never sent to any third-party
                server. You can disconnect any platform at any time.
              </p>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
