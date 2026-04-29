/** @type {import('tailwindcss').Config} */
module.exports = {
  // NOTE: Update this to include the paths to all of your component files.
  content: ["./App.{js,jsx,ts,tsx}", "./src/**/*.{js,jsx,ts,tsx}", "./components/**/*.{js,jsx,ts,tsx}", "./screens/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        background: "#000000",
        surface: "#0a0a0a",
        surfaceSecondary: "#282828",
        border: "#222222",
        accent: "#eab308",
        text: "#ffffff",
        textMuted: "#a0a0a0",
        danger: "#ff4444",
      },
    },
  },
  plugins: [],
};
