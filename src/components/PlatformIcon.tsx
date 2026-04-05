import {
  Facebook,
  Twitter,
  Instagram,
  Linkedin,
  Youtube,
  Send,
  Pin,
  AtSign,
  Cloud,
  Music2,
  type LucideIcon
} from 'lucide-react'
import { PlatformId } from '../types'

const iconMap: Record<PlatformId, LucideIcon> = {
  facebook: Facebook,
  twitter: Twitter,
  instagram: Instagram,
  linkedin: Linkedin,
  youtube: Youtube,
  telegram: Send,
  pinterest: Pin,
  threads: AtSign,
  bluesky: Cloud,
  tiktok: Music2
}

const colorMap: Record<PlatformId, string> = {
  facebook: '#1877F2',
  tiktok: '#00F2EA',
  twitter: '#9CA3AF',
  instagram: '#E4405F',
  linkedin: '#0A66C2',
  pinterest: '#E60023',
  threads: '#9CA3AF',
  youtube: '#FF0000',
  bluesky: '#0085FF',
  telegram: '#26A5E4'
}

interface PlatformIconProps {
  platformId: PlatformId
  size?: number
  colored?: boolean
  className?: string
}

export default function PlatformIcon({
  platformId,
  size = 18,
  colored = true,
  className = ''
}: PlatformIconProps) {
  const Icon = iconMap[platformId]
  const color = colored ? colorMap[platformId] : 'currentColor'

  return <Icon size={size} color={color} className={className} />
}
