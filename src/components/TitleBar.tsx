import { useState, useEffect } from 'react'
import { Minus, Square, X, Copy, Download, Loader2, CheckCircle2, RefreshCw } from 'lucide-react'

interface UpdateInfo {
  status: string
  version?: string
  percent?: number
  message?: string
}

export default function TitleBar() {
  const [isMaximized, setIsMaximized] = useState(false)
  const [updateInfo, setUpdateInfo] = useState<UpdateInfo | null>(null)

  useEffect(() => {
    const checkMaximized = async () => {
      if (window.api) {
        const max = await window.api.isMaximized()
        setIsMaximized(max)
      }
    }
    checkMaximized()
    window.addEventListener('resize', checkMaximized)
    return () => window.removeEventListener('resize', checkMaximized)
  }, [])

  useEffect(() => {
    if (!window.api?.onUpdaterStatus) return
    const unsubscribe = window.api.onUpdaterStatus((data) => {
      setUpdateInfo(data as UpdateInfo)
    })
    return unsubscribe
  }, [])

  const renderUpdateBadge = () => {
    if (!updateInfo) return null

    switch (updateInfo.status) {
      case 'checking':
        return (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-surface-800/80 text-[10px] text-surface-400">
            <RefreshCw size={10} className="animate-spin" />
            Checking...
          </div>
        )
      case 'downloading':
        return (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-blue-500/10 text-[10px] text-blue-400">
            <Loader2 size={10} className="animate-spin" />
            {updateInfo.percent ?? 0}%
          </div>
        )
      case 'available':
        return (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-amber-500/10 text-[10px] text-amber-400">
            <Download size={10} />
            v{updateInfo.version}
          </div>
        )
      case 'downloaded':
        return (
          <button
            onClick={() => window.api?.installUpdate()}
            className="no-drag flex items-center gap-1.5 px-2 py-0.5 rounded bg-emerald-500/10 text-[10px] text-emerald-400 hover:bg-emerald-500/20 transition-colors"
          >
            <CheckCircle2 size={10} />
            Install v{updateInfo.version}
          </button>
        )
      default:
        return null
    }
  }

  return (
    <div className="drag-region h-10 flex items-center justify-between bg-surface-950 border-b border-surface-800/60 px-4 shrink-0">
      <div className="flex items-center gap-2">
        <div className="w-5 h-5 bg-brand-red rounded-md flex items-center justify-center">
          <span className="text-[9px] font-black text-white leading-none">PX</span>
        </div>
        <span className="text-xs font-semibold text-surface-300 tracking-wide">PostX App</span>
        <span className="text-[10px] text-surface-500 font-mono">v1.0.0</span>
        {renderUpdateBadge()}
      </div>

      <div className="no-drag flex items-center">
        <button
          onClick={() => window.api?.minimizeWindow()}
          className="w-10 h-10 flex items-center justify-center text-surface-400 hover:text-white hover:bg-surface-800 transition-colors"
        >
          <Minus size={14} />
        </button>
        <button
          onClick={() => {
            window.api?.maximizeWindow()
            setIsMaximized(!isMaximized)
          }}
          className="w-10 h-10 flex items-center justify-center text-surface-400 hover:text-white hover:bg-surface-800 transition-colors"
        >
          {isMaximized ? <Copy size={12} /> : <Square size={12} />}
        </button>
        <button
          onClick={() => window.api?.closeWindow()}
          className="w-10 h-10 flex items-center justify-center text-surface-400 hover:text-white hover:bg-red-600 transition-colors"
        >
          <X size={14} />
        </button>
      </div>
    </div>
  )
}
