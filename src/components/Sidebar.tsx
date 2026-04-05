import {
  LayoutDashboard,
  PenSquare,
  Users,
  History,
  Settings,
  ChevronLeft,
  ChevronRight,
  Zap
} from 'lucide-react'
import { useAppStore } from '../stores/appStore'
import { usePlatformStore } from '../stores/platformStore'
import { motion, AnimatePresence } from 'framer-motion'

const navItems = [
  { id: 'dashboard' as const, label: 'Dashboard', icon: LayoutDashboard },
  { id: 'compose' as const, label: 'Compose', icon: PenSquare },
  { id: 'accounts' as const, label: 'Accounts', icon: Users },
  { id: 'history' as const, label: 'History', icon: History },
  { id: 'settings' as const, label: 'Settings', icon: Settings }
]

export default function Sidebar() {
  const { currentPage, setPage, sidebarCollapsed, toggleSidebar } = useAppStore()
  const connectedCount = usePlatformStore((s) => s.getConnectedPlatforms().length)

  return (
    <motion.aside
      initial={false}
      animate={{ width: sidebarCollapsed ? 68 : 220 }}
      transition={{ duration: 0.2, ease: 'easeInOut' }}
      className="h-full bg-surface-900/80 border-r border-surface-800/60 flex flex-col shrink-0"
    >
      {/* Logo area */}
      <div className="p-4 flex items-center gap-3">
        <div className="w-9 h-9 bg-gradient-to-br from-brand-red to-brand-red-dark rounded-xl flex items-center justify-center shadow-lg shadow-brand-red/20 shrink-0">
          <Zap size={18} className="text-white" />
        </div>
        <AnimatePresence>
          {!sidebarCollapsed && (
            <motion.div
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -10 }}
              transition={{ duration: 0.15 }}
            >
              <h1 className="text-sm font-bold text-white leading-tight">PostX</h1>
              <p className="text-[10px] text-surface-500 leading-tight">xman studio</p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-2 py-2 space-y-1">
        {navItems.map((item) => {
          const isActive = currentPage === item.id
          const Icon = item.icon
          return (
            <button
              key={item.id}
              onClick={() => setPage(item.id)}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 group relative ${
                isActive
                  ? 'bg-brand-red/10 text-brand-red'
                  : 'text-surface-400 hover:text-white hover:bg-surface-800/60'
              }`}
            >
              {isActive && (
                <motion.div
                  layoutId="sidebar-indicator"
                  className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 bg-brand-red rounded-r-full"
                  transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                />
              )}
              <Icon size={18} className="shrink-0" />
              <AnimatePresence>
                {!sidebarCollapsed && (
                  <motion.span
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="text-sm font-medium whitespace-nowrap"
                  >
                    {item.label}
                  </motion.span>
                )}
              </AnimatePresence>
            </button>
          )
        })}
      </nav>

      {/* Connection status */}
      <div className="px-3 py-3 border-t border-surface-800/60">
        <div className="flex items-center gap-2">
          <div className={`status-dot ${connectedCount > 0 ? 'connected' : 'disconnected'}`} />
          <AnimatePresence>
            {!sidebarCollapsed && (
              <motion.span
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="text-xs text-surface-400"
              >
                {connectedCount} connected
              </motion.span>
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Collapse toggle */}
      <button
        onClick={toggleSidebar}
        className="p-3 border-t border-surface-800/60 text-surface-500 hover:text-white hover:bg-surface-800/40 transition-colors flex items-center justify-center"
      >
        {sidebarCollapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
      </button>
    </motion.aside>
  )
}
