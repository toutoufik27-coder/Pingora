/** Shared by the proxy and the server; keep this file free of imports. */
export const SESSION_COOKIE = "cl_session";
export const SESSION_COOKIE_MAX_AGE_S = 30 * 24 * 60 * 60;

export function sessionCookieOptions(appUrl: string) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: appUrl.startsWith("https://"),
    path: "/",
    maxAge: SESSION_COOKIE_MAX_AGE_S,
  };
}
