import { useState, useEffect } from 'react'
import { Minus, Square, X, Copy } from 'lucide-react'

export default function TitleBar() {
  const [isMaximized, setIsMaximized] = useState(false)

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

  return (
    <div className="drag-region h-10 flex items-center justify-between bg-surface-950 border-b border-surface-800/60 px-4 shrink-0">
      <div className="flex items-center gap-2">
        <div className="w-5 h-5 bg-brand-red rounded-md flex items-center justify-center">
          <span className="text-[9px] font-black text-white leading-none">PX</span>
        </div>
        <span className="text-xs font-semibold text-surface-300 tracking-wide">PostX App</span>
        <span className="text-[10px] text-surface-500 font-mono">v1.0.0</span>
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
