import type { SVGProps } from "react";

/** Small outline icons (24×24 grid, 1.75 stroke) drawn inline so they need no icon library. */
export type IconName =
  | "dashboard"
  | "upload"
  | "statement"
  | "calendar"
  | "home"
  | "users"
  | "receipt"
  | "chart"
  | "settings"
  | "card"
  | "user"
  | "logout"
  | "menu"
  | "close"
  | "check"
  | "arrow"
  | "chevron";

const PATHS: Record<IconName, string[]> = {
  dashboard: ["M4 13h6V4H4z", "M14 20h6v-9h-6z", "M14 8h6V4h-6z", "M4 20h6v-3H4z"],
  upload: ["M12 16V4", "m7 9 5-5 5 5", "M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"],
  statement: ["M7 3h7l5 5v12a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z", "M14 3v5h5", "M9 13h6", "M9 17h6"],
  calendar: ["M5 5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z", "M4 10h16", "M8 3v4", "M16 3v4"],
  home: ["m4 11 8-7 8 7", "M6 10v9a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-9", "M10 20v-5h4v5"],
  users: [
    "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z",
    "M3 20c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5",
    "M16 4.5a3.5 3.5 0 0 1 0 6.5",
    "M18 14.8c1.8.7 3 2.5 3 5.2",
  ],
  receipt: ["M6 3h12v18l-3-2-3 2-3-2-3 2z", "M9 8h6", "M9 12h6", "M9 16h3"],
  chart: ["M4 20h16", "M7 16v-4", "M12 16V7", "M17 16v-7"],
  settings: [
    "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
    "M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z",
  ],
  card: ["M4 6h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z", "M3 10h18", "M7 15h3"],
  user: ["M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z", "M4 21c0-4 3.6-6.5 8-6.5s8 2.5 8 6.5"],
  logout: ["M15 17l5-5-5-5", "M20 12H9", "M11 20H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h6"],
  menu: ["M4 7h16", "M4 12h16", "M4 17h16"],
  close: ["M6 6l12 12", "M18 6 6 18"],
  check: ["m5 12 5 5 9-10"],
  arrow: ["M5 12h14", "m13 6 6 6-6 6"],
  chevron: ["m9 6 6 6-6 6"],
};

export function Icon({ name, className = "size-5", ...props }: { name: IconName } & SVGProps<SVGSVGElement>) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      className={className}
      {...props}
    >
      {PATHS[name].map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  );
}
