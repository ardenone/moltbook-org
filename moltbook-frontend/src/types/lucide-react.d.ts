declare module 'lucide-react' {
  import * as React from 'react';

  export interface LucideProps extends React.SVGProps<SVGSVGElement> {
    size?: number | string;
    absoluteStrokeWidth?: boolean;
  }

  export type LucideIcon = React.ForwardRefExoticComponent<
    LucideProps & React.RefAttributes<SVGSVGElement>
  >;

  export const X: LucideIcon;
  export const ChevronDown: LucideIcon;
  export const ChevronUp: LucideIcon;
  export const Check: LucideIcon;
  export const Circle: LucideIcon;
  export const Loader2: LucideIcon;
  export const ChevronLeft: LucideIcon;
  export const ChevronRight: LucideIcon;
  export const ArrowBigUp: LucideIcon;
  export const ArrowBigDown: LucideIcon;
  export const MessageSquare: LucideIcon;
  export const Share2: LucideIcon;
  export const Bookmark: LucideIcon;
  export const MoreHorizontal: LucideIcon;
  export const ExternalLink: LucideIcon;
  export const Flag: LucideIcon;
  export const Eye: LucideIcon;
  export const EyeOff: LucideIcon;
  export const Trash2: LucideIcon;
  export const TrendingUp: LucideIcon;
  export const Users: LucideIcon;
  export const Flame: LucideIcon;
  export const Clock: LucideIcon;
  export const Zap: LucideIcon;
  export const Home: LucideIcon;
  export const Search: LucideIcon;
  export const Bell: LucideIcon;
  export const Plus: LucideIcon;
  export const Menu: LucideIcon;
  export const Settings: LucideIcon;
  export const LogOut: LucideIcon;
  export const User: LucideIcon;
  export const Moon: LucideIcon;
  export const Sun: LucideIcon;
  export const Hash: LucideIcon;
  export const ArrowRight: LucideIcon;
  export const FileText: LucideIcon;
  export const AlertTriangle: LucideIcon;
  export const RefreshCw: LucideIcon;
  export const ArrowUp: LucideIcon;
  export const Download: LucideIcon;
  export const ZoomIn: LucideIcon;
  export const ZoomOut: LucideIcon;
  export const RotateCw: LucideIcon;
  export const Maximize2: LucideIcon;
  export const Minimize2: LucideIcon;
  export const Link: LucideIcon;
  export const Image: LucideIcon;
  export const Smile: LucideIcon;
}
