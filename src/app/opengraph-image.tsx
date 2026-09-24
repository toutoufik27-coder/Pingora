import { ImageResponse } from "next/og";
import { APP_NAME, PRICE_MONTHLY_USD } from "@/lib/brand";

export const alt = `${APP_NAME} — owner statements for Airbnb co-hosts`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** Preview card shown when the site is shared on social networks and chat apps. */
export default function OpenGraphImage() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: 72,
        background: "#214a41",
        color: "white",
        fontFamily: "sans-serif",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
        <svg width="64" height="64" viewBox="0 0 32 32">
          <rect width="32" height="32" rx="9" fill="#ffffff" />
          <path
            d="M9 15.5 16 9.5l7 6v7a1 1 0 0 1-1 1H10a1 1 0 0 1-1-1Z"
            fill="none"
            stroke="#2f6b5e"
            strokeWidth="2"
            strokeLinejoin="round"
          />
          <path d="M12.5 18.5h7M12.5 21h4.5" stroke="#2f6b5e" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
        <div style={{ fontSize: 36, fontWeight: 700 }}>{APP_NAME}</div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
        <div style={{ fontSize: 72, fontWeight: 700, lineHeight: 1.05, maxWidth: 980 }}>Owner statements in minutes, not evenings.</div>
        <div style={{ fontSize: 32, color: "#dcece5" }}>For Airbnb co-hosts · PDF, email and owner portal</div>
      </div>
      <div style={{ fontSize: 28, color: "#dcece5" }}>{`Free trial · $${PRICE_MONTHLY_USD}/month`}</div>
    </div>,
    size,
  );
}
