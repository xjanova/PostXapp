import { motion } from 'framer-motion'
import {
  TrendingUp,
  Send,
  CheckCircle2,
  AlertCircle,
  Zap,
  ArrowUpRight,
  Clock,
  BarChart3
} from 'lucide-react'
import { usePlatformStore } from '../stores/platformStore'
import { usePostStore } from '../stores/postStore'
import { useAppStore } from '../stores/appStore'
import PlatformIcon from '../components/PlatformIcon'
import { PLATFORMS } from '../types/platforms'

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.05 }
  }
}

const item = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0 }
}

export default function Dashboard() {
  const accounts = usePlatformStore((s) => s.accounts)
  const history = usePostStore((s) => s.history)
  const setPage = useAppStore((s) => s.setPage)

  const connectedCount = accounts.filter((a) => a.connectionStatus === 'connected').length
  const totalPosts = history.length
  const successPosts = history.filter((h) => h.status === 'success').length
  const failedPosts = history.filter((h) => h.status === 'error').length

  return (
    <div className="flex-1 overflow-y-auto p-6">
      <motion.div variants={container} initial="hidden" animate="show" className="space-y-6">
        {/* Header */}
        <motion.div variants={item} className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-white">Dashboard</h1>
            <p className="text-sm text-surface-400 mt-1">
              Overview of your posting activity
            </p>
          </div>
          <button onClick={() => setPage('compose')} className="btn-glow flex items-center gap-2">
            <Zap size={16} />
            New Post
          </button>
        </motion.div>

        {/* Stats Row */}
        <motion.div variants={item} className="grid grid-cols-4 gap-4">
          <div className="stat-card">
            <div className="flex items-center justify-between">
              <span className="stat-label">Platforms</span>
              <div className="w-8 h-8 rounded-lg bg-blue-500/10 flex items-center justify-center">
                <TrendingUp size={16} className="text-blue-400" />
              </div>
            </div>
            <span className="stat-value">{connectedCount}</span>
            <span className="stat-change text-surface-400">
              of {PLATFORMS.length} available
            </span>
          </div>

          <div className="stat-card">
            <div className="flex items-center justify-between">
              <span className="stat-label">Total Posts</span>
              <div className="w-8 h-8 rounded-lg bg-brand-red/10 flex items-center justify-center">
                <Send size={16} className="text-brand-red" />
              </div>
            </div>
            <span className="stat-value">{totalPosts}</span>
            <span className="stat-change text-surface-400">all time</span>
          </div>

          <div className="stat-card">
            <div className="flex items-center justify-between">
              <span className="stat-label">Successful</span>
              <div className="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                <CheckCircle2 size={16} className="text-emerald-400" />
              </div>
            </div>
            <span className="stat-value">{successPosts}</span>
            <span className="stat-change text-emerald-400">
              {totalPosts > 0 ? ((successPosts / totalPosts) * 100).toFixed(0) : 0}% rate
            </span>
          </div>

          <div className="stat-card">
            <div className="flex items-center justify-between">
              <span className="stat-label">Failed</span>
              <div className="w-8 h-8 rounded-lg bg-red-500/10 flex items-center justify-center">
                <AlertCircle size={16} className="text-red-400" />
              </div>
            </div>
            <span className="stat-value">{failedPosts}</span>
            <span className="stat-change text-red-400">
              {totalPosts > 0 ? ((failedPosts / totalPosts) * 100).toFixed(0) : 0}% rate
            </span>
          </div>
        </motion.div>

        <div className="grid grid-cols-3 gap-6">
          {/* Connected Platforms */}
          <motion.div variants={item} className="col-span-2 glass-card p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-semibold text-white flex items-center gap-2">
                <BarChart3 size={16} className="text-brand-red" />
                Platform Status
              </h2>
              <button
                onClick={() => setPage('accounts')}
                className="text-xs text-surface-400 hover:text-brand-red transition-colors flex items-center gap-1"
              >
                Manage <ArrowUpRight size={12} />
              </button>
            </div>

            <div className="grid grid-cols-2 gap-3">
              {PLATFORMS.map((platform) => {
                const account = accounts.find((a) => a.platformId === platform.id)
                const isConnected = account?.connectionStatus === 'connected'
                return (
                  <div
                    key={platform.id}
                    className={`flex items-center gap-3 p-3 rounded-lg border transition-all duration-200 ${
                      isConnected
                        ? 'bg-surface-800/40 border-surface-700/50'
                        : 'bg-surface-900/40 border-surface-800/30 opacity-50'
                    }`}
                  >
                    <PlatformIcon platformId={platform.id} size={20} />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-white truncate">{platform.name}</p>
                      <p className="text-[11px] text-surface-400 truncate">
                        {account ? account.displayName || account.username : 'Not connected'}
                      </p>
                    </div>
                    <div className={`status-dot ${isConnected ? 'connected' : 'disconnected'}`} />
                  </div>
                )
              })}
            </div>
          </motion.div>

          {/* Quick Actions & Recent */}
          <motion.div variants={item} className="space-y-4">
            {/* Quick Compose */}
            <div className="glass-card p-5">
              <h2 className="text-sm font-semibold text-white flex items-center gap-2 mb-3">
                <Zap size={16} className="text-amber-400" />
                Quick Post
              </h2>
              <p className="text-xs text-surface-400 mb-4">
                Create and publish to all connected platforms instantly.
              </p>
              <button
                onClick={() => setPage('compose')}
                className="w-full btn-glow text-sm py-2"
              >
                Start Composing
              </button>
            </div>

            {/* Recent Activity */}
            <div className="glass-card p-5">
              <h2 className="text-sm font-semibold text-white flex items-center gap-2 mb-3">
                <Clock size={16} className="text-surface-400" />
                Recent Activity
              </h2>
              {history.length === 0 ? (
                <div className="text-center py-6">
                  <div className="w-10 h-10 rounded-full bg-surface-800 flex items-center justify-center mx-auto mb-2">
                    <Send size={16} className="text-surface-500" />
                  </div>
                  <p className="text-xs text-surface-500">No posts yet</p>
                  <p className="text-[10px] text-surface-600">
                    Your posting history will appear here
                  </p>
                </div>
              ) : (
                <div className="space-y-2">
                  {history.slice(0, 5).map((h) => (
                    <div
                      key={h.id}
                      className="flex items-center gap-2 p-2 rounded-lg bg-surface-800/30"
                    >
                      <PlatformIcon platformId={h.platform} size={14} />
                      <span className="text-xs text-surface-300 flex-1 truncate">
                        {h.content.text.substring(0, 40)}...
                      </span>
                      {h.status === 'success' ? (
                        <CheckCircle2 size={12} className="text-emerald-400 shrink-0" />
                      ) : (
                        <AlertCircle size={12} className="text-red-400 shrink-0" />
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </motion.div>
        </div>
      </motion.div>
    </div>
  )
}
