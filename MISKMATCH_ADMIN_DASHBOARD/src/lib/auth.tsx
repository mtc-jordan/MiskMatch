"use client";

import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { useRouter } from "next/navigation";

interface AuthCtx {
  token: string | null;
  setToken: (t: string | null) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthCtx>({ token: null, setToken: () => {}, logout: () => {} });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setTokenState] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    const stored = localStorage.getItem("admin_token");
    if (stored) setTokenState(stored);
  }, []);

  const setToken = (t: string | null) => {
    if (t) {
      localStorage.setItem("admin_token", t);
    } else {
      localStorage.removeItem("admin_token");
    }
    setTokenState(t);
  };

  const logout = () => {
    setToken(null);
    router.push("/login");
  };

  return <AuthContext.Provider value={{ token, setToken, logout }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
