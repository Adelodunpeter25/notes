/** @type {import('tailwindcss').Config} */
module.exports = {
  // NOTE: Update this to include the paths to all of your component files.
  content: ["./App.{js,jsx,ts,tsx}", "./src/**/*.{js,jsx,ts,tsx}", "./components/**/*.{js,jsx,ts,tsx}", "./screens/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        background: "#1e1e1e",
        surface: "#252525",
        surfaceSecondary: "#2b2b2b",
        border: "#3e3e3e",
        accent: "#eab308",
        text: "#ffffff",
        textMuted: "#a0a0a0",
      },
    },
  },
  plugins: [],
};
