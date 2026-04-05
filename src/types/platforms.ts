import { Platform } from './index'

export const PLATFORMS: Platform[] = [
  {
    id: 'facebook',
    name: 'Facebook',
    icon: 'facebook',
    color: '#1877F2',
    loginUrl: 'https://www.facebook.com/login',
    supportedTypes: ['text', 'image', 'video', 'story', 'reel'],
    maxTextLength: 63206,
    maxImages: 10,
    supportsVideo: true
  },
  {
    id: 'tiktok',
    name: 'TikTok',
    icon: 'tiktok',
    color: '#00F2EA',
    loginUrl: 'https://www.tiktok.com/login',
    supportedTypes: ['video'],
    maxTextLength: 2200,
    maxImages: 0,
    supportsVideo: true
  },
  {
    id: 'twitter',
    name: 'X (Twitter)',
    icon: 'twitter',
    color: '#000000',
    loginUrl: 'https://twitter.com/i/flow/login',
    supportedTypes: ['text', 'image', 'video'],
    maxTextLength: 280,
    maxImages: 4,
    supportsVideo: true
  },
  {
    id: 'instagram',
    name: 'Instagram',
    icon: 'instagram',
    color: '#E4405F',
    loginUrl: 'https://www.instagram.com/accounts/login/',
    supportedTypes: ['image', 'video', 'story', 'reel'],
    maxTextLength: 2200,
    maxImages: 10,
    supportsVideo: true
  },
  {
    id: 'linkedin',
    name: 'LinkedIn',
    icon: 'linkedin',
    color: '#0A66C2',
    loginUrl: 'https://www.linkedin.com/login',
    supportedTypes: ['text', 'image', 'video'],
    maxTextLength: 3000,
    maxImages: 9,
    supportsVideo: true
  },
  {
    id: 'pinterest',
    name: 'Pinterest',
    icon: 'pin',
    color: '#E60023',
    loginUrl: 'https://www.pinterest.com/login/',
    supportedTypes: ['image', 'video'],
    maxTextLength: 500,
    maxImages: 1,
    supportsVideo: true
  },
  {
    id: 'threads',
    name: 'Threads',
    icon: 'at-sign',
    color: '#000000',
    loginUrl: 'https://www.threads.net/login',
    supportedTypes: ['text', 'image', 'video'],
    maxTextLength: 500,
    maxImages: 10,
    supportsVideo: true
  },
  {
    id: 'youtube',
    name: 'YouTube',
    icon: 'youtube',
    color: '#FF0000',
    loginUrl: 'https://accounts.google.com/ServiceLogin',
    supportedTypes: ['text', 'video'],
    maxTextLength: 5000,
    maxImages: 0,
    supportsVideo: true
  },
  {
    id: 'bluesky',
    name: 'Bluesky',
    icon: 'cloud',
    color: '#0085FF',
    loginUrl: 'https://bsky.app/login',
    supportedTypes: ['text', 'image'],
    maxTextLength: 300,
    maxImages: 4,
    supportsVideo: false
  },
  {
    id: 'telegram',
    name: 'Telegram',
    icon: 'send',
    color: '#26A5E4',
    loginUrl: 'https://web.telegram.org/',
    supportedTypes: ['text', 'image', 'video'],
    maxTextLength: 4096,
    maxImages: 10,
    supportsVideo: true
  }
]

export const getPlatform = (id: string): Platform | undefined =>
  PLATFORMS.find((p) => p.id === id)
