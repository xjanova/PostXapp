import { motion } from 'framer-motion'
import {
  History as HistoryIcon,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
  Trash2,
  Search
} from 'lucide-react'
import { useState } from 'react'
import { usePostStore } from '../stores/postStore'
import PlatformIcon from '../components/PlatformIcon'
import { PlatformId } from '../types'

export default function History() {
  const { history, clearHistory } = usePostStore()
  const [filter, setFilter] = useState<'all' | 'success' | 'error'>('all')
  const [search, setSearch] = useState('')
  const [platformFilter, setPlatformFilter] = useState<PlatformId | 'all'>('all')

  const filtered = history.filter((h) => {
    if (filter !== 'all' && h.status !== filter) return false
    if (platformFilter !== 'all' && h.platform !== platformFilter) return false
    if (search && !h.content.text.toLowerCase().includes(search.toLowerCase())) return false
    return true
  })

  const platforms = [...new Set(history.map((h) => h.platform))]

  return (
    <div className="flex-1 overflow-y-auto p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-4xl mx-auto space-y-6"
      >
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <HistoryIcon size={22} className="text-brand-red" />
              Post History
            </h1>
            <p className="text-sm text-surface-400 mt-1">
              Track all your published posts across platforms
            </p>
          </div>
          {history.length > 0 && (
            <button
              onClick={clearHistory}
              className="btn-secondary flex items-center gap-1.5 text-xs text-red-400 hover:text-red-300"
            >
              <Trash2 size={12} />
              Clear All
            </button>
          )}
        </div>

        {/* Filters */}
        <div className="glass-card p-4 flex items-center gap-3">
          <div className="relative flex-1">
            <Search
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-surface-500"
            />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search posts..."
              className="input-field pl-9 py-2 text-sm"
            />
          </div>

          <div className="flex items-center gap-1 bg-surface-800/60 rounded-lg p-0.5">
            {(['all', 'success', 'error'] as const).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                  filter === f
                    ? 'bg-surface-700 text-white'
                    : 'text-surface-400 hover:text-surface-200'
                }`}
              >
                {f === 'all' ? 'All' : f === 'success' ? 'Success' : 'Failed'}
              </button>
            ))}
          </div>

          {platforms.length > 1 && (
            <select
              value={platformFilter}
              onChange={(e) => setPlatformFilter(e.target.value as PlatformId | 'all')}
              className="input-field py-2 text-sm w-40"
            >
              <option value="all">All Platforms</option>
              {platforms.map((p) => (
                <option key={p} value={p}>
                  {p.charAt(0).toUpperCase() + p.slice(1)}
                </option>
              ))}
            </select>
          )}
        </div>

        {/* History List */}
        {filtered.length === 0 ? (
          <div className="glass-card p-12 text-center">
            <div className="w-16 h-16 rounded-full bg-surface-800 flex items-center justify-center mx-auto mb-4">
              <HistoryIcon size={24} className="text-surface-500" />
            </div>
            <h3 className="text-lg font-semibold text-surface-300">No posts yet</h3>
            <p className="text-sm text-surface-500 mt-1">
              {history.length === 0
                ? 'Start posting to see your history here'
                : 'No posts match your filters'}
            </p>
          </div>
        ) : (
          <div className="space-y-2">
            {filtered.map((entry, index) => (
              <motion.div
                key={entry.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.03 }}
                className="glass-card p-4 flex items-start gap-4 hover:bg-surface-800/70 transition-colors"
              >
                <PlatformIcon platformId={entry.platform} size={20} />

                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white leading-relaxed">
                    {entry.content.text.length > 120
                      ? entry.content.text.substring(0, 120) + '...'
                      : entry.content.text}
                  </p>
                  <div className="flex items-center gap-3 mt-2">
                    <span className="text-[10px] text-surface-500">
                      {new Date(entry.postedAt).toLocaleString()}
                    </span>
                    {entry.content.images.length > 0 && (
                      <span className="text-[10px] text-surface-500">
                        {entry.content.images.length} image(s)
                      </span>
                    )}
                  </div>
                  {entry.error && (
                    <p className="text-xs text-red-400 mt-1">{entry.error}</p>
                  )}
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {entry.status === 'success' ? (
                    <CheckCircle2 size={16} className="text-emerald-400" />
                  ) : (
                    <AlertCircle size={16} className="text-red-400" />
                  )}
                  {entry.postUrl && (
                    <a
                      href={entry.postUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="w-7 h-7 rounded-lg bg-surface-800/60 flex items-center justify-center text-surface-400 hover:text-white transition-colors"
                    >
                      <ExternalLink size={12} />
                    </a>
                  )}
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </motion.div>
    </div>
  )
}
