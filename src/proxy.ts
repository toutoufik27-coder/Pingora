import { NextResponse, type NextRequest } from "next/server";
import { SESSION_COOKIE, sessionCookieOptions } from "./server/auth/cookie";
import { appUrl } from "./server/env";

/** Pages that need a signed-in user. The server re-checks the session on every request. */
const APP_PATHS = [
  "/dashboard",
  "/import",
  "/statements",
  "/properties",
  "/owners",
  "/expenses",
  "/transactions",
  "/reports",
  "/settings",
  "/account",
  "/billing",
];

function isAppPath(pathname: string): boolean {
  return APP_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

export function proxy(request: NextRequest) {
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const { pathname, search } = request.nextUrl;

  if (!token && isAppPath(pathname)) {
    const login = new URL("/login", request.url);
    login.searchParams.set("next", `${pathname}${search}`);
    return NextResponse.redirect(login);
  }

  const response = NextResponse.next();
  // Keep an active user's cookie alive; the database decides whether the session is still valid.
  if (token && request.method === "GET") {
    response.cookies.set(SESSION_COOKIE, token, sessionCookieOptions(appUrl()));
  }
  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|api/|favicon.ico|samples/|marketing/|robots.txt|sitemap.xml).*)"],
};
