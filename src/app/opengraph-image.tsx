import { ImageResponse } from "next/og";
import { APP_NAME, PRICE_MONTHLY_USD } from "@/lib/brand";

export const alt = `${APP_NAME} — owner statements for Airbnb co-hosts`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** Preview card shown when the site is shared on social networks and chat apps. */
export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 72,
          background: "#134e4a",
          color: "white",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
          <div
            style={{
              width: 64,
              height: 64,
              borderRadius: 14,
              background: "white",
              color: "#0f766e",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 30,
              fontWeight: 700,
            }}
          >
            CL
          </div>
          <div style={{ fontSize: 36, fontWeight: 700 }}>{APP_NAME}</div>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
          <div style={{ fontSize: 72, fontWeight: 700, lineHeight: 1.05, maxWidth: 980 }}>Owner statements in minutes, not evenings.</div>
          <div style={{ fontSize: 32, color: "#d7f2ea" }}>For Airbnb co-hosts · PDF, email and owner portal</div>
        </div>
        <div style={{ fontSize: 28, color: "#d7f2ea" }}>{`Free trial · $${PRICE_MONTHLY_USD}/month`}</div>
      </div>
    ),
    size,
  );
}
