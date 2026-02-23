/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: "#1e1e1e",
        surface: "#282828",
        border: "#3f3f3f",
        text: "#f5f5f7",
        muted: "#98989d",
        accent: {
          DEFAULT: "#eab308",
          foreground: "#ffffff",
          soft: "#fef08a",
        },
        danger: {
          DEFAULT: "#ef4444",
          soft: "#f87171",
          foreground: "#ffffff",
        },
      },
      borderRadius: {
        xl: "0.875rem",
      },
      transitionTimingFunction: {
        apple: "cubic-bezier(0.22, 1, 0.36, 1)",
      },
      boxShadow: {
        card: "0 10px 30px rgba(0, 0, 0, 0.28)",
      },
    },
  },
  plugins: [],
};
