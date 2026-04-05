import { AnimatePresence, motion } from 'framer-motion'
import TitleBar from './components/TitleBar'
import Sidebar from './components/Sidebar'
import Dashboard from './pages/Dashboard'
import Compose from './pages/Compose'
import Accounts from './pages/Accounts'
import History from './pages/History'
import Settings from './pages/Settings'
import { useAppStore } from './stores/appStore'

const pageComponents = {
  dashboard: Dashboard,
  compose: Compose,
  accounts: Accounts,
  history: History,
  settings: Settings
}

export default function App() {
  const currentPage = useAppStore((s) => s.currentPage)
  const PageComponent = pageComponents[currentPage]

  return (
    <div className="h-screen w-screen flex flex-col bg-surface-950 overflow-hidden">
      <TitleBar />
      <div className="flex flex-1 overflow-hidden">
        <Sidebar />
        <main className="flex-1 flex overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.div
              key={currentPage}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ duration: 0.15, ease: 'easeOut' }}
              className="flex-1 flex overflow-hidden"
            >
              <PageComponent />
            </motion.div>
          </AnimatePresence>
        </main>
      </div>
    </div>
  )
}
