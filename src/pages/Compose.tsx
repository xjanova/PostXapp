import { useState, useRef } from 'react'
import { motion } from 'framer-motion'
import {
  ImagePlus,
  Video,
  Send,
  X,
  Loader2,
  CheckCircle2,
  AlertTriangle,
  Sparkles,
  Eye,
  Type
} from 'lucide-react'
import { usePostStore } from '../stores/postStore'
import { usePlatformStore } from '../stores/platformStore'
import PlatformIcon from '../components/PlatformIcon'
import { PLATFORMS } from '../types/platforms'
import { PlatformId } from '../types'

export default function Compose() {
  const {
    currentPost,
    updateCurrentPost,
    selectedPlatforms,
    togglePlatform,
    resetCurrentPost
  } = usePostStore()
  const accounts = usePlatformStore((s) => s.accounts)
  const [isPosting, setIsPosting] = useState(false)
  const [postResults, setPostResults] = useState<Record<string, 'success' | 'error' | 'posting'>>({})
  const [showPreview, setShowPreview] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const connectedAccounts = accounts.filter((a) => a.connectionStatus === 'connected')

  const handleSelectAll = () => {
    const connectedIds = connectedAccounts.map((a) => a.platformId)
    const allSelected = connectedIds.every((id) => selectedPlatforms.includes(id))
    if (allSelected) {
      connectedIds.forEach((id) => {
        if (selectedPlatforms.includes(id)) togglePlatform(id)
      })
    } else {
      connectedIds.forEach((id) => {
        if (!selectedPlatforms.includes(id)) togglePlatform(id)
      })
    }
  }

  const handleImageAdd = () => {
    fileInputRef.current?.click()
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (files) {
      const paths = Array.from(files).map((f) => URL.createObjectURL(f))
      updateCurrentPost({ images: [...currentPost.images, ...paths] })
    }
  }

  const handleRemoveImage = (index: number) => {
    updateCurrentPost({
      images: currentPost.images.filter((_, i) => i !== index)
    })
  }

  const handlePost = async () => {
    if (selectedPlatforms.length === 0 || !currentPost.text.trim()) return
    setIsPosting(true)

    // Simulate posting to each platform
    for (const platformId of selectedPlatforms) {
      setPostResults((prev) => ({ ...prev, [platformId]: 'posting' }))
      await new Promise((r) => setTimeout(r, 1500))
      // In real implementation, this would use browser automation
      setPostResults((prev) => ({ ...prev, [platformId]: 'success' }))
    }

    setIsPosting(false)
  }

  const handleReset = () => {
    resetCurrentPost()
    setPostResults({})
  }

  const charCount = currentPost.text.length
  const minMaxLength = selectedPlatforms.length > 0
    ? Math.min(...selectedPlatforms.map((id) => {
        const p = PLATFORMS.find((pl) => pl.id === id)
        return p?.maxTextLength ?? Infinity
      }))
    : Infinity

  return (
    <div className="flex-1 overflow-y-auto p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-5xl mx-auto space-y-6"
      >
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <Sparkles size={22} className="text-brand-red" />
              Compose Post
            </h1>
            <p className="text-sm text-surface-400 mt-1">
              Create once, publish everywhere
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowPreview(!showPreview)}
              className="btn-secondary flex items-center gap-2 text-sm"
            >
              <Eye size={14} />
              Preview
            </button>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-6">
          {/* Left: Composer */}
          <div className="col-span-2 space-y-4">
            {/* Text Input */}
            <div className="glass-card p-5">
              <div className="flex items-center justify-between mb-3">
                <label className="text-xs font-semibold text-surface-300 uppercase tracking-wider flex items-center gap-1.5">
                  <Type size={12} />
                  Post Content
                </label>
                <span
                  className={`text-xs font-mono ${
                    charCount > minMaxLength ? 'text-red-400' : 'text-surface-500'
                  }`}
                >
                  {charCount}
                  {minMaxLength < Infinity && ` / ${minMaxLength}`}
                </span>
              </div>
              <textarea
                value={currentPost.text}
                onChange={(e) => updateCurrentPost({ text: e.target.value })}
                placeholder="What's on your mind? Write your post here..."
                className="input-field min-h-[200px] resize-y font-normal text-sm leading-relaxed"
              />

              {/* Media Buttons */}
              <div className="flex items-center gap-2 mt-3">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  multiple
                  className="hidden"
                  onChange={handleFileChange}
                />
                <button
                  onClick={handleImageAdd}
                  className="btn-secondary flex items-center gap-1.5 text-xs"
                >
                  <ImagePlus size={14} />
                  Add Images
                </button>
                <button className="btn-secondary flex items-center gap-1.5 text-xs">
                  <Video size={14} />
                  Add Video
                </button>
              </div>
            </div>

            {/* Image Preview */}
            {currentPost.images.length > 0 && (
              <div className="glass-card p-4">
                <label className="text-xs font-semibold text-surface-300 uppercase tracking-wider mb-3 block">
                  Attached Images ({currentPost.images.length})
                </label>
                <div className="flex gap-2 flex-wrap">
                  {currentPost.images.map((img, i) => (
                    <div key={i} className="relative group w-20 h-20">
                      <img
                        src={img}
                        alt=""
                        className="w-full h-full object-cover rounded-lg border border-surface-700"
                      />
                      <button
                        onClick={() => handleRemoveImage(i)}
                        className="absolute -top-1.5 -right-1.5 w-5 h-5 bg-red-500 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X size={10} className="text-white" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Post Results */}
            {Object.keys(postResults).length > 0 && (
              <div className="glass-card p-4">
                <label className="text-xs font-semibold text-surface-300 uppercase tracking-wider mb-3 block">
                  Posting Status
                </label>
                <div className="space-y-2">
                  {selectedPlatforms.map((pid) => {
                    const platform = PLATFORMS.find((p) => p.id === pid)
                    const status = postResults[pid]
                    return (
                      <div
                        key={pid}
                        className="flex items-center gap-3 p-2.5 rounded-lg bg-surface-800/40"
                      >
                        <PlatformIcon platformId={pid} size={16} />
                        <span className="text-sm text-white flex-1">{platform?.name}</span>
                        {status === 'posting' && (
                          <Loader2 size={14} className="text-amber-400 animate-spin" />
                        )}
                        {status === 'success' && (
                          <CheckCircle2 size={14} className="text-emerald-400" />
                        )}
                        {status === 'error' && (
                          <AlertTriangle size={14} className="text-red-400" />
                        )}
                      </div>
                    )
                  })}
                </div>
              </div>
            )}
          </div>

          {/* Right: Platform Selection */}
          <div className="space-y-4">
            {/* Platform Selector */}
            <div className="glass-card p-5">
              <div className="flex items-center justify-between mb-3">
                <label className="text-xs font-semibold text-surface-300 uppercase tracking-wider">
                  Post To
                </label>
                <button
                  onClick={handleSelectAll}
                  className="text-[10px] text-brand-red hover:text-brand-red-light transition-colors font-medium"
                >
                  {connectedAccounts.length > 0 &&
                  connectedAccounts.every((a) => selectedPlatforms.includes(a.platformId))
                    ? 'Deselect All'
                    : 'Select All'}
                </button>
              </div>

              <div className="space-y-1.5">
                {PLATFORMS.map((platform) => {
                  const account = accounts.find((a) => a.platformId === platform.id)
                  const isConnected = account?.connectionStatus === 'connected'
                  const isSelected = selectedPlatforms.includes(platform.id)
                  return (
                    <button
                      key={platform.id}
                      onClick={() => isConnected && togglePlatform(platform.id)}
                      disabled={!isConnected}
                      className={`w-full flex items-center gap-3 p-2.5 rounded-lg border transition-all duration-200 ${
                        isSelected
                          ? 'bg-brand-red/10 border-brand-red/30 text-white'
                          : isConnected
                            ? 'bg-surface-800/30 border-surface-700/30 text-surface-300 hover:border-surface-600'
                            : 'bg-surface-900/20 border-surface-800/20 text-surface-600 cursor-not-allowed'
                      }`}
                    >
                      <PlatformIcon platformId={platform.id} colored={isConnected} size={16} />
                      <span className="text-sm flex-1 text-left">{platform.name}</span>
                      {isConnected ? (
                        <div
                          className={`w-4 h-4 rounded border-2 flex items-center justify-center transition-all ${
                            isSelected
                              ? 'bg-brand-red border-brand-red'
                              : 'border-surface-500'
                          }`}
                        >
                          {isSelected && (
                            <svg viewBox="0 0 12 12" className="w-2.5 h-2.5 text-white">
                              <path
                                fill="currentColor"
                                d="M10 3L4.5 8.5 2 6l.7-.7L4.5 7.1 9.3 2.3z"
                              />
                            </svg>
                          )}
                        </div>
                      ) : (
                        <span className="text-[10px] text-surface-600">Not linked</span>
                      )}
                    </button>
                  )
                })}
              </div>
            </div>

            {/* Post Button */}
            <button
              onClick={handlePost}
              disabled={
                isPosting || selectedPlatforms.length === 0 || !currentPost.text.trim()
              }
              className={`w-full py-3.5 rounded-xl font-semibold text-sm flex items-center justify-center gap-2 transition-all duration-300 ${
                isPosting || selectedPlatforms.length === 0 || !currentPost.text.trim()
                  ? 'bg-surface-700 text-surface-500 cursor-not-allowed'
                  : 'btn-glow'
              }`}
            >
              {isPosting ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  Posting...
                </>
              ) : (
                <>
                  <Send size={16} />
                  Post to {selectedPlatforms.length} Platform
                  {selectedPlatforms.length !== 1 ? 's' : ''}
                </>
              )}
            </button>

            {/* Reset */}
            {(currentPost.text || currentPost.images.length > 0) && (
              <button
                onClick={handleReset}
                className="w-full text-xs text-surface-500 hover:text-surface-300 transition-colors py-1"
              >
                Clear & Reset
              </button>
            )}
          </div>
        </div>
      </motion.div>
    </div>
  )
}
