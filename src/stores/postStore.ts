import { create } from 'zustand'
import { PostContent, PostJob, PostHistory, PlatformId, PostStatus } from '../types'

interface PostState {
  // Current post being composed
  currentPost: PostContent
  selectedPlatforms: PlatformId[]

  // Post queue and history
  activeJobs: PostJob[]
  history: PostHistory[]

  // Actions - compose
  updateCurrentPost: (updates: Partial<PostContent>) => void
  resetCurrentPost: () => void
  togglePlatform: (platformId: PlatformId) => void
  setSelectedPlatforms: (platforms: PlatformId[]) => void

  // Actions - jobs
  addJob: (job: PostJob) => void
  updateJobStatus: (jobId: string, platformId: PlatformId, status: PostStatus, error?: string) => void
  removeJob: (jobId: string) => void

  // Actions - history
  addHistory: (entry: PostHistory) => void
  setHistory: (history: PostHistory[]) => void
  clearHistory: () => void
}

const defaultPost: PostContent = {
  text: '',
  images: [],
  type: 'text'
}

export const usePostStore = create<PostState>((set) => ({
  currentPost: { ...defaultPost },
  selectedPlatforms: [],
  activeJobs: [],
  history: [],

  updateCurrentPost: (updates) =>
    set((state) => ({
      currentPost: { ...state.currentPost, ...updates }
    })),

  resetCurrentPost: () =>
    set({
      currentPost: { ...defaultPost },
      selectedPlatforms: []
    }),

  togglePlatform: (platformId) =>
    set((state) => ({
      selectedPlatforms: state.selectedPlatforms.includes(platformId)
        ? state.selectedPlatforms.filter((id) => id !== platformId)
        : [...state.selectedPlatforms, platformId]
    })),

  setSelectedPlatforms: (platforms) => set({ selectedPlatforms: platforms }),

  addJob: (job) =>
    set((state) => ({
      activeJobs: [job, ...state.activeJobs]
    })),

  updateJobStatus: (jobId, platformId, status, error) =>
    set((state) => ({
      activeJobs: state.activeJobs.map((job) =>
        job.id === jobId
          ? {
              ...job,
              status: { ...job.status, [platformId]: status },
              errors: error
                ? { ...job.errors, [platformId]: error }
                : job.errors
            }
          : job
      )
    })),

  removeJob: (jobId) =>
    set((state) => ({
      activeJobs: state.activeJobs.filter((job) => job.id !== jobId)
    })),

  addHistory: (entry) =>
    set((state) => ({
      history: [entry, ...state.history]
    })),

  setHistory: (history) => set({ history }),

  clearHistory: () => set({ history: [] })
}))
