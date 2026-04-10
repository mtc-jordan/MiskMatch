import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        misk: {
          50: "#f5f3f0",
          100: "#e8e3db",
          200: "#d4cbb8",
          300: "#b8a88e",
          400: "#9d866a",
          500: "#8B7355",
          600: "#6d5a43",
          700: "#564737",
          800: "#3f342b",
          900: "#2d2520",
          950: "#1a1512",
        },
        gold: {
          50: "#fffbeb",
          100: "#fef3c7",
          200: "#fde68a",
          300: "#fcd34d",
          400: "#fbbf24",
          500: "#D4A853",
          600: "#b8922e",
          700: "#92730e",
          800: "#78600d",
          900: "#634f0e",
        },
      },
    },
  },
  plugins: [],
};

export default config;
