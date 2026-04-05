import { motion } from 'framer-motion'
import { Settings2, Globe, Timer, RefreshCw, Info } from 'lucide-react'
import { useAppStore } from '../stores/appStore'

export default function Settings() {
  const { settings, updateSettings } = useAppStore()

  return (
    <div className="flex-1 overflow-y-auto p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-3xl mx-auto space-y-6"
      >
        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Settings2 size={22} className="text-brand-red" />
            Settings
          </h1>
          <p className="text-sm text-surface-400 mt-1">Configure your PostX experience</p>
        </div>

        {/* General */}
        <div className="glass-card p-5 space-y-5">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <Globe size={16} className="text-surface-400" />
            General
          </h2>

          {/* Language */}
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-surface-200">Language</p>
              <p className="text-xs text-surface-500">Display language for the app</p>
            </div>
            <select
              value={settings.language}
              onChange={(e) => updateSettings({ language: e.target.value as 'en' | 'th' })}
              className="input-field w-40 py-2 text-sm"
            >
              <option value="en">English</option>
              <option value="th">ไทย</option>
            </select>
          </div>
        </div>

        {/* Posting */}
        <div className="glass-card p-5 space-y-5">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <Timer size={16} className="text-surface-400" />
            Posting Behavior
          </h2>

          {/* Post delay */}
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-surface-200">Delay Between Posts</p>
              <p className="text-xs text-surface-500">
                Wait time between posting to each platform (ms)
              </p>
            </div>
            <input
              type="number"
              value={settings.postDelay}
              onChange={(e) => updateSettings({ postDelay: parseInt(e.target.value) || 0 })}
              className="input-field w-28 py-2 text-sm text-center"
              min={0}
              max={30000}
              step={500}
            />
          </div>

          {/* Auto retry */}
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-surface-200">Auto Retry</p>
              <p className="text-xs text-surface-500">
                Automatically retry failed posts
              </p>
            </div>
            <button
              onClick={() => updateSettings({ autoRetry: !settings.autoRetry })}
              className={`w-11 h-6 rounded-full relative transition-colors duration-200 ${
                settings.autoRetry ? 'bg-brand-red' : 'bg-surface-700'
              }`}
            >
              <motion.div
                animate={{ x: settings.autoRetry ? 20 : 2 }}
                transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                className="w-5 h-5 rounded-full bg-white absolute top-0.5"
              />
            </button>
          </div>

          {/* Retry count */}
          {settings.autoRetry && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="flex items-center justify-between pl-4 border-l-2 border-surface-700"
            >
              <div>
                <p className="text-sm text-surface-200">Retry Attempts</p>
                <p className="text-xs text-surface-500">
                  Maximum number of retry attempts
                </p>
              </div>
              <input
                type="number"
                value={settings.retryCount}
                onChange={(e) => updateSettings({ retryCount: parseInt(e.target.value) || 1 })}
                className="input-field w-20 py-2 text-sm text-center"
                min={1}
                max={5}
              />
            </motion.div>
          )}
        </div>

        {/* About */}
        <div className="glass-card p-5 space-y-4">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <Info size={16} className="text-surface-400" />
            About
          </h2>
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-sm text-surface-400">App Name</span>
              <span className="text-sm text-white font-medium">PostX App</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-surface-400">Version</span>
              <span className="text-sm text-white font-mono">1.0.0</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-surface-400">Developer</span>
              <span className="text-sm text-white">xman studio</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-surface-400">Runtime</span>
              <span className="text-sm text-white font-mono">Electron + React</span>
            </div>
          </div>
        </div>

        {/* Reset */}
        <div className="glass-card p-5 border-l-2 border-red-500/30">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-surface-200 flex items-center gap-2">
                <RefreshCw size={14} className="text-red-400" />
                Reset All Settings
              </p>
              <p className="text-xs text-surface-500">
                Restore all settings to their default values
              </p>
            </div>
            <button className="btn-secondary text-xs text-red-400 border-red-500/20 hover:bg-red-500/10">
              Reset
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
